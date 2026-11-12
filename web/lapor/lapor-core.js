// Pure logic for Lapor Error admin pos PWA
// Vanilla ES module, zero external dependencies, zero DOM access.
// Network and browser interfaces are injected to allow running under Node.js test runner.

import { SUPABASE_URL, SUPABASE_ANON_KEY } from './config.js';

export const SESSION_KEY = 'lapor_session_v1';
export const SPV_SESSION_KEY = 'lapor_spv_session_v1';
const DEFAULT_TTL_MS = 30 * 24 * 60 * 60 * 1000; // 30 days
const PASSWORD_CHARS = '23456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

/**
 * Returns formatted date and time parts in Asia/Makassar timezone.
 * @param {Date|number|string} [date=new Date()]
 * @returns {{ tanggal: string, waktu: string }}
 */
export function nowParts(date = new Date()) {
  const d = date instanceof Date ? date : new Date(date);
  const formatter = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Asia/Makassar',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
    hourCycle: 'h23',
  });
  const parts = formatter.formatToParts(d);
  const p = {};
  for (const part of parts) {
    p[part.type] = part.value;
  }
  return {
    tanggal: `${p.day}-${p.month}-${p.year}`,
    waktu: `${p.hour}.${p.minute}`,
  };
}

/**
 * Helper to validate calendar date components.
 */
function isValidDate(dd, mm, yyyy) {
  const day = Number(dd);
  const month = Number(mm);
  const year = Number(yyyy);
  if (!Number.isInteger(day) || !Number.isInteger(month) || !Number.isInteger(year)) {
    return false;
  }
  if (month < 1 || month > 12 || year < 1000 || year > 9999) {
    return false;
  }
  const d = new Date(Date.UTC(year, month - 1, day));
  return (
    d.getUTCFullYear() === year &&
    d.getUTCMonth() === month - 1 &&
    d.getUTCDate() === day
  );
}

/**
 * Validates the report form inputs.
 * @param {Record<string, unknown>} form
 * @returns {{ ok: boolean, field: string|null, message: string }}
 */
export function validate(form) {
  if (!form || typeof form !== 'object') {
    return { ok: false, field: null, message: 'Data formulir tidak valid.' };
  }

  const kendala = String(form.kendala ?? '').trim();
  if (!kendala) {
    return { ok: false, field: 'kendala', message: 'Isi kendala dulu.' };
  }
  if (kendala.length > 300) {
    return { ok: false, field: 'kendala', message: 'Kendala maksimal 300 karakter.' };
  }

  const textFields = ['penyebab', 'solusi_sementara', 'durasi_error'];
  for (const field of textFields) {
    const val = String(form[field] ?? '');
    if (val.length > 300) {
      const label =
        field === 'penyebab'
          ? 'Penyebab'
          : field === 'solusi_sementara'
          ? 'Solusi sementara'
          : 'Durasi error';
      return { ok: false, field, message: `${label} maksimal 300 karakter.` };
    }
  }

  const tanggal = String(form.tanggal ?? '').trim();
  if (!tanggal) {
    return { ok: false, field: 'tanggal', message: 'Isi tanggal dulu.' };
  }
  const dateMatch = tanggal.match(/^(\d{2})-(\d{2})-(\d{4})$/);
  if (!dateMatch) {
    return { ok: false, field: 'tanggal', message: 'Tanggal tidak valid.' };
  }
  const [, dd, mm, yyyy] = dateMatch;
  if (!isValidDate(dd, mm, yyyy)) {
    return { ok: false, field: 'tanggal', message: 'Tanggal tidak valid.' };
  }

  const waktu = String(form.waktu ?? '').trim();
  if (!waktu) {
    return { ok: false, field: 'waktu', message: 'Isi waktu dulu.' };
  }
  const timeMatch = waktu.match(/^(\d{2})\.(\d{2})$/);
  if (!timeMatch) {
    return { ok: false, field: 'waktu', message: 'Waktu tidak valid.' };
  }
  const h = Number(timeMatch[1]);
  const m = Number(timeMatch[2]);
  if (h < 0 || h > 23 || m < 0 || m > 59) {
    return { ok: false, field: 'waktu', message: 'Waktu tidak valid.' };
  }

  return { ok: true, field: null, message: '' };
}

