# Phase 2 적용 가이드 — FREE / 2026 BETA

이번 단계는 결제 연동 전의 시장검증 구조입니다.

## 1. 적용 파일

- `supabase/migrations/20260919000006_plans_usage_beta.sql`
- `supabase/functions/ai-proxy/index.ts`
- `app.html`

## 2. Supabase Migration 적용

Supabase Dashboard → SQL Editor에서 migration 파일 내용을 실행하거나, 프로젝트의 migration 배포 절차로 적용합니다.

생성되는 핵심 구조:

- `plans`: FREE / BETA
- `user_plans`: 사용자별 현재 플랜
- `usage_events`: 질문/면접/피드백 사용량
- `coupons`: 베타 코드
- `get_my_plan()`
- `get_my_usage()`
- `consume_ai_usage()`
- `create_interview_session_with_usage()`
- `redeem_coupon()`
- `admin_create_coupon()`

## 3. Edge Function 재배포

`supabase/functions/ai-proxy/index.ts`를 재배포합니다.

이제 AI 요청에는 다음 정보가 반드시 포함됩니다.

- `usage_feature`: `questions` / `feedback`
- `usage_quantity`: 사용량

면접 세션은 `create_interview_session_with_usage()`에서 서버 측으로 사용량을 차감합니다.

## 4. 테스트용 베타 쿠폰 생성

관리자 계정으로 로그인한 상태에서 Supabase SQL Editor에서 다음을 실행할 수 있습니다.

```sql
select public.admin_create_coupon('BETA2026-TEST', 50, 120, null);
```

그 후 앱에서 **🎟️ 베타 코드**를 눌러 `BETA2026-TEST`를 입력합니다.

> 실제 고객에게 배포하기 전에는 테스트 쿠폰을 비활성화하거나 별도의 고객용 코드를 생성하세요.

## 5. FREE 플랜

- 등록 가능 대학: 1개
- AI 질문: 3개
- 면접: 1회
- AI 피드백: 1회
- 질문 선택 UI: 3개만 노출
- 전체 면접 버튼은 숨김

## 6. BETA 플랜

- 가격 기준: 29,000원
- 등록 가능 대학: 3개
- AI 질문: 최대 1,000개(검증 단계에서 사실상 무제한)
- 면접: 100회
- AI 피드백: 100회
- 질문: 10/20/30개 선택
- 전체 면접 사용 가능

## 7. 결제는 아직 연결하지 않음

현재는 쿠폰으로 BETA를 활성화합니다.

실제 결제 연동은 다음 단계에서 진행합니다.

`결제 성공 → BETA 자동 활성화`

## 8. 반드시 테스트할 것

1. 신규 승인 사용자 → FREE 자동 생성
2. 질문 3개 생성 → FREE 질문 한도 소진
3. 질문 4개 추가 생성 → 서버에서 차단
4. 면접 1회 → FREE 면접 한도 소진
5. 두 번째 면접 → 서버에서 차단
6. 피드백 1회 → FREE 피드백 한도 소진
7. 두 번째 피드백 → 서버에서 차단
8. BETA 쿠폰 적용 → BETA 표시
9. BETA에서 대학 3개 등록 → 성공
10. BETA에서 4번째 대학 등록 → 서버에서 차단
11. BETA에서 질문 10/20/30개 생성
12. 승인되지 않은 계정의 AI 호출 → 403
13. 다른 사용자의 student/session 접근 → RLS 차단

## 9. 주의

`.env`, API Key, Supabase service role key는 저장소나 압축파일에 포함하지 마세요.
