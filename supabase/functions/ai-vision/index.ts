// Proxy AI Vision — Supabase Edge Function.
//
// Tujuan: API key Gemini TIDAK ikut terpasang di APK / bundle web.
// Client (app) tetap memanggil AI seperti biasa, hanya lewat fungsi ini.
//
// Deploy:
//   1. Set secret di server:  supabase secrets set GEMINI_API_KEY=<key-bar>
//      (opsional)             supabase secrets set APP_PROXY_SECRET=<shared-secret>
//   2. Deploy:                supabase functions deploy ai-vision
//
// Catatan:
// - Body request diteruskan apa adanya ke endpoint OpenAI-compatible Gemini,
//   jadi format di sisi app tidak berubah sama sekali.
// - CORS wajib: tanpa header ini, browser (web PWA) memblokir preflight.
// - Kalau APP_PROXY_SECRET diset, header 'x-app-secret' wajib cocok.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const GEMINI_BASE = 'https://generativelanguage.googleapis.com/v1beta/openai';
const MAX_BODY_BYTES = 12_000_000; // foto base64 + prompt
const ALLOWED_MODELS = [
  'gemini-3.6-flash',
  'gemini-3.5-flash-lite',
  'gemini-flash-lite-latest',
  'gemini-3.1-flash-lite',
  'gemini-flash-lite',
];

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-app-secret',
  'Access-Control-Max-Age': '86400',
};

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
    },
  });
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'method not allowed' }, 405);
  }

  const apiKey = Deno.env.get('GEMINI_API_KEY');
  if (!apiKey) {
    return json({ error: 'GEMINI_API_KEY belum diset di server' }, 500);
  }

  const appSecret = Deno.env.get('APP_PROXY_SECRET');
  if (appSecret && req.headers.get('x-app-secret') !== appSecret) {
    return json({ error: 'unauthorized' }, 401);
  }

  const rawBody = await req.text();
  if (rawBody.length > MAX_BODY_BYTES) {
    return json({ error: 'payload too large' }, 413);
  }

  // Batasi model ke daftar yang diizinkan supaya client tidak bisa memakai
  // proxy ini untuk model lain di luar kebutuhan app.
  let model = '';
  try {
    const parsed = JSON.parse(rawBody);
    model = typeof parsed?.model === 'string' ? parsed.model : '';
  } catch {
    return json({ error: 'invalid json body' }, 400);
  }
  if (!ALLOWED_MODELS.includes(model)) {
    return json({ error: 'model not allowed' }, 400);
  }

  try {
    const upstream = await fetch(`${GEMINI_BASE}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: rawBody,
    });

    const text = await upstream.text();
    return new Response(text, {
      status: upstream.status,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
        'Cache-Control': 'no-store',
      },
    });
  } catch (err) {
    return json({ error: 'upstream error', detail: String(err) }, 502);
  }
});
