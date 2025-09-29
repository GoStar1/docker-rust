# Production Docker Setup - Rust + RabbitMQ + PostgreSQL + Redis

## 🚀 快速开始

### 1. 配置环境变量
```bash
cp .env.example .env
# 编辑 .env 文件，设置安全的密码
```

### 2. 部署
```bash
./deploy.sh
```

## 📦 服务组件

- **Rust Application**: 主应用服务
- **PostgreSQL 16**: 主数据库
- **Redis 7**: 缓存服务
- **RabbitMQ 3.13**: 消息队列
- **Nginx**: 反向代理（可选）

## 🛠️ 管理命令

### 启动所有服务
```bash
docker-compose up -d
```

### 停止所有服务
```bash
docker-compose down
```

### 查看服务状态
```bash
docker-compose ps
```

### 查看日志
```bash
# 所有服务
docker-compose logs -f

# 特定服务
docker-compose logs -f rust_app
docker-compose logs -f postgres
docker-compose logs -f redis
docker-compose logs -f rabbitmq
```

### 重启服务
```bash
docker-compose restart rust_app
```

### 数据备份

#### PostgreSQL 备份
```bash
docker exec postgres_prod pg_dump -U postgres app_db > backup.sql
```

#### PostgreSQL 恢复
```bash
docker exec -i postgres_prod psql -U postgres app_db < backup.sql
```

#### Redis 备份
```bash
docker exec redis_prod redis-cli --rdb /data/dump.rdb BGSAVE
docker cp redis_prod:/data/dump.rdb ./redis_backup.rdb
```

## 📊 监控

### 查看资源使用
```bash
docker stats
```

### 健康检查
```bash
curl http://localhost:8080/health
```

### RabbitMQ 管理界面
访问: http://localhost:15672
- 用户名: 配置的 RABBITMQ_USER
- 密码: 配置的 RABBITMQ_PASSWORD

## 🔒 生产环境安全建议

1. **使用强密码**: 确保所有服务使用强密码
2. **限制端口暴露**: 仅暴露必要的端口
3. **启用 SSL/TLS**: 为所有对外服务配置 HTTPS
4. **定期备份**: 设置自动备份策略
5. **监控和日志**: 配置日志收集和监控系统
6. **更新依赖**: 定期更新 Docker 镜像和依赖

## 🔧 性能优化

### PostgreSQL 优化
配置已包含生产环境优化参数：
- 连接池配置
- 内存优化
- 查询性能优化

### Redis 优化
配置包含：
- 最大内存限制
- LRU 缓存策略
- 持久化配置

### RabbitMQ 优化
配置包含：
- 内存限制
- 磁盘空间限制
- 日志级别优化

## 📁 项目结构
```
.
├── docker-compose.yml    # Docker 编排配置
├── Dockerfile           # Rust 应用镜像配置
├── .env                 # 环境变量（需创建）
├── .env.example         # 环境变量示例
├── .dockerignore        # Docker 忽略文件
├── init.sql            # PostgreSQL 初始化脚本
├── nginx.conf          # Nginx 配置
├── deploy.sh           # 部署脚本
└── README.md           # 本文档
```

## 🚨 故障排查

### 服务无法启动
```bash
# 检查日志
docker-compose logs [service_name]

# 检查配置
docker-compose config
```

### 连接问题
```bash
# 测试网络
docker network ls
docker network inspect tt_app_network
```

### 清理和重置
```bash
# 停止并删除容器、网络、卷
docker-compose down -v

# 清理未使用的资源
docker system prune -a
```

## 📝 注意事项

1. 首次部署前必须配置 `.env` 文件
2. 确保主机有足够的资源（建议最少 4GB 内存）
3. 定期监控磁盘空间使用情况
4. 生产环境建议使用 Docker Swarm 或 Kubernetes

## 🆘 支持

如有问题，请检查：
1. 服务日志
2. 环境变量配置
3. 网络连接
4. 资源使用情况