// Hardened AI Vision Proxy — Supabase Edge Function (SEC-03)
// Contract: docs/contracts/app-session.md

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { verifySession } from '../_shared/session.ts';

const GEMINI_BASE = 'https://generativelanguage.googleapis.com/v1beta/openai';
const MAX_BODY_BYTES = 8_000_000;
const MAX_TOKENS_CAP = 1024;

const VALID_REASONING_EFFORTS = new Set(['none', 'low', 'medium', 'high']);
const REASONING_FAMILY_MARKERS = [
  '3.1',
  '3.6',
  '3.7',
  '3.8',
  '3-flash',
  'reasoning',
  'thinking',
];

function modelSupportsReasoningEffort(modelId: string): boolean {
  return REASONING_FAMILY_MARKERS.some((marker) => modelId.includes(marker));
}

function resolveReasoningEffort(rawEffort: unknown, modelId: string): string | undefined {
  if (
    typeof rawEffort === 'string' &&
    VALID_REASONING_EFFORTS.has(rawEffort) &&
    modelSupportsReasoningEffort(modelId)
  ) {
    return rawEffort;
  }
  return undefined;
}

function resolveResponseFormat(raw: unknown): { type: 'json_object' } | undefined {
  if (
    raw !== null &&
    typeof raw === 'object' &&
    !Array.isArray(raw) &&
    (raw as Record<string, unknown>).type === 'json_object'
  ) {
    return { type: 'json_object' };
  }
  return undefined;
}

export const ALLOWED_MODELS = [
  'gemini-3-flash-preview',
  'gemini-3.5-flash',
  'gemini-3.6-flash',
  'gemini-3.8-flash',
  'gemini-3.5-flash-lite',
  'gemini-flash-lite-latest',
  'gemini-3.1-flash-lite',
  'gemini-flash-lite',
  'gemini-2.5-flash',
  'gemini-2.5-flash-lite',
  'gemini-2.0-flash',
] as const;

const ALLOWED_MODEL_SET = new Set<string>(ALLOWED_MODELS);

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-app-session',
  'Access-Control-Max-Age': '86400',
};

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
    },
  });
}

async function readBodyCapped(
  req: Request,
  maxBytes: number,
): Promise<{ ok: true; text: string } | { ok: false; status: number; error: string }> {
  if (!req.body) {
    return { ok: false, status: 400, error: 'empty body' };
  }
  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      if (value) {
        total += value.byteLength;
        if (total > maxBytes) {
          try {
            await reader.cancel();
          } catch {
            // ignore stream cancel error
          }
          return { ok: false, status: 413, error: 'payload too large' };
        }
        chunks.push(value);
      }
    }
  } catch {
    return { ok: false, status: 400, error: 'invalid body stream' };
  }

  const merged = new Uint8Array(total);
  let offset = 0;
  for (const c of chunks) {
    merged.set(c, offset);
    offset += c.byteLength;
  }
  return { ok: true, text: new TextDecoder().decode(merged) };
}

