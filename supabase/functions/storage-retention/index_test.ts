Deno.env.set('DENO_TESTING', '1');

import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { handleStorageRetention } from './index.ts';

const TEST_SECRET = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const NOW = new Date('2026-11-08T12:00:00Z').getTime();
const DAY_MS = 86400 * 1000;

function createMockStorage(initialObjects: Array<{
  name: string;
  created_at: string;
  metadata?: { size?: number };
}>) {
  const removedBatches: string[][] = [];
  return {
    removedBatches,
    storageClient: {
      from: (bucket: string) => ({
        list: async (_path: string, options: { limit: number; offset: number }) => {
          assertEquals(bucket, 'task-proofs');
          const slice = initialObjects.slice(options.offset, options.offset + options.limit);
          return { data: slice, error: null };
        },
        remove: async (paths: string[]) => {
          assertEquals(bucket, 'task-proofs');
          removedBatches.push([...paths]);
          return { data: paths.map((p) => ({ name: p })), error: null };
        },
      }),
    },
  };
}

Deno.test('Auth: 401 without secret or with wrong secret', async () => {
  const reqNoSecret = new Request('http://localhost', {
    method: 'POST',
    headers: {},
  });
  const res1 = await handleStorageRetention(reqNoSecret, { cronSecret: TEST_SECRET });
  assertEquals(res1.status, 401);

  const reqWrongSecret = new Request('http://localhost', {
    method: 'POST',
    headers: { 'x-cron-secret': 'wrong-secret' },
  });
  const res2 = await handleStorageRetention(reqWrongSecret, { cronSecret: TEST_SECRET });
  assertEquals(res2.status, 401);
});

Deno.test('Safety Cap: refuse if cutoff below minimum allowed', async () => {
  const req = new Request('http://localhost', {
    method: 'POST',
    headers: { 'x-cron-secret': TEST_SECRET },
  });

  const resOrphan = await handleStorageRetention(req, {
    cronSecret: TEST_SECRET,
    orphanCutoffDays: 1, // min is 2
    taskCutoffDays: 7,
    fixCutoffDays: 30,
  });
  assertEquals(resOrphan.status, 500);

  const resTask = await handleStorageRetention(req, {
    cronSecret: TEST_SECRET,
    orphanCutoffDays: 2,
    taskCutoffDays: 5, // min is 6
    fixCutoffDays: 30,
  });
  assertEquals(resTask.status, 500);

  const resFix = await handleStorageRetention(req, {
    cronSecret: TEST_SECRET,
    orphanCutoffDays: 2,
    taskCutoffDays: 7,
    fixCutoffDays: 28, // min is 29
  });
  assertEquals(resFix.status, 500);
});

Deno.test('Retention: 8-day-old proof_task deleted, 6-day-old kept', async () => {
  const files = [
    {
      name: 'proof_task_101_1_1793000000.jpg',
      created_at: new Date(NOW - 8 * DAY_MS).toISOString(),
      metadata: { size: 5000 },
    },
    {
      name: 'proof_task_102_1_1793000000.jpg',
      created_at: new Date(NOW - 6 * DAY_MS).toISOString(),
      metadata: { size: 3000 },
    },
  ];

  // Referenced so rule 1 does not delete the 6-day-old
  const referencedSet = new Set(['proof_task_101_1_1793000000.jpg', 'proof_task_102_1_1793000000.jpg']);
  const mock = createMockStorage(files);

  const req = new Request('http://localhost', {
    method: 'POST',
    headers: { 'x-cron-secret': TEST_SECRET },
    body: JSON.stringify({ dryRun: false }),
  });

  const res = await handleStorageRetention(req, {
    cronSecret: TEST_SECRET,
    now: NOW,
    storageClient: mock.storageClient,
    referencedSet,
  });

  assertEquals(res.status, 200);
  const data = await res.json();
  assertEquals(data.scanned, 2);
  assertEquals(data.matchedTask, 1);
  assertEquals(data.matchedOrphan, 0);
  assertEquals(data.deleted, 1);
  assertEquals(data.bytesFreed, 5000);
  assertEquals(mock.removedBatches.flat(), ['proof_task_101_1_1793000000.jpg']);
});

