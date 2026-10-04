const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const OUT_DIR = '/home/annnpii/Product development annpii/BssparkingTimeMark';
const splashLogoPath = path.join(__dirname, '..', 'foto', 'splash_logo.png');
const bssTransparentPath = path.join(__dirname, '..', 'foto', 'bssfotologo_transparent.png');

let splashLogoBase64 = '';
if (fs.existsSync(splashLogoPath)) {
  splashLogoBase64 = `data:image/png;base64,${fs.readFileSync(splashLogoPath).toString('base64')}`;
}

let bssTransparentBase64 = '';
if (fs.existsSync(bssTransparentPath)) {
  bssTransparentBase64 = `data:image/png;base64,${fs.readFileSync(bssTransparentPath).toString('base64')}`;
}

const htmlContent = `<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>PMA App - Visual Rebranding Phase 1 Showcase</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Plus Jakarta Sans", sans-serif; }
  
  body {
    background: #050811;
    color: #F8FAFC;
    padding: 30px;
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
  }

  .canvas {
    width: 1440px;
    background: #0B1120;
    border-radius: 24px;
    border: 1px solid #1E293B;
    box-shadow: 0 30px 80px rgba(0, 0, 0, 0.85);
    padding: 32px 36px;
  }

  /* Header Section */
  .header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px solid #1E293B;
    padding-bottom: 20px;
    margin-bottom: 28px;
  }

  .brand-badge-box {
    display: flex;
    align-items: center;
    gap: 16px;
  }

  .pma-logo-box {
    width: 48px;
    height: 48px;
    background: #111827;
    border: 2px solid #FF6500;
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 900;
    color: #FF6500;
    font-size: 18px;
    letter-spacing: 1px;
  }

  .title-meta h1 {
    font-size: 20px;
    font-weight: 800;
    color: #FFFFFF;
    letter-spacing: 0.5px;
  }

  .title-meta p {
    font-size: 13px;
    color: #94A3B8;
    margin-top: 3px;
  }

  .status-tag {
    background: #064E3B;
    border: 1px solid #10B981;
    color: #A7F3D0;
    padding: 6px 14px;
    border-radius: 20px;
    font-size: 12px;
    font-weight: 700;
  }

  /* Screen Grid */
  .grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 32px;
  }

  .screen-col {
    display: flex;
    flex-direction: column;
    align-items: center;
  }

  .screen-label {
    margin-bottom: 14px;
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .screen-label span.num {
    background: #FF6500;
    color: #FFF;
    width: 22px;
    height: 22px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 12px;
    font-weight: bold;
  }

  .screen-label h3 {
    font-size: 14px;
    font-weight: 700;
    color: #E2E8F0;
  }

  /* Phone Mockup Frame */
  .phone-frame {
    width: 360px;
    height: 720px;
    background: #0F172A;
    border-radius: 40px;
    border: 4px solid #334155;
    box-shadow: 0 20px 50px rgba(0, 0, 0, 0.7);
    overflow: hidden;
    position: relative;
    display: flex;
    flex-direction: column;
  }

  /* Status Bar */
  .status-bar {
    height: 32px;
    padding: 0 24px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 11px;
    font-weight: 600;
    color: #94A3B8;
    z-index: 10;
  }

  /* SCREEN 1: SPLASH SCREEN */
  .splash-container {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: space-between;
    padding: 40px 24px 32px;
    position: relative;
  }

  .splash-center {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    margin-top: 100px;
  }

  .splash-logo-circle {
    width: 110px;
    height: 110px;
    border-radius: 50%;
    background: #FFFFFF;
    border: 3px solid #FF6500;
    box-shadow: 0 0 35px rgba(255, 101, 0, 0.45);
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    margin-bottom: 24px;
  }

  .splash-logo-circle img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .pma-title {
    font-size: 32px;
    font-weight: 900;
    color: #FFFFFF;
    letter-spacing: 3px;
    margin-bottom: 6px;
  }

  .pma-tagline {
    font-size: 14px;
    font-weight: 700;
    color: #FF6500;
    letter-spacing: 0.8px;
    margin-bottom: 6px;
  }

  .pma-subtagline {
    font-size: 11.5px;
    color: #94A3B8;
    max-width: 240px;
    line-height: 1.4;
  }

  .splash-footer {
    width: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
  }

  .progress-track {
    width: 180px;
    height: 4px;
    background: #1E293B;
    border-radius: 2px;
    overflow: hidden;
  }

  .progress-fill {
    width: 65%;
    height: 100%;
    background: #FF6500;
    box-shadow: 0 0 8px #FF6500;
  }

  .status-text {
    font-size: 11px;
    color: #64748B;
    font-weight: 600;
  }

  /* SCREEN 2: SIDEBAR DRAWER (REBRANDED) */
  .drawer-screen {
    flex: 1;
    background: #FFFFFF;
    display: flex;
    flex-direction: column;
  }

  .drawer-header {
    background: #1E448D;
    padding: 46px 20px 24px;
    border-bottom: 3px solid #FF6500;
    display: flex;
    justify-content: center;
    align-items: center;
  }

  .drawer-header img {
    height: 44px;
    object-fit: contain;
  }

  .drawer-content {
    flex: 1;
    padding: 16px 12px;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .menu-item {
    display: flex;
    align-items: center;
    padding: 12px 14px;
    border-radius: 12px;
    gap: 14px;
    transition: 0.2s;
  }

  .menu-item.active {
    background: #FFF7ED;
  }

  .menu-icon {
    width: 38px;
    height: 38px;
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 18px;
  }

  .icon-orange {
    background: rgba(255, 101, 0, 0.15);
    color: #FF6500;
  }

  .icon-blue {
    background: rgba(30, 68, 141, 0.12);
    color: #1E448D;
  }

  .icon-sky {
    background: rgba(2, 132, 199, 0.12);
    color: #0284C7;
  }

  .menu-info {
    flex: 1;
  }

  .menu-title-row {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .menu-title {
    font-size: 13.5px;
    font-weight: 700;
    color: #0F172A;
  }

  .spv-pill {
    background: #FF6500;
    color: #FFFFFF;
    font-size: 9px;
    font-weight: 800;
    padding: 1px 6px;
    border-radius: 4px;
  }

  .menu-subtitle {
    font-size: 11px;
    color: #64748B;
    margin-top: 2px;
  }

  .badge-count {
    background: #E0F2FE;
    color: #0369A1;
    font-size: 10px;
    font-weight: 800;
    padding: 3px 8px;
    border-radius: 10px;
    border: 1px solid #BAE6FD;
  }

  .divider {
    height: 1px;
    background: #E2E8F0;
    margin: 12px 6px;
  }

  /* Account Card */
  .account-row {
    display: flex;
    align-items: center;
    padding: 10px 14px;
    border-radius: 12px;
    gap: 12px;
    background: #F8FAFC;
    border: 1px solid #E2E8F0;
  }

  .account-avatar {
    width: 38px;
    height: 38px;
    border-radius: 50%;
    background: rgba(255, 101, 0, 0.2);
    color: #FF6500;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 800;
    font-size: 16px;
  }

  .account-info {
    flex: 1;
  }

  .account-name {
    font-size: 13.5px;
    font-weight: 700;
    color: #0F172A;
  }

  .account-role {
    font-size: 11px;
    font-weight: 600;
    color: #64748B;
  }

  .logout-btn {
    color: #EF4444;
    font-size: 18px;
    padding: 4px;
    cursor: pointer;
  }

  /* Footer Drawer */
  .drawer-footer {
    padding: 14px;
    text-align: center;
    border-top: 1px solid #F1F5F9;
  }

  .footer-brand {
    font-size: 11.5px;
    font-weight: 700;
    color: #1E448D;
  }

  .footer-sub {
    font-size: 10px;
    color: #94A3B8;
    margin-top: 2px;
  }

  /* SCREEN 3: MODAL KONFIRMASI LOGOUT */
  .modal-screen {
    flex: 1;
    background: rgba(15, 23, 42, 0.75);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 24px;
  }

  .dialog-box {
    background: #FFFFFF;
    width: 100%;
    border-radius: 18px;
    padding: 22px 20px;
    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.4);
    border: 1px solid #E2E8F0;
  }

  .dialog-header {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 12px;
  }

  .dialog-icon {
    width: 32px;
    height: 32px;
    border-radius: 8px;
    background: #FEE2E2;
    color: #EF4444;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 16px;
  }

  .dialog-title {
    font-size: 16px;
    font-weight: 800;
    color: #0F172A;
  }

  .dialog-body {
    font-size: 13px;
    color: #475569;
    line-height: 1.5;
    margin-bottom: 22px;
  }

  .dialog-actions {
    display: flex;
    justify-content: flex-end;
    gap: 10px;
  }

  .btn-cancel {
    padding: 9px 16px;
    border-radius: 8px;
    background: transparent;
    color: #64748B;
    font-size: 12.5px;
    font-weight: 700;
    border: none;
  }

  .btn-logout {
    padding: 9px 20px;
    border-radius: 8px;
    background: #EF4444;
    color: #FFFFFF;
    font-size: 12.5px;
    font-weight: 700;
    border: none;
    box-shadow: 0 4px 12px rgba(239, 68, 68, 0.35);
  }

</style>
</head>
<body>

<div class="canvas">
  <!-- Top Bar -->
  <div class="header">
    <div class="brand-badge-box">
      <div class="pma-logo-box">PMA</div>
      <div class="title-meta">
        <h1>PMA App — Project Maintenance Assembly</h1>
        <p>Preview Visual Rebranding: Splash Screen, Clean Sidebar Drawer & Guard Keluar Akun</p>
      </div>
    </div>
    <div class="status-tag">STATUS: 100% IMPLEMENTED IN CODE</div>
  </div>

  <!-- 3 Phones Display -->
  <div class="grid">
    
    <!-- Phone 1: Splash Screen -->
    <div class="screen-col">
      <div class="screen-label">
        <span class="num">1</span>
        <h3>Loading / Splash Screen</h3>
      </div>
      <div class="phone-frame">
        <div class="status-bar">
          <span>11:58</span>
          <span>4G LTE • 95%</span>
        </div>
        <div class="splash-container">
          <div class="splash-center">
            <div class="splash-logo-circle">
              <img src="${splashLogoBase64}" alt="PMA Logo">
            </div>
            <div class="pma-title">PMA</div>
            <div class="pma-tagline">Project Maintenance Assembly</div>
            <div class="pma-subtagline">Technician Maintenance, Grooming & Daily task</div>
          </div>
          <div class="splash-footer">
            <div class="progress-track">
              <div class="progress-fill"></div>
            </div>
            <div class="status-text">Sinkronisasi koordinat GPS & waktu WITA...</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Phone 2: Clean Sidebar Drawer -->
    <div class="screen-col">
      <div class="screen-label">
        <span class="num">2</span>
        <h3>Sidebar Drawer Khusus Teknisi</h3>
      </div>
      <div class="phone-frame">
        <div class="status-bar" style="background:#1E448D; color:rgba(255,255,255,0.7);">
          <span>11:58</span>
          <span>4G LTE • 95%</span>
        </div>
        <div class="drawer-screen">
          <!-- Header Logo Transparan murni di atas Biru BSS tanpa Tombol Close & tanpa Kotak Dalam -->
          <div class="drawer-header">
            <img src="${bssTransparentBase64}" alt="BSS Parking Logo">
          </div>

          <div class="drawer-content">
            <!-- Penugasan Teknisi SPV -->
            <div class="menu-item">
              <div class="menu-icon icon-orange">📋</div>
              <div class="menu-info">
                <div class="menu-title-row">
                  <div class="menu-title">Penugasan Teknisi</div>
                  <span class="spv-pill">SPV</span>
                </div>
                <div class="menu-subtitle">Buat tugas & pantau progres teknisi</div>
              </div>
            </div>

            <!-- Daily Task (Eks Tugas Saya Hari Ini) -->
            <div class="menu-item active">
              <div class="menu-icon icon-orange">⚡</div>
              <div class="menu-info">
                <div class="menu-title" style="color:#C2410C;">Daily Task</div>
                <div class="menu-subtitle">List daily yang harus dikerjakan</div>
              </div>
            </div>

            <!-- Riwayat Maintenance -->
            <div class="menu-item">
              <div class="menu-icon icon-blue">🔧</div>
              <div class="menu-info">
                <div class="menu-title">Riwayat Maintenance</div>
                <div class="menu-subtitle">Daftar checklist unit pos/server</div>
              </div>
            </div>

            <!-- Arsip Kehadiran -->
            <div class="menu-item">
              <div class="menu-icon icon-sky">📁</div>
              <div class="menu-info">
                <div class="menu-title">Arsip Kehadiran</div>
                <div class="menu-subtitle">Catatan absensi 30 hari terakhir</div>
              </div>
              <span class="badge-count">30 Hari</span>
            </div>

            <div class="divider"></div>

            <!-- Profil Akun IT Support KC BSG -->
            <div class="account-row">
              <div class="account-avatar">R</div>
              <div class="account-info">
                <div class="account-name">Ryan Lumasuge</div>
                <div class="account-role">IT Support KC BSG</div>
              </div>
              <div class="logout-btn" title="Keluar Akun">🚪</div>
            </div>
          </div>

          <!-- Bottom Footer -->
          <div class="drawer-footer">
            <div class="footer-brand">PMA App ❤️ Made by annnpii</div>
            <div class="footer-sub">Project Maintenance Assembly</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Phone 3: Logout Guard Modal -->
    <div class="screen-col">
      <div class="screen-label">
        <span class="num">3</span>
        <h3>Modal Konfirmasi Keluar Akun</h3>
      </div>
      <div class="phone-frame">
        <div class="status-bar" style="background:#0F172A; color:rgba(255,255,255,0.7);">
          <span>11:58</span>
          <span>4G LTE • 95%</span>
        </div>
        <div class="modal-screen">
          <div class="dialog-box">
            <div class="dialog-header">
              <div class="dialog-icon">⚠️</div>
              <div class="dialog-title">Keluar Akun</div>
            </div>
            <div class="dialog-body">
              Apakah Anda yakin ingin keluar dari akun ini? Sesi kerja Anda akan diakhiri.
            </div>
            <div class="dialog-actions">
              <button class="btn-cancel">Batal</button>
              <button class="btn-logout">Keluar</button>
            </div>
          </div>
        </div>
      </div>
    </div>

  </div>
</div>

</body>
</html>
`;

const htmlPath = path.join(OUT_DIR, 'PMA-App-Rebranding-Showcase.html');
fs.writeFileSync(htmlPath, htmlContent);

const outPngPath = path.join(OUT_DIR, 'PMA-App-Rebranding-Visual-Showcase.png');
try {
  execSync(`google-chrome-stable --headless --disable-gpu --screenshot="${outPngPath}" --window-size=1540,920 "${htmlPath}"`, { stdio: 'inherit' });
  console.log('SUCCESS: Rendered to ' + outPngPath);
} catch (e) {
  try {
    execSync(`chromium --headless --disable-gpu --screenshot="${outPngPath}" --window-size=1540,920 "${htmlPath}"`, { stdio: 'inherit' });
    console.log('SUCCESS: Rendered to ' + outPngPath);
  } catch (err) {
    console.error('Failed to render screenshot with chrome/chromium', err);
  }
}
