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
<title>PMA App - White-Navy-Orange Theme Showcase</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Plus Jakarta Sans", sans-serif; }
  
  body {
    background: #090E17;
    color: #F8FAFC;
    padding: 30px;
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
  }

  .canvas {
    width: 1440px;
    background: #0F172A;
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
    background: #FFFFFF;
    border: 2px solid #FF6500;
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 900;
    color: #1E448D;
    font-size: 18px;
    letter-spacing: 1px;
    box-shadow: 0 4px 14px rgba(255, 101, 0, 0.25);
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

  .theme-badge {
    background: #FFFFFF;
    border: 1.5px solid #FF6500;
    color: #1E448D;
    padding: 6px 14px;
    border-radius: 20px;
    font-size: 12px;
    font-weight: 800;
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .theme-badge span.dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #FF6500;
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
    background: #FFFFFF;
    border-radius: 40px;
    border: 4px solid #CBD5E1;
    box-shadow: 0 20px 50px rgba(0, 0, 0, 0.6);
    overflow: hidden;
    position: relative;
    display: flex;
    flex-direction: column;
  }

  /* Status Bar */
  .status-bar-light {
    height: 32px;
    padding: 0 24px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 11px;
    font-weight: 700;
    color: #1E293B;
    background: transparent;
    z-index: 10;
  }

  /* SCREEN 1: SPLASH SCREEN (WHITE DOMINANT + NAVY + ORANGE) */
  .splash-white-container {
    flex: 1;
    background: radial-gradient(circle at 50% 20%, #FFFFFF 0%, #F8FAFC 100%);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: space-between;
    padding: 36px 20px 32px;
    position: relative;
  }

  .splash-white-center {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    margin-top: 100px;
    width: 100%;
  }

  .splash-logo-clean {
    width: 112px;
    height: 112px;
    border-radius: 50%;
    background: #FFFFFF;
    border: 3.5px solid #1E448D;
    box-shadow: 0 10px 25px rgba(30, 68, 141, 0.18), 0 0 0 4px rgba(255, 101, 0, 0.25);
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    margin-bottom: 24px;
  }

  .splash-logo-clean img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .splash-brand-pma {
    font-size: 34px;
    font-weight: 900;
    color: #1E448D;
    letter-spacing: 3px;
    margin-bottom: 4px;
  }

  .splash-tagline-orange {
    font-size: 13.5px;
    font-weight: 800;
    color: #FF6500;
    letter-spacing: 0.6px;
    margin-bottom: 8px;
  }

  /* 1 BARIS MUTLAK TANPA PATAH */
  .splash-subtagline-single-line {
    font-size: 11px;
    font-weight: 600;
    color: #475569;
    white-space: nowrap;
    letter-spacing: 0.2px;
    display: inline-block;
  }

  .splash-white-footer {
    width: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
  }

  .progress-track-light {
    width: 190px;
    height: 5px;
    background: #E2E8F0;
    border-radius: 3px;
    overflow: hidden;
  }

  .progress-fill-light {
    width: 70%;
    height: 100%;
    background: #FF6500;
    border-radius: 3px;
  }

  .status-text-light {
    font-size: 11px;
    color: #64748B;
    font-weight: 600;
  }

  /* SCREEN 2: UI CAMERA (WHITE + NAVY + ORANGE HUD) */
  .camera-view-container {
    flex: 1;
    background: #0B1120;
    display: flex;
    flex-direction: column;
    position: relative;
  }

  /* Top Bar (Clean White Card Style) */
  .camera-top-bar {
    background: #FFFFFF;
    padding: 10px 14px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1.5px solid #E2E8F0;
    z-index: 10;
  }

  .top-left-group {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .btn-round-white {
    width: 36px;
    height: 36px;
    border-radius: 50%;
    background: #F1F5F9;
    border: 1px solid #CBD5E1;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 18px;
    color: #1E448D;
  }

  .ratio-pill-white {
    background: #F8FAFC;
    border: 1px solid #CBD5E1;
    color: #1E448D;
    font-size: 11.5px;
    font-weight: 700;
    padding: 6px 12px;
    border-radius: 18px;
  }

  .loc-badge-clean {
    background: #FFF7ED;
    border: 1px solid #FDBA74;
    color: #C2410C;
    font-size: 11px;
    font-weight: 800;
    padding: 5px 10px;
    border-radius: 8px;
  }

  /* Viewfinder Area */
  .viewfinder-mock {
    flex: 1;
    background: #111827;
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
  }

  .simulated-lens {
    width: 100%;
    height: 100%;
    background: radial-gradient(circle at 50% 50%, #1E293B 0%, #0F172A 100%);
    display: flex;
    align-items: center;
    justify-content: center;
    position: relative;
  }

  .focus-crosshair {
    width: 60px;
    height: 60px;
    border: 1.5px solid #FF6500;
    border-radius: 8px;
    opacity: 0.8;
  }

  /* Watermark Card (Clean White on Viewfinder) */
  .wm-card-bottom {
    position: absolute;
    bottom: 12px;
    left: 12px;
    right: 12px;
    background: rgba(255, 255, 255, 0.96);
    backdrop-filter: blur(10px);
    border-radius: 12px;
    padding: 10px 12px;
    box-shadow: 0 8px 24px rgba(0,0,0,0.3);
    border-left: 4px solid #FF6500;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .wm-left h4 {
    font-size: 12px;
    font-weight: 800;
    color: #1E448D;
  }

  .wm-left p {
    font-size: 10px;
    color: #475569;
    margin-top: 2px;
  }

  .wm-right {
    text-align: right;
  }

  .wm-time {
    font-size: 12px;
    font-weight: 800;
    color: #FF6500;
  }

  .wm-date {
    font-size: 9.5px;
    color: #64748B;
  }

  /* Bottom Controls (Clean White Studio Deck) */
  .camera-bottom-deck {
    background: #FFFFFF;
    padding: 14px 20px 18px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-top: 1.5px solid #E2E8F0;
  }

  .btn-deck-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    color: #1E448D;
    font-size: 10px;
    font-weight: 700;
  }

  .deck-icon-circle {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    background: #F1F5F9;
    border: 1px solid #CBD5E1;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 18px;
  }

  /* Shutter Button (BSS Orange Power Core) */
  .shutter-outer {
    width: 68px;
    height: 68px;
    border-radius: 50%;
    background: #FFF;
    border: 3.5px solid #1E448D;
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: 0 4px 14px rgba(30, 68, 141, 0.25);
  }

  .shutter-inner {
    width: 52px;
    height: 52px;
    border-radius: 50%;
    background: #FF6500;
    box-shadow: 0 0 12px rgba(255, 101, 0, 0.5);
  }

  /* SCREEN 3: SIDEBAR DRAWER (MATCHING THEME) */
  .drawer-white-screen {
    flex: 1;
    background: #FFFFFF;
    display: flex;
    flex-direction: column;
  }

  .drawer-white-header {
    background: #1E448D;
    padding: 46px 20px 24px;
    border-bottom: 3.5px solid #FF6500;
    display: flex;
    justify-content: center;
    align-items: center;
  }

  .drawer-white-header img {
    height: 44px;
    object-fit: contain;
  }

  .drawer-white-content {
    flex: 1;
    padding: 16px 12px;
    display: flex;
    flex-direction: column;
    gap: 6px;
    background: #FFFFFF;
  }

  .menu-clean-card {
    display: flex;
    align-items: center;
    padding: 12px 14px;
    border-radius: 12px;
    gap: 14px;
    background: #FFFFFF;
    border: 1px solid transparent;
  }

  .menu-clean-card.active {
    background: #FFF7ED;
    border-color: #FED7AA;
  }

  .menu-clean-card.active .m-title {
    color: #C2410C;
    font-weight: 800;
  }

  .m-icon {
    width: 38px;
    height: 38px;
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 18px;
  }

  .icon-org { background: #FFEDD5; color: #EA580C; }
  .icon-nv { background: #E0E7FF; color: #1E448D; }
  .icon-sk { background: #E0F2FE; color: #0284C7; }

  .m-text { flex: 1; }
  .m-title-row { display: flex; align-items: center; gap: 6px; }
  .m-title { font-size: 13.5px; font-weight: 700; color: #0F172A; }
  .m-sub { font-size: 11px; color: #64748B; margin-top: 2px; }

  .tag-spv {
    background: #FF6500;
    color: #FFFFFF;
    font-size: 9px;
    font-weight: 800;
    padding: 2px 6px;
    border-radius: 4px;
  }

  .tag-count {
    background: #EFF6FF;
    color: #1E448D;
    font-size: 10px;
    font-weight: 800;
    padding: 3px 8px;
    border-radius: 10px;
    border: 1px solid #BFDBFE;
  }

  .user-box-clean {
    display: flex;
    align-items: center;
    padding: 12px 14px;
    border-radius: 12px;
    gap: 12px;
    background: #F8FAFC;
    border: 1px solid #E2E8F0;
    margin-top: 10px;
  }

  .user-avatar-clean {
    width: 38px;
    height: 38px;
    border-radius: 50%;
    background: #1E448D;
    color: #FFFFFF;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 800;
    font-size: 15px;
  }

  .user-role-clean {
    font-size: 11px;
    font-weight: 700;
    color: #FF6500;
  }

  .drawer-white-footer {
    padding: 14px;
    text-align: center;
    border-top: 1px solid #E2E8F0;
    background: #F8FAFC;
  }

  .footer-t1 { font-size: 11.5px; font-weight: 800; color: #1E448D; }
  .footer-t2 { font-size: 10px; color: #64748B; margin-top: 2px; }

</style>
</head>
<body>

<div class="canvas">
  <!-- Top Bar -->
  <div class="header">
    <div class="brand-badge-box">
      <div class="pma-logo-box">PMA</div>
      <div class="title-meta">
        <h1>PMA App — Modern Clean Theme (White + Navy + Orange)</h1>
        <p>Solusi Tagline 1 Baris Utuh & Palet Warna Bersih Sesuai Arahan Lapangan</p>
      </div>
    </div>
    <div class="theme-badge">
      <span class="dot"></span>
      PALETTE: WHITE #FFF • NAVY #1E448D • ORANGE #FF6500
    </div>
  </div>

  <!-- 3 Phones Display -->
  <div class="grid">
    
    <!-- Phone 1: Loading Screen (White Dominant) -->
    <div class="screen-col">
      <div class="screen-label">
        <span class="num">1</span>
        <h3>Loading Screen (Tagline 1 Baris)</h3>
      </div>
      <div class="phone-frame">
        <div class="status-bar-light">
          <span>12:20</span>
          <span>4G LTE • 95%</span>
        </div>
        <div class="splash-white-container">
          <div class="splash-white-center">
            <div class="splash-logo-clean">
              <img src="${splashLogoBase64}" alt="PMA Logo">
            </div>
            <div class="splash-brand-pma">PMA</div>
            <div class="splash-tagline-orange">Project Maintenance Assembly</div>
            <!-- INI DIA: 1 BARIS UTUH TANPA PATAH -->
            <div class="splash-subtagline-single-line">Technician Maintenance, Grooming &amp; Daily Task</div>
          </div>
          <div class="splash-white-footer">
            <div class="progress-track-light">
              <div class="progress-fill-light"></div>
            </div>
            <div class="status-text-light">Sinkronisasi koordinat GPS &amp; waktu WITA...</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Phone 2: Clean Studio Camera HUD -->
    <div class="screen-col">
      <div class="screen-label">
        <span class="num">2</span>
        <h3>Camera HUD (White Deck + Navy + Orange)</h3>
      </div>
      <div class="phone-frame">
        <div class="status-bar-light" style="background:#FFFFFF;">
          <span>12:20</span>
          <span>4G LTE • 95%</span>
        </div>
        <div class="camera-view-container">
          <!-- Top Bar Clean White -->
          <div class="camera-top-bar">
            <div class="top-left-group">
              <div class="btn-round-white">☰</div>
              <div class="ratio-pill-white">3:4</div>
            </div>
            <div class="loc-badge-clean">📍 Pos 1 Gate Keluar (TBM)</div>
          </div>

          <!-- Viewfinder with clean watermark -->
          <div class="viewfinder-mock">
            <div class="simulated-lens">
              <div class="focus-crosshair"></div>
            </div>
            <div class="wm-card-bottom">
              <div class="wm-left">
                <h4>PMA TECHNICIAN REPORT</h4>
                <p>IT Support KC BSG • Pos 1 Gate Keluar</p>
              </div>
              <div class="wm-right">
                <div class="wm-time">12:20:45 WITA</div>
                <div class="wm-date">04 Okt 2026 • Verified GPS</div>
              </div>
            </div>
          </div>

          <!-- Bottom Control Deck (Studio White) -->
          <div class="camera-bottom-deck">
            <div class="btn-deck-item">
              <div class="deck-icon-circle">🔄</div>
              <span>Switch</span>
            </div>
            <div class="shutter-outer">
              <div class="shutter-inner"></div>
            </div>
            <div class="btn-deck-item">
              <div class="deck-icon-circle">📋</div>
              <span>SOP</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Phone 3: Sidebar Drawer (Cohesive Match) -->
    <div class="screen-col">
      <div class="screen-label">
        <span class="num">3</span>
        <h3>Sidebar Drawer (Paduan Sempurna)</h3>
      </div>
      <div class="phone-frame">
        <div class="status-bar-light" style="background:#1E448D; color:rgba(255,255,255,0.85);">
          <span>12:20</span>
          <span>4G LTE • 95%</span>
        </div>
        <div class="drawer-white-screen">
          <div class="drawer-white-header">
            <img src="${bssTransparentBase64}" alt="BSS Parking Logo">
          </div>

          <div class="drawer-white-content">
            <div class="menu-clean-card">
              <div class="m-icon icon-org">📋</div>
              <div class="m-text">
                <div class="m-title-row">
                  <div class="m-title">Penugasan Teknisi</div>
                  <span class="tag-spv">SPV</span>
                </div>
                <div class="m-sub">Buat tugas &amp; pantau progres teknisi</div>
              </div>
            </div>

            <div class="menu-clean-card active">
              <div class="m-icon icon-org">⚡</div>
              <div class="m-text">
                <div class="m-title">Daily Task</div>
                <div class="m-sub">List daily yang harus dikerjakan</div>
              </div>
            </div>

            <div class="menu-clean-card">
              <div class="m-icon icon-nv">🔧</div>
              <div class="m-text">
                <div class="m-title">Riwayat Maintenance</div>
                <div class="m-sub">Daftar checklist unit pos/server</div>
              </div>
            </div>

            <div class="menu-clean-card">
              <div class="m-icon icon-sk">📁</div>
              <div class="m-text">
                <div class="m-title">Arsip Kehadiran</div>
                <div class="m-sub">Catatan absensi 30 hari terakhir</div>
              </div>
              <span class="tag-count">30 Hari</span>
            </div>

            <div class="user-box-clean">
              <div class="user-avatar-clean">R</div>
              <div class="m-text">
                <div class="m-title">Ryan Lumasuge</div>
                <div class="user-role-clean">IT Support KC BSG</div>
              </div>
              <div style="color:#EF4444; font-size:18px;">🚪</div>
            </div>
          </div>

          <div class="drawer-white-footer">
            <div class="footer-t1">PMA App ❤️ Made by annnpii</div>
            <div class="footer-t2">Project Maintenance Assembly</div>
          </div>
        </div>
      </div>
    </div>

  </div>
</div>

</body>
</html>
`;

const htmlPath = path.join(OUT_DIR, 'PMA-App-White-Navy-Theme.html');
fs.writeFileSync(htmlPath, htmlContent);

const outPngPath = path.join(OUT_DIR, 'PMA-App-White-Navy-Showcase.png');
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
