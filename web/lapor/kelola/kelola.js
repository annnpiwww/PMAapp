import {
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
} from '/lapor/lapor-core.js';

// Register Service Worker
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/lapor/sw.js', { scope: '/lapor/' }).catch(() => {});
  });
}

// Screens
const screenLogin = document.getElementById('screen-spv-login');
const screenK1 = document.getElementById('screen-k1');
const screenK2 = document.getElementById('screen-k2');
const screenK3 = document.getElementById('screen-k3');

// Login DOM
const formSpvLogin = document.getElementById('form-spv-login');
const inputSpvUsername = document.getElementById('spv-username');
const inputSpvPassword = document.getElementById('spv-password');
const btnToggleSpvPw = document.getElementById('btn-toggle-spv-pw');
const spvLoginError = document.getElementById('spv-login-error');
const btnSpvLogin = document.getElementById('btn-spv-login');

// K1 DOM
const k1Subtitle = document.getElementById('k1-subtitle');
const k1Loading = document.getElementById('k1-loading');
const k1Error = document.getElementById('k1-error');
const k1ErrorText = document.getElementById('k1-error-text');
const btnK1Retry = document.getElementById('btn-k1-retry');
const k1Empty = document.getElementById('k1-empty');
const k1List = document.getElementById('k1-list');
const k1Footnote = document.getElementById('k1-footnote');
const btnGoAdd = document.getElementById('btn-go-add');

// K2 DOM
const formCreate = document.getElementById('form-create');
const inputNama = document.getElementById('k2-nama');
const selectLokasi = document.getElementById('k2-lokasi');
const inputKode = document.getElementById('k2-kode');
const previewUsername = document.getElementById('k2-username-preview');
const inputNewPassword = document.getElementById('k2-password');
const btnGenPw = document.getElementById('btn-gen-pw');
const btnSaveAccount = document.getElementById('btn-save-account');
const errK2Nama = document.getElementById('err-k2-nama');
const errK2Lokasi = document.getElementById('err-k2-lokasi');
const errK2Kode = document.getElementById('err-k2-kode');
const errK2Password = document.getElementById('err-k2-password');
const k2FormError = document.getElementById('k2-form-error');

// K3 DOM
const k3PosSubtitle = document.getElementById('k3-pos-subtitle');
const k3Heading = document.getElementById('k3-heading');
const k3Subheading = document.getElementById('k3-subheading');
const k3Username = document.getElementById('k3-username');
const k3Password = document.getElementById('k3-password');
const btnShareCred = document.getElementById('btn-share-cred');
const btnK3Done = document.getElementById('btn-k3-done');

// Logout buttons
const btnLogoutK1 = document.getElementById('btn-logout-k1');
const btnLogoutK2 = document.getElementById('btn-logout-k2');
const btnLogoutK3 = document.getElementById('btn-logout-k3');

// Atur sheet DOM
const aturBackdrop = document.getElementById('atur-backdrop');
const aturDialog = document.getElementById('atur-dialog');
const aturTitle = document.getElementById('atur-title');
const aturSub = document.getElementById('atur-sub');
const btnAturClose = document.getElementById('btn-atur-close');
const aturMenu = document.getElementById('atur-menu');
const btnAturResetView = document.getElementById('btn-atur-reset-view');
const btnAturToggleView = document.getElementById('btn-atur-toggle-view');
const aturToggleLabel = document.getElementById('atur-toggle-label');

const formAturReset = document.getElementById('form-atur-reset');
const inputAturNewPw = document.getElementById('atur-new-pw');
const btnAturGenPw = document.getElementById('btn-atur-gen-pw');
const aturResetError = document.getElementById('atur-reset-error');
const btnAturResetCancel = document.getElementById('btn-atur-reset-cancel');
const btnAturResetSave = document.getElementById('btn-atur-reset-save');

const aturConfirm = document.getElementById('atur-confirm');
const aturConfirmText = document.getElementById('atur-confirm-text');
const aturConfirmError = document.getElementById('atur-confirm-error');
const btnAturConfirmCancel = document.getElementById('btn-atur-confirm-cancel');
const btnAturConfirmOk = document.getElementById('btn-atur-confirm-ok');

const toastEl = document.getElementById('toast');

let spvSession = null;
let accountsCache = [];
let posListCache = [];
let activeAccount = null;
let lastTriggerEl = null;
let currentCredentials = null;
let toastTimer = null;

function showToast(text) {
  if (toastTimer) clearTimeout(toastTimer);
  toastEl.textContent = text;
  toastEl.classList.remove('hidden');
  toastTimer = setTimeout(() => {
    toastEl.classList.add('hidden');
  }, 3000);
}

