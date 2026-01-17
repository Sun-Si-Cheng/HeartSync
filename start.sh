#!/bin/bash

# 双人协作爱心网页 - Linux/Mac启动脚本

echo "========================================"
echo "  双人协作爱心网页 - 启动中..."
echo "========================================"
echo ""

# 检查Python版本
if ! command -v python3 &> /dev/null; then
    echo "错误: 未找到Python3，请先安装Python3"
    exit 1
fi

# 检查是否存在虚拟环境
if [ ! -d "venv" ]; then
    echo "[1/4] 创建虚拟环境..."
    python3 -m venv venv
    echo "[OK] 虚拟环境已创建"
else
    echo "[1/4] 虚拟环境已存在"
fi

# 激活虚拟环境
echo "[2/4] 激活虚拟环境..."
source venv/bin/activate

# 安装依赖
echo "[3/4] 检查依赖..."
pip install -r requirements.txt --quiet

# 初始化数据库
echo "[4/4] 初始化数据库..."
if [ ! -f "users.db" ]; then
    python3 -c "from app import init_db; init_db()"
    echo "[OK] 数据库已初始化"
else
    echo "[OK] 数据库已存在"
fi

echo ""
echo "========================================"
echo "  启动成功！"
echo "========================================"
echo ""
echo "访问地址: http://localhost:5000"
echo "按 Ctrl+C 停止服务器"
echo ""

# 启动应用
python app.py
