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
<title>BSS TimeMark - Maintenance Scope & Toggle Polish Preview v2.0.47</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Plus Jakarta Sans", sans-serif; }
  body {
    background: #0B0F19;
    color: #F8FAFC;
    padding: 24px;
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
  }
  .canvas {
    width: 1200px;
    background: radial-gradient(circle at 12% 18%, #162038 0%, #0A0E17 88%);
    border-radius: 20px;
    border: 1px solid rgba(255,255,255,0.12);
    box-shadow: 0 30px 70px rgba(0,0,0,0.7);
    padding: 26px 30px;
  }
  
  /* Top Banner */
  .brand-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px solid rgba(255,255,255,0.08);
    padding-bottom: 16px;
    margin-bottom: 20px;
  }
  .brand-title {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  .logo-icon {
    width: 40px;
    height: 40px;
    background: linear-gradient(135deg, #2563EB, #1D4ED8);
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 900;
    font-size: 19px;
    color: #fff;
    box-shadow: 0 4px 14px rgba(37,99,235,0.45);
  }
  .brand-text h1 {
    font-size: 18px;
    font-weight: 800;
    letter-spacing: 0.5px;
    color: #FFFFFF;
  }
  .brand-text p {
    font-size: 12px;
    color: #94A3B8;
  }
  .badge-group {
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .version-tag {
    background: rgba(37, 99, 235, 0.2);
    border: 1px solid #3B82F6;
    color: #93C5FD;
    padding: 5px 12px;
    border-radius: 20px;
    font-size: 12px;
    font-weight: 700;
  }
  .success-tag {
    background: rgba(16, 185, 129, 0.18);
    border: 1px solid #10B981;
    color: #34D399;
    padding: 5px 12px;
    border-radius: 20px;
    font-size: 12px;
    font-weight: 700;
  }

  /* Main Grid Comparison */
  .preview-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 20px;
  }

  /* Column Container */
  .col-container {
    background: #FFFFFF;
    color: #1E293B;
    border-radius: 16px;
    padding: 18px 20px;
    box-shadow: 0 14px 32px rgba(0,0,0,0.35);
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  /* Header Box per Mode */
  .dialog-top {
    background: #F8FAFC;
    border: 1px solid #E2E8F0;
    border-radius: 12px;
    padding: 12px 14px;
  }
  .dialog-title-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 4px;
  }
  .dialog-title-row h2 {
    font-size: 14.5px;
    font-weight: 800;
    color: #0F172A;
    display: flex;
    align-items: center;
    gap: 7px;
  }
  .dialog-subtitle {
    font-size: 11.5px;
    color: #64748B;
    font-weight: 500;
  }

  /* Section Title */
  .field-label {
    font-size: 11px;
    font-weight: 700;
    color: #475569;
    text-transform: uppercase;
    letter-spacing: 0.4px;
  }

  /* Segmented Buttons */
  .scope-selector {
    display: flex;
    gap: 8px;
  }
  .scope-btn {
    flex: 1;
    padding: 8px 10px;
    border-radius: 8px;
    font-size: 12px;
    font-weight: 700;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    border: 1.5px solid #CBD5E1;
    background: #F8FAFC;
    color: #64748B;
  }
  .scope-btn.active {
    background: #EFF6FF;
    border-color: #2563EB;
    color: #1D4ED8;
    box-shadow: 0 2px 6px rgba(37,99,235,0.12);
  }

  /* Toggle Box */
  .toggle-box {
    background: #F8FAFC;
    border: 1px solid #E2E8F0;
    border-radius: 10px;
    padding: 10px 12px;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .toggle-text h4 {
    font-size: 12.5px;
    font-weight: 700;
    color: #1E293B;
    line-height: 1.3;
  }
  .toggle-pill {
    display: inline-block;
    padding: 2.5px 8px;
    border-radius: 6px;
    font-size: 10px;
    font-weight: 800;
    margin-top: 3px;
  }
  .toggle-pill.on {
    background: #EFF6FF;
    color: #2563EB;
    border: 1px solid rgba(37,99,235,0.3);
  }
  .toggle-pill.off {
    background: #F1F5F9;
    color: #64748B;
    border: 1px solid #CBD5E1;
  }
  .toggle-desc {
    font-size: 10.5px;
    color: #64748B;
    margin-top: 3px;
  }

  /* Switch graphic */
  .switch-graphic {
    width: 44px;
    height: 24px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    padding: 2px;
    flex-shrink: 0;
  }
  .switch-graphic.active {
    background: #2563EB;
    justify-content: flex-end;
  }
  .switch-graphic.inactive {
    background: #CBD5E1;
    justify-content: flex-start;
  }
  .switch-knob {
    width: 20px;
    height: 20px;
    background: #FFFFFF;
    border-radius: 50%;
    box-shadow: 0 2px 4px rgba(0,0,0,0.2);
  }

  /* Stepper Box */
  .stepper-box {
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: #F8FAFC;
    border: 1px solid #E2E8F0;
    border-radius: 10px;
    padding: 9px 12px;
  }
  .stepper-info h4 {
    font-size: 12px;
    font-weight: 700;
    color: #1E293B;
  }
  .stepper-info p {
    font-size: 10.5px;
    color: #64748B;
  }
  .stepper-controls {
    display: flex;
    align-items: center;
    gap: 7px;
  }
  .btn-circle {
    width: 26px;
    height: 26px;
    border-radius: 6px;
    border: 1px solid #CBD5E1;
    background: #fff;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 14px;
    font-weight: 800;
    color: #1E293B;
  }
  .count-val {
    font-size: 14px;
    font-weight: 800;
    color: #2563EB;
    min-width: 20px;
    text-align: center;
  }

  /* Summary Cards */
  .summary-card {
    background: #ECFDF5;
    border: 1px solid #A7F3D0;
    border-radius: 10px;
    padding: 10px 12px;
  }
  .summary-title {
    font-size: 12px;
    font-weight: 800;
    color: #065F46;
    display: flex;
    align-items: center;
    gap: 6px;
    margin-bottom: 2px;
  }
  .summary-sub {
    font-size: 10.5px;
    font-weight: 600;
    color: #047857;
  }

  /* Secondary Sub-panel for Alternate State */
  .mini-comparison {
    background: #F8FAFC;
    border: 1px dashed #CBD5E1;
    border-radius: 10px;
    padding: 9px 12px;
    margin-top: 2px;
  }
  .mini-title {
    font-size: 10.5px;
    font-weight: 800;
    color: #475569;
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 4px;
  }

  /* Button CTA */
  .action-btn {
    width: 100%;
    background: #2563EB;
    color: #FFFFFF;
    border: none;
    padding: 10px;
    border-radius: 9px;
    font-size: 12.5px;
    font-weight: 700;
    text-align: center;
    box-shadow: 0 4px 10px rgba(37,99,235,0.25);
  }

  /* Right Section: Mobile Preview / WhatsApp Output */
  .sub-box {
    background: #064E3B;
    border: 1px solid #059669;
    border-radius: 9px;
    padding: 10px 12px;
    font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
    font-size: 10px;
    line-height: 1.45;
    color: #ECFDF5;
    white-space: pre-wrap;
  }
  .sub-header {
    font-weight: 800;
    color: #A7F3D0;
    margin-bottom: 4px;
    display: flex;
    align-items: center;
    gap: 5px;
  }

  /* Bottom Feature Badges */
  .feature-pills {
    display: flex;
    justify-content: space-around;
    margin-top: 18px;
    padding-top: 14px;
    border-top: 1px solid rgba(255,255,255,0.08);
  }
  .feat-item {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 11.5px;
    color: #CBD5E1;
    font-weight: 600;
  }
  .feat-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: #34D399;
  }
</style>
</head>
<body>

<div class="canvas">
  <!-- Brand Bar -->
  <div class="brand-bar">
    <div class="brand-title">
      <div class="logo-icon">B</div>
      <div class="brand-text">
        <h1>BSS PARKING TIMEMARK — STATE & UI POLISH VERIFIED</h1>
        <p>Konsistensi Judul Dinamis, Anti-Truncate Label Toggle, & Sinkronisasi Total Foto Real-time</p>
      </div>
    </div>
    <div class="badge-group">
      <div class="version-tag">v2.0.47 Release</div>
      <div class="success-tag">169/169 Tests Passed (100%)</div>
    </div>
  </div>

  <!-- Dual Comparison Grid -->
  <div class="preview-grid">
    
    <!-- KOLOM KIRI: MODE SERVER & KASIR -->
    <div class="col-container">
      <div class="dialog-top">
        <div class="dialog-title-row">
          <h2><span>🖥️</span> Maintenance: Server & Kasir</h2>
          <span style="font-size:10px; font-weight:800; background:#DBEAFE; color:#1D4ED8; padding:2px 7px; border-radius:6px;">MODE AKTIF</span>
        </div>
        <div class="dialog-subtitle">Pemeriksaan PC Server dan PC Kasir</div>
      </div>

      <div>
        <div class="field-label" style="margin-bottom:5px;">Pilihan Ruang Lingkup Maintenance:</div>
        <div class="scope-selector">
          <div class="scope-btn active">🖥️ Server & Kasir ✓</div>
          <div class="scope-btn">🛒 Hanya Kasir</div>
        </div>
      </div>

      <!-- Toggle State 1: ON (Terpisah) -->
      <div class="toggle-box">
        <div class="toggle-text">
          <h4>PC Server & PC Kasir Terpisah</h4>
          <span class="toggle-pill on">ON: Terpisah (Komputer Berbeda)</span>
          <p class="toggle-desc">Komputer berbeda (PC Server & PC Kasir terpisah)</p>
        </div>
        <div class="switch-graphic active">
          <div class="switch-knob"></div>
        </div>
      </div>

      <!-- Stepper Unit Kasir (Muncul saat ON) -->
      <div class="stepper-box">
        <div class="stepper-info">
          <h4>Jumlah PC Kasir</h4>
          <p>Tentukan jumlah kasir pos yang diperiksa</p>
        </div>
        <div class="stepper-controls">
          <div class="btn-circle">-</div>
          <div class="count-val">2</div>
          <div class="btn-circle">+</div>
        </div>
      </div>

      <!-- Total Kalkulasi ON -->
      <div class="summary-card">
        <div class="summary-title">
          <span>✅</span>
          <span>Total Wajib: 18 Foto (1 Server + 2 Kasir)</span>
        </div>
        <div class="summary-sub">6 foto Server + 12 foto Kasir (2 unit × 6 foto) • Real-time</div>
      </div>

      <!-- State Alternatif: OFF (Gabung) -->
      <div class="mini-comparison">
        <div class="mini-title">
          <span>🔄 KETIKA TOGGLE DIUBAH KE OFF (GABUNG)</span>
          <span class="toggle-pill off">OFF: Gabung (1 Komputer)</span>
        </div>
        <p style="font-size:10px; color:#64748B; margin-bottom:4px;">Stepper Kasir otomatis tersembunyi. Dihitung sebagai 1 unit komputer All-in-One.</p>
        <div style="font-size:10.5px; font-weight:700; color:#047857;">Total Wajib: 6 Foto (1 Unit PC Server & Kasir Gabung)</div>
      </div>

      <button class="action-btn">Mulai Form Checklist (18 Foto) ➔</button>
    </div>

    <!-- KOLOM KANAN: MODE HANYA KASIR -->
    <div class="col-container">
      <div class="dialog-top">
        <div class="dialog-title-row">
          <h2><span>🛒</span> Maintenance: Kasir</h2>
          <span style="font-size:10px; font-weight:800; background:#DCFCE7; color:#15803D; padding:2px 7px; border-radius:6px;">MODE AKTIF</span>
        </div>
        <div class="dialog-subtitle">Pemeriksaan Unit PC Kasir</div>
      </div>

      <div>
        <div class="field-label" style="margin-bottom:5px;">Pilihan Ruang Lingkup Maintenance:</div>
        <div class="scope-selector">
          <div class="scope-btn">🖥️ Server & Kasir</div>
          <div class="scope-btn active">🛒 Hanya Kasir ✓</div>
        </div>
      </div>

      <div style="background:#F1F5F9; border-radius:8px; padding:8px 10px; font-size:11px; color:#475569; display:flex; align-items:center; gap:6px;">
        <span>ℹ️</span>
        <span>Toggle Server otomatis dinonaktifkan. Langsung tentukan unit Kasir.</span>
      </div>

      <!-- Stepper Unit Kasir (Hanya Kasir) -->
      <div class="stepper-box">
        <div class="stepper-info">
          <h4>Jumlah PC Kasir</h4>
          <p>Tentukan jumlah kasir pos yang diperiksa</p>
        </div>
        <div class="stepper-controls">
          <div class="btn-circle">-</div>
          <div class="count-val">2</div>
          <div class="btn-circle">+</div>
        </div>
      </div>

      <!-- Total Kalkulasi Hanya Kasir -->
      <div class="summary-card">
        <div class="summary-title">
          <span>✅</span>
          <span>Total Wajib: 12 Foto (2 PC Kasir)</span>
        </div>
        <div class="summary-sub">12 foto SOP PC Kasir (2 unit × 6 foto) • Real-time</div>
      </div>

      <!-- Output Laporan WA -->
      <div class="sub-box">
        <div class="sub-header">📱 HEADER & FORMAT LAPORAN ADAPTIF</div>Izin melaporkan hasil maintenance Komputer Kasir

Lokasi : Pasar Bersehati Manado (PBM)
Perangkat : 2 PC Kasir
Hasil : 12/12 Sesuai (100%)
• PC Kasir 1: 6 Foto (Storage, Firewall, Keyboard, Debu CPU, USB, LAN)
• PC Kasir 2: 6 Foto (Storage, Firewall, Keyboard, Debu CPU, USB, LAN)</div>

      <button class="action-btn" style="background:#059669;">Mulai Form Checklist (12 Foto) ➔</button>
    </div>

  </div>

  <!-- Bottom Badges -->
  <div class="feature-pills">
    <div class="feat-item"><div class="feat-dot"></div> Judul Dinamis: "Maintenance: Kasir" vs "Maintenance: Server & Kasir"</div>
    <div class="feat-item"><div class="feat-dot"></div> Toggle Anti-Truncate: 2 Baris + Badge "ON: Terpisah" / "OFF: Gabung"</div>
    <div class="feat-item"><div class="feat-dot"></div> Sinkronisasi Otomatis: Jumlah Unit & Total Foto Real-time</div>
    <div class="feat-item"><div class="feat-dot"></div> Zero Bug / Zero Regression: 169/169 Tests Pass</div>
  </div>
</div>

</body>
</html>
`;

const htmlPath = path.join(OUT_DIR, 'preview.html');
const pngPath = path.join(OUT_DIR, 'bss_maintenance_scope_preview.png');

fs.writeFileSync(htmlPath, htmlContent, 'utf8');

try {
  execSync(
    `google-chrome-stable --headless=new --disable-gpu --no-sandbox --hide-scrollbars --screenshot="${pngPath}" --window-size=1260,860 "file://${htmlPath}"`,
    { stdio: 'inherit' }
  );
  console.log(`[Preview Generated] Output saved to ${pngPath}`);
  console.log(`Size: ${fs.statSync(pngPath).size} bytes`);
} catch (err) {
  console.error('[Preview Error]', err.message);
  process.exit(1);
}
