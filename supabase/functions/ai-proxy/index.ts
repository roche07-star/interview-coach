import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY')
const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY')
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405)
  }

  try {
    // Do not trust the client just because it has the public anon key.
    // Verify the user's Supabase access token on every AI request.
    const authorization = req.headers.get('Authorization')
    if (!authorization?.startsWith('Bearer ')) {
      return jsonResponse({ error: '로그인이 필요합니다.' }, 401)
    }

    if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
      console.error('Missing Supabase environment variables')
      return jsonResponse({ error: 'AI 서버 인증 설정이 완료되지 않았습니다.' }, 500)
    }

    const token = authorization.replace('Bearer ', '').trim()
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: {
        headers: { Authorization: `Bearer ${token}` },
      },
      auth: { persistSession: false, autoRefreshToken: false },
    })

    const { data: { user }, error: userError } = await supabase.auth.getUser(token)
    if (userError || !user) {
      return jsonResponse({ error: '유효하지 않은 로그인 세션입니다. 다시 로그인해 주세요.' }, 401)
    }

    // Server-side approval check. The browser-side check in app.html is not
    // sufficient because a client can call an Edge Function directly.
    const { data: approval, error: approvalError } = await supabase
      .from('user_approvals')
      .select('approval_status, deleted_at')
      .eq('user_id', user.id)
      .maybeSingle()

    if (approvalError) {
      console.error('Approval lookup failed:', approvalError)
      return jsonResponse({ error: '사용자 승인 상태를 확인하지 못했습니다.' }, 500)
    }

    if (!approval || approval.deleted_at) {
      return jsonResponse({ error: 'AI 면접코치 이용 승인이 필요합니다.' }, 403)
    }

    if (approval.approval_status !== 'approved') {
      return jsonResponse({ error: '관리자 승인 후 AI 기능을 이용할 수 있습니다.' }, 403)
    }

    const body = await req.json()
    const { provider, prompt, max_tokens } = body

    if (typeof prompt !== 'string' || !prompt.trim()) {
      return jsonResponse({ error: 'AI 요청 내용이 없습니다.' }, 400)
    }

    // Prevent an accidental/malicious client request from consuming an
    // unexpectedly large amount of provider quota. Feature-specific limits
    // will be added in the next phase with the FREE/BETA usage system.
    const requestedMaxTokens = Number(max_tokens || 4096)
    if (!Number.isFinite(requestedMaxTokens) || requestedMaxTokens < 1 || requestedMaxTokens > 20000) {
      return jsonResponse({ error: 'max_tokens는 1~20000 범위여야 합니다.' }, 400)
    }

    if (provider === 'claude') {
      if (!ANTHROPIC_API_KEY) {
        return jsonResponse({ error: 'Claude API가 서버에 설정되지 않았습니다.' }, 500)
      }

      const response = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': ANTHROPIC_API_KEY,
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify({
          model: 'claude-sonnet-4-5-20250929',
          max_tokens: requestedMaxTokens,
          messages: [{ role: 'user', content: prompt }],
        }),
      })

      const data = await response.json()

      if (!response.ok) {
        console.error('Claude API error:', response.status, data)
        return jsonResponse({ error: data.error?.message || 'Claude API error' }, response.status)
      }

      return jsonResponse({
        text: data.content?.[0]?.text || '',
        usage: data.usage,
      })
    }

    if (provider === 'openai') {
      if (!OPENAI_API_KEY) {
        return jsonResponse({ error: 'OpenAI API가 서버에 설정되지 않았습니다.' }, 500)
      }

      const response = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${OPENAI_API_KEY}`,
        },
        body: JSON.stringify({
          model: 'gpt-4o',
          messages: [{ role: 'user', content: prompt }],
          max_tokens: requestedMaxTokens,
        }),
      })

      const data = await response.json()

      if (!response.ok) {
        console.error('OpenAI API error:', response.status, data)
        return jsonResponse({ error: data.error?.message || 'OpenAI API error' }, response.status)
      }

      return jsonResponse({
        text: data.choices?.[0]?.message?.content || '',
        usage: data.usage,
      })
    }

    return jsonResponse({ error: 'Invalid provider. Use "claude" or "openai".' }, 400)
  } catch (error) {
    console.error('AI proxy unexpected error:', error)
    return jsonResponse(
      { error: error instanceof Error ? error.message : 'AI 서버에서 오류가 발생했습니다.' },
      500,
    )
  }
})
