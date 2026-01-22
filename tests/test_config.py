"""
配置测试模块
测试不同环境配置
"""
import pytest
import os
from config import Config, DevelopmentConfig, StagingConfig, ProductionConfig


class TestConfig:
    """测试基础配置"""
    
    def test_default_config(self):
        """测试默认配置"""
        config = Config()
        assert config.DEBUG == False
        assert config.SQLALCHEMY_TRACK_MODIFICATIONS == False
    
    def test_secret_key(self):
        """测试密钥配置"""
        os.environ['SECRET_KEY'] = 'test-secret'
        config = Config()
        assert config.SECRET_KEY == 'test-secret'


class TestDevelopmentConfig:
    """测试开发环境配置"""
    
    def test_debug_mode(self):
        """测试调试模式"""
        config = DevelopmentConfig()
        assert config.DEBUG == True
        assert config.TESTING == False
        assert config.SESSION_COOKIE_SECURE == False


class TestStagingConfig:
    """测试测试环境配置"""
    
    def test_staging_mode(self):
        """测试测试环境配置"""
        config = StagingConfig()
        assert config.DEBUG == False
        assert config.TESTING == True
        assert config.SESSION_COOKIE_SECURE == False


class TestProductionConfig:
    """测试生产环境配置"""
    
    def test_production_mode(self):
        """测试生产环境配置"""
        config = ProductionConfig()
        assert config.DEBUG == False
        assert config.TESTING == False
        assert config.SESSION_COOKIE_SECURE == True
        assert config.PREFERRED_URL_SCHEME == 'https'


class TestConfigLoader:
    """测试配置加载器"""
    
    def test_load_development_config(self):
        """测试加载开发环境配置"""
        from config import load_config
        config = load_config('development')
        assert isinstance(config, DevelopmentConfig)
    
    def test_load_staging_config(self):
        """测试加载测试环境配置"""
        from config import load_config
        config = load_config('staging')
        assert isinstance(config, StagingConfig)
    
    def test_load_production_config(self):
        """测试加载生产环境配置"""
        from config import load_config
        config = load_config('production')
        assert isinstance(config, ProductionConfig)
    
    def test_load_default_config(self):
        """测试加载默认配置"""
        from config import load_config
        config = load_config('unknown')
        assert isinstance(config, DevelopmentConfig)
