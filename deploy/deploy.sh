#!/bin/bash

# 双人协作爱心网页 - 自动部署脚本
# 用途：自动化部署Flask应用到Linux服务器

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置变量（根据实际情况修改）
PROJECT_NAME="love-collaboration"
PROJECT_DIR="/var/www/${PROJECT_NAME}"
VENV_DIR="${PROJECT_DIR}/venv"
SERVICE_NAME="${PROJECT_NAME}"
NGINX_CONF="/etc/nginx/sites-available/${PROJECT_NAME}"
GIT_REPO=""  # 如果使用Git部署，填写仓库地址

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  双人协作爱心网页 - 自动部署脚本${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}请使用root权限运行此脚本${NC}"
    echo "使用命令: sudo bash deploy.sh"
    exit 1
fi

# 1. 更新系统包
echo -e "${YELLOW}[1/8] 更新系统包...${NC}"
apt-get update -y
apt-get upgrade -y

# 2. 安装系统依赖
echo -e "${YELLOW}[2/8] 安装系统依赖...${NC}"
apt-get install -y python3 python3-pip python3-venv nginx git sqlite3 supervisor

# 3. 创建项目目录
echo -e "${YELLOW}[3/8] 创建项目目录...${NC}"
mkdir -p ${PROJECT_DIR}
mkdir -p ${PROJECT_DIR}/logs
mkdir -p ${PROJECT_DIR}/backup

# 4. 复制项目文件
echo -e "${YELLOW}[4/8] 复制项目文件...${NC}"
if [ -d "./" ]; then
    cp -r ./* ${PROJECT_DIR}/
    echo -e "${GREEN}✓ 项目文件已复制${NC}"
elif [ -n "$GIT_REPO" ]; then
    git clone $GIT_REPO ${PROJECT_DIR}
    echo -e "${GREEN}✓ 项目已从Git克隆${NC}"
else
    echo -e "${RED}错误: 找不到项目文件或未配置Git仓库${NC}"
    exit 1
fi

# 5. 创建Python虚拟环境
echo -e "${YELLOW}[5/8] 创建Python虚拟环境...${NC}"
if [ ! -d "${VENV_DIR}" ]; then
    python3 -m venv ${VENV_DIR}
    echo -e "${GREEN}✓ 虚拟环境已创建${NC}"
else
    echo -e "${GREEN}✓ 虚拟环境已存在${NC}"
fi

# 6. 安装Python依赖
echo -e "${YELLOW}[6/8] 安装Python依赖...${NC}"
source ${VENV_DIR}/bin/activate
pip install --upgrade pip
pip install -r ${PROJECT_DIR}/requirements.txt
echo -e "${GREEN}✓ Python依赖已安装${NC}"

# 7. 初始化数据库
echo -e "${YELLOW}[7/8] 初始化数据库...${NC}"
cd ${PROJECT_DIR}
export FLASK_APP=app.py
python -c "from app import app, db, init_db; init_db()"
echo -e "${GREEN}✓ 数据库已初始化${NC}"

# 8. 设置文件权限
echo -e "${YELLOW}[8/8] 设置文件权限...${NC}"
chown -R www-data:www-data ${PROJECT_DIR}
chmod -R 755 ${PROJECT_DIR}
chmod 644 ${PROJECT_DIR}/users.db
echo -e "${GREEN}✓ 文件权限已设置${NC}"

# 9. 配置systemd服务
echo -e "${YELLOW}[9/10] 配置systemd服务...${NC}"
# 读取服务文件并替换路径
sed "s|/path/to/your/project|${PROJECT_DIR}|g" \
    ${PROJECT_DIR}/deploy/love-collaboration.service > \
    /etc/systemd/system/${SERVICE_NAME}.service

sed -i "s|/path/to/your/venv|${VENV_DIR}|g" \
    /etc/systemd/system/${SERVICE_NAME}.service

# 重载systemd并启动服务
systemctl daemon-reload
systemctl enable ${SERVICE_NAME}
systemctl start ${SERVICE_NAME}
echo -e "${GREEN}✓ Systemd服务已配置并启动${NC}"

# 10. 配置Nginx
echo -e "${YELLOW}[10/10] 配置Nginx...${NC}"
# 创建日志目录
mkdir -p /var/log/nginx/${PROJECT_NAME}

# 复制Nginx配置
sed "s|/path/to/your/project|${PROJECT_DIR}|g" \
    ${PROJECT_DIR}/deploy/nginx.conf > ${NGINX_CONF}

# 询问域名
read -p "请输入你的域名或服务器IP（默认：localhost）: " DOMAIN
DOMAIN=${DOMAIN:-localhost}
sed -i "s|your-domain.com|${DOMAIN}|g" ${NGINX_CONF}

# 创建软链接
ln -sf ${NGINX_CONF} /etc/nginx/sites-enabled/${PROJECT_NAME}
rm -f /etc/nginx/sites-enabled/default

# 测试并重启Nginx
nginx -t
systemctl reload nginx
echo -e "${GREEN}✓ Nginx已配置并重启${NC}"

# 11. 配置防火墙
echo -e "${YELLOW}配置防火墙...${NC}"
if command -v ufw &> /dev/null; then
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 5000/tcp
    echo -e "${GREEN}✓ 防火墙规则已添加${NC}"
else
    echo -e "${YELLOW}⚠ 未检测到ufw，请手动配置防火墙${NC}"
fi

# 完成
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  部署完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "服务状态："
systemctl status ${SERVICE_NAME} --no-pager
echo ""
echo "Nginx状态："
systemctl status nginx --no-pager
echo ""
echo -e "${GREEN}访问地址: http://${DOMAIN}${NC}"
echo -e "${GREEN}项目路径: ${PROJECT_DIR}${NC}"
echo -e "${GREEN}日志路径: ${PROJECT_DIR}/logs${NC}"
echo ""
echo "常用命令："
echo "  查看服务状态: systemctl status ${SERVICE_NAME}"
echo "  重启服务: systemctl restart ${SERVICE_NAME}"
echo "  查看日志: journalctl -u ${SERVICE_NAME} -f"
echo "  重启Nginx: systemctl reload nginx"
echo ""
