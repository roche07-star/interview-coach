-- Add deleted_at column to user_approvals for soft delete

ALTER TABLE user_approvals
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- RPC function to request account deletion (soft delete)
CREATE OR REPLACE FUNCTION request_account_deletion()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- 현재 사용자의 탈퇴 요청 기록
  UPDATE user_approvals
  SET deleted_at = NOW()
  WHERE user_id = auth.uid();
END;
$$;

-- 모든 인증된 사용자가 이 함수를 호출할 수 있도록 권한 부여
GRANT EXECUTE ON FUNCTION request_account_deletion() TO authenticated;
