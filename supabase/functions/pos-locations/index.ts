// Supabase Edge Function: pos-locations
// Contract reference: docs/contracts/pos-locations.md
// Manages POS locations in public.pos_locations (upsert, delete, import)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const MAX_BODY_BYTES = 64 * 1024; // 64 KB
const POS_ID_REGEX = /^[A-Za-z0-9_-]{3,60}$/;
const BRANCH_VALUES = new Set(['manado', 'bali', 'ho']);
const SPECIAL_CHARS = /[,()*%]/;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
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

function validateLocation(loc: any): { valid: boolean; cleaned?: any; error?: string } {
  if (!loc || typeof loc !== 'object') {
    return { valid: false, error: 'location must be an object' };
  }
  const { pos_id, pos_name, cabang_name, full_address, location_tag, tag_color, branch, lat, lng } = loc;

  if (typeof pos_id !== 'string' || !POS_ID_REGEX.test(pos_id)) {
    return { valid: false, error: 'invalid pos_id' };
  }
  if (typeof pos_name !== 'string' || pos_name.length < 1 || pos_name.length > 120) {
    return { valid: false, error: 'invalid pos_name' };
  }
  if (typeof cabang_name !== 'string' || cabang_name.length < 1 || cabang_name.length > 120) {
    return { valid: false, error: 'invalid cabang_name' };
  }
  const address = typeof full_address === 'string' ? full_address : '';
  if (address.length > 300) {
    return { valid: false, error: 'invalid full_address' };
  }
  if (typeof location_tag !== 'string' || location_tag.trim().length < 1 || location_tag.trim().length > 16) {
    return { valid: false, error: 'invalid location_tag' };
  }
  const cleanTag = location_tag.trim().toUpperCase();

  const color = typeof tag_color === 'number' ? Math.floor(tag_color) : 4294286859;

  if (typeof branch !== 'string' || !BRANCH_VALUES.has(branch)) {
    return { valid: false, error: 'invalid branch' };
  }
  if (typeof lat !== 'number' || isNaN(lat) || lat < -90 || lat > 90) {
    return { valid: false, error: 'invalid lat' };
  }
  if (typeof lng !== 'number' || isNaN(lng) || lng < -180 || lng > 180) {
    return { valid: false, error: 'invalid lng' };
  }

  return {
    valid: true,
    cleaned: {
      pos_id,
      pos_name,
      cabang_name,
      full_address: address,
      location_tag: cleanTag,
      tag_color: color,
      branch,
      lat,
      lng,
    },
  };
}

async function verifySpv(
  supabaseUrl: string,
  serviceKey: string,
  identity: unknown,
  password: unknown
): Promise<{ ok: boolean; status: number; error: string }> {
  if (typeof identity !== 'string' || typeof password !== 'string') {
    return { ok: false, status: 401, error: 'unauthorized' };
  }
  const idStr = identity.trim();
  const passStr = password.trim();
  if (idStr.length === 0 || idStr.length > 100 || SPECIAL_CHARS.test(idStr)) {
    return { ok: false, status: 401, error: 'unauthorized' };
  }
  if (passStr.length === 0) {
    return { ok: false, status: 401, error: 'unauthorized' };
  }

  const encId = encodeURIComponent(idStr);
  const url = `${supabaseUrl}/rest/v1/app_users?or=(username.ilike.${encId},email.ilike.${encId},nama.ilike.${encId})&select=username,email,nama,password,role`;

  try {
    const res = await fetch(url, {
      method: 'GET',
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
      },
    });

    if (!res.ok) {
      console.error(`app_users query failed with status ${res.status}`);
      return { ok: false, status: 500, error: 'server error' };
    }

    const users = await res.json();
    if (!Array.isArray(users) || users.length === 0) {
      return { ok: false, status: 401, error: 'unauthorized' };
    }

    const lowerId = idStr.toLowerCase();
    const matched = users.find((u: any) =>
      (u.username && String(u.username).trim().toLowerCase() === lowerId) ||
      (u.email && String(u.email).trim().toLowerCase() === lowerId) ||
      (u.nama && String(u.nama).trim().toLowerCase() === lowerId)
    );

    if (!matched) {
      return { ok: false, status: 401, error: 'unauthorized' };
    }

    const userPass = String(matched.password ?? '').trim().toLowerCase();
    if (userPass !== passStr.toLowerCase()) {
      return { ok: false, status: 401, error: 'unauthorized' };
    }

    const userRole = String(matched.role ?? '').trim().toLowerCase();
    if (userRole !== 'spv') {
      return { ok: false, status: 403, error: 'forbidden' };
    }

    return { ok: true, status: 200, error: '' };
  } catch (err) {
    console.error('SPV check error:', err instanceof Error ? err.message : String(err));
    return { ok: false, status: 500, error: 'server error' };
  }
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'method not allowed' }, 405);
  }

  const contentLength = Number(req.headers.get('content-length') ?? '0');
  if (contentLength > MAX_BODY_BYTES) {
    return json({ error: 'payload too large' }, 413);
  }

  const rawBody = await req.text();
  if (new TextEncoder().encode(rawBody).length > MAX_BODY_BYTES) {
    return json({ error: 'payload too large' }, 413);
  }

  let body: any;
  try {
    body = JSON.parse(rawBody);
  } catch {
    return json({ error: 'invalid' }, 400);
  }

  if (!body || typeof body !== 'object') {
    return json({ error: 'invalid' }, 400);
  }

  const action = body.action;
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !serviceRoleKey) {
    console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
    return json({ error: 'server error' }, 500);
  }

  if (action === 'upsert') {
    const { identity, password, location } = body;
    const auth = await verifySpv(supabaseUrl, serviceRoleKey, identity, password);
    if (!auth.ok) {
      return json({ error: auth.error }, auth.status);
    }

    const val = validateLocation(location);
    if (!val.valid || !val.cleaned) {
      return json({ error: 'invalid' }, 400);
    }

    const row = {
      ...val.cleaned,
      active: true,
      source: 'spv',
      updated_by: String(identity).trim(),
    };

    const url = `${supabaseUrl}/rest/v1/pos_locations?on_conflict=pos_id`;
    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
          'Content-Type': 'application/json',
          'Prefer': 'resolution=merge-duplicates,return=representation',
        },
        body: JSON.stringify(row),
      });

      if (!res.ok) {
        console.error(`upsert failed with status ${res.status}`);
        return json({ error: 'server error' }, 500);
      }

      return json({ ok: true, count: 1 }, 200);
    } catch (err) {
      console.error('upsert error:', err instanceof Error ? err.message : String(err));
      return json({ error: 'server error' }, 500);
    }
  }

  if (action === 'delete') {
    const { identity, password, pos_id } = body;
    const auth = await verifySpv(supabaseUrl, serviceRoleKey, identity, password);
    if (!auth.ok) {
      return json({ error: auth.error }, auth.status);
    }

    if (typeof pos_id !== 'string' || !POS_ID_REGEX.test(pos_id)) {
      return json({ error: 'invalid' }, 400);
    }

    const url = `${supabaseUrl}/rest/v1/pos_locations?pos_id=eq.${encodeURIComponent(pos_id)}`;
    try {
      const res = await fetch(url, {
        method: 'PATCH',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: JSON.stringify({
          active: false,
          updated_by: String(identity).trim(),
        }),
      });

      if (!res.ok) {
        console.error(`delete failed with status ${res.status}`);
        return json({ error: 'server error' }, 500);
      }

      const rows = await res.json();
      const count = Array.isArray(rows) ? rows.length : 1;
      return json({ ok: true, count }, 200);
    } catch (err) {
      console.error('delete error:', err instanceof Error ? err.message : String(err));
      return json({ error: 'server error' }, 500);
    }
  }

  if (action === 'import') {
    const { locations } = body;
    if (!Array.isArray(locations) || locations.length === 0 || locations.length > 50) {
      return json({ error: 'invalid' }, 400);
    }

    const rows: any[] = [];
    for (const item of locations) {
      const val = validateLocation(item);
      if (!val.valid || !val.cleaned) {
        return json({ error: 'invalid' }, 400);
      }
      rows.push({
        ...val.cleaned,
        active: true,
        source: 'device_import',
      });
    }

    const url = `${supabaseUrl}/rest/v1/pos_locations?on_conflict=pos_id`;
    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
          'Content-Type': 'application/json',
          'Prefer': 'resolution=ignore-duplicates,return=representation',
        },
        body: JSON.stringify(rows),
      });

      if (!res.ok) {
        console.error(`import failed with status ${res.status}`);
        return json({ error: 'server error' }, 500);
      }

      const inserted = await res.json();
      const count = Array.isArray(inserted) ? inserted.length : rows.length;
      return json({ ok: true, count }, 200);
    } catch (err) {
      console.error('import error:', err instanceof Error ? err.message : String(err));
      return json({ error: 'server error' }, 500);
    }
  }

  return json({ error: 'invalid' }, 400);
});
