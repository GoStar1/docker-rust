#!/bin/bash

# Production deployment script

set -e

echo "🚀 Starting production deployment..."

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found!"
    echo "Please copy .env.example to .env and configure it:"
    echo "  cp .env.example .env"
    exit 1
fi

# Load environment variables
export $(cat .env | grep -v '^#' | xargs)

# Validate required environment variables
required_vars=("POSTGRES_PASSWORD" "REDIS_PASSWORD" "RABBITMQ_PASSWORD")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Error: $var is not set in .env file!"
        exit 1
    fi
done

# Function to wait for service
wait_for_service() {
    local service=$1
    local max_attempts=30
    local attempt=1

    echo "⏳ Waiting for $service to be healthy..."
    while [ $attempt -le $max_attempts ]; do
        if docker-compose ps | grep -q "$service.*healthy"; then
            echo "✅ $service is healthy"
            return 0
        fi
        echo "  Attempt $attempt/$max_attempts..."
        sleep 2
        attempt=$((attempt + 1))
    done

    echo "❌ $service failed to become healthy"
    return 1
}

# Pull latest images
echo "📦 Pulling latest images..."
docker-compose pull

# Build Rust application
echo "🔨 Building Rust application..."
docker-compose build rust_app

# Start infrastructure services first
echo "🗄️ Starting infrastructure services..."
docker-compose up -d postgres redis rabbitmq

# Wait for services to be healthy
wait_for_service "postgres"
wait_for_service "redis"
wait_for_service "rabbitmq"

# Start Rust application
echo "🦀 Starting Rust application..."
docker-compose up -d rust_app

# Optional: Start Nginx if needed
read -p "Do you want to start Nginx reverse proxy? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🌐 Starting Nginx..."
    docker-compose --profile with-nginx up -d nginx
fi

# Show service status
echo ""
echo "📊 Service Status:"
docker-compose ps

# Show logs
echo ""
echo "📋 Recent logs:"
docker-compose logs --tail=20

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📌 Service URLs:"
echo "  - Application: http://localhost:${APP_PORT:-8080}"
echo "  - RabbitMQ Management: http://localhost:${RABBITMQ_MANAGEMENT_PORT:-15672}"
echo "  - PostgreSQL: localhost:${POSTGRES_PORT:-5432}"
echo "  - Redis: localhost:${REDIS_PORT:-6379}"
echo ""
echo "📝 Useful commands:"
echo "  - View logs: docker-compose logs -f [service_name]"
echo "  - Stop all: docker-compose down"
echo "  - Restart service: docker-compose restart [service_name]"
echo "  - View stats: docker stats"