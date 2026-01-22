"""
应用测试模块
测试Flask应用的核心功能
"""
import pytest
from app import app, db, init_db
from models import User
import json


@pytest.fixture
def client():
    """创建测试客户端"""
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    app.config['WTF_CSRF_ENABLED'] = False
    
    with app.app_context():
        db.create_all()
        yield app.test_client()
        db.session.remove()
        db.drop_all()


@pytest.fixture
def auth_client(client):
    """创建已认证的测试客户端"""
    # 注册测试用户
    client.post('/register', data={
        'username': 'testuser',
        'email': 'test@example.com',
        'password': 'Test123',
        'confirm_password': 'Test123'
    }, follow_redirects=True)
    
    # 登录
    client.post('/login', data={
        'username': 'testuser',
        'password': 'Test123'
    }, follow_redirects=True)
    
    return client


class TestBasicRoutes:
    """测试基本路由"""
    
    def test_index_redirect_to_login(self, client):
        """测试未登录时主页重定向到登录页"""
        rv = client.get('/')
        assert rv.status_code == 302
        assert '/login' in rv.location
    
    def test_login_page(self, client):
        """测试登录页面访问"""
        rv = client.get('/login')
        assert rv.status_code == 200
        assert b'登录' in rv.data
    
    def test_register_page(self, client):
        """测试注册页面访问"""
        rv = client.get('/register')
        assert rv.status_code == 200
        assert b'注册' in rv.data


class TestRegistration:
    """测试注册功能"""
    
    def test_valid_registration(self, client):
        """测试有效注册"""
        rv = client.post('/register', data={
            'username': 'newuser',
            'email': 'new@example.com',
            'password': 'Password123',
            'confirm_password': 'Password123'
        }, follow_redirects=True)
        
        assert b'注册成功' in rv.data
    
    def test_duplicate_username(self, client):
        """测试重复用户名"""
        # 第一次注册
        client.post('/register', data={
            'username': 'testuser',
            'email': 'test1@example.com',
            'password': 'Password123',
            'confirm_password': 'Password123'
        })
        
        # 第二次尝试相同用户名
        rv = client.post('/register', data={
            'username': 'testuser',
            'email': 'test2@example.com',
            'password': 'Password123',
            'confirm_password': 'Password123'
        })
        
        assert b'用户名已被使用' in rv.data
    
    def test_duplicate_email(self, client):
        """测试重复邮箱"""
        # 第一次注册
        client.post('/register', data={
            'username': 'user1',
            'email': 'test@example.com',
            'password': 'Password123',
            'confirm_password': 'Password123'
        })
        
        # 第二次尝试相同邮箱
        rv = client.post('/register', data={
            'username': 'user2',
            'email': 'test@example.com',
            'password': 'Password123',
            'confirm_password': 'Password123'
        })
        
        assert b'邮箱已被注册' in rv.data
    
    def test_weak_password(self, client):
        """测试弱密码"""
        rv = client.post('/register', data={
            'username': 'weakuser',
            'email': 'weak@example.com',
            'password': '123',  # 过短
            'confirm_password': '123'
        })
        
        assert b'密码长度至少6位' in rv.data
    
    def test_password_mismatch(self, client):
        """测试密码不匹配"""
        rv = client.post('/register', data={
            'username': 'mismatchuser',
            'email': 'mismatch@example.com',
            'password': 'Password123',
            'confirm_password': 'Password456'
        })
        
        assert b'两次密码输入不一致' in rv.data