Deno.test('Retention: referenced 3-day-old kept and unreferenced 3-day-old deleted', async () => {
  const files = [
    {
      name: 'proof_task_ref_3d_1_1793000000.jpg',
      created_at: new Date(NOW - 3 * DAY_MS).toISOString(),
      metadata: { size: 1000 },
    },
    {
      name: 'proof_task_unref_3d_1_1793000000.jpg',
      created_at: new Date(NOW - 3 * DAY_MS).toISOString(),
      metadata: { size: 2000 },
    },
    {
      name: 'proof_task_unref_1d_1_1793000000.jpg',
      created_at: new Date(NOW - 1 * DAY_MS).toISOString(),
      metadata: { size: 1500 },
    },
  ];

  const referencedSet = new Set(['proof_task_ref_3d_1_1793000000.jpg']);
  const mock = createMockStorage(files);

  const req = new Request('http://localhost', {
    method: 'POST',
    headers: { 'x-cron-secret': TEST_SECRET },
    body: JSON.stringify({ dryRun: false }),
  });

  const res = await handleStorageRetention(req, {
    cronSecret: TEST_SECRET,
    now: NOW,
    storageClient: mock.storageClient,
    referencedSet,
  });

  assertEquals(res.status, 200);
  const data = await res.json();
  assertEquals(data.scanned, 3);
  assertEquals(data.matchedOrphan, 1); // unref 3-day-old deleted
  assertEquals(data.matchedTask, 0);
  assertEquals(data.deleted, 1);
  assertEquals(data.bytesFreed, 2000);
  assertEquals(mock.removedBatches.flat(), ['proof_task_unref_3d_1_1793000000.jpg']);
});

Deno.test('Retention: table-read failure skips rule 1 (fail-safe)', async () => {
  const files = [
    {
      name: 'proof_task_unref_3d_1_1793000000.jpg',
      created_at: new Date(NOW - 3 * DAY_MS).toISOString(),
      metadata: { size: 2000 },
    },
    {
      name: 'proof_task_old_8d_1_1793000000.jpg',
      created_at: new Date(NOW - 8 * DAY_MS).toISOString(),
      metadata: { size: 4000 },
    },
  ];

  // tablesFailed = true triggers skip of rule 1
  const mock = createMockStorage(files);

  const req = new Request('http://localhost', {
    method: 'POST',
    headers: { 'x-cron-secret': TEST_SECRET },
    body: JSON.stringify({ dryRun: false }),
  });

  const res = await handleStorageRetention(req, {
    cronSecret: TEST_SECRET,
    now: NOW,
    storageClient: mock.storageClient,
    referencedSet: new Set(),
    tablesFailed: true,
  });

  assertEquals(res.status, 200);
  const data = await res.json();
  assertEquals(data.scanned, 2);
  assertEquals(data.matchedOrphan, 0); // Skipped due to tablesFailed
  assertEquals(data.matchedTask, 1); // Only > 7 days deleted
  assertEquals(data.deleted, 1);
  assertEquals(data.bytesFreed, 4000);
  assertEquals(mock.removedBatches.flat(), ['proof_task_old_8d_1_1793000000.jpg']);
});

Deno.test('Retention: proof_fix 31-day-old deleted, 26-day-old kept', async () => {
  const files = [
    {
      name: 'proof_fix_old_1_1793000000.jpg',
      created_at: new Date(NOW - 31 * DAY_MS).toISOString(),
      metadata: { size: 7000 },
    },
    {
      name: 'proof_fix_recent_1_1793000000.jpg',
      created_at: new Date(NOW - 26 * DAY_MS).toISOString(),
      metadata: { size: 6000 },
    },
  ];

  const mock = createMockStorage(files);

  const req = new Request('http://localhost', {
    method: 'POST',
    headers: { 'x-cron-secret': TEST_SECRET },
    body: JSON.stringify({ dryRun: false }),
  });

  const res = await handleStorageRetention(req, {
    cronSecret: TEST_SECRET,
    now: NOW,
    storageClient: mock.storageClient,
    referencedSet: new Set(),
  });

  assertEquals(res.status, 200);
  const data = await res.json();
  assertEquals(data.scanned, 2);
  assertEquals(data.matchedFix, 1);
  assertEquals(data.deleted, 1);
  assertEquals(data.bytesFreed, 7000);
  assertEquals(mock.removedBatches.flat(), ['proof_fix_old_1_1793000000.jpg']);
});

