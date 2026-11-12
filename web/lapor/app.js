import {
  nowParts,
  validate,
  login,
  sendReport,
  shareReport,
  saveSession,
  loadSession,
  clearSession,
  listMyReports,
  statusInfo,
  riwayatMeta,
} from '/lapor/lapor-core.js';

const DRAFT_KEY = 'lapor_draft_v1';
const ACTIVE_TAB_KEY = 'lapor_active_tab';

// Register Service Worker
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/lapor/sw.js', { scope: '/lapor/' }).catch(() => {});
  });
}

// DOM Elements
const screenL1 = document.getElementById('screen-l1');
const screenL2 = document.getElementById('screen-l2');
const screenL3 = document.getElementById('screen-l3');

const tabBtnLaporan = document.getElementById('tab-btn-laporan');
const tabBtnRiwayat = document.getElementById('tab-btn-riwayat');
const tabPanelLaporan = document.getElementById('tab-laporan');
const tabPanelRiwayat = document.getElementById('tab-riwayat');
const riwayatBadge = document.getElementById('riwayat-badge');
const l2BottomBar = document.getElementById('l2-bottom-bar');

const formLogin = document.getElementById('form-login');
const inputUsername = document.getElementById('login-username');
const inputPassword = document.getElementById('login-password');
const btnTogglePw = document.getElementById('btn-toggle-pw');
const loginError = document.getElementById('login-error');
const btnLogin = document.getElementById('btn-login');

const l2PosName = document.getElementById('l2-pos-name');
const l3PosName = document.getElementById('l3-pos-name');
const btnLogoutL2 = document.getElementById('btn-logout-l2');
const btnLogoutL3 = document.getElementById('btn-logout-l3');

const formReport = document.getElementById('form-report');
const inputTanggal = document.getElementById('report-tanggal');
const inputWaktu = document.getElementById('report-waktu');
const inputKendala = document.getElementById('report-kendala');
const inputPenyebab = document.getElementById('report-penyebab');
const inputSolusi = document.getElementById('report-solusi');
const inputDurasi = document.getElementById('report-durasi');
const reportError = document.getElementById('report-error');
const btnSend = document.getElementById('btn-send');

const inputCamera = document.getElementById('input-camera');
const inputVideo = document.getElementById('input-video');
const inputGallery = document.getElementById('input-gallery');
const btnCamera = document.getElementById('btn-camera');
const btnVideo = document.getElementById('btn-video');
const btnGallery = document.getElementById('btn-gallery');
const photoPickers = document.getElementById('photo-pickers');
const photoPreviewWrap = document.getElementById('photo-preview-wrap');
const photoThumb = document.getElementById('photo-thumb');
const videoThumb = document.getElementById('video-thumb');
const btnRemovePhoto = document.getElementById('btn-remove-photo');

const l3StatusSub = document.getElementById('l3-status-sub');
const l3Message = document.getElementById('l3-message');
const l3PhotoHint = document.getElementById('l3-photo-hint');
const btnShareAgain = document.getElementById('btn-share-again');
const btnReportAnother = document.getElementById('btn-report-another');
const toastEl = document.getElementById('toast');

const riwayatSection = document.getElementById('riwayat-section');
const riwayatList = document.getElementById('riwayat-list');
const riwayatEmpty = document.getElementById('riwayat-empty');

let currentSession = null;
let selectedPhotoFile = null;
let selectedPhotoUrl = null;
let lastSentMessage = '';
let toastTimer = null;
let riwayatPollTimer = null;
let previousStatusMap = null;
let audioCtx = null;

function getAudioContext() {
  if (!audioCtx) {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (AudioContextClass) {
      audioCtx = new AudioContextClass();
    }
  }
  if (audioCtx && audioCtx.state === 'suspended') {
    audioCtx.resume().catch(() => {});
  }
  return audioCtx;
}

function unlockAudio() {
  getAudioContext();
}

function playTwoToneBeep() {
  try {
    const ctx = getAudioContext();
    if (!ctx) return;
    const now = ctx.currentTime;

    const osc1 = ctx.createOscillator();
    const gain1 = ctx.createGain();
    osc1.type = 'sine';
    osc1.frequency.setValueAtTime(587.33, now);
    gain1.gain.setValueAtTime(0.15, now);
    gain1.gain.exponentialRampToValueAtTime(0.01, now + 0.12);
    osc1.connect(gain1);
    gain1.connect(ctx.destination);
    osc1.start(now);
    osc1.stop(now + 0.12);

    const osc2 = ctx.createOscillator();
    const gain2 = ctx.createGain();
    osc2.type = 'sine';
    osc2.frequency.setValueAtTime(880, now + 0.14);
    gain2.gain.setValueAtTime(0.18, now + 0.14);
    gain2.gain.exponentialRampToValueAtTime(0.01, now + 0.32);
    osc2.connect(gain2);
    gain2.connect(ctx.destination);
    osc2.start(now + 0.14);
    osc2.stop(now + 0.32);
  } catch {
    // Ignore audio playback failure
  }
}

function switchTab(tabName) {
  const isLaporan = tabName === 'laporan';
  if (tabBtnLaporan) {
    tabBtnLaporan.setAttribute('aria-selected', isLaporan ? 'true' : 'false');
    tabBtnLaporan.classList.toggle('active', isLaporan);
  }
  if (tabBtnRiwayat) {
    tabBtnRiwayat.setAttribute('aria-selected', isLaporan ? 'false' : 'true');
    tabBtnRiwayat.classList.toggle('active', !isLaporan);
  }
  if (tabPanelLaporan) {
    tabPanelLaporan.classList.toggle('hidden', !isLaporan);
  }
  if (tabPanelRiwayat) {
    tabPanelRiwayat.classList.toggle('hidden', isLaporan);
  }
  if (l2BottomBar) {
    l2BottomBar.classList.toggle('hidden', !isLaporan);
  }
  try {
    sessionStorage.setItem(ACTIVE_TAB_KEY, isLaporan ? 'laporan' : 'riwayat');
  } catch {}
}

function showToast(text) {
  if (toastTimer) clearTimeout(toastTimer);
  toastEl.textContent = text;
  toastEl.classList.remove('hidden');
  toastTimer = setTimeout(() => {
    toastEl.classList.add('hidden');
  }, 3000);
}

function showScreen(which) {
  screenL1.classList.toggle('hidden', which !== 'l1');
  screenL2.classList.toggle('hidden', which !== 'l2');
  screenL3.classList.toggle('hidden', which !== 'l3');
}

function setPosTitle(session) {
  const pos = session?.user?.pos_name || '-';
  l2PosName.textContent = pos;
  l3PosName.textContent = pos;
}

