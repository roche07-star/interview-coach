-- Add approval system for users

-- approval_status: 'pending' | 'approved' | 'rejected'

-- Create a custom users table to store approval status
CREATE TABLE IF NOT EXISTS user_approvals (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  approval_status TEXT NOT NULL DEFAULT 'pending',
  requested_at TIMESTAMPTZ DEFAULT NOW(),
  approved_at TIMESTAMPTZ,
  approved_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE user_approvals ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view own approval"
  ON user_approvals FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can request approval"
  ON user_approvals FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can view all approvals"
  ON user_approvals FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.email = 'roche07he@gmail.com'
    )
  );

CREATE POLICY "Admins can update approvals"
  ON user_approvals FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.email = 'roche07he@gmail.com'
    )
  );
