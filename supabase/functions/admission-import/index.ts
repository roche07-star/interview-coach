import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY')
const ADMIN_EMAIL = Deno.env.get('ADMIN_EMAIL') || 'ziron7@gmail.com'
const corsHeaders = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'}
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...corsHeaders,'Content-Type':'application/json'}})
function stripHtml(html:string){return html.replace(/<script[\s\S]*?<\/script>/gi,' ').replace(/<style[\s\S]*?<\/style>/gi,' ').replace(/<noscript[\s\S]*?<\/noscript>/gi,' ').replace(/<[^>]+>/g,' ').replace(/&nbsp;/gi,' ').replace(/&amp;/gi,'&').replace(/&lt;/gi,'<').replace(/&gt;/gi,'>').replace(/\s+/g,' ').trim()}
serve(async(req)=>{
 if(req.method==='OPTIONS') return new Response('ok',{headers:corsHeaders});
 if(req.method!=='POST') return json({error:'Method not allowed'},405)
 try{
  const auth=req.headers.get('Authorization'); if(!auth?.startsWith('Bearer ')) return json({error:'로그인이 필요합니다.'},401)
  const token=auth.replace('Bearer ','').trim();
  const userClient=createClient(SUPABASE_URL,SUPABASE_ANON_KEY,{global:{headers:{Authorization:`Bearer ${token}`}},auth:{persistSession:false,autoRefreshToken:false}})
  const {data:{user},error}=await userClient.auth.getUser(token); if(error||!user) return json({error:'유효하지 않은 로그인 세션입니다.'},401)
  if(user.email!==ADMIN_EMAIL) return json({error:'관리자 권한이 없습니다.'},403)
  const {admission_year, university, source_url}=await req.json()
  const year=Number(admission_year); if(!Number.isInteger(year)||year<2020||year>2100) return json({error:'입시연도를 확인하세요.'},400)
  if(!university||!source_url) return json({error:'대학과 공식 출처 URL이 필요합니다.'},400)
  let url:URL; try{url=new URL(source_url)}catch{ return json({error:'올바른 URL을 입력하세요.'},400) }
  if(!/^https?:$/.test(url.protocol)) return json({error:'http/https URL만 지원합니다.'},400)
  const response=await fetch(url.toString(),{headers:{'User-Agent':'Mozilla/5.0 AI-Interview-Coach Admission Importer'}})
  if(!response.ok) return json({error:`출처 페이지를 가져오지 못했습니다. (${response.status})`},502)
  const contentType=response.headers.get('content-type')||''
  if(contentType.includes('application/pdf')) return json({error:'PDF 직접 가져오기는 다음 단계에서 지원합니다. 현재는 대학 입학처의 HTML 전형 안내 페이지 URL을 사용하세요.'},415)
  const html=await response.text(); const text=stripHtml(html).slice(0,50000)
  if(text.length<200) return json({error:'페이지에서 충분한 텍스트를 찾지 못했습니다.'},422)
  if(!ANTHROPIC_API_KEY) return json({error:'ANTHROPIC_API_KEY가 Edge Function에 설정되지 않았습니다.'},500)
  const prompt=`너는 한국 대학 입시 전형 데이터 정규화 전문가다. 아래는 대학 입학처의 공식 페이지에서 추출한 텍스트다. 지정된 대학의 ${year}학년도 학생부종합전형 정보를 구조화하라. 페이지에 명시되지 않은 사실은 만들지 말고, 불확실하면 빈 문자열 또는 '공식자료 확인 필요'로 표시한다. 여러 전형이 있으면 각각 별도 항목으로 만든다. 모집단위별로 다른 경우 department_scope에 범위를 적는다. 반드시 JSON만 출력한다.\n\n출력: {"tracks":[{"track":"전형명","department_scope":"모집단위 범위","document_criteria":"서류평가 요소","interview_criteria":"면접평가 요소/방식","method":"전형방법"}]}\n\n대학: ${university}\n입시연도: ${year}\n출처: ${source_url}\n\n[원문]\n${text}`
  const ai=await fetch('https://api.anthropic.com/v1/messages',{method:'POST',headers:{'Content-Type':'application/json','x-api-key':ANTHROPIC_API_KEY,'anthropic-version':'2023-06-01'},body:JSON.stringify({model:'claude-sonnet-4-5-20250929',max_tokens:6000,messages:[{role:'user',content:prompt}]})})
  const aiData=await ai.json(); if(!ai.ok) return json({error:aiData.error?.message||'AI 구조화 실패'},ai.status)
  const raw=aiData.content?.[0]?.text||''; const start=raw.indexOf('{'),end=raw.lastIndexOf('}'); if(start<0||end<=start) return json({error:'AI가 유효한 전형 JSON을 반환하지 않았습니다.'},502)
  const parsed=JSON.parse(raw.slice(start,end+1)); const tracks=Array.isArray(parsed.tracks)?parsed.tracks:[]; if(!tracks.length) return json({error:'전형 정보를 찾지 못했습니다.'},422)
  const admin=createClient(SUPABASE_URL,SERVICE_ROLE_KEY)
  const rows=tracks.map((t:any)=>({admission_year:year,university,track:String(t.track||'').trim(),department_scope:String(t.department_scope||'').trim(),document_criteria:String(t.document_criteria||'').trim(),interview_criteria:String(t.interview_criteria||'').trim(),method:String(t.method||'').trim(),source_url:source_url,source_title:university+' '+year+'학년도 공식 전형 안내',source_checked_at:new Date().toISOString(),import_status:'draft',raw_source_text:text,import_notes:'AI 자동 구조화 완료. 관리자 검수 후 공개하세요.'})).filter((r:any)=>r.track)
  const {data, error:upsertError}=await admin.from('admission_tracks').upsert(rows,{onConflict:'admission_year,university,track'}).select()
  if(upsertError) return json({error:upsertError.message},500)
  return json({ok:true,count:data?.length||0,tracks:data})
 }catch(e){console.error(e);return json({error:e instanceof Error?e.message:'가져오기 중 오류가 발생했습니다.'},500)}
})
