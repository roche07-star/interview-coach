-- Phase 1 security/stability fixes for interview-coach
-- 1) Allow users to update their own interview sessions.
--    app.html updates status/completed_at and feedback after an interview.
-- 2) Add an explicit WITH CHECK so a session cannot be reassigned to another student.

DROP POLICY IF EXISTS "Users can update own sessions" ON interview_sessions;

CREATE POLICY "Users can update own sessions"
  ON interview_sessions FOR UPDATE
  USING (
    EXISTS (
      SELECT 1
      FROM students
      WHERE students.id = interview_sessions.student_id
        AND students.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM students
      WHERE students.id = interview_sessions.student_id
        AND students.user_id = auth.uid()
    )
  );
