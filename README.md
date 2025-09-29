# Docker Infrastructure Stack

A production-ready Docker Compose setup with PostgreSQL, Redis, and RabbitMQ.

## Services

### PostgreSQL
- **Version**: 16-alpine
- **Port**: 5432 (configurable)
- **Management**: psql, pgAdmin, or any PostgreSQL client
- **Default Database**: maindb
- **Health Check**: Automatic with pg_isready

### Redis
- **Version**: 7-alpine
- **Port**: 6379 (configurable)
- **Persistence**: AOF (Append Only File) enabled
- **Management**: redis-cli or RedisInsight
- **Memory Limit**: 256MB (configurable in redis.conf)

### RabbitMQ
- **Version**: 3.13 with Management Plugin
- **AMQP Port**: 5672 (configurable)
- **Management UI Port**: 15672 (configurable)
- **Management URL**: http://localhost:15672
- **Default Virtual Host**: /

## Quick Start

### 1. Clone and Setup

```bash
# Copy environment variables
cp .env.example .env

# Edit .env file with your preferred credentials
nano .env
```

### 2. Start Services

```bash
# Start all services
docker-compose up -d

# Start specific service
docker-compose up -d postgres
docker-compose up -d redis
docker-compose up -d rabbitmq

# View logs
docker-compose logs -f
docker-compose logs -f postgres
```

### 3. Stop Services

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (WARNING: This will delete all data)
docker-compose down -v
```

## Connection Details

### PostgreSQL
```bash
# Command line
psql -h localhost -p 5432 -U admin -d maindb

# Connection string
postgresql://admin:password123@localhost:5432/maindb
```

### Redis
```bash
# Command line
redis-cli -h localhost -p 6379 -a redis123

# Connection string
redis://:redis123@localhost:6379
```

### RabbitMQ
```bash
# Management UI
http://localhost:15672
Username: admin
Password: rabbit123

# AMQP Connection string
amqp://admin:rabbit123@localhost:5672/
```

## Data Persistence

All data is persisted using Docker volumes:
- `postgres_data`: PostgreSQL data
- `redis_data`: Redis persistence files
- `rabbitmq_data`: RabbitMQ data
- `rabbitmq_logs`: RabbitMQ logs

## Custom Configuration

### PostgreSQL Initialization Scripts
Place `.sql` or `.sh` files in `init-scripts/` directory. They will be executed on first container start.

### Redis Configuration
Modify `redis.conf` for custom Redis settings.

### Environment Variables
All configuration is done through environment variables in `.env` file:

```env
# PostgreSQL
POSTGRES_USER=admin
POSTGRES_PASSWORD=password123
POSTGRES_DB=maindb
POSTGRES_PORT=5432

# Redis
REDIS_PASSWORD=redis123
REDIS_PORT=6379

# RabbitMQ
RABBITMQ_USER=admin
RABBITMQ_PASSWORD=rabbit123
RABBITMQ_VHOST=/
RABBITMQ_PORT=5672
RABBITMQ_MGMT_PORT=15672
```

## Health Checks

All services include health checks for monitoring:

```bash
# Check service health
docker-compose ps

# Manual health check
docker exec postgres_db pg_isready -U admin
docker exec redis_cache redis-cli ping
docker exec rabbitmq_broker rabbitmq-diagnostics ping
```

## Backup and Restore

### PostgreSQL Backup
```bash
# Backup
docker exec postgres_db pg_dump -U admin maindb > backup.sql

# Restore
docker exec -i postgres_db psql -U admin maindb < backup.sql
```

### Redis Backup
```bash
# Backup
docker exec redis_cache redis-cli --rdb /data/dump.rdb
docker cp redis_cache:/data/dump.rdb ./redis-backup.rdb

# Restore
docker cp ./redis-backup.rdb redis_cache:/data/dump.rdb
docker-compose restart redis
```

## Monitoring

### View Resource Usage
```bash
docker stats
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f postgres
docker-compose logs -f redis
docker-compose logs -f rabbitmq
```

## Troubleshooting

### Container Won't Start
1. Check logs: `docker-compose logs [service_name]`
2. Verify ports are not in use: `lsof -i :5432` (PostgreSQL), `lsof -i :6379` (Redis), `lsof -i :5672` (RabbitMQ)
3. Ensure Docker daemon is running: `docker info`

### Connection Refused
1. Verify service is running: `docker-compose ps`
2. Check firewall settings
3. Verify credentials in `.env` file

### Permission Issues
```bash
# Fix volume permissions
docker-compose down -v
sudo rm -rf ./data
docker-compose up -d
```

## Security Notes

1. **Change default passwords** in production
2. **Use secrets management** for sensitive data
3. **Restrict network access** in production environments
4. **Enable SSL/TLS** for external connections
5. **Regular backups** of critical data

## License

MIT