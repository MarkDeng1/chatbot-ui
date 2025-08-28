-- 数据库功能测试脚本
-- 用于验证所有功能是否正常工作

-- 测试管理员功能
DO $$
BEGIN
    RAISE NOTICE '=== 开始数据库功能测试 ===';
    
    -- 1. 测试管理员表
    RAISE NOTICE '1. 测试管理员表...';
    IF EXISTS (SELECT 1 FROM admins WHERE email = 'admin@mentalshield.com') THEN
        RAISE NOTICE '✓ 管理员账户存在';
    ELSE
        RAISE NOTICE '✗ 管理员账户不存在';
    END IF;
    
    -- 2. 测试管理员会话功能
    RAISE NOTICE '2. 测试管理员会话功能...';
    BEGIN
        PERFORM set_admin_session('admin@mentalshield.com');
        IF is_admin() THEN
            RAISE NOTICE '✓ 管理员会话设置成功';
        ELSE
            RAISE NOTICE '✗ 管理员会话设置失败';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '✗ 管理员会话功能异常: %', SQLERRM;
    END;
    
    -- 3. 测试用户数据
    RAISE NOTICE '3. 测试用户数据...';
    IF EXISTS (SELECT 1 FROM profiles LIMIT 1) THEN
        RAISE NOTICE '✓ 用户档案数据存在，数量: %', (SELECT COUNT(*) FROM profiles);
    ELSE
        RAISE NOTICE '⚠ 用户档案数据不存在（需要运行seed.sql）';
    END IF;
    
    -- 4. 测试表单数据
    RAISE NOTICE '4. 测试表单数据...';
    IF EXISTS (SELECT 1 FROM emoji_surveys LIMIT 1) THEN
        RAISE NOTICE '✓ 表单数据存在，数量: %', (SELECT COUNT(*) FROM emoji_surveys);
        RAISE NOTICE '  - 必填调查: %', (SELECT COUNT(*) FROM emoji_surveys WHERE survey_type = 'daily_required');
        RAISE NOTICE '  - 自愿调查: %', (SELECT COUNT(*) FROM emoji_surveys WHERE survey_type = 'extra_voluntary');
    ELSE
        RAISE NOTICE '⚠ 表单数据不存在（需要运行seed.sql）';
    END IF;
    
    -- 5. 测试进度数据
    RAISE NOTICE '5. 测试进度数据...';
    IF EXISTS (SELECT 1 FROM user_daily_progress LIMIT 1) THEN
        RAISE NOTICE '✓ 用户进度数据存在，数量: %', (SELECT COUNT(*) FROM user_daily_progress);
    ELSE
        RAISE NOTICE '⚠ 用户进度数据不存在（需要运行seed.sql）';
    END IF;
    
    -- 6. 测试视图
    RAISE NOTICE '6. 测试数据视图...';
    BEGIN
        IF EXISTS (SELECT 1 FROM user_emotion_trends LIMIT 1) THEN
            RAISE NOTICE '✓ 情绪趋势视图正常，记录数: %', (SELECT COUNT(*) FROM user_emotion_trends);
        ELSE
            RAISE NOTICE '⚠ 情绪趋势视图无数据';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '✗ 情绪趋势视图异常: %', SQLERRM;
    END;
    
    -- 7. 测试触发器
    RAISE NOTICE '7. 测试触发器功能...';
    IF EXISTS (SELECT 1 FROM emoji_surveys LIMIT 1) THEN
        -- 检查是否有对应的进度记录
        DECLARE
            survey_count INTEGER;
            progress_count INTEGER;
        BEGIN
            SELECT COUNT(*) INTO survey_count FROM emoji_surveys;
            SELECT COUNT(*) INTO progress_count FROM user_daily_progress;
            
            IF progress_count > 0 THEN
                RAISE NOTICE '✓ 进度更新触发器正常工作';
            ELSE
                RAISE NOTICE '⚠ 进度更新触发器可能未正常工作';
            END IF;
        END;
    END IF;
    
    -- 8. 测试RLS策略
    RAISE NOTICE '8. 测试RLS策略...';
    IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'emoji_surveys') THEN
        RAISE NOTICE '✓ RLS策略已设置，emoji_surveys策略数: %', 
            (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'emoji_surveys');
    ELSE
        RAISE NOTICE '✗ RLS策略未设置';
    END IF;
    
    RAISE NOTICE '=== 数据库功能测试完成 ===';
END $$;

-- 显示数据库统计信息
SELECT 
    '数据库表统计' as category,
    'admins' as table_name,
    COUNT(*) as record_count
FROM admins
UNION ALL
SELECT 
    '数据库表统计',
    'profiles',
    COUNT(*)
FROM profiles
UNION ALL
SELECT 
    '数据库表统计',
    'emoji_surveys',
    COUNT(*)
FROM emoji_surveys
UNION ALL
SELECT 
    '数据库表统计',
    'user_daily_progress',
    COUNT(*)
FROM user_daily_progress
UNION ALL
SELECT 
    '数据库表统计',
    'chats',
    COUNT(*)
FROM chats
UNION ALL
SELECT 
    '数据库表统计',
    'messages',
    COUNT(*)
FROM messages;

-- 如果有数据，显示一些示例记录
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM emoji_surveys LIMIT 1) THEN
        RAISE NOTICE '';
        RAISE NOTICE '=== 示例数据 ===';
        RAISE NOTICE '最近的表单提交:';
        
        -- 显示最近的表单数据
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN 
                SELECT 
                    p.username,
                    es.session_date,
                    es.survey_type,
                    es.emotion_score,
                    es.question_text
                FROM emoji_surveys es
                JOIN profiles p ON es.user_id = p.user_id
                ORDER BY es.created_at DESC
                LIMIT 3
            LOOP
                RAISE NOTICE '- %: % (%) - 分数: %, 问题: %', 
                    r.username, r.session_date, r.survey_type, r.emotion_score, 
                    LEFT(r.question_text, 20) || '...';
            END LOOP;
        END;
    END IF;
END $$;

-- 管理员功能测试（如果设置了管理员会话）
DO $$
BEGIN
    -- 尝试设置管理员会话并测试权限
    BEGIN
        PERFORM set_admin_session('admin@mentalshield.com');
        
        IF is_admin() THEN
            RAISE NOTICE '';
            RAISE NOTICE '=== 管理员权限测试 ===';
            RAISE NOTICE '✓ 管理员身份验证成功';
            
            -- 测试是否可以查看所有用户数据
            RAISE NOTICE '可查看的用户档案数量: %', (SELECT COUNT(*) FROM profiles);
            RAISE NOTICE '可查看的表单数量: %', (SELECT COUNT(*) FROM emoji_surveys);
            RAISE NOTICE '可查看的进度记录数量: %', (SELECT COUNT(*) FROM user_daily_progress);
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '管理员权限测试失败: %', SQLERRM;
    END;
END $$; 