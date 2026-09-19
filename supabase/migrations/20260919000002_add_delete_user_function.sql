-- RPC function to allow users to delete their own account

CREATE OR REPLACE FUNCTION delete_current_user()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- 현재 사용자의 계정을 삭제
  -- user_approvals는 CASCADE로 자동 삭제됨
  -- interview_sessions도 CASCADE로 자동 삭제됨
  DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;

-- 모든 인증된 사용자가 이 함수를 호출할 수 있도록 권한 부여
GRANT EXECUTE ON FUNCTION delete_current_user() TO authenticated;