function showScreen(name) {
  screenLogin.classList.toggle('hidden', name !== 'login');
  screenK1.classList.toggle('hidden', name !== 'k1');
  screenK2.classList.toggle('hidden', name !== 'k2');
  screenK3.classList.toggle('hidden', name !== 'k3');
}

function handleLogout(alertMsg = '') {
  clearSpvSession(localStorage);
  spvSession = null;
  currentCredentials = null;
  closeAturSheet();
  inputSpvPassword.value = '';
  if (alertMsg) {
    spvLoginError.textContent = alertMsg;
    spvLoginError.classList.remove('hidden');
  } else {
    spvLoginError.textContent = '';
    spvLoginError.classList.add('hidden');
  }
  showScreen('login');
}

// Render K1 grouped list
function renderAccounts(accounts) {
  const cabang = spvSession?.user?.cabang || 'KC Manado';
  k1Subtitle.textContent = `${cabang} · ${accounts.length} akun`;
  k1List.innerHTML = '';

  if (accounts.length === 0) {
    k1Empty.classList.remove('hidden');
    k1Footnote.classList.add('hidden');
    return;
  }

  k1Empty.classList.add('hidden');
  k1Footnote.classList.remove('hidden');

  const groups = new Map();
  for (const acc of accounts) {
    const pos = acc.pos_name || 'Lokasi lainnya';
    if (!groups.has(pos)) {
      groups.set(pos, { pos_name: pos, pos_kode: acc.pos_kode || '', items: [] });
    }
    groups.get(pos).items.push(acc);
  }

  for (const group of groups.values()) {
    const section = document.createElement('div');
    section.className = 'pos-group';

    const title = document.createElement('h2');
    title.className = 'pos-group-title';
    title.textContent = group.pos_name;
    section.appendChild(title);

    if (group.pos_kode) {
      const codeEl = document.createElement('p');
      codeEl.className = 'pos-group-code';
      codeEl.textContent = `Kode ${String(group.pos_kode).toUpperCase()}`;
      section.appendChild(codeEl);
    }

    const listWrap = document.createElement('div');
    listWrap.className = 'account-list';

    for (const acc of group.items) {
      const isAktif = acc.aktif !== false;
      const card = document.createElement('div');
      card.className = isAktif ? 'account-card' : 'account-card account-card--nonaktif';

      const info = document.createElement('div');
      info.className = 'account-info';

      const namaEl = document.createElement('p');
      namaEl.className = 'account-nama';
      namaEl.textContent = acc.nama;

      const userEl = document.createElement('p');
      userEl.className = 'account-username';
      userEl.textContent = isAktif ? acc.username : `${acc.username} · nonaktif`;

      info.appendChild(namaEl);
      info.appendChild(userEl);

      const btnAtur = document.createElement('button');
      btnAtur.type = 'button';
      btnAtur.className = 'btn-text';
      btnAtur.textContent = 'Atur';
      btnAtur.setAttribute('aria-label', `Atur ${acc.nama}`);
      btnAtur.addEventListener('click', () => openAturSheet(acc, btnAtur));

      card.appendChild(info);
      card.appendChild(btnAtur);
      listWrap.appendChild(card);
    }

    section.appendChild(listWrap);
    k1List.appendChild(section);
  }
}

async function loadK1Data() {
  showScreen('k1');
  k1Loading.classList.remove('hidden');
  k1Error.classList.add('hidden');
  k1Empty.classList.add('hidden');
  k1Footnote.classList.add('hidden');
  k1List.innerHTML = '';

  try {
    const accounts = await listAccounts(spvSession.token);
    accountsCache = accounts;
    k1Loading.classList.add('hidden');
    renderAccounts(accounts);
  } catch (err) {
    k1Loading.classList.add('hidden');
    const msg = err?.message || 'Gagal memuat akun.';
    if (msg.includes('Sesi habis')) {
      handleLogout(msg);
      return;
    }
    k1ErrorText.textContent = msg;
    k1Error.classList.remove('hidden');
  }
}

// K2 Helpers
function clearK2Errors() {
  for (const el of [errK2Nama, errK2Lokasi, errK2Kode, errK2Password, k2FormError]) {
    el.textContent = '';
    el.classList.add('hidden');
  }
  for (const id of ['box-k2-nama', 'box-k2-lokasi', 'box-k2-kode', 'box-k2-password']) {
    document.getElementById(id)?.classList.remove('field-box--error');
  }
}