/**
 * Authenticates user credentials against the auth-login Supabase Edge Function.
 * Rejects non-admin_pos accounts.
 * @param {string} identity
 * @param {string} password
 * @param {typeof fetch} [fetchImpl=fetch]
 * @param {object} [options={}]
 * @returns {Promise<{ token: string, user: object }>}
 */
export async function login(identity, password, fetchImpl = fetch, options = {}) {
  const url = `${options.supabaseUrl || SUPABASE_URL}/functions/v1/auth-login`;
  const anonKey = options.supabaseAnonKey || SUPABASE_ANON_KEY;

  let res;
  try {
    res = await fetchImpl(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: anonKey,
        Authorization: `Bearer ${anonKey}`,
      },
      body: JSON.stringify({
        identity: String(identity ?? '').trim(),
        password: String(password ?? ''),
      }),
    });
  } catch {
    throw new Error('Gagal terkirim. Cek sinyal lalu coba lagi.');
  }

  if (res.status === 401) {
    throw new Error('Username atau password salah.');
  }

  if (!res.ok) {
    throw new Error('Server bermasalah, coba lagi.');
  }

  let data;
  try {
    data = await res.json();
  } catch {
    throw new Error('Server bermasalah, coba lagi.');
  }

  if (!data || !data.token || !data.user) {
    throw new Error('Server bermasalah, coba lagi.');
  }

  if (data.user.role !== 'admin_pos') {
    throw new Error('Akun ini bukan akun admin lokasi.');
  }

  return {
    token: data.token,
    user: data.user,
  };
}

/**
 * Submits the report to the daily-tasks Supabase Edge Function (action: admin_report).
 * @param {string} token
 * @param {object} form
 * @param {typeof fetch} [fetchImpl=fetch]
 * @param {object} [options={}]
 * @returns {Promise<{ id: string, message: string }>}
 */
export async function sendReport(token, form, fetchImpl = fetch, options = {}) {
  const url = `${options.supabaseUrl || SUPABASE_URL}/functions/v1/daily-tasks`;
  const anonKey = options.supabaseAnonKey || SUPABASE_ANON_KEY;

  let res;
  try {
    res = await fetchImpl(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: anonKey,
        Authorization: `Bearer ${anonKey}`,
        'x-app-session': token,
      },
      body: JSON.stringify({
        action: 'admin_report',
        report: {
          tanggal: form.tanggal,
          waktu: form.waktu,
          kendala: form.kendala,
          penyebab: form.penyebab || '',
          solusi_sementara: form.solusi_sementara || '',
          durasi_error: form.durasi_error || '',
          ada_foto: Boolean(form.ada_foto),
        },
      }),
    });
  } catch {
    throw new Error('Gagal terkirim. Cek sinyal lalu coba lagi.');
  }

  if (res.status === 401) {
    throw new Error('Sesi habis, masuk lagi.');
  }
  if (res.status === 403) {
    throw new Error('Akun ini tidak boleh melapor.');
  }
  if (res.status === 409) {
    throw new Error('Laporan yang sama sudah terkirim hari ini.');
  }
  if (!res.ok) {
    throw new Error('Server bermasalah, coba lagi.');
  }

  let data;
  try {
    data = await res.json();
  } catch {
    throw new Error('Server bermasalah, coba lagi.');
  }

  return {
    id: data?.id,
    message: data?.message,
  };
}

/**
 * Shares the generated Telegram message and optional photo.
 * Falls back to clipboard copy + deep link opener.
 * @param {string} message
 * @param {File|Blob|null} [file=null]
 * @param {object} [nav]
 * @param {Function} [locationAssign]
 * @returns {Promise<'shared'|'copied'|'cancelled'>}
 */
