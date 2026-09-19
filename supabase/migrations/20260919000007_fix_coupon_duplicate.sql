-- 쿠폰 중복 사용 방지 (사용 이력 추적)

-- 1. 쿠폰 사용 이력 테이블 생성
CREATE TABLE IF NOT EXISTS coupon_redemptions (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  coupon_id BIGINT NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
  redeemed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, coupon_id)  -- 한 사용자당 하나의 쿠폰만
);

CREATE INDEX idx_coupon_redemptions_user ON coupon_redemptions(user_id);
CREATE INDEX idx_coupon_redemptions_coupon ON coupon_redemptions(coupon_id);

-- RLS 정책
ALTER TABLE coupon_redemptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own redemptions" ON coupon_redemptions;
CREATE POLICY "Users can view own redemptions"
  ON coupon_redemptions FOR SELECT
  USING (auth.uid() = user_id);

-- 2. redeem_coupon 함수 수정 (중복 사용 방지)
DROP FUNCTION IF EXISTS public.redeem_coupon(TEXT);

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
  v_already_used BOOLEAN;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  IF p_code IS NULL OR BTRIM(p_code) = '' THEN
    RETURN QUERY SELECT FALSE, '쿠폰 코드를 입력하세요.', NULL::TEXT, NULL::TIMESTAMPTZ;
    RETURN;
  END IF;

  SELECT * INTO v_coupon
    FROM coupons
   WHERE UPPER(coupons.code) = UPPER(BTRIM(p_code))
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

  -- 🆕 중복 사용 체크
  SELECT EXISTS(
    SELECT 1 FROM coupon_redemptions
     WHERE coupon_redemptions.user_id = v_uid
       AND coupon_redemptions.coupon_id = v_coupon.id
  ) INTO v_already_used;

  IF v_already_used THEN
    RETURN QUERY SELECT FALSE, '이미 사용한 쿠폰입니다.', NULL::TEXT, NULL::TIMESTAMPTZ;
    RETURN;
  END IF;

  v_expires := NOW() + make_interval(days => v_coupon.duration_days);

  -- 플랜 업데이트
  INSERT INTO user_plans (user_id, plan_id, status, started_at, expires_at, updated_at)
  VALUES (v_uid, v_coupon.plan_id, 'active', NOW(), v_expires, NOW())
  ON CONFLICT (user_id) DO UPDATE SET
    plan_id = EXCLUDED.plan_id,
    status = 'active',
    started_at = EXCLUDED.started_at,
    expires_at = EXCLUDED.expires_at,
    updated_at = NOW();

  -- 쿠폰 사용 횟수 증가
  UPDATE coupons SET used_count = coupons.used_count + 1 WHERE coupons.id = v_coupon.id;

  -- 🆕 사용 이력 기록
  INSERT INTO coupon_redemptions (user_id, coupon_id)
  VALUES (v_uid, v_coupon.id);

  RETURN QUERY
    SELECT TRUE, '베타 플랜이 활성화되었습니다.', p.code, v_expires
      FROM plans p WHERE p.id = v_coupon.plan_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.redeem_coupon(TEXT) TO authenticated;