function loadDraft() {
  try {
    const raw = sessionStorage.getItem(DRAFT_KEY);
    if (!raw) return null;
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function saveDraft() {
  try {
    const draft = {
      tanggal: inputTanggal.value,
      waktu: inputWaktu.value,
      kendala: inputKendala.value,
      penyebab: inputPenyebab.value,
      solusi_sementara: inputSolusi.value,
      durasi_error: inputDurasi.value,
    };
    sessionStorage.setItem(DRAFT_KEY, JSON.stringify(draft));
  } catch {
    // ignore storage errors
  }
}

function clearDraft() {
  try {
    sessionStorage.removeItem(DRAFT_KEY);
  } catch {
    // ignore
  }
}

function clearFieldErrors() {
  const fields = ['tanggal', 'waktu', 'kendala', 'penyebab', 'solusi_sementara', 'durasi_error'];
  for (const f of fields) {
    const errEl = document.getElementById(`err-${f}`);
    const boxEl = document.getElementById(`box-${f}`);
    if (errEl) {
      errEl.textContent = '';
      errEl.classList.add('hidden');
    }
    if (boxEl) {
      boxEl.classList.remove('field-box--error');
    }
  }
  reportError.textContent = '';
  reportError.classList.add('hidden');
}

function showFieldError(field, message) {
  clearFieldErrors();
  if (field) {
    const errEl = document.getElementById(`err-${field}`);
    const boxEl = document.getElementById(`box-${field}`);
    if (errEl) {
      errEl.textContent = message;
      errEl.classList.remove('hidden');
    }
    if (boxEl) {
      boxEl.classList.add('field-box--error');
    }
    const inputMap = {
      tanggal: inputTanggal,
      waktu: inputWaktu,
      kendala: inputKendala,
      penyebab: inputPenyebab,
      solusi_sementara: inputSolusi,
      durasi_error: inputDurasi,
    };
    const target = inputMap[field];
    if (target) target.focus();
  } else {
    reportError.textContent = message;
    reportError.classList.remove('hidden');
  }
}

function clearPhoto() {
  if (selectedPhotoUrl) {
    URL.revokeObjectURL(selectedPhotoUrl);
    selectedPhotoUrl = null;
  }
  selectedPhotoFile = null;
  inputCamera.value = '';
  if (inputVideo) inputVideo.value = '';
  inputGallery.value = '';
  photoThumb.removeAttribute('src');
  photoThumb.classList.remove('hidden');
  if (videoThumb) {
    videoThumb.removeAttribute('src');
    videoThumb.load();
    videoThumb.classList.add('hidden');
  }
  photoPreviewWrap.classList.add('hidden');
  photoPickers.classList.remove('hidden');
}

function handlePhotoPicked(file) {
  if (!file) return;
  if (selectedPhotoUrl) URL.revokeObjectURL(selectedPhotoUrl);
  selectedPhotoFile = file;
  selectedPhotoUrl = URL.createObjectURL(file);
  const isVideo = file.type && file.type.startsWith('video/');
  if (isVideo) {
    photoThumb.removeAttribute('src');
    photoThumb.classList.add('hidden');
    videoThumb.src = selectedPhotoUrl;
    videoThumb.classList.remove('hidden');
  } else {
    if (videoThumb) {
      videoThumb.removeAttribute('src');
      videoThumb.load();
      videoThumb.classList.add('hidden');
    }
    photoThumb.src = selectedPhotoUrl;
    photoThumb.classList.remove('hidden');
  }
  photoPickers.classList.add('hidden');
  photoPreviewWrap.classList.remove('hidden');
}

function initReportForm(useSavedDraft = true) {
  clearFieldErrors();
  const now = nowParts(new Date());
  const draft = useSavedDraft ? loadDraft() : null;
  inputTanggal.value = draft?.tanggal || now.tanggal;
  inputWaktu.value = draft?.waktu || now.waktu;
  inputKendala.value = draft?.kendala || '';
  inputPenyebab.value = draft?.penyebab || '';
  inputSolusi.value = draft?.solusi_sementara || '';
  inputDurasi.value = draft?.durasi_error || '';
  if (!useSavedDraft) {
    clearDraft();
    clearPhoto();
  }
}

function formatTanggal(raw) {
  if (!raw) return '-';
  if (typeof raw === 'string') {
    if (/^\d{2}\/\d{2}\/\d{4}$/.test(raw)) return raw;
    if (/^(\d{2})-(\d{2})-(\d{4})$/.test(raw)) return raw.replace(/-/g, '/');
    const match = raw.match(/^(\d{4})-(\d{2})-(\d{2})/);
    if (match) {
      const [, y, m, d] = match;
      return `${d}/${m}/${y}`;
    }
  }
  const d = new Date(raw);
  if (!isNaN(d.getTime())) {
    const day = String(d.getDate()).padStart(2, '0');
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const year = d.getFullYear();
    return `${day}/${month}/${year}`;
  }
  return String(raw);
}

function defaultStatusInfo(reportOrStatus) {
  const s = typeof reportOrStatus === 'object' && reportOrStatus !== null
    ? String(reportOrStatus.status || '').toLowerCase()
    : String(reportOrStatus || '').toLowerCase();
  if (s === 'selesai' || s === 'done' || s === 'closed') {
    return { cssClass: 'status-selesai', text: 'Selesai' };
  }
  if (s === 'ditangani' || s === 'in_progress' || s === 'process') {
    const tech = typeof reportOrStatus === 'object' && reportOrStatus?.teknisi;
    return { cssClass: 'status-ditangani', text: tech ? `Ditangani oleh ${tech}` : 'Ditangani' };
  }
  return { cssClass: 'status-menunggu', text: 'Menunggu' };
}

async function loadRiwayat() {
  if (!currentSession?.token) return;

  try {
    const reports = await listMyReports(currentSession.token);

    if (Array.isArray(reports)) {
      // Update badge for reports still 'menunggu'
      const countMenunggu = reports.filter((r) => r && r.status === 'menunggu').length;
      if (riwayatBadge) {
        if (countMenunggu > 0) {
          riwayatBadge.textContent = String(countMenunggu);
          riwayatBadge.classList.remove('hidden');
        } else {
          riwayatBadge.textContent = '0';
          riwayatBadge.classList.add('hidden');
        }
      }

      // Check for status changes on subsequent loads
      if (previousStatusMap !== null) {
        for (const report of reports) {
          if (!report || !report.id) continue;
          const prevStatus = previousStatusMap.get(report.id);
          if (prevStatus && prevStatus !== report.status) {
            playTwoToneBeep();
            if (typeof navigator !== 'undefined' && typeof navigator.vibrate === 'function') {
              navigator.vibrate(200);
            }
            const kendalaShort = (report.kendala || '').slice(0, 30);
            const info = statusInfo(report) || defaultStatusInfo(report);
            const statusText = info?.text || report.status;
            showToast(`Laporan ${kendalaShort} sekarang ${statusText}`);
          }
        }
      }

      // Update previous status map
      const nextMap = new Map();
      for (const report of reports) {
        if (report && report.id) {
          nextMap.set(report.id, report.status);
        }
      }
      previousStatusMap = nextMap;
    }

    if (riwayatSection) {
      riwayatSection.classList.remove('hidden');
      riwayatSection.hidden = false;
    }

    if (!Array.isArray(reports) || reports.length === 0) {
      if (riwayatList) riwayatList.textContent = '';
      if (riwayatEmpty) riwayatEmpty.hidden = false;
      return;
    }

    if (riwayatEmpty) riwayatEmpty.hidden = true;
    const fragment = document.createDocumentFragment();

    for (const report of reports) {
      const card = document.createElement('div');
      card.className = 'riwayat-card';

      const kendalaEl = document.createElement('p');
      kendalaEl.className = 'riwayat-kendala';
      kendalaEl.textContent = report.kendala || '-';

      const metaEl = document.createElement('div');
      metaEl.className = 'riwayat-meta';

      const tanggalEl = document.createElement('span');
      tanggalEl.className = 'riwayat-tanggal';
      tanggalEl.textContent = formatTanggal(report.tanggal || report.waktu_lapor);

      const info = statusInfo(report) || defaultStatusInfo(report);
      const pillEl = document.createElement('span');
      pillEl.className = `status-pill ${info.cssClass || 'status-menunggu'}`;
      pillEl.textContent = info.text || 'Menunggu';

      metaEl.appendChild(tanggalEl);
      metaEl.appendChild(pillEl);

      card.appendChild(kendalaEl);
      card.appendChild(metaEl);

      const submetaText = riwayatMeta(report);
      if (submetaText) {
        const submetaEl = document.createElement('div');
        submetaEl.className = 'riwayat-submeta';
        submetaEl.textContent = submetaText;
        card.appendChild(submetaEl);
      }

      fragment.appendChild(card);
    }

    if (riwayatList) {
      riwayatList.textContent = '';
      riwayatList.appendChild(fragment);
    }
  } catch {
    // Graceful degradation: silently hide riwayat section if listMyReports throws
    if (riwayatSection) {
      riwayatSection.classList.add('hidden');
      riwayatSection.hidden = true;
    }
  }
}

window.loadRiwayat = loadRiwayat;

function startRiwayatPolling() {
  stopRiwayatPolling();
  loadRiwayat();
  riwayatPollTimer = setInterval(() => {
    loadRiwayat();
  }, 30000);
}

function stopRiwayatPolling() {
  if (riwayatPollTimer) {
    clearInterval(riwayatPollTimer);
    riwayatPollTimer = null;
  }
}

function handleLogout(alertMessage = '') {
  stopRiwayatPolling();
  previousStatusMap = null;
  if (riwayatBadge) {
    riwayatBadge.textContent = '0';
    riwayatBadge.classList.add('hidden');
  }
  if (riwayatList) {
    riwayatList.textContent = '';
  }
  if (riwayatSection) {
    riwayatSection.classList.add('hidden');
    riwayatSection.hidden = true;
  }
  clearSession(localStorage);
  currentSession = null;
  clearPhoto();
  inputPassword.value = '';
  if (alertMessage) {
    loginError.textContent = alertMessage;
    loginError.classList.remove('hidden');
  } else {
    loginError.textContent = '';
    loginError.classList.add('hidden');
  }
  showScreen('l1');
}

// Tab buttons & keyboard navigation
if (tabBtnLaporan) {
  tabBtnLaporan.addEventListener('click', () => switchTab('laporan'));
  tabBtnLaporan.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
      e.preventDefault();
      switchTab('riwayat');
      tabBtnRiwayat?.focus();
    }
  });
}

