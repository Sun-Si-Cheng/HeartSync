from flask_wtf import FlaskForm
from wtforms import StringField, PasswordField, BooleanField, SubmitField
from wtforms.validators import DataRequired, Length, Email, EqualTo, ValidationError, Regexp
import re

class RegistrationForm(FlaskForm):
    """注册表单"""
    username = StringField('用户名', 
                          validators=[DataRequired(message='用户名不能为空'),
                                    Length(min=3, max=20, message='用户名长度必须在3-20位之间'),
                                    Regexp(r'^[a-zA-Z0-9_\u4e00-\u9fa5]+$', 
                                          message='用户名只能包含字母、数字、下划线和中文')])
    email = StringField('邮箱',
                       validators=[DataRequired(message='邮箱不能为空'),
                                  Email(message='邮箱格式不正确')])
    password = PasswordField('密码',
                            validators=[DataRequired(message='密码不能为空'),
                                      Length(min=6, message='密码长度至少6位')])
    confirm_password = PasswordField('确认密码',
                                   validators=[DataRequired(message='请确认密码'),
                                              EqualTo('password', message='两次密码输入不一致')])
    submit = SubmitField('注册')
    
    def validate_username(self, username):
        """验证用户名是否已被使用"""
        from models import User
        user = User.query.filter_by(username=username.data).first()
        if user:
            raise ValidationError('用户名已被使用')
    
    def validate_email(self, email):
        """验证邮箱是否已被注册"""
        from models import User
        user = User.query.filter_by(email=email.data).first()
        if user:
            raise ValidationError('邮箱已被注册')
    
    def validate_password(self, password):
        """验证密码强度"""
        if len(password.data) < 6:
            raise ValidationError('密码长度至少6位')
        if not re.search(r'[A-Za-z]', password.data):
            raise ValidationError('密码必须包含字母')
        if not re.search(r'[0-9]', password.data):
            raise ValidationError('密码必须包含数字')

class LoginForm(FlaskForm):
    """登录表单"""
    username = StringField('用户名/邮箱',
                         validators=[DataRequired(message='请输入用户名或邮箱')])
    password = PasswordField('密码',
                           validators=[DataRequired(message='请输入密码')])
    remember = BooleanField('记住我')
    submit = SubmitField('登录')
