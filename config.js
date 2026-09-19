// 환경변수 설정
// ⚠️ 이 파일은 Git에 커밋되지 않습니다 (.gitignore에 등록됨)

const CONFIG = {
  SUPABASE_URL: 'https://uflotegcmhkfocvszncd.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVmbG90ZWdjbWhrZm9jdnN6bmNkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkyODE2NDksImV4cCI6MjEwNDg1NzY0OX0.zgeE4lgiy1qnynWFcABLLRG09SrFv1zXdtNhWed39_M',

  // Claude API (BYOK 기능용 - 선택사항)
  CLAUDE_API_KEY: '',
};

// Vercel 환경변수가 있으면 우선 사용
if (typeof window !== 'undefined' && window.__VERCEL_ENV__) {
  CONFIG.SUPABASE_URL = window.__VERCEL_ENV__.SUPABASE_URL || CONFIG.SUPABASE_URL;
  CONFIG.SUPABASE_ANON_KEY = window.__VERCEL_ENV__.SUPABASE_ANON_KEY || CONFIG.SUPABASE_ANON_KEY;
}
