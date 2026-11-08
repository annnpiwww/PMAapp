Deno.env.set('DENO_TESTING', '1');

import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { handleStorageRetention, extractGroupPrefix } from './index.ts';

const TEST_SECRET = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const NOW = new Date('2026-11-08T12:00:00Z').getTime();
const HOUR_MS = 3600 * 1000;
const DAY_MS = 24 * HOUR_MS;

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

Deno.test('extractGroupPrefix: correctly extracts prefix before last millis timestamp', () => {
  assertEquals(
    extractGroupPrefix('proof_task_1793580811564_4957_12_1793625296859.jpg'),
    'proof_task_1793580811564_4957_12',
  );
  assertEquals(
    extractGroupPrefix('proof_fix_sample_1_1793000000.jpg'),
    'proof_fix_sample_1',
  );
  assertEquals(extractGroupPrefix('other.png'), null);
});

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

  const resDup = await handleStorageRetention(req, {
    cronSecret: TEST_SECRET,
    duplicateCutoffHours: 4, // min is 5
  });
  assertEquals(resDup.status, 500);

  const resOrphan = await handleStorageRetention(req, {
    cronSecret: TEST_SECRET,
    orphanCutoffDays: 1, // min is 2
  });
  assertEquals(resOrphan.status, 500);

  const resTask = await handleStorageRetention(req, {
    cronSecret: TEST_SECRET,
    taskCutoffDays: 5, // min is 6
  });
  assertEquals(resTask.status, 500);

  const resFix = await handleStorageRetention(req, {
    cronSecret: TEST_SECRET,
    fixCutoffDays: 28, // min is 29
  });
  assertEquals(resFix.status, 500);
});

// Spec requirement 4(a): orphan >6h with referenced same-size twin -> deleted
Deno.test('Requirement 4(a): orphan >6h with referenced same-size twin -> deleted', async () => {
  const files = [
    {
      name: 'proof_task_100_1_1793000001.jpg', // Referenced original
      created_at: new Date(NOW - 8 * HOUR_MS).toISOString(),
      metadata: { size: 500000 },
    },
    {
      name: 'proof_task_100_1_1793000002.jpg', // Duplicate orphan 8h old (>6h)
      created_at: new Date(NOW - 8 * HOUR_MS).toISOString(),
      metadata: { size: 500000 },
    },
  ];

  const referencedSet = new Set(['proof_task_100_1_1793000001.jpg']);
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
  assertEquals(data.matchedDuplicateOrphan, 1);
  assertEquals(data.matchedOrphan, 0);
  assertEquals(data.deleted, 1);
  assertEquals(data.bytesFreed, 500000);
  assertEquals(mock.removedBatches.flat(), ['proof_task_100_1_1793000002.jpg']);
});

// Spec requirement 4(b): young orphan without twin -> kept
Deno.test('Requirement 4(b): young orphan without twin -> kept', async () => {
  const files = [
    {
      name: 'proof_task_200_1_1793000001.jpg', // Orphan 18h old, NO referenced twin
      created_at: new Date(NOW - 18 * HOUR_MS).toISOString(),
      metadata: { size: 400000 },
    },
    {
      name: 'proof_task_200_2_1793000002.jpg', // Another orphan 4h old (<6h) with different index
      created_at: new Date(NOW - 4 * HOUR_MS).toISOString(),
      metadata: { size: 450000 },
    },
  ];

  // No file is referenced
  const referencedSet = new Set<string>();
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
  assertEquals(data.matchedDuplicateOrphan, 0);
  assertEquals(data.matchedOrphan, 0);
  assertEquals(data.deleted, 0);
  assertEquals(mock.removedBatches.length, 0); // Both kept
});

// Spec requirement 4(c): orphan >2d without twin -> deleted
Deno.test('Requirement 4(c): orphan >2d without twin -> deleted', async () => {
  const files = [
    {
      name: 'proof_task_300_1_1793000001.jpg', // Orphan 3 days old, no twin
      created_at: new Date(NOW - 3 * DAY_MS).toISOString(),
      metadata: { size: 600000 },
    },
  ];

  const referencedSet = new Set<string>();
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
  assertEquals(data.scanned, 1);
  assertEquals(data.matchedDuplicateOrphan, 0);
  assertEquals(data.matchedOrphan, 1);
  assertEquals(data.deleted, 1);
  assertEquals(data.bytesFreed, 600000);
  assertEquals(mock.removedBatches.flat(), ['proof_task_300_1_1793000001.jpg']);
});