if (tabBtnRiwayat) {
  tabBtnRiwayat.addEventListener('click', () => switchTab('riwayat'));
  tabBtnRiwayat.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
      e.preventDefault();
      switchTab('laporan');
      tabBtnLaporan?.focus();
    }
  });
}

// Audio unlock on user gesture
btnLogin.addEventListener('click', unlockAudio);
window.addEventListener('click', unlockAudio, { once: true });
window.addEventListener('touchstart', unlockAudio, { once: true });

// Password visibility toggle
btnTogglePw.addEventListener('click', () => {
  const isHidden = inputPassword.type === 'password';
  inputPassword.type = isHidden ? 'text' : 'password';
  btnTogglePw.textContent = isHidden ? 'Sembunyikan' : 'Tampilkan';
  btnTogglePw.setAttribute('aria-pressed', isHidden ? 'true' : 'false');
});

// Login submit
formLogin.addEventListener('submit', async (e) => {
  e.preventDefault();
  loginError.textContent = '';
  loginError.classList.add('hidden');

  const identity = inputUsername.value.trim();
  const password = inputPassword.value;
  if (!identity || !password) {
    loginError.textContent = 'Isi nama pengguna dan kata sandi.';
    loginError.classList.remove('hidden');
    return;
  }

  btnLogin.disabled = true;
  btnLogin.textContent = 'Masuk...';

  try {
    const session = await login(identity, password);
    saveSession(session, localStorage);
    currentSession = session;
    setPosTitle(session);
    initReportForm(true);
    const savedTab = sessionStorage.getItem(ACTIVE_TAB_KEY) || 'laporan';
    switchTab(savedTab);
    showScreen('l2');
    startRiwayatPolling();
  } catch (err) {
    loginError.textContent = err?.message || 'Gagal masuk.';
    loginError.classList.remove('hidden');
  } finally {
    btnLogin.disabled = false;
    btnLogin.textContent = 'Masuk';
  }
});

