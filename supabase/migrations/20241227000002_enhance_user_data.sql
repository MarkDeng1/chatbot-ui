-- 增强用户数据和表单功能的数据库迁移

-- 确保所有必要的触发器函数存在
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 为emoji_surveys表添加更多索引以提升查询性能
CREATE INDEX IF NOT EXISTS emoji_surveys_user_type_idx ON emoji_surveys(user_id, survey_type);
CREATE INDEX IF NOT EXISTS emoji_surveys_emotion_score_idx ON emoji_surveys(emotion_score);
CREATE INDEX IF NOT EXISTS emoji_surveys_created_at_idx ON emoji_surveys(created_at);

-- 为user_daily_progress表添加更多索引
CREATE INDEX IF NOT EXISTS user_daily_progress_user_date_idx ON user_daily_progress(user_id, session_date);
CREATE INDEX IF NOT EXISTS user_daily_progress_created_at_idx ON user_daily_progress(created_at);

-- 创建用户情绪趋势分析视图
CREATE OR REPLACE VIEW user_emotion_trends AS
SELECT 
    user_id,
    session_date,
    AVG(emotion_score) as daily_avg_emotion,
    COUNT(*) as surveys_count,
    COUNT(CASE WHEN survey_type = 'daily_required' THEN 1 END) as required_surveys,
    COUNT(CASE WHEN survey_type = 'extra_voluntary' THEN 1 END) as voluntary_surveys,
    MIN(emotion_score) as min_emotion,
    MAX(emotion_score) as max_emotion,
    -- 计算情绪变化趋势
    LAG(AVG(emotion_score)) OVER (PARTITION BY user_id ORDER BY session_date) as prev_day_avg,
    AVG(emotion_score) - LAG(AVG(emotion_score)) OVER (PARTITION BY user_id ORDER BY session_date) as emotion_change
FROM emoji_surveys
GROUP BY user_id, session_date
ORDER BY user_id, session_date DESC;

-- 创建用户活跃度统计视图
CREATE OR REPLACE VIEW user_activity_stats AS
SELECT 
    p.user_id,
    p.username,
    p.display_name,
    p.created_at as registration_date,
    p.has_onboarded,
    -- 基本统计
    COALESCE(survey_stats.total_surveys, 0) as total_surveys,
    COALESCE(survey_stats.total_required, 0) as total_required_surveys,
    COALESCE(survey_stats.total_voluntary, 0) as total_voluntary_surveys,
    COALESCE(survey_stats.avg_emotion, 0) as avg_emotion_score,
    COALESCE(survey_stats.latest_survey, NULL) as latest_survey_date,
    -- 活跃度指标
    COALESCE(progress_stats.active_days, 0) as active_days,
    COALESCE(progress_stats.streak_days, 0) as current_streak,
    COALESCE(chat_stats.total_chats, 0) as total_chats,
    COALESCE(message_stats.total_messages, 0) as total_messages,
    -- 最近活动
    COALESCE(chat_stats.latest_chat, NULL) as latest_chat_date,
    COALESCE(message_stats.latest_message, NULL) as latest_message_date
FROM profiles p
LEFT JOIN (
    SELECT 
        user_id,
        COUNT(*) as total_surveys,
        COUNT(CASE WHEN survey_type = 'daily_required' THEN 1 END) as total_required,
        COUNT(CASE WHEN survey_type = 'extra_voluntary' THEN 1 END) as total_voluntary,
        ROUND(AVG(emotion_score), 2) as avg_emotion,
        MAX(session_date) as latest_survey
    FROM emoji_surveys 
    GROUP BY user_id
) survey_stats ON p.user_id = survey_stats.user_id
LEFT JOIN (
    SELECT 
        user_id, 
        COUNT(DISTINCT session_date) as active_days,
        -- 计算连续天数（简化版本）
        COUNT(DISTINCT session_date) as streak_days
    FROM user_daily_progress 
    WHERE session_date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY user_id
) progress_stats ON p.user_id = progress_stats.user_id
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
) message_stats ON p.user_id = message_stats.user_id;

-- 创建表单完成度统计函数
CREATE OR REPLACE FUNCTION get_user_survey_completion(user_uuid UUID, target_date DATE DEFAULT CURRENT_DATE)
RETURNS TABLE(
    date DATE,
    required_completed INTEGER,
    required_total INTEGER,
    completion_rate DECIMAL,
    has_extra_surveys BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        target_date as date,
        COALESCE(
            (SELECT required_surveys_completed FROM user_daily_progress 
             WHERE user_id = user_uuid AND session_date = target_date), 
            0
        ) as required_completed,
        3 as required_total, -- 每天需要完成3个必填调查
        ROUND(
            COALESCE(
                (SELECT required_surveys_completed FROM user_daily_progress 
                 WHERE user_id = user_uuid AND session_date = target_date), 
                0
            ) * 100.0 / 3, 
            2
        ) as completion_rate,
        EXISTS(
            SELECT 1 FROM emoji_surveys 
            WHERE user_id = user_uuid 
              AND session_date = target_date 
              AND survey_type = 'extra_voluntary'
        ) as has_extra_surveys;
END;
$$ LANGUAGE plpgsql;

-- 创建获取用户最近情绪数据的函数
CREATE OR REPLACE FUNCTION get_user_recent_emotions(user_uuid UUID, days_back INTEGER DEFAULT 7)
RETURNS TABLE(
    date DATE,
    avg_emotion DECIMAL,
    survey_count INTEGER,
    notes TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        es.session_date as date,
        ROUND(AVG(es.emotion_score), 2) as avg_emotion,
        COUNT(*)::INTEGER as survey_count,
        ARRAY_AGG(es.notes) FILTER (WHERE es.notes IS NOT NULL AND es.notes != '') as notes
    FROM emoji_surveys es
    WHERE es.user_id = user_uuid
      AND es.session_date >= CURRENT_DATE - days_back
    GROUP BY es.session_date
    ORDER BY es.session_date DESC;
END;
$$ LANGUAGE plpgsql;

-- 创建管理员专用的用户详细信息函数
CREATE OR REPLACE FUNCTION get_admin_user_details(user_uuid UUID)
RETURNS TABLE(
    user_id UUID,
    username TEXT,
    display_name TEXT,
    email TEXT,
    bio TEXT,
    registration_date TIMESTAMPTZ,
    has_onboarded BOOLEAN,
    total_surveys INTEGER,
    total_chats INTEGER,
    total_messages INTEGER,
    active_days INTEGER,
    avg_emotion_score DECIMAL,
    latest_activity DATE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.user_id,
        p.username,
        p.display_name,
        COALESCE(au.email, p.username || '@example.com') as email,
        p.bio,
        p.created_at as registration_date,
        p.has_onboarded,
        COALESCE(survey_count.total, 0)::INTEGER as total_surveys,
        COALESCE(chat_count.total, 0)::INTEGER as total_chats,
        COALESCE(message_count.total, 0)::INTEGER as total_messages,
        COALESCE(active_count.days, 0)::INTEGER as active_days,
        COALESCE(emotion_avg.avg_score, 0) as avg_emotion_score,
        GREATEST(
            COALESCE(survey_count.latest_date, '1900-01-01'::date),
            COALESCE(chat_count.latest_date, '1900-01-01'::date),
            COALESCE(message_count.latest_date, '1900-01-01'::date)
        ) as latest_activity
    FROM profiles p
    LEFT JOIN auth.users au ON p.user_id = au.id
    LEFT JOIN (
        SELECT user_id, COUNT(*) as total, MAX(session_date) as latest_date
        FROM emoji_surveys WHERE user_id = user_uuid GROUP BY user_id
    ) survey_count ON p.user_id = survey_count.user_id
    LEFT JOIN (
        SELECT user_id, COUNT(*) as total, MAX(created_at::date) as latest_date
        FROM chats WHERE user_id = user_uuid GROUP BY user_id
    ) chat_count ON p.user_id = chat_count.user_id
    LEFT JOIN (
        SELECT user_id, COUNT(*) as total, MAX(created_at::date) as latest_date
        FROM messages WHERE user_id = user_uuid GROUP BY user_id
    ) message_count ON p.user_id = message_count.user_id
    LEFT JOIN (
        SELECT user_id, COUNT(DISTINCT session_date) as days
        FROM user_daily_progress WHERE user_id = user_uuid GROUP BY user_id
    ) active_count ON p.user_id = active_count.user_id
    LEFT JOIN (
        SELECT user_id, ROUND(AVG(emotion_score), 2) as avg_score
        FROM emoji_surveys WHERE user_id = user_uuid GROUP BY user_id
    ) emotion_avg ON p.user_id = emotion_avg.user_id
    WHERE p.user_id = user_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 优化表单提交的触发器函数
CREATE OR REPLACE FUNCTION update_user_progress_optimized()
RETURNS TRIGGER AS $$
BEGIN
    -- 当插入新的emoji survey时，更新用户进度
    INSERT INTO user_daily_progress (user_id, session_date, required_surveys_completed, extra_surveys_completed)
    VALUES (
        NEW.user_id,
        NEW.session_date,
        CASE WHEN NEW.survey_type = 'daily_required' THEN 1 ELSE 0 END,
        CASE WHEN NEW.survey_type = 'extra_voluntary' THEN 1 ELSE 0 END
    )
    ON CONFLICT (user_id, session_date) 
    DO UPDATE SET
        required_surveys_completed = CASE 
            WHEN NEW.survey_type = 'daily_required' THEN 
                LEAST(user_daily_progress.required_surveys_completed + 1, 3)
            ELSE user_daily_progress.required_surveys_completed
        END,
        extra_surveys_completed = CASE 
            WHEN NEW.survey_type = 'extra_voluntary' THEN 
                user_daily_progress.extra_surveys_completed + 1
            ELSE user_daily_progress.extra_surveys_completed
        END,
        updated_at = CURRENT_TIMESTAMP;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 替换原有的触发器
DROP TRIGGER IF EXISTS update_progress_on_survey_insert ON emoji_surveys;
CREATE TRIGGER update_progress_on_survey_insert
    AFTER INSERT ON emoji_surveys
    FOR EACH ROW
    EXECUTE FUNCTION update_user_progress_optimized();

-- 创建数据完整性检查函数
CREATE OR REPLACE FUNCTION check_data_integrity()
RETURNS TABLE(
    table_name TEXT,
    issue_type TEXT,
    issue_count BIGINT,
    description TEXT
) AS $$
BEGIN
    -- 检查孤立的profiles记录
    RETURN QUERY
    SELECT 
        'profiles'::TEXT,
        'orphaned_profiles'::TEXT,
        COUNT(*),
        'Profiles without corresponding auth.users records'::TEXT
    FROM profiles p
    LEFT JOIN auth.users u ON p.user_id = u.id
    WHERE u.id IS NULL;
    
    -- 检查缺少profiles的auth.users
    RETURN QUERY
    SELECT 
        'auth.users'::TEXT,
        'missing_profiles'::TEXT,
        COUNT(*),
        'Auth users without corresponding profiles'::TEXT
    FROM auth.users u
    LEFT JOIN profiles p ON u.id = p.user_id
    WHERE p.user_id IS NULL;
    
    -- 检查emoji_surveys数据一致性
    RETURN QUERY
    SELECT 
        'emoji_surveys'::TEXT,
        'invalid_scores'::TEXT,
        COUNT(*),
        'Emotion scores outside valid range (1-5)'::TEXT
    FROM emoji_surveys
    WHERE emotion_score < 1 OR emotion_score > 5;
    
    -- 检查user_daily_progress数据一致性
    RETURN QUERY
    SELECT 
        'user_daily_progress'::TEXT,
        'invalid_required_count'::TEXT,
        COUNT(*),
        'Required surveys count outside valid range (0-3)'::TEXT
    FROM user_daily_progress
    WHERE required_surveys_completed < 0 OR required_surveys_completed > 3;
END;
$$ LANGUAGE plpgsql;

-- 添加一些有用的索引来提升性能
CREATE INDEX IF NOT EXISTS profiles_username_idx ON profiles(username);
CREATE INDEX IF NOT EXISTS profiles_display_name_idx ON profiles(display_name);
CREATE INDEX IF NOT EXISTS profiles_has_onboarded_idx ON profiles(has_onboarded);

CREATE INDEX IF NOT EXISTS chats_user_created_idx ON chats(user_id, created_at);
CREATE INDEX IF NOT EXISTS messages_user_created_idx ON messages(user_id, created_at);
CREATE INDEX IF NOT EXISTS messages_chat_sequence_idx ON messages(chat_id, sequence_number);

-- 注意：PostgreSQL不支持对VIEW启用RLS
-- 这些视图的访问控制需要在应用层面实现
-- 或者通过将VIEW转换为函数来实现安全访问 