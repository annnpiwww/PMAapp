import test from 'node:test';
import assert from 'node:assert';
import {
  nowParts,
  validate,
  login,
  sendReport,
  shareReport,
  saveSession,
  loadSession,
  clearSession,
  SESSION_KEY,
  loginSpv,
  listAccounts,
  createAccount,
  resetPassword,
  setAktif,
  fetchPosList,
  usernamePreview,
  generatePassword,
  saveSpvSession,
  loadSpvSession,
  clearSpvSession,
  SPV_SESSION_KEY,
  listMyReports,
  statusInfo,
  riwayatMeta,
} from '../../web/lapor/lapor-core.js';

test('nowParts in Asia/Makassar for a fixed UTC instant', () => {
  // 2026-11-11 02:05:00 UTC -> 2026-11-11 10:05:00 in Asia/Makassar (UTC+8)
  const instant = new Date('2026-11-11T02:05:00Z');
  const result = nowParts(instant);
  assert.deepStrictEqual(result, {
    tanggal: '11-11-2026',
    waktu: '10.05',
  });

  // Cross midnight UTC instant test:
  // 2026-11-11 16:30:00 UTC -> 2026-11-12 00:30:00 in Asia/Makassar
  const midnightInstant = new Date('2026-11-11T16:30:00Z');
  const midnightResult = nowParts(midnightInstant);
  assert.deepStrictEqual(midnightResult, {
    tanggal: '12-11-2026',
    waktu: '00.30',
  });
});

test('validate cases (empty kendala, 301 chars, bad tanggal 31-02-2026, bad waktu 24.00, ok)', () => {
  // 1. Empty kendala
  const emptyKendala = validate({
    kendala: '',
    tanggal: '11-11-2026',
    waktu: '10.00',
  });
  assert.strictEqual(emptyKendala.ok, false);
  assert.strictEqual(emptyKendala.field, 'kendala');
  assert.strictEqual(emptyKendala.message, 'Isi kendala dulu.');

  // 2. 301 chars in kendala
  const longKendala = validate({
    kendala: 'a'.repeat(301),
    tanggal: '11-11-2026',
    waktu: '10.00',
  });
  assert.strictEqual(longKendala.ok, false);
  assert.strictEqual(longKendala.field, 'kendala');
  assert.strictEqual(longKendala.message, 'Kendala maksimal 300 karakter.');

  // 3. Bad tanggal 31-02-2026 (February does not have 31 days)
  const badTanggal = validate({
    kendala: 'Printer macet',
    tanggal: '31-02-2026',
    waktu: '10.00',
  });
  assert.strictEqual(badTanggal.ok, false);
  assert.strictEqual(badTanggal.field, 'tanggal');
  assert.strictEqual(badTanggal.message, 'Tanggal tidak valid.');

  // 4. Bad waktu 24.00 (hour must be 00-23)
  const badWaktu = validate({
    kendala: 'Printer macet',
    tanggal: '11-11-2026',
    waktu: '24.00',
  });
  assert.strictEqual(badWaktu.ok, false);
  assert.strictEqual(badWaktu.field, 'waktu');
  assert.strictEqual(badWaktu.message, 'Waktu tidak valid.');

  // 5. Valid (ok) form
  const okForm = validate({
    kendala: 'Barrier gate patah',
    tanggal: '11-11-2026',
    waktu: '10.00',
    penyebab: 'Ditabrak mobil',
    solusi_sementara: 'Buka manual',
    durasi_error: '30 menit',
    ada_foto: true,
  });
  assert.strictEqual(okForm.ok, true);
  assert.strictEqual(okForm.field, null);
  assert.strictEqual(okForm.message, '');
});

test('login rejects role technician', async () => {
  const mockFetchTech = async () => ({
    ok: true,
    status: 200,
    json: async () => ({
      token: 'mock-tech-token',
      user: {
        id: 'u-1',
        username: 'tech1',
        nama: 'Teknisi 1',
        role: 'technician',
      },
    }),
  });

  await assert.rejects(
    login('tech1', 'secret', mockFetchTech),
    (err) => err.message === 'Akun ini bukan akun admin lokasi.'
  );

  // Success case for admin_pos
  const mockFetchAdminPos = async () => ({
    ok: true,
    status: 200,
    json: async () => ({
      token: 'mock-admin-token',
      user: {
        id: 'u-2',
        username: 'lapor.pos1',
        nama: 'Admin Pos 1',
        role: 'admin_pos',
        pos_name: 'Pos Masuk 1',
      },
    }),
  });

  const loggedIn = await login('lapor.pos1', 'secret', mockFetchAdminPos);
  assert.strictEqual(loggedIn.token, 'mock-admin-token');
  assert.strictEqual(loggedIn.user.role, 'admin_pos');
});

