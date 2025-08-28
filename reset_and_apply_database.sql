-- 数据库完整重置和应用脚本
-- 用于重新初始化整个数据库结构和数据

-- 首先清理现有的策略和触发器
DO $$ 
DECLARE
    r RECORD;
BEGIN
    -- 删除所有RLS策略
    FOR r IN (SELECT schemaname, tablename, policyname FROM pg_policies WHERE schemaname = 'public') LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', r.policyname, r.schemaname, r.tablename);
    END LOOP;
    
    -- 删除所有触发器
    FOR r IN (SELECT trigger_name, event_object_table FROM information_schema.triggers WHERE trigger_schema = 'public') LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON %I', r.trigger_name, r.event_object_table);
    END LOOP;
END $$;

-- 删除现有的视图和函数
DROP VIEW IF EXISTS admin_user_statistics CASCADE;
DROP VIEW IF EXISTS user_emotion_trends CASCADE;
DROP VIEW IF EXISTS user_activity_stats CASCADE;

DROP FUNCTION IF EXISTS is_admin() CASCADE;
DROP FUNCTION IF EXISTS verify_admin_access(TEXT) CASCADE;
DROP FUNCTION IF EXISTS create_admin_session(TEXT, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS verify_admin_session(TEXT) CASCADE;
DROP FUNCTION IF EXISTS cleanup_expired_admin_sessions() CASCADE;
DROP FUNCTION IF EXISTS get_user_survey_completion(UUID, DATE) CASCADE;
DROP FUNCTION IF EXISTS get_user_recent_emotions(UUID, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS get_admin_user_details(UUID) CASCADE;
DROP FUNCTION IF EXISTS update_user_progress_optimized() CASCADE;
DROP FUNCTION IF EXISTS check_data_integrity() CASCADE;
DROP FUNCTION IF EXISTS get_all_users_summary() CASCADE;
DROP FUNCTION IF EXISTS get_user_progress_details(UUID, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS get_admin_dashboard_stats() CASCADE;
DROP FUNCTION IF EXISTS set_admin_session(TEXT) CASCADE;
DROP FUNCTION IF EXISTS clear_admin_session() CASCADE;

-- 删除现有表（按依赖关系顺序）
DROP TABLE IF EXISTS admin_sessions CASCADE;
DROP TABLE IF EXISTS admins CASCADE;
DROP TABLE IF EXISTS user_daily_progress CASCADE;
DROP TABLE IF EXISTS emoji_surveys CASCADE;

-- 现在重新创建所有结构

-- 1. 应用基础设置迁移
-- 确保所有必要的扩展和函数存在
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 创建更新时间戳函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 2. 应用emoji_surveys迁移
CREATE TABLE IF NOT EXISTS emoji_surveys (
    -- ID
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- RELATIONSHIPS
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    -- METADATA
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ,

    -- REQUIRED
    survey_type TEXT NOT NULL CHECK (survey_type IN ('daily_required', 'extra_voluntary')),
    emotion_score INTEGER NOT NULL CHECK (emotion_score >= 1 AND emotion_score <= 5),
    question_text TEXT NOT NULL CHECK (char_length(question_text) <= 200),
    
    -- OPTIONAL
    session_date DATE NOT NULL DEFAULT CURRENT_DATE,
    survey_order INTEGER DEFAULT 1 CHECK (survey_order >= 1 AND survey_order <= 3),
    notes TEXT CHECK (char_length(notes) <= 500)
);

-- INDEXES
CREATE INDEX IF NOT EXISTS emoji_surveys_user_id_idx ON emoji_surveys(user_id);
CREATE INDEX IF NOT EXISTS emoji_surveys_session_date_idx ON emoji_surveys(session_date);
CREATE INDEX IF NOT EXISTS emoji_surveys_user_date_idx ON emoji_surveys(user_id, session_date);
CREATE INDEX IF NOT EXISTS emoji_surveys_user_type_idx ON emoji_surveys(user_id, survey_type);
CREATE INDEX IF NOT EXISTS emoji_surveys_emotion_score_idx ON emoji_surveys(emotion_score);
CREATE INDEX IF NOT EXISTS emoji_surveys_created_at_idx ON emoji_surveys(created_at);

-- RLS
ALTER TABLE emoji_surveys ENABLE ROW LEVEL SECURITY;

-- TRIGGERS
CREATE TRIGGER update_emoji_surveys_updated_at
BEFORE UPDATE ON emoji_surveys 
FOR EACH ROW 
EXECUTE PROCEDURE update_updated_at_column();

-- 3. 创建user_daily_progress表
CREATE TABLE IF NOT EXISTS user_daily_progress (
    -- ID
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- RELATIONSHIPS  
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    -- METADATA
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ,

    -- REQUIRED
    session_date DATE NOT NULL DEFAULT CURRENT_DATE,
    required_surveys_completed INTEGER NOT NULL DEFAULT 0 CHECK (required_surveys_completed >= 0 AND required_surveys_completed <= 3),
    extra_surveys_completed INTEGER NOT NULL DEFAULT 0 CHECK (extra_surveys_completed >= 0),
    
    -- UNIQUE CONSTRAINT
    UNIQUE(user_id, session_date)
);

-- INDEXES
CREATE INDEX IF NOT EXISTS user_daily_progress_user_id_idx ON user_daily_progress(user_id);
CREATE INDEX IF NOT EXISTS user_daily_progress_session_date_idx ON user_daily_progress(session_date);
CREATE INDEX IF NOT EXISTS user_daily_progress_user_date_idx ON user_daily_progress(user_id, session_date);
CREATE INDEX IF NOT EXISTS user_daily_progress_created_at_idx ON user_daily_progress(created_at);

-- RLS
ALTER TABLE user_daily_progress ENABLE ROW LEVEL SECURITY;

-- TRIGGERS
CREATE TRIGGER update_user_daily_progress_updated_at
BEFORE UPDATE ON user_daily_progress 
FOR EACH ROW 
EXECUTE PROCEDURE update_updated_at_column();

-- 4. 创建管理员表
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

-- 添加更新时间触发器
CREATE TRIGGER update_admins_updated_at 
    BEFORE UPDATE ON admins 
    FOR EACH ROW 
    EXECUTE PROCEDURE update_updated_at_column();

-- 5. 创建管理员会话表
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

-- 现在重新应用所有迁移文件内容...

-- 从 20241227000002_enhance_user_data.sql 应用内容
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
    LAG(AVG(emotion_score)) OVER (PARTITION BY user_id ORDER BY session_date) as prev_day_avg,
    AVG(emotion_score) - LAG(AVG(emotion_score)) OVER (PARTITION BY user_id ORDER BY session_date) as emotion_change
FROM emoji_surveys
GROUP BY user_id, session_date
ORDER BY user_id, session_date DESC;

-- 从 20241227000003_admin_access_policies.sql 应用内容
-- 创建管理员身份验证函数
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
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

-- 创建所有RLS策略
CREATE POLICY "Allow full access to own emoji surveys" ON emoji_surveys
    USING (user_id = auth.uid() OR is_admin())
    WITH CHECK (user_id = auth.uid() OR is_admin());

CREATE POLICY "Allow full access to own daily progress" ON user_daily_progress
    USING (user_id = auth.uid() OR is_admin())
    WITH CHECK (user_id = auth.uid() OR is_admin());

CREATE POLICY "Admins can only access their own data" ON admins 
    FOR ALL USING (email = current_setting('app.current_admin_email', true));

CREATE POLICY "Admins can only access their own sessions" ON admin_sessions 
    FOR ALL USING (admin_id IN (SELECT id FROM admins WHERE email = current_setting('app.current_admin_email', true)));

-- 创建进度更新触发器函数
CREATE OR REPLACE FUNCTION update_user_progress_optimized()
RETURNS TRIGGER AS $$
BEGIN
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

CREATE TRIGGER update_progress_on_survey_insert
    AFTER INSERT ON emoji_surveys
    FOR EACH ROW
    EXECUTE FUNCTION update_user_progress_optimized();

-- 创建管理员会话管理函数
CREATE OR REPLACE FUNCTION set_admin_session(admin_email TEXT)
RETURNS VOID AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM admins WHERE email = admin_email AND is_active = true) THEN
        RAISE EXCEPTION 'Invalid admin email or inactive admin';
    END IF;
    
    PERFORM set_config('app.current_admin_email', admin_email, true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 应用种子数据（来自 seed.sql）
-- 注意：这里只包含管理员数据，用户数据在seed.sql中
INSERT INTO admins (email, password_hash, name, is_active) VALUES 
('admin@mentalshield.com', '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'System Administrator', true),
('manager@mentalshield.com', '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Project Manager', true)
ON CONFLICT (email) DO UPDATE SET
    password_hash = EXCLUDED.password_hash,
    name = EXCLUDED.name,
    is_active = EXCLUDED.is_active;

-- 验证数据完整性
DO $$
BEGIN
    RAISE NOTICE '数据库重置完成！';
    RAISE NOTICE '管理员账户数量: %', (SELECT COUNT(*) FROM admins);
    RAISE NOTICE '请运行 seed.sql 来添加测试用户和数据';
END $$; 