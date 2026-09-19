-- interview-coach 테이블 스키마

-- 기존 테이블 삭제 (타입 불일치 방지)
DROP TABLE IF EXISTS interviews CASCADE;
DROP TABLE IF EXISTS interview_sessions CASCADE;
DROP TABLE IF EXISTS questions CASCADE;
DROP TABLE IF EXISTS students CASCADE;

-- students 테이블
CREATE TABLE students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  university TEXT,
  department TEXT,
  record TEXT,
  masked_record TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- user_id 인덱스
CREATE INDEX students_user_id_idx ON students(user_id);

-- questions 테이블
CREATE TABLE questions (
  id SERIAL PRIMARY KEY,
  student_id UUID NOT NULL UNIQUE REFERENCES students(id) ON DELETE CASCADE,
  questions JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- student_id 인덱스 (UNIQUE 제약 조건이 자동으로 인덱스 생성)
-- CREATE INDEX questions_student_id_idx ON questions(student_id); -- 불필요 (UNIQUE가 인덱스 생성)

-- interview_sessions 테이블
CREATE TABLE interview_sessions (
  id SERIAL PRIMARY KEY,
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  mode TEXT,
  question_count INTEGER,
  status TEXT DEFAULT 'in_progress',
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- student_id 인덱스
CREATE INDEX interview_sessions_student_id_idx ON interview_sessions(student_id);

-- interviews 테이블 (면접 연습 답변)
CREATE TABLE interviews (
  id SERIAL PRIMARY KEY,
  session_id INTEGER NOT NULL REFERENCES interview_sessions(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  question_index INTEGER NOT NULL,
  question TEXT NOT NULL,
  model_answer TEXT,
  student_answer TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(session_id, question_index)
);

-- session_id 인덱스
CREATE INDEX interviews_session_id_idx ON interviews(session_id);

-- Row Level Security (RLS) 활성화
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE interview_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE interviews ENABLE ROW LEVEL SECURITY;

-- students 정책
CREATE POLICY "Users can view own students"
  ON students FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own students"
  ON students FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own students"
  ON students FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own students"
  ON students FOR DELETE
  USING (auth.uid() = user_id);

-- questions 정책
CREATE POLICY "Users can view own questions"
  ON questions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM students
      WHERE students.id = questions.student_id
      AND students.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own questions"
  ON questions FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM students
      WHERE students.id = questions.student_id
      AND students.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update own questions"
  ON questions FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM students
      WHERE students.id = questions.student_id
      AND students.user_id = auth.uid()
    )
  );

-- interview_sessions 정책
CREATE POLICY "Users can view own sessions"
  ON interview_sessions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM students
      WHERE students.id = interview_sessions.student_id
      AND students.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own sessions"
  ON interview_sessions FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM students
      WHERE students.id = interview_sessions.student_id
      AND students.user_id = auth.uid()
    )
  );

-- interviews 정책
CREATE POLICY "Users can view own interviews"
  ON interviews FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM students
      WHERE students.id = interviews.student_id
      AND students.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own interviews"
  ON interviews FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM students
      WHERE students.id = interviews.student_id
      AND students.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update own interviews"
  ON interviews FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM students
      WHERE students.id = interviews.student_id
      AND students.user_id = auth.uid()
    )
  );
