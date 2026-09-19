-- Admin function to permanently delete a user

CREATE OR REPLACE FUNCTION admin_delete_user(target_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- 관리자만 실행 가능
  IF (auth.jwt() ->> 'email') != 'ziron7@gmail.com' THEN
    RAISE EXCEPTION 'Unauthorized: Only admin can delete users';
  END IF;

  -- user_approvals에서 삭제 (CASCADE로 관련 데이터 자동 삭제)
  DELETE FROM user_approvals WHERE user_id = target_user_id;

  -- auth.users에서 삭제
  DELETE FROM auth.users WHERE id = target_user_id;
END;
$$;

-- 관리자에게 실행 권한 부여
GRANT EXECUTE ON FUNCTION admin_delete_user(UUID) TO authenticated;
