# HeartSync Makefile
# 快捷命令集合

.PHONY: help install install-dev test lint format clean run deploy build docker

# 默认目标
help:
	@echo "HeartSync - 可用命令："
	@echo ""
	@echo "开发命令："
	@echo "  make install       - 安装生产依赖"
	@echo "  make install-dev    - 安装开发依赖"
	@echo "  make run           - 运行应用"
	@echo "  make test          - 运行测试"
	@echo "  make lint          - 代码质量检查"
	@echo "  make format        - 代码格式化"
	@echo ""
	@echo "部署命令："
	@echo "  make deploy        - 部署到开发环境"
	@echo "  make deploy-stg    - 部署到测试环境"
	@echo "  make deploy-prod   - 部署到生产环境"
	@echo "  make rollback      - 查看回滚选项"
	@echo ""
	@echo "Docker 命令："
	@echo "  make build         - 构建 Docker 镜像"
	@echo "  make docker-up     - 启动 Docker 容器"
	@echo "  make docker-down   - 停止 Docker 容器"
	@echo ""
	@echo "其他命令："
	@echo "  make clean         - 清理临时文件"
	@echo "  make monitor       - 运行监控"

# 安装依赖
install:
	pip install --upgrade pip
	pip install -r requirements.txt

# 安装开发依赖
install-dev:
	pip install --upgrade pip
	pip install -r requirements.txt
	pip install -r requirements-test.txt

# 运行应用
run:
	python app.py

# 运行测试
test:
	pytest tests/ -v --cov=. --cov-report=html --cov-report=term-missing

# 测试覆盖率
test-coverage:
	pytest tests/ --cov=. --cov-report=html
	@echo "打开 htmlcov/index.html 查看详细报告"

# 代码质量检查
lint:
	@echo "运行代码质量检查..."
	flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics
	flake8 . --count --exit-zero --max-complexity=10 --max-line-length=127 --statistics
	pylint app.py models.py forms.py config.py || true
	mypy app.py models.py forms.py config.py || true
	@echo "代码质量检查完成"

# 代码格式化
format:
	@echo "格式化代码..."
	black .
	isort .
	@echo "代码格式化完成"

# 格式检查
format-check:
	black --check .
	isort --check-only .

# 安全扫描
security:
	@echo "运行安全扫描..."
	safety check --full-report
	bandit -r . -f json -o bandit-report.json || true
	@echo "安全扫描完成"

# 清理临时文件
clean:
	@echo "清理临时文件..."
	find . -type f -name '*.pyc' -delete
	find . -type d -name '__pycache__' -delete
	find . -type d -name '.pytest_cache' -exec rm -rf {} + || true
	find . -type f -name '.coverage' -delete
	find . -type d -name 'htmlcov' -exec rm -rf {} + || true
	find . -type d -name '*.egg-info' -exec rm -rf {} + || true
	rm -rf build dist .eggs
	@echo "清理完成"

# 部署到开发环境
deploy:
	bash deploy/deploy-enhanced.sh development

# 部署到测试环境
deploy-stg:
	bash deploy/deploy-enhanced.sh staging

# 部署到生产环境
deploy-prod:
	bash deploy/deploy-enhanced.sh production

# 查看回滚选项
rollback:
	bash deploy/rollback.sh --list

# 运行监控
monitor:
	bash deploy/monitor.sh --all

# Docker 构建
build:
	docker build -t heart-sync:latest .

# Docker 启动
docker-up:
	docker-compose up -d

# Docker 停止
docker-down:
	docker-compose down

# Docker 重启
docker-restart:
	docker-compose restart

# Docker 查看日志
docker-logs:
	docker-compose logs -f

# Docker 清理
docker-clean:
	docker-compose down -v
	docker system prune -f

# 数据库迁移
db-upgrade:
	@echo "执行数据库迁移..."
	python -c "from app import app, db; app.app_context().push(); db.create_all()"

# 创建备份
backup:
	bash deploy/deploy-enhanced.sh development backup

# 健康检查
health-check:
	curl -f http://localhost:5000/health || echo "健康检查失败"

# 完整检查（lint + test + security）
check: lint test security
	@echo "所有检查完成！"

# 快速启动（开发环境）
dev:
	@echo "启动开发环境..."
	@make install-dev
	@python app.py
