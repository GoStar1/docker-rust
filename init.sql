-- PostgreSQL initialization script for production

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Create application user with limited privileges
CREATE USER app_user WITH PASSWORD 'app_secure_password';

-- Create application schema
CREATE SCHEMA IF NOT EXISTS app;

-- Grant privileges
GRANT CONNECT ON DATABASE app_db TO app_user;
GRANT USAGE ON SCHEMA app TO app_user;
GRANT CREATE ON SCHEMA app TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT ALL ON TABLES TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT ALL ON SEQUENCES TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT EXECUTE ON FUNCTIONS TO app_user;

-- Create audit table for tracking changes
CREATE TABLE IF NOT EXISTS app.audit_log (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    table_name VARCHAR(255) NOT NULL,
    operation VARCHAR(10) NOT NULL,
    user_name VARCHAR(255),
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    old_data JSONB,
    new_data JSONB
);

-- Create index for audit log
CREATE INDEX idx_audit_log_table_name ON app.audit_log(table_name);
CREATE INDEX idx_audit_log_changed_at ON app.audit_log(changed_at);

-- Example application table
CREATE TABLE IF NOT EXISTS app.users (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    last_login TIMESTAMP WITH TIME ZONE
);

-- Create indexes for users table
CREATE INDEX idx_users_email ON app.users(email);
CREATE INDEX idx_users_username ON app.users(username);
CREATE INDEX idx_users_is_active ON app.users(is_active);

-- Example sessions table
CREATE TABLE IF NOT EXISTS app.sessions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
    token VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create index for sessions
CREATE INDEX idx_sessions_token ON app.sessions(token);
CREATE INDEX idx_sessions_user_id ON app.sessions(user_id);
CREATE INDEX idx_sessions_expires_at ON app.sessions(expires_at);

-- Example messages table for RabbitMQ tracking
CREATE TABLE IF NOT EXISTS app.message_queue (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    queue_name VARCHAR(255) NOT NULL,
    message_body JSONB NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    retry_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT
);

-- Create indexes for message queue
CREATE INDEX idx_message_queue_status ON app.message_queue(status);
CREATE INDEX idx_message_queue_created_at ON app.message_queue(created_at);

-- Example cache invalidation table
CREATE TABLE IF NOT EXISTS app.cache_invalidation (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    cache_key VARCHAR(255) NOT NULL,
    invalidated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    reason VARCHAR(255)
);

-- Create index for cache invalidation
CREATE INDEX idx_cache_invalidation_key ON app.cache_invalidation(cache_key);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION app.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to auto-update updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON app.users
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at_column();

-- Function for audit logging
CREATE OR REPLACE FUNCTION app.audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO app.audit_log(table_name, operation, user_name, old_data)
        VALUES (TG_TABLE_NAME, TG_OP, current_user, row_to_json(OLD));
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO app.audit_log(table_name, operation, user_name, old_data, new_data)
        VALUES (TG_TABLE_NAME, TG_OP, current_user, row_to_json(OLD), row_to_json(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO app.audit_log(table_name, operation, user_name, new_data)
        VALUES (TG_TABLE_NAME, TG_OP, current_user, row_to_json(NEW));
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Apply audit trigger to users table
CREATE TRIGGER audit_trigger_users
AFTER INSERT OR UPDATE OR DELETE ON app.users
FOR EACH ROW EXECUTE FUNCTION app.audit_trigger_function();

-- Performance optimization settings
ALTER DATABASE app_db SET random_page_cost = 1.1;
ALTER DATABASE app_db SET effective_io_concurrency = 200;
ALTER DATABASE app_db SET shared_preload_libraries = 'pg_stat_statements';

-- Create read-only user for reporting (optional)
CREATE USER app_readonly WITH PASSWORD 'readonly_secure_password';
GRANT CONNECT ON DATABASE app_db TO app_readonly;
GRANT USAGE ON SCHEMA app TO app_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA app TO app_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT SELECT ON TABLES TO app_readonly;

-- Initial data seed (optional)
INSERT INTO app.users (username, email, password_hash)
VALUES ('admin', 'admin@example.com', crypt('admin_password', gen_salt('bf')))
ON CONFLICT DO NOTHING;