-- Phase 2: FREE / 2026 BETA plan, usage limits, coupons, and server-side enforcement.

CREATE TABLE IF NOT EXISTS plans (
  id BIGSERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE CHECK (code IN ('FREE', 'BETA')),
  name TEXT NOT NULL,
  price_krw INTEGER NOT NULL DEFAULT 0 CHECK (price_krw >= 0),
  max_universities INTEGER NOT NULL CHECK (max_universities >= 1),
  question_limit INTEGER,
  interview_limit INTEGER,
  feedback_limit INTEGER,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO plans (code, name, price_krw, max_universities, question_limit, interview_limit, feedback_limit)
VALUES
  ('FREE', '무료 체험', 0, 1, 3, 1, 1),
  ('BETA', '2026 AI 면접코치 베타', 29000, 3, 300, 50, 50)
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  price_krw = EXCLUDED.price_krw,
  max_universities = EXCLUDED.max_universities,
  question_limit = EXCLUDED.question_limit,
  interview_limit = EXCLUDED.interview_limit,
  feedback_limit = EXCLUDED.feedback_limit,
  active = TRUE;

CREATE TABLE IF NOT EXISTS user_plans (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_id BIGINT NOT NULL REFERENCES plans(id),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'expired', 'cancelled')),
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS user_plans_plan_id_idx ON user_plans(plan_id);