// Logout buttons
btnLogoutL2.addEventListener('click', () => handleLogout());
btnLogoutL3.addEventListener('click', () => handleLogout());

// Draft persistence on input
formReport.addEventListener('input', () => {
  saveDraft();
});

// Photo and video buttons
btnCamera.addEventListener('click', () => inputCamera.click());
btnVideo.addEventListener('click', () => inputVideo.click());
btnGallery.addEventListener('click', () => inputGallery.click());
inputCamera.addEventListener('change', () => handlePhotoPicked(inputCamera.files?.[0]));
inputVideo.addEventListener('change', () => handlePhotoPicked(inputVideo.files?.[0]));
inputGallery.addEventListener('change', () => handlePhotoPicked(inputGallery.files?.[0]));
btnRemovePhoto.addEventListener('click', () => clearPhoto());

// Submit report
formReport.addEventListener('submit', async (e) => {
  e.preventDefault();
  clearFieldErrors();

  const formPayload = {
    tanggal: inputTanggal.value.trim(),
    waktu: inputWaktu.value.trim(),
    kendala: inputKendala.value.trim(),
    penyebab: inputPenyebab.value.trim(),
    solusi_sementara: inputSolusi.value.trim(),
    durasi_error: inputDurasi.value.trim(),
    ada_foto: Boolean(selectedPhotoFile),
  };

  const check = validate(formPayload);
  if (!check.ok) {
    showFieldError(check.field, check.message);
    return;
  }

  btnSend.disabled = true;
  btnSend.textContent = 'Mengirim...';

  try {
    const res = await sendReport(currentSession?.token, formPayload);
    lastSentMessage = res.message || '';
    clearDraft();

    const cabang = currentSession?.user?.cabang;
    const prefix = cabang ? `Teknisi ${cabang}` : 'Teknisi';
    l3StatusSub.textContent = `${formPayload.waktu} · ${prefix} sudah dapat alarm.`;
    l3Message.textContent = lastSentMessage;
    l3PhotoHint.classList.toggle('hidden', !selectedPhotoFile);

    showScreen('l3');
    loadRiwayat();

    try {
      const shareResult = await shareReport(lastSentMessage, selectedPhotoFile, navigator);
      if (shareResult === 'copied') {
        showToast('Pesan disalin. Tempel di grup Telegram.');
      }
    } catch {
      // If browser rejects share for lost user activation, L3's button covers it
    }
  } catch (err) {
    const msg = err?.message || 'Gagal terkirim. Cek sinyal lalu coba lagi.';
    if (msg.includes('Sesi habis')) {
      handleLogout(msg);
      return;
    }
    showFieldError(null, msg);
  } finally {
    btnSend.disabled = false;
    btnSend.textContent = 'Kirim & bagikan ke grup';
  }
});

// Share again on L3
btnShareAgain.addEventListener('click', async () => {
  if (!lastSentMessage) return;
  try {
    const res = await shareReport(lastSentMessage, selectedPhotoFile, navigator);
    if (res === 'copied') {
      showToast('Pesan disalin. Tempel di grup Telegram.');
    }
  } catch {
    // ignore share errors
  }
});

// Report another: return to L2 on tab Riwayat
btnReportAnother.addEventListener('click', () => {
  lastSentMessage = '';
  initReportForm(false);
  switchTab('riwayat');
  showScreen('l2');
});

// Boot
const saved = loadSession(localStorage);
if (saved && saved.token) {
  currentSession = saved;
  setPosTitle(saved);
  initReportForm(true);
  const savedTab = sessionStorage.getItem(ACTIVE_TAB_KEY) || 'laporan';
  switchTab(savedTab);
  showScreen('l2');
  startRiwayatPolling();
} else {
  showScreen('l1');
}
