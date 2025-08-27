--------------- EMOJI SURVEYS ---------------

-- TABLE --

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

-- INDEXES --

CREATE INDEX emoji_surveys_user_id_idx ON emoji_surveys(user_id);
CREATE INDEX emoji_surveys_session_date_idx ON emoji_surveys(session_date);
CREATE INDEX emoji_surveys_user_date_idx ON emoji_surveys(user_id, session_date);

-- RLS --

ALTER TABLE emoji_surveys ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow full access to own emoji surveys"
    ON emoji_surveys
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- TRIGGERS --

CREATE TRIGGER update_emoji_surveys_updated_at
BEFORE UPDATE ON emoji_surveys 
FOR EACH ROW 
EXECUTE PROCEDURE update_updated_at_column();

--------------- USER PROGRESS ---------------

-- TABLE --

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

-- INDEXES --

CREATE INDEX user_daily_progress_user_id_idx ON user_daily_progress(user_id);
CREATE INDEX user_daily_progress_session_date_idx ON user_daily_progress(session_date);

-- RLS --

ALTER TABLE user_daily_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow full access to own daily progress"
    ON user_daily_progress
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- TRIGGERS --

CREATE TRIGGER update_user_daily_progress_updated_at
BEFORE UPDATE ON user_daily_progress 
FOR EACH ROW 
EXECUTE PROCEDURE update_updated_at_column();

-- FUNCTIONS --

CREATE OR REPLACE FUNCTION update_user_progress()
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
        required_surveys_completed = user_daily_progress.required_surveys_completed + 
            CASE WHEN NEW.survey_type = 'daily_required' THEN 1 ELSE 0 END,
        extra_surveys_completed = user_daily_progress.extra_surveys_completed + 
            CASE WHEN NEW.survey_type = 'extra_voluntary' THEN 1 ELSE 0 END,
        updated_at = CURRENT_TIMESTAMP;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_progress_on_survey_insert
AFTER INSERT ON emoji_surveys
FOR EACH ROW
EXECUTE FUNCTION update_user_progress(); 