-- Create user inquiries table

CREATE TABLE IF NOT EXISTS user_inquiries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  subject TEXT NOT NULL,
  message TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  answered_at TIMESTAMPTZ,
  answer TEXT
);

-- Enable RLS
ALTER TABLE user_inquiries ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Anyone can insert inquiry"
  ON user_inquiries FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Admins can view all inquiries"
  ON user_inquiries FOR SELECT
  USING (
    (auth.jwt() ->> 'email') = 'roche07he@gmail.com'
  );

CREATE POLICY "Admins can update inquiries"
  ON user_inquiries FOR UPDATE
  USING (
    (auth.jwt() ->> 'email') = 'roche07he@gmail.com'
  );

CREATE POLICY "Admins can delete inquiries"
  ON user_inquiries FOR DELETE
  USING (
    (auth.jwt() ->> 'email') = 'roche07he@gmail.com'
  );
