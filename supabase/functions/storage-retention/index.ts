// Supabase Edge Function: storage-retention (SEC-RETENTION)
// Retention policy for bucket 'task-proofs'
// Rules:
//  (1) Duplicate orphan: proof_* unreferenced with identical-size referenced twin AND > 6 hours old
//  (2) Orphan grace: proof_* unreferenced without twin AND > 2 days old
//  (3) Aged task: proof_task_* > 7 days old (referenced or not)
//  (4) Aged fix: proof_fix_* > 30 days old

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

export const BUCKET_NAME = 'task-proofs';
export const SAFE_NAME_REGEX = /^proof_(task|fix)_[A-Za-z0-9_\-]+\.jpg$/;

export const MIN_DUPLICATE_HOURS = 5;
export const MIN_ORPHAN_DAYS = 2;
export const MIN_TASK_DAYS = 6;
export const MIN_FIX_DAYS = 29;

export const DEFAULT_DUPLICATE_HOURS = 6;
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

export function extractGroupPrefix(name: string): string | null {
  const match = name.match(/^(proof_[A-Za-z0-9_\-]+)_[0-9]+\.jpg$/);
  if (!match) {
    return null;
  }
  return match[1];
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
  duplicateCutoffHours?: number;
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
    if (body) {
      if (typeof body.dryRun === 'boolean') {
        dryRun = body.dryRun;
      } else if (typeof body.dry_run === 'boolean') {
        dryRun = body.dry_run;
      }
    }
  } catch {
    // Empty body is valid, default dryRun = false
  }

  const now = deps?.now ?? Date.now();
  const duplicateHours = deps?.duplicateCutoffHours ?? DEFAULT_DUPLICATE_HOURS;
  const orphanDays = deps?.orphanCutoffDays ?? DEFAULT_ORPHAN_DAYS;
  const taskDays = deps?.taskCutoffDays ?? DEFAULT_TASK_DAYS;
  const fixDays = deps?.fixCutoffDays ?? DEFAULT_FIX_DAYS;

  // Hard safety caps on cutoffs
  if (
    duplicateHours < MIN_DUPLICATE_HOURS ||
    orphanDays < MIN_ORPHAN_DAYS ||
    taskDays < MIN_TASK_DAYS ||
    fixDays < MIN_FIX_DAYS
  ) {
    return json(
      { error: 'Safety violation: cutoff duration below minimum allowed limit' },
      500,
    );
  }

  const cutoffDuplicate = now - duplicateHours * 3600 * 1000;
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
  const allObjects: Array<{
    name: string;
    created_at?: string;
    metadata?: { size?: number };
  }> = [];

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

    for (const item of data) {
      allObjects.push(item);
    }

    if (data.length < LIST_LIMIT) {
      hasMore = false;
    } else {
      offset += LIST_LIMIT;
    }
  }

  // Pass 1: Index referenced files by prefix and size for exact twin matching
  const referencedTwins = new Set<string>();
  for (const item of allObjects) {
    if (referencedSet.has(item.name)) {
      const prefix = extractGroupPrefix(item.name);
      const size = (item.metadata?.size as number) || 0;
      if (prefix && size > 0) {
        referencedTwins.add(`${prefix}:${size}`);
      }
    }
  }

  // Pass 2: Evaluate deletion rules
  const namesToDelete: string[] = [];
  let matchedDuplicateOrphan = 0;
  let matchedOrphan = 0;
  let matchedTask = 0;
  let matchedFix = 0;
  let bytesFreed = 0;

  for (const item of allObjects) {
    const name = item.name;
    if (!name || !SAFE_NAME_REGEX.test(name)) {
      continue;
    }

    const createdAt = item.created_at ? new Date(item.created_at).getTime() : NaN;
    if (isNaN(createdAt)) {
      continue;
    }

    const size = (item.metadata?.size as number) || 0;
    const isReferenced = referencedSet.has(name);

    if (name.startsWith('proof_task_')) {
      if (!tablesFailed && !isReferenced) {
        const prefix = extractGroupPrefix(name);
        const hasReferencedTwin = prefix && size > 0 && referencedTwins.has(`${prefix}:${size}`);

        if (hasReferencedTwin && createdAt < cutoffDuplicate) {
          // Rule (1): Duplicate orphan older than 6 hours with referenced same-size twin
          matchedDuplicateOrphan++;
          namesToDelete.push(name);
          bytesFreed += size;
        } else if (createdAt < cutoffOrphan) {
          // Rule (2): Orphan without twin older than 2 days
          matchedOrphan++;
          namesToDelete.push(name);
          bytesFreed += size;
        }
      } else {
        // Rule (3): Referenced (or table read failed) task proof older than 7 days
        if (createdAt < cutoffTask) {
          matchedTask++;
          namesToDelete.push(name);
          bytesFreed += size;
        }
      }
    } else if (name.startsWith('proof_fix_')) {
      if (!tablesFailed && !isReferenced) {
        const prefix = extractGroupPrefix(name);
        const hasReferencedTwin = prefix && size > 0 && referencedTwins.has(`${prefix}:${size}`);

        if (hasReferencedTwin && createdAt < cutoffDuplicate) {
          matchedDuplicateOrphan++;
          namesToDelete.push(name);
          bytesFreed += size;
        } else if (createdAt < cutoffOrphan) {
          matchedOrphan++;
          namesToDelete.push(name);
          bytesFreed += size;
        } else if (createdAt < cutoffFix) {
          matchedFix++;
          namesToDelete.push(name);
          bytesFreed += size;
        }
      } else {
        // Rule (4): Referenced fix proof older than 30 days
        if (createdAt < cutoffFix) {
          matchedFix++;
          namesToDelete.push(name);
          bytesFreed += size;
        }
      }
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
      scanned: allObjects.length,
      matchedDuplicateOrphan,
      matchedOrphan,
      matchedTask,
      matchedFix,
      totalMatched: namesToDelete.length,
      deleted: dryRun ? 0 : deleted,
      bytesFreed,
      errors: errors.slice(0, 5),
    },
    200,
  );
}

if (!Deno.env.get('DENO_TESTING')) {
  serve((req: Request) => handleStorageRetention(req));
}
