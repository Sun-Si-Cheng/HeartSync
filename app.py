from flask import Flask, render_template, request, redirect, url_for, flash, jsonify, session
from flask_login import LoginManager, login_user, logout_user, login_required, current_user
from flask_socketio import SocketIO, join_room, leave_room, emit
from werkzeug.security import generate_password_hash
import secrets
import re
from datetime import datetime
from models import db, User
from forms import RegistrationForm, LoginForm

app = Flask(__name__)
app.config['SECRET_KEY'] = secrets.token_hex(32)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///users.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# 初始化数据库
db.init_app(app)

# 初始化SocketIO
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='eventlet')

# 初始化Flask-Login
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'
login_manager.login_message = '请先登录'

@login_manager.user_loader
def load_user(user_id):
    """加载用户"""
    return User.query.get(int(user_id))

# 内存存储房间状态（可替换为Redis）
rooms_state = {}

# 预设配对指令组（可扩展为数据库存储）
PRESET_PAIRS = [
    {'pair': ['心动', '信号'], 'description': '心动信号'},
    {'pair': ['我', '你'], 'description': '我和你'},
    {'pair': ['爱', '你'], 'description': '爱你'},
    {'pair': ['喜欢', '你'], 'description': '喜欢你'},
    {'pair': ['想', '你'], 'description': '想你'},
    {'pair': ['宝贝', '宝贝'], 'description': '宝贝'},
]

def generate_room_code():
    """生成6位随机房间码"""
    return ''.join(secrets.choice('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789') for _ in range(6))

def get_or_create_room(room_code):
    """获取或创建房间"""
    if room_code not in rooms_state:
        rooms_state[room_code] = {
            'user1': None,
            'user2': None,
            'user1_command': '',
            'user2_command': '',
            'user1_username': None,
            'user2_username': None,
            'status': 'waiting',  # waiting, matched
            'created_at': datetime.utcnow()
        }
    return rooms_state[room_code]

def validate_password_strength(password):
    """验证密码强度"""
    if len(password) < 6:
        return False, '密码长度至少6位'
    if not re.search(r'[A-Za-z]', password):
        return False, '密码必须包含字母'
    if not re.search(r'[0-9]', password):
        return False, '密码必须包含数字'
    return True, '密码强度符合要求'

def check_match(command1, command2):
    """检查两个指令是否匹配"""
    for pair in PRESET_PAIRS:
        if set([command1, command2]) == set(pair['pair']):
            return True, pair['description']
    return False, None

# ============ HTTP路由 ============

@app.route('/')
def index():
    """主页 - 重定向到登录或协作页面"""
    if current_user.is_authenticated:
        room_code = request.args.get('room', generate_room_code())
        return redirect(url_for('collaborate', room=room_code))
    return redirect(url_for('login'))

@app.route('/register', methods=['GET', 'POST'])
def register():
    """用户注册"""
    if current_user.is_authenticated:
        return redirect(url_for('index'))
    
    form = RegistrationForm()
    
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        email = request.form.get('email', '').strip()
        password = request.form.get('password', '').strip()
        confirm_password = request.form.get('confirm_password', '').strip()
        
        # 服务器端验证
        errors = []
        
        if not username:
            errors.append('用户名不能为空')
        elif len(username) < 3 or len(username) > 20:
            errors.append('用户名长度必须在3-20位之间')
        elif not re.match(r'^[a-zA-Z0-9_\u4e00-\u9fa5]+$', username):
            errors.append('用户名只能包含字母、数字、下划线和中文')
        elif User.query.filter_by(username=username).first():
            errors.append('用户名已被使用')
        
        if not email:
            errors.append('邮箱不能为空')
        elif User.query.filter_by(email=email).first():
            errors.append('邮箱已被注册')
        
        if not password:
            errors.append('密码不能为空')
        else:
            valid, msg = validate_password_strength(password)
            if not valid:
                errors.append(msg)
        
        if password != confirm_password:
            errors.append('两次密码输入不一致')
        
        if errors:
            for error in errors:
                flash(error, 'error')
            return render_template('register.html', form=form)
        
        # 创建用户
        user = User(
            username=username,
            email=email,
            nickname=username
        )
        user.set_password(password)
        
        try:
            db.session.add(user)
            db.session.commit()
            flash('注册成功！请登录', 'success')
            return redirect(url_for('login'))
        except Exception as e:
            db.session.rollback()
            flash('注册失败，请稍后重试', 'error')
    
    return render_template('register.html', form=form)

@app.route('/login', methods=['GET', 'POST'])
def login():
    """用户登录"""
    if current_user.is_authenticated:
        return redirect(url_for('index'))
    
    form = LoginForm()
    
    if request.method == 'POST':
        username_or_email = request.form.get('username', '').strip()
        password = request.form.get('password', '').strip()
        remember = request.form.get('remember', False)
        
        # 查找用户（通过用户名或邮箱）
        user = User.query.filter(
            (User.username == username_or_email) | (User.email == username_or_email)
        ).first()
        
        if not user:
            flash('用户不存在', 'error')
        elif not user.is_active:
            flash('账户已被禁用', 'error')
        elif not user.check_password(password):
            flash('密码错误', 'error')
        else:
            # 登录成功
            user.update_last_login()
            login_user(user, remember=remember)
            flash(f'欢迎回来，{user.nickname}！', 'success')
            
            # 重定向到之前访问的页面或主页
            next_page = request.args.get('next')
            if next_page:
                return redirect(next_page)
            return redirect(url_for('index'))
    
    return render_template('login.html', form=form)

