-- Phase 3: UX funnel, analytics events, and admin plan/usage dashboard

CREATE TABLE IF NOT EXISTS analytics_events (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  event_name TEXT NOT NULL CHECK (length(trim(event_name)) > 0),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS analytics_events_user_created_idx ON analytics_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS analytics_events_name_created_idx ON analytics_events(event_name, created_at DESC);
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own analytics events" ON analytics_events;
CREATE POLICY "Users can view own analytics events" ON analytics_events FOR SELECT USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.log_analytics_event(p_event_name TEXT, p_metadata JSONB DEFAULT '{}'::jsonb)
RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_uid UUID := auth.uid(); v_id BIGINT;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  IF p_event_name IS NULL OR BTRIM(p_event_name) = '' THEN RAISE EXCEPTION '이벤트명이 필요합니다.'; END IF;
  INSERT INTO analytics_events(user_id,event_name,metadata) VALUES(v_uid,BTRIM(p_event_name),COALESCE(p_metadata,'{}'::jsonb)) RETURNING id INTO v_id;
  RETURN v_id;
END; $$;
GRANT EXECUTE ON FUNCTION public.log_analytics_event(TEXT, JSONB) TO authenticated;

-- Admin-only plan/usage summary. No auth.users table access is exposed to the browser.
CREATE OR REPLACE FUNCTION public.admin_get_user_plan_usage()
RETURNS TABLE(
  user_id UUID,
  email TEXT,
  approval_status TEXT,
  plan_code TEXT,
  plan_name TEXT,
  started_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  questions_used INTEGER,
  interview_used INTEGER,
  feedback_used INTEGER,
  last_activity_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_admin_email TEXT := auth.jwt() ->> 'email';
BEGIN
  IF v_admin_email NOT IN ('ziron7@gmail.com', 'roche07he@gmail.com') THEN RAISE EXCEPTION '관리자 권한이 없습니다.'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT ua.user_id, ua.email, ua.approval_status,
           COALESCE(p.code,'FREE') AS plan_code,
           COALESCE(p.name,'무료 체험') AS plan_name,
           up.started_at, up.expires_at
      FROM user_approvals ua
      LEFT JOIN user_plans up ON up.user_id=ua.user_id
      LEFT JOIN plans p ON p.id=up.plan_id
     WHERE ua.email <> v_admin_email AND ua.deleted_at IS NULL
  ), usage AS (
    SELECT ue.user_id,
      SUM(ue.quantity) FILTER (WHERE ue.feature='questions')::INTEGER AS questions_used,
      SUM(ue.quantity) FILTER (WHERE ue.feature='interview')::INTEGER AS interview_used,
      SUM(ue.quantity) FILTER (WHERE ue.feature='feedback')::INTEGER AS feedback_used,
      MAX(ue.created_at) AS last_activity_at
    FROM usage_events ue GROUP BY ue.user_id
  )
  SELECT b.user_id,b.email,b.approval_status,b.plan_code,b.plan_name,b.started_at,b.expires_at,
         COALESCE(u.questions_used,0),COALESCE(u.interview_used,0),COALESCE(u.feedback_used,0),u.last_activity_at
    FROM base b LEFT JOIN usage u ON u.user_id=b.user_id
   ORDER BY COALESCE(u.last_activity_at,b.started_at) DESC NULLS LAST;
END; $$;
GRANT EXECUTE ON FUNCTION public.admin_get_user_plan_usage() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_get_funnel_stats()
RETURNS TABLE(event_name TEXT,event_count BIGINT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_admin_email TEXT := auth.jwt() ->> 'email';
BEGIN
  IF v_admin_email NOT IN ('ziron7@gmail.com', 'roche07he@gmail.com') THEN RAISE EXCEPTION '관리자 권한이 없습니다.'; END IF;
  RETURN QUERY SELECT ae.event_name, COUNT(*)::BIGINT FROM analytics_events ae
   LEFT JOIN user_approvals ua ON ua.user_id=ae.user_id
  WHERE COALESCE(ua.email,'') <> v_admin_email GROUP BY ae.event_name ORDER BY COUNT(*) DESC;
END; $$;
GRANT EXECUTE ON FUNCTION public.admin_get_funnel_stats() TO authenticated;
