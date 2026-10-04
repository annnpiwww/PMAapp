const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const OUT_DIR = '/tmp/opencode/audit_visuals';
if (!fs.existsSync(OUT_DIR)) {
  fs.mkdirSync(OUT_DIR, { recursive: true });
}

// Helper: render HTML file and screenshot via Chrome headless
function renderScreenshot(htmlContent, fileName, width = 390, height = 844) {
  const htmlPath = path.join(OUT_DIR, `${fileName}.html`);
  const pngPath = path.join(OUT_DIR, `${fileName}.png`);
  fs.writeFileSync(htmlPath, htmlContent, 'utf8');

  try {
    execSync(
      `google-chrome-stable --headless=new --disable-gpu --no-sandbox --hide-scrollbars --screenshot="${pngPath}" --window-size=${width},${height} "file://${htmlPath}"`,
      { stdio: 'pipe' }
    );
    console.log(`[Visual Eyes] Rendered ${fileName}.png (${width}x${height})`);
    return pngPath;
  } catch (err) {
    console.error(`[Visual Eyes Error] Failed rendering ${fileName}:`, err.message);
    return null;
  }
}

// 1. Camera HUD Idle (Belum Absen Masuk)
function renderCameraHudIdle() {
  return `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
  body { width: 390px; height: 844px; background: #000; color: #fff; position: relative; overflow: hidden; }
  .viewfinder { width: 100%; height: 100%; position: absolute; background: linear-gradient(180deg, #111827 0%, #1e293b 50%, #0f172a 100%); display: flex; flex-direction: column; justify-content: space-between; padding: 16px; }
  
  /* Top Bar */
  .top-bar { display: flex; justify-content: space-between; align-items: center; padding-top: 24px; z-index: 10; }
  .icon-btn { width: 40px; height: 40px; border-radius: 20px; background: rgba(0,0,0,0.45); display: flex; align-items: center; justify-content: center; font-size: 14px; border: 1px solid rgba(255,255,255,0.15); backdrop-filter: blur(8px); }
  .ai-pill { display: flex; align-items: center; gap: 6px; padding: 6px 12px; border-radius: 20px; background: rgba(16,185,129,0.18); border: 1px solid #10B981; color: #10B981; font-weight: 700; font-size: 11.5px; }
  .dot-pulse { width: 8px; height: 8px; border-radius: 4px; background: #10B981; }

  /* Watermark Card */
  .watermark-container { margin-top: auto; margin-bottom: 20px; z-index: 10; }
  .wm-card { background: rgba(15,23,42,0.85); border: 1px solid rgba(255,255,255,0.15); border-radius: 14px; padding: 14px; backdrop-filter: blur(12px); box-shadow: 0 8px 32px rgba(0,0,0,0.5); }
  .wm-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
  .badge-tag { background: #3B82F6; color: #fff; font-weight: 800; font-size: 11px; padding: 3px 8px; border-radius: 6px; letter-spacing: 0.5px; }
  .wm-title { font-weight: 800; font-size: 13px; color: #F1F5F9; }
  .wm-code { font-family: monospace; font-size: 11px; color: #94A3B8; }
  .wm-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; font-size: 11px; margin-top: 6px; }
  .wm-row { display: flex; flex-direction: column; }
  .wm-label { color: #64748B; font-size: 9.5px; text-transform: uppercase; font-weight: 700; }
  .wm-val { color: #E2E8F0; font-weight: 600; }
  .wm-address { grid-column: span 2; margin-top: 4px; padding-top: 4px; border-top: 1px solid rgba(255,255,255,0.08); font-size: 10.5px; color: #CBD5E1; }

  /* Bottom Controls */
  .bottom-bar { display: flex; flex-direction: column; align-items: center; gap: 14px; padding-bottom: 24px; z-index: 10; }
  .shortcut-shift-pill { display: flex; align-items: center; gap: 8px; padding: 8px 18px; border-radius: 24px; background: rgba(16,185,129,0.22); border: 1px solid #10B981; color: #34D399; font-weight: 700; font-size: 13px; box-shadow: 0 4px 16px rgba(16,185,129,0.2); }
  .shutter-row { display: flex; align-items: center; justify-content: space-around; width: 100%; }
  .shutter-outer { width: 72px; height: 72px; border-radius: 36px; border: 4px solid #fff; display: flex; align-items: center; justify-content: center; cursor: pointer; }
  .shutter-inner { width: 56px; height: 56px; border-radius: 28px; background: #fff; }
</style>
</head>
<body>
<div class="viewfinder">
  <div class="top-bar">
    <div class="icon-btn">⚙️</div>
    <div class="ai-pill"><div class="dot-pulse"></div>AI CLOUD</div>
    <div class="icon-btn">⚡</div>
    <div class="icon-btn">4:3</div>
    <div class="icon-btn">🔄</div>
  </div>

  <div class="watermark-container">
    <div class="wm-card">
      <div class="wm-header">
        <span class="badge-tag">PBM</span>
        <span class="wm-title">Pasar Bersehati Manado</span>
        <span class="wm-code">#BSS-789A</span>
      </div>
      <div class="wm-grid">
        <div class="wm-row"><span class="wm-label">Teknisi</span><span class="wm-val">Ryan Lumasuge</span></div>
        <div class="wm-row"><span class="wm-label">Waktu</span><span class="wm-val">13 Sep 2026 09:58 WITA</span></div>
        <div class="wm-row"><span class="wm-label">Shift</span><span class="wm-val">Shift 2 (10:00 - 18:00)</span></div>
        <div class="wm-row"><span class="wm-label">GPS Real</span><span class="wm-val">1.49305, 124.84197 (±2.8m)</span></div>
        <div class="wm-address">Jl. Nusantara No. 1, Calaca, Kec. Wenang, Kota Manado, Sulawesi Utara</div>
      </div>
    </div>
  </div>

  <div class="bottom-bar">
    <div class="shortcut-shift-pill">
      <span>🟢</span>
      <span>Masuk : Shift 2 (10:00 - 18:00) ▾</span>
    </div>
    <div class="shutter-row">
      <div class="icon-btn">🖼️</div>
      <div class="shutter-outer"><div class="shutter-inner"></div></div>
      <div class="icon-btn">📋</div>
    </div>
  </div>
</div>
</body>
</html>`;
}