export async function handleAiVision(
  req: Request,
  fetchImpl: typeof fetch = fetch,
): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'method not allowed' }, 405);
  }

  // ENFORCE_SESSION rollout control:
  // - When 'true': valid x-app-session required on every request.
  // - Otherwise (compat mode for 2.0.132): present token must verify (bad token -> 401),
  //   absent header proceeds without session check while still enforcing all body/model caps.
  const enforceSession = Deno.env.get('ENFORCE_SESSION') === 'true';
  const rawSessionHeader = req.headers.get('x-app-session');
  if (rawSessionHeader !== null && rawSessionHeader.trim().length > 0) {
    const session = await verifySession(req);
    if (!session) {
      return json({ error: 'unauthorized' }, 401);
    }
    if (session.role === 'admin_pos') return json({ error: 'forbidden' }, 403);
  } else if (enforceSession) {
    return json({ error: 'unauthorized' }, 401);
  }

  // Reject missing or oversize content-length BEFORE reading body
  const clHeader = req.headers.get('content-length');
  if (!clHeader || !/^\d+$/.test(clHeader.trim())) {
    return json({ error: 'content-length required' }, 411);
  }
  const declaredLength = Number(clHeader.trim());
  if (!Number.isFinite(declaredLength) || declaredLength <= 0) {
    return json({ error: 'invalid content-length' }, 400);
  }
  if (declaredLength > MAX_BODY_BYTES) {
    return json({ error: 'payload too large' }, 413);
  }

  const bodyResult = await readBodyCapped(req, MAX_BODY_BYTES);
  if (!bodyResult.ok) {
    return json({ error: bodyResult.error }, bodyResult.status);
  }

  let parsed: Record<string, unknown>;
  try {
    const decoded = JSON.parse(bodyResult.text);
    if (!decoded || typeof decoded !== 'object' || Array.isArray(decoded)) {
      return json({ error: 'invalid json body' }, 400);
    }
    parsed = decoded as Record<string, unknown>;
  } catch {
    return json({ error: 'invalid json body' }, 400);
  }

  const model = typeof parsed.model === 'string' ? parsed.model.trim() : '';
  if (!ALLOWED_MODEL_SET.has(model)) {
    return json({ error: 'model not allowed' }, 400);
  }

  if (!Array.isArray(parsed.messages) || parsed.messages.length === 0) {
    return json({ error: 'invalid messages' }, 400);
  }

  const clientMaxTokens =
    typeof parsed.max_tokens === 'number' &&
      Number.isFinite(parsed.max_tokens) &&
      parsed.max_tokens > 0
      ? Math.floor(parsed.max_tokens)
      : MAX_TOKENS_CAP;
  const maxTokens = Math.min(clientMaxTokens, MAX_TOKENS_CAP);

  const clientTemp =
    typeof parsed.temperature === 'number' && Number.isFinite(parsed.temperature)
      ? parsed.temperature
      : 0;
  const temperature = Math.min(1, Math.max(0, clientTemp));

  const responseFormat = resolveResponseFormat(parsed.response_format);
  const reasoningEffort = resolveReasoningEffort(parsed.reasoning_effort, model);

  // Build clean upstream body: drop every other client field
  const cleanPayload: Record<string, unknown> = {
    model,
    messages: parsed.messages,
    max_tokens: maxTokens,
    temperature,
    ...(responseFormat ? { response_format: responseFormat } : {}),
    ...(reasoningEffort ? { reasoning_effort: reasoningEffort } : {}),
  };

  const apiKey = Deno.env.get('GEMINI_API_KEY');
  if (!apiKey) {
    console.error('ai-vision: missing GEMINI_API_KEY');
    return json({ error: 'ai unavailable' }, 502);
  }

  const callGemini = (key: string, bodyObj: Record<string, unknown>) =>
    fetchImpl(`${GEMINI_BASE}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${key}`,
      },
      body: JSON.stringify(bodyObj),
    });

  try {
    let upstream = await callGemini(apiKey, cleanPayload);

    const fallbackKey = Deno.env.get('GEMINI_API_KEY_FALLBACK');
    if (fallbackKey && [429, 500, 502, 503, 504].includes(upstream.status)) {
      const fallbackModelRaw = Deno.env.get('GEMINI_FALLBACK_MODEL') ?? 'gemini-3.5-flash';
      const fallbackModel = ALLOWED_MODEL_SET.has(fallbackModelRaw)
        ? fallbackModelRaw
        : 'gemini-3.5-flash';
      const fallbackPayload: Record<string, unknown> = {
        ...cleanPayload,
        model: fallbackModel,
      };
      const fallbackReasoningEffort = resolveReasoningEffort(
        parsed.reasoning_effort,
        fallbackModel,
      );
      if (fallbackReasoningEffort) {
        fallbackPayload.reasoning_effort = fallbackReasoningEffort;
      } else {
        delete fallbackPayload.reasoning_effort;
      }
      upstream = await callGemini(fallbackKey, fallbackPayload);
    }

    if (!upstream.ok) {
      console.error(`ai-vision upstream status: ${upstream.status}`);
      return json({ error: 'ai unavailable' }, 502);
    }

    const text = await upstream.text();
    return new Response(text, {
      status: upstream.status,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
        'Cache-Control': 'no-store',
      },
    });
  } catch {
    console.error('ai-vision upstream fetch failed');
    return json({ error: 'ai unavailable' }, 502);
  }
}

if (!Deno.env.get('DENO_TESTING')) {
  serve((req: Request) => handleAiVision(req));
}
