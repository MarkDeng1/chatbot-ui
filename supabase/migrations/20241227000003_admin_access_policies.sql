-- 管理员访问策略数据库迁移
-- 确保管理员可以查看所有用户数据和进度

-- 删除可能冲突的现有策略
DROP POLICY IF EXISTS "Allow admin full access to profiles" ON profiles;
DROP POLICY IF EXISTS "Allow admin read access to emoji_surveys" ON emoji_surveys;
DROP POLICY IF EXISTS "Allow admin read access to user_daily_progress" ON user_daily_progress;
DROP POLICY IF EXISTS "Allow admin read access to chats" ON chats;
DROP POLICY IF EXISTS "Allow admin read access to messages" ON messages;
DROP POLICY IF EXISTS "Allow admin read access to workspaces" ON workspaces;

-- 创建管理员身份验证函数
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    -- 检查当前用户是否为管理员
    -- 这里使用session变量来标识管理员身份
    RETURN current_setting('app.current_admin_email', true) != '' AND
           current_setting('app.current_admin_email', true) IS NOT NULL AND
           EXISTS (
               SELECT 1 FROM admins 
               WHERE email = current_setting('app.current_admin_email', true) 
                 AND is_active = true
           );
EXCEPTION
    WHEN OTHERS THEN
        RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 为auth.users表添加管理员访问策略（如果可能）
-- 注意：auth.users表通常由Supabase管理，可能无法直接添加策略

-- 为profiles表添加管理员访问策略
CREATE POLICY "Allow users and admins access to profiles" ON profiles
    FOR ALL TO authenticated
    USING (
        user_id = auth.uid() OR is_admin()
    )
    WITH CHECK (
        user_id = auth.uid() OR is_admin()
    );

-- 为emoji_surveys表添加管理员访问策略
CREATE POLICY "Allow users and admins access to emoji_surveys" ON emoji_surveys
    FOR ALL TO authenticated
    USING (
        user_id = auth.uid() OR is_admin()
    )
    WITH CHECK (
        user_id = auth.uid() OR is_admin()
    );

-- 为user_daily_progress表添加管理员访问策略
CREATE POLICY "Allow users and admins access to user_daily_progress" ON user_daily_progress
    FOR ALL TO authenticated
    USING (
        user_id = auth.uid() OR is_admin()
    )
    WITH CHECK (
        user_id = auth.uid() OR is_admin()
    );

-- 为chats表添加管理员访问策略
CREATE POLICY "Allow users and admins access to chats" ON chats
    FOR ALL TO authenticated
    USING (
        user_id = auth.uid() OR is_admin()
    )
    WITH CHECK (
        user_id = auth.uid() OR is_admin()
    );

-- 为messages表添加管理员访问策略
CREATE POLICY "Allow users and admins access to messages" ON messages
    FOR ALL TO authenticated
    USING (
        user_id = auth.uid() OR is_admin()
    )
    WITH CHECK (
        user_id = auth.uid() OR is_admin()
    );

-- 为workspaces表添加管理员访问策略
CREATE POLICY "Allow users and admins access to workspaces" ON workspaces
    FOR ALL TO authenticated
    USING (
        user_id = auth.uid() OR is_admin()
    )
    WITH CHECK (
        user_id = auth.uid() OR is_admin()
    );

-- 为其他相关表添加管理员访问策略
CREATE POLICY "Allow users and admins access to presets" ON presets
    FOR ALL TO authenticated
    USING (
        user_id = auth.uid() OR is_admin()
    )
    WITH CHECK (
        user_id = auth.uid() OR is_admin()
    );

CREATE POLICY "Allow users and admins access to assistants" ON assistants
    FOR ALL TO authenticated
    USING (
        user_id = auth.uid() OR is_admin()
    )
    WITH CHECK (
        user_id = auth.uid() OR is_admin()
    );

CREATE POLICY "Allow users and admins access to prompts" ON prompts
    FOR ALL TO authenticated
    USING (
        user_id = auth.uid() OR is_admin()
    )
    WITH CHECK (
        user_id = auth.uid() OR is_admin()
    );

CREATE POLICY "Allow users and admins access to collections" ON collections
    FOR ALL TO authenticated
    USING (
        user_id = auth.uid() OR is_admin()
    )
    WITH CHECK (
        user_id = auth.uid() OR is_admin()
    );