export async function shareReport(message, file = null, nav = null, locationAssign = null) {
  const assignFn =
    typeof locationAssign === 'function'
      ? locationAssign
      : typeof nav?.locationAssign === 'function'
      ? nav.locationAssign.bind(nav)
      : (url) => {
          if (typeof location !== 'undefined' && location && typeof location.assign === 'function') {
            location.assign(url);
          }
        };

  // Branch 1: Web Share Level 2 with file
  if (file && typeof nav?.canShare === 'function' && nav.canShare({ files: [file] })) {
    try {
      await nav.share({ text: message, files: [file] });
      return 'shared';
    } catch (err) {
      if (err && err.name === 'AbortError') {
        return 'cancelled';
      }
      throw err;
    }
  }

  // Branch 2: Web Share text-only
  if (typeof nav?.share === 'function') {
    try {
      await nav.share({ text: message });
      return 'shared';
    } catch (err) {
      if (err && err.name === 'AbortError') {
        return 'cancelled';
      }
      throw err;
    }
  }

  // Branch 3: Fallback (no share API) -> copy to clipboard + deep link
  if (nav?.clipboard && typeof nav.clipboard.writeText === 'function') {
    await nav.clipboard.writeText(message);
  }

  const tgUrl = 'tg://msg?text=' + encodeURIComponent(message);
  assignFn(tgUrl);

  return 'copied';
}

/**
 * Persists session to the given storage.
 * @param {object} session
 * @param {Storage} storage
 */
export function saveSession(session, storage) {
  if (!session || !storage) return;
  const payload = {
    ...session,
    savedAt: session.savedAt || Date.now(),
    expiresAt: session.expiresAt || Date.now() + DEFAULT_TTL_MS,
  };
  storage.setItem(SESSION_KEY, JSON.stringify(payload));
}

/**
 * Loads session from storage, dropping expired sessions.
 * @param {Storage} storage
 * @returns {object|null}
 */
export function loadSession(storage) {
  if (!storage) return null;
  const raw = storage.getItem(SESSION_KEY);
  if (!raw) return null;
  try {
    const session = JSON.parse(raw);
    if (!session || typeof session !== 'object') {
      clearSession(storage);
      return null;
    }
    if (typeof session.expiresAt === 'number' && Date.now() > session.expiresAt) {
      clearSession(storage);
      return null;
    }
    return session;
  } catch {
    clearSession(storage);
    return null;
  }
}

/**
 * Clears session from storage.
 * @param {Storage} storage
 */
export function clearSession(storage) {
  if (!storage) return;
  storage.removeItem(SESSION_KEY);
}

// ---------------------------------------------------------------------------
// Kelola Akun (SPV Web Management)
// ---------------------------------------------------------------------------

/**
 * Authenticates SPV credentials against auth-login.
 * Rejects non-spv accounts.
 * @param {string} identity
 * @param {string} password
 * @param {typeof fetch} [fetchImpl=fetch]
 * @param {object} [options={}]
 * @returns {Promise<{ token: string, user: object }>}
 */
export async function loginSpv(identity, password, fetchImpl = fetch, options = {}) {
  const url = `${options.supabaseUrl || SUPABASE_URL}/functions/v1/auth-login`;
  const anonKey = options.supabaseAnonKey || SUPABASE_ANON_KEY;

  let res;
  try {
    res = await fetchImpl(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: anonKey,
        Authorization: `Bearer ${anonKey}`,
      },
      body: JSON.stringify({
        identity: String(identity ?? '').trim(),
        password: String(password ?? ''),
      }),
    });
  } catch {
    throw new Error('Gagal terkirim. Cek sinyal lalu coba lagi.');
  }

  if (res.status === 401) {
    throw new Error('Username atau password salah.');
  }

  if (!res.ok) {
    throw new Error('Server bermasalah, coba lagi.');
  }

  let data;
  try {
    data = await res.json();
  } catch {
    throw new Error('Server bermasalah, coba lagi.');
  }

  if (!data || !data.token || !data.user) {
    throw new Error('Server bermasalah, coba lagi.');
  }

  if (data.user.role !== 'spv') {
    throw new Error('Akun ini bukan akun SPV.');
  }

  return {
    token: data.token,
    user: data.user,
  };
}

/**
 * Lists all admin_pos accounts in the SPV's branch.
 * @param {string} token
 * @param {typeof fetch} [fetchImpl=fetch]
 * @param {object} [options={}]
 * @returns {Promise<Array<object>>}
 */
