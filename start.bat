@echo off
REM 双人协作爱心网页 - Windows启动脚本

echo ========================================
echo   双人协作爱心网页 - 启动中...
echo ========================================
echo.

REM 检查是否存在虚拟环境
if not exist "venv" (
    echo [1/4] 创建虚拟环境...
    python -m venv venv
    echo [OK] 虚拟环境已创建
) else (
    echo [1/4] 虚拟环境已存在
)

REM 激活虚拟环境
echo [2/4] 激活虚拟环境...
call venv\Scripts\activate.bat

REM 安装依赖
echo [3/4] 检查依赖...
pip install -r requirements.txt --quiet

REM 初始化数据库
echo [4/4] 初始化数据库...
if not exist "users.db" (
    python -c "from app import init_db; init_db()"
    echo [OK] 数据库已初始化
) else (
    echo [OK] 数据库已存在
)

echo.
echo ========================================
echo   启动成功！
echo ========================================
echo.
echo 访问地址: http://localhost:5000
echo 按 Ctrl+C 停止服务器
echo.

REM 启动应用
python app.py

pause
