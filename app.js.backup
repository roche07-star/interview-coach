// ============================================================
// 2027 대입 면접코치 - Main Application Logic
// common.js의 showToast 등 유틸리티 사용
// ============================================================

// Supabase 초기화 (app.js 전용)
const SUPABASE_URL = CONFIG.SUPABASE_URL;
const SUPABASE_ANON_KEY = CONFIG.SUPABASE_ANON_KEY;

let supabaseClient = null;
let currentUser = null;

if (window.supabase) {
  supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
}

class Database {
  async init() {
    if (!supabaseClient) throw new Error('Supabase SDK 초기화에 실패했습니다.');
    const { data: { session } } = await supabaseClient.auth.getSession();
    currentUser = session?.user || null;
    return true;
  }

  async requireUser() {
    if (!supabaseClient) throw new Error('Supabase가 초기화되지 않았습니다.');
    const { data: { user }, error } = await supabaseClient.auth.getUser();
    if (error) throw error;
    if (!user) throw new Error('로그인이 필요합니다.');
    currentUser = user;
    return user;
  }

  async saveStudent(data) {
    const user = await this.requireUser();
    const payload = {
      user_id: user.id,
      email: user.email || '',
      university: data.university,
      department: data.department,
      record: data.record,
      masked_record: data.maskedRecord
    };
    const { data: row, error } = await supabaseClient.from('students').insert(payload).select().single();
    if (error) throw error;
    return row.id;
  }

  async getStudent(studentId) {
    const user = await this.requireUser();
    const { data, error } = await supabaseClient.from('students').select('*').eq('id', studentId).eq('user_id', user.id).single();
    if (error) throw error;
    return data;
  }

  async getAllStudents() {
    const user = await this.requireUser();
    const { data, error } = await supabaseClient.from('students').select('*').eq('user_id', user.id).order('created_at', { ascending: false });
    if (error) throw error;
    return data || [];
  }

  async deleteStudent(studentId) {
    const user = await this.requireUser();
    const { error } = await supabaseClient.from('students').delete().eq('id', studentId).eq('user_id', user.id);
    if (error) throw error;
  }

  async saveQuestions(studentId, questionList) {
    await this.getStudent(studentId);
    const payload = { student_id: studentId, questions: questionList };
    const { data, error } = await supabaseClient.from('questions').upsert(payload, { onConflict: 'student_id' }).select().single();
    if (error) throw error;
    return data.id;
  }

  async getQuestions(studentId) {
    await this.getStudent(studentId);
    const { data, error } = await supabaseClient.from('questions').select('*').eq('student_id', studentId).maybeSingle();
    if (error) throw error;
    return data;
  }

  async createInterviewSession(studentId, mode, selected) {
    await this.getStudent(studentId);
    const { data, error } = await supabaseClient.rpc('create_interview_session_with_usage', {
      p_student_id: studentId,
      p_mode: mode,
      p_question_count: selected.length
    });
    if (error) throw error;
    return data;
  }

  async saveInterview(data) {
    await this.getStudent(data.studentId);
    const payload = {
      session_id: data.sessionId,
      student_id: data.studentId,
      question_index: data.questionNumber,
      question: data.question,
      model_answer: data.modelAnswer || '',
      student_answer: data.studentAnswer || ''
    };
    const { data: row, error } = await supabaseClient.from('interviews').upsert(payload, { onConflict: 'session_id,question_index' }).select().single();
    if (error) throw error;
    return row;
  }

  async getSessionInterviews(sessionId) {
    const user = await this.requireUser();
    const { data, error } = await supabaseClient
      .from('interviews')
      .select('*')
      .eq('session_id', sessionId)
      .eq('student_id', (await this.getCurrentStudentIdForSession(sessionId)))
      .order('question_index', { ascending: true });
    if (error) throw error;
    return data || [];
  }

  async getCurrentStudentIdForSession(sessionId) {
    const { data, error } = await supabaseClient.from('interview_sessions').select('student_id').eq('id', sessionId).single();
    if (error) throw error;
    await this.getStudent(data.student_id);
    return data.student_id;
  }

  async completeSession(sessionId) {
    await this.getCurrentStudentIdForSession(sessionId);
    const { error } = await supabaseClient.from('interview_sessions').update({ status: 'completed', completed_at: new Date().toISOString() }).eq('id', sessionId);
    if (error) throw error;
  }

  async saveFeedback(sessionId, feedback) {
    await this.getCurrentStudentIdForSession(sessionId);
    const { error } = await supabaseClient.from('interview_sessions').update({ feedback }).eq('id', sessionId);
    if (error) throw error;
  }

  async getFeedback(sessionId) {
    await this.getCurrentStudentIdForSession(sessionId);
    const { data, error } = await supabaseClient.from('interview_sessions').select('feedback').eq('id', sessionId).single();
    if (error) throw error;
    return data?.feedback || null;
  }

  async getRecentSession(studentId) {
    await this.getStudent(studentId);
    const { data, error } = await supabaseClient
      .from('interview_sessions')
      .select('*')
      .eq('student_id', studentId)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (error) throw error;
    return data;
  }

  async getStudentSessions(studentId) {
    await this.getStudent(studentId);
    const { data, error } = await supabaseClient
      .from('interview_sessions')
      .select('*')
      .eq('student_id', studentId)
      .order('created_at', { ascending: false });
    if (error) throw error;
    return data || [];
  }
}

const db = new Database();
let currentStep = 1;
let savedRecord = '';
let maskedRecord = '';
let questions = [];
let selectedQuestions = [];
let currentQuestion = 0;
let isTestMode = false;
let selectedQuestionCount = 3;
let planState = null;
let usageState = null;
let currentSessionCompleted = false;
let currentStudentId = null;
let currentSessionId = null;
let currentTranscript = '';
let recognition = null;
let recordingFinalText = '';
let loadingProgressInterval = null;

