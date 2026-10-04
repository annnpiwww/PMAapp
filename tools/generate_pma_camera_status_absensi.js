const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const OUT_DIR = '/home/annnpii/Product development annpii/BssparkingTimeMark';

const htmlContent = `<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>PMA App - UI Camera HUD: Floating Status Absensi & Location</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Plus Jakarta Sans", sans-serif; }
  
  body {
    background: #06090F;
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
    font-weight: 800;
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
    background: #000000;
    border-radius: 40px;
    border: 4px solid #334155;
    box-shadow: 0 20px 50px rgba(0, 0, 0, 0.75);
    overflow: hidden;
    position: relative;
    display: flex;
    flex-direction: column;
  }

  .camera-container {
    flex: 1;
    display: flex;
    flex-direction: column;
    position: relative;
    background: #050811;
  }

  /* Top HUD Bar */
  .hud-top-bar {
    height: 60px;
    padding: 10px 16px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: linear-gradient(180deg, rgba(0,0,0,0.7) 0%, rgba(0,0,0,0) 100%);
    z-index: 20;
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
  }

  .hud-left {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .hud-icon-btn {
    width: 36px;
    height: 36px;
    border-radius: 50%;
    background: rgba(0, 0, 0, 0.55);
    backdrop-filter: blur(8px);
    border: 1px solid rgba(255, 255, 255, 0.2);
    display: flex;
    align-items: center;
    justify-content: center;
    color: #FFFFFF;
    font-size: 17px;
  }

  .hud-ratio-pill {
    height: 36px;
    padding: 0 12px;
    border-radius: 18px;
    background: rgba(0, 0, 0, 0.55);
    backdrop-filter: blur(8px);
    border: 1px solid rgba(255, 255, 255, 0.2);
    display: flex;
    align-items: center;
    gap: 5px;
    color: #FFFFFF;
    font-size: 12px;
    font-weight: 800;
  }

  .hud-right {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  /* Location Icon Quick-Access (Tetap Dipertahankan Sesuai Arahan) */
  .loc-pill-header {
    height: 36px;
    padding: 0 10px;
    border-radius: 18px;
    background: rgba(0, 0, 0, 0.55);
    backdrop-filter: blur(8px);
    border: 1px solid rgba(255, 101, 0, 0.4);
    display: flex;
    align-items: center;
    gap: 5px;
    color: #FFF;
    font-size: 11.5px;
    font-weight: 700;
  }

  /* Viewfinder Area */
  .viewfinder-box {
    flex: 1;
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    background: #0F172A;
    overflow: hidden;
  }

  .optical-lens-layer {
    width: 100%;
    height: 100%;
    background: radial-gradient(circle at 50% 50%, #1E293B 0%, #0B1120 100%);
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  /* FLOATING STATUS ABSENSI PILL (DI TENGAH ATAS VIEWFINDER) */
  .floating-absensi-slot {
    position: absolute;
    top: 72px;
    left: 0;
    right: 0;
    display: flex;
    justify-content: center;
    z-index: 15;
  }

  .status-absensi-pill {
    padding: 7px 16px;
    border-radius: 24px;
    backdrop-filter: blur(10px);
    display: flex;
    align-items: center;
    gap: 8px;
    cursor: pointer;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.5);
    transition: 0.2s;
  }

  /* Mode Masuk: Emerald Glow */
  .pill-masuk {
    background: rgba(5, 46, 22, 0.85);
    border: 1.5px solid #10B981;
    color: #D1FAE5;
  }
  .dot-masuk { width: 8px; height: 8px; border-radius: 50%; background: #10B981; box-shadow: 0 0 8px #10B981; }

  /* Mode Kerja / Aktif: Sky/Blue Glow */
  .pill-kerja {
    background: rgba(12, 74, 110, 0.85);
    border: 1.5px solid #0284C7;
    color: #E0F2FE;
  }
  .dot-kerja { width: 8px; height: 8px; border-radius: 50%; background: #0284C7; box-shadow: 0 0 8px #0284C7; }

  /* Mode Pulang: Orange/Amber Alert */
  .pill-pulang {
    background: rgba(124, 45, 18, 0.85);
    border: 1.5px solid #FF6500;
    color: #FFEDD5;
  }
  .dot-pulang { width: 8px; height: 8px; border-radius: 50%; background: #FF6500; box-shadow: 0 0 8px #FF6500; }

  .pill-label {
    font-size: 12.5px;
    font-weight: 800;
    letter-spacing: 0.3px;
  }

  /* Optical Frame Corner Brackets */
  .corner-tl { position: absolute; top: 20px; left: 20px; width: 18px; height: 18px; border-top: 2px solid #FF6500; border-left: 2px solid #FF6500; }
  .corner-tr { position: absolute; top: 20px; right: 20px; width: 18px; height: 18px; border-top: 2px solid #FF6500; border-right: 2px solid #FF6500; }
  .corner-bl { position: absolute; bottom: 85px; left: 20px; width: 18px; height: 18px; border-bottom: 2px solid #FF6500; border-left: 2px solid #FF6500; }
  .corner-br { position: absolute; bottom: 85px; right: 20px; width: 18px; height: 18px; border-bottom: 2px solid #FF6500; border-right: 2px solid #FF6500; }

  .center-target {
    width: 64px;
    height: 64px;
    border: 1px dashed rgba(255, 101, 0, 0.6);
    border-radius: 8px;
    position: relative;
  }

  .center-target::after {
    content: '';
    position: absolute;
    top: 50%; left: 50%;
    transform: translate(-50%, -50%);
    width: 6px; height: 6px;
    background: #FF6500;
    border-radius: 50%;
  }

  /* WATERMARK 100% ORIGINAL PRESERVED */
  .original-watermark-card {
    position: absolute;
    bottom: 14px;
    left: 14px;
    right: 14px;
    background: rgba(255, 255, 255, 0.95);
    backdrop-filter: blur(8px);
    border-radius: 12px;
    padding: 10px 14px;
    border-left: 4px solid #FF6500;
    box-shadow: 0 8px 20px rgba(0, 0, 0, 0.35);
    display: flex;
    justify-content: space-between;
    align-items: center;
    z-index: 10;
  }

  .wm-meta-title { font-size: 12px; font-weight: 800; color: #1E448D; }
  .wm-meta-sub { font-size: 10px; color: #334155; margin-top: 2px; font-weight: 600; }
  .wm-meta-right { text-align: right; }
  .wm-time-str { font-size: 12.5px; font-weight: 800; color: #FF6500; }
  .wm-date-str { font-size: 9.5px; color: #64748B; font-weight: 600; margin-top: 1px; }

  /* Bottom Controls Deck */
  .hud-bottom-deck {
    height: 120px;
    background: rgba(11, 17, 32, 0.96);
    border-top: 1px solid #1E293B;
    padding: 12px 24px 20px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    z-index: 20;
  }

  .side-deck-action {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
  }

  .action-circle-icon {
    width: 48px;
    height: 48px;
    border-radius: 14px;
    background: #1E293B;
    border: 1px solid #334155;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #FFFFFF;
    font-size: 20px;
  }

  .action-label-text {
    font-size: 11px;
    font-weight: 700;
    color: #94A3B8;
  }

  .industrial-shutter-wrap {
    width: 76px;
    height: 76px;
    border-radius: 50%;
    border: 3.5px solid #FFFFFF;
    background: transparent;
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: 0 0 20px rgba(255, 101, 0, 0.35);
  }

  .industrial-shutter-core {
    width: 58px;
    height: 58px;
    border-radius: 50%;
    background: #FF6500;
    box-shadow: 0 0 14px rgba(255, 101, 0, 0.7);
    display: flex;
    align-items: center;
    justify-content: center;
    color: #FFFFFF;
    font-size: 22px;
  }

  /* MODAL MODES PREVIEW (Screen 3) */
  .modal-overlay-preview {
    position: absolute;
    inset: 0;
    background: rgba(0, 0, 0, 0.75);
    backdrop-filter: blur(4px);
    z-index: 30;
    display: flex;
    flex-direction: column;
    justify-content: flex-end;
  }

  .modal-sheet-box {
    background: #FFFFFF;
    border-top-left-radius: 24px;
    border-top-right-radius: 24px;
    padding: 22px 18px 24px;
    color: #0F172A;
  }

  .sheet-handle {
    width: 36px;
    height: 4px;
    border-radius: 2px;
    background: #CBD5E1;
    margin: 0 auto 16px;
  }

  .sheet-title {
    font-size: 15.5px;
    font-weight: 800;
    color: #1E448D;
    margin-bottom: 4px;
  }

  .sheet-sub {
    font-size: 11.5px;
    color: #64748B;
    margin-bottom: 16px;
  }

  /* 3 State Cards */
  .state-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .state-card {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 10px 14px;
    border-radius: 12px;
    border: 1px solid #E2E8F0;
    background: #F8FAFC;
  }

  .state-card.selected {
    background: #EFF6FF;
    border-color: #1E448D;
  }

  .state-icon {
    width: 34px;
    height: 34px;
    border-radius: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 16px;
  }

  .state-meta h4 { font-size: 13px; font-weight: 800; color: #0F172A; }
  .state-meta p { font-size: 10.5px; color: #64748B; }

  /* Annotation Callout Card */
  .callout-box {
    margin-top: 14px;
    background: #111827;
    border: 1px solid #1E293B;
    border-radius: 12px;
    padding: 12px 14px;
    width: 360px;
  }

  .callout-title {
    font-size: 12px;
    font-weight: 800;
    color: #FF6500;
    display: flex;
    align-items: center;
    gap: 6px;
    margin-bottom: 4px;
  }

  .callout-desc {
    font-size: 11px;
    color: #94A3B8;
    line-height: 1.4;
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
        <h1>PMA App — Status Absensi Pintar & Preservasi Ikon Lokasi (CP-04)</h1>
        <p>Floating Status Absensi (Masuk, Shift Aktif, Pulang) • Ikon Lokasi Tetap Ada • Modal Dialog Terintegrasi</p>
      </div>
    </div>
    <div class="status-tag">APPROVED ARCHITECTURE</div>
  </div>

  <!-- 3 Phones Display -->
  <div class="grid">
    
    <!-- Phone 1: Mode Masuk Shift -->
    <div class="screen-col">
      <div class="screen-label">
        <span class="num">1</span>
        <h3>Status: Masuk Shift (Awal Hari)</h3>
      </div>
      <div class="phone-frame">
        <div class="camera-container">
          <!-- Top Overlay HUD dengan Ikon Lokasi Tetap Terpasang -->
          <div class="hud-top-bar">
            <div class="hud-left">
              <div class="hud-icon-btn">☰</div>
              <div class="hud-ratio-pill">
                <span style="color:#FF6500;">⊞</span>
                <span>3:4</span>
              </div>
            </div>
            <!-- Ikon Lokasi Tetap Eksis di Top Bar -->
            <div class="hud-right">
              <div class="loc-pill-header">
                <span style="color:#FF6500;">📍</span>
                <span>TBM - Pos 1</span>
              </div>
              <div class="hud-icon-btn">⚡</div>
            </div>
          </div>

          <!-- FLOATING STATUS ABSENSI: MASUK SHIFT -->
          <div class="floating-absensi-slot">
            <div class="status-absensi-pill pill-masuk">
              <div class="dot-masuk"></div>
              <span class="pill-label">Masuk : S1 (06:00 - 14:00)</span>
              <span style="font-size:10px; color:#A7F3D0;">▼</span>
            </div>
          </div>

          <div class="viewfinder-box">
            <div class="optical-lens-layer">
              <div class="corner-tl"></div><div class="corner-tr"></div>
              <div class="corner-bl"></div><div class="corner-br"></div>
              <div class="center-target"></div>
            </div>

            <!-- WATERMARK 100% ORIGINAL -->
            <div class="original-watermark-card">
              <div class="wm-meta-left">
                <div class="wm-meta-title">BSS PARKING TIMEMARK</div>
                <div class="wm-meta-sub">Pos 1 Gate Keluar (TBM) • Manado</div>
              </div>
              <div class="wm-meta-right">
                <div class="wm-time-str">06:02:15 WITA</div>
                <div class="wm-date-str">04/10/2026 • GPS Verified</div>
              </div>
            </div>
          </div>

          <div class="hud-bottom-deck">
            <div class="side-deck-action">
              <div class="action-circle-icon">🖼️</div>
              <span class="action-label-text">Galeri</span>
            </div>
            <div class="industrial-shutter-wrap">
              <div class="industrial-shutter-core">📷</div>
            </div>
            <div class="side-deck-action">
              <div class="action-circle-icon" style="color:#60A5FA;">📋</div>
              <span class="action-label-text" style="color:#60A5FA;">SOP Unit</span>
            </div>
          </div>
        </div>
      </div>

      <div class="callout-box">
        <div class="callout-title">🟢 Mode Awal: Absen Masuk</div>
        <div class="callout-desc">Menampilkan shift aktif dengan warna hijau. Tap pill ini untuk mengubah shift atau ganti jadwal.</div>
      </div>
    </div>

    <!-- Phone 2: Mode Pulang Shift (Shift Selesai) -->
    <div class="screen-col">
      <div class="screen-label">
        <span class="num">2</span>
        <h3>Status: Pulang Shift (Handover Daily)</h3>
      </div>
      <div class="phone-frame">
        <div class="camera-container">
          <div class="hud-top-bar">
            <div class="hud-left">
              <div class="hud-icon-btn">☰</div>
              <div class="hud-ratio-pill"><span>3:4</span></div>
            </div>
            <div class="hud-right">
              <div class="loc-pill-header">
                <span style="color:#FF6500;">📍</span>
                <span>TBM - Pos 1</span>
              </div>
              <div class="hud-icon-btn">⚡</div>
            </div>
          </div>

          <!-- FLOATING STATUS ABSENSI: PULANG SHIFT (ORANYE ALERT) -->
          <div class="floating-absensi-slot">
            <div class="status-absensi-pill pill-pulang">
              <div class="dot-pulang"></div>
              <span class="pill-label">Pulang Shift : 14:05 WITA</span>
              <span style="font-size:10px; color:#FDBA74;">▼</span>
            </div>
          </div>

          <div class="viewfinder-box">
            <div class="optical-lens-layer">
              <div class="corner-tl"></div><div class="corner-tr"></div>
              <div class="corner-bl"></div><div class="corner-br"></div>
              <div class="center-target"></div>
            </div>

            <!-- WATERMARK 100% ORIGINAL -->
            <div class="original-watermark-card">
              <div class="wm-meta-left">
                <div class="wm-meta-title">BSS PARKING TIMEMARK</div>
                <div class="wm-meta-sub">Pos 1 Gate Keluar (TBM) • Manado</div>
              </div>
              <div class="wm-meta-right">
                <div class="wm-time-str">14:05:30 WITA</div>
                <div class="wm-date-str">04/10/2026 • GPS Verified</div>
              </div>
            </div>
          </div>

          <div class="hud-bottom-deck">
            <div class="side-deck-action"><div class="action-circle-icon">🖼️</div><span class="action-label-text">Galeri</span></div>
            <div class="industrial-shutter-wrap"><div class="industrial-shutter-core">📷</div></div>
            <div class="side-deck-action"><div class="action-circle-icon" style="color:#60A5FA;">📋</div><span class="action-label-text" style="color:#60A5FA;">SOP Unit</span></div>
          </div>
        </div>
      </div>

      <div class="callout-box">
        <div class="callout-title">🟠 Mode Akhir: Absen Pulang</div>
        <div class="callout-desc">Otomatis berubah ke warna oranye saat jam shift selesai. Shutter diproteksi guard Handover Daily.</div>
      </div>
    </div>

    <!-- Phone 3: Modal Interaktif Masuk, Shift & Pulang -->
    <div class="screen-col">
      <div class="screen-label">
        <span class="num">3</span>
        <h3>Modal Dialog: Masuk, Shift & Pulang</h3>
      </div>
      <div class="phone-frame">
        <div class="camera-container">
          <div class="hud-top-bar">
            <div class="hud-left"><div class="hud-icon-btn">☰</div></div>
            <div class="hud-right"><div class="loc-pill-header"><span>📍 TBM</span></div></div>
          </div>

          <div class="viewfinder-box" style="filter:blur(3px);">
            <div class="optical-lens-layer"></div>
          </div>

          <!-- Bottom Sheet Modal Status Kerja -->
          <div class="modal-overlay-preview">
            <div class="modal-sheet-box">
              <div class="sheet-handle"></div>
              <div class="sheet-title">Atur Status Absensi &amp; Shift</div>
              <div class="sheet-sub">Pilih jenis pelaporan kehadiran Anda hari ini</div>

              <div class="state-list">
                <!-- Opsi 1: Masuk Shift -->
                <div class="state-card selected">
                  <div class="state-icon" style="background:#D1FAE5; color:#059669;">☀️</div>
                  <div class="state-meta">
                    <h4 style="color:#065F46;">Absensi Masuk Shift</h4>
                    <p>Mulai jam kerja • Verifikasi seragam BSS</p>
                  </div>
                </div>

                <!-- Opsi 2: Atur Jadwal Shift -->
                <div class="state-card">
                  <div class="state-icon" style="background:#E0F2FE; color:#0284C7;">⏱️</div>
                  <div class="state-meta">
                    <h4>Pilih Jadwal Shift Kerja</h4>
                    <p>S1 (06:00-14:00) • S2 (10:00-14:00) • S3 (14:00-22:00)</p>
                  </div>
                </div>

                <!-- Opsi 3: Pulang & Handover -->
                <div class="state-card">
                  <div class="state-icon" style="background:#FFEDD5; color:#EA580C;">🌙</div>
                  <div class="state-meta">
                    <h4>Absensi Pulang (Handover Shift)</h4>
                    <p>Laporan pekerjaan selesai & serah terima pos</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="callout-box">
        <div class="callout-title">⚡ Modal Terbuka Saat Pill Di-Tap</div>
        <div class="callout-desc">Bila pill status absensi di-tap, teknisi langsung disajikan modal pengaturan Masuk, Shift, dan Pulang.</div>
      </div>
    </div>

  </div>
</div>

</body>
</html>
`;

const htmlPath = path.join(OUT_DIR, 'PMA-App-Camera-Status-Absensi.html');
fs.writeFileSync(htmlPath, htmlContent);

const outPngPath = path.join(OUT_DIR, 'PMA-App-Camera-Status-Absensi.png');
try {
  execSync(`google-chrome-stable --headless --disable-gpu --screenshot="${outPngPath}" --window-size=1540,920 "${htmlPath}"`, { stdio: 'inherit' });
  console.log('SUCCESS: Rendered to ' + outPngPath);
} catch (e) {
  try {
    execSync(`chromium --headless --disable-gpu --screenshot="${outPngPath}" --window-size=1540,920 "${htmlPath}"`, { stdio: 'inherit' });
    console.log('SUCCESS: Rendered to ' + outPngPath);
  } catch (err) {
    console.error('Failed to render screenshot', err);
  }
}