@app.route('/logout')
@login_required
def logout():
    """用户登出"""
    logout_user()
    flash('已成功登出', 'success')
    return redirect(url_for('login'))

@app.route('/collaborate')
@login_required
def collaborate():
    """协作页面"""
    room_code = request.args.get('room', generate_room_code())
    room = get_or_create_room(room_code)
    
    return render_template('index.html', 
                          room_code=room_code,
                          current_user=current_user,
                          preset_pairs=PRESET_PAIRS)

@app.route('/api/check-username', methods=['POST'])
def check_username():
    """检查用户名是否可用"""
    username = request.json.get('username', '').strip()
    if not username:
        return jsonify({'available': False, 'message': '用户名不能为空'})
    
    if User.query.filter_by(username=username).first():
        return jsonify({'available': False, 'message': '用户名已被使用'})
    
    return jsonify({'available': True, 'message': '用户名可用'})

@app.route('/api/check-email', methods=['POST'])
def check_email():
    """检查邮箱是否可用"""
    email = request.json.get('email', '').strip()
    if not email:
        return jsonify({'available': False, 'message': '邮箱不能为空'})
    
    if User.query.filter_by(email=email).first():
        return jsonify({'available': False, 'message': '邮箱已被注册'})
    
    return jsonify({'available': True, 'message': '邮箱可用'})

# ============ SocketIO事件 ============

@socketio.on('connect')
def handle_connect():
    """客户端连接"""
    if current_user.is_authenticated:
        emit('connected', {'username': current_user.nickname})

@socketio.on('disconnect')
def handle_disconnect():
    """客户端断开连接"""
    pass

@socketio.on('join_room')
def handle_join_room(data):
    """加入房间"""
    room_code = data.get('room_code')
    if not room_code:
        return
    
    # 将客户端加入SocketIO房间
    join_room(room_code)
    
    # 更新房间状态
    room = get_or_create_room(room_code)
    
    # 分配用户角色
    if room['user1'] is None or room['user1'] == current_user.id:
        room['user1'] = current_user.id
        room['user1_username'] = current_user.nickname
        user_role = 'user1'
    elif room['user2'] is None or room['user2'] == current_user.id:
        room['user2'] = current_user.id
        room['user2_username'] = current_user.nickname
        user_role = 'user2'
    else:
        # 房间已满，创建新房间
        new_room_code = generate_room_code()
        room = get_or_create_room(new_room_code)
        room['user1'] = current_user.id
        room['user1_username'] = current_user.nickname
        room_code = new_room_code
        user_role = 'user1'
        join_room(room_code)
    
    # 通知房间内其他用户
    emit('user_joined', {
        'username': current_user.nickname,
        'room_code': room_code,
        'user_role': user_role
    }, room=room_code, include_self=False)
    
    # 向当前用户返回房间信息
    emit('room_info', {
        'room_code': room_code,
        'user_role': user_role,
        'user1_username': room['user1_username'],
        'user2_username': room['user2_username'],
        'user1_command': room['user1_command'],
        'user2_command': room['user2_command'],
        'status': room['status']
    })

@socketio.on('submit_command')
def handle_submit_command(data):
    """提交指令"""
    room_code = data.get('room_code')
    command = data.get('command', '').strip()
    user_role = data.get('user_role')
    
    if not room_code or not command or not user_role:
        return
    
    room = get_or_create_room(room_code)
    
    # 更新指令
    if user_role == 'user1':
        room['user1_command'] = command
    else:
        room['user2_command'] = command
    
    # 广播指令更新
    emit('command_updated', {
        'user_role': user_role,
        'command': command,
        'user1_username': room['user1_username'],
        'user2_username': room['user2_username'],
        'user1_command': room['user1_command'],
        'user2_command': room['user2_command']
    }, room=room_code)
    
    # 检查匹配
    if room['user1_command'] and room['user2_command']:
        is_match, description = check_match(room['user1_command'], room['user2_command'])
        
        if is_match:
            room['status'] = 'matched'
            # 清空指令以便下次使用
            room['user1_command'] = ''
            room['user2_command'] = ''
            
            emit('match_success', {
                'description': description,
                'command_pair': [room['user1_command'], room['user2_command']],
                'user1_username': room['user1_username'],
                'user2_username': room['user2_username'],
                'timestamp': datetime.utcnow().isoformat()
            }, room=room_code)
        else:
            emit('match_failed', {
                'message': '指令不匹配，请重新输入',
                'user1_command': room['user1_command'],
                'user2_command': room['user2_command']
            }, room=room_code)

@socketio.on('leave_room')
def handle_leave_room(data):
    """离开房间"""
    room_code = data.get('room_code')
    if room_code:
        leave_room(room_code)
        # 可选：从房间状态中移除用户
        room = rooms_state.get(room_code)
        if room:
            if room['user1'] == current_user.id:
                room['user1'] = None
                room['user1_command'] = ''
                room['user1_username'] = None
            elif room['user2'] == current_user.id:
                room['user2'] = None
                room['user2_command'] = ''
                room['user2_username'] = None

# ============ 错误处理 ============

@app.errorhandler(404)
def not_found(error):
    return render_template('404.html'), 404

@app.errorhandler(500)
def internal_error(error):
    db.session.rollback()
    return render_template('500.html'), 500

# ============ 初始化数据库 ============

def init_db():
    """初始化数据库"""
    with app.app_context():
        db.create_all()
        print('数据库初始化完成')

if __name__ == '__main__':
    init_db()
    socketio.run(app, debug=True, host='0.0.0.0', port=5000)
