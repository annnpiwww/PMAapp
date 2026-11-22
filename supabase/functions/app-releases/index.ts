// Supabase Edge Function: app-releases
// PMApp P1 in-app updater backend: public 'latest' check + allowlisted publisher admin actions.
// Contract: docs/contracts/app-releases.md

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient, type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { verifySession } from '../_shared/session.ts';
import {
  APP_ID,
  decideUpdate,
  normalizeCabang,
  objectPath,
  parsePublisherUids,
  pickRelease,
  validateCreate,
  validateLatestInput,
  validateTargetCabang,
} from './logic.ts';
import {
  type R2Config,
  presignR2Url,
  r2Delete,
  r2GetBytes,
  readR2Config,
} from './r2.ts';

const MAX_BODY_BYTES = 32 * 1024;
const BUCKET_NAME = 'app-releases';
const SIGNED_DOWNLOAD_TTL_SECONDS = 900;
const SIGNED_UPLOAD_TTL_SECONDS = 900;
const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const ADMIN_SELECT_COLUMNS =
  'id, app, abi, version_code, base_version_code, version_name, sha256, size_bytes, changelog, mandatory, min_supported_version, target_cabang, backend, status, created_by, created_at, published_at';

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

async function computeSha256Hex(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', bytes as BufferSource);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

// Retention: keep only the latest published APK per ABI in storage; archive older rows.
async function runRetention(
  // deno-lint-ignore no-explicit-any
  supabase: SupabaseClient<any>,
  row: { id: string; abi: string; version_code: number; apk_path: string | null },
  r2: R2Config | null,
): Promise<number> {
  const { data: olderRows, error: olderErr } = await supabase
    .from('app_releases')
    .select('id, apk_path, backend')
    .eq('app', APP_ID)
    .eq('abi', row.abi)
    .in('status', ['published', 'rolled_back'])
    .lt('version_code', Number(row.version_code))
    .neq('id', row.id);

  if (olderErr) {
    console.error('app-releases retention query error:', olderErr.message);
    return 0;
  }
  if (!Array.isArray(olderRows) || olderRows.length === 0) {
    return 0;
  }

  const supabasePathsToRemove: string[] = [];
  const r2PathsToRemove: string[] = [];
  for (const r of olderRows) {
    const p = r.apk_path;
    if (typeof p !== 'string' || p.length === 0 || p === row.apk_path) {
      continue;
    }
    if (r.backend === 'r2') {
      r2PathsToRemove.push(p);
    } else {
      supabasePathsToRemove.push(p);
    }
  }

  if (supabasePathsToRemove.length > 0) {
    const { error: rmErr } = await supabase.storage
      .from(BUCKET_NAME)
      .remove(supabasePathsToRemove);
    if (rmErr) {
      console.error('app-releases retention storage remove error:', rmErr.message);
    }
  }

  if (r2PathsToRemove.length > 0) {
    if (!r2) {
      console.error('app-releases retention R2 not configured; skipping R2 deletes');
    } else {
      for (const key of r2PathsToRemove) {
        try {
          await r2Delete(r2, key);
        } catch (err) {
          console.error(
            'app-releases retention R2 delete error:',
            err instanceof Error ? err.message : 'unknown',
          );
        }
      }
    }
  }

  const olderIds = olderRows.map((r) => r.id);
  const { error: archErr } = await supabase
    .from('app_releases')
    .update({ status: 'archived', apk_path: null })
    .in('id', olderIds);
  if (archErr) {
    console.error('app-releases retention archive update error:', archErr.message);
    return 0;
  }
  return olderIds.length;
}

export async function handleAppReleases(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'method not allowed' }, 405);
  }

  const clHeader = Number(req.headers.get('content-length') ?? '0');
  if (clHeader > MAX_BODY_BYTES) {
    return json({ error: 'payload too large' }, 413);
  }

  let rawBody: string;
  try {
    rawBody = await req.text();
  } catch {
    return json({ error: 'invalid' }, 400);
  }
  if (new TextEncoder().encode(rawBody).length > MAX_BODY_BYTES) {
    return json({ error: 'payload too large' }, 413);
  }

  let body: Record<string, unknown>;
  try {
    const parsed = JSON.parse(rawBody);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      return json({ error: 'invalid' }, 400);
    }
    body = parsed as Record<string, unknown>;
  } catch {
    return json({ error: 'invalid' }, 400);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    console.error('app-releases: missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
    return json({ error: 'server error' }, 500);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const r2 = readR2Config();

  const action = body.action;

  // Public check: no x-app-session required so logged-out devices and mandatory updates work.
  if (action === 'latest') {
    const validated = validateLatestInput(body);
    if (!validated.ok) {
      return json({ error: 'invalid', errors: validated.errors }, 400);
    }
    const { abi, current_code, current_version } = validated.value;
    const session = await verifySession(req);
    const callerCabang = session ? normalizeCabang(session.cabang) : null;

    const { data: rows, error: qErr } = await supabase
      .from('app_releases')
      .select('id, version_name, version_code, size_bytes, sha256, changelog, mandatory, min_supported_version, apk_path, target_cabang, backend')
      .eq('app', APP_ID)
      .eq('abi', abi)
      .eq('status', 'published')
      .order('version_code', { ascending: false })
      .limit(20);

    if (qErr) {
      console.error('app-releases latest query error:', qErr.message);
      return json({ error: 'server error' }, 500);
    }
    const row = pickRelease(rows ?? [], callerCabang);
    if (!row) {
      return json({ update: false }, 200);
    }

    const decision = decideUpdate({
      currentCode: current_code,
      currentVersion: current_version,
      release: {
        version_code: Number(row.version_code),
        mandatory: Boolean(row.mandatory),
        min_supported_version: row.min_supported_version ?? null,
      },
    });

    if (!decision.update) {
      return json({ update: false }, 200);
    }
    if (typeof row.apk_path !== 'string' || row.apk_path.length === 0) {
      console.error('app-releases latest missing apk_path for published row:', row.id);
      return json({ error: 'server error' }, 500);
    }

    let downloadUrl: string;
    if (row.backend === 'r2') {
      if (!r2) {
        console.error('app-releases latest R2 not configured');
        return json({ error: 'server error' }, 500);
      }
      try {
        downloadUrl = await presignR2Url({
          method: 'GET',
          config: r2,
          key: row.apk_path,
          expiresSeconds: SIGNED_DOWNLOAD_TTL_SECONDS,
        });
      } catch (err) {
        console.error(
          'app-releases presignR2Url download error:',
          err instanceof Error ? err.message : 'unknown',
        );
        return json({ error: 'server error' }, 500);
      }
    } else {
      const { data: signedData, error: signErr } = await supabase.storage
        .from(BUCKET_NAME)
        .createSignedUrl(row.apk_path, SIGNED_DOWNLOAD_TTL_SECONDS);

      if (signErr || !signedData?.signedUrl) {
        console.error('app-releases createSignedUrl error:', signErr?.message ?? 'missing signedUrl');
        return json({ error: 'server error' }, 500);
      }
      downloadUrl = signedData.signedUrl;
    }

    return json(
      {
        update: true,
        mandatory: decision.mandatory,
        release: {
          id: row.id,
          version_name: row.version_name,
          version_code: Number(row.version_code),
          size_bytes: Number(row.size_bytes),
          sha256: row.sha256,
          changelog: row.changelog ?? '',
        },
        download_url: downloadUrl,
      },
      200,
    );
  }

  // All admin actions require valid session AND explicit publisher allowlist membership.
  const session = await verifySession(req);
  if (!session) {
    return json({ error: 'unauthorized' }, 401);
  }

  const allowedPublishers = parsePublisherUids(Deno.env.get('RELEASE_PUBLISHER_UIDS'));
  if (!allowedPublishers.has(session.uid)) {
    return json({ error: 'forbidden' }, 403);
  }

  if (action === 'list') {
    const { data: rows, error } = await supabase
      .from('app_releases')
      .select(ADMIN_SELECT_COLUMNS)
      .eq('app', APP_ID)
      .order('created_at', { ascending: false })
      .order('version_code', { ascending: false });

    if (error) {
      console.error('app-releases list error:', error.message);
      return json({ error: 'server error' }, 500);
    }
    return json({ releases: rows ?? [] }, 200);
  }

  if (action === 'create_upload') {
    const validated = validateCreate(body);
    if (!validated.ok) {
      return json({ error: 'invalid', errors: validated.errors }, 400);
    }
    const v = validated.value;

    const { data: maxRow, error: maxErr } = await supabase
      .from('app_releases')
      .select('version_code')
      .eq('app', APP_ID)
      .eq('abi', v.abi)
      .order('version_code', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (maxErr) {
      console.error('app-releases create_upload max check error:', maxErr.message);
      return json({ error: 'server error' }, 500);
    }
    if (maxRow && v.version_code <= Number(maxRow.version_code)) {
      return json(
        { error: 'version_code_must_increase', max_version_code: Number(maxRow.version_code) },
        409,
      );
    }

    if (!r2) {
      console.error('app-releases R2 not configured');
      return json({ error: 'server error' }, 500);
    }

    const apkPath = objectPath(v.abi, v.version_code);
    const { data: inserted, error: insErr } = await supabase
      .from('app_releases')
      .insert({
        app: APP_ID,
        abi: v.abi,
        version_code: v.version_code,
        base_version_code: v.base_version_code,
        version_name: v.version_name,
        apk_path: apkPath,
        sha256: v.sha256,
        size_bytes: v.size_bytes,
        changelog: v.changelog,
        mandatory: v.mandatory,
        min_supported_version: v.min_supported_version,
        target_cabang: v.target_cabang,
        backend: 'r2',
        status: 'draft',
        created_by: session.uid,
      })
      .select('id')
      .single();

    if (insErr) {
      if (insErr.code === '23505') {
        return json({ error: 'duplicate' }, 409);
      }
      console.error('app-releases create_upload insert error:', insErr.message);
      return json({ error: 'server error' }, 500);
    }

    let signedUrl: string;
    try {
      signedUrl = await presignR2Url({
        method: 'PUT',
        config: r2,
        key: apkPath,
        expiresSeconds: SIGNED_UPLOAD_TTL_SECONDS,
      });
    } catch (err) {
      console.error(
        'app-releases presignR2Url upload error:',
        err instanceof Error ? err.message : 'unknown',
      );
      await supabase.from('app_releases').delete().eq('id', inserted.id).eq('status', 'draft');
      return json({ error: 'server error' }, 500);
    }

    return json(
      {
        id: inserted.id,
        upload: {
          path: apkPath,
          token: '',
          signedUrl,
        },
      },
      201,
    );
  }

  if (action === 'publish') {
    const id = typeof body.id === 'string' ? body.id.trim() : '';
    if (!UUID_REGEX.test(id)) {
      return json({ error: 'invalid', errors: { id: 'must be a valid UUID' } }, 400);
    }

    const { data: row, error: fetchErr } = await supabase
      .from('app_releases')
      .select('*')
      .eq('id', id)
      .maybeSingle();

    if (fetchErr) {
      console.error('app-releases publish fetch error:', fetchErr.message);
      return json({ error: 'server error' }, 500);
    }
    if (!row) {
      return json({ error: 'not_found' }, 404);
    }
    if (row.status !== 'draft') {
      return json({ error: 'not_draft' }, 409);
    }
    if (typeof row.apk_path !== 'string' || row.apk_path.length === 0) {
      return json({ error: 'upload_missing' }, 422);
    }

    let bytes: Uint8Array;
    if (row.backend === 'r2') {
      if (!r2) {
        console.error('app-releases publish R2 not configured');
        return json({ error: 'server error' }, 500);
      }
      try {
        const fetched = await r2GetBytes(r2, row.apk_path);
        if (!fetched) {
          return json({ error: 'upload_missing' }, 422);
        }
        bytes = fetched;
      } catch (err) {
        console.error(
          'app-releases publish R2 download error:',
          err instanceof Error ? err.message : 'unknown',
        );
        return json({ error: 'server error' }, 500);
      }
    } else {
      const { data: blob, error: dlErr } = await supabase.storage
        .from(BUCKET_NAME)
        .download(row.apk_path);

      if (dlErr || !blob) {
        console.error('app-releases publish download error:', dlErr?.message ?? 'empty blob');
        return json({ error: 'upload_missing' }, 422);
      }

      bytes = new Uint8Array(await blob.arrayBuffer());
    }

    const actualSha = await computeSha256Hex(bytes);
    if (bytes.byteLength !== Number(row.size_bytes) || actualSha !== row.sha256) {
      return json({ error: 'hash_mismatch' }, 422);
    }

    const publishedAt = new Date().toISOString();
    const { data: updated, error: updErr } = await supabase
      .from('app_releases')
      .update({ status: 'published', published_at: publishedAt })
      .eq('id', id)
      .eq('status', 'draft')
      .select(ADMIN_SELECT_COLUMNS)
      .maybeSingle();

    if (updErr) {
      console.error('app-releases publish update error:', updErr.message);
      return json({ error: 'server error' }, 500);
    }
    if (!updated) {
      return json({ error: 'not_draft' }, 409);
    }

    const archivedCount =
      updated.target_cabang == null
        ? await runRetention(
            supabase,
            {
              id,
              abi: row.abi,
              version_code: Number(row.version_code),
              apk_path: row.apk_path,
            },
            r2,
          )
        : 0;

    return json({ release: updated, archived_count: archivedCount }, 200);
  }

  if (action === 'rollback') {
    const id = typeof body.id === 'string' ? body.id.trim() : '';
    if (!UUID_REGEX.test(id)) {
      return json({ error: 'invalid', errors: { id: 'must be a valid UUID' } }, 400);
    }

    const { data: row, error: fetchErr } = await supabase
      .from('app_releases')
      .select('id, status')
      .eq('id', id)
      .maybeSingle();

    if (fetchErr) {
      console.error('app-releases rollback fetch error:', fetchErr.message);
      return json({ error: 'server error' }, 500);
    }
    if (!row) {
      return json({ error: 'not_found' }, 404);
    }
    if (row.status !== 'published') {
      return json({ error: 'not_published' }, 409);
    }

    const { data: updated, error: updErr } = await supabase
      .from('app_releases')
      .update({ status: 'rolled_back' })
      .eq('id', id)
      .eq('status', 'published')
      .select(ADMIN_SELECT_COLUMNS)
      .maybeSingle();

    if (updErr) {
      console.error('app-releases rollback update error:', updErr.message);
      return json({ error: 'server error' }, 500);
    }
    if (!updated) {
      return json({ error: 'not_published' }, 409);
    }
    return json({ release: updated }, 200);
  }

  if (action === 'set_targets') {
    const id = typeof body.id === 'string' ? body.id.trim() : '';
    if (!UUID_REGEX.test(id)) {
      return json({ error: 'invalid', errors: { id: 'must be a valid UUID' } }, 400);
    }
    const targetResult = validateTargetCabang(body.target_cabang);
    if (!targetResult.ok) {
      return json({ error: 'invalid', errors: targetResult.errors }, 400);
    }

    const { data: row, error: fetchErr } = await supabase
      .from('app_releases')
      .select('id, abi, version_code, apk_path, status')
      .eq('id', id)
      .maybeSingle();

    if (fetchErr) {
      console.error('app-releases set_targets fetch error:', fetchErr.message);
      return json({ error: 'server error' }, 500);
    }
    if (!row) {
      return json({ error: 'not_found' }, 404);
    }
    if (row.status !== 'draft' && row.status !== 'published') {
      return json({ error: 'not_editable' }, 409);
    }

    const { data: updated, error: updErr } = await supabase
      .from('app_releases')
      .update({ target_cabang: targetResult.value })
      .eq('id', id)
      .in('status', ['draft', 'published'])
      .select(ADMIN_SELECT_COLUMNS)
      .maybeSingle();

    if (updErr) {
      console.error('app-releases set_targets update error:', updErr.message);
      return json({ error: 'server error' }, 500);
    }
    if (!updated) {
      return json({ error: 'not_editable' }, 409);
    }

    const archivedCount =
      updated.status === 'published' && targetResult.value === null
        ? await runRetention(
            supabase,
            {
              id,
              abi: row.abi,
              version_code: Number(row.version_code),
              apk_path: row.apk_path,
            },
            r2,
          )
        : 0;

    return json({ release: updated, archived_count: archivedCount }, 200);
  }

  if (action === 'delete_draft') {
    const id = typeof body.id === 'string' ? body.id.trim() : '';
    if (!UUID_REGEX.test(id)) {
      return json({ error: 'invalid', errors: { id: 'must be a valid UUID' } }, 400);
    }

    const { data: row, error: fetchErr } = await supabase
      .from('app_releases')
      .select('id, status, apk_path, backend')
      .eq('id', id)
      .maybeSingle();

    if (fetchErr) {
      console.error('app-releases delete_draft fetch error:', fetchErr.message);
      return json({ error: 'server error' }, 500);
    }
    if (!row) {
      return json({ error: 'not_found' }, 404);
    }
    if (row.status !== 'draft') {
      return json({ error: 'not_draft' }, 409);
    }

    if (typeof row.apk_path === 'string' && row.apk_path.length > 0) {
      if (row.backend === 'r2') {
        if (!r2) {
          console.error('app-releases delete_draft R2 not configured');
        } else {
          try {
            await r2Delete(r2, row.apk_path);
          } catch (err) {
            console.error(
              'app-releases delete_draft R2 delete warning:',
              err instanceof Error ? err.message : 'unknown',
            );
          }
        }
      } else {
        const { error: rmErr } = await supabase.storage
          .from(BUCKET_NAME)
          .remove([row.apk_path]);
        if (rmErr) {
          console.error('app-releases delete_draft storage remove warning:', rmErr.message);
        }
      }
    }

    const { error: delErr } = await supabase
      .from('app_releases')
      .delete()
      .eq('id', id)
      .eq('status', 'draft');

    if (delErr) {
      console.error('app-releases delete_draft delete error:', delErr.message);
      return json({ error: 'server error' }, 500);
    }
    return json({ deleted: true, id }, 200);
  }

  return json({ error: 'invalid action' }, 400);
}

if (import.meta.main && !Deno.env.get('DENO_TESTING')) {
  serve((req: Request) => handleAppReleases(req));
}