CREATE TABLE IF NOT EXISTS usage_events (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  feature TEXT NOT NULL CHECK (feature IN ('questions', 'interview', 'feedback')),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS usage_events_user_feature_created_idx
  ON usage_events(user_id, feature, created_at DESC);

CREATE TABLE IF NOT EXISTS coupons (
  id BIGSERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  plan_id BIGINT NOT NULL REFERENCES plans(id),
  max_uses INTEGER NOT NULL DEFAULT 1 CHECK (max_uses > 0),
  used_count INTEGER NOT NULL DEFAULT 0 CHECK (used_count >= 0),
  duration_days INTEGER NOT NULL DEFAULT 120 CHECK (duration_days > 0),
  expires_at TIMESTAMPTZ,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS
ALTER TABLE plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE usage_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view active plans" ON plans;
CREATE POLICY "Authenticated users can view active plans"
  ON plans FOR SELECT
  USING (auth.uid() IS NOT NULL AND active = TRUE);

DROP POLICY IF EXISTS "Users can view own plan" ON user_plans;
CREATE POLICY "Users can view own plan"
  ON user_plans FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view own usage" ON usage_events;
CREATE POLICY "Users can view own usage"
  ON usage_events FOR SELECT
  USING (auth.uid() = user_id);

-- Coupon contents are intentionally not readable by normal users.
-- Coupon redemption happens through a SECURITY DEFINER RPC.

-- Return the caller's effective plan and create FREE automatically when needed.
CREATE OR REPLACE FUNCTION public.get_my_plan()
RETURNS TABLE (
  code TEXT,
  name TEXT,
  price_krw INTEGER,
  max_universities INTEGER,
  question_limit INTEGER,
  interview_limit INTEGER,
  feedback_limit INTEGER,
  started_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_plan_id BIGINT;
  v_code TEXT;
  v_name TEXT;
  v_price INTEGER;
  v_max_universities INTEGER;
  v_question_limit INTEGER;
  v_interview_limit INTEGER;
  v_feedback_limit INTEGER;
  v_started_at TIMESTAMPTZ;
  v_expires_at TIMESTAMPTZ;
  v_status TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다.';
  END IF;

  SELECT up.plan_id, p.code, p.name, p.price_krw, p.max_universities,
         p.question_limit, p.interview_limit, p.feedback_limit,
         up.started_at, up.expires_at, up.status
    INTO v_plan_id, v_code, v_name, v_price, v_max_universities,
         v_question_limit, v_interview_limit, v_feedback_limit,
         v_started_at, v_expires_at, v_status
    FROM user_plans up
    JOIN plans p ON p.id = up.plan_id
   WHERE up.user_id = v_uid;

  IF NOT FOUND THEN
    SELECT plans.id, plans.code, plans.name, plans.price_krw, plans.max_universities,
           plans.question_limit, plans.interview_limit, plans.feedback_limit
      INTO v_plan_id, v_code, v_name, v_price, v_max_universities,
           v_question_limit, v_interview_limit, v_feedback_limit
      FROM plans WHERE plans.code = 'FREE' AND plans.active = TRUE;

    INSERT INTO user_plans (user_id, plan_id, status)
    VALUES (v_uid, v_plan_id, 'active')
    RETURNING user_plans.started_at, user_plans.expires_at, user_plans.status
      INTO v_started_at, v_expires_at, v_status;
  END IF;

  IF v_expires_at IS NOT NULL AND v_expires_at < NOW() THEN
    SELECT plans.code, plans.name, plans.price_krw, plans.max_universities,
           plans.question_limit, plans.interview_limit, plans.feedback_limit
      INTO v_code, v_name, v_price, v_max_universities,
           v_question_limit, v_interview_limit, v_feedback_limit
      FROM plans WHERE plans.code = 'FREE' AND plans.active = TRUE;
    v_status := 'expired';
  END IF;

  RETURN QUERY SELECT v_code, v_name, v_price, v_max_universities,
    v_question_limit, v_interview_limit, v_feedback_limit,
    v_started_at, v_expires_at, v_status;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_plan() TO authenticated;

-- Atomically reserve usage for an AI-backed feature.
CREATE OR REPLACE FUNCTION public.consume_ai_usage(
  p_feature TEXT,
  p_quantity INTEGER,
  p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS TABLE (
  allowed BOOLEAN,
  plan_code TEXT,
  limit_value INTEGER,
  used_value INTEGER,
  remaining_value INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_plan_id BIGINT;
  v_plan_code TEXT;
  v_limit INTEGER;
  v_used INTEGER;
  v_period_start TIMESTAMPTZ;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  IF p_feature NOT IN ('questions', 'interview', 'feedback') THEN RAISE EXCEPTION '지원하지 않는 기능입니다.'; END IF;
  IF p_quantity IS NULL OR p_quantity < 1 THEN RAISE EXCEPTION '사용량은 1 이상이어야 합니다.'; END IF;

  PERFORM public.get_my_plan();

  SELECT up.plan_id, p.code,
         CASE consume_ai_usage.p_feature
           WHEN 'questions' THEN p.question_limit
           WHEN 'interview' THEN p.interview_limit
           WHEN 'feedback' THEN p.feedback_limit
         END
    INTO v_plan_id, v_plan_code, v_limit
    FROM user_plans up
    JOIN plans p ON p.id = up.plan_id
   WHERE up.user_id = v_uid
   FOR UPDATE;

  SELECT user_plans.started_at INTO v_period_start FROM user_plans WHERE user_plans.user_id = v_uid;

  -- Expired BETA falls back to FREE for usage purposes.
  IF v_plan_code IS NULL THEN RAISE EXCEPTION '플랜을 찾을 수 없습니다.'; END IF;
  IF EXISTS (
    SELECT 1 FROM user_plans
     WHERE user_plans.user_id = v_uid AND user_plans.expires_at IS NOT NULL AND user_plans.expires_at < NOW()
  ) THEN
    SELECT plans.id, plans.code,
           CASE consume_ai_usage.p_feature
             WHEN 'questions' THEN plans.question_limit
             WHEN 'interview' THEN plans.interview_limit
             WHEN 'feedback' THEN plans.feedback_limit
           END
      INTO v_plan_id, v_plan_code, v_limit
      FROM plans WHERE plans.code = 'FREE';
    SELECT user_plans.expires_at INTO v_period_start FROM user_plans WHERE user_plans.user_id = v_uid;
  END IF;

  SELECT COALESCE(SUM(usage_events.quantity), 0)::INTEGER
    INTO v_used
    FROM usage_events
   WHERE usage_events.user_id = v_uid
     AND usage_events.feature = consume_ai_usage.p_feature
     AND usage_events.created_at >= COALESCE(v_period_start, '1970-01-01'::timestamptz);

  IF v_limit IS NOT NULL AND v_used + p_quantity > v_limit THEN
    RETURN QUERY SELECT FALSE, v_plan_code, v_limit, v_used, GREATEST(v_limit - v_used, 0);
    RETURN;
  END IF;

  INSERT INTO usage_events (user_id, feature, quantity, metadata)
  VALUES (v_uid, p_feature, p_quantity, COALESCE(p_metadata, '{}'::jsonb));

  RETURN QUERY SELECT TRUE, v_plan_code, v_limit, v_used + p_quantity,
    CASE WHEN v_limit IS NULL THEN NULL ELSE GREATEST(v_limit - (v_used + p_quantity), 0) END;
END;
$$;

GRANT EXECUTE ON FUNCTION public.consume_ai_usage(TEXT, INTEGER, JSONB) TO authenticated;

-- Interview sessions must be created through this function so the interview quota
-- cannot be bypassed by inserting directly into the table.
CREATE OR REPLACE FUNCTION public.create_interview_session_with_usage(
  p_student_id UUID,
  p_mode TEXT,
  p_question_count INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_allowed BOOLEAN;
  v_session_id INTEGER;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  IF NOT EXISTS (SELECT 1 FROM students WHERE id = p_student_id AND user_id = v_uid) THEN
    RAISE EXCEPTION '접근할 수 없는 학생부입니다.';
  END IF;

  SELECT allowed INTO v_allowed
    FROM public.consume_ai_usage('interview', 1, jsonb_build_object('mode', p_mode, 'question_count', p_question_count));

  IF NOT v_allowed THEN RAISE EXCEPTION '면접 연습 이용 한도를 초과했습니다.'; END IF;

  INSERT INTO interview_sessions (student_id, mode, question_count, status)
  VALUES (p_student_id, p_mode, p_question_count, 'in_progress')
  RETURNING id INTO v_session_id;

  RETURN v_session_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_interview_session_with_usage(UUID, TEXT, INTEGER) TO authenticated;

-- Enforce the university limit server-side. Multiple records for the same
-- university are allowed; only distinct universities count toward the limit.
CREATE OR REPLACE FUNCTION public.enforce_student_university_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_limit INTEGER;
  v_count INTEGER;
BEGIN
  SELECT max_universities INTO v_limit
    FROM public.get_my_plan();

  SELECT COUNT(DISTINCT university)::INTEGER INTO v_count
    FROM students
   WHERE user_id = NEW.user_id
     AND id <> COALESCE(NEW.id, gen_random_uuid())
     AND university IS NOT NULL
     AND BTRIM(university) <> '';

  IF NOT EXISTS (
    SELECT 1 FROM students
     WHERE user_id = NEW.user_id
       AND id <> COALESCE(NEW.id, gen_random_uuid())
       AND university = NEW.university
  ) AND v_count >= v_limit THEN
    RAISE EXCEPTION '현재 플랜에서는 최대 %개 대학까지 등록할 수 있습니다.', v_limit;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS students_university_limit_trigger ON students;
CREATE TRIGGER students_university_limit_trigger
BEFORE INSERT OR UPDATE OF university ON students
FOR EACH ROW EXECUTE FUNCTION public.enforce_student_university_limit();

-- Prevent direct session inserts; the RPC above is the controlled path.
DROP POLICY IF EXISTS "Users can insert own sessions" ON interview_sessions;

-- Coupon redemption. Normal users cannot read coupon rows directly.
CREATE OR REPLACE FUNCTION public.redeem_coupon(p_code TEXT)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT,
  plan_code TEXT,
  expires_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_coupon RECORD;
  v_expires TIMESTAMPTZ;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  IF p_code IS NULL OR BTRIM(p_code) = '' THEN
    RETURN QUERY SELECT FALSE, '쿠폰 코드를 입력하세요.', NULL::TEXT, NULL::TIMESTAMPTZ;
    RETURN;
  END IF;

  SELECT * INTO v_coupon
    FROM coupons
   WHERE UPPER(code) = UPPER(BTRIM(p_code))
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE, '유효하지 않은 쿠폰입니다.', NULL::TEXT, NULL::TIMESTAMPTZ;
    RETURN;
  END IF;
  IF NOT v_coupon.active THEN
    RETURN QUERY SELECT FALSE, '비활성화된 쿠폰입니다.', NULL::TEXT, NULL::TIMESTAMPTZ;
    RETURN;
  END IF;
  IF v_coupon.expires_at IS NOT NULL AND v_coupon.expires_at < NOW() THEN
    RETURN QUERY SELECT FALSE, '만료된 쿠폰입니다.', NULL::TEXT, NULL::TIMESTAMPTZ;
    RETURN;
  END IF;
  IF v_coupon.used_count >= v_coupon.max_uses THEN
    RETURN QUERY SELECT FALSE, '사용 한도가 모두 소진된 쿠폰입니다.', NULL::TEXT, NULL::TIMESTAMPTZ;
    RETURN;
  END IF;

  v_expires := NOW() + make_interval(days => v_coupon.duration_days);

  INSERT INTO user_plans (user_id, plan_id, status, started_at, expires_at, updated_at)
  VALUES (v_uid, v_coupon.plan_id, 'active', NOW(), v_expires, NOW())
  ON CONFLICT (user_id) DO UPDATE SET
    plan_id = EXCLUDED.plan_id,
    status = 'active',
    started_at = EXCLUDED.started_at,
    expires_at = EXCLUDED.expires_at,
    updated_at = NOW();

  UPDATE coupons SET used_count = used_count + 1 WHERE id = v_coupon.id;

  RETURN QUERY
    SELECT TRUE, '베타 플랜이 활성화되었습니다.', p.code, v_expires
      FROM plans p WHERE p.id = v_coupon.plan_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.redeem_coupon(TEXT) TO authenticated;

-- Lightweight usage summary for the current user. The app uses this only for UX;
-- enforcement remains in consume_ai_usage/create_interview_session_with_usage.
CREATE OR REPLACE FUNCTION public.get_my_usage()
RETURNS TABLE (
  questions_used INTEGER,
  interview_used INTEGER,
  feedback_used INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_period_start TIMESTAMPTZ;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;

  SELECT started_at INTO v_period_start FROM user_plans WHERE user_id = v_uid;
  IF EXISTS (SELECT 1 FROM user_plans WHERE user_id = v_uid AND expires_at IS NOT NULL AND expires_at < NOW()) THEN
    SELECT expires_at INTO v_period_start FROM user_plans WHERE user_id = v_uid;
  END IF;

  RETURN QUERY SELECT
    COALESCE((SELECT SUM(quantity)::INTEGER FROM usage_events WHERE user_id = v_uid AND feature = 'questions' AND created_at >= COALESCE(v_period_start, '1970-01-01'::timestamptz)), 0),
    COALESCE((SELECT SUM(quantity)::INTEGER FROM usage_events WHERE user_id = v_uid AND feature = 'interview' AND created_at >= COALESCE(v_period_start, '1970-01-01'::timestamptz)), 0),
    COALESCE((SELECT SUM(quantity)::INTEGER FROM usage_events WHERE user_id = v_uid AND feature = 'feedback' AND created_at >= COALESCE(v_period_start, '1970-01-01'::timestamptz)), 0);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_usage() TO authenticated;

-- Admin helper for creating beta coupons without exposing the coupons table.
CREATE OR REPLACE FUNCTION public.admin_create_coupon(
  p_code TEXT,
  p_max_uses INTEGER DEFAULT 50,
  p_duration_days INTEGER DEFAULT 120,
  p_expires_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id BIGINT;
  v_admin_email TEXT := auth.jwt() ->> 'email';
  v_beta_plan_id BIGINT;
BEGIN
  IF v_admin_email <> 'ziron7@gmail.com' THEN
    RAISE EXCEPTION '관리자 권한이 없습니다.';
  END IF;
  IF p_code IS NULL OR BTRIM(p_code) = '' THEN
    RAISE EXCEPTION '쿠폰 코드를 입력하세요.';
  END IF;

  SELECT id INTO v_beta_plan_id FROM plans WHERE code = 'BETA' AND active = TRUE;
  IF v_beta_plan_id IS NULL THEN RAISE EXCEPTION 'BETA 플랜이 없습니다.'; END IF;

  INSERT INTO coupons (code, plan_id, max_uses, duration_days, expires_at, active)
  VALUES (UPPER(BTRIM(p_code)), v_beta_plan_id, p_max_uses, p_duration_days, p_expires_at, TRUE)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_create_coupon(TEXT, INTEGER, INTEGER, TIMESTAMPTZ) TO authenticated;
