# Interview Coach - Enhancement 개선 계획

**검토일**: 2026-09-19
**현재 버전**: Phase 3 (사용량 대시보드 + 온보딩 + 관리자 통계)

---

## 🔴 **High Priority (즉시 수정 필요)**

### 1. **보안 취약점**

#### 1.1 admin.html - 관리자 이메일 필터 미완료
**위치**: `admin.html:721, 777, 942`
```javascript
// 현재 (잘못됨)
.neq('email', ADMIN_EMAIL)  // ADMIN_EMAIL 변수 없음

// 수정 필요
.not('email', 'in', `(${ADMIN_EMAILS.map(e => `"${e}"`).join(',')})`)
```
**영향**: 관리자 목록에 잘못된 데이터 표시
**우선순위**: ⭐⭐⭐⭐⭐

#### 1.2 RLS 정책 누락
**위치**: `supabase/migrations/20260919000007_fix_coupon_duplicate.sql`
- coupons 테이블 INSERT 정책 누락 가능성
- Edge Function ai-proxy에서 사용량 체크 우회 가능성

**수정 필요**:
```sql
-- coupons 테이블 RLS 정책 확인 및 추가
DROP POLICY IF EXISTS "Admin can insert coupons" ON coupons;
CREATE POLICY "Admin can insert coupons"
  ON coupons FOR INSERT
  WITH CHECK (
    auth.jwt() ->> 'email' IN ('ziron7@gmail.com', 'roche07he@gmail.com')
  );
```
**우선순위**: ⭐⭐⭐⭐⭐

#### 1.3 SQL Injection 방지
**위치**: `admin.html` - 동적 쿼리 생성
```javascript
// 현재
.not('email', 'in', `(${ADMIN_EMAILS.map(e => `"${e}"`).join(',')})`)

// 개선: Prepared statement 사용 (Supabase SDK 제한으로 현재 방식 유지)
// 하지만 ADMIN_EMAILS가 코드에서 정의되므로 안전함
```
**우선순위**: ⭐⭐⭐

---

## 🟡 **Medium Priority (1주일 내 개선)**

### 2. **성능 최적화**

#### 2.1 app.html 파일 크기 (1832줄)
**문제**: 하나의 파일에 모든 로직
**개선 방안**:
```
app.html (1832줄)
  ↓ 분리
├─ app.html (HTML 구조만, ~500줄)
├─ app.js (JavaScript 로직, ~1000줄)
└─ app.css (스타일, ~300줄)
```
**장점**: 캐싱, 유지보수성, 로딩 속도
**우선순위**: ⭐⭐⭐⭐

#### 2.2 중복 코드 제거
**위치**: `app.html`, `admin.html`
```javascript
// 중복 1: Supabase 초기화
// app.html, admin.html, login.html 모두 동일한 코드

// 중복 2: Toast 알림
// 동일한 showToast 함수가 여러 파일에 존재

// 개선: 공통 모듈화
// common.js 파일 생성
```
**우선순위**: ⭐⭐⭐

#### 2.3 이미지 최적화
**위치**: 없음 (현재 이미지 사용 안 함)
**개선**: 로고, 아이콘 SVG로 변경 (Lucide 사용 중이므로 OK)
**우선순위**: ⭐

---

### 3. **UX/UI 개선**

#### 3.1 로딩 상태 표시
**위치**: `app.html` - AI 요청 중
```javascript
// 현재: 버튼 비활성화만
// 개선: 스피너 + 진행 메시지
<div class="loading-spinner">
  <div class="spinner"></div>
  <p>AI가 질문을 생성하고 있습니다... (약 10초 소요)</p>
</div>
```
**우선순위**: ⭐⭐⭐⭐

#### 3.2 에러 메시지 개선
**위치**: `app.html`, `admin.html`
```javascript
// 현재
showToast('error', '오류가 발생했습니다.');

// 개선
showToast('error', '질문 생성에 실패했습니다. 생기부를 먼저 저장해주세요.');
```
**우선순위**: ⭐⭐⭐⭐

#### 3.3 반응형 디자인
**위치**: `app.html`, `admin.html`
```css
/* 현재: 모바일 최적화 부족 */

/* 개선 필요 */
@media (max-width: 768px) {
  .navbar { flex-direction: column; }
  .nav-actions { width: 100%; justify-content: space-around; }
  .usage-grid { grid-template-columns: 1fr; }
}
```
**우선순위**: ⭐⭐⭐

#### 3.4 접근성 (Accessibility)
**위치**: 모든 HTML 파일
```html
<!-- 현재: aria-label 누락 -->
<button onclick="showPlanInfo()">플랜 확인</button>

<!-- 개선 -->
<button onclick="showPlanInfo()" aria-label="현재 플랜 및 사용량 확인">플랜 확인</button>
```
**우선순위**: ⭐⭐⭐

---

### 4. **코드 품질**

#### 4.1 TypeScript 도입
**현재**: Vanilla JavaScript
**개선**: TypeScript로 마이그레이션
```typescript
// types.ts
interface User {
  id: string;
  email: string;
  plan: 'FREE' | 'BETA';
}

interface UsageStats {
  questions_used: number;
  interview_used: number;
  feedback_used: number;
}
```
**우선순위**: ⭐⭐

#### 4.2 ESLint 설정
**현재**: 없음
**개선**: `.eslintrc.json` 추가
```json
{
  "extends": ["eslint:recommended"],
  "env": {
    "browser": true,
    "es2021": true
  },
  "rules": {
    "no-unused-vars": "warn",
    "no-console": "off"
  }
}
```
**우선순위**: ⭐⭐