export async function listAccounts(token, fetchImpl = fetch, options = {}) {
  const url = `${options.supabaseUrl || SUPABASE_URL}/functions/v1/admin-accounts`;
  const anonKey = options.supabaseAnonKey || SUPABASE_ANON_KEY;

  let res;
  try {
    res = await fetchImpl(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: anonKey,
        Authorization: `Bearer ${anonKey}`,
        'x-app-session': token,
      },
      body: JSON.stringify({ action: 'list' }),
    });
  } catch {
    throw new Error('Gagal terkirim. Cek sinyal lalu coba lagi.');
  }

  if (res.status === 401) {
    throw new Error('Sesi habis, masuk lagi.');
  }
  if (res.status === 403) {
    throw new Error('Hanya SPV yang boleh mengakses.');
  }
  if (!res.ok) {
    throw new Error('Server bermasalah, coba lagi.');
  }

  let data;
  try {
    data = await res.json();
  } catch {
    throw new Error('Server bermasalah, coba lagi.');
  }

  return data?.accounts || [];
}

/**
 * Creates an admin_pos account.
 * @param {string} token
 * @param {{ nama: string, pos_name: string, pos_kode: string, password: string }} param1
 * @param {typeof fetch} [fetchImpl=fetch]
 * @param {object} [options={}]
 * @returns {Promise<{ id: string, username: string }>}
 */
export async function createAccount(
  token,
  { nama, pos_name, pos_kode, password },
  fetchImpl = fetch,
  options = {}
) {
  const url = `${options.supabaseUrl || SUPABASE_URL}/functions/v1/admin-accounts`;
  const anonKey = options.supabaseAnonKey || SUPABASE_ANON_KEY;

  let res;
  try {
    res = await fetchImpl(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: anonKey,
        Authorization: `Bearer ${anonKey}`,
        'x-app-session': token,
      },
      body: JSON.stringify({
        action: 'create',
        nama: String(nama ?? '').trim(),
        pos_name: String(pos_name ?? '').trim(),
        pos_kode: String(pos_kode ?? '').trim(),
        password: String(password ?? ''),
      }),
    });
  } catch {
    throw new Error('Gagal terkirim. Cek sinyal lalu coba lagi.');
  }

  if (res.status === 401) {
    throw new Error('Sesi habis, masuk lagi.');
  }
  if (res.status === 403) {
    throw new Error('Hanya SPV yang boleh mengakses.');
  }
  if (res.status === 409) {
    throw new Error('Username sudah digunakan.');
  }
  if (res.status === 400) {
    const body = await res.json().catch(() => null);
    const fieldMessages = {
      nama: 'Nama admin cuma boleh huruf dan spasi, tanpa kode lokasi.',
      pos_kode: 'Kode lokasi 2-10 huruf kecil atau angka.',
      pos_name: 'Lokasi tidak ditemukan di cabang ini.',
      password: 'Kata sandi minimal 8 karakter dan beda dari nama pengguna.',
    };
    throw new Error(fieldMessages[body?.field] || 'Data belum benar, cek lagi isiannya.');
  }
  if (!res.ok) {
    throw new Error('Server bermasalah, coba lagi.');
  }

  let data;
  try {
    data = await res.json();
  } catch {
    throw new Error('Server bermasalah, coba lagi.');
  }

  return {
    id: data?.id,
    username: data?.username,
  };
}

/**
 * Resets the password of an admin_pos account.
 * @param {string} token
 * @param {string} id
 * @param {string} password
 * @param {typeof fetch} [fetchImpl=fetch]
 * @param {object} [options={}]
 * @returns {Promise<{ ok: boolean }>}
 */
export async function resetPassword(token, id, password, fetchImpl = fetch, options = {}) {
  const url = `${options.supabaseUrl || SUPABASE_URL}/functions/v1/admin-accounts`;
  const anonKey = options.supabaseAnonKey || SUPABASE_ANON_KEY;

  let res;
  try {
    res = await fetchImpl(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: anonKey,
        Authorization: `Bearer ${anonKey}`,
        'x-app-session': token,
      },
      body: JSON.stringify({
        action: 'reset_password',
        id: String(id ?? ''),
        password: String(password ?? ''),
      }),
    });
  } catch {
    throw new Error('Gagal terkirim. Cek sinyal lalu coba lagi.');
  }

  if (res.status === 401) {
    throw new Error('Sesi habis, masuk lagi.');
  }
  if (res.status === 403) {
    throw new Error('Hanya SPV yang boleh mengakses.');
  }
  if (res.status === 404) {
    throw new Error('Akun tidak ditemukan.');
  }
  if (!res.ok) {
    throw new Error('Server bermasalah, coba lagi.');
  }

  return { ok: true };
}