// 2. Camera HUD Working (Sudah Absen Masuk -> Siap Pulang)
function renderCameraHudWorking() {
  return `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
  body { width: 390px; height: 844px; background: #000; color: #fff; position: relative; overflow: hidden; }
  .viewfinder { width: 100%; height: 100%; position: absolute; background: linear-gradient(180deg, #090d16 0%, #1e293b 50%, #0b1120 100%); display: flex; flex-direction: column; justify-content: space-between; padding: 16px; }
  .top-bar { display: flex; justify-content: space-between; align-items: center; padding-top: 24px; z-index: 10; }
  .icon-btn { width: 40px; height: 40px; border-radius: 20px; background: rgba(0,0,0,0.45); display: flex; align-items: center; justify-content: center; font-size: 14px; border: 1px solid rgba(255,255,255,0.15); }
  .ai-pill { display: flex; align-items: center; gap: 6px; padding: 6px 12px; border-radius: 20px; background: rgba(16,185,129,0.18); border: 1px solid #10B981; color: #10B981; font-weight: 700; font-size: 11.5px; }
  .dot-pulse { width: 8px; height: 8px; border-radius: 4px; background: #10B981; }

  .watermark-container { margin-top: auto; margin-bottom: 20px; z-index: 10; }
  .wm-card { background: rgba(15,23,42,0.85); border: 1px solid rgba(255,255,255,0.15); border-radius: 14px; padding: 14px; backdrop-filter: blur(12px); }
  .wm-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
  .badge-tag { background: #3B82F6; color: #fff; font-weight: 800; font-size: 11px; padding: 3px 8px; border-radius: 6px; }
  .wm-title { font-weight: 800; font-size: 13px; color: #F1F5F9; }
  .wm-code { font-family: monospace; font-size: 11px; color: #94A3B8; }
  .wm-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; font-size: 11px; margin-top: 6px; }
  .wm-row { display: flex; flex-direction: column; }
  .wm-label { color: #64748B; font-size: 9.5px; text-transform: uppercase; font-weight: 700; }
  .wm-val { color: #E2E8F0; font-weight: 600; }
  .wm-address { grid-column: span 2; margin-top: 4px; padding-top: 4px; border-top: 1px solid rgba(255,255,255,0.08); font-size: 10.5px; color: #CBD5E1; }

  .bottom-bar { display: flex; flex-direction: column; align-items: center; gap: 14px; padding-bottom: 24px; z-index: 10; }
  /* Pulang Pill Blue with Live Timer */
  .shortcut-shift-pill { display: flex; align-items: center; gap: 8px; padding: 8px 18px; border-radius: 24px; background: rgba(59,130,246,0.25); border: 1px solid #3B82F6; color: #60A5FA; font-weight: 700; font-size: 13px; box-shadow: 0 4px 16px rgba(59,130,246,0.25); }
  .shutter-row { display: flex; align-items: center; justify-content: space-around; width: 100%; }
  .shutter-outer { width: 72px; height: 72px; border-radius: 36px; border: 4px solid #3B82F6; display: flex; align-items: center; justify-content: center; }
  .shutter-inner { width: 56px; height: 56px; border-radius: 28px; background: #3B82F6; display: flex; align-items: center; justify-content: center; font-size: 20px; }
</style>
</head>
<body>
<div class="viewfinder">
  <div class="top-bar">
    <div class="icon-btn">⚙️</div>
    <div class="ai-pill"><div class="dot-pulse"></div>AI CLOUD</div>
    <div class="icon-btn">⚡</div>
    <div class="icon-btn">4:3</div>
    <div class="icon-btn">🔄</div>
  </div>

  <div class="watermark-container">
    <div class="wm-card">
      <div class="wm-header">
        <span class="badge-tag">PBM</span>
        <span class="wm-title">Pasar Bersehati Manado</span>
        <span class="wm-code">#BSS-902B</span>
      </div>
      <div class="wm-grid">
        <div class="wm-row"><span class="wm-label">Teknisi</span><span class="wm-val">Ryan Lumasuge</span></div>
        <div class="wm-row"><span class="wm-label">Waktu Pulang</span><span class="wm-val">13 Sep 2026 18:05 WITA</span></div>
        <div class="wm-row"><span class="wm-label">Durasi Kerja</span><span class="wm-val" style="color:#10B981">8 Jam 07 Menit (Selesai)</span></div>
        <div class="wm-row"><span class="wm-label">GPS Real</span><span class="wm-val">1.49305, 124.84197 (±2.1m)</span></div>
        <div class="wm-address">Jl. Nusantara No. 1, Calaca, Kec. Wenang, Kota Manado, Sulawesi Utara</div>
      </div>
    </div>
  </div>

  <div class="bottom-bar">
    <div class="shortcut-shift-pill">
      <span>🔵</span>
      <span>Pulang (Kerja: 08j 07m) ▾</span>
    </div>
    <div class="shutter-row">
      <div class="icon-btn">🖼️</div>
      <div class="shutter-outer"><div class="shutter-inner">🏠</div></div>
      <div class="icon-btn">📋</div>
    </div>
  </div>
</div>
</body>
</html>`;
}

// 3. Handover Pulang Modal (Laporan Daily Pulang)
function renderHandoverPulangModal() {
  return `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
  body { width: 390px; height: 844px; background: rgba(0,0,0,0.65); display: flex; align-items: flex-end; }
  .modal-sheet { width: 100%; background: #0F172A; border-top-left-radius: 24px; border-top-right-radius: 24px; padding: 22px; color: #fff; border-top: 1px solid rgba(255,255,255,0.15); }
  .drag-handle { width: 40px; height: 4px; border-radius: 2px; background: #334155; margin: 0 auto 16px auto; }
  .modal-title { font-size: 16px; font-weight: 800; color: #F8FAFC; margin-bottom: 4px; display: flex; align-items: center; gap: 8px; }
  .modal-subtitle { font-size: 12px; color: #94A3B8; margin-bottom: 18px; }
  
  .section-label { font-size: 12px; font-weight: 700; color: #CBD5E1; margin-bottom: 6px; display: flex; align-items: center; gap: 6px; }
  
  /* High Contrast Card (White card, Black Font) */
  .card-input { background: #FFFFFF; border-radius: 12px; padding: 12px 14px; margin-bottom: 14px; box-shadow: 0 2px 8px rgba(0,0,0,0.15); }
  .card-textarea { width: 100%; border: none; outline: none; resize: none; font-size: 13.5px; font-weight: 600; color: #0F172A; line-height: 1.5; background: transparent; height: 75px; }
  
  /* Toggle Pending Jobs */
  .toggle-row { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; padding: 6px 0; }
  .toggle-text { font-size: 12.5px; font-weight: 600; color: #E2E8F0; }
  .switch-mock { width: 44px; height: 24px; border-radius: 12px; background: #10B981; position: relative; display: flex; align-items: center; padding: 2px; }
  .switch-knob { width: 20px; height: 20px; border-radius: 10px; background: #fff; transform: translateX(20px); }
  
  /* Action Button (Orange Simpan) */
  .btn-simpan { width: 100%; padding: 14px; border-radius: 14px; background: #F59E0B; border: none; color: #000; font-size: 15px; font-weight: 800; display: flex; align-items: center; justify-content: center; gap: 8px; cursor: pointer; box-shadow: 0 4px 16px rgba(245,158,11,0.35); margin-top: 10px; }
</style>
</head>
<body>
<div class="modal-sheet">
  <div class="drag-handle"></div>
  <div class="modal-title">📋 Laporan Pekerjaan Shift Pulang</div>
  <div class="modal-subtitle">Ringkasan operasional sebelum absensi pulang tercatat</div>

  <div class="section-label">✅ Pekerjaan yang Telah Selesai</div>
  <div class="card-input">
    <textarea class="card-textarea" readonly>1. Pembersihan sensor barrier gate pos 1 dan 2
2. Refill thermal paper tiket dispenser manless
3. Pengecekan koneksi CCTV pos keluar normal</textarea>
  </div>

  <div class="toggle-row">
    <span class="toggle-text">⚠️ Ada Pekerjaan Belum Selesai (Pending)?</span>
    <div class="switch-mock"><div class="switch-knob"></div></div>
  </div>

  <div class="card-input">
    <textarea class="card-textarea" style="height: 48px;" readonly>1. Perbaikan kabel loop detector pos 2 tunggu teknisi sipil</textarea>
  </div>

  <button class="btn-simpan">
    <span>✓</span>
    <span>Simpan & Lanjut Foto Pulang</span>
  </button>
</div>
</body>
</html>`;
}

// 4. Riwayat Kerja Screen (Attendance Archive Screen)
function renderRiwayatKerjaScreen() {
  return `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
  body { width: 390px; height: 844px; background: #F8FAFC; color: #0F172A; }
  
  /* AppBar */
  .app-bar { height: 60px; background: #fff; display: flex; align-items: center; justify-content: space-between; padding: 0 16px; border-bottom: 1px solid #E2E8F0; }
  .app-title { font-size: 17px; font-weight: 800; color: #0F172A; }
  .app-actions { display: flex; gap: 12px; }

  .content { padding: 14px; display: flex; flex-direction: column; gap: 12px; }

  /* Profile Header */
  .profile-card { background: linear-gradient(135deg, #1E3A8A 0%, #2563EB 100%); border-radius: 14px; padding: 14px; color: #fff; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 4px 12px rgba(37,99,235,0.2); }
  .prof-name { font-size: 15px; font-weight: 800; }
  .prof-pos { font-size: 12px; opacity: 0.9; margin-top: 2px; }
  .prof-badge { background: rgba(255,255,255,0.2); padding: 4px 10px; border-radius: 20px; font-size: 11px; font-weight: 700; }

  /* Retention Warning Banner */
  .retention-banner { background: #FEF3C7; border: 1px solid #FCD34D; border-radius: 10px; padding: 10px 12px; font-size: 11.5px; color: #92400E; display: flex; align-items: center; gap: 8px; font-weight: 600; }

  /* KPI Summary 3 Cards */
  .kpi-row { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 10px; }
  .kpi-card { background: #fff; border-radius: 12px; padding: 12px 10px; border: 1px solid #E2E8F0; display: flex; flex-direction: column; align-items: center; text-align: center; }
  .kpi-title { font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase; margin-bottom: 4px; }
  .kpi-val { font-size: 20px; font-weight: 900; }
  .kpi-hadir { color: #10B981; }
  .kpi-pulang { color: #3B82F6; }
  .kpi-terlambat { color: #EF4444; }

  /* Record Cards */
  .rec-card { background: #fff; border-radius: 12px; padding: 14px; border: 1px solid #E2E8F0; display: flex; flex-direction: column; gap: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.05); }
  .rec-header { display: flex; justify-content: space-between; align-items: center; }
  .rec-shift { font-size: 13.5px; font-weight: 800; color: #1E293B; }
  .status-badge { font-size: 10.5px; font-weight: 800; padding: 3px 8px; border-radius: 6px; }
  .badge-tepat { background: #D1FAE5; color: #065F46; }
  .badge-terlambat { background: #FEE2E2; color: #991B1B; }

  .rec-body { display: flex; justify-content: space-between; font-size: 12px; color: #475569; }
  .rec-footer { font-size: 11px; color: #94A3B8; border-top: 1px solid #F1F5F9; padding-top: 6px; display: flex; justify-content: space-between; }
</style>
</head>
<body>
<div class="app-bar">
  <div class="app-title">Riwayat Kerja</div>
  <div class="app-actions">
    <span>📊 Export</span>
    <span>🗑️</span>
  </div>
</div>

<div class="content">
  <div class="profile-card">
    <div>
      <div class="prof-name">Ryan Lumasuge</div>
      <div class="prof-pos">📍 Pasar Bersehati Manado</div>
    </div>
    <div class="prof-badge">KC BSG</div>
  </div>

  <div class="retention-banner">
    <span>ℹ️</span>
    <span>Riwayat catatan absensi hanya tersimpan otomatis selama 30 hari</span>
  </div>

  <div class="kpi-row">
    <div class="kpi-card">
      <span class="kpi-title">Hadir</span>
      <span class="kpi-val kpi-hadir">14</span>
    </div>
    <div class="kpi-card">
      <span class="kpi-title">Pulang</span>
      <span class="kpi-val kpi-pulang">13</span>
    </div>
    <div class="kpi-card">
      <span class="kpi-title">Terlambat</span>
      <span class="kpi-val kpi-terlambat">1</span>
    </div>
  </div>

  <div class="rec-card">
    <div class="rec-header">
      <span class="rec-shift">Shift 2 (10:00 - 18:00)</span>
      <span class="status-badge badge-tepat">Tepat Waktu</span>
    </div>
    <div class="rec-body">
      <div>Masuk: <strong>09:58 WITA</strong></div>
      <div>Pulang: <strong>18:05 WITA</strong> (8j 07m)</div>
    </div>
    <div class="rec-footer">
      <span>13 Sep 2026</span>
      <span>Pasar Bersehati Manado • #BSS-789A</span>
    </div>
  </div>

  <div class="rec-card">
    <div class="rec-header">
      <span class="rec-shift">Shift 2 (10:00 - 18:00)</span>
      <span class="status-badge badge-terlambat">Terlambat (7m)</span>
    </div>
    <div class="rec-body">
      <div>Masuk: <strong>10:07 WITA</strong></div>
      <div>Pulang: <strong>18:10 WITA</strong> (8j 03m)</div>
    </div>
    <div class="rec-footer">
      <span>12 Sep 2026</span>
      <span>Pasar Bersehati Manado • #BSS-652D</span>
    </div>
  </div>
</div>
</body>
</html>`;
}

// 5. Maintenance Point Camera View
function renderMaintenancePointCamera() {
  return `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
  body { width: 390px; height: 844px; background: #000; color: #fff; position: relative; overflow: hidden; }
  .viewfinder { width: 100%; height: 100%; position: absolute; background: radial-gradient(circle at center, #1E293B 0%, #0F172A 100%); display: flex; flex-direction: column; justify-content: space-between; padding: 16px; }
  
  /* Top Bar (Clean, No Redundant Title) */
  .top-bar { display: flex; justify-content: space-between; align-items: center; padding-top: 24px; z-index: 10; }
  .icon-btn { width: 40px; height: 40px; border-radius: 20px; background: rgba(0,0,0,0.45); display: flex; align-items: center; justify-content: center; font-size: 14px; border: 1px solid rgba(255,255,255,0.15); }
  .shortcut-row { display: flex; align-items: center; gap: 8px; }
  .ai-pill { display: flex; align-items: center; gap: 6px; padding: 6px 12px; border-radius: 20px; background: rgba(16,185,129,0.22); border: 1px solid #10B981; color: #10B981; font-weight: 700; font-size: 11.5px; cursor: pointer; }
  
  /* Point Info Banner */
  .point-banner { background: rgba(30,41,59,0.85); border: 1px solid rgba(255,255,255,0.15); border-radius: 12px; padding: 10px 14px; margin-top: 14px; backdrop-filter: blur(8px); }
  .point-title { font-size: 13px; font-weight: 800; color: #F8FAFC; }
  .point-desc { font-size: 11px; color: #94A3B8; margin-top: 2px; }

  /* Watermark Card Maintenance */
  .watermark-container { margin-top: auto; margin-bottom: 20px; z-index: 10; }
  .wm-card { background: rgba(15,23,42,0.88); border: 1px solid rgba(255,255,255,0.15); border-radius: 14px; padding: 14px; backdrop-filter: blur(12px); }
  .wm-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
  .badge-tag { background: #F59E0B; color: #000; font-weight: 800; font-size: 11px; padding: 3px 8px; border-radius: 6px; }
  .wm-title { font-weight: 800; font-size: 13px; color: #F1F5F9; }
  .wm-code { font-family: monospace; font-size: 11px; color: #94A3B8; }
  .wm-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; font-size: 11px; margin-top: 6px; }
  .wm-row { display: flex; flex-direction: column; }
  .wm-label { color: #64748B; font-size: 9.5px; text-transform: uppercase; font-weight: 700; }
  .wm-val { color: #E2E8F0; font-weight: 600; }
  .wm-address { grid-column: span 2; margin-top: 4px; padding-top: 4px; border-top: 1px solid rgba(255,255,255,0.08); font-size: 10.5px; color: #CBD5E1; }

  /* Bottom Controls */
  .bottom-bar { display: flex; justify-content: space-around; align-items: center; padding-bottom: 24px; z-index: 10; }
  .shutter-outer { width: 72px; height: 72px; border-radius: 36px; border: 4px solid #F59E0B; display: flex; align-items: center; justify-content: center; }
  .shutter-inner { width: 56px; height: 56px; border-radius: 28px; background: #F59E0B; }
</style>
</head>
<body>
<div class="viewfinder">
  <div>
    <div class="top-bar">
      <div class="icon-btn">✕</div>
      <div class="shortcut-row">
        <div class="ai-pill">🟢 AI Cloud</div>
        <div class="icon-btn">⚡</div>
        <div class="icon-btn">4:3</div>
      </div>
    </div>
    <div class="point-banner">
      <div class="point-title">[Pos 1] Kebersihan Pos & Kaca</div>
      <div class="point-desc">Pastikan kaca bersih, bebas debu tebal dan stiker rusak</div>
    </div>
  </div>

  <div class="watermark-container">
    <div class="wm-card">
      <div class="wm-header">
        <span class="badge-tag">PBM</span>
        <span class="wm-title">Pasar Bersehati Manado</span>
        <span class="wm-code">#MNT-441K</span>
      </div>
      <div class="wm-grid">
        <div class="wm-row"><span class="wm-label">Item Maintenance</span><span class="wm-val">[Pos 1] Kebersihan Pos</span></div>
        <div class="wm-row"><span class="wm-label">Teknisi</span><span class="wm-val">Ryan Lumasuge</span></div>
        <div class="wm-row"><span class="wm-label">Waktu</span><span class="wm-val">13 Sep 2026 14:22 WITA</span></div>
        <div class="wm-row"><span class="wm-label">GPS Real</span><span class="wm-val">1.49305, 124.84197 (±2.5m)</span></div>
        <div class="wm-address">Jl. Nusantara No. 1, Calaca, Kec. Wenang, Kota Manado, Sulawesi Utara</div>
      </div>
    </div>
  </div>

  <div class="bottom-bar">
    <div class="icon-btn">🖼️</div>
    <div class="shutter-outer"><div class="shutter-inner"></div></div>
    <div class="icon-btn">💡</div>
  </div>
</div>
</body>
</html>`;
}

// Execute all renders
const rendered = [];
rendered.push(renderScreenshot(renderCameraHudIdle(), '01_camera_hud_idle'));
rendered.push(renderScreenshot(renderCameraHudWorking(), '02_camera_hud_working'));
rendered.push(renderScreenshot(renderHandoverPulangModal(), '03_handover_pulang_modal'));
rendered.push(renderScreenshot(renderRiwayatKerjaScreen(), '04_riwayat_kerja_screen'));
rendered.push(renderScreenshot(renderMaintenancePointCamera(), '05_maintenance_point_camera'));

console.log(`\n=== Visual Eyes Render Completed: ${rendered.filter(Boolean).length} screens generated ===\n`);