test('sendReport maps 201/401/403/409/500/network', async () => {
  const form = {
    tanggal: '11-11-2026',
    waktu: '10.00',
    kendala: 'Kamera LPR mati',
    penyebab: 'Kabel LAN putus',
    solusi_sementara: 'Input manual plat',
    durasi_error: '1 jam',
    ada_foto: false,
  };

  // 201: Success
  const mock201 = async () => ({
    ok: true,
    status: 201,
    json: async () => ({ id: 'ticket-99', message: 'Laporan diterima' }),
  });
  const res201 = await sendReport('session-token', form, mock201);
  assert.deepStrictEqual(res201, { id: 'ticket-99', message: 'Laporan diterima' });

  // 401: Sesi habis
  const mock401 = async () => ({
    ok: false,
    status: 401,
    json: async () => ({ error: 'unauthorized' }),
  });
  await assert.rejects(
    sendReport('bad-token', form, mock401),
    (err) => err.message === 'Sesi habis, masuk lagi.'
  );

  // 403: Akun ini tidak boleh melapor
  const mock403 = async () => ({
    ok: false,
    status: 403,
    json: async () => ({ error: 'forbidden' }),
  });
  await assert.rejects(
    sendReport('session-token', form, mock403),
    (err) => err.message === 'Akun ini tidak boleh melapor.'
  );

  // 409: Duplicate
  const mock409 = async () => ({
    ok: false,
    status: 409,
    json: async () => ({ error: 'duplicate' }),
  });
  await assert.rejects(
    sendReport('session-token', form, mock409),
    (err) => err.message === 'Laporan yang sama sudah terkirim hari ini.'
  );

  // 500: Server bermasalah
  const mock500 = async () => ({
    ok: false,
    status: 500,
    json: async () => ({ error: 'internal server error' }),
  });
  await assert.rejects(
    sendReport('session-token', form, mock500),
    (err) => err.message === 'Server bermasalah, coba lagi.'
  );

  // Network failure
  const mockNetworkError = async () => {
    throw new Error('Failed to fetch');
  };
  await assert.rejects(
    sendReport('session-token', form, mockNetworkError),
    (err) => err.message === 'Gagal terkirim. Cek sinyal lalu coba lagi.'
  );
});

test('shareReport 3 branches + AbortError', async () => {
  const message = 'Selamat pagi, izin melaporkan kendala printer.';
  const mockFile = { name: 'foto.jpg', type: 'image/jpeg' };

  // Branch 1: Level 2 Web Share with file (photo)
  let sharedData1 = null;
  const navBranch1 = {
    canShare: (opts) => Boolean(opts?.files?.length),
    share: async (data) => {
      sharedData1 = data;
    },
  };
  const res1 = await shareReport(message, mockFile, navBranch1);
  assert.strictEqual(res1, 'shared');
  assert.deepStrictEqual(sharedData1, { text: message, files: [mockFile] });

  // Branch 1b: Level 2 Web Share with video file (file-type agnostic)
  const mockVideoFile = { name: 'kerusakan.mp4', type: 'video/mp4' };
  let sharedDataVideo = null;
  const navBranchVideo = {
    canShare: (opts) => Boolean(opts?.files?.length),
    share: async (data) => {
      sharedDataVideo = data;
    },
  };
  const resVideo = await shareReport(message, mockVideoFile, navBranchVideo);
  assert.strictEqual(resVideo, 'shared');
  assert.deepStrictEqual(sharedDataVideo, { text: message, files: [mockVideoFile] });

  // Branch 2: Text-only share (no file or canShare returns false)
  let sharedData2 = null;
  const navBranch2 = {
    canShare: () => false,
    share: async (data) => {
      sharedData2 = data;
    },
  };
  const res2 = await shareReport(message, mockFile, navBranch2);
  assert.strictEqual(res2, 'shared');
  assert.deepStrictEqual(sharedData2, { text: message });

  // AbortError: User cancels the native share sheet
  const navAbort = {
    share: async () => {
      const err = new Error('Share canceled');
      err.name = 'AbortError';
      throw err;
    },
  };
  const resAbort = await shareReport(message, null, navAbort);
  assert.strictEqual(resAbort, 'cancelled');

  // Branch 3: Fallback (no share API available) -> clipboard + telegram deep link
  let clipboardCopied = '';
  let assignedLocation = '';
  const navFallback = {
    clipboard: {
      writeText: async (text) => {
        clipboardCopied = text;
      },
    },
  };
  const locationAssign = (url) => {
    assignedLocation = url;
  };

  const res3 = await shareReport(message, null, navFallback, locationAssign);
  assert.strictEqual(res3, 'copied');
  assert.strictEqual(clipboardCopied, message);
  assert.strictEqual(
    assignedLocation,
    'tg://msg?text=' + encodeURIComponent(message)
  );
});