/**
 * Activates or deactivates an admin_pos account.
 * @param {string} token
 * @param {string} id
 * @param {boolean} aktif
 * @param {typeof fetch} [fetchImpl=fetch]
 * @param {object} [options={}]
 * @returns {Promise<{ ok: boolean }>}
 */
export async function setAktif(token, id, aktif, fetchImpl = fetch, options = {}) {
  const url = `${options.supabaseUrl || SUPABASE_URL}/functions/v1/admin-accounts`;
  const anonKey = options.supabaseAnonKey || SUPABASE_ANON_KEY;

  let res;
  try {
    res = await fetchImpl(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: anonKey,
        Authorization: `Bearer ${anonKey}`,
        'x-app-session': token,
      },
      body: JSON.stringify({
        action: 'set_aktif',
        id: String(id ?? ''),
        aktif: Boolean(aktif),
      }),
    });
  } catch {
    throw new Error('Gagal terkirim. Cek sinyal lalu coba lagi.');
  }

  if (res.status === 401) {
    throw new Error('Sesi habis, masuk lagi.');
  }
  if (res.status === 403) {
    throw new Error('Hanya SPV yang boleh mengakses.');
  }
  if (res.status === 404) {
    throw new Error('Akun tidak ditemukan.');
  }
  if (!res.ok) {
    throw new Error('Server bermasalah, coba lagi.');
  }

  return { ok: true };
}

/**
 * Fetches POS locations for the SPV's branch.
 * @param {string} token
 * @param {typeof fetch} [fetchImpl=fetch]
 * @param {object} [options={}]
 * @returns {Promise<Array<object>>}
 */
export async function fetchPosList(token, fetchImpl = fetch, options = {}) {
  const baseUrl = options.supabaseUrl || SUPABASE_URL;
  const anonKey = options.supabaseAnonKey || SUPABASE_ANON_KEY;

  // Primary: try pos-locations function with action: 'list'
  try {
    const res = await fetchImpl(`${baseUrl}/functions/v1/pos-locations`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: anonKey,
        Authorization: `Bearer ${anonKey}`,
        'x-app-session': token,
      },
      body: JSON.stringify({ action: 'list' }),
    });
    if (res.ok) {
      const data = await res.json();
      if (Array.isArray(data)) return data;
      if (Array.isArray(data?.locations)) return data.locations;
      if (Array.isArray(data?.pos)) return data.pos;
    }
  } catch {
    // network or endpoint error, fallback to REST
  }

  // Fallback: REST public.pos_locations table
  let res;
  try {
    res = await fetchImpl(
      `${baseUrl}/rest/v1/pos_locations?select=pos_id,pos_name,location_tag&active=eq.true&order=pos_name.asc`,
      {
        method: 'GET',
        headers: {
          apikey: anonKey,
          Authorization: `Bearer ${anonKey}`,
          'x-app-session': token,
        },
      }
    );
  } catch {
    throw new Error('Gagal terkirim. Cek sinyal lalu coba lagi.');
  }

  if (res.status === 401) {
    throw new Error('Sesi habis, masuk lagi.');
  }
  if (res.status === 403) {
    throw new Error('Hanya SPV yang boleh mengakses.');
  }
  if (!res.ok) {
    throw new Error('Server bermasalah, coba lagi.');
  }

  const data = await res.json();
  return Array.isArray(data) ? data : [];
}

/**
 * Builds the preview username: slug(nama)-kode.
 * slug: lowercase, spaces removed, [a-z0-9] only, max 20 chars.
 * @param {string} nama
 * @param {string} kode
 * @returns {string}
 */
export function usernamePreview(nama, kode) {
  const slug = String(nama ?? '')
    .toLowerCase()
    .replace(/\s+/g, '')
    .replace(/[^a-z0-9]/g, '')
    .slice(0, 20);
  const cleanKode = String(kode ?? '')
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '')
    .slice(0, 10);
  return `${slug}-${cleanKode}`;
}

/**
 * Generates a random 10-character password without look-alike characters (0, O, 1, l, I).
 * Uses crypto.getRandomValues unless a test rng is passed.
 * @param {Function} [rng]
 * @returns {string}
 */