function updatePreview() {
  const prev = usernamePreview(inputNama.value, inputKode.value);
  previewUsername.textContent = prev === '-' ? '-' : prev;
}

function deriveCodeForPos(posName) {
  const existingAcc = accountsCache.find(
    (a) => a.pos_name && a.pos_name.toLowerCase() === posName.toLowerCase() && a.pos_kode
  );
  if (existingAcc) return String(existingAcc.pos_kode).toLowerCase();

  const foundPos = posListCache.find((p) => {
    const name = p.pos_name || p.name || '';
    return name.toLowerCase() === posName.toLowerCase();
  });
  if (foundPos) {
    const rawCode = foundPos.pos_kode || foundPos.code || foundPos.location_tag || '';
    if (rawCode) {
      return String(rawCode).toLowerCase().replace(/[^a-z0-9]/g, '').slice(0, 10);
    }
  }
  return '';
}

async function openK2Screen() {
  clearK2Errors();
  inputNama.value = '';
  inputKode.value = '';
  inputNewPassword.value = '';
  updatePreview();
  showScreen('k2');

  // Populate select
  selectLokasi.innerHTML = '<option value="">Pilih lokasi</option>';
  try {
    if (posListCache.length === 0) {
      posListCache = await fetchPosList(spvSession.token);
    }
  } catch {
    // Fallback to any known pos names from existing accounts if pos-locations fails
  }

  const namesSet = new Set();
  for (const p of posListCache) {
    const n = typeof p === 'string' ? p : p.pos_name || p.name;
    if (n) namesSet.add(n);
  }
  for (const a of accountsCache) {
    if (a.pos_name) namesSet.add(a.pos_name);
  }

  for (const name of namesSet) {
    const opt = document.createElement('option');
    opt.value = name;
    opt.textContent = name;
    selectLokasi.appendChild(opt);
  }
}

// K3 Screen
function openK3Screen({ nama, pos_name, username, password, isReset = false }) {
  currentCredentials = { nama, pos_name, username, password };
  k3PosSubtitle.textContent = pos_name || '-';
  k3Heading.textContent = isReset ? `Kata sandi ${nama} direset` : `Akun ${nama} dibuat`;
  k3Subheading.textContent = `Kirim data masuk ini ke ${nama}.`;
  k3Username.textContent = username;
  k3Password.textContent = password;
  showScreen('k3');
}

// Atur Sheet Logic + Focus Trap
function showAturView(view) {
  aturMenu.classList.toggle('hidden', view !== 'menu');
  formAturReset.classList.toggle('hidden', view !== 'reset');
  aturConfirm.classList.toggle('hidden', view !== 'confirm');
  aturResetError.classList.add('hidden');
  aturConfirmError.classList.add('hidden');
}

function openAturSheet(acc, triggerEl) {
  activeAccount = acc;
  lastTriggerEl = triggerEl || null;
  aturTitle.textContent = acc.nama;
  aturSub.textContent = `${acc.username} · ${acc.pos_name || ''}`;
  const isAktif = acc.aktif !== false;
  aturToggleLabel.textContent = isAktif ? 'Nonaktifkan akun' : 'Aktifkan lagi';
  btnAturToggleView.classList.toggle('sheet-action-btn--danger', isAktif);

  showAturView('menu');
  aturBackdrop.classList.remove('hidden');
  btnAturResetView.focus();
}

function closeAturSheet() {
  aturBackdrop.classList.add('hidden');
  activeAccount = null;
  if (lastTriggerEl && typeof lastTriggerEl.focus === 'function') {
    lastTriggerEl.focus();
  }
  lastTriggerEl = null;
}

// Keyboard Escape & Focus trap for Atur sheet
document.addEventListener('keydown', (e) => {
  if (aturBackdrop.classList.contains('hidden')) return;
  if (e.key === 'Escape') {
    e.preventDefault();
    closeAturSheet();
    return;
  }
  if (e.key === 'Tab') {
    const focusables = Array.from(
      aturDialog.querySelectorAll(
        'button:not([disabled]), input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])'
      )
    ).filter((el) => el.offsetParent !== null);
    if (focusables.length === 0) return;
    const first = focusables[0];
    const last = focusables[focusables.length - 1];
    if (e.shiftKey && document.activeElement === first) {
      e.preventDefault();
      last.focus();
    } else if (!e.shiftKey && document.activeElement === last) {
      e.preventDefault();
      first.focus();
    }
  }
});

aturBackdrop.addEventListener('click', (e) => {
  if (e.target === aturBackdrop) closeAturSheet();
});
btnAturClose.addEventListener('click', () => closeAturSheet());