CREATE POLICY "Allow users and admins access to files" ON files
    FOR ALL TO authenticated
    USING (
        user_id = auth.uid() OR is_admin()
    )
    WITH CHECK (
        user_id = auth.uid() OR is_admin()
    );

CREATE POLICY "Allow users and admins access to folders" ON folders
    FOR ALL TO authenticated
    USING (
        user_id = auth.uid() OR is_admin()
    )
    WITH CHECK (
        user_id = auth.uid() OR is_admin()
    );

CREATE POLICY "Allow users and admins access to tools" ON tools
    FOR ALL TO authenticated
    USING (
        user_id = auth.uid() OR is_admin()
    )
    WITH CHECK (
        user_id = auth.uid() OR is_admin()
    );

-- 注意：VIEW不支持RLS策略，访问控制需要在应用层面实现
-- 或者通过将VIEW转换为安全函数来实现

-- 创建管理员专用的综合查询函数
CREATE OR REPLACE FUNCTION get_all_users_summary()
RETURNS TABLE(
    user_id UUID,
    username TEXT,
    display_name TEXT,
    email TEXT,
    registration_date TIMESTAMPTZ,
    has_onboarded BOOLEAN,
    total_surveys INTEGER,
    total_required_surveys INTEGER,
    total_extra_surveys INTEGER,
    total_chats INTEGER,
    total_messages INTEGER,
    active_days INTEGER,
    avg_emotion_score DECIMAL,
    latest_survey_date DATE,
    latest_activity_date DATE
) AS $$
BEGIN
    -- 只有管理员可以调用此函数
    IF NOT is_admin() THEN
        RAISE EXCEPTION 'Access denied: Admin privileges required';
    END IF;
    
    RETURN QUERY
    SELECT 
        p.user_id,
        p.username,
        p.display_name,
        COALESCE(au.email, p.username || '@example.com') as email,
        p.created_at as registration_date,
        p.has_onboarded,
        COALESCE(survey_stats.total_surveys, 0)::INTEGER,
        COALESCE(survey_stats.required_surveys, 0)::INTEGER,
        COALESCE(survey_stats.extra_surveys, 0)::INTEGER,
        COALESCE(chat_stats.total_chats, 0)::INTEGER,
        COALESCE(message_stats.total_messages, 0)::INTEGER,
        COALESCE(progress_stats.active_days, 0)::INTEGER,
        COALESCE(survey_stats.avg_emotion, 0.0) as avg_emotion_score,
        survey_stats.latest_survey as latest_survey_date,
        GREATEST(
            COALESCE(survey_stats.latest_survey, '1900-01-01'::date),
            COALESCE(chat_stats.latest_chat, '1900-01-01'::date),
            COALESCE(message_stats.latest_message, '1900-01-01'::date)
        ) as latest_activity_date
    FROM profiles p
    LEFT JOIN auth.users au ON p.user_id = au.id
    LEFT JOIN (
        SELECT 
            user_id,
            COUNT(*) as total_surveys,
            COUNT(CASE WHEN survey_type = 'daily_required' THEN 1 END) as required_surveys,
            COUNT(CASE WHEN survey_type = 'extra_voluntary' THEN 1 END) as extra_surveys,
            ROUND(AVG(emotion_score), 2) as avg_emotion,
            MAX(session_date) as latest_survey
        FROM emoji_surveys 
        GROUP BY user_id
    ) survey_stats ON p.user_id = survey_stats.user_id
    LEFT JOIN (
        SELECT 
            user_id, 
            COUNT(*) as total_chats,
            MAX(created_at::date) as latest_chat
        FROM chats 
        GROUP BY user_id
    ) chat_stats ON p.user_id = chat_stats.user_id
    LEFT JOIN (
        SELECT 
            user_id, 
            COUNT(*) as total_messages,
            MAX(created_at::date) as latest_message
        FROM messages 
        GROUP BY user_id
    ) message_stats ON p.user_id = message_stats.user_id
    LEFT JOIN (
        SELECT 
            user_id, 
            COUNT(DISTINCT session_date) as active_days
        FROM user_daily_progress 
        GROUP BY user_id
    ) progress_stats ON p.user_id = progress_stats.user_id
    ORDER BY p.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建获取用户详细进度的管理员函数
