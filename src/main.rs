use actix_web::{web, App, HttpResponse, HttpServer, Result};
use redis::AsyncCommands;
use sqlx::postgres::PgPoolOptions;
use lapin::{Connection, ConnectionProperties, options::*, types::FieldTable};
use tracing::{info, error};
use tracing_subscriber;
use std::env;

#[derive(serde::Serialize)]
struct HealthResponse {
    status: String,
    postgres: String,
    redis: String,
    rabbitmq: String,
}

async fn health_check(
    db: web::Data<sqlx::PgPool>,
    redis_client: web::Data<redis::aio::ConnectionManager>,
) -> Result<HttpResponse> {
    let mut health = HealthResponse {
        status: "healthy".to_string(),
        postgres: "unknown".to_string(),
        redis: "unknown".to_string(),
        rabbitmq: "unknown".to_string(),
    };

    match sqlx::query("SELECT 1").fetch_one(db.get_ref()).await {
        Ok(_) => health.postgres = "healthy".to_string(),
        Err(e) => {
            error!("PostgreSQL health check failed: {}", e);
            health.postgres = "unhealthy".to_string();
            health.status = "unhealthy".to_string();
        }
    }

    let mut redis_conn = redis_client.get_ref().clone();
    match redis_conn.ping::<String>().await {
        Ok(_) => health.redis = "healthy".to_string(),
        Err(e) => {
            error!("Redis health check failed: {}", e);
            health.redis = "unhealthy".to_string();
            health.status = "unhealthy".to_string();
        }
    }

    Ok(HttpResponse::Ok().json(health))
}

async fn index() -> Result<HttpResponse> {
    Ok(HttpResponse::Ok().json(serde_json::json!({
        "message": "Rust API Server",
        "version": "1.0.0"
    })))
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    tracing_subscriber::fmt::init();

    info!("Starting Rust application...");

    let database_url = env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgres://postgres:password@localhost/app_db".to_string());
    let redis_url = env::var("REDIS_URL")
        .unwrap_or_else(|_| "redis://localhost:6379".to_string());
    let amqp_url = env::var("AMQP_URL")
        .unwrap_or_else(|_| "amqp://admin:password@localhost:5672/%2f".to_string());
    let app_host = env::var("APP_HOST").unwrap_or_else(|_| "0.0.0.0".to_string());
    let app_port = env::var("APP_PORT")
        .unwrap_or_else(|_| "8080".to_string())
        .parse::<u16>()
        .expect("APP_PORT must be a valid port number");

    info!("Connecting to PostgreSQL...");
    let db_pool = PgPoolOptions::new()
        .max_connections(25)
        .connect(&database_url)
        .await
        .expect("Failed to connect to PostgreSQL");

    info!("Connecting to Redis...");
    let redis_client = redis::Client::open(redis_url).expect("Failed to create Redis client");
    let redis_conn_manager = redis::aio::ConnectionManager::new(redis_client)
        .await
        .expect("Failed to connect to Redis");

    info!("Connecting to RabbitMQ...");
    let rabbitmq_conn = Connection::connect(&amqp_url, ConnectionProperties::default())
        .await
        .expect("Failed to connect to RabbitMQ");

    let channel = rabbitmq_conn.create_channel()
        .await
        .expect("Failed to create RabbitMQ channel");

    channel
        .queue_declare(
            "task_queue",
            QueueDeclareOptions::default(),
            FieldTable::default(),
        )
        .await
        .expect("Failed to declare queue");

    info!("Starting HTTP server on {}:{}", app_host, app_port);

    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(db_pool.clone()))
            .app_data(web::Data::new(redis_conn_manager.clone()))
            .route("/", web::get().to(index))
            .route("/health", web::get().to(health_check))
            .route("/api/health", web::get().to(health_check))
    })
    .bind((app_host, app_port))?
    .run()
    .await
}