# Phase 1 적용 안내

이번 변경은 `FREE/BETA` 과금 기능을 아직 추가하지 않고, 그 전에 필요한 인증/보안/기존 면접 저장 안정화를 적용합니다.

## 변경 파일

- `supabase/functions/ai-proxy/index.ts`
  - Authorization Bearer 토큰 필수
  - Supabase `auth.getUser()`로 사용자 검증
  - `user_approvals`에서 승인 상태 서버 검증
  - 승인되지 않은 사용자의 AI 호출 차단
  - `max_tokens` 1~20000 범위 검증
  - AI provider/API 오류를 적절한 HTTP 상태로 반환

- `supabase/migrations/20260919000005_security_fix.sql`
  - `interview_sessions` UPDATE RLS 추가
  - 본인 소유 세션만 업데이트 가능하도록 WITH CHECK 추가

## 적용 전 확인

Supabase Edge Function 환경변수에 다음이 설정되어 있어야 합니다.

- `ANTHROPIC_API_KEY`
- `OPENAI_API_KEY` (OpenAI를 사용하는 경우)
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

API Key는 소스코드나 Git에 넣지 않습니다.

## 적용 순서

### 1. Supabase Migration 실행

```bash
# Supabase CLI가 설치되어 있다면
supabase db push

# 또는 Supabase 대시보드에서 SQL Editor로 직접 실행
# supabase/migrations/20260919000005_security_fix.sql 내용 복사
```

### 2. ai-proxy Edge Function 재배포

```bash
# Supabase CLI로 배포
supabase functions deploy ai-proxy

# 또는 Supabase 대시보드에서:
# Edge Functions → ai-proxy → Deploy new version
```

### 3. Supabase Edge Function 환경변수 설정 확인

Supabase Dashboard → Edge Functions → ai-proxy → Settings → Environment Variables

필수:
- `ANTHROPIC_API_KEY`: Claude API 키
- `SUPABASE_URL`: Supabase 프로젝트 URL
- `SUPABASE_ANON_KEY`: Supabase Anon Key

선택 (OpenAI 사용 시):
- `OPENAI_API_KEY`: OpenAI API 키

### 4. 테스트

#### ✅ 정상 동작 테스트
1. 로그인된 승인 계정으로 학생부 저장 테스트
2. 질문 생성 테스트
3. 모의면접 시작/완료 테스트
4. 피드백 저장 테스트

#### ⚠️ 보안 테스트
1. 미로그인 상태에서 AI 요청 → **401 Unauthorized** 예상
2. 승인 대기 계정에서 AI 요청 → **403 Forbidden** 예상
3. 탈퇴 계정에서 AI 요청 → **403 Forbidden** 예상

## 다음 Phase

Phase 1이 정상 동작한 뒤 다음으로 아래를 추가합니다.

- `plans` 테이블 (FREE, BETA, PRO 등)
- `user_plans` 테이블
- `usage_events` 테이블
- FREE 플랜 제한
- 2026 BETA 플랜
- 베타 쿠폰
- 관리자 플랜 관리

결제 연동은 그 다음 단계입니다.

## 롤백 방법

문제가 발생하면:

### 1. Edge Function 롤백
```bash
# 이전 버전으로 롤백
# Supabase Dashboard → Edge Functions → ai-proxy → Deployments
# 이전 버전 선택 → Redeploy
```

### 2. Migration 롤백
```sql
-- 20260919000005_security_fix.sql 롤백
DROP POLICY IF EXISTS "Users can update own sessions" ON interview_sessions;

-- 이전 정책 복원 (있었다면)
```

## 문제 해결

### 401 Unauthorized
- 로그인 세션이 유효한지 확인
- Authorization 헤더가 전송되는지 확인

### 403 Forbidden
- user_approvals 테이블에서 approval_status 확인
- 관리자 페이지에서 승인 처리

### 500 Internal Server Error
- Edge Function 로그 확인 (Supabase Dashboard → Edge Functions → Logs)
- 환경변수 설정 확인
- API 키 유효성 확인
