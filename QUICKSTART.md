# HeartSync - 快速开始指南

## 一分钟快速启动

### 1. 安装依赖

```bash
pip install -r requirements.txt
```

### 2. 运行应用

```bash
python app.py
```

访问：http://localhost:5000

---

## 完整开发环境设置

### 步骤 1: 环境初始化

```bash
# 克隆项目后
cd HeartSync

# 使用初始化脚本（推荐）
chmod +x scripts/setup_env.sh
bash scripts/setup_env.sh --dev
```

### 步骤 2: 配置环境变量

```bash
# 编辑 .env.development
nano .env.development
```

关键配置项：
```bash
SECRET_KEY=your-secret-key
DATABASE_URL=sqlite:///users.db
DEBUG=True
```

### 步骤 3: 初始化数据库

```bash
source venv/bin/activate  # Windows: venv\Scripts\activate
python -c "from app import app, db, init_db; app.app_context().push(); init_db()"
```

### 步骤 4: 运行测试

```bash
make test
# 或
pytest tests/ -v
```

### 步骤 5: 启动应用

```bash
make run
# 或
python app.py
```

---

## 部署到服务器

### 前提条件

- Ubuntu 18.04+ 或 CentOS 7+
- Root 权限
- SSH 访问
- 已安装 Git（可选）

### 快速部署

```bash
# 1. 上传代码到服务器
scp -r HeartSync user@server:/tmp/

# 2. SSH 登录服务器
ssh user@server

# 3. 进入项目目录
cd /tmp/HeartSync

# 4. 执行部署脚本
sudo bash deploy/deploy-enhanced.sh production
```

### 使用 GitHub Actions 自动部署

1. **配置 Secrets**

在 GitHub 仓库设置中添加：
- `PROD_SSH_PRIVATE_KEY`: 服务器 SSH 私钥
- `PROD_HOST`: 服务器 IP 或域名
- `PROD_USER`: SSH 用户名
- `PROD_SSH_PORT`: SSH 端口（默认 22）
- `PROD_URL`: 应用访问 URL

2. **推送到 main 分支**

```bash
git add .
git commit -m "Update deployment"
git push origin main
```

3. **手动批准生产部署**

在 GitHub Actions 页面找到 "deploy-prod" job，点击 "Approve and deploy"

---

## 常用命令

### 开发

```bash
make install-dev    # 安装开发依赖
make run           # 运行应用
make test          # 运行测试
make lint          # 代码检查
make format        # 代码格式化
```

### 部署

```bash
make deploy        # 部署到开发环境
make deploy-stg    # 部署到测试环境
make deploy-prod   # 部署到生产环境
make rollback      # 查看回滚选项
```

### 监控

```bash
make monitor       # 生成监控报告
bash deploy/monitor.sh --realtime  # 实时监控
bash deploy/health_check.sh       # 健康检查
```

### Docker

```bash
make build        # 构建镜像
make docker-up    # 启动容器
make docker-down  # 停止容器
make docker-logs  # 查看日志
```

---

## 故障排除

### 问题：应用无法启动

```bash
# 检查端口占用
netstat -tlnp | grep 5000

# 检查日志
tail -f logs/app.log

# 检查配置
cat .env.development
```

### 问题：测试失败

```bash
# 安装测试依赖
pip install -r requirements-test.txt

# 查看详细错误
pytest tests/ -v --tb=short
```

### 问题：部署失败

```bash
# 查看部署日志
tail -f /var/www/heart_sync/logs/deploy_*.log

# 检查服务状态
systemctl status heart_sync

# 回滚到上一版本
sudo bash deploy/rollback.sh --list
sudo bash deploy/rollback.sh --rollback backup_<name>
```

### 问题：数据库错误

```bash
# 重新初始化数据库
python -c "from app import app, db; app.app_context().push(); db.drop_all(); db.create_all()"

# 检查数据库文件
ls -la *.db
```

---

## 环境配置说明

### 开发环境 (.env.development)

- 调试模式：开启
- 数据库：SQLite
- 日志级别：DEBUG
- HTTPS：否

### 测试环境 (.env.staging)

- 调试模式：关闭
- 数据库：PostgreSQL（推荐）
- 日志级别：INFO
- HTTPS：可选

### 生产环境 (.env.production)

- 调试模式：关闭
- 数据库：PostgreSQL
- 日志级别：WARNING
- HTTPS：强制
- Session 安全：开启

---

## 下一步

- 📖 阅读完整的部署文档：`DEPLOYMENT.md`
- 📝 查看 API 文档：待添加
- 🎓 学习项目结构：`README.md`
- 🐛 报告问题：提交 Issue

---

## 需要帮助？

1. 查看日志文件
2. 运行健康检查：`curl http://localhost:5000/health`
3. 查看部署日志：`/var/www/heart_sync/logs/`
4. 提交 Issue 或 Pull Request
