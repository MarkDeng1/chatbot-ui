-- 管理员系统数据库迁移 - 完整版本

-- 创建管理员表
CREATE TABLE IF NOT EXISTS admins (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT true
);

-- 创建管理员表索引
CREATE INDEX IF NOT EXISTS admins_email_idx ON admins(email);
CREATE INDEX IF NOT EXISTS admins_active_idx ON admins(is_active);

-- 启用RLS
ALTER TABLE admins ENABLE ROW LEVEL SECURITY;

-- 管理员表的RLS策略 - 只有管理员自己能访问自己的数据
CREATE POLICY "Admins can only access their own data" ON admins 
    FOR ALL USING (email = current_setting('app.current_admin_email', true));

-- 添加更新时间触发器
CREATE TRIGGER update_admins_updated_at 
    BEFORE UPDATE ON admins 
    FOR EACH ROW 
    EXECUTE PROCEDURE update_updated_at_column();

-- 创建管理员会话表
CREATE TABLE IF NOT EXISTS admin_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_id UUID NOT NULL REFERENCES admins(id) ON DELETE CASCADE,
    session_token TEXT UNIQUE NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 创建管理员会话表索引
CREATE INDEX IF NOT EXISTS admin_sessions_token_idx ON admin_sessions(session_token);
CREATE INDEX IF NOT EXISTS admin_sessions_admin_id_idx ON admin_sessions(admin_id);
CREATE INDEX IF NOT EXISTS admin_sessions_expires_idx ON admin_sessions(expires_at);

-- 启用RLS
ALTER TABLE admin_sessions ENABLE ROW LEVEL SECURITY;

-- 管理员会话的RLS策略
CREATE POLICY "Admins can only access their own sessions" ON admin_sessions 
    FOR ALL USING (admin_id IN (SELECT id FROM admins WHERE email = current_setting('app.current_admin_email', true)));

-- 创建清理过期会话的函数
CREATE OR REPLACE FUNCTION cleanup_expired_admin_sessions()
RETURNS void AS $$
BEGIN
    DELETE FROM admin_sessions WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- 为管理员添加查看所有用户数据的RLS策略

-- 为profiles表添加管理员访问策略
CREATE POLICY "Allow admin full access to profiles" ON profiles
    FOR ALL TO authenticated
    USING (
        auth.uid() IN (
            SELECT user_id FROM profiles 
            WHERE user_id = auth.uid()
        ) OR
        current_setting('app.current_admin_email', true) IN (
            SELECT email FROM admins WHERE is_active = true
        )
    );

-- 为emoji_surveys表添加管理员访问策略
CREATE POLICY "Allow admin read access to emoji_surveys" ON emoji_surveys
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid() OR
        current_setting('app.current_admin_email', true) IN (
            SELECT email FROM admins WHERE is_active = true
        )
    );

-- 为user_daily_progress表添加管理员访问策略
CREATE POLICY "Allow admin read access to user_daily_progress" ON user_daily_progress
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid() OR
        current_setting('app.current_admin_email', true) IN (
            SELECT email FROM admins WHERE is_active = true
        )
    );

-- 为chats表添加管理员访问策略
CREATE POLICY "Allow admin read access to chats" ON chats
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid() OR
        current_setting('app.current_admin_email', true) IN (
            SELECT email FROM admins WHERE is_active = true
        )
    );

-- 为messages表添加管理员访问策略
CREATE POLICY "Allow admin read access to messages" ON messages
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid() OR
        current_setting('app.current_admin_email', true) IN (
            SELECT email FROM admins WHERE is_active = true
        )
    );

-- 为workspaces表添加管理员访问策略
CREATE POLICY "Allow admin read access to workspaces" ON workspaces
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid() OR
        current_setting('app.current_admin_email', true) IN (
            SELECT email FROM admins WHERE is_active = true
        )
    );

-- 创建管理员专用的查询视图，方便获取用户统计信息
CREATE OR REPLACE VIEW admin_user_statistics AS
SELECT 
    p.user_id,
    p.username,
    p.display_name,
    p.created_at as user_created_at,
    p.has_onboarded,
    -- 统计信息
    COALESCE(survey_stats.total_required_surveys, 0) as total_required_surveys,
    COALESCE(survey_stats.total_extra_surveys, 0) as total_extra_surveys,
    COALESCE(chat_stats.total_chats, 0) as total_chats,
    COALESCE(message_stats.total_messages, 0) as total_messages,
    COALESCE(progress_stats.active_days, 0) as active_days,
    COALESCE(survey_stats.avg_emotion_score, 0) as avg_emotion_score
FROM profiles p
LEFT JOIN (
    SELECT 
        user_id,
        COUNT(CASE WHEN survey_type = 'daily_required' THEN 1 END) as total_required_surveys,
        COUNT(CASE WHEN survey_type = 'extra_voluntary' THEN 1 END) as total_extra_surveys,
        AVG(emotion_score) as avg_emotion_score
    FROM emoji_surveys 
    GROUP BY user_id
) survey_stats ON p.user_id = survey_stats.user_id
LEFT JOIN (
    SELECT user_id, COUNT(*) as total_chats
    FROM chats 
    GROUP BY user_id
) chat_stats ON p.user_id = chat_stats.user_id
LEFT JOIN (
    SELECT user_id, COUNT(*) as total_messages
    FROM messages 
    GROUP BY user_id
) message_stats ON p.user_id = message_stats.user_id
LEFT JOIN (
    SELECT user_id, COUNT(DISTINCT session_date) as active_days
    FROM user_daily_progress 
    GROUP BY user_id
) progress_stats ON p.user_id = progress_stats.user_id;

-- 注意：VIEW不支持RLS，改为使用函数来控制访问权限

-- 创建管理员验证函数
CREATE OR REPLACE FUNCTION verify_admin_access(admin_email TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM admins 
        WHERE email = admin_email AND is_active = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建生成管理员会话令牌的函数
CREATE OR REPLACE FUNCTION create_admin_session(admin_email TEXT, session_duration_hours INTEGER DEFAULT 24)
RETURNS TEXT AS $$
DECLARE
    admin_record admins%ROWTYPE;
    session_token TEXT;
    expires_at TIMESTAMPTZ;
BEGIN
    -- 验证管理员
    SELECT * INTO admin_record FROM admins WHERE email = admin_email AND is_active = true;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Admin not found or inactive';
    END IF;
    
    -- 生成会话令牌
    session_token := encode(gen_random_bytes(32), 'base64');
    expires_at := NOW() + (session_duration_hours || ' hours')::INTERVAL;
    
    -- 插入会话记录
    INSERT INTO admin_sessions (admin_id, session_token, expires_at)
    VALUES (admin_record.id, session_token, expires_at);
    
    RETURN session_token;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建验证管理员会话的函数
CREATE OR REPLACE FUNCTION verify_admin_session(session_token TEXT)
RETURNS TABLE(admin_id UUID, email TEXT, name TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT a.id, a.email, a.name
    FROM admins a
    JOIN admin_sessions s ON a.id = s.admin_id
    WHERE s.session_token = verify_admin_session.session_token
      AND s.expires_at > NOW()
      AND a.is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建定期清理过期会话的任务（需要pg_cron扩展，这里只是示例）
-- SELECT cron.schedule('cleanup-admin-sessions', '0 * * * *', 'SELECT cleanup_expired_admin_sessions();'); 