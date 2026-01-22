# HeartSync - CI/CD 和自动部署文档

## 概述

HeartSync 项目现已集成完整的 CI/CD 流程，支持自动化构建、测试、部署到多环境（开发、测试、生产），并提供详细的部署日志和回滚机制。

## 目录结构

```
HeartSync/
├── .github/
│   └── workflows/
│       └── ci-cd.yml          # GitHub Actions CI/CD 配置
├── deploy/
│   ├── deploy.sh              # 原始部署脚本
│   ├── deploy-enhanced.sh     # 增强版部署脚本（推荐）
│   ├── rollback.sh            # 回滚脚本
│   ├── health_check.sh        # 健康检查脚本
│   ├── monitor.sh             # 监控脚本
│   └── *.conf, *.service      # Nginx 和 systemd 配置
├── tests/
│   ├── test_app.py            # 应用测试
│   └── test_config.py         # 配置测试
├── config.py                  # 多环境配置管理
├── .env.example               # 环境变量示例
└── requirements-test.txt      # 测试依赖
```

## 快速开始

### 1. 环境准备

```bash
# 复制环境配置文件
cp .env.example .env.development
cp .env.example .env.staging
cp .env.example .env.production

# 编辑配置文件，填入实际的配置值
```

### 2. 本地测试

```bash
# 安装测试依赖
pip install -r requirements-test.txt

# 运行测试
pytest tests/ -v --cov=. --cov-report=html

# 代码格式检查
black --check .
isort --check-only .

# 代码质量检查
flake8 .
```

### 3. 部署到服务器

#### 方式一：使用增强版部署脚本（推荐）

```bash
# 部署到开发环境
sudo bash deploy/deploy-enhanced.sh development

# 部署到测试环境
sudo bash deploy/deploy-enhanced.sh staging

# 部署到生产环境
sudo bash deploy/deploy-enhanced.sh production
```

#### 方式二：使用 GitHub Actions CI/CD

1. 在 GitHub 仓库设置中配置 Secrets：
   - `DEV_SSH_PRIVATE_KEY`: 开发环境 SSH 私钥
   - `DEV_HOST`: 开发服务器地址
   - `DEV_USER`: 开发服务器用户名
   - `DEV_SSH_PORT`: SSH 端口（默认 22）
   - `DEV_URL`: 开发环境 URL
   - 同样配置 STAGING 和 PROD 相关的 secrets

2. 推送代码到相应分支：
   - `develop` 分支 → 自动部署到开发环境
   - `main` 分支的 PR → 部署到测试环境
   - `main` 分支的 push → 部署到生产环境（需要手动批准）

## CI/CD 流程

### GitHub Actions 工作流

CI/CD 流程包含以下阶段：

1. **代码质量检查** (lint)
   - 代码格式检查 (black, isort)
   - 代码质量检查 (flake8)
   - 类型检查 (mypy)

2. **安全扫描** (security)
   - 依赖安全检查 (safety)
   - 代码安全检查 (bandit)

3. **单元测试** (test)
   - 运行所有测试用例
   - 生成测试覆盖率报告
   - 上传到 Codecov

4. **构建和打包** (build)
   - 创建部署包
   - 生成版本信息
   - 上传构建产物

5. **部署**
   - 开发环境（自动）
   - 测试环境（PR 触发）
   - 生产环境（需要手动批准）

## 部署管理

### 查看部署状态

```bash
# 查看服务状态
sudo bash deploy/deploy-enhanced.sh development status

# 查看所有备份
sudo bash deploy/rollback.sh --list

# 检查当前版本
sudo bash deploy/rollback.sh --check
```

### 回滚操作

```bash
# 列出可用备份
sudo bash deploy/rollback.sh --list

# 回滚到指定备份
sudo bash deploy/rollback.sh --rollback backup_20240122_120000
```

### 监控和健康检查

```bash
# 启动健康检查服务
sudo bash deploy/health_check.sh

# 生成完整监控报告
sudo bash deploy/monitor.sh --all

# 实时监控
sudo bash deploy/monitor.sh --realtime

# 查看访问统计
sudo bash deploy/monitor.sh --stats

# 查看数据库统计
sudo bash deploy/monitor.sh --database

# 查看错误日志
sudo bash deploy/monitor.sh --errors
```

## 多环境配置

### 开发环境 (development)

- 调试模式开启
- SQLite 数据库
- 允许详细日志
- 不使用 HTTPS

### 测试环境 (staging)

