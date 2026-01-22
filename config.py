"""
配置管理模块
支持多环境配置（开发、测试、生产）
"""
import os
from pathlib import Path
from dotenv import load_dotenv

# 基础路径
BASE_DIR = Path(__file__).parent


class Config:
    """基础配置类"""
    
    # Flask基础配置
    SECRET_KEY = os.getenv('SECRET_KEY', 'dev-secret-key-change-in-production')
    DEBUG = os.getenv('DEBUG', 'False').lower() == 'true'
    
    # 数据库配置
    SQLALCHEMY_DATABASE_URI = os.getenv('DATABASE_URL', 'sqlite:///users.db')
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    
    # 服务器配置
    HOST = os.getenv('HOST', '0.0.0.0')
    PORT = int(os.getenv('PORT', 5000))
    
    # 日志配置
    LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
    LOG_DIR = BASE_DIR / 'logs'
    LOG_FILE = os.getenv('LOG_FILE', str(LOG_DIR / 'app.log'))
    
    # 会话配置
    SESSION_COOKIE_SECURE = os.getenv('SESSION_COOKIE_SECURE', 'False').lower() == 'true'
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SAMESITE = 'Lax'
    
    # CORS配置
    CORS_ALLOWED_ORIGINS = os.getenv('CORS_ALLOWED_ORIGINS', '*').split(',')
    
    # SocketIO配置
    SOCKETIO_ASYNC_MODE = os.getenv('SOCKETIO_ASYNC_MODE', 'eventlet')
    SOCKETIO_CORS_ALLOWED_ORIGINS = os.getenv('CORS_ALLOWED_ORIGINS', '*')
    
    # 部署相关
    APP_ENV = os.getenv('APP_ENV', 'development')
    
    # 备份配置
    BACKUP_ENABLED = os.getenv('BACKUP_ENABLED', 'True').lower() == 'true'
    BACKUP_RETENTION_DAYS = int(os.getenv('BACKUP_RETENTION_DAYS', 7))
    BACKUP_PATH = Path(os.getenv('BACKUP_PATH', str(BASE_DIR / 'backup')))
    
    # 健康检查
    HEALTH_CHECK_ENABLED = os.getenv('HEALTH_CHECK_ENABLED', 'True').lower() == 'true'
    
    @staticmethod
    def init_app(app):
        """初始化应用配置"""
        # 确保必要的目录存在
        Config.LOG_DIR.mkdir(parents=True, exist_ok=True)
        Config.BACKUP_PATH.mkdir(parents=True, exist_ok=True)


class DevelopmentConfig(Config):
    """开发环境配置"""
    DEBUG = True
    TESTING = False
    SESSION_COOKIE_SECURE = False


class StagingConfig(Config):
    """测试环境配置"""
    DEBUG = False
    TESTING = True
    SESSION_COOKIE_SECURE = False


class ProductionConfig(Config):
    """生产环境配置"""
    DEBUG = False
    TESTING = False
    SESSION_COOKIE_SECURE = True
    
    # 生产环境强制HTTPS
    PREFERRED_URL_SCHEME = 'https'
    
    @staticmethod
    def init_app(app):
        Config.init_app(app)
        # 生产环境额外配置
        import logging
        from logging.handlers import RotatingFileHandler
        
        # 配置日志轮转
        handler = RotatingFileHandler(
            Config.LOG_FILE,
            maxBytes=10485760,  # 10MB
            backupCount=10
        )
        handler.setLevel(getattr(logging, Config.LOG_LEVEL))
        formatter = logging.Formatter(
            '%(asctime)s %(levelname)s: %(message)s [in %(pathname)s:%(lineno)d]'
        )
        handler.setFormatter(formatter)
        app.logger.addHandler(handler)
        app.logger.setLevel(getattr(logging, Config.LOG_LEVEL))


# 配置字典
config = {
    'development': DevelopmentConfig,
    'staging': StagingConfig,
    'production': ProductionConfig,
    'default': DevelopmentConfig
}


def load_config(env=None):
    """加载指定环境的配置"""
    if env is None:
        # 从环境变量或.env文件读取
        env = os.getenv('APP_ENV', 'development')
        
        # 尝试加载对应的.env文件
        env_file = BASE_DIR / f'.env.{env}'
        if env_file.exists():
            load_dotenv(env_file)
        else:
            # 回退到.env文件
            load_dotenv(BASE_DIR / '.env')
    
    return config.get(env, config['default'])