btnAturResetView.addEventListener('click', () => {
  inputAturNewPw.value = generatePassword();
  showAturView('reset');
  inputAturNewPw.focus();
});

btnAturGenPw.addEventListener('click', () => {
  inputAturNewPw.value = generatePassword();
  inputAturNewPw.focus();
});

btnAturResetCancel.addEventListener('click', () => {
  showAturView('menu');
});

formAturReset.addEventListener('submit', async (e) => {
  e.preventDefault();
  if (!activeAccount) return;
  const pw = inputAturNewPw.value;
  if (!pw || pw.length < 8) {
    aturResetError.textContent = 'Kata sandi minimal 8 karakter.';
    aturResetError.classList.remove('hidden');
    return;
  }
  if (pw === activeAccount.username) {
    aturResetError.textContent = 'Kata sandi tidak boleh sama dengan nama pengguna.';
    aturResetError.classList.remove('hidden');
    return;
  }

  btnAturResetSave.disabled = true;
  btnAturResetSave.textContent = 'Menyimpan...';

  try {
    await resetPassword(spvSession.token, activeAccount.id, pw);
    const acc = activeAccount;
    closeAturSheet();
    openK3Screen({
      nama: acc.nama,
      pos_name: acc.pos_name,
      username: acc.username,
      password: pw,
      isReset: true,
    });
  } catch (err) {
    aturResetError.textContent = err?.message || 'Gagal mereset kata sandi.';
    aturResetError.classList.remove('hidden');
  } finally {
    btnAturResetSave.disabled = false;
    btnAturResetSave.textContent = 'Simpan';
  }
});

btnAturToggleView.addEventListener('click', async () => {
  if (!activeAccount) return;
  const isAktif = activeAccount.aktif !== false;
  if (isAktif) {
    aturConfirmText.textContent = `Nonaktifkan ${activeAccount.nama}? Dia tidak bisa masuk dan melapor lagi.`;
    btnAturConfirmOk.textContent = 'Nonaktifkan';
    showAturView('confirm');
    btnAturConfirmOk.focus();
  } else {
    try {
      await setAktif(spvSession.token, activeAccount.id, true);
      closeAturSheet();
      await loadK1Data();
    } catch (err) {
      showToast(err?.message || 'Gagal mengaktifkan akun.');
    }
  }
});

btnAturConfirmCancel.addEventListener('click', () => {
  showAturView('menu');
});

btnAturConfirmOk.addEventListener('click', async () => {
  if (!activeAccount) return;
  btnAturConfirmOk.disabled = true;
  try {
    await setAktif(spvSession.token, activeAccount.id, false);
    closeAturSheet();
    await loadK1Data();
  } catch (err) {
    aturConfirmError.textContent = err?.message || 'Gagal menonaktifkan akun.';
    aturConfirmError.classList.remove('hidden');
  } finally {
    btnAturConfirmOk.disabled = false;
  }
});

// Login Events
btnToggleSpvPw.addEventListener('click', () => {
  const isHidden = inputSpvPassword.type === 'password';
  inputSpvPassword.type = isHidden ? 'text' : 'password';
  btnToggleSpvPw.textContent = isHidden ? 'Sembunyikan' : 'Tampilkan';
  btnToggleSpvPw.setAttribute('aria-pressed', isHidden ? 'true' : 'false');
});

formSpvLogin.addEventListener('submit', async (e) => {
  e.preventDefault();
  spvLoginError.textContent = '';
  spvLoginError.classList.add('hidden');

  const identity = inputSpvUsername.value.trim();
  const password = inputSpvPassword.value;
  if (!identity || !password) {
    spvLoginError.textContent = 'Isi nama pengguna dan kata sandi.';
    spvLoginError.classList.remove('hidden');
    return;
  }

  btnSpvLogin.disabled = true;
  btnSpvLogin.textContent = 'Masuk...';

  try {
    const session = await loginSpv(identity, password);
    saveSpvSession(session, localStorage);
    spvSession = session;
    await loadK1Data();
  } catch (err) {
    spvLoginError.textContent = err?.message || 'Gagal masuk.';
    spvLoginError.classList.remove('hidden');
  } finally {
    btnSpvLogin.disabled = false;
    btnSpvLogin.textContent = 'Masuk';
  }
});

btnLogoutK1.addEventListener('click', () => handleLogout());
btnLogoutK2.addEventListener('click', () => handleLogout());
btnLogoutK3.addEventListener('click', () => handleLogout());

btnK1Retry.addEventListener('click', () => loadK1Data());
btnGoAdd.addEventListener('click', () => openK2Screen());

