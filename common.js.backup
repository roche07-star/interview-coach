/**
 * Common Utilities - 면접코치 공통 모듈
 * 여러 페이지에서 사용되는 공통 함수들
 */

// ============================================================
// Supabase 초기화 (IIFE로 전역 변수 충돌 방지)
// ============================================================

(function() {
  let _supabaseClient = null;

  /**
   * Supabase 클라이언트 초기화
   * @returns {Object} Supabase 클라이언트
   */
  window.initSupabase = function() {
    if (_supabaseClient) return _supabaseClient;

    if (!window.CONFIG) {
      console.error('❌ CONFIG가 정의되지 않았습니다. config.js를 먼저 로드해주세요.');
      return null;
    }

    if (!window.supabase) {
      console.error('❌ Supabase SDK가 로드되지 않았습니다.');
      return null;
    }

    try {
      _supabaseClient = window.supabase.createClient(
        window.CONFIG.SUPABASE_URL,
        window.CONFIG.SUPABASE_ANON_KEY
      );
      console.log('✅ Supabase 초기화 완료');
      return _supabaseClient;
    } catch (error) {
      console.error('❌ Supabase 초기화 실패:', error);
      return null;
    }
  };

  /**
   * Supabase 클라이언트 가져오기
   * @returns {Object} Supabase 클라이언트
   */
  window.getSupabaseClient = function() {
    if (!_supabaseClient) {
      return window.initSupabase();
    }
    return _supabaseClient;
  };
})();

// ============================================================
// Toast 알림
// ============================================================

/**
 * Toast 알림 표시
 * @param {string} type - 'success' | 'error' | 'info'
 * @param {string} message - 표시할 메시지
 * @param {number} duration - 표시 시간 (ms, 기본 3500)
 */
function showToast(type, message, duration = 3500) {
  const toast = document.getElementById('toast');
  if (!toast) {
    console.warn('⚠️ Toast 엘리먼트를 찾을 수 없습니다.');
    return;
  }

  const iconEl = document.getElementById('toastIcon');
  const messageEl = document.getElementById('toastMessage');

  if (!iconEl || !messageEl) {
    console.warn('⚠️ Toast 내부 엘리먼트를 찾을 수 없습니다.');
    return;
  }

  // 아이콘 설정
  const icons = {
    success: '✅',
    error: '❌',
    info: 'ℹ️',
    warning: '⚠️'
  };
  iconEl.textContent = icons[type] || icons.info;

  // 메시지 설정
  messageEl.textContent = message;

  // Toast 표시
  toast.className = `toast show ${type}`;

  // 기존 타이머 제거
  if (toast._timer) {
    clearTimeout(toast._timer);
  }

  // 자동 숨김
  toast._timer = setTimeout(() => {
    toast.classList.remove('show');
  }, duration);
}

// ============================================================
// 인증 체크
// ============================================================

/**
 * 로그인 상태 확인 및 리디렉션
 * @param {boolean} requireAuth - true면 로그인 필요, false면 로그인 시 리디렉션
 * @param {string} redirectTo - 리디렉션 경로
 * @returns {Promise<Object|null>} 현재 사용자 또는 null
 */
async function checkAuth(requireAuth = true, redirectTo = null) {
  const client = getSupabaseClient();
  if (!client) {
    if (requireAuth) {
      window.location.href = 'login.html';
    }
    return null;
  }

  try {
    const { data: { session } } = await client.auth.getSession();

    if (requireAuth && !session) {
      // 로그인 필요한데 로그인 안 됨 → 로그인 페이지로
      window.location.href = 'login.html';
      return null;
    }

    if (!requireAuth && session && redirectTo) {
      // 로그인 불필요한데 로그인 됨 → 리디렉션
      window.location.href = redirectTo;
      return null;
    }

    return session?.user || null;
  } catch (error) {
    console.error('❌ 인증 확인 실패:', error);
    if (requireAuth) {
      window.location.href = 'login.html';
    }
    return null;
  }
}

// ============================================================
// 유틸리티 함수
// ============================================================

/**
 * HTML 이스케이프 (XSS 방지)
 * @param {string} text - 이스케이프할 텍스트
 * @returns {string} 이스케이프된 텍스트
 */
function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

/**
 * 로딩 오버레이 표시
 * @param {string} text - 로딩 메시지
 * @param {string} subtext - 서브 메시지 (선택)
 */
function showLoading(text = '처리 중...', subtext = '') {
  const overlay = document.getElementById('loadingOverlay');
  if (!overlay) return;

  const textEl = document.getElementById('loadingText');
  const subtextEl = document.getElementById('loadingSubtext');

  if (textEl) textEl.textContent = text;
  if (subtextEl) subtextEl.textContent = subtext;

  overlay.classList.add('show');
}

/**
 * 로딩 오버레이 숨김
 */
function hideLoading() {
  const overlay = document.getElementById('loadingOverlay');
  if (overlay) {
    overlay.classList.remove('show');
  }
}

/**
 * 날짜 포맷팅 (한국어)
 * @param {string|Date} date - 날짜
 * @returns {string} 포맷된 날짜 (YYYY-MM-DD HH:mm)
 */
function formatDate(date) {
  const d = new Date(date);
  if (isNaN(d.getTime())) return '-';

  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  const hours = String(d.getHours()).padStart(2, '0');
  const minutes = String(d.getMinutes()).padStart(2, '0');

  return `${year}-${month}-${day} ${hours}:${minutes}`;
}

/**
 * 상대 시간 표시 (예: "5분 전", "어제")
 * @param {string|Date} date - 날짜
 * @returns {string} 상대 시간
 */
function timeAgo(date) {
  const d = new Date(date);
  const now = new Date();
  const diff = Math.floor((now - d) / 1000); // 초 단위

  if (diff < 60) return '방금 전';
  if (diff < 3600) return `${Math.floor(diff / 60)}분 전`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}시간 전`;
  if (diff < 604800) return `${Math.floor(diff / 86400)}일 전`;

  return formatDate(d).split(' ')[0]; // YYYY-MM-DD만
}

// ============================================================
// 내보내기 (ES6 모듈이 아닌 경우 전역 스코프)
// ============================================================

// 전역 스코프에 함수 노출
if (typeof window !== 'undefined') {
  // initSupabase, getSupabaseClient는 이미 IIFE에서 할당됨
  window.showToast = showToast;
  window.checkAuth = checkAuth;
  window.escapeHtml = escapeHtml;
  window.showLoading = showLoading;
  window.hideLoading = hideLoading;
  window.formatDate = formatDate;
  window.timeAgo = timeAgo;
}

console.log('✅ common.js 로드 완료');