test('session expiry drop', () => {
  const storageMap = new Map();
  const mockStorage = {
    getItem: (key) => (storageMap.has(key) ? storageMap.get(key) : null),
    setItem: (key, val) => storageMap.set(key, String(val)),
    removeItem: (key) => storageMap.delete(key),
  };

  // Case 1: Expired session must be dropped
  const expiredSession = {
    token: 'expired-token',
    user: { role: 'admin_pos' },
    expiresAt: Date.now() - 5000, // 5 seconds ago
  };
  saveSession(expiredSession, mockStorage);
  assert.ok(mockStorage.getItem(SESSION_KEY) !== null);

  const loadedExpired = loadSession(mockStorage);
  assert.strictEqual(loadedExpired, null);
  // Must be dropped from storage
  assert.strictEqual(mockStorage.getItem(SESSION_KEY), null);

  // Case 2: Valid non-expired session
  const validSession = {
    token: 'valid-token',
    user: { role: 'admin_pos', pos_name: 'Pos Keluar' },
    expiresAt: Date.now() + 100_000,
  };
  saveSession(validSession, mockStorage);
  const loadedValid = loadSession(mockStorage);
  assert.ok(loadedValid !== null);
  assert.strictEqual(loadedValid.token, 'valid-token');
  assert.strictEqual(loadedValid.user.pos_name, 'Pos Keluar');

  // Case 3: Clear session
  clearSession(mockStorage);
  assert.strictEqual(loadSession(mockStorage), null);
  assert.strictEqual(mockStorage.getItem(SESSION_KEY), null);
});

// ---------------------------------------------------------------------------
// Kelola Akun Tests (SPV Management)
// ---------------------------------------------------------------------------

test('loginSpv rejects non-spv and accepts spv', async () => {
  const mockFetchTech = async () => ({
    ok: true,
    status: 200,
    json: async () => ({
      token: 'tok-tech',
      user: { role: 'technician', nama: 'Teknisi' },
    }),
  });

  await assert.rejects(
    loginSpv('tech', 'pass', mockFetchTech),
    (err) => err.message === 'Akun ini bukan akun SPV.'
  );

  const mockFetchSpv = async () => ({
    ok: true,
    status: 200,
    json: async () => ({
      token: 'tok-spv',
      user: { role: 'spv', nama: 'Pak SPV' },
    }),
  });

  const res = await loginSpv('spv1', 'pass', mockFetchSpv);
  assert.strictEqual(res.token, 'tok-spv');
  assert.strictEqual(res.user.role, 'spv');
});

test('listAccounts returns accounts list and handles 401/403', async () => {
  const mockAccounts = [
    { id: '1', username: 'irma-mgnw', nama: 'Irma', pos_name: 'Mantos Barat', pos_kode: 'mgnw', aktif: true },
  ];
  const mockFetch = async () => ({
    ok: true,
    status: 200,
    json: async () => ({ accounts: mockAccounts }),
  });

  const list = await listAccounts('token-spv', mockFetch);
  assert.deepStrictEqual(list, mockAccounts);

  const mock403 = async () => ({
    ok: false,
    status: 403,
    json: async () => ({ error: 'forbidden' }),
  });
  await assert.rejects(
    listAccounts('token-bad', mock403),
    (err) => err.message === 'Hanya SPV yang boleh mengakses.'
  );
});