// K2 Events
inputNama.addEventListener('input', () => updatePreview());
inputKode.addEventListener('input', () => {
  inputKode.value = inputKode.value.toLowerCase().replace(/[^a-z0-9]/g, '').slice(0, 10);
  updatePreview();
});
selectLokasi.addEventListener('change', () => {
  const code = deriveCodeForPos(selectLokasi.value);
  if (code) {
    inputKode.value = code;
    updatePreview();
  }
});

btnGenPw.addEventListener('click', () => {
  inputNewPassword.value = generatePassword();
  inputNewPassword.focus();
});

formCreate.addEventListener('submit', async (e) => {
  e.preventDefault();
  clearK2Errors();

  const nama = inputNama.value.trim();
  const pos_name = selectLokasi.value.trim();
  const pos_kode = inputKode.value.trim().toLowerCase();
  const password = inputNewPassword.value;

  if (nama.length < 2) {
    errK2Nama.textContent = 'Isi nama admin minimal 2 huruf.';
    errK2Nama.classList.remove('hidden');
    document.getElementById('box-k2-nama')?.classList.add('field-box--error');
    inputNama.focus();
    return;
  }
  if (!pos_name) {
    errK2Lokasi.textContent = 'Pilih lokasi dulu.';
    errK2Lokasi.classList.remove('hidden');
    document.getElementById('box-k2-lokasi')?.classList.add('field-box--error');
    selectLokasi.focus();
    return;
  }
  if (pos_kode.length < 2) {
    errK2Kode.textContent = 'Isi kode lokasi minimal 2 karakter.';
    errK2Kode.classList.remove('hidden');
    document.getElementById('box-k2-kode')?.classList.add('field-box--error');
    inputKode.focus();
    return;
  }
  const expectedUsername = usernamePreview(nama, pos_kode);
  if (!password || password.length < 8) {
    errK2Password.textContent = 'Kata sandi minimal 8 karakter.';
    errK2Password.classList.remove('hidden');
    document.getElementById('box-k2-password')?.classList.add('field-box--error');
    inputNewPassword.focus();
    return;
  }
  if (password === expectedUsername) {
    errK2Password.textContent = 'Kata sandi tidak boleh sama dengan nama pengguna.';
    errK2Password.classList.remove('hidden');
    document.getElementById('box-k2-password')?.classList.add('field-box--error');
    inputNewPassword.focus();
    return;
  }

  btnSaveAccount.disabled = true;
  btnSaveAccount.textContent = 'Menyimpan...';

  try {
    const created = await createAccount(spvSession.token, {
      nama,
      pos_name,
      pos_kode,
      password,
    });
    openK3Screen({
      nama,
      pos_name,
      username: created.username || expectedUsername,
      password,
      isReset: false,
    });
  } catch (err) {
    const msg = err?.message || 'Gagal menyimpan akun.';
    if (msg.includes('Sesi habis')) {
      handleLogout(msg);
      return;
    }
    if (msg.includes('Username sudah digunakan')) {
      errK2Nama.textContent = 'Nama pengguna ini sudah dipakai. Tambah huruf pada nama.';
      errK2Nama.classList.remove('hidden');
      document.getElementById('box-k2-nama')?.classList.add('field-box--error');
      inputNama.focus();
      return;
    }
    k2FormError.textContent = msg;
    k2FormError.classList.remove('hidden');
  } finally {
    btnSaveAccount.disabled = false;
    btnSaveAccount.textContent = 'Simpan akun';
  }
});

// K3 Events
btnShareCred.addEventListener('click', async () => {
  if (!currentCredentials) return;
  const text = [
    `Alamat: bssparking-pma.vercel.app/lapor`,
    `Nama pengguna: ${currentCredentials.username}`,
    `Kata sandi: ${currentCredentials.password}`,
  ].join('\n');

  if (typeof navigator.share === 'function') {
    try {
      await navigator.share({ text });
      return;
    } catch (err) {
      if (err && err.name === 'AbortError') return;
    }
  }
  if (navigator.clipboard && typeof navigator.clipboard.writeText === 'function') {
    await navigator.clipboard.writeText(text);
  }
  showToast('Data masuk disalin.');
});

btnK3Done.addEventListener('click', async () => {
  currentCredentials = null;
  k3Password.textContent = '-';
  await loadK1Data();
});

// Boot
const savedSpv = loadSpvSession(localStorage);
if (savedSpv && savedSpv.token) {
  spvSession = savedSpv;
  loadK1Data();
} else {
  showScreen('login');
}