// Spec requirement 4(d): referenced object never deleted regardless of age (under 7d)
Deno.test('Requirement 4(d): referenced object never deleted regardless of age (under 7d)', async () => {
  const files = [
    {
      name: 'proof_task_400_1_1793000001.jpg', // Referenced, 1 hour old
      created_at: new Date(NOW - 1 * HOUR_MS).toISOString(),
      metadata: { size: 300000 },
    },
    {
      name: 'proof_task_400_1_1793000002.jpg', // Duplicate orphan 8h old (>6h)
      created_at: new Date(NOW - 8 * HOUR_MS).toISOString(),
      metadata: { size: 300000 },
    },
    {
      name: 'proof_task_401_1_1793000001.jpg', // Referenced, 5 days old
      created_at: new Date(NOW - 5 * DAY_MS).toISOString(),
      metadata: { size: 700000 },
    },
  ];

  const referencedSet = new Set([
    'proof_task_400_1_1793000001.jpg',
    'proof_task_401_1_1793000001.jpg',
  ]);
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
  assertEquals(data.matchedDuplicateOrphan, 1);
  assertEquals(data.deleted, 1);
  // Only the orphan copy is deleted, referenced files are NEVER deleted
  assertEquals(mock.removedBatches.flat(), ['proof_task_400_1_1793000002.jpg']);
});

// Spec requirement 4(e): proof_task >7d / proof_fix >30d unchanged
Deno.test('Requirement 4(e): proof_task >7d and proof_fix >30d retention unchanged', async () => {
  const files = [
    {
      name: 'proof_task_old_1_1793000000.jpg', // 8 days old -> deleted
      created_at: new Date(NOW - 8 * DAY_MS).toISOString(),
      metadata: { size: 100000 },
    },
    {
      name: 'proof_task_recent_1_1793000000.jpg', // 6 days old, referenced -> kept
      created_at: new Date(NOW - 6 * DAY_MS).toISOString(),
      metadata: { size: 200000 },
    },
    {
      name: 'proof_fix_old_1_1793000000.jpg', // 31 days old -> deleted
      created_at: new Date(NOW - 31 * DAY_MS).toISOString(),
      metadata: { size: 300000 },
    },
    {
      name: 'proof_fix_recent_1_1793000000.jpg', // 26 days old, referenced -> kept
      created_at: new Date(NOW - 26 * DAY_MS).toISOString(),
      metadata: { size: 400000 },
    },
  ];

  const referencedSet = new Set([
    'proof_task_old_1_1793000000.jpg',
    'proof_task_recent_1_1793000000.jpg',
    'proof_fix_old_1_1793000000.jpg',
    'proof_fix_recent_1_1793000000.jpg',
  ]);
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
  assertEquals(data.scanned, 4);
  assertEquals(data.matchedTask, 1);
  assertEquals(data.matchedFix, 1);
  assertEquals(data.deleted, 2);
  assertEquals(data.bytesFreed, 400000);
  assertEquals(mock.removedBatches.flat(), [
    'proof_task_old_1_1793000000.jpg',
    'proof_fix_old_1_1793000000.jpg',
  ]);
});

Deno.test('Retention: dry_run body flag counts correctly and deletes nothing', async () => {
  const files = [
    {
      name: 'proof_task_500_1_1793000001.jpg',
      created_at: new Date(NOW - 8 * HOUR_MS).toISOString(),
      metadata: { size: 50000 },
    },
    {
      name: 'proof_task_500_1_1793000002.jpg',
      created_at: new Date(NOW - 8 * HOUR_MS).toISOString(),
      metadata: { size: 50000 },
    },
  ];

  const referencedSet = new Set(['proof_task_500_1_1793000001.jpg']);
  const mock = createMockStorage(files);

  // Using dry_run instead of dryRun
  const req = new Request('http://localhost', {
    method: 'POST',
    headers: { 'x-cron-secret': TEST_SECRET },
    body: JSON.stringify({ dry_run: true }),
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
  assertEquals(data.scanned, 2);
  assertEquals(data.matchedDuplicateOrphan, 1);
  assertEquals(data.deleted, 0);
  assertEquals(mock.removedBatches.length, 0); // Nothing removed
});

Deno.test('Retention: table-read failure skips orphan rules (fail-safe)', async () => {
  const files = [
    {
      name: 'proof_task_600_1_1793000002.jpg',
      created_at: new Date(NOW - 8 * HOUR_MS).toISOString(),
      metadata: { size: 50000 },
    },
    {
      name: 'proof_task_old_8d_1_1793000000.jpg',
      created_at: new Date(NOW - 8 * DAY_MS).toISOString(),
      metadata: { size: 4000 },
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
    tablesFailed: true,
  });

  assertEquals(res.status, 200);
  const data = await res.json();
  assertEquals(data.scanned, 2);
  assertEquals(data.matchedDuplicateOrphan, 0);
  assertEquals(data.matchedOrphan, 0);
  assertEquals(data.matchedTask, 1); // Only > 7 days deleted
  assertEquals(data.deleted, 1);
  assertEquals(mock.removedBatches.flat(), ['proof_task_old_8d_1_1793000000.jpg']);
});