test('createAccount creates account and handles 409 duplicate', async () => {
  const mockFetch = async () => ({
    ok: true,
    status: 201,
    json: async () => ({ id: 'new-id', username: 'irma-mgnw' }),
  });

  const res = await createAccount(
    'tok',
    { nama: 'Irma', pos_name: 'Mantos Barat', pos_kode: 'mgnw', password: 'password123' },
    mockFetch
  );
  assert.deepStrictEqual(res, { id: 'new-id', username: 'irma-mgnw' });

  const mock409 = async () => ({
    ok: false,
    status: 409,
    json: async () => ({ error: 'duplicate' }),
  });
  await assert.rejects(
    createAccount(
      'tok',
      { nama: 'Irma', pos_name: 'Mantos Barat', pos_kode: 'mgnw', password: 'password123' },
      mock409
    ),
    (err) => err.message === 'Username sudah digunakan.'
  );
});

test('resetPassword and setAktif handle success and 404', async () => {
  const mockFetchOk = async () => ({
    ok: true,
    status: 200,
    json: async () => ({ ok: true }),
  });

  const resReset = await resetPassword('tok', 'user-1', 'newpass123', mockFetchOk);
  assert.deepStrictEqual(resReset, { ok: true });

  const resAktif = await setAktif('tok', 'user-1', false, mockFetchOk);
  assert.deepStrictEqual(resAktif, { ok: true });

  const mock404 = async () => ({
    ok: false,
    status: 404,
    json: async () => ({ error: 'not found' }),
  });
  await assert.rejects(
    resetPassword('tok', 'unknown-id', 'newpass123', mock404),
    (err) => err.message === 'Akun tidak ditemukan.'
  );
  await assert.rejects(
    setAktif('tok', 'unknown-id', true, mock404),
    (err) => err.message === 'Akun tidak ditemukan.'
  );
});

test('fetchPosList queries locations correctly', async () => {
  const mockPos = [
    { pos_id: 'm1', pos_name: 'Pos Masuk 1', location_tag: 'M1' },
    { pos_id: 'k1', pos_name: 'Pos Keluar 1', location_tag: 'K1' },
  ];
  const mockFetch = async () => ({
    ok: true,
    status: 200,
    json: async () => ({ locations: mockPos }),
  });

  const list = await fetchPosList('tok', mockFetch);
  assert.deepStrictEqual(list, mockPos);
});

test('usernamePreview matches slug rule', () => {
  assert.strictEqual(usernamePreview('Irma', 'mgnw'), 'irma-mgnw');
  assert.strictEqual(usernamePreview('Irma Sari', 'mgnw'), 'irmasari-mgnw');
  assert.strictEqual(usernamePreview('Pos 01 & Admin!', 'pos01'), 'pos01admin-pos01');
  assert.strictEqual(usernamePreview('A very long name exceeding twenty characters', 'abc'), 'averylongnameexceedi-abc');
});

test('generatePassword returns 10 chars with no look-alikes (0, O, 1, l, I)', () => {
  const forbidden = /[0O1lI]/;
  for (let i = 0; i < 50; i++) {
    const pw = generatePassword();
    assert.strictEqual(pw.length, 10);
    assert.strictEqual(forbidden.test(pw), false, `Password ${pw} contains look-alike characters`);
  }

  // Deterministic RNG test
  const deterministicPw = generatePassword(() => 0);
  assert.strictEqual(deterministicPw, '2222222222');
});

test('saveSpvSession / loadSpvSession / clearSpvSession handles expiry', () => {
  const map = new Map();
  const mockStorage = {
    getItem: (k) => (map.has(k) ? map.get(k) : null),
    setItem: (k, v) => map.set(k, String(v)),
    removeItem: (k) => map.delete(k),
  };

  const expiredSession = {
    token: 'tok-spv-exp',
    user: { role: 'spv' },
    expiresAt: Date.now() - 1000,
  };
  saveSpvSession(expiredSession, mockStorage);
  assert.strictEqual(loadSpvSession(mockStorage), null);
  assert.strictEqual(mockStorage.getItem(SPV_SESSION_KEY), null);

  const activeSession = {
    token: 'tok-spv-ok',
    user: { role: 'spv', nama: 'SPV Aktif' },
    expiresAt: Date.now() + 50000,
  };
  saveSpvSession(activeSession, mockStorage);
  const loaded = loadSpvSession(mockStorage);
  assert.strictEqual(loaded.token, 'tok-spv-ok');
  assert.strictEqual(loaded.user.nama, 'SPV Aktif');

  clearSpvSession(mockStorage);
  assert.strictEqual(loadSpvSession(mockStorage), null);
});