Deno.test('Retention: foreign name "other.png" never deleted', async () => {
  const files = [
    {
      name: 'other.png',
      created_at: new Date(NOW - 100 * DAY_MS).toISOString(),
      metadata: { size: 99999 },
    },
    {
      name: 'proof_custom_101.jpg',
      created_at: new Date(NOW - 100 * DAY_MS).toISOString(),
      metadata: { size: 99999 },
    },
  ];

  const mock = createMockStorage(files);

  const req = new Request('http://localhost', {
    method: 'POST',
    headers: { 'x-cron-secret': TEST_SECRET },
    body: JSON.stringify({ dryRun: false }),
  });

  const res = await handleStorageRetention(req, {
    cronSecret: TEST_SECRET,
    now: NOW,
    storageClient: mock.storageClient,
    referencedSet: new Set(),
  });

  assertEquals(res.status, 200);
  const data = await res.json();
  assertEquals(data.scanned, 2);
  assertEquals(data.matchedOrphan, 0);
  assertEquals(data.matchedTask, 0);
  assertEquals(data.matchedFix, 0);
  assertEquals(data.deleted, 0);
  assertEquals(mock.removedBatches.length, 0);
});

Deno.test('Retention: dryRun counts correctly and deletes nothing', async () => {
  const files = [
    {
      name: 'proof_task_orphan_101_1_1793000000.jpg',
      created_at: new Date(NOW - 4 * DAY_MS).toISOString(),
      metadata: { size: 1000 },
    },
    {
      name: 'proof_task_old_102_1_1793000000.jpg',
      created_at: new Date(NOW - 10 * DAY_MS).toISOString(),
      metadata: { size: 2000 },
    },
    {
      name: 'proof_fix_old_103_1_1793000000.jpg',
      created_at: new Date(NOW - 35 * DAY_MS).toISOString(),
      metadata: { size: 3000 },
    },
  ];

  const referencedSet = new Set(['proof_task_old_102_1_1793000000.jpg']);
  const mock = createMockStorage(files);

  const req = new Request('http://localhost', {
    method: 'POST',
    headers: { 'x-cron-secret': TEST_SECRET },
    body: JSON.stringify({ dryRun: true }),
  });

  const res = await handleStorageRetention(req, {
    cronSecret: TEST_SECRET,
    now: NOW,
    storageClient: mock.storageClient,
    referencedSet,
  });

  assertEquals(res.status, 200);
  const data = await res.json();
  assertEquals(data.dryRun, true);
  assertEquals(data.scanned, 3);
  assertEquals(data.matchedOrphan, 1);
  assertEquals(data.matchedTask, 1);
  assertEquals(data.matchedFix, 1);
  assertEquals(data.deleted, 0);
  assertEquals(data.bytesFreed, 6000);
  assertEquals(mock.removedBatches.length, 0); // Nothing removed
});

Deno.test('Pagination: handles > 1000 objects in storage and batches deletes in 100', async () => {
  const count = 1050;
  const files: Array<{ name: string; created_at: string; metadata: { size: number } }> = [];

  for (let i = 0; i < count; i++) {
    files.push({
      name: `proof_task_batch_${i}_1_1793000000.jpg`,
      created_at: new Date(NOW - 10 * DAY_MS).toISOString(),
      metadata: { size: 100 },
    });
  }

  const mock = createMockStorage(files);

  const req = new Request('http://localhost', {
    method: 'POST',
    headers: { 'x-cron-secret': TEST_SECRET },
    body: JSON.stringify({ dryRun: false }),
  });

  const res = await handleStorageRetention(req, {
    cronSecret: TEST_SECRET,
    now: NOW,
    storageClient: mock.storageClient,
    referencedSet: new Set(),
  });

  assertEquals(res.status, 200);
  const data = await res.json();
  assertEquals(data.scanned, 1050);
  assertEquals(data.deleted, 1050);
  assertEquals(data.bytesFreed, 1050 * 100);

  // 1050 items deleted in batches of 100 = 10 batches of 100 + 1 batch of 50 = 11 batches
  assertEquals(mock.removedBatches.length, 11);
  assertEquals(mock.removedBatches[0].length, 100);
  assertEquals(mock.removedBatches[10].length, 50);
});