#### 4.3 주석 및 문서화
**위치**: 모든 JavaScript 함수
```javascript
// 현재: 주석 부족

// 개선: JSDoc 스타일
/**
 * 플랜 정보를 로드하고 UI를 업데이트합니다.
 * @returns {Promise<void>}
 * @throws {Error} Supabase 연결 실패 시
 */
async function loadPlanState() {
  // ...
}
```
**우선순위**: ⭐⭐⭐

---

## 🟢 **Low Priority (선택적 개선)**

### 5. **테스트**

#### 5.1 단위 테스트
**현재**: 없음
**개선**: Jest 도입
```javascript
// tests/planState.test.js
describe('loadPlanState', () => {
  test('FREE 플랜 로드', async () => {
    const plan = await loadPlanState();
    expect(plan.code).toBe('FREE');
  });
});
```
**우선순위**: ⭐⭐

#### 5.2 E2E 테스트
**현재**: 없음
**개선**: Playwright 도입
```javascript
// tests/e2e/login.spec.js
test('로그인 후 앱 접속', async ({ page }) => {
  await page.goto('/login.html');
  await page.fill('#email', 'test@test.com');
  await page.fill('#password', 'password');
  await page.click('button[type="submit"]');
  await expect(page).toHaveURL('/app.html');
});
```
**우선순위**: ⭐

---

### 6. **기능 개선**

#### 6.1 오프라인 지원
**현재**: 온라인 전용
**개선**: Service Worker + IndexedDB
```javascript
// sw.js
self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request).then((response) => {
      return response || fetch(event.request);
    })
  );
});
```
**우선순위**: ⭐

#### 6.2 다국어 지원
**현재**: 한국어만
**개선**: i18n
```javascript
// i18n.js
const messages = {
  ko: { welcome: '환영합니다' },
  en: { welcome: 'Welcome' }
};
```
**우선순위**: ⭐

#### 6.3 다크모드
**현재**: 라이트 모드만
**개선**: 다크모드 토글
```css
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #1a1a1a;
    --text: #f0f0f0;
  }
}
```
**우선순위**: ⭐⭐

---

### 7. **DevOps**

#### 7.1 CI/CD 파이프라인
**현재**: 수동 배포
**개선**: GitHub Actions
```yaml
# .github/workflows/deploy.yml
name: Deploy
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: npm run build
      - uses: amondnet/vercel-action@v20
```
**우선순위**: ⭐⭐

#### 7.2 환경 변수 관리
**현재**: config.js 커밋됨
**개선**: .env + Vercel 환경 변수
```bash
# .env.example
VITE_SUPABASE_URL=your_url
VITE_SUPABASE_ANON_KEY=your_key
```
**우선순위**: ⭐⭐⭐

#### 7.3 모니터링
**현재**: 없음
**개선**: Sentry 도입
```javascript
Sentry.init({
  dsn: "...",
  integrations: [new Sentry.BrowserTracing()],
  tracesSampleRate: 1.0,
});
```
**우선순위**: ⭐⭐

---

### 8. **데이터베이스**

#### 8.1 인덱스 최적화
**위치**: Supabase
```sql
-- 느린 쿼리 확인
EXPLAIN ANALYZE 
SELECT * FROM usage_events 
WHERE user_id = '...' AND feature = 'questions';

-- 인덱스 추가 (이미 있음)
CREATE INDEX IF NOT EXISTS idx_usage_events_user_feature 
ON usage_events(user_id, feature);
```
**우선순위**: ⭐⭐

#### 8.2 데이터 백업
**현재**: Supabase 자동 백업
**개선**: 정기적인 로컬 백업
```bash
# backup.sh
pg_dump $DATABASE_URL > backup_$(date +%Y%m%d).sql
```
**우선순위**: ⭐⭐⭐

---

## 📊 **우선순위 요약**

### **즉시 수정 (이번 주)**
1. ✅ admin.html - .neq 필터 수정
2. ✅ RLS 정책 확인 및 추가
3. ✅ 로딩 상태 UI 개선
4. ✅ 에러 메시지 개선

### **1주일 내**
1. ✅ app.html 파일 분리 (JS/CSS)
2. ⬜ 중복 코드 제거
3. ⬜ 반응형 디자인 개선
4. ⬜ 주석/문서화

### **1개월 내**
1. ⬜ TypeScript 도입
2. ⬜ 테스트 코드 작성
3. ⬜ CI/CD 파이프라인
4. ⬜ 모니터링 시스템

---

## 🎯 **성과 지표**

### **현재 상태**
- ✅ 기본 기능 완성 (Phase 3)
- ✅ 보안 기본 설정 (RLS, Edge Function)
- ✅ 사용량 대시보드
- ⚠️ 코드 품질 (분리 필요)
- ⚠️ 테스트 (없음)
- ⚠️ 문서화 (부족)

### **목표 (3개월 후)**
- ✅ TypeScript 전환
- ✅ 테스트 커버리지 80%+
- ✅ 성능 점수 90+
- ✅ 접근성 점수 90+
- ✅ SEO 점수 90+

---

## 📝 **다음 액션**

### **Step 1: 즉시 수정**
```bash
1. admin.html .neq 필터 수정
2. RLS 정책 Supabase에서 실행
3. 로딩 스피너 추가
4. 에러 메시지 개선
```

### **Step 2: 리팩토링**
```bash
1. app.html → app.js, app.css 분리
2. common.js 공통 모듈 생성
3. ESLint 설정
4. 주석 추가
```

### **Step 3: 테스트**
```bash
1. Jest 설정
2. 주요 함수 단위 테스트
3. Playwright E2E 테스트
```

---

**문서 작성일**: 2026-09-19
**작성자**: Claude Sonnet 4.5
**다음 검토일**: 2026-10-19