class TestLogin:
    """测试登录功能"""
    
    def test_valid_login(self, client):
        """测试有效登录"""
        # 先注册
        client.post('/register', data={
            'username': 'loginuser',
            'email': 'login@example.com',
            'password': 'Password123',
            'confirm_password': 'Password123'
        })
        
        # 再登录
        rv = client.post('/login', data={
            'username': 'loginuser',
            'password': 'Password123'
        }, follow_redirects=True)
        
        assert b'欢迎回来' in rv.data
    
    def test_invalid_username(self, client):
        """测试无效用户名"""
        rv = client.post('/login', data={
            'username': 'nonexistent',
            'password': 'Password123'
        })
        
        assert b'用户不存在' in rv.data
    
    def test_invalid_password(self, client):
        """测试无效密码"""
        # 先注册
        client.post('/register', data={
            'username': 'testuser',
            'email': 'test@example.com',
            'password': 'Password123',
            'confirm_password': 'Password123'
        })
        
        # 使用错误密码登录
        rv = client.post('/login', data={
            'username': 'testuser',
            'password': 'WrongPassword'
        })
        
        assert b'密码错误' in rv.data
    
    def test_login_with_email(self, client):
        """测试使用邮箱登录"""
        # 先注册
        client.post('/register', data={
            'username': 'emailuser',
            'email': 'email@example.com',
            'password': 'Password123',
            'confirm_password': 'Password123'
        })
        
        # 使用邮箱登录
        rv = client.post('/login', data={
            'username': 'email@example.com',
            'password': 'Password123'
        }, follow_redirects=True)
        
        assert b'欢迎回来' in rv.data


class TestLogout:
    """测试登出功能"""
    
    def test_logout(self, auth_client):
        """测试登出"""
        rv = auth_client.get('/logout', follow_redirects=True)
        assert b'已成功登出' in rv.data


class TestAPIChecks:
    """测试API检查接口"""
    
    def test_check_username_available(self, client):
        """测试检查用户名可用性"""
        rv = client.post('/api/check-username', 
                        json={'username': 'newusername'})
        data = json.loads(rv.data)
        assert data['available'] == True
    
    def test_check_username_taken(self, client):
        """测试检查已占用用户名"""
        # 先注册
        client.post('/register', data={
            'username': 'taken',
            'email': 'taken@example.com',
            'password': 'Password123',
            'confirm_password': 'Password123'
        })
        
        # 检查
        rv = client.post('/api/check-username',
                        json={'username': 'taken'})
        data = json.loads(rv.data)
        assert data['available'] == False
    
    def test_check_email_available(self, client):
        """测试检查邮箱可用性"""
        rv = client.post('/api/check-email',
                        json={'email': 'newemail@example.com'})
        data = json.loads(rv.data)
        assert data['available'] == True
    
    def test_check_email_taken(self, client):
        """测试检查已占用邮箱"""
        # 先注册
        client.post('/register', data={
            'username': 'user1',
            'email': 'takenemail@example.com',
            'password': 'Password123',
            'confirm_password': 'Password123'
        })
        
        # 检查
        rv = client.post('/api/check-email',
                        json={'email': 'takenemail@example.com'})
        data = json.loads(rv.data)
        assert data['available'] == False


class TestHealthCheck:
    """测试健康检查端点"""
    
    def test_health_endpoint(self, client):
        """测试健康检查端点"""
        rv = client.get('/health')
        assert rv.status_code == 200
        data = json.loads(rv.data)
        assert 'status' in data


class TestUserModel:
    """测试用户模型"""
    
    def test_user_creation(self, client):
        """测试用户创建"""
        user = User(
            username='modeluser',
            email='model@example.com',
            nickname='Model User'
        )
        user.set_password('Password123')
        
        assert user.username == 'modeluser'
        assert user.email == 'model@example.com'
        assert user.check_password('Password123') == True
        assert user.check_password('WrongPassword') == False
    
    def test_user_to_dict(self, client):
        """测试用户序列化"""
        user = User(
            username='dictuser',
            email='dict@example.com',
            nickname='Dict User'
        )
        user.set_password('Password123')
        
        user_dict = user.to_dict()
        assert 'id' in user_dict
        assert 'username' in user_dict
        assert 'email' in user_dict
        assert 'password_hash' not in user_dict  # 密码不应该被序列化