test('statusInfo returns correct text and cssClass for all 3 status cases', () => {
  // Case 1: selesai
  const selesai = statusInfo({ status: 'selesai', teknisi: 'Farhan' });
  assert.deepStrictEqual(selesai, { text: 'Selesai oleh Farhan', cssClass: 'status-selesai' });
  assert.deepStrictEqual(statusInfo({ status: 'selesai', teknisi: null }), { text: 'Selesai', cssClass: 'status-selesai' });

  // Case 2: ditangani
  const ditangani = statusInfo({ status: 'ditangani', teknisi: 'Ryan Lumasuge' });
  assert.deepStrictEqual(ditangani, { text: 'Dikerjakan oleh Ryan Lumasuge', cssClass: 'status-ditangani' });

  // Case 3: default / menunggu
  const menunggu = statusInfo({ status: 'menunggu', teknisi: null });
  assert.deepStrictEqual(menunggu, { text: 'Menunggu Teknisi', cssClass: 'status-menunggu' });

  const unknown = statusInfo({});
  assert.deepStrictEqual(unknown, { text: 'Menunggu Teknisi', cssClass: 'status-menunggu' });
});

test('listMyReports handles 200 with sample data, 401 expiry, and other errors', async () => {
  // Mock 200 success
  const sampleReports = [
    {
      id: 'task_1',
      tanggal: '11-11-2026',
      kendala: 'Barrier gate macet',
      status: 'ditangani',
      teknisi: 'Ryan',
      waktu_lapor: '2026-11-11T14:00:00Z',
    },
    {
      id: 'task_2',
      tanggal: '11-11-2026',
      kendala: 'Karcis habis',
      status: 'menunggu',
      teknisi: null,
      waktu_lapor: '2026-11-11T13:00:00Z',
    },
  ];

  const mockFetchSuccess = async (url, options) => {
    assert.strictEqual(options.method, 'POST');
    assert.strictEqual(options.headers['x-app-session'], 'token-valid');
    const body = JSON.parse(options.body);
    assert.strictEqual(body.action, 'admin_list');
    return {
      ok: true,
      status: 200,
      json: async () => ({ reports: sampleReports }),
    };
  };

  const reports = await listMyReports('token-valid', mockFetchSuccess);
  assert.deepStrictEqual(reports, sampleReports);

  // Mock 401 error throws 'sesi habis'
  const mockFetch401 = async () => ({
    ok: false,
    status: 401,
    json: async () => ({ error: 'unauthorized' }),
  });

  await assert.rejects(
    async () => {
      await listMyReports('token-expired', mockFetch401);
    },
    {
      name: 'Error',
      message: 'sesi habis',
    }
  );

  // Mock 500 throws 'gagal memuat riwayat'
  const mockFetch500 = async () => ({
    ok: false,
    status: 500,
    json: async () => ({ error: 'server error' }),
  });

  await assert.rejects(
    async () => {
      await listMyReports('token-valid', mockFetch500);
    },
    {
      name: 'Error',
      message: 'gagal memuat riwayat',
    }
  );
});

test('riwayatMeta formats diambil and selesai correctly', () => {
  // Both diambil and selesai
  assert.strictEqual(
    riwayatMeta({ diambil: '10:05', selesai: '10:15' }),
    'Diambil 10:05 · Selesai 10:15'
  );
  // Claimed timestamp with date like '12 Nov 10:05'
  assert.strictEqual(
    riwayatMeta({ diambil: '12 Nov 10:05', selesai: '10:15' }),
    'Diambil 10:05 · Selesai 10:15'
  );
  // Only diambil
  assert.strictEqual(
    riwayatMeta({ diambil: '10:05', selesai: null }),
    'Diambil 10:05'
  );
  assert.strictEqual(
    riwayatMeta({ diambil: '12 Nov 10:05' }),
    'Diambil 10:05'
  );
  // Only selesai
  assert.strictEqual(
    riwayatMeta({ diambil: null, selesai: '10:15' }),
    'Selesai 10:15'
  );
  assert.strictEqual(
    riwayatMeta({ selesai: '10:15' }),
    'Selesai 10:15'
  );
  // Neither
  assert.strictEqual(riwayatMeta({}), '');
  assert.strictEqual(riwayatMeta(null), '');
  assert.strictEqual(riwayatMeta({ diambil: null, selesai: null }), '');
});
