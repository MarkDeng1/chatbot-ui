# MentalShield 数据库重构文档

## 概述

本次数据库重构完成了以下目标：
1. ✅ 创建完整的用户信息和表单系统
2. ✅ 建立管理员账户系统，支持登录查看用户进度
3. ✅ 优化数据库结构和性能
4. ✅ 确保所有功能正常运转

## 数据库结构

### 核心表结构

#### 1. 用户相关表
- **`profiles`** - 用户档案信息
- **`auth.users`** - Supabase 用户认证表（自动管理）

#### 2. 表单和进度表
- **`emoji_surveys`** - 情绪调查表单数据
- **`user_daily_progress`** - 用户每日进度统计

#### 3. 管理员系统表
- **`admins`** - 管理员账户信息
- **`admin_sessions`** - 管理员会话管理

#### 4. 其他业务表
- **`chats`** - 聊天记录
- **`messages`** - 消息内容
- **`workspaces`** - 工作空间
- **`presets`** - 预设配置
- **`prompts`** - 提示词
- **`collections`** - 收藏集
- **`files`** - 文件管理
- **`tools`** - 工具集成

## 新增功能

### 1. 管理员系统
- 独立的管理员认证系统
- 会话管理和权限控制
- 可查看所有用户数据和进度
- 支持多个管理员账户

### 2. 表单系统增强
- **必填调查** (`daily_required`): 每天最多3个
- **自愿调查** (`extra_voluntary`): 无限制
- 自动进度统计和更新
- 情绪评分范围：1-5分

### 3. 数据分析视图
- `user_emotion_trends` - 用户情绪趋势分析
- `user_activity_stats` - 用户活跃度统计
- `admin_user_statistics` - 管理员专用统计视图

### 4. 高级功能函数
- `get_user_survey_completion()` - 获取用户表单完成度
- `get_user_recent_emotions()` - 获取用户最近情绪数据
- `get_admin_user_details()` - 管理员获取用户详情
- `get_admin_dashboard_stats()` - 管理员仪表板统计

## 数据库部署步骤

### 方法一：完整重置（推荐用于开发环境）

1. **运行重置脚本**
   ```sql
   -- 在 Supabase SQL 编辑器中运行
   \i reset_and_apply_database.sql
   ```

2. **应用种子数据**
   ```sql
   \i seed.sql
   ```

3. **验证功能**
   ```sql
   \i test_database.sql
   ```

### 方法二：增量迁移（推荐用于生产环境）

按顺序运行以下迁移文件：

1. `20241227000000_add_emoji_surveys.sql` - 表单系统
2. `20241227000001_add_admin_system.sql` - 管理员系统
3. `20241227000002_enhance_user_data.sql` - 数据增强
4. `20241227000003_admin_access_policies.sql` - 权限策略

## 预设账户信息

### 管理员账户
- **邮箱**: `admin@mentalshield.com`
- **密码**: `admin123`
- **权限**: 系统管理员

- **邮箱**: `manager@mentalshield.com`
- **密码**: `admin123`
- **权限**: 项目管理员

### 测试用户账户
- **用户1**: `user1@example.com` / `password123`
  - 用户名: `alice_chen`
  - 显示名: 陈小丽
  - 角色: 大学生

- **用户2**: `user2@example.com` / `password123`
  - 用户名: `bob_wang`
  - 显示名: 王小明
  - 角色: 软件工程师

- **用户3**: `user3@example.com` / `password123`
  - 用户名: `carol_li`
  - 显示名: 李小红
  - 角色: 心理咨询师

## 数据示例

### 表单数据特点
- 每个用户都有过去7天的表单数据
- 包含必填和自愿两种类型的调查
- 情绪评分体现不同用户的心理状态差异
- 自动生成对应的进度统计

### 聊天数据特点
- 包含真实的心理健康对话内容
- 展示AI助手如何提供支持性建议
- 涵盖学习压力、工作焦虑等常见话题

## API 集成

### 管理员 API 使用
前端管理员界面通过以下 API 端点访问数据：

- `POST /api/admin/auth` - 管理员登录验证
- `GET /api/admin/users` - 获取所有用户数据和统计
- `GET /api/admin/dashboard` - 获取仪表板统计信息

### 用户表单 API
- `POST /api/emoji-survey` - 提交情绪调查表单
- `GET /api/user/progress` - 获取用户进度信息

## 安全特性

### Row Level Security (RLS)
- 所有表都启用了 RLS 策略
- 用户只能访问自己的数据
- 管理员可以访问所有用户数据
- 基于会话变量进行权限验证

### 数据验证
- 情绪评分限制在 1-5 范围内
- 文本长度限制防止恶意输入
- 外键约束确保数据完整性
- 自动时间戳和更新追踪

## 性能优化

### 索引策略
- 用户ID和日期的复合索引
- 情绪评分和调查类型的专用索引
- 管理员会话的快速查找索引

### 查询优化
- 使用视图预计算复杂统计
- 触发器自动维护聚合数据
- 批量操作减少数据库负载

## 监控和维护

### 数据完整性检查
运行 `SELECT * FROM check_data_integrity();` 来检查：
- 孤立的档案记录
- 缺失的用户档案
- 无效的评分数据
- 进度统计异常

### 定期清理
- 管理员会话自动过期清理
- 历史数据归档策略
- 日志文件轮转

## 故障排除

### 常见问题

1. **管理员无法登录**
   - 检查密码哈希是否正确
   - 验证管理员账户是否激活
   - 确认 RLS 策略是否正确设置

2. **用户进度不更新**
   - 检查触发器是否正常工作
   - 验证表单数据是否正确插入
   - 确认用户ID格式是否有效

3. **权限访问问题**
   - 验证 RLS 策略配置
   - 检查管理员会话设置
   - 确认函数安全设置

### 调试命令

```sql
-- 检查管理员状态
SELECT is_admin();

-- 查看当前会话设置
SELECT current_setting('app.current_admin_email', true);

-- 检查表单统计
SELECT survey_type, COUNT(*) FROM emoji_surveys GROUP BY survey_type;

-- 验证进度同步
SELECT 
    es.user_id,
    COUNT(es.*) as surveys,
    MAX(udp.required_surveys_completed) as progress
FROM emoji_surveys es
LEFT JOIN user_daily_progress udp ON es.user_id = udp.user_id 
    AND es.session_date = udp.session_date
WHERE es.survey_type = 'daily_required'
GROUP BY es.user_id;
```

## 更新日志

### v1.0.0 (2024-12-27)
- ✅ 完整的数据库结构重构
- ✅ 管理员系统实现
- ✅ 表单系统增强
- ✅ 用户进度跟踪
- ✅ 权限管理和安全策略
- ✅ 性能优化和索引
- ✅ 测试数据和文档

---

**注意**: 在生产环境中部署前，请务必备份现有数据并在测试环境中验证所有功能。 