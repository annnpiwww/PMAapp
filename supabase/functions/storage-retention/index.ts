// Supabase Edge Function: storage-retention (SEC-RETENTION)
// Daily retention policy for bucket 'task-proofs'
// Rules:
//  (1) proof_task_* unreferenced in daily_tasks_* AND > 2 days old
//  (2) proof_task_* > 7 days old (referenced or not)
//  (3) proof_fix_* > 30 days old

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

export const BUCKET_NAME = 'task-proofs';
export const SAFE_NAME_REGEX = /^proof_(task|fix)_[A-Za-z0-9_\-]+\.jpg$/;

export const MIN_ORPHAN_DAYS = 2;
export const MIN_TASK_DAYS = 6;
export const MIN_FIX_DAYS = 29;

export const DEFAULT_ORPHAN_DAYS = 2;
export const DEFAULT_TASK_DAYS = 7;
export const DEFAULT_FIX_DAYS = 30;

export const BATCH_DELETE_SIZE = 100;
export const LIST_LIMIT = 1000;
export const TABLES = ['daily_tasks_manado', 'daily_tasks_bali', 'daily_tasks_ho'];

export function timingSafeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const aBuf = enc.encode(a);
  const bBuf = enc.encode(b);
  if (aBuf.byteLength !== bBuf.byteLength) {
    return false;
  }
  let c = 0;
  for (let i = 0; i < aBuf.byteLength; i++) {
    c |= aBuf[i] ^ bBuf[i];
  }
  return c === 0;
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
    },
  });
}

export async function fetchReferencedFileNames(
  supabaseUrl: string,
  serviceKey: string,
  fetchFn: typeof fetch = fetch,
): Promise<{ filenames: Set<string>; failed: boolean }> {
  const filenames = new Set<string>();

  for (const table of TABLES) {
    let offset = 0;
    const limit = 1000;
    let hasMore = true;

    while (hasMore) {
      const url = `${supabaseUrl}/rest/v1/${table}?select=foto_bukti&limit=${limit}&offset=${offset}`;
      try {
        const res = await fetchFn(url, {
          method: 'GET',
          headers: {
            apikey: serviceKey,
            Authorization: `Bearer ${serviceKey}`,
            'Content-Type': 'application/json',
          },
        });

        if (!res.ok) {
          console.error(`PostgREST error on table ${table}: HTTP ${res.status}`);
          return { filenames, failed: true };
        }

        const rows = await res.json();
        if (!Array.isArray(rows) || rows.length === 0) {
          hasMore = false;
          break;
        }

        for (const row of rows) {
          if (!row || !row.foto_bukti) continue;
          const photos = Array.isArray(row.foto_bukti)
            ? row.foto_bukti
            : typeof row.foto_bukti === 'string'
            ? [row.foto_bukti]
            : [];

          for (const item of photos) {
            if (typeof item === 'string' && item.trim().length > 0) {
              const cleanUrl = item.split('?')[0].split('#')[0];
              const segments = cleanUrl.split('/');
              const fname = segments[segments.length - 1];
              if (fname) {
                try {
                  filenames.add(decodeURIComponent(fname));
                } catch {
                  filenames.add(fname);
                }
              }
            }
          }
        }

        if (rows.length < limit) {
          hasMore = false;
        } else {
          offset += limit;
        }
      } catch (err) {
        console.error(`Exception fetching table ${table}:`, err);
        return { filenames, failed: true };
      }
    }
  }

  return { filenames, failed: false };
}

export interface StorageRetentionDeps {
  cronSecret?: string;
  supabaseUrl?: string;
  serviceRoleKey?: string;
  storageClient?: any;
  fetchImpl?: typeof fetch;
  now?: number;
  orphanCutoffDays?: number;
  taskCutoffDays?: number;
  fixCutoffDays?: number;
  referencedSet?: Set<string>;
  tablesFailed?: boolean;
}

export async function handleStorageRetention(
  req: Request,
  deps?: StorageRetentionDeps,
): Promise<Response> {
  if (req.method !== 'POST') {
    return json({ error: 'method not allowed' }, 405);
  }

  const expectedSecret = deps?.cronSecret ?? Deno.env.get('CRON_SECRET') ?? '';
  const incomingSecret = req.headers.get('x-cron-secret') ?? '';

  if (!expectedSecret || !incomingSecret || !timingSafeEqual(incomingSecret, expectedSecret)) {
    return json({ error: 'unauthorized' }, 401);
  }

  let dryRun = false;
  try {
    const body = await req.json();
    if (body && typeof body.dryRun === 'boolean') {
      dryRun = body.dryRun;
    }
  } catch {
    // Empty body is valid, default dryRun = false
  }

  const now = deps?.now ?? Date.now();
  const orphanDays = deps?.orphanCutoffDays ?? DEFAULT_ORPHAN_DAYS;
  const taskDays = deps?.taskCutoffDays ?? DEFAULT_TASK_DAYS;
  const fixDays = deps?.fixCutoffDays ?? DEFAULT_FIX_DAYS;

  // Hard safety caps on cutoffs
  if (orphanDays < MIN_ORPHAN_DAYS || taskDays < MIN_TASK_DAYS || fixDays < MIN_FIX_DAYS) {
    return json(
      { error: 'Safety violation: cutoff duration below minimum allowed limit' },
      500,
    );
  }

  const cutoffOrphan = now - orphanDays * 86400 * 1000;
  const cutoffTask = now - taskDays * 86400 * 1000;
  const cutoffFix = now - fixDays * 86400 * 1000;

  const supabaseUrl = deps?.supabaseUrl ?? Deno.env.get('SUPABASE_URL') ?? '';
  const serviceKey = deps?.serviceRoleKey ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  const fetchFn = deps?.fetchImpl ?? fetch;

  let storageClient = deps?.storageClient;
  if (!storageClient) {
    if (!supabaseUrl || !serviceKey) {
      return json({ error: 'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY' }, 500);
    }
    const supabase = createClient(supabaseUrl, serviceKey);
    storageClient = supabase.storage;
  }

  let referencedSet: Set<string>;
  let tablesFailed = false;

  if (deps?.referencedSet !== undefined) {
    referencedSet = deps.referencedSet;
    tablesFailed = deps.tablesFailed ?? false;
  } else {
    const refResult = await fetchReferencedFileNames(supabaseUrl, serviceKey, fetchFn);
    referencedSet = refResult.filenames;
    tablesFailed = refResult.failed;
  }

  let offset = 0;
  let hasMore = true;
  let scanned = 0;
  const namesToDelete: string[] = [];
  let matchedOrphan = 0;
  let matchedTask = 0;
  let matchedFix = 0;
  let bytesFreed = 0;

  while (hasMore) {
    const { data, error } = await storageClient
      .from(BUCKET_NAME)
      .list('', {
        limit: LIST_LIMIT,
        offset,
        sortBy: { column: 'created_at', order: 'asc' },
      });

    if (error) {
      return json({ error: `Storage list error: ${error.message}` }, 500);
    }

    if (!data || data.length === 0) {
      hasMore = false;
      break;
    }

    scanned += data.length;

    for (const item of data) {
      const name = item.name;
      if (!name || !SAFE_NAME_REGEX.test(name)) {
        continue;
      }

      const createdAt = item.created_at ? new Date(item.created_at).getTime() : NaN;
      if (isNaN(createdAt)) {
        continue;
      }

      const size = (item.metadata?.size as number) || 0;

      if (name.startsWith('proof_task_')) {
        if (!tablesFailed && !referencedSet.has(name)) {
          // Rule (1): Unreferenced orphan older than 2 days
          if (createdAt < cutoffOrphan) {
            matchedOrphan++;
            namesToDelete.push(name);
            bytesFreed += size;
          }
        } else {
          // Rule (2): Older than 7 days (referenced or table-read failed)
          if (createdAt < cutoffTask) {
            matchedTask++;
            namesToDelete.push(name);
            bytesFreed += size;
          }
        }
      } else if (name.startsWith('proof_fix_')) {
        // Rule (3): proof_fix_* older than 30 days
        if (createdAt < cutoffFix) {
          matchedFix++;
          namesToDelete.push(name);
          bytesFreed += size;
        }
      }
    }

    if (data.length < LIST_LIMIT) {
      hasMore = false;
    } else {
      offset += LIST_LIMIT;
    }
  }

  let deleted = 0;
  const errors: string[] = [];

  if (!dryRun && namesToDelete.length > 0) {
    for (let i = 0; i < namesToDelete.length; i += BATCH_DELETE_SIZE) {
      const batch = namesToDelete.slice(i, i + BATCH_DELETE_SIZE);
      const { error: removeErr } = await storageClient.from(BUCKET_NAME).remove(batch);
      if (removeErr) {
        if (errors.length < 5) {
          errors.push(`Remove batch failed at offset ${i}: ${removeErr.message}`);
        }
      } else {
        deleted += batch.length;
      }
    }
  }

  return json(
    {
      dryRun,
      scanned,
      matchedOrphan,
      matchedTask,
      matchedFix,
      deleted,
      bytesFreed,
      errors: errors.slice(0, 5),
    },
    200,
  );
}

if (!Deno.env.get('DENO_TESTING')) {
  serve((req: Request) => handleStorageRetention(req));
}