async function loadPlanState() {
  if (!supabaseClient) return;
  const { data, error } = await supabaseClient.rpc('get_my_plan');
  if (error) throw error;
  planState = Array.isArray(data) ? data[0] : data;
  const { data: usage, error: usageError } = await supabaseClient.rpc('get_my_usage');
  if (!usageError) usageState = Array.isArray(usage) ? usage[0] : usage;

  const badge = document.getElementById('planBadge');
  if (badge) badge.textContent = planState?.code === 'BETA' ? 'BETA 29,000원' : '무료 체험';
  const isBeta = planState?.code === 'BETA';
  const qLimit = planState?.question_limit;
  const iLimit = planState?.interview_limit;
  const fLimit = planState?.feedback_limit;
  const used = usageState || {};
  const setUsage=(id,bar,usedValue,limit)=>{
    const u=Number(usedValue||0), l=Number(limit||0);
    document.getElementById(id)?.replaceChildren(document.createTextNode(limit==null?`${u}회 사용`: `${u} / ${l}회`));
    const pct=limit==null?0:Math.min(100,(u/l)*100);
    const el=document.getElementById(bar); if(el) el.style.width=`${pct}%`;
  };
  setUsage('usageQuestions','usageQuestionsBar',used.questions_used,qLimit);
  setUsage('usageInterviews','usageInterviewsBar',used.interview_used,iLimit);
  setUsage('usageFeedback','usageFeedbackBar',used.feedback_used,fLimit);
  document.getElementById('usagePlanName')?.replaceChildren(document.createTextNode(planState?.name || '무료 체험'));
  document.getElementById('usagePlanMeta')?.replaceChildren(document.createTextNode(isBeta && planState.expires_at ? `베타 만료 ${new Date(planState.expires_at).toLocaleDateString('ko-KR')}` : '현재 무료 체험 플랜'));
  document.getElementById('generateBtnText')?.replaceChildren(document.createTextNode(isBeta ? `질문/답변 ${selectedQuestionCount}개 생성` : `무료 질문 ${Math.min(selectedQuestionCount,10)}개 생성`));
  // 무료: 10개까지, 유료: 10/20/30개
  ['count10','count20','count30'].forEach(id=>{
    const b=document.getElementById(id);
    if(!b) return;
    if(id === 'count10') {
      b.disabled = false;
      b.style.opacity = '1';
      b.title = '';
    } else {
      b.disabled = !isBeta;
      b.style.opacity = isBeta ? '1' : '0.45';
      b.title = isBeta ? '' : 'BETA 플랜에서 사용할 수 있습니다.';
    }
  });
  if(!isBeta && selectedQuestionCount>10) selectQuestionCount(10);
  updateOnboarding();
}

function updateOnboarding(){
  const rows=[['onboardRecord',!!currentStudentId],['onboardQuestions',questions.length>0],['onboardInterview',!!currentSessionId && currentSessionCompleted],['onboardFeedback',!!window._currentFeedback]];
  rows.forEach(([id,done])=>{const el=document.getElementById(id);if(!el)return;el.classList.toggle('done',done);el.textContent=(done?'✓ ':'○ ')+el.textContent.slice(2);});
}
function logEvent(name, metadata={}){
  if(!supabaseClient) return;
  supabaseClient.rpc('log_analytics_event',{p_event_name:name,p_metadata:metadata}).catch(e=>console.warn('analytics:',e));
}

function showPlanInfo() {
  if (!planState) return;
  const usage = usageState || {};
  const lines = [
    `현재 플랜: ${planState.name}`,
    `등록 가능 대학: 최대 ${planState.max_universities}개`,
    `질문 사용량: ${usage.questions_used ?? 0} / ${planState.question_limit ?? '무제한'}`,
    `면접 사용량: ${usage.interview_used ?? 0} / ${planState.interview_limit ?? '무제한'}`,
    `피드백 사용량: ${usage.feedback_used ?? 0} / ${planState.feedback_limit ?? '무제한'}`
  ];
  if (planState.expires_at) lines.push(`플랜 만료: ${new Date(planState.expires_at).toLocaleDateString('ko-KR')}`);
  alert(lines.join('\n'));
}

async function redeemBetaCoupon() {
  const code = prompt('베타 코드를 입력하세요.');
  if (!code) return;
  try {
    const { data, error } = await supabaseClient.rpc('redeem_coupon', { p_code: code.trim() });
    if (error) throw error;
    const result = Array.isArray(data) ? data[0] : data;
    if (!result?.success) { showToast('error', result?.message || '쿠폰 적용에 실패했습니다.'); return; }
    showToast('success', '2026 베타 플랜이 활성화되었습니다.');
    await loadPlanState();
  } catch (e) {
    console.error(e);
    showToast('error', '쿠폰 적용 실패: ' + e.message);
  }
}

function getAIConfig() {
  return {
    provider: localStorage.getItem('aiProvider') || 'claude',
    apiKey: '',
    endpoint: `${SUPABASE_URL}/functions/v1/ai-proxy`
  };
}

async function checkAuth() {
  if (!supabaseClient) return;
  const { data: { session } } = await supabaseClient.auth.getSession();

  if (!session) {
    window.location.href = 'login.html';
    return;
  }

  currentUser = session.user;

  // 승인 상태 및 탈퇴 상태 확인
  try {
    const { data, error } = await supabaseClient
      .from('user_approvals')
      .select('approval_status, deleted_at')
      .eq('user_id', session.user.id)
      .single();

    // 탈퇴 요청한 사용자는 즉시 로그아웃
    if (data && data.deleted_at) {
      alert('회원 탈퇴가 처리되었습니다.');
      await supabaseClient.auth.signOut();
      window.location.href = 'login.html';
      return;
    }

    if (!data || data.approval_status === 'pending') {
      alert('승인 대기 중입니다. 관리자 승인 후 이용 가능합니다.');
      window.location.href = 'guide.html';
      return;
    }

    if (data.approval_status === 'rejected') {
      alert('승인이 거부되었습니다. 관리자에게 문의하세요.');
      await supabaseClient.auth.signOut();
      window.location.href = 'login.html';
      return;
    }
  } catch (error) {
    console.error('승인 상태 확인 오류:', error);
  }

  const navUser = document.getElementById('navUser');
  const userEmail = document.getElementById('userEmail');
  if (currentUser && navUser && userEmail) {
    userEmail.textContent = currentUser.email || '사용자';
    navUser.style.display = 'flex';
  }
}

async function handleLogout() {
  if (supabaseClient) await supabaseClient.auth.signOut();
  window.location.href = 'login.html';
}

async function handleDeleteAccount() {
  if (!supabaseClient || !currentUser) {
    alert('로그인이 필요합니다.');
    return;
  }

  const confirmMsg = '⚠️ 정말로 회원 탈퇴하시겠습니까?\n\n' +
    '- 모든 생기부 데이터가 삭제됩니다.\n' +
    '- 면접 세션 및 피드백이 삭제됩니다.\n' +
    '- 이 작업은 되돌릴 수 없습니다.\n\n' +
    '계속하려면 "탈퇴"를 입력하세요.';

  const userInput = prompt(confirmMsg);

  if (userInput !== '탈퇴') {
    alert('회원 탈퇴가 취소되었습니다.');
    return;
  }

  try {
    // RPC 함수를 통해 자신의 계정 삭제 (user_approvals, interview_sessions는 CASCADE로 자동 삭제)
    const { error } = await supabaseClient.rpc('request_account_deletion');

    if (error) {
      console.error('계정 삭제 오류:', error);
      alert('⚠️ 계정 삭제 중 오류가 발생했습니다.\n\n' + error.message);
      return;
    }

    alert('✅ 회원 탈퇴가 완료되었습니다.\n\n그동안 이용해 주셔서 감사합니다.');
    window.location.href = 'login.html';

  } catch (error) {
    console.error('탈퇴 처리 오류:', error);
    alert('오류가 발생했습니다: ' + error.message);
  }
}

function openSettings() { document.getElementById('settingsModal').classList.add('show'); }
function closeSettings() { document.getElementById('settingsModal').classList.remove('show'); }

