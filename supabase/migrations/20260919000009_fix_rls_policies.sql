-- Fix RLS Policies - Add missing policies for coupons and other tables

-- ============================================================================
-- 1. COUPONS TABLE - Admin-only policies
-- ============================================================================

-- Admin can view coupons
DROP POLICY IF EXISTS "Admin can view coupons" ON coupons;
CREATE POLICY "Admin can view coupons"
  ON coupons FOR SELECT
  USING (
    auth.jwt() ->> 'email' IN ('ziron7@gmail.com', 'roche07he@gmail.com')
  );

-- Admin can insert coupons
DROP POLICY IF EXISTS "Admin can insert coupons" ON coupons;
CREATE POLICY "Admin can insert coupons"
  ON coupons FOR INSERT
  WITH CHECK (
    auth.jwt() ->> 'email' IN ('ziron7@gmail.com', 'roche07he@gmail.com')
  );

-- Admin can update coupons
DROP POLICY IF EXISTS "Admin can update coupons" ON coupons;
CREATE POLICY "Admin can update coupons"
  ON coupons FOR UPDATE
  USING (
    auth.jwt() ->> 'email' IN ('ziron7@gmail.com', 'roche07he@gmail.com')
  );

-- ============================================================================
-- 2. USER_PLANS TABLE - Insert/Update policies for RPC functions
-- ============================================================================

-- Users can insert own plan (via RPC only - redeem_coupon)
DROP POLICY IF EXISTS "Users can insert own plan" ON user_plans;
CREATE POLICY "Users can insert own plan"
  ON user_plans FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update own plan (via RPC only - redeem_coupon)
DROP POLICY IF EXISTS "Users can update own plan" ON user_plans;
CREATE POLICY "Users can update own plan"
  ON user_plans FOR UPDATE
  USING (auth.uid() = user_id);

-- ============================================================================
-- 3. USAGE_EVENTS TABLE - Insert policy for consumption tracking
-- ============================================================================

-- Users can insert own usage events (via RPC only - consume_ai_usage)
DROP POLICY IF EXISTS "Users can insert own usage" ON usage_events;
CREATE POLICY "Users can insert own usage"
  ON usage_events FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- 4. ANALYTICS_EVENTS TABLE - Insert policy
-- ============================================================================

-- Users can insert own analytics events (via RPC - log_analytics_event)
DROP POLICY IF EXISTS "Users can insert own analytics" ON analytics_events;
CREATE POLICY "Users can insert own analytics"
  ON analytics_events FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- 5. FEEDBACK TABLE - Ensure policies exist
-- ============================================================================

-- Enable RLS on feedback table (if not already)
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;

-- Users can view own feedback
DROP POLICY IF EXISTS "Users can view own feedback" ON feedback;
CREATE POLICY "Users can view own feedback"
  ON feedback FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM interview_sessions
      WHERE interview_sessions.id = feedback.session_id
        AND EXISTS (
          SELECT 1 FROM students
          WHERE students.id = interview_sessions.student_id
            AND students.user_id = auth.uid()
        )
    )
  );

-- Users can insert own feedback
DROP POLICY IF EXISTS "Users can insert own feedback" ON feedback;
CREATE POLICY "Users can insert own feedback"
  ON feedback FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM interview_sessions
      WHERE interview_sessions.id = session_id
        AND EXISTS (
          SELECT 1 FROM students
          WHERE students.id = interview_sessions.student_id
            AND students.user_id = auth.uid()
        )
    )
  );

-- ============================================================================
-- 6. COUPON_REDEMPTIONS TABLE - User can insert own redemptions
-- ============================================================================

-- Users can insert own coupon redemptions (via RPC - redeem_coupon)
DROP POLICY IF EXISTS "Users can insert own redemptions" ON coupon_redemptions;
CREATE POLICY "Users can insert own redemptions"
  ON coupon_redemptions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- 검증: 모든 테이블의 RLS 상태 확인
-- ============================================================================

-- 다음 쿼리로 RLS 정책 확인 가능:
-- SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public';
-- SELECT * FROM pg_policies WHERE schemaname = 'public';