- 调试模式关闭
- PostgreSQL 数据库
- 测试数据隔离
- 模拟生产配置

### 生产环境 (production)

- 调试模式关闭
- PostgreSQL 数据库
- HTTPS 强制
- 日志轮转
- 性能优化

## 备份和恢复

### 自动备份

部署脚本会自动创建备份，包括：
- 应用代码
- 数据库文件
- 配置文件

备份保留 7 天，自动清理旧备份。

### 手动备份

```bash
# 创建快速回滚备份
sudo bash deploy/rollback.sh --create-quick
```

### 恢复备份

```bash
# 查看备份列表
sudo bash deploy/rollback.sh --list

# 恢复指定备份
sudo bash deploy/rollback.sh --rollback backup_20240122_120000
```

## 健康检查

应用提供 `/health` 端点用于健康检查：

```bash
curl http://your-server/health
```

响应示例：

```json
{
  "status": "healthy",
  "timestamp": "2024-01-22T12:00:00.000Z",
  "environment": "production",
  "version": "2024.01.22-1"
}
```

健康检查服务会自动：
- 检查 HTTP 服务可用性
- 检查服务状态
- 检查数据库连接
- 检查磁盘和内存使用
- 连续失败时发送告警

## 日志管理

### 应用日志

```bash
# 查看应用日志
tail -f /var/www/heart_sync/logs/app.log

# 查看部署日志
tail -f /var/www/heart_sync/logs/deploy_*.log

# 查看健康检查日志
tail -f /var/www/heart_sync/logs/health_check_*.log
```

### 系统日志

```bash
# 查看 systemd 服务日志
journalctl -u heart_sync -f

# 查看 Nginx 日志
tail -f /var/log/nginx/heart_sync.access.log
tail -f /var/log/nginx/heart_sync.error.log
```

## 故障排除

### 服务无法启动

```bash
# 检查服务状态
systemctl status heart_sync

# 查看详细日志
journalctl -u heart_sync -n 50

# 检查配置文件
cat /var/www/heart_sync/current/.env
```

### 健康检查失败

```bash
# 手动执行健康检查
curl -v http://localhost:5000/health

# 检查数据库
sqlite3 /var/www/heart_sync/current/users.db

# 检查端口监听
netstat -tlnp | grep 5000
```

### 部署失败

```bash
# 查看部署日志
tail -f /var/www/heart_sync/logs/deploy_*.log

# 回滚到上一个版本
sudo bash deploy/rollback.sh --list
sudo bash deploy/rollback.sh --rollback backup_<name>
```

## 安全建议

1. **密钥管理**
   - 使用强随机密钥（`python -c "import secrets; print(secrets.token_hex(32))"`）
   - 不要将密钥提交到代码仓库
   - 使用环境变量或密钥管理服务

2. **SSH 配置**
   - 使用密钥认证，禁用密码登录
   - 限制 SSH 访问 IP
   - 定期更新 SSH 密钥

3. **数据库安全**
   - 使用强密码
   - 定期备份
   - 生产环境使用 PostgreSQL

4. **HTTPS**
   - 生产环境必须使用 HTTPS
   - 使用 Let's Encrypt 免费证书
   - 配置 SSL 自动续期

## 最佳实践

1. **部署前检查**
   - 运行所有测试
   - 检查代码覆盖率
   - 审查代码变更
   - 在测试环境验证

2. **部署策略**
   - 蓝绿部署
   - 金丝雀发布
   - 保持可回滚能力

3. **监控**
   - 定期检查日志
   - 设置告警阈值
   - 监控性能指标

4. **维护**
   - 定期更新依赖
   - 清理旧备份
   - 优化数据库

## 常见问题

**Q: 如何添加新的环境变量？**
A: 编辑对应的 `.env.*` 文件，然后重新部署。

**Q: 如何修改健康检查间隔？**
A: 编辑 `deploy/health_check.sh` 中的 `sleep 60` 参数。

**Q: 如何自定义部署流程？**
A: 编辑 `deploy/deploy-enhanced.sh`，根据需要添加或修改步骤。

**Q: 如何设置 HTTPS？**
A: 使用 Let's Encrypt：`certbot --nginx -d yourdomain.com`

**Q: 如何备份到远程服务器？**
A: 在 `deploy/deploy-enhanced.sh` 的备份函数中添加 rsync 或 scp 命令。

## 支持和反馈

如有问题或建议，请提交 Issue 或 Pull Request。