CREATE OR REPLACE FUNCTION get_user_progress_details(target_user_id UUID, days_back INTEGER DEFAULT 30)
RETURNS TABLE(
    session_date DATE,
    required_completed INTEGER,
    extra_completed INTEGER,
    completion_rate DECIMAL,
    avg_emotion_score DECIMAL,
    emotion_variance DECIMAL,
    survey_count INTEGER,
    has_notes BOOLEAN
) AS $$
BEGIN
    -- 只有管理员可以调用此函数
    IF NOT is_admin() THEN
        RAISE EXCEPTION 'Access denied: Admin privileges required';
    END IF;
    
    RETURN QUERY
    SELECT 
        udp.session_date,
        udp.required_surveys_completed,
        udp.extra_surveys_completed,
        ROUND((udp.required_surveys_completed * 100.0 / 3), 2) as completion_rate,
        COALESCE(ROUND(AVG(es.emotion_score), 2), 0) as avg_emotion_score,
        COALESCE(ROUND(VARIANCE(es.emotion_score), 2), 0) as emotion_variance,
        COALESCE(COUNT(es.id), 0)::INTEGER as survey_count,
        EXISTS(
            SELECT 1 FROM emoji_surveys es2 
            WHERE es2.user_id = target_user_id 
              AND es2.session_date = udp.session_date 
              AND es2.notes IS NOT NULL 
              AND es2.notes != ''
        ) as has_notes
    FROM user_daily_progress udp
    LEFT JOIN emoji_surveys es ON udp.user_id = es.user_id AND udp.session_date = es.session_date
    WHERE udp.user_id = target_user_id
      AND udp.session_date >= CURRENT_DATE - days_back
    GROUP BY udp.session_date, udp.required_surveys_completed, udp.extra_surveys_completed
    ORDER BY udp.session_date DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建管理员仪表板统计函数
CREATE OR REPLACE FUNCTION get_admin_dashboard_stats()
RETURNS TABLE(
    total_users INTEGER,
    active_users_today INTEGER,
    active_users_week INTEGER,
    total_surveys_today INTEGER,
    total_surveys_week INTEGER,
    avg_emotion_today DECIMAL,
    avg_emotion_week DECIMAL,
    completion_rate_today DECIMAL
) AS $$
BEGIN
    -- 只有管理员可以调用此函数
    IF NOT is_admin() THEN
        RAISE EXCEPTION 'Access denied: Admin privileges required';
    END IF;
    
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*)::INTEGER FROM profiles) as total_users,
        (SELECT COUNT(DISTINCT user_id)::INTEGER FROM emoji_surveys WHERE session_date = CURRENT_DATE) as active_users_today,
        (SELECT COUNT(DISTINCT user_id)::INTEGER FROM emoji_surveys WHERE session_date >= CURRENT_DATE - 6) as active_users_week,
        (SELECT COUNT(*)::INTEGER FROM emoji_surveys WHERE session_date = CURRENT_DATE) as total_surveys_today,
        (SELECT COUNT(*)::INTEGER FROM emoji_surveys WHERE session_date >= CURRENT_DATE - 6) as total_surveys_week,
        (SELECT COALESCE(ROUND(AVG(emotion_score), 2), 0) FROM emoji_surveys WHERE session_date = CURRENT_DATE) as avg_emotion_today,
        (SELECT COALESCE(ROUND(AVG(emotion_score), 2), 0) FROM emoji_surveys WHERE session_date >= CURRENT_DATE - 6) as avg_emotion_week,
        (SELECT COALESCE(ROUND(AVG(required_surveys_completed * 100.0 / 3), 2), 0) FROM user_daily_progress WHERE session_date = CURRENT_DATE) as completion_rate_today;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建设置管理员会话的函数（用于API调用）
CREATE OR REPLACE FUNCTION set_admin_session(admin_email TEXT)
RETURNS VOID AS $$
BEGIN
    -- 验证管理员身份
    IF NOT EXISTS (SELECT 1 FROM admins WHERE email = admin_email AND is_active = true) THEN
        RAISE EXCEPTION 'Invalid admin email or inactive admin';
    END IF;
    
    -- 设置会话变量
    PERFORM set_config('app.current_admin_email', admin_email, true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建清除管理员会话的函数
CREATE OR REPLACE FUNCTION clear_admin_session()
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.current_admin_email', '', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 