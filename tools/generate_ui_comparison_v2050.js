const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const OUT_DIR = '/tmp/bss_preview';
if (!fs.existsSync(OUT_DIR)) {
  fs.mkdirSync(OUT_DIR, { recursive: true });
}

const htmlContent = `<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>BSS TimeMark - Perbandingan UI Lama vs UI Baru v2.0.50</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, "Plus Jakarta Sans", sans-serif; }
  body {
    background: #06090E;
    color: #F8FAFC;
    padding: 24px;
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
  }
  .canvas {
    width: 1280px;
    background: radial-gradient(circle at 15% 15%, #111927 0%, #06090E 90%);
    border-radius: 28px;
    border: 1px solid rgba(255, 255, 255, 0.12);
    box-shadow: 0 40px 100px rgba(0, 0, 0, 0.9);
    padding: 30px 36px;
  }

  /* Header Bar */
  .header-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
    padding-bottom: 20px;
    margin-bottom: 24px;
  }
  .brand-group {
    display: flex;
    align-items: center;
    gap: 16px;
  }
  .app-icon {
    width: 48px;
    height: 48px;
    background: linear-gradient(135deg, #1A428A 0%, #0F2856 100%);
    border: 2px solid #FF6500;
    border-radius: 14px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 900;
    font-size: 22px;
    color: #FFFFFF;
    box-shadow: 0 6px 20px rgba(255, 101, 0, 0.35);
  }
  .brand-meta h1 {
    font-size: 22px;
    font-weight: 800;
    letter-spacing: -0.2px;
    color: #FFFFFF;
  }
  .brand-meta p {
    font-size: 13px;
    color: #94A3B8;
    margin-top: 2px;
  }
  .header-badges {
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .pill {
    padding: 6px 14px;
    border-radius: 20px;
    font-size: 11.5px;
    font-weight: 700;
    letter-spacing: 0.2px;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .pill-orange {
    background: rgba(255, 101, 0, 0.18);
    border: 1px solid #FF6500;
    color: #FFA066;
  }
  .pill-green {
    background: rgba(16, 185, 129, 0.16);
    border: 1px solid #10B981;
    color: #6EE7B7;
  }
  .pill-blue {
    background: rgba(26, 66, 138, 0.3);
    border: 1px solid #3B82F6;
    color: #93C5FD;
  }

  /* Main Comparison Grid */
  .grid-2col {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 24px;
  }

  /* Comparison Cards */
  .card-col {
    border-radius: 22px;
    padding: 22px;
    display: flex;
    flex-direction: column;
    gap: 18px;
    position: relative;
  }
  .card-lama {
    background: rgba(15, 23, 42, 0.7);
    border: 1px solid rgba(255, 255, 255, 0.1);
  }
  .card-baru {
    background: rgba(17, 24, 39, 0.85);
    border: 1.5px solid rgba(255, 101, 0, 0.45);
    box-shadow: 0 16px 40px rgba(255, 101, 0, 0.12);
  }

  .col-title-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding-bottom: 12px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  }
  .col-title-bar h2 {
    font-size: 16px;
    font-weight: 800;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .tag-lama {
    background: #334155;
    color: #94A3B8;
    font-size: 10px;
    font-weight: 700;
    padding: 3px 8px;
    border-radius: 6px;
  }
  .tag-baru {
    background: #FF6500;
    color: #FFFFFF;
    font-size: 10px;
    font-weight: 800;
    padding: 3px 8px;
    border-radius: 6px;
    letter-spacing: 0.5px;
  }

  /* Palette Row */
  .palette-box {
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: rgba(0, 0, 0, 0.35);
    padding: 10px 14px;
    border-radius: 12px;
  }
  .palette-label {
    font-size: 11px;
    font-weight: 700;
    color: #94A3B8;
  }
  .swatches {
    display: flex;
    gap: 8px;
  }
  .swatch {
    width: 26px;
    height: 26px;
    border-radius: 8px;
    border: 1px solid rgba(255, 255, 255, 0.2);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 8px;
    font-weight: 700;
  }

  /* Phone Mockup Representation */
  .phone-mockup {
    border-radius: 18px;
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 12px;
    border: 1px solid rgba(255, 255, 255, 0.08);
  }
  .mockup-lama {
    background: #0A0F1D;
  }
  .mockup-baru {
    background: #0E1526;
    border: 1px solid rgba(255, 101, 0, 0.25);
  }

  .mock-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 11px;
    color: #94A3B8;
    padding-bottom: 6px;
    border-bottom: 1px solid rgba(255,255,255,0.06);
  }
  .mock-badge {
    padding: 2px 8px;
    border-radius: 4px;
    font-size: 10px;
    font-weight: 700;
  }

  /* Camera Viewfinder with Burner Watermark */
  .viewfinder-box {
    height: 140px;
    border-radius: 12px;
    position: relative;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    padding: 10px;
  }
  .viewfinder-lama {
    background: #111827;
    border: 1px solid #1E293B;
  }
  .viewfinder-baru {
    background: linear-gradient(180deg, #152033 0%, #0D1624 100%);
    border: 1.5px solid rgba(255,101,0,0.3);
  }

  /* Live Watermark Overlay Demo */
  .watermark-overlay {
    border-radius: 8px;
    padding: 6px 8px;
    font-size: 9.5px;
    line-height: 1.35;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  }
  .wm-lama {
    background: rgba(10, 15, 29, 0.85);
    border: 1px solid #334155;
    color: #CBD5E1;
  }
  .wm-baru {
    background: rgba(255, 255, 255, 0.95);
    border-left: 3px solid #FF6500;
    color: #0F172A;
    box-shadow: 0 4px 12px rgba(0,0,0,0.4);
  }
  .wm-title {
    font-weight: 800;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .wm-lama .wm-title { color: #38BDF8; }
  .wm-baru .wm-title { color: #1A428A; }

  /* Shortcut Pill Demo */
  .shortcut-pill-demo {
    align-self: center;
    padding: 4px 12px;
    border-radius: 16px;
    font-size: 10px;
    font-weight: 700;
    display: flex;
    align-items: center;
    gap: 5px;
  }
  .pill-demo-lama {
    background: #1E293B;
    color: #94A3B8;
    border: 1px solid #334155;
  }
  .pill-demo-baru {
    background: rgba(26, 66, 138, 0.4);
    color: #93C5FD;
    border: 1px solid #3B82F6;
    box-shadow: 0 2px 8px rgba(0,0,0,0.3);
  }

  /* Shutter & Action Bars */
  .action-bar-demo {
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: rgba(0,0,0,0.45);
    padding: 10px 16px;
    border-radius: 14px;
  }
  .btn-mini {
    padding: 6px 12px;
    border-radius: 8px;
    font-size: 10.5px;
    font-weight: 600;
  }
  .btn-mini-lama {
    background: #1E293B;
    color: #94A3B8;
  }
  .btn-mini-baru {
    background: #1A428A;
    color: #FFFFFF;
    border-radius: 14px;
    border: 1px solid rgba(255,255,255,0.18);
    box-shadow: 0 2px 8px rgba(0,0,0,0.3);
  }
  .shutter-lama {
    width: 44px;
    height: 44px;
    border-radius: 50%;
    background: #334155;
    border: 3px solid #64748B;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .shutter-lama-core {
    width: 24px;
    height: 24px;
    border-radius: 50%;
    background: #FFFFFF;
  }
  .shutter-baru {
    width: 50px;
    height: 50px;
    border-radius: 50%;
    background: rgba(255, 101, 0, 0.25);
    border: 2.5px solid #FF6500;
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: 0 0 18px rgba(255, 101, 0, 0.5);
  }
  .shutter-baru-core {
    width: 30px;
    height: 30px;
    border-radius: 50%;
    background: #FF6500;
    box-shadow: 0 2px 8px rgba(0,0,0,0.4);
  }

  /* Bottom Sheet: Daily Pulang Demo */
  .modal-demo {
    border-radius: 14px;
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 7px;
  }
  .modal-lama {
    background: #0A0F1D;
    border: 1px solid #1E293B;
  }
  .modal-baru {
    background: #FFFFFF;
    color: #0F172A;
    border-radius: 20px;
    border-top: 4px solid #FF6500;
    box-shadow: 0 8px 24px rgba(0,0,0,0.35);
  }
  .modal-header-text {
    font-size: 11.5px;
    font-weight: 800;
  }
  .modal-lama .modal-header-text { color: #F1F5F9; }
  .modal-baru .modal-header-text { color: #0F172A; }
  
  .sheet-field {
    display: flex;
    flex-direction: column;
    gap: 3px;
    font-size: 9.5px;
  }
  .sheet-label { font-weight: 600; color: #64748B; }
  .sheet-input-lama {
    background: #1E293B;
    border: 1px solid #334155;
    padding: 5px 8px;
    border-radius: 6px;
    color: #CBD5E1;
  }
  .sheet-input-baru {
    background: #FAF7F0;
    border: 1.5px solid #E2E8F0;
    padding: 6px 10px;
    border-radius: 12px;
    color: #1A428A;
    font-weight: 700;
  }

  .cta-lama {
    background: #059669;
    color: white;
    text-align: center;
    padding: 7px;
    border-radius: 8px;
    font-size: 10.5px;
    font-weight: 700;
  }
  .cta-baru {
    background: #FF6500;
    color: white;
    text-align: center;
    padding: 8px;
    border-radius: 14px;
    font-size: 11px;
    font-weight: 800;
    box-shadow: 0 4px 12px rgba(255,101,0,0.35);
    letter-spacing: 0.3px;
  }

  /* Comparison Points Table */
  .points-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .point-item {
    display: flex;
    align-items: flex-start;
    gap: 8px;
    font-size: 11.5px;
    line-height: 1.4;
  }
  .point-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    margin-top: 5px;
    flex-shrink: 0;
  }
  .dot-red { background: #EF4444; }
  .dot-green { background: #10B981; }

  /* Bottom Stats Bar */
  .stats-bar {
    margin-top: 24px;
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 14px;
    background: rgba(15, 23, 42, 0.6);
    border: 1px solid rgba(255,255,255,0.08);
    border-radius: 16px;
    padding: 14px 20px;
  }
  .stat-card {
    display: flex;
    flex-direction: column;
    gap: 3px;
  }
  .stat-label {
    font-size: 10.5px;
    color: #94A3B8;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    font-weight: 600;
  }
  .stat-val {
    font-size: 13.5px;
    font-weight: 800;
    color: #FFFFFF;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .val-highlight { color: #FF6500; }
  .val-success { color: #10B981; }
</style>
</head>
<body>

<div class="canvas">
  <!-- Top Bar -->
  <div class="header-bar">
    <div class="brand-group">
      <div class="app-icon">B</div>
      <div class="brand-meta">
        <h1>BSS Parking TimeMark • Visual Architecture Redesign</h1>
        <p>Aplikasi Kamera TimeMark & Absensi Shift POS Parkir • Legacy Dark vs Apple HIG Native Tactile (v2.0.50)</p>
      </div>
    </div>
    <div class="header-badges">
      <div class="pill pill-blue">🎯 Anti-AI Slop</div>
      <div class="pill pill-orange">⚡ Squircles 14-28px</div>
      <div class="pill pill-green">🛡️ Instant Recovery Ready</div>
    </div>
  </div>

  <!-- Main 2 Column Grid -->
  <div class="grid-2col">

    <!-- Left Column: UI Lama v2.0.49 -->
    <div class="card-col card-lama">
      <div class="col-title-bar">
        <h2><span>🌑</span> UI Lama (v2.0.49)</h2>
        <span class="tag-lama">LEGACY THEME</span>
      </div>

      <!-- Color Palette -->
      <div class="palette-box">
        <span class="palette-label">Palette Dasar</span>
        <div class="swatches">
          <div class="swatch" style="background:#0A0F1D; color:#888;">#0A</div>
          <div class="swatch" style="background:#1E293B; color:#888;">#1E</div>
          <div class="swatch" style="background:#00E5FF; color:#000;">#00E</div>
          <div class="swatch" style="background:#00C853; color:#000;">#00C</div>
        </div>
      </div>

      <!-- Phone Mockup Preview -->
      <div class="phone-mockup mockup-lama">
        <div class="mock-header">
          <span>Kamera TimeMark Petugas Parkir</span>
          <span class="mock-badge" style="background:#1E293B; color:#94A3B8;">Dark Layout</span>
        </div>

        <!-- Viewfinder & Watermark -->
        <div class="viewfinder-box viewfinder-lama">
          <div class="watermark-overlay wm-lama">
            <div class="wm-title"><span>BSS PARKING • POS BERSEHATI</span> <span>15:45 WITA</span></div>
            <div>Petugas: Junifer Manua | Shift 1</div>
            <div>GPS: 1.493055, 124.841972 (Pasar Bersehati)</div>
          </div>
          <div class="shortcut-pill-demo pill-demo-lama">
            <span>[ 🟢 Masuk : Shift 1 ▾ ]</span>
          </div>
        </div>

        <div class="action-bar-demo">
          <div class="btn-mini btn-mini-lama">Galeri</div>
          <div class="shutter-lama">
            <div class="shutter-lama-core"></div>
          </div>
          <div class="btn-mini btn-mini-lama">SOP Pos</div>
        </div>

        <!-- Daily Pulang Sheet -->
        <div class="modal-demo modal-lama">
          <div class="modal-header-text">Form Kepulangan Shift (Daily IT)</div>
          <div class="sheet-field">
            <span class="sheet-label">Rekan IT Pengganti:</span>
            <div class="sheet-input-lama">Ryan Lumasuge</div>
          </div>
          <div class="cta-lama">SIMPAN & LANJUT ABSEN PULANG</div>
        </div>
      </div>

      <!-- Comparison Bullet Points -->
      <div class="points-list">
        <div class="point-item">
          <div class="point-dot dot-red"></div>
          <div><strong>Aesthetic:</strong> Dominan gelap monokrom (#0A0F1D), visibilitas redup di bawah terik matahari pos parkir.</div>
        </div>
        <div class="point-item">
          <div class="point-dot dot-red"></div>
          <div><strong>Shape Language:</strong> Radius sudut kaku 8px - 12px standar, minim hierarki sentuhan jari.</div>
        </div>
        <div class="point-item">
          <div class="point-dot dot-red"></div>
          <div><strong>Feedback Kamera:</strong> Shutter datar monoton tanpa dual-ring haptic konfirmasi.</div>
        </div>
      </div>
    </div>

    <!-- Right Column: UI Baru v2.0.50 -->
    <div class="card-col card-baru">
      <div class="col-title-bar">
        <h2><span>🔥</span> UI Baru (v2.0.50 PRO)</h2>
        <span class="tag-baru">NATIVE TACTILE HIG</span>
      </div>

      <!-- Color Palette -->
      <div class="palette-box">
        <span class="palette-label">Palette High-Contrast</span>
        <div class="swatches">
          <div class="swatch" style="background:#FFFFFF; color:#000;">#FFF</div>
          <div class="swatch" style="background:#1A428A; color:#FFF;">#1A4</div>
          <div class="swatch" style="background:#FF6500; color:#FFF;">#FF6</div>
          <div class="swatch" style="background:#FAF7F0; color:#000;">#FAF</div>
        </div>
      </div>

      <!-- Phone Mockup Preview -->
      <div class="phone-mockup mockup-baru">
        <div class="mock-header">
          <span style="color:#FFF; font-weight:700;">Kamera TimeMark PRO • HIG</span>
          <span class="mock-badge" style="background:#FF6500; color:#FFF;">v2.0.50 Tactile</span>
        </div>

        <!-- Viewfinder & Watermark -->
        <div class="viewfinder-box viewfinder-baru">
          <div class="watermark-overlay wm-baru">
            <div class="wm-title"><span>BSS PARKING • POS BERSEHATI</span> <span>15:45:12 WITA</span></div>
            <div>Petugas: Junifer Manua | Shift 1 (03:00 - 11:00)</div>
            <div>GPS: 1.493055, 124.841972 • AI: SERAGAM LENGKAP</div>
          </div>
          <div class="shortcut-pill-demo pill-demo-baru">
            <span>[ 🔵 Pulang (Kerja: 08j 00m) ▾ ]</span>
          </div>
        </div>

        <div class="action-bar-demo">
          <div class="btn-mini btn-mini-baru">Galeri</div>
          <div class="shutter-baru">
            <div class="shutter-baru-core"></div>
          </div>
          <div class="btn-mini btn-mini-baru">SOP Patroli</div>
        </div>

        <!-- Daily Pulang Sheet -->
        <div class="modal-demo modal-baru">
          <div class="modal-header-text">Form Kepulangan Shift (Pristine White)</div>
          <div class="sheet-field">
            <span class="sheet-label">Rekan IT Shift Selanjutnya:</span>
            <div class="sheet-input-baru">Ryan Lumasuge (IT Support)</div>
          </div>
          <div class="cta-baru">SIMPAN & LANJUT ABSEN PULANG ➔</div>
        </div>
      </div>

      <!-- Comparison Bullet Points -->
      <div class="points-list">
        <div class="point-item">
          <div class="point-dot dot-green"></div>
          <div><strong>Aesthetic:</strong> Putih Bersih + Navy BSS (#1A428A) + Safety Orange (#FF6500) kontras tinggi anti-silau.</div>
        </div>
        <div class="point-item">
          <div class="point-dot dot-green"></div>
          <div><strong>Continuous Squircles:</strong> 14px (Action chips), 16px (Card), 28px (Modal Bottom Sheet).</div>
        </div>
        <div class="point-item">
          <div class="point-dot dot-green"></div>
          <div><strong>Tactile Shutter & Haptics:</strong> Dual-ring Safety Orange dengan getaran taktil presisi saat capture foto pos.</div>
        </div>
      </div>
    </div>

  </div>

  <!-- Bottom Metric & Safety Bar -->
  <div class="stats-bar">
    <div class="stat-card">
      <span class="stat-label">Code Health</span>
      <span class="stat-val val-success">✓ 0 Issues (Clean Analyze)</span>
    </div>
    <div class="stat-card">
      <span class="stat-label">UI Standard</span>
      <span class="stat-val val-success">⚡ Apple HIG Continuous Squircles</span>
    </div>
    <div class="stat-card">
      <span class="stat-label">Safety Backup</span>
      <span class="stat-val val-highlight">🛡️ lib_v2049_backup/ Preserved</span>
    </div>
    <div class="stat-card">
      <span class="stat-label">Instant Rollback</span>
      <span class="stat-val" style="color:#60A5FA;">1-Click recovery_ui_v2049.sh</span>
    </div>
  </div>
</div>

</body>
</html>
`;

const htmlPath = path.join(OUT_DIR, 'comparison_v2050.html');
const pngPath = path.join(OUT_DIR, 'bss_ui_comparison_v2050.png');
const repoPngPath = path.join(__dirname, '..', 'BSS-TimeMark-v2.0.50-UI-Comparison.png');

fs.writeFileSync(htmlPath, htmlContent, 'utf8');

try {
  execSync(
    `google-chrome-stable --headless=new --disable-gpu --no-sandbox --hide-scrollbars --screenshot="${pngPath}" --window-size=1350,1050 "file://${htmlPath}"`,
    { stdio: 'inherit' }
  );
  fs.copyFileSync(pngPath, repoPngPath);
  console.log(`[Preview Generated] Saved to ${pngPath} and ${repoPngPath}`);
  console.log(`Size: ${fs.statSync(repoPngPath).size} bytes`);
} catch (err) {
  console.error('[Preview Error]', err.message);
  process.exit(1);
}