export function generatePassword(rng) {
  const n = PASSWORD_CHARS.length;
  const buf = new Uint32Array(10);
  if (typeof rng !== 'function') globalThis.crypto.getRandomValues(buf);
  let res = '';
  for (let i = 0; i < 10; i++) {
    const idx = typeof rng === 'function' ? Math.floor(Math.abs(rng()) * n) % n : buf[i] % n;
    res += PASSWORD_CHARS[idx];
  }
  return res;
}

/**
 * Persists SPV session to storage.
 * @param {object} session
 * @param {Storage} storage
 */
export function saveSpvSession(session, storage) {
  if (!session || !storage) return;
  const payload = {
    ...session,
    savedAt: session.savedAt || Date.now(),
    expiresAt: session.expiresAt || Date.now() + DEFAULT_TTL_MS,
  };
  storage.setItem(SPV_SESSION_KEY, JSON.stringify(payload));
}

/**
 * Loads SPV session from storage, dropping expired sessions.
 * @param {Storage} storage
 * @returns {object|null}
 */
export function loadSpvSession(storage) {
  if (!storage) return null;
  const raw = storage.getItem(SPV_SESSION_KEY);
  if (!raw) return null;
  try {
    const session = JSON.parse(raw);
    if (!session || typeof session !== 'object') {
      clearSpvSession(storage);
      return null;
    }
    if (typeof session.expiresAt === 'number' && Date.now() > session.expiresAt) {
      clearSpvSession(storage);
      return null;
    }
    return session;
  } catch {
    clearSpvSession(storage);
    return null;
  }
}

/**
 * Clears SPV session from storage.
 * @param {Storage} storage
 */
export function clearSpvSession(storage) {
  if (!storage) return;
  storage.removeItem(SPV_SESSION_KEY);
}

/**
 * Lists error reports filed by the logged-in admin_pos for their location.
 * @param {string} token
 * @param {typeof fetch} [fetchImpl=fetch]
 * @param {object} [options={}]
 * @returns {Promise<Array<object>>}
 */
export async function listMyReports(token, fetchImpl = fetch, options = {}) {
  const url = `${options.supabaseUrl || SUPABASE_URL}/functions/v1/daily-tasks`;
  const anonKey = options.supabaseAnonKey || SUPABASE_ANON_KEY;

  let res;
  try {
    res = await fetchImpl(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: anonKey,
        Authorization: `Bearer ${anonKey}`,
        'x-app-session': token,
      },
      body: JSON.stringify({ action: 'admin_list' }),
    });
  } catch {
    throw new Error('gagal memuat riwayat');
  }

  if (res.status === 401) {
    throw new Error('sesi habis');
  }
  if (!res.ok) {
    throw new Error('gagal memuat riwayat');
  }

  let data;
  try {
    data = await res.json();
  } catch {
    throw new Error('gagal memuat riwayat');
  }

  if (!data || !Array.isArray(data.reports)) {
    throw new Error('gagal memuat riwayat');
  }

  return data.reports;
}

/**
 * Returns display text and CSS class for a report status.
 * @param {{ status?: string, teknisi?: string|null }} report
 * @returns {{ text: string, cssClass: string }}
 */
export function statusInfo(report) {
  const status = report?.status;
  if (status === 'selesai') {
    const tech = report?.teknisi;
    return { text: tech ? `Selesai oleh ${tech}` : 'Selesai', cssClass: 'status-selesai' };
  }
  if (status === 'ditangani') {
    return { text: `Ditangani oleh ${report?.teknisi}`, cssClass: 'status-ditangani' };
  }
  return { text: 'Menunggu Teknisi', cssClass: 'status-menunggu' };
}

/**
 * Formats second meta line for riwayat card (e.g. 'Diambil 10:05 · Selesai 10:15').
 * Only includes the parts that exist.
 * @param {{ diambil?: string|null, selesai?: string|null }|null} report
 * @returns {string}
 */
export function riwayatMeta(report) {
  if (!report || typeof report !== 'object') return '';
  const formatTime = (val) => {
    if (!val || typeof val !== 'string') return '';
    const trimmed = val.trim();
    const match = trimmed.match(/(\d{1,2}[:.]\d{2})$/);
    if (match) return match[1].replace('.', ':');
    return trimmed;
  };
  const parts = [];
  const d = formatTime(report.diambil);
  if (d) parts.push(`Diambil ${d}`);
  const s = formatTime(report.selesai);
  if (s) parts.push(`Selesai ${s}`);
  return parts.join(' · ');
}