function saveSettings() {
  const university = document.getElementById('university').value;
  const department = document.getElementById('department').value.trim();
  const providerEl = document.getElementById('aiProvider');
  const provider = providerEl ? providerEl.value : 'claude';

  if (!university || !department) return showToast('error', '🎓 대학과 학과를 모두 선택해주세요.');

  localStorage.setItem('aiProvider', provider);
  localStorage.setItem('university', university);
  localStorage.setItem('department', department);
  showToast('success', '설정이 저장되었습니다.');
  closeSettings();
}

async function changePassword() {
  const newPassword = document.getElementById('newPassword').value;
  const confirmPassword = document.getElementById('newPasswordConfirm').value;

  if (!newPassword || !confirmPassword) {
    showToast('error', '🔒 새 비밀번호와 확인 비밀번호를 모두 입력해주세요.');
    return;
  }

  if (newPassword.length < 6) {
    showToast('error', '🔒 비밀번호는 보안을 위해 최소 6자 이상이어야 합니다.');
    return;
  }

  if (newPassword !== confirmPassword) {
    showToast('error', '🔒 비밀번호가 일치하지 않습니다. 다시 확인해주세요.');
    return;
  }

  try {
    const { error } = await supabaseClient.auth.updateUser({
      password: newPassword
    });

    if (error) throw error;

    // 입력 필드 초기화
    document.getElementById('newPassword').value = '';
    document.getElementById('newPasswordConfirm').value = '';

    showToast('success', '비밀번호가 변경되었습니다.');
  } catch (error) {
    console.error('비밀번호 변경 오류:', error);
    showToast('error', '비밀번호 변경 실패: ' + error.message);
  }
}

function loadSettings() {
  const provider = localStorage.getItem('aiProvider') || 'claude';
  const university = localStorage.getItem('university') || '';
  const department = localStorage.getItem('department') || '';
  const p = document.getElementById('aiProvider'); if (p) p.value = provider;
  const u = document.getElementById('university'); if (u) u.value = university;
  const d = document.getElementById('department'); if (d) d.value = department;
  updateAISettingsHelp();
}

function updateAISettingsHelp() {
  const provider = document.getElementById('aiProvider')?.value || 'claude';
  const help = document.getElementById('aiProviderHelp');
  if (!help) return;
  help.textContent = provider === 'claude' ? 'Claude API는 Supabase Edge Function을 통해 안전하게 호출합니다.' : 'OpenAI API는 Supabase Edge Function을 통해 안전하게 호출합니다.';
  const endpoint = document.getElementById('aiEndpoint');
  if (endpoint) endpoint.value = `${SUPABASE_URL}/functions/v1/ai-proxy`;
}

