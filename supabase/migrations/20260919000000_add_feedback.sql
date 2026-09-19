-- Add feedback column to interview_sessions table

ALTER TABLE interview_sessions
ADD COLUMN IF NOT EXISTS feedback TEXT;
