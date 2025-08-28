-- 数据库种子数据文件 - 完整版本
-- 包含用户信息、管理员账户、表单数据和进度数据

-- 插入测试用户到 auth.users 表
INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, invited_at, confirmation_token, confirmation_sent_at, recovery_token, recovery_sent_at, email_change_token_new, email_change, email_change_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at, phone, phone_confirmed_at, phone_change, phone_change_token, phone_change_sent_at, email_change_token_current, email_change_confirm_status, banned_until, reauthentication_token, reauthentication_sent_at, is_sso_user) VALUES
-- 测试用户1
('00000000-0000-0000-0000-000000000000', 'e9fc7e46-a8a5-4fd4-8ba7-af485013e6fa', 'authenticated', 'authenticated', 'user1@example.com', crypt('password123', gen_salt('bf')), '2024-01-01 10:00:00.000000+00', NULL, '', '2024-01-01 10:00:00.000000+00', '', NULL, '', '', NULL, '2024-01-01 10:00:00.000000+00', '{"provider": "email", "providers": ["email"]}', '{}', NULL, '2024-01-01 10:00:00.000000+00', '2024-01-01 10:00:00.000000+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, 'f'),
-- 测试用户2
('00000000-0000-0000-0000-000000000000', 'f8ec6d35-b7a4-4ed3-9ba6-bf485013e6fb', 'authenticated', 'authenticated', 'user2@example.com', crypt('password123', gen_salt('bf')), '2024-01-02 11:00:00.000000+00', NULL, '', '2024-01-02 11:00:00.000000+00', '', NULL, '', '', NULL, '2024-01-02 11:00:00.000000+00', '{"provider": "email", "providers": ["email"]}', '{}', NULL, '2024-01-02 11:00:00.000000+00', '2024-01-02 11:00:00.000000+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, 'f'),
-- 测试用户3
('00000000-0000-0000-0000-000000000000', 'a7db5c24-c6b3-4dc2-8ca5-cf485013e6fc', 'authenticated', 'authenticated', 'user3@example.com', crypt('password123', gen_salt('bf')), '2024-01-03 12:00:00.000000+00', NULL, '', '2024-01-03 12:00:00.000000+00', '', NULL, '', '', NULL, '2024-01-03 12:00:00.000000+00', '{"provider": "email", "providers": ["email"]}', '{}', NULL, '2024-01-03 12:00:00.000000+00', '2024-01-03 12:00:00.000000+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, 'f')
ON CONFLICT (id) DO NOTHING;

-- 插入用户档案信息
INSERT INTO profiles (user_id, username, display_name, bio, profile_context, has_onboarded, image_url, image_path, use_azure_openai, openai_api_key) VALUES
('e9fc7e46-a8a5-4fd4-8ba7-af485013e6fa', 'alice_chen', '陈小丽', '我是一名大学生，喜欢学习心理学和人工智能。', '我正在使用MentalShield来跟踪我的情绪健康状况。', true, '', '', false, ''),
('f8ec6d35-b7a4-4ed3-9ba6-bf485013e6fb', 'bob_wang', '王小明', '我是一名软件工程师，关注心理健康和工作生活平衡。', '我希望通过定期的情绪记录来更好地了解自己。', true, '', '', false, ''),
('a7db5c24-c6b3-4dc2-8ca5-cf485013e6fc', 'carol_li', '李小红', '我是一名心理咨询师，也在使用这个应用来自我监测。', '我相信数据驱动的心理健康管理方法。', true, '', '', false, '')
ON CONFLICT (user_id) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    bio = EXCLUDED.bio,
    profile_context = EXCLUDED.profile_context,
    has_onboarded = EXCLUDED.has_onboarded;

-- 为每个用户创建工作空间
DO $$
DECLARE
    user1_id UUID := 'e9fc7e46-a8a5-4fd4-8ba7-af485013e6fa';
    user2_id UUID := 'f8ec6d35-b7a4-4ed3-9ba6-bf485013e6fb';
    user3_id UUID := 'a7db5c24-c6b3-4dc2-8ca5-cf485013e6fc';
    workspace1_id UUID;
    workspace2_id UUID;
    workspace3_id UUID;
BEGIN
    -- 为用户1创建工作空间（如果不存在）
    SELECT id INTO workspace1_id FROM workspaces WHERE user_id = user1_id AND is_home = true;
    IF workspace1_id IS NULL THEN
        INSERT INTO workspaces (user_id, name, description, default_context_length, default_model, default_prompt, default_temperature, include_profile_context, include_workspace_instructions, instructions, is_home, sharing, embeddings_provider) 
        VALUES (user1_id, 'Home', '我的主要工作空间', 4000, 'gpt-4-turbo-preview', 'You are a helpful AI assistant focused on mental health support.', 0.5, true, true, '这是我的个人AI助手，专注于心理健康支持。', true, 'private', 'openai')
        RETURNING id INTO workspace1_id;
    END IF;

    -- 为用户2创建工作空间（如果不存在）
    SELECT id INTO workspace2_id FROM workspaces WHERE user_id = user2_id AND is_home = true;
    IF workspace2_id IS NULL THEN
        INSERT INTO workspaces (user_id, name, description, default_context_length, default_model, default_prompt, default_temperature, include_profile_context, include_workspace_instructions, instructions, is_home, sharing, embeddings_provider) 
        VALUES (user2_id, 'Home', '我的主要工作空间', 4000, 'gpt-4-turbo-preview', 'You are a helpful AI assistant for work-life balance.', 0.5, true, true, '帮助我平衡工作和生活的AI助手。', true, 'private', 'openai')
        RETURNING id INTO workspace2_id;
    END IF;

    -- 为用户3创建工作空间（如果不存在）
    SELECT id INTO workspace3_id FROM workspaces WHERE user_id = user3_id AND is_home = true;
    IF workspace3_id IS NULL THEN
        INSERT INTO workspaces (user_id, name, description, default_context_length, default_model, default_prompt, default_temperature, include_profile_context, include_workspace_instructions, instructions, is_home, sharing, embeddings_provider) 
        VALUES (user3_id, 'Home', '我的主要工作空间', 4000, 'gpt-4-turbo-preview', 'You are a professional AI assistant for mental health professionals.', 0.5, true, true, '专业的心理健康AI助手。', true, 'private', 'openai')
        RETURNING id INTO workspace3_id;
    END IF;

    -- 为每个用户创建一些聊天记录
    INSERT INTO chats (user_id, workspace_id, name, model, prompt, temperature, context_length, include_profile_context, include_workspace_instructions, embeddings_provider) VALUES
    (user1_id, workspace1_id, '情绪咨询', 'gpt-4-turbo-preview', 'You are a supportive mental health assistant.', 0.7, 4000, true, true, 'openai'),
    (user1_id, workspace1_id, '学习压力', 'gpt-4-turbo-preview', 'Help me manage study stress.', 0.5, 4000, true, true, 'openai'),
    (user2_id, workspace2_id, '工作焦虑', 'gpt-4-turbo-preview', 'Help me with work anxiety.', 0.6, 4000, true, true, 'openai'),
    (user2_id, workspace2_id, '生活平衡', 'gpt-4-turbo-preview', 'Advice on work-life balance.', 0.5, 4000, true, true, 'openai'),
    (user3_id, workspace3_id, '专业咨询', 'gpt-4-turbo-preview', 'Professional consultation assistant.', 0.4, 4000, true, true, 'openai');

END $$;

-- 插入情绪调查数据（最近7天的数据）
DO $$
DECLARE
    user1_id UUID := 'e9fc7e46-a8a5-4fd4-8ba7-af485013e6fa';
    user2_id UUID := 'f8ec6d35-b7a4-4ed3-9ba6-bf485013e6fb';
    user3_id UUID := 'a7db5c24-c6b3-4dc2-8ca5-cf485013e6fc';
    i INTEGER;
    survey_date DATE;
BEGIN
    -- 为每个用户插入过去7天的情绪调查数据
    FOR i IN 0..6 LOOP
        survey_date := CURRENT_DATE - i;
        
        -- 用户1的数据 - 情绪波动较大
        INSERT INTO emoji_surveys (user_id, survey_type, emotion_score, question_text, session_date, survey_order, notes) VALUES
        (user1_id, 'daily_required', 2 + (i % 4), '今天感觉如何？', survey_date, 1, CASE WHEN i % 2 = 0 THEN '学习压力比较大' ELSE '心情还不错' END),
        (user1_id, 'daily_required', 3 + (i % 3), '对今天的学习满意吗？', survey_date, 2, ''),
        (user1_id, 'daily_required', 2 + (i % 4), '今晚睡眠质量预期如何？', survey_date, 3, '');
        
        -- 用户2的数据 - 相对稳定
        INSERT INTO emoji_surveys (user_id, survey_type, emotion_score, question_text, session_date, survey_order, notes) VALUES
        (user2_id, 'daily_required', 3 + (i % 2), '今天感觉如何？', survey_date, 1, '工作还算顺利'),
        (user2_id, 'daily_required', 4, '对今天的工作满意吗？', survey_date, 2, ''),
        (user2_id, 'daily_required', 3 + (i % 3), '今晚睡眠质量预期如何？', survey_date, 3, '');
        
        -- 用户3的数据 - 整体较好
        INSERT INTO emoji_surveys (user_id, survey_type, emotion_score, question_text, session_date, survey_order, notes) VALUES
        (user3_id, 'daily_required', 4 + (i % 2), '今天感觉如何？', survey_date, 1, '帮助了很多来访者'),
        (user3_id, 'daily_required', 4, '对今天的工作满意吗？', survey_date, 2, ''),
        (user3_id, 'daily_required', 4 + (i % 2), '今晚睡眠质量预期如何？', survey_date, 3, '');
        
        -- 偶尔添加额外的自愿调查
        IF i % 3 = 0 THEN
            INSERT INTO emoji_surveys (user_id, survey_type, emotion_score, question_text, session_date, survey_order, notes) VALUES
            (user1_id, 'extra_voluntary', 3 + (i % 3), '现在的心情如何？', survey_date, 1, '额外记录'),
            (user2_id, 'extra_voluntary', 4, '对工作环境满意吗？', survey_date, 1, ''),
            (user3_id, 'extra_voluntary', 5, '今天有什么特别的收获吗？', survey_date, 1, '帮助了一位重度抑郁的患者');
        END IF;
    END LOOP;
END $$;

-- 插入一些消息记录
DO $$
DECLARE
    chat_ids UUID[];
    chat_id UUID;
BEGIN
    -- 获取所有聊天ID
    SELECT ARRAY(SELECT id FROM chats ORDER BY created_at) INTO chat_ids;
    
    -- 为第一个聊天添加消息
    IF array_length(chat_ids, 1) > 0 THEN
        chat_id := chat_ids[1];
        INSERT INTO messages (user_id, chat_id, content, role, model, sequence_number, image_paths) VALUES
        ('e9fc7e46-a8a5-4fd4-8ba7-af485013e6fa', chat_id, '你好，我最近感觉学习压力很大，总是担心考试成绩。', 'user', 'gpt-4-turbo-preview', 0, '{}'),
        ('e9fc7e46-a8a5-4fd4-8ba7-af485013e6fa', chat_id, '我理解你的担心。学习压力是很常见的，特别是面对重要考试时。让我们一起探讨一些减压的方法。首先，你能告诉我具体是什么让你最担心吗？', 'assistant', 'gpt-4-turbo-preview', 1, '{}'),
        ('e9fc7e46-a8a5-4fd4-8ba7-af485013e6fa', chat_id, '主要是担心自己准备不够充分，还有就是怕辜负父母的期望。', 'user', 'gpt-4-turbo-preview', 2, '{}'),
        ('e9fc7e46-a8a5-4fd4-8ba7-af485013e6fa', chat_id, '这些担心都很正常。让我建议几个方法：1) 制定合理的学习计划，将大目标分解成小步骤；2) 定期休息和运动；3) 与父母开诚布公地沟通你的感受。记住，尽力而为就足够了。', 'assistant', 'gpt-4-turbo-preview', 3, '{}');
    END IF;
    
    -- 为第二个聊天添加消息
    IF array_length(chat_ids, 1) > 1 THEN
        chat_id := chat_ids[2];
        INSERT INTO messages (user_id, chat_id, content, role, model, sequence_number, image_paths) VALUES
        ('e9fc7e46-a8a5-4fd4-8ba7-af485013e6fa', chat_id, '我发现自己经常拖延，明明知道要学习但就是提不起劲。', 'user', 'gpt-4-turbo-preview', 0, '{}'),
        ('e9fc7e46-a8a5-4fd4-8ba7-af485013e6fa', chat_id, '拖延是很多人都会遇到的问题。这通常是因为任务看起来太困难或者缺乏明确的目标。试试"番茄工作法"：专注学习25分钟，然后休息5分钟。这样可以让学习变得更容易开始。', 'assistant', 'gpt-4-turbo-preview', 1, '{}');
    END IF;
END $$;

-- 插入管理员账户（使用bcrypt加密密码）
-- 密码为: admin123
INSERT INTO admins (email, password_hash, name, is_active) VALUES 
('admin@mentalshield.com', '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'System Administrator', true),
('manager@mentalshield.com', '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Project Manager', true)
ON CONFLICT (email) DO UPDATE SET
    password_hash = EXCLUDED.password_hash,
    name = EXCLUDED.name,
    is_active = EXCLUDED.is_active;

-- 插入一些预设和提示词
DO $$
DECLARE
    user1_id UUID := 'e9fc7e46-a8a5-4fd4-8ba7-af485013e6fa';
    workspace_id UUID;
BEGIN
    SELECT id INTO workspace_id FROM workspaces WHERE user_id = user1_id AND is_home = true LIMIT 1;
    
    IF workspace_id IS NOT NULL THEN
        -- 插入预设
        INSERT INTO presets (user_id, created_at, updated_at, sharing, include_profile_context, include_workspace_instructions, context_length, model, name, prompt, temperature, description, embeddings_provider) VALUES
        (user1_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'private', TRUE, TRUE, 4000, 'gpt-4-turbo-preview', '心理健康助手', '你是一个专业的心理健康助手，善于倾听和提供支持性的建议。', 0.7, '专门用于心理健康咨询的AI助手预设', 'openai');

        -- 插入提示词
        INSERT INTO prompts (user_id, folder_id, created_at, updated_at, sharing, content, name) VALUES 
        (user1_id, null, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'private', '我想让你充当心理健康顾问。我将向你提供一个寻求指导和建议的人，以管理他们的情绪、压力、焦虑和其他心理健康问题。你应该利用你的认知行为疗法、冥想技巧、正念练习和其他治疗方法的知识来制定个人可以实施的策略，以改善他们的整体健康状况。', '心理健康顾问'),
        (user1_id, null, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'private', '我希望你能充当压力管理教练。我会告诉你我生活中的压力源，你需要提供健康的应对策略和技巧来管理这些压力。你应该提供实用的建议，包括时间管理、放松技巧、运动建议等。', '压力管理教练');
        
        -- 连接预设和提示词到工作空间
        INSERT INTO preset_workspaces (user_id, preset_id, workspace_id) 
        SELECT user1_id, id, workspace_id FROM presets WHERE user_id = user1_id AND name = '心理健康助手';
        
        INSERT INTO prompt_workspaces (user_id, prompt_id, workspace_id) 
        SELECT user1_id, id, workspace_id FROM prompts WHERE user_id = user1_id;
    END IF;
END $$;