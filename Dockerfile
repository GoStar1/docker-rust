# Multi-stage Dockerfile for Rust application
ARG RUST_VERSION=1.79

# Stage 1: Build stage
FROM rust:${RUST_VERSION}-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    musl-dev \
    openssl-dev \
    pkgconfig \
    postgresql-dev \
    build-base

# Create app directory
WORKDIR /usr/src/app

# Copy dependency files
COPY Cargo.toml Cargo.lock ./

# Create dummy main.rs to build dependencies
RUN mkdir src && \
    echo "fn main() {}" > src/main.rs && \
    cargo build --release && \
    rm -rf src

# Copy source code
COPY src ./src

# Build the application with optimizations
RUN cargo build --release --target x86_64-unknown-linux-musl && \
    strip target/x86_64-unknown-linux-musl/release/app

# Stage 2: Runtime stage
FROM alpine:3.19

# Install runtime dependencies
RUN apk add --no-cache \
    openssl \
    postgresql-client \
    ca-certificates \
    tzdata && \
    addgroup -g 1000 rust && \
    adduser -D -s /bin/sh -u 1000 -G rust rust

# Set timezone
ENV TZ=UTC

# Create necessary directories
RUN mkdir -p /app/logs /app/config && \
    chown -R rust:rust /app

WORKDIR /app

# Copy binary from builder
COPY --from=builder --chown=rust:rust /usr/src/app/target/x86_64-unknown-linux-musl/release/app /app/app

# Copy configuration files if exists
COPY --chown=rust:rust config/* /app/config/ 2>/dev/null || :

# Use non-root user
USER rust

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:${APP_PORT:-8080}/health || exit 1

# Expose application port
EXPOSE ${APP_PORT:-8080}

# Run the application
CMD ["./app"]