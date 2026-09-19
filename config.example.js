// 환경변수 설정 (예시 파일)
//
// 사용법:
// 1. 이 파일을 config.js로 복사
// 2. .env 파일의 값을 참고하여 아래 빈 문자열을 채우세요
// 3. config.js는 Git에 커밋되지 않습니다
//
// 예시:
// const CONFIG = {
//   SUPABASE_URL: 'https://your-project.supabase.co',
//   SUPABASE_ANON_KEY: 'eyJhbG...',
// };

const CONFIG = {
  SUPABASE_URL: '',  // Supabase 프로젝트 URL
  SUPABASE_ANON_KEY: '',  // Supabase Anon Key

  // Claude API (BYOK 기능용 - 선택사항)
  CLAUDE_API_KEY: '',  // Claude API Key (필요시)
};

// Vercel 환경변수가 있으면 우선 사용
if (typeof window !== 'undefined' && window.__VERCEL_ENV__) {
  CONFIG.SUPABASE_URL = window.__VERCEL_ENV__.SUPABASE_URL || CONFIG.SUPABASE_URL;
  CONFIG.SUPABASE_ANON_KEY = window.__VERCEL_ENV__.SUPABASE_ANON_KEY || CONFIG.SUPABASE_ANON_KEY;
}
