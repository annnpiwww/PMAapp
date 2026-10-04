const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const OUT_DIR = '/tmp/bss_preview';
if (!fs.existsSync(OUT_DIR)) {
  fs.mkdirSync(OUT_DIR, { recursive: true });
}

let logoBase64 = '';
const logoPath = path.join(__dirname, '..', 'foto', 'splash_logo.png');
if (fs.existsSync(logoPath)) {
  logoBase64 = `data:image/png;base64,${fs.readFileSync(logoPath).toString('base64')}`;
}

const htmlContent = `<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>BSS Parking TimeMark - Senior UI/UX Audit & Redesign Showcase</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", Roboto, "Plus Jakarta Sans", sans-serif; }
  
  body {
    background: #04070D;
    color: #F8FAFC;
    padding: 30px;
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
    overflow-x: hidden;
  }

  .artboard {
    width: 1540px;
    background: radial-gradient(circle at 5% 5%, #0F172A 0%, #060911 60%, #020408 100%);
    border-radius: 32px;
    border: 1px solid rgba(255, 255, 255, 0.12);
    box-shadow: 0 40px 120px rgba(0, 0, 0, 0.95);
    padding: 36px 42px;
    position: relative;
  }

  /* Decorative Ambient Glow */
  .ambient-glow-1 {
    position: absolute;
    top: -80px;
    left: 20%;
    width: 450px;
    height: 250px;
    background: radial-gradient(circle, rgba(255, 101, 0, 0.12) 0%, transparent 70%);
    filter: blur(50px);
    pointer-events: none;
  }
  .ambient-glow-2 {
    position: absolute;
    top: 150px;
    right: 5%;
    width: 500px;
    height: 300px;
    background: radial-gradient(circle, rgba(37, 99, 235, 0.1) 0%, transparent 70%);
    filter: blur(60px);
    pointer-events: none;
  }

  /* Top Navigation / Brand Header */
  .nav-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
    padding-bottom: 22px;
    margin-bottom: 30px;
    position: relative;
    z-index: 2;
  }
  .brand-block {
    display: flex;
    align-items: center;
    gap: 16px;
  }
  .logo-box {
    width: 52px;
    height: 52px;
    background: #FFFFFF;
    border: 2px solid #FF6500;
    border-radius: 14px;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    box-shadow: 0 8px 24px rgba(255, 101, 0, 0.35);
  }
  .logo-box img {
    width: 44px;
    height: 44px;
    object-fit: contain;
  }
  .brand-text h1 {
    font-size: 23px;
    font-weight: 800;
    letter-spacing: -0.4px;
    color: #FFFFFF;
  }
  .brand-text p {
    font-size: 13px;
    color: #94A3B8;
    margin-top: 3px;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .tag-badge {
    background: rgba(255, 101, 0, 0.15);
    color: #FF8A3D;
    border: 1px solid rgba(255, 101, 0, 0.35);
    padding: 3px 8px;
    border-radius: 6px;
    font-size: 11px;
    font-weight: 700;
  }

  /* Design Standards Chips */
  .standards-chips {
    display: flex;
    gap: 10px;
  }
  .chip {
    padding: 6px 14px;
    border-radius: 999px;
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 0.3px;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .chip-anti-slop {
    background: rgba(16, 185, 129, 0.12);
    border: 1px solid rgba(16, 185, 129, 0.35);
    color: #34D399;
  }
  .chip-impeccable {
    background: rgba(59, 130, 246, 0.12);
    border: 1px solid rgba(59, 130, 246, 0.35);
    color: #60A5FA;
  }
  .chip-tactile {
    background: rgba(245, 158, 11, 0.12);
    border: 1px solid rgba(245, 158, 11, 0.35);
    color: #FBBF24;
  }

  /* 4-Column Showcase Layout */
  .grid-showcase {
    display: grid;
    grid-template-columns: 330px 370px 370px 370px;
    gap: 24px;
    position: relative;
    z-index: 2;
  }

  /* Phone Mockup Wrapper */
  .device-shell {
    background: #0B111E;
    border-radius: 36px;
    border: 2px solid rgba(255, 255, 255, 0.16);
    box-shadow: 0 24px 60px rgba(0, 0, 0, 0.85), inset 0 0 0 1px rgba(255, 255, 255, 0.05);
    overflow: hidden;
    display: flex;
    flex-direction: column;
    height: 670px;
    position: relative;
  }
  .speaker-notch {
    height: 22px;
    background: #030712;
    display: flex;
    justify-content: center;
    align-items: center;
  }
  .speaker-bar {
    width: 50px;
    height: 6px;
    background: #1E293B;
    border-radius: 999px;
  }
  .shell-header {
    background: #141E33;
    padding: 12px 16px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  }
  .shell-title {
    font-size: 13px;
    font-weight: 700;
    color: #FFFFFF;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .shell-badge {
    font-size: 10px;
    font-weight: 700;
    padding: 2px 8px;
    border-radius: 6px;
  }
  .shell-body {
    flex: 1;
    padding: 14px;
    overflow-y: hidden;
    background: #090E1A;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  /* Section Title Bar Inside Phones */
  .step-pill {
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 8px;
    padding: 5px 10px;
    font-size: 11px;
    font-weight: 700;
    color: #CBD5E1;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .step-pill span.num {
    color: #FF6500;
  }

  /* ---------------- SCREEN 1: LOGIN ---------------- */
  .login-card {
    background: #131D31;
    border-radius: 20px;
    border: 1px solid rgba(255, 255, 255, 0.08);
    padding: 20px 16px;
    display: flex;
    flex-direction: column;
    align-items: center;
    margin-top: 10px;
    box-shadow: 0 12px 30px rgba(0, 0, 0, 0.5);
  }
  .login-logo {
    width: 64px;
    height: 64px;
    background: #FFFFFF;
    border: 2px solid #FF6500;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-bottom: 12px;
    box-shadow: 0 0 25px rgba(255, 101, 0, 0.4);
  }
  .login-logo img {
    width: 54px;
    height: 54px;
    object-fit: contain;
  }
  .login-title {
    font-size: 16px;
    font-weight: 800;
    color: #FFFFFF;
  }
  .login-sub {
    font-size: 11px;
    color: #94A3B8;
    margin-top: 2px;
    margin-bottom: 20px;
  }
  .login-field {
    width: 100%;
    margin-bottom: 12px;
  }
  .field-label-clean {
    font-size: 11px;
    font-weight: 600;
    color: #CBD5E1;
    margin-bottom: 6px;
    display: block;
  }
  .field-input-box {
    width: 100%;
    background: #0A0F1D;
    border: 1px solid #334155;
    border-radius: 10px;
    padding: 10px 12px;
    font-size: 12px;
    color: #F8FAFC;
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .field-input-box.focused {
    border-color: #FF6500;
    box-shadow: 0 0 12px rgba(255, 101, 0, 0.25);
  }
  .btn-primary-login {
    width: 100%;
    background: linear-gradient(135deg, #FF6500 0%, #EA580C 100%);
    border: none;
    border-radius: 10px;
    padding: 11px;
    font-size: 12px;
    font-weight: 700;
    color: #FFFFFF;
    margin-top: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    box-shadow: 0 6px 18px rgba(255, 101, 0, 0.35);
  }

  /* ---------------- SCREEN 2: SPV DISPATCHER ---------------- */
  .spv-segmented {
    display: flex;
    background: #0A0F1D;
    border-radius: 10px;
    padding: 3px;
    border: 1px solid rgba(255,255,255,0.08);
  }
  .spv-seg-btn {
    flex: 1;
    padding: 7px;
    font-size: 11px;
    font-weight: 700;
    text-align: center;
    border-radius: 7px;
    color: #94A3B8;
  }
  .spv-seg-btn.active {
    background: #FF6500;
    color: #FFFFFF;
    box-shadow: 0 2px 8px rgba(255, 101, 0, 0.35);
  }
  .chip-group-loc {
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
    margin-top: 4px;
  }
  .chip-loc {
    background: #141E33;
    border: 1px solid rgba(255,255,255,0.12);
    border-radius: 6px;
    padding: 5px 10px;
    font-size: 10px;
    font-weight: 700;
    color: #CBD5E1;
  }
  .chip-loc.selected {
    background: rgba(255, 101, 0, 0.15);
    border-color: #FF6500;
    color: #FF8A3D;
  }
  .spv-input {
    background: #0A0F1D;
    border: 1px solid #334155;
    border-radius: 8px;
    padding: 8px 10px;
    font-size: 11px;
    color: #F8FAFC;
    width: 100%;
  }

  /* ---------------- SCREEN 3: TEKNISI EXECUTION ---------------- */
  .task-exec-header {
    background: #131D31;
    border-radius: 12px;
    padding: 12px;
    border: 1px solid rgba(255, 255, 255, 0.08);
  }
  .task-exec-title {
    font-size: 13px;
    font-weight: 800;
    color: #FFFFFF;
    line-height: 1.3;
  }
  .task-exec-tag {
    display: inline-block;
    background: rgba(255, 101, 0, 0.15);
    color: #FF8A3D;
    font-size: 10px;
    font-weight: 700;
    padding: 2px 8px;
    border-radius: 4px;
    margin-top: 6px;
  }

  .photo-deck {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 8px;
    margin-top: 6px;
  }
  .photo-card {
    height: 90px;
    border-radius: 10px;
    border: 1px solid rgba(255, 255, 255, 0.12);
    position: relative;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    justify-content: flex-end;
    padding: 6px;
    background-size: cover;
    background-position: center;
  }
  .photo-mock-1 {
    background-color: #1E293B;
    background-image: linear-gradient(180deg, rgba(0,0,0,0.1), rgba(0,0,0,0.9));
  }
  .photo-mock-2 {
    background-color: #334155;
    background-image: linear-gradient(180deg, rgba(0,0,0,0.1), rgba(0,0,0,0.9));
  }
  .photo-add-box {
    border: 2px dashed rgba(255, 101, 0, 0.45);
    background: rgba(255, 101, 0, 0.04);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    cursor: pointer;
  }
  .photo-pill-label {
    font-size: 8px;
    font-weight: 800;
    background: #020617;
    color: #FFFFFF;
    padding: 2px 5px;
    border-radius: 4px;
    width: fit-content;
  }
  .photo-wm-sub {
    font-size: 7px;
    color: #E2E8F0;
    margin-top: 2px;
    line-height: 1.1;
  }

  .notes-area {
    width: 100%;
    height: 75px;
    background: #0A0F1D;
    border: 1px solid #334155;
    border-radius: 10px;
    padding: 10px;
    color: #F8FAFC;
    font-size: 11px;
    line-height: 1.4;
    resize: none;
    font-family: inherit;
  }
  .notes-area::placeholder {
    color: #64748B;
  }

  .cta-group {
    display: flex;
    flex-direction: column;
    gap: 8px;
    margin-top: auto;
  }
  .btn-share-tg {
    background: linear-gradient(135deg, #10B981 0%, #059669 100%);
    border: none;
    border-radius: 10px;
    padding: 10px;
    font-size: 11px;
    font-weight: 700;
    color: #FFFFFF;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    box-shadow: 0 4px 14px rgba(16, 185, 129, 0.35);
  }
  .btn-complete-task {
    background: #131D31;
    border: 1px solid rgba(255,255,255,0.14);
    border-radius: 10px;
    padding: 9px;
    font-size: 11px;
    font-weight: 600;
    color: #CBD5E1;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
  }

  /* ---------------- SCREEN 4: CHAT OUTPUT & PULANG ---------------- */
  .chat-container {
    background: #0B111E;
    border-radius: 20px;
    border: 1px solid rgba(255, 255, 255, 0.08);
    padding: 14px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .chat-bubble-clean {
    background: #064E3B;
    border: 1px solid #059669;
    border-radius: 14px 14px 2px 14px;
    padding: 14px;
    color: #F8FAFC;
    font-size: 11px;
    line-height: 1.5;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", monospace;
  }
  .chat-header-row {
    font-size: 11px;
    font-weight: 800;
    color: #6EE7B7;
    border-bottom: 1px dashed rgba(255,255,255,0.2);
    padding-bottom: 6px;
    margin-bottom: 8px;
  }
  .chat-meta-item {
    display: flex;
    gap: 4px;
    margin-bottom: 3px;
  }
  .chat-label {
    color: #A7F3D0;
    font-weight: 600;
    min-width: 68px;
  }
  .chat-val {
    color: #FFFFFF;
  }

  .pulang-sync-card {
    background: #131D31;
    border-radius: 14px;
    border: 1px solid rgba(16, 185, 129, 0.35);
    padding: 12px;
    margin-top: auto;
  }
  .pulang-sync-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 8px;
  }
  .pulang-sync-header h4 {
    font-size: 11px;
    font-weight: 700;
    color: #34D399;
  }
  .pulang-item-row {
    font-size: 10px;
    color: #E2E8F0;
    line-height: 1.4;
    display: flex;
    align-items: flex-start;
    gap: 6px;
    margin-bottom: 4px;
  }

  /* Footer Audit Metrics */
  .audit-footer {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 16px;
    border-top: 1px solid rgba(255, 255, 255, 0.08);
    padding-top: 24px;
    margin-top: 26px;
  }
  .metric-card {
    background: rgba(255, 255, 255, 0.025);
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-radius: 12px;
    padding: 14px;
  }
  .metric-title {
    font-size: 12px;
    font-weight: 700;
    color: #F8FAFC;
    margin-bottom: 4px;
  }
  .metric-desc {
    font-size: 11px;
    color: #94A3B8;
    line-height: 1.4;
  }
</style>
</head>
<body>

<div class="artboard">
  <div class="ambient-glow-1"></div>
  <div class="ambient-glow-2"></div>

  <!-- Header -->
  <div class="nav-header">
    <div class="brand-block">
      <div class="logo-box">
        ${logoBase64 ? `<img src="${logoBase64}" alt="BSS Logo">` : '<span>BSS</span>'}
      </div>
      <div class="brand-text">
        <h1>BSS Parking TimeMark — Senior UI/UX Audit & Production Redesign</h1>
        <p>
          Audit 4 Fitur Kunci Lapangan: Login, Penugasan SPV, Eksekusi Tugas Teknisi & Integrasi Laporan
          <span class="tag-badge">V2.0.50 SPEC</span>
        </p>
      </div>
    </div>
    <div class="standards-chips">
      <div class="chip chip-anti-slop">✓ Anti-AI Slop Standards</div>
      <div class="chip chip-impeccable">✓ Impeccable Design</div>
      <div class="chip chip-tactile">✓ Tactile Micro-Interactions</div>
    </div>
  </div>

  <!-- 4 Phones Layout -->
  <div class="grid-showcase">

    <!-- 1. Form Login -->
    <div class="device-shell">
      <div class="speaker-notch"><div class="speaker-bar"></div></div>
      <div class="shell-header">
        <span class="shell-title">🔐 1. Form Login</span>
        <span class="shell-badge" style="background:rgba(255,101,0,0.15); color:#FF8A3D;">Clean BSS</span>
      </div>
      <div class="shell-body">
        <div class="step-pill"><span class="num">01.</span> Identitas Resmi & Otentikasi</div>
        
        <div class="login-card">
          <div class="login-logo">
            ${logoBase64 ? `<img src="${logoBase64}" alt="BSS Logo">` : '<span>BSS</span>'}
          </div>
          <div class="login-title">BSS TimeMark</div>
          <div class="login-sub">Absensi, Maintenance & Daily Task</div>

          <div class="login-field">
            <span class="field-label-clean">Email atau Username</span>
            <div class="field-input-box focused">
              <span>ryan@bssparking.id</span>
              <span style="color:#FF6500; font-size:12px;">●</span>
            </div>
          </div>

          <div class="login-field">
            <span class="field-label-clean">Kata Sandi</span>
            <div class="field-input-box">
              <span>••••••••••</span>
              <span style="color:#64748B; font-size:11px;">👁</span>
            </div>
          </div>

          <button class="btn-primary-login">
            <span>Masuk ke Sistem</span> ➔
          </button>
        </div>

        <div style="margin-top:auto; font-size:10px; color:#94A3B8; line-height:1.4; padding:10px; background:#131D31; border-radius:10px;">
          💡 <strong>Audit Login:</strong> Hapus testing quick-chips di production. Gunakan persistent label yang tenang, logo resmi BSS berbingkai aksen oranye, dan autofocus state presisi.
        </div>
      </div>
    </div>

    <!-- 2. Form Penugasan SPV -->
    <div class="device-shell">
      <div class="speaker-notch"><div class="speaker-bar"></div></div>
      <div class="shell-header">
        <span class="shell-title">📋 2. Penugasan SPV</span>
        <span class="shell-badge" style="background:rgba(59,130,246,0.15); color:#60A5FA;">SPV Role</span>
      </div>
      <div class="shell-body">
        <div class="step-pill"><span class="num">02.</span> Input Tugas Cepat & Tepat</div>

        <!-- Segmented Control Kategori -->
        <div class="spv-segmented">
          <div class="spv-seg-btn active">Tugas Khusus</div>
          <div class="spv-seg-btn">Maintenance SOP</div>
        </div>

        <!-- Pilih Teknisi -->
        <div>
          <span class="field-label-clean">Pilih Teknisi</span>
          <div class="field-input-box">
            <span>Ryan Lumasuge</span>
            <span style="color:#94A3B8;">▾</span>
          </div>
        </div>

        <!-- Pilih Singkatan Lokasi (Chips Cepat) -->
        <div>
          <span class="field-label-clean">Singkatan Lokasi</span>
          <div class="chip-group-loc">
            <div class="chip-loc selected">TBM</div>
            <div class="chip-loc">MTC</div>
            <div class="chip-loc">Mantos</div>
            <div class="chip-loc">Megamas</div>
            <div class="chip-loc">+ Lainnya</div>
          </div>
        </div>

        <!-- Judul Tugas -->
        <div>
          <span class="field-label-clean">Pekerjaan</span>
          <div class="spv-input">Pengecatan markah panah lokasi TBM</div>
        </div>

        <button class="btn-primary-login" style="margin-top:auto; background:linear-gradient(135deg, #2563EB, #1D4ED8);">
          <span>Kirim Tugas ke Teknisi</span> ➔
        </button>
      </div>
    </div>

    <!-- 3. Eksekusi Tugas Teknisi -->
    <div class="device-shell">
      <div class="speaker-notch"><div class="speaker-bar"></div></div>
      <div class="shell-header">
        <span class="shell-title">⚡ 3. Kerjakan Tugas</span>
        <span class="shell-badge" style="background:rgba(245,158,11,0.15); color:#FBBF24;">Teknisi</span>
      </div>
      <div class="shell-body">
        <div class="step-pill"><span class="num">03.</span> Multi-Foto Fleksibel & Catatan</div>

        <div class="task-exec-header">
          <div class="task-exec-title">Pengecatan markah panah lokasi TBM</div>
          <div class="task-exec-tag">Lokasi: TBM</div>
        </div>

        <!-- Multi Photo Grid -->
        <div>
          <span class="field-label-clean">Foto Dokumentasi (Bebas Jumlah)</span>
          <div class="photo-deck">
            <div class="photo-card photo-mock-1">
              <span class="photo-pill-label">Foto 1 (Awal)</span>
              <span class="photo-wm-sub">04/10 11:20 WITA</span>
            </div>
            <div class="photo-card photo-mock-2">
              <span class="photo-pill-label">Foto 2 (Selesai)</span>
              <span class="photo-wm-sub">04/10 13:45 WITA</span>
            </div>
            <div class="photo-card photo-add-box">
              <span style="font-size:18px; color:#FF6500; font-weight:800;">+</span>
              <span style="font-size:9px; color:#FF6500; font-weight:700;">Tambah</span>
            </div>
          </div>
        </div>

        <!-- Catatan Bersih -->
        <div>
          <span class="field-label-clean">Catatan</span>
          <textarea class="notes-area" placeholder="Catatan Laporan"></textarea>
        </div>

        <div class="cta-group">
          <button class="btn-share-tg">
            <span>📲</span> Kirim ke WA / Telegram
          </button>
          <button class="btn-complete-task">
            <span>💾</span> Selesai & Simpan
          </button>
        </div>
      </div>
    </div>

    <!-- 4. Laporan WA/Telegram & Auto Pulang -->
    <div class="device-shell">
      <div class="speaker-notch"><div class="speaker-bar"></div></div>
      <div class="shell-header">
        <span class="shell-title">📲 4. Output & Sinkronisasi</span>
        <span class="shell-badge" style="background:rgba(16,185,129,0.15); color:#34D399;">Real-Time</span>
      </div>
      <div class="shell-body">
        <div class="step-pill"><span class="num">04.</span> Format Bersih & Auto-Trigger</div>

        <!-- Output Chat Bersih -->
        <div class="chat-container">
          <div class="chat-bubble-clean">
            <div class="chat-header-row">Laporan Daily Hari ini</div>
            <div class="chat-meta-item"><span class="chat-label">Teknisi</span>: <span class="chat-val">Ryan</span></div>
            <div class="chat-meta-item"><span class="chat-label">Tanggal</span>: <span class="chat-val">04 Oktober 2026</span></div>
            <div class="chat-meta-item"><span class="chat-label">Lokasi</span>: <span class="chat-val">TBM</span></div>
            <div class="chat-meta-item"><span class="chat-label">Pekerjaan</span>: <span class="chat-val">Pengecatan markah panah lokasi TBM</span></div>
            <div class="chat-meta-item"><span class="chat-label">Status</span>: <span class="chat-val">Selesai (13:45)</span></div>
            <div style="border-top: 1px dashed rgba(255,255,255,0.2); margin: 6px 0;"></div>
            <div style="font-weight:700; color:#A7F3D0; margin-bottom:2px;">Catatan :</div>
            <div style="font-style:italic; color:#F8FAFC;">"Pengecatan markah selesai, cat kering siap dilalui kendaraan"</div>
          </div>
        </div>

        <!-- Auto Trigger di UI Pulang -->
        <div class="pulang-sync-card">
          <div class="pulang-sync-header">
            <h4>✓ Otomatis Masuk UI Pulang</h4>
            <span style="font-size:9px; color:#10B981; font-weight:700;">Zero Duplicate</span>
          </div>
          <div class="pulang-item-row">
            <span style="color:#10B981; font-weight:900;">✓</span>
            <span>Pengecatan markah panah lokasi TBM (13:45)</span>
          </div>
          <div class="pulang-item-row">
            <span style="color:#10B981; font-weight:900;">✓</span>
            <span>Maintenance mingguan: Pembersihan manless (15:30)</span>
          </div>
          <div style="font-size:9px; color:#94A3B8; margin-top:6px;">
            * Saat jadwal shift pulang tiba, teknisi cukup buka menu pulang seperti biasa. Seluruh daftar tugas yang selesai sudah otomatis terisi centang hijau.
          </div>
        </div>
      </div>
    </div>

  </div>

  <!-- Bottom Senior UX Metrics -->
  <div class="audit-footer">
    <div class="metric-card">
      <div class="metric-title">1. Visual Tactile & Anti-AI Slop</div>
      <div class="metric-desc">Palet warna resmi BSS Dark Slate (#04070D & #131D31) dengan aksen Amber (#FF6500) yang tegas, kontras tinggi, dan tanpa gradien ungu murah.</div>
    </div>
    <div class="metric-card">
      <div class="metric-title">2. Zero Cognitive Load SPV</div>
      <div class="metric-desc">SPV cukup tap chip singkatan lokasi (TBM, MTC, dsb) tanpa harus ngetik panjang nama pos yang sering keliru di database.</div>
    </div>
    <div class="metric-card">
      <div class="metric-title">3. Dynamic Photographic Grid</div>
      <div class="metric-desc">Bebas kuota foto kaku. Teknisi bisa dokumentasikan 1, 2, 3, hingga 5 foto ber-watermark resmi sesuai kompleksitas pekerjaan.</div>
    </div>
    <div class="metric-card">
      <div class="metric-title">4. Concise WhatsApp / Telegram</div>
      <div class="metric-desc">Format pesan teks to-the-point langsung mengarah pada esensi: Siapa, Kapan, Di Mana, Apa yang dikerjakan, dan Catatan ringkas.</div>
    </div>
  </div>

</div>

</body>
</html>
`;

const htmlPath = path.join(OUT_DIR, 'senior_ui_audit_showcase.html');
const pngPath = path.join(OUT_DIR, 'BSS-TimeMark-Senior-UI-UX-Audit-Showcase.png');
const repoPngPath = path.join(__dirname, '..', 'BSS-TimeMark-Senior-UI-UX-Audit-Showcase.png');

fs.writeFileSync(htmlPath, htmlContent, 'utf8');

try {
  execSync(
    `google-chrome-stable --headless=new --disable-gpu --no-sandbox --hide-scrollbars --screenshot="${pngPath}" --window-size=1580,980 "file://${htmlPath}"`,
    { stdio: 'inherit' }
  );
  fs.copyFileSync(pngPath, repoPngPath);
  console.log(`[Senior Showcase Generated] Saved to ${pngPath} and ${repoPngPath}`);
  console.log(`File size: ${fs.statSync(repoPngPath).size} bytes`);
} catch (err) {
  console.error('[Senior Showcase Error]', err.message);
  process.exit(1);
}