function switchStep(step) {
  document.querySelectorAll('.step-content').forEach(el => el.classList.remove('active'));
  document.querySelectorAll('.step-tab').forEach(el => el.classList.remove('active'));
  document.getElementById(`step${step}`)?.classList.add('active');
  document.getElementById(`tab${step}`)?.classList.add('active');
  currentStep = step;
}
function completeStep(step) { document.getElementById(`tab${step}`)?.classList.add('completed'); }

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
}
function safeText(value) { return escapeHtml(value).replace(/\n/g, '<br>'); }
function formatDate(dateStr) {
  if (!dateStr) return '저장 시간 미상';
  try {
    const date = new Date(dateStr);
    return isNaN(date.getTime()) ? '저장 시간 미상' : date.toLocaleString('ko-KR');
  } catch {
    return '저장 시간 미상';
  }
}
function markdownToHtml(text) {
  if (!text) return '';
  let html = escapeHtml(text);

  // 헤더 (### Title)
  html = html.replace(/^### (.+)$/gm, '<h3 style="font-size:18px;font-weight:700;margin:20px 0 10px;color:#333">$1</h3>');
  html = html.replace(/^## (.+)$/gm, '<h2 style="font-size:20px;font-weight:700;margin:24px 0 12px;color:#333">$1</h2>');
  html = html.replace(/^# (.+)$/gm, '<h1 style="font-size:24px;font-weight:700;margin:28px 0 14px;color:#333">$1</h1>');

  // 볼드 (**text**)
  html = html.replace(/\*\*(.+?)\*\*/g, '<strong style="font-weight:700;color:#1a1a1a">$1</strong>');

  // 이탤릭 (*text*)
  html = html.replace(/\*(.+?)\*/g, '<em style="font-style:italic">$1</em>');

  // 리스트 (- item 또는 * item)
  html = html.replace(/^[*-] (.+)$/gm, '<li style="margin:6px 0;padding-left:8px">$1</li>');
  html = html.replace(/(<li[^>]*>.*<\/li>)/s, '<ul style="margin:12px 0;padding-left:24px;list-style:disc">$1</ul>');

  // 숫자 리스트 (1. item)
  html = html.replace(/^\d+\. (.+)$/gm, '<li style="margin:6px 0;padding-left:8px">$1</li>');

  // 코드 블록 (`code`)
  html = html.replace(/`(.+?)`/g, '<code style="background:#f5f5f5;padding:2px 6px;border-radius:3px;font-family:monospace;font-size:13px">$1</code>');

  // 줄바꿈
  html = html.replace(/\n\n/g, '<br><br>');
  html = html.replace(/\n/g, '<br>');

  return html;
}

function maskPersonalInfo(text) {
  let masked = text;
  masked = masked.replace(/(성명|이름|학생명)\s*[:：]?\s*([가-힣]{2,4})/g, '$1: ' + '***');
  masked = masked.replace(/([가-힣]{2,4})\s*\(/g, (m, n) => n[0] + '*'.repeat(Math.max(1,n.length-1)) + ' (');
  masked = masked.replace(/01[016789]-?\d{3,4}-?\d{4}/g, '010-****-****');
  masked = masked.replace(/[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}/g, '****@****.***');
  return masked;
}
function countMasked(original, masked) {
  if (original === masked) return 0;
  const a = (original.match(/\*+/g) || []).length;
  const b = (masked.match(/\*+/g) || []).length;
  return Math.max(1, b - a);
}

async function saveStudentRecord() {
  const record = document.getElementById('studentRecord').value.trim();
  const university = localStorage.getItem('university');
  const department = localStorage.getItem('department');
  if (record.length < 100) return showToast('error', '📝 생기부 내용이 너무 짧습니다. 면접 준비를 위해 최소 100자 이상 작성해주세요.');
  if (!university || !department) { showToast('error', '🎓 대학과 학과 정보가 필요합니다. 설정에서 먼저 선택해주세요.'); openSettings(); return; }
  showLoading('생기부 저장 중...', '개인정보 마스킹 및 DB 저장');
  try {
    savedRecord = record;
    maskedRecord = maskPersonalInfo(record);
    currentStudentId = await db.saveStudent({ university, department, record, maskedRecord });
    logEvent('record_saved',{university,department});
    const info = document.getElementById('maskedInfo');
    if (info) info.innerHTML = `<strong>마스킹 처리:</strong> ${countMasked(record, maskedRecord)}개 항목<br><small>학생 ID: ${escapeHtml(currentStudentId)}</small>`;
    document.getElementById('analysisResult').style.display = 'block';
    completeStep(1); switchStep(2); hideLoading(); showToast('success', '생기부가 저장되었습니다.');
  } catch (e) { hideLoading(); showToast('error', '생기부 저장 실패: ' + e.message); }
}

function selectQuestionCount(count) {
  selectedQuestionCount = count;
  document.querySelectorAll('.count-select-btn').forEach(btn => { btn.style.borderColor='#e0e0e0'; btn.style.color='#666'; });
  const btn = document.getElementById(`count${count}`); if (btn) { btn.style.borderColor='#667eea'; btn.style.color='#667eea'; }
  const text = document.getElementById('generateBtnText'); if (text) text.textContent = `질문/답변 ${count}개 생성`;
}

async function callAI(prompt, maxTokens=12000, usageFeature, usageQuantity=1, usageMetadata={}) {
  if (!supabaseClient) throw new Error('Supabase가 초기화되지 않았습니다.');
  const cfg = getAIConfig();

  const { data, error } = await supabaseClient.functions.invoke('ai-proxy', {
    body: {
      provider: cfg.provider,
      prompt,
      max_tokens: maxTokens,
      usage_feature: usageFeature,
      usage_quantity: usageQuantity,
      usage_metadata: usageMetadata
    }
  });

  if (error) {
    let detail = error.message || 'AI 서버 호출 실패';
    try {
      if (error.context?.body) {
        const body = typeof error.context.body === 'string' ? JSON.parse(error.context.body) : error.context.body;
        if (body?.error) detail = body.error;
      }
    } catch (_) {}
    if (error?.context?.status === 429 || /PLAN_LIMIT_EXCEEDED|이용 한도/.test(detail)) { setTimeout(()=>showPlanInfo(),150); }
    throw new Error(detail);
  }

  if (!data?.text) throw new Error(data?.error || 'AI 응답이 비어 있습니다.');
  return data.text;
}

function extractJson(text) {
  const cleaned = String(text).replace(/^```json\s*/i,'').replace(/^```\s*/,'').replace(/\s*```$/,'').trim();
  try { return JSON.parse(cleaned); } catch (_) {}
  const start=cleaned.indexOf('{'), end=cleaned.lastIndexOf('}');
  if(start<0 || end<=start) throw new Error('AI 응답에서 JSON을 찾지 못했습니다.');
  return JSON.parse(cleaned.slice(start,end+1));
}

async function generateQuestions() {
  if (!currentStudentId) { showToast('error','📋 생기부를 먼저 저장해주세요. 1단계로 이동합니다.'); switchStep(1); return; }
  if (!supabaseClient) { showToast('error','🔌 서버 연결이 필요합니다. 페이지를 새로고침해주세요.'); return; }
  const university=localStorage.getItem('university')||''; const department=localStorage.getItem('department')||'';
  const isBeta = planState?.code === 'BETA';
  const targetCount = isBeta ? selectedQuestionCount : Math.min(selectedQuestionCount,10);
  const need=Math.max(0,targetCount-questions.length);
  if(need===0){showToast('info',`이미 ${targetCount}개 질문이 있습니다.`);return;}
  showLoading('🤖 AI가 질문을 생성하고 있습니다',`${need}개의 맞춤형 면접 질문 생성 중 (평균 10~15초 소요)`,true);
  try {
    // 무료 사용자 프롬프트 (꼬리질문 없음)
    const freePrompt = `너는 2027학년도 대입 학생부종합전형 면접 전문가이다.

대학: ${university}
학과: ${department}

[학생부]
${maskedRecord}

${questions.length ? `
[기존 질문]
${JSON.stringify(questions)}

기존 질문과 동일하거나 유사한 질문은 제외하고 새로운 질문 ${need}개만 생성한다.
` : `
새로운 질문 ${need}개를 생성한다.
`}

[질문 생성 원칙]
1. 반드시 학생부에 실제로 기록된 활동, 교과, 세특, 동아리, 진로활동, 탐구활동 등을 근거로 질문한다.
2. 학생부에 없는 경험, 활동, 수상, 역할, 성과, 수치 등을 임의로 만들어내지 않는다.
3. 실제 대학 면접관이 학생부를 보고 물어볼 만한 구체적인 질문을 만든다.
4. 단순한 자기소개나 지원동기 질문만 반복하지 않는다.
5. 학생부의 여러 활동과 영역을 균형 있게 활용한다.
6. 대학과 학과의 특성을 고려하여 전공과 학생부 활동의 연결성을 확인한다.
7. 활동의 결과뿐 아니라 활동 과정, 학생의 역할, 배운 점과 성찰을 확인한다.

[평가요소]
전체 질문에서 다음 평가요소를 균형 있게 반영한다.
- 전공적합성: 40%
- 학업역량: 30%
- 인성: 20%
- 발전가능성: 10%

[질문 유형]
다음 유형을 골고루 포함한다.
- 학생부 활동 확인
- 전공 및 진로 연계
- 학업 및 탐구
- 문제 해결
- 협업 및 공동체
- 경험에 대한 성찰

[답변 생성 원칙]
1. 질문과 학생부 내용을 직접 연결하여 답변한다.
2. 학생부에 없는 사실을 절대 추가하지 않는다.
3. 학생이 실제 면접에서 말할 수 있는 자연스러운 표현으로 작성한다.
4. 질문에 먼저 직접 답하고 구체적인 경험이나 근거를 제시한다.
5. 마지막에는 배운 점이나 앞으로의 방향을 자연스럽게 연결한다.
6. 학생부 내용을 그대로 복사하지 않고 학생의 생각이 드러나도록 작성한다.
7. 답변은 5~7문장으로 작성한다.
8. 지나치게 전문적이거나 완벽한 표현은 피한다.

⚠️ 중요
- 꼬리질문은 생성하지 않는다.
- 반드시 질문과 답변만 생성한다.
- 반드시 유효한 JSON만 출력한다.
- 설명, 주석, 마크다운, 코드블록은 출력하지 않는다.
- JSON 외의 문자는 출력하지 않는다.

출력 형식:
{
  "questions": [
    {
      "question": "질문 내용",
      "answer": "답변 내용"
    }
  ]
}`;

    // 유료 사용자 프롬프트 (꼬리질문 2~3개 포함, 실전 대비 강화)
    const paidPrompt = `너는 2027학년도 대입 학생부종합전형 면접 전문가이자
실전 대학 면접을 대비시키는 전문 면접 코치이다.

대학: ${university}
학과: ${department}

[학생부]
${maskedRecord}

${questions.length ? `
[기존 질문]
${JSON.stringify(questions)}

기존 질문과 동일하거나 유사한 질문은 제외하고 새로운 질문 ${need}개만 생성한다.
` : `
실전 면접 대비를 위한 질문 ${need}개를 생성한다.
`}

[질문 생성 원칙]
1. 반드시 학생부에 기록된 구체적인 활동과 내용을 근거로 질문한다.
2. 학생부에 없는 경험, 활동, 수상, 역할, 성과, 수치 등을 임의로 만들어내지 않는다.
3. 대학과 학과의 특성을 고려한다.
4. 실제 대학 면접관이 학생부를 보고 추가로 확인할 가능성이 높은 질문을 만든다.
5. 동일한 활동만 반복하지 않고 학생부의 여러 영역을 활용한다.
6. 활동의 동기, 과정, 역할, 결과, 어려움, 해결방법, 배운 점과 성찰을 다양하게 확인한다.
7. 전공 관련 활동은 전공과의 연결성을 한 단계 깊게 확인한다.
8. 학생이 실제로 해당 활동을 이해하고 수행했는지 확인할 수 있는 질문을 포함한다.
9. 학생부의 강점뿐 아니라 면접에서 추가 설명이 필요할 가능성이 있는 부분도 질문한다.

[평가요소]
다음 평가요소를 균형 있게 반영한다.
- 전공적합성
- 학업역량
- 인성
- 발전가능성

[실전 질문 유형]
전체 질문에서 다음 유형이 골고루 포함되도록 한다.

1. 활동 확인 질문
2. 탐구 심화 질문
3. 전공 연계 질문
4. 학업 과정 질문
5. 문제 해결 질문
6. 협업 및 갈등 상황 질문
7. 가치관 및 성찰 질문
8. 학생부 내용 검증 질문
9. 예상 반론 및 추가 설명 질문
10. 사고의 깊이를 확인하는 질문

[답변 생성 원칙]
1. 학생부에 기록된 내용을 근거로 답변한다.
2. 학생부에 없는 경험이나 성과를 절대 추가하지 않는다.
3. 학생이 실제 면접에서 말할 수 있는 자연스러운 말투로 작성한다.
4. 질문에 먼저 직접 답하고 구체적인 경험을 근거로 설명한다.
5. 자신의 역할과 생각이 드러나도록 작성한다.
6. 활동의 결과뿐 아니라 과정과 배운 점을 설명한다.
7. 마지막에는 변화, 성찰 또는 향후 방향을 자연스럽게 연결한다.
8. 학생부 내용을 단순히 반복하지 않는다.
9. 답변은 5~7문장으로 작성한다.
10. 지나치게 완벽하거나 성인 전문가처럼 들리는 표현은 피한다.

[꼬리질문]
각 질문마다 실제 면접관이 추가로 물어볼 가능성이 높은 꼬리질문 2~3개를 생성한다.

꼬리질문은 다음 목적을 가진다.
- 답변의 근거 확인
- 학생의 이해도 확인
- 사고의 깊이 확인
- 활동의 진정성 확인
- 전공과의 연결성 확인
- 답변의 논리적 빈틈 확인

꼬리질문은 본 질문과 동일한 내용을 반복하지 않는다.

[실전 검증]
각 질문과 답변이 다음 조건을 만족하는지 확인한다.

- 질문이 학생부의 구체적인 근거를 가지고 있는가?
- 답변이 질문에 직접 답하고 있는가?
- 답변에 학생부에 없는 사실이 포함되지 않았는가?
- 질문과 답변이 서로 모순되지 않는가?
- 실제 고등학생이 면접에서 말할 수 있는 수준인가?
- 꼬리질문이 실제 면접에서 이어질 만한 내용인가?

조건을 충족하지 않는 경우 내부적으로 수정한 후 최종 결과만 출력한다.

⚠️ 매우 중요
- 반드시 유효한 JSON만 출력한다.
- 설명, 주석, 마크다운, 코드블록은 절대 출력하지 않는다.
- JSON 외의 문자는 출력하지 않는다.

출력 형식:
{
  "questions": [
    {
      "question": "질문 내용",
      "answer": "답변 내용",
      "follow_ups": [
        "꼬리질문1",
        "꼬리질문2",
        "꼬리질문3"
      ]
    }
  ]
}`;

    const prompt = isBeta ? paidPrompt : freePrompt;
    const result=extractJson(await callAI(prompt,16000,'questions',need,{university,department}));
    const added=(result.questions||[]).map(q=>({
      question:String(q.question||'').trim(),
      answer:String(q.answer||'').trim(),
      follow_ups:Array.isArray(q.follow_ups)?q.follow_ups.map(String):[]
    })).filter(q=>q.question&&q.answer).slice(0,need);
    if(!added.length) throw new Error('생성된 질문이 없습니다.');
    questions=[...questions,...added];
    logEvent('questions_generated',{count:added.length,university,department});
    await db.saveQuestions(currentStudentId,questions);

    // 수동 사용량 기록 (Edge Function 실패 대비)
    try {
      await supabaseClient.rpc('consume_ai_usage', {
        p_feature: 'questions',
        p_quantity: added.length,
        p_metadata: { university, department }
      });
      console.log(`✅ 사용량 기록 완료: questions ${added.length}개`);
    } catch (usageError) {
      console.warn('⚠️ 사용량 기록 실패:', usageError);
    }

    hideLoading(); displayQuestions(); await loadPlanState(); completeStep(2); switchStep(3); showToast('success',`총 ${questions.length}개 질문이 준비되었습니다.`);
  } catch(e){hideLoading();console.error(e);showToast('error','질문 생성 실패: '+e.message);}
}

function displayQuestions(){
  const c=document.getElementById('questionsContainer'); if(!c)return;
  c.innerHTML=`<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px"><strong>총 ${questions.length}개 질문</strong><div><button class="btn" onclick="downloadQuestions()">다운로드</button> <button class="btn" onclick="printQuestions()" style="background:#6c757d">인쇄</button></div></div>`+
    questions.map((q,i)=>`<div style="border:1px solid #e5e5e5;border-radius:10px;padding:18px;margin-bottom:12px"><div style="font-weight:700">Q${i+1}. ${safeText(q.question)}</div><div style="margin-top:10px;color:#555">${safeText(q.answer)}</div>${q.follow_ups?.length?`<div style="margin-top:12px;color:#667eea"><strong>꼬리 질문</strong>${q.follow_ups.map((f,j)=>`<div>${j+1}. ${safeText(f)}</div>`).join('')}</div>`:''}</div>`).join('');
}
function downloadQuestions(){
  const html=`<!doctype html><html lang="ko"><meta charset="utf-8"><title>면접 질문</title><body>${questions.map((q,i)=>`<h3>Q${i+1}. ${escapeHtml(q.question)}</h3><p>${safeText(q.answer)}</p><h4>꼬리 질문</h4><ul>${(q.follow_ups||[]).map(f=>`<li>${escapeHtml(f)}</li>`).join('')}</ul>`).join('')}</body></html>`;
  const blob=new Blob([html],{type:'text/html;charset=utf-8'}); const a=document.createElement('a'); a.href=URL.createObjectURL(blob); a.download='AI_면접_질문.html'; a.click(); URL.revokeObjectURL(a.href);
}
function printQuestions(){const w=window.open('','_blank');w.document.write(`<html lang="ko"><meta charset="utf-8"><title>면접 질문</title><body>${document.getElementById('questionsContainer').innerHTML}</body></html>`);w.document.close();w.print();}

function startInterview(testMode=false){
  if(!currentStudentId){showToast('error','📋 생기부를 먼저 저장하거나 불러와주세요. 1단계로 이동합니다.');switchStep(1);return;}
  if(!questions.length){showToast('error','❓ 질문을 먼저 생성하거나 불러와주세요. 2단계로 이동합니다.');switchStep(2);return;}
  isTestMode=testMode;
  const count=testMode?Math.min(2,questions.length):questions.length;
  selectedQuestions=[...questions].sort(()=>Math.random()-0.5).slice(0,count);
  currentQuestion=0; currentTranscript='';
  db.createInterviewSession(currentStudentId,testMode?'test':'full',selectedQuestions).then(id=>{currentSessionId=id;currentSessionCompleted=false;logEvent('interview_started',{mode:testMode?'test':'full',question_count:count});document.getElementById('interviewStartSection').style.display='none';document.getElementById('interviewContainer').style.display='block';showQuestion();}).catch(e=>showToast('error','면접 세션 생성 실패: '+e.message));
}

function showQuestion(){
  if(currentQuestion>=selectedQuestions.length){showInterviewComplete();return;}
  const q=selectedQuestions[currentQuestion], c=document.getElementById('interviewContainer');
  c.innerHTML=`<div style="text-align:center;margin-bottom:30px"><div style="font-size:14px;color:#999">질문 ${currentQuestion+1} / ${selectedQuestions.length} ${isTestMode?'(테스트)':''}</div><div style="font-size:18px;font-weight:600;margin-top:10px">${safeText(q.question)}</div></div><div id="answerMethodSelection" style="display:flex;gap:12px;justify-content:center"><button class="btn" onclick="selectAnswerMethod('voice')">🎤 음성으로 답변</button><button class="btn" onclick="selectAnswerMethod('text')" style="background:#2196f3">✏️ 텍스트로 답변</button></div><div id="voiceAnswerArea" style="display:none;text-align:center"><button class="btn" id="recordBtn" onclick="startRecording()">답변 시작</button><button class="btn" id="stopBtn" onclick="stopRecording()" style="display:none">답변 완료</button><div id="transcript" style="display:none;margin-top:20px;padding:16px;background:#f9f9f9;border-radius:8px;min-height:100px;text-align:left"></div></div><div id="textAnswerArea" style="display:none"><textarea id="textAnswer" placeholder="답변을 입력하세요..." style="min-height:200px"></textarea><div style="text-align:center;margin-top:12px"><button class="btn" onclick="submitTextAnswer()">답변 완료</button></div></div><div id="editAnswerArea" style="display:none"></div>`;
  lucide.createIcons();
}
function selectAnswerMethod(method){document.getElementById('answerMethodSelection').style.display='none';document.getElementById(method==='voice'?'voiceAnswerArea':'textAnswerArea').style.display='block';}

async function persistCurrentAnswer(answer){
  if(!answer || !answer.trim()) throw new Error('답변이 비어 있습니다.');
  if(!currentSessionId) throw new Error('면접 세션이 없습니다.');
  const q=selectedQuestions[currentQuestion]; currentTranscript=answer.trim();
  await db.saveInterview({sessionId:currentSessionId,studentId:currentStudentId,questionNumber:currentQuestion+1,question:q.question,modelAnswer:q.answer,studentAnswer:currentTranscript});
}

async function submitTextAnswer(){
  try{await persistCurrentAnswer(document.getElementById('textAnswer').value);showEditButton();showToast('success','답변이 저장되었습니다.');}catch(e){showToast('error','답변 저장 실패: '+e.message);}
}
function showEditButton(){
  const c=document.getElementById('interviewContainer');
  c.innerHTML=`<div style="text-align:center"><div style="font-size:14px;color:#999">질문 ${currentQuestion+1} 답변 완료</div><div style="text-align:left;margin:18px 0;padding:16px;background:#f9f9f9;border-radius:8px;white-space:pre-wrap">${safeText(currentTranscript)}</div><button class="btn" onclick="editAnswer()" style="background:#ff9800">답변 수정</button><button class="btn" onclick="confirmAnswer()" style="background:#4caf50;margin-left:8px">다음 질문</button></div>`;
}
function editAnswer(){
  const c=document.getElementById('interviewContainer');
  c.innerHTML=`<div><div style="font-weight:700;margin-bottom:12px">질문 ${currentQuestion+1} 답변 수정</div><textarea id="editAnswer" style="min-height:200px">${escapeHtml(currentTranscript)}</textarea><div style="text-align:center;margin-top:12px"><button class="btn" onclick="saveEditedAnswer()">수정 저장</button><button class="btn" onclick="cancelEdit()" style="background:#999;margin-left:8px">취소</button></div></div>`;
}
async function saveEditedAnswer(){try{await persistCurrentAnswer(document.getElementById('editAnswer').value);showToast('success','수정된 답변이 저장되었습니다.');showEditButton();}catch(e){showToast('error','수정 저장 실패: '+e.message);}}
function cancelEdit(){showEditButton();}
function confirmAnswer(){currentQuestion++;currentTranscript='';showQuestion();}

function startRecording(){
  if(!('webkitSpeechRecognition' in window)&&!('SpeechRecognition' in window)){showToast('error','🎤 음성 인식을 지원하지 않는 브라우저입니다. Chrome 또는 Edge 브라우저를 사용해주세요.');return;}
  const SpeechRecognition=window.SpeechRecognition||window.webkitSpeechRecognition;
  if(recognition){try{recognition.stop();}catch(e){}}
  recognition=new SpeechRecognition(); recognition.lang='ko-KR'; recognition.continuous=true; recognition.interimResults=true;
  recordingFinalText='';
  const transcriptEl=document.getElementById('transcript'); transcriptEl.style.display='block'; transcriptEl.textContent='듣고 있습니다...';
  document.getElementById('recordBtn').style.display='none'; document.getElementById('stopBtn').style.display='inline-flex';
  recognition.onresult=e=>{let interim='';for(let i=e.resultIndex;i<e.results.length;i++){const t=e.results[i][0].transcript;if(e.results[i].isFinal)recordingFinalText+=t+' ';else interim+=t;}transcriptEl.textContent=(recordingFinalText+interim).trim()||'듣고 있습니다...';};
  recognition.onerror=e=>{if(e.error!=='no-speech')showToast('error','음성 인식 오류: '+e.error);};
  recognition.onend=()=>{};
  try{recognition.start();}catch(e){showToast('error','음성 인식을 시작할 수 없습니다.');}
}
async function stopRecording(){
  if(recognition){recognition.onend=null;try{recognition.stop();}catch(e){}}
  const answer=(recordingFinalText||document.getElementById('transcript')?.textContent||'').replace('듣고 있습니다...','').trim();
  if(!answer){showToast('error','답변이 인식되지 않았습니다.');return;}
  try{await persistCurrentAnswer(answer);showEditButton();showToast('success','음성 답변이 저장되었습니다.');}catch(e){showToast('error','답변 저장 실패: '+e.message);}
}

async function showInterviewComplete(){
  try{if(currentSessionId)await db.completeSession(currentSessionId); currentSessionCompleted=true; logEvent('interview_completed',{session_id:currentSessionId});}catch(e){console.error(e);}
  const c=document.getElementById('interviewContainer');
  c.innerHTML=`<div style="text-align:center;padding:40px 0"><div style="font-size:48px">🎉</div><h2>${isTestMode?'테스트 면접':'면접 연습'} 완료!</h2><p>${selectedQuestions.length}개 질문에 답변했습니다.</p><div style="margin-top:20px"><button class="btn" onclick="getFeedback()" style="background:#4caf50">AI 피드백 받기</button><button class="btn" onclick="retryInterview()" style="background:#ff9800;margin-left:8px">다시하기</button></div></div>`;
}
function resetInterview(){currentSessionId=null;currentQuestion=0;document.getElementById('interviewStartSection').style.display='block';document.getElementById('interviewContainer').style.display='none';}
function retryInterview(){resetInterview();showToast('info','같은 질문으로 다시 연습할 수 있습니다.');}

async function showSavedFeedbacks(){
  if(!currentStudentId){showToast('error','📋 생기부를 먼저 입력하고 질문을 생성해주세요. 1단계부터 진행해주세요.');return;}
  showLoading('피드백 목록 조회 중...');
  try{
    const sessions=await db.getStudentSessions(currentStudentId);
    const feedbackSessions=sessions.filter(s=>s.feedback);
    hideLoading();

    const c=document.getElementById('feedbackListContainer');
    if(!feedbackSessions.length){
      c.innerHTML='<p style="padding:40px;text-align:center;color:#999">저장된 피드백이 없습니다.<br>면접을 완료하고 피드백을 받아보세요.</p>';
    }else{
      c.innerHTML='';
      feedbackSessions.forEach(s=>{
        const div=document.createElement('div');
        div.className='student-item';
        div.dataset.sessionId=s.id;
        div.style.cssText='padding:16px;border:1px solid #ddd;border-radius:8px;margin-bottom:10px;cursor:pointer';

        const title=document.createElement('strong');
        title.textContent=`면접 세션 #${s.id}`;

        const date=document.createElement('div');
        date.style.cssText='font-size:12px;color:#888;margin-top:4px';
        date.textContent=formatDate(s.created_at);

        const status=document.createElement('div');
        status.style.cssText='font-size:12px;color:#4caf50;margin-top:4px';
        status.textContent=`질문 ${s.question_count}개 | ${s.status==='completed'?'완료':'진행중'}`;

        div.appendChild(title);
        div.appendChild(date);
        div.appendChild(status);
        c.appendChild(div);
      });

      c.onclick=e=>{
        const item=e.target.closest('.student-item');
        if(item)loadFeedback(item.dataset.sessionId);
      };
    }
    document.getElementById('feedbackListModal').classList.add('show');
  }catch(e){hideLoading();console.error(e);showToast('error','피드백 목록 조회 실패: '+e.message);}
}

function closeFeedbackListModal(){document.getElementById('feedbackListModal').classList.remove('show');}

async function loadFeedback(sessionId){
  showLoading('피드백 불러오는 중...');
  try{
    const feedback=await db.getFeedback(sessionId);
    if(!feedback)throw new Error('저장된 피드백이 없습니다.');
    closeFeedbackListModal();
    hideLoading();
    displayFeedback(feedback,sessionId);
    document.getElementById('interviewStartSection').style.display='none';
    document.getElementById('interviewContainer').style.display='block';
    showToast('success','이전 피드백을 불러왔습니다.');
  }catch(e){hideLoading();showToast('error','피드백 불러오기 실패: '+e.message);}
}

async function getFeedback(){
  if(!currentSessionId){showToast('error','🎯 분석할 면접 세션이 없습니다. 면접을 먼저 진행해주세요.');return;}
  showLoading('🎯 AI 피드백 생성 중','답변을 분석하고 맞춤형 피드백을 작성하고 있습니다 (평균 15~20초 소요)');
  try{
    const interviews=await db.getSessionInterviews(currentSessionId);
    if(!interviews.length)throw new Error('저장된 답변이 없습니다.');
    const qa=interviews.map((i,n)=>({number:n+1,question:i.question,modelAnswer:i.model_answer||'',studentAnswer:i.student_answer||''}));
    const prompt=`너는 대입 면접 평가 전문가다. 다음 학생의 실제 면접 답변만 근거로 객관적인 피드백을 작성하라. 관찰할 수 없는 목소리, 표정, 자세는 평가하지 않는다.\n\n${qa.map(x=>`[질문 ${x.number}]\n${x.question}\n[참고 답변]\n${x.modelAnswer}\n[학생 답변]\n${x.studentAnswer}`).join('\n\n')}\n\n다음 형식으로 작성한다:\n## 전체 평가\n점수: 0-100\n총평: 2-3문장\n## 질문별 분석\n각 질문마다 평가(상/중/하), 강점, 개선점\n## 종합 피드백\n잘한 점 3가지\n아쉬운 점 3가지\n개선 방향 3가지\n다음 면접 준비사항.\n'모범답안과 일치' 같은 표현은 사용하지 않는다.`;
    const feedback=await callAI(prompt,6000,'feedback',1,{session_id:currentSessionId}); if(!feedback)throw new Error('AI 피드백 응답이 비어 있습니다.');
    await db.saveFeedback(currentSessionId,feedback); logEvent('feedback_generated',{session_id:currentSessionId});

    // 수동 사용량 기록 (Edge Function 실패 대비)
    try {
      await supabaseClient.rpc('consume_ai_usage', {
        p_feature: 'feedback',
        p_quantity: 1,
        p_metadata: { session_id: currentSessionId }
      });
      console.log('✅ 사용량 기록 완료: feedback 1회');
    } catch (usageError) {
      console.warn('⚠️ 사용량 기록 실패:', usageError);
    }

    await loadPlanState(); // 사용량 표시 업데이트
    hideLoading();displayFeedback(feedback,currentSessionId);
    showToast('success','피드백이 저장되었습니다.');
  }catch(e){hideLoading();console.error(e);showToast('error','피드백 생성 실패: '+e.message);}
}
function displayFeedback(feedback,sessionId){
  const c=document.getElementById('interviewContainer');
  c.innerHTML=`<div style="line-height:1.8"><h2 style="margin-bottom:16px">🤖 면접 피드백</h2><div style="background:#f8f9ff;padding:20px;border-radius:10px">${markdownToHtml(feedback)}</div><div style="text-align:center;margin-top:20px;display:flex;gap:12px;justify-content:center;flex-wrap:wrap"><button class="btn" onclick="downloadFeedback()" style="background:#4caf50">📥 다운로드</button><button class="btn" onclick="resetInterview()">처음으로</button></div></div>`;
  window._currentFeedback=feedback;
  window._currentSessionId=sessionId;
}

function downloadFeedback(){
  const feedback=window._currentFeedback;
  if(!feedback){showToast('error','📊 피드백 데이터가 없습니다. 피드백을 먼저 생성해주세요.');return;}

  const university=localStorage.getItem('university')||'대학';
  const department=localStorage.getItem('department')||'학과';
  const now=new Date().toLocaleString('ko-KR').replace(/[:/\s]/g,'-');

  const html=`<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>면접 피드백 - ${university} ${department}</title>
<style>
* { margin:0; padding:0; box-sizing:border-box; }
body {
  font-family: 'Pretendard', -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  min-height: 100vh;
  padding: 40px 20px;
  line-height: 1.6;
}
.container {
  max-width: 800px;
  margin: 0 auto;
  background: white;
  border-radius: 20px;
  padding: 40px;
  box-shadow: 0 20px 60px rgba(0,0,0,0.3);
}
h1 { font-size: 28px; margin-bottom: 8px; color: #333; }
.meta { font-size: 14px; color: #666; margin-bottom: 30px; }
.content {
  background: #f8f9ff;
  padding: 30px;
  border-radius: 12px;
  line-height: 1.8;
}
h2, h3 { margin-top: 24px; margin-bottom: 12px; color: #333; }
strong { font-weight: 700; color: #1a1a1a; }
ul { margin: 12px 0; padding-left: 24px; }
li { margin: 6px 0; }
code { background: #f5f5f5; padding: 2px 6px; border-radius: 3px; font-family: monospace; font-size: 13px; }
@media print {
  body { background: white; padding: 0; }
  .container { box-shadow: none; }
}
</style>
</head>
<body>
<div class="container">
  <h1>🤖 면접 피드백</h1>
  <div class="meta">${university} ${department} | ${new Date().toLocaleDateString('ko-KR')}</div>
  <div class="content">
    ${markdownToHtml(feedback)}
  </div>
</div>
</body>
</html>`;

  const blob=new Blob([html],{type:'text/html;charset=utf-8'});
  const url=URL.createObjectURL(blob);
  const a=document.createElement('a');
  a.href=url;
  a.download=`AI면접피드백_${university}_${department}_${now}.html`;
  a.click();
  URL.revokeObjectURL(url);
  showToast('success','피드백이 다운로드되었습니다.');
}

async function loadStudentRecord(){
  try{
    const students=await db.getAllStudents();
    console.log('📊 Students data:', students);
    const c=document.getElementById('studentListContainer');

    if(!students.length){
      c.innerHTML='<p style="padding:20px">저장된 생기부가 없습니다.</p>';
      document.getElementById('loadStudentModal').classList.add('show');
      return;
    }

    // 안전하게 HTML 생성
    c.innerHTML='';
    students.forEach(s=>{
      console.log('Student:', s.university, s.department, 'created_at:', s.created_at);

      const div=document.createElement('div');
      div.className='student-item';
      div.dataset.id=s.id;
      div.style.cssText='padding:16px;border:1px solid #ddd;border-radius:8px;margin-bottom:10px;cursor:pointer';

      const title=document.createElement('strong');
      title.textContent=(s.university||'대학 미상')+' - '+(s.department||'학과 미상');

      const date=document.createElement('div');
      date.style.cssText='font-size:12px;color:#888;margin-top:4px';
      date.textContent=formatDate(s.created_at);

      div.appendChild(title);
      div.appendChild(date);
      c.appendChild(div);
    });

    c.onclick=e=>{const item=e.target.closest('.student-item');if(item)selectStudent(item.dataset.id);};
    document.getElementById('loadStudentModal').classList.add('show');
  }catch(e){console.error('❌ Load error:', e);showToast('error','목록 조회 실패: '+e.message);}
}
function closeLoadStudentModal(){document.getElementById('loadStudentModal').classList.remove('show');}
async function selectStudent(id){
  try{showLoading('불러오는 중...','생기부와 질문을 불러옵니다.');const s=await db.getStudent(id);currentStudentId=s.id;savedRecord=s.record||s.masked_record||'';maskedRecord=s.masked_record||s.record||'';document.getElementById('studentRecord').value=s.record||s.masked_record||'';document.getElementById('university').value=s.university||'';document.getElementById('department').value=s.department||'';localStorage.setItem('university',s.university||'');localStorage.setItem('department',s.department||'');const q=await db.getQuestions(id);questions=q?.questions||[];document.getElementById('analysisResult').style.display='block';completeStep(1);if(questions.length){displayQuestions();completeStep(2);}closeLoadStudentModal();hideLoading();showToast('success',`생기부와 질문 ${questions.length}개를 불러왔습니다.`);}catch(e){hideLoading();showToast('error','불러오기 실패: '+e.message);}
}
async function loadQuestionsOnly(){await loadStudentRecord();}
async function selectQuestionsOnly(id){await selectStudent(id);switchStep(2);}

function showLoading(text, subtext, progress = false) {
  if (progress) {
    const b = document.getElementById('backgroundProgress');
    b.style.display = 'block';
    document.getElementById('bgProgressTitle').textContent = text;
    document.getElementById('bgProgressSubtitle').textContent = subtext || '';
    let p = 0;
    let elapsed = 0;
    clearInterval(loadingProgressInterval);
    loadingProgressInterval = setInterval(() => {
      elapsed += 400;
      p = Math.min(90, p + Math.random() * 4);
      document.getElementById('bgProgressBar').style.width = p + '%';
      document.getElementById('bgProgressText').textContent = Math.floor(p) + '%';

      // 경과 시간 표시
      const seconds = Math.floor(elapsed / 1000);
      if (seconds > 0) {
        const timeText = seconds < 60 ? `${seconds}초 경과` : `${Math.floor(seconds/60)}분 ${seconds%60}초 경과`;
        document.getElementById('bgProgressSubtitle').textContent = (subtext || '') + ` • ${timeText}`;
      }
    }, 400);
  } else {
    document.getElementById('loadingText').textContent = text;
    document.getElementById('loadingSubtext').textContent = subtext || '';
    document.getElementById('loadingOverlay').classList.add('show');
  }
}
// hideLoading은 진행바 관리 기능이 추가된 버전 (app 전용)
function hideLoading(){if(loadingProgressInterval){clearInterval(loadingProgressInterval);loadingProgressInterval=null;document.getElementById('bgProgressBar').style.width='100%';document.getElementById('bgProgressText').textContent='100%';setTimeout(()=>{document.getElementById('backgroundProgress').style.display='none';document.getElementById('bgProgressBar').style.width='0%';document.getElementById('bgProgressText').textContent='0%';},500);}document.getElementById('loadingOverlay').classList.remove('show');}
function minimizeProgress(){document.getElementById('backgroundProgress').style.display='none';}
// showToast는 common.js에서 제공 (중복 제거)

window.addEventListener('DOMContentLoaded',async()=>{
  lucide.createIcons();loadSettings();await checkAuth();
  try{await db.init(); await loadPlanState();}catch(e){console.error(e);showToast('error',e.message);}
  document.getElementById('aiProvider')?.addEventListener('change',updateAISettingsHelp);
  const SpeechRecognition=window.SpeechRecognition||window.webkitSpeechRecognition;if(SpeechRecognition)console.log('음성 인식 지원');
});

