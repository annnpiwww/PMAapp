const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const OUT_DIR = '/home/annnpii/Product development annpii/BssparkingTimeMark';

const htmlContent = `<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>PMA App - Daily Task Workflow: Dark Mode & Light Mode (CP-06)</title>
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
    font-size: 15px;
    font-weight: 700;
    color: #E2E8F0;
  }

  .phone-frame {
    width: 380px;
    height: 720px;
    border-radius: 36px;
    border: 8px solid #1E293B;
    overflow: hidden;
    position: relative;
    box-shadow: 0 20px 50px rgba(0, 0, 0, 0.6);
    display: flex;
    flex-direction: column;
  }

  /* ---------------- PHONE 1: DARK MODE (DAILY TASK LIST) ---------------- */
  .phone-dark {
    background: #0B1120;
    color: #F8FAFC;
  }

  .appbar-dark {
    background: #111827;
    padding: 14px 16px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px solid #1E293B;
  }

  .card-dark {
    background: #111827;
    border: 1px solid #1E293B;
    border-radius: 14px;
    padding: 14px;
    margin-bottom: 12px;
  }

  /* ---------------- PHONE 2: LIGHT MODE (DAILY TASK LIST) ---------------- */
  .phone-light {
    background: #FAF8F5;
    color: #0F172A;
  }

  .appbar-light {
    background: #1E448D;
    padding: 14px 16px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    color: #FFFFFF;
  }

  .card-light {
    background: #FFFFFF;
    border: 1px solid #E2E8F0;
    border-radius: 14px;
    padding: 14px;
    margin-bottom: 12px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.02);
  }

  /* ---------------- PHONE 3: TASK EXECUTION & SHARE DIALOG ---------------- */
  .modal-dialog-preview {
    background: #111827;
    border: 1px solid #1E293B;
    border-radius: 18px;
    padding: 18px;
    margin: 20px 14px;
    box-shadow: 0 10px 25px rgba(0,0,0,0.5);
  }

  .dialog-top-title {
    display: flex;
    align-items: center;
    gap: 8px;
    color: #10B981;
    font-size: 15px;
    font-weight: 800;
    margin-bottom: 8px;
  }

  .report-box-mono {
    background: #06090F;
    border: 1px solid #334155;
    border-radius: 8px;
    padding: 12px;
    font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
    font-size: 11px;
    line-height: 1.45;
    color: #E2E8F0;
    margin: 12px 0;
  }

  .callout-box {
    margin-top: 14px;
    background: #111827;
    border: 1px solid #1F2937;
    border-radius: 12px;
    padding: 12px 14px;
    width: 380px;
  }

  .callout-title {
    font-size: 13px;
    font-weight: 700;
    color: #F8FAFC;
    margin-bottom: 4px;
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .callout-desc {
    font-size: 11.5px;
    color: #94A3B8;
    line-height: 1.45;
  }
</style>
</head>
<body>

<div class="canvas">
  <div class="header">
    <div class="brand-badge-box">
      <div class="pma-logo-box">PMA</div>
      <div class="title-meta">
        <h1>Checkpoint 6: Daily Task Workflow Showcase</h1>
        <p>Support Dark Mode &amp; Light Mode • Photo Deck • Format Laporan Ringkas &amp; Share WA/TG</p>
      </div>
    </div>
    <div class="status-tag">🟢 CHECKPOINT 6 READY</div>
  </div>

  <div class="grid">
    <!-- Screen 1: Dark Mode -->
    <div class="screen-col">
      <div class="screen-label">
        <span class="num">1</span>
        <h3>Daily Task — Dark Mode</h3>
      </div>
      <div class="phone-frame phone-dark">
        <div class="appbar-dark">
          <div>
            <div style="font-size:15px; font-weight:800; color:#FFF;">Daily Task</div>
            <div style="font-size:11px; color:#94A3B8;">Junifer Manua • IT Support KC BSG</div>
          </div>
          <div style="display:flex; gap:10px;">
            <div style="font-size:16px;">🌙</div>
            <div style="font-size:16px;">🔄</div>
          </div>
        </div>

        <div style="padding:14px; overflow-y:auto; flex:1;">
          <!-- Status Banner -->
          <div class="card-dark" style="display:flex; justify-content:space-between; align-items:center;">
            <div>
              <div style="font-size:11px; color:#94A3B8;">Status Pengerjaan</div>
              <div style="font-size:15px; font-weight:800; color:#FFF; margin-top:2px;">2 dari 3 Selesai</div>
            </div>
            <div style="background:rgba(255,101,0,0.15); border:1px solid #FF6500; color:#FF6500; padding:4px 10px; border-radius:6px; font-size:11px; font-weight:800;">
              1 Belum
            </div>
          </div>

          <!-- Task Card 1 (Done) -->
          <div class="card-dark" style="border-color:rgba(16,185,129,0.3);">
            <div style="display:flex; justify-content:space-between; margin-bottom:8px;">
              <span style="background:rgba(59,130,246,0.15); border:1px solid rgba(59,130,246,0.35); color:#60A5FA; font-size:10px; font-weight:800; padding:2px 8px; border-radius:4px;">Maintenance</span>
              <span style="background:rgba(16,185,129,0.15); border:1px solid rgba(16,185,129,0.35); color:#10B981; font-size:10px; font-weight:800; padding:2px 8px; border-radius:4px;">Selesai</span>
            </div>
            <div style="font-size:13.5px; font-weight:700; color:#94A3B8; text-decoration:line-through;">Checklist Berkala Barrier Gate Keluar</div>
            <div style="font-size:11px; color:#94A3B8; margin-top:4px;">📍 Pos 2 • 08:30 WITA</div>
            <div style="margin-top:10px; border-top:1px solid #1E293B; padding-top:8px;">
              <div style="border:1px solid #10B981; color:#10B981; text-align:center; padding:6px; border-radius:8px; font-size:11px; font-weight:700;">Lihat Hasil Laporan</div>
            </div>
          </div>

          <!-- Task Card 2 (Pending) -->
          <div class="card-dark">
            <div style="display:flex; justify-content:space-between; margin-bottom:8px;">
              <span style="background:rgba(245,158,11,0.15); border:1px solid rgba(245,158,11,0.35); color:#FBBF24; font-size:10px; font-weight:800; padding:2px 8px; border-radius:4px;">Tugas Khusus</span>
              <span style="background:rgba(245,158,11,0.15); border:1px solid rgba(245,158,11,0.35); color:#FBBF24; font-size:10px; font-weight:800; padding:2px 8px; border-radius:4px;">Baru</span>
            </div>
            <div style="font-size:13.5px; font-weight:700; color:#FFF;">Pembersihan &amp; Ganti Thermal Paper Kasir</div>
            <div style="font-size:11px; color:#FF6500; font-weight:600; margin-top:4px;">📍 Pos Kasir 1 • 10:00 WITA</div>
            <div style="margin-top:10px;">
              <div style="background:#1E448D; color:#FFF; text-align:center; padding:8px; border-radius:8px; font-size:11.5px; font-weight:800; box-shadow:0 3px 10px rgba(30,68,141,0.3);">Kerjakan Tugas Sekarang →</div>
            </div>
          </div>
        </div>
      </div>
      <div class="callout-box">
        <div class="callout-title">🌙 Dark Mode Native</div>
        <div class="callout-desc">Tampilan gelap kontras tinggi, hemat baterai perangkat di lapangan, teks jernih terbaca.</div>
      </div>
    </div>

    <!-- Screen 2: Light Mode -->
    <div class="screen-col">
      <div class="screen-label">
        <span class="num">2</span>
        <h3>Daily Task — Light Mode</h3>
      </div>
      <div class="phone-frame phone-light">
        <div class="appbar-light">
          <div>
            <div style="font-size:15px; font-weight:800; color:#FFF;">Daily Task</div>
            <div style="font-size:11px; color:rgba(255,255,255,0.8);">Junifer Manua • IT Support KC BSG</div>
          </div>
          <div style="display:flex; gap:10px;">
            <div style="font-size:16px;">☀️</div>
            <div style="font-size:16px;">🔄</div>
          </div>
        </div>

        <div style="padding:14px; overflow-y:auto; flex:1;">
          <!-- Status Banner -->
          <div class="card-light" style="display:flex; justify-content:space-between; align-items:center;">
            <div>
              <div style="font-size:11px; color:#64748B;">Status Pengerjaan</div>
              <div style="font-size:15px; font-weight:800; color:#0F172A; margin-top:2px;">2 dari 3 Selesai</div>
            </div>
            <div style="background:#FFF4ED; border:1px solid #FF6500; color:#FF6500; padding:4px 10px; border-radius:6px; font-size:11px; font-weight:800;">
              1 Belum
            </div>
          </div>

          <!-- Task Card 1 (Done) -->
          <div class="card-light" style="border-color:#A7F3D0;">
            <div style="display:flex; justify-content:space-between; margin-bottom:8px;">
              <span style="background:#EFF6FF; border:1px solid #BFDBFE; color:#1E448D; font-size:10px; font-weight:800; padding:2px 8px; border-radius:4px;">Maintenance</span>
              <span style="background:#ECFDF5; border:1px solid #A7F3D0; color:#059669; font-size:10px; font-weight:800; padding:2px 8px; border-radius:4px;">Selesai</span>
            </div>
            <div style="font-size:13.5px; font-weight:700; color:#94A3B8; text-decoration:line-through;">Checklist Berkala Barrier Gate Keluar</div>
            <div style="font-size:11px; color:#64748B; margin-top:4px;">📍 Pos 2 • 08:30 WITA</div>
            <div style="margin-top:10px; border-top:1px solid #F1F5F9; padding-top:8px;">
              <div style="border:1px solid #059669; color:#059669; text-align:center; padding:6px; border-radius:8px; font-size:11px; font-weight:700;">Lihat Hasil Laporan</div>
            </div>
          </div>

          <!-- Task Card 2 (Pending) -->
          <div class="card-light">
            <div style="display:flex; justify-content:space-between; margin-bottom:8px;">
              <span style="background:#FFFBEB; border:1px solid #FDE68A; color:#B45309; font-size:10px; font-weight:800; padding:2px 8px; border-radius:4px;">Tugas Khusus</span>
              <span style="background:#FFF7ED; border:1px solid #FFEDD5; color:#C2410C; font-size:10px; font-weight:800; padding:2px 8px; border-radius:4px;">Baru</span>
            </div>
            <div style="font-size:13.5px; font-weight:700; color:#0F172A;">Pembersihan &amp; Ganti Thermal Paper Kasir</div>
            <div style="font-size:11px; color:#FF6500; font-weight:600; margin-top:4px;">📍 Pos Kasir 1 • 10:00 WITA</div>
            <div style="margin-top:10px;">
              <div style="background:#1E448D; color:#FFF; text-align:center; padding:8px; border-radius:8px; font-size:11.5px; font-weight:800; box-shadow:0 3px 10px rgba(30,68,141,0.2);">Kerjakan Tugas Sekarang →</div>
            </div>
          </div>
        </div>
      </div>
      <div class="callout-box">
        <div class="callout-title">☀️ Light Mode Bersih</div>
        <div class="callout-desc">Warna latar putih hangat, selaras dengan tema splash screen &amp; branding signature PMA App.</div>
      </div>
    </div>

    <!-- Screen 3: Pengerjaan & Share WA/TG -->
    <div class="screen-col">
      <div class="screen-label">
        <span class="num">3</span>
        <h3>Pengerjaan &amp; Share WA / TG</h3>
      </div>
      <div class="phone-frame" style="background:#0F172A;">
        <div class="modal-dialog-preview">
          <div class="dialog-top-title">
            <span>✓</span> Laporan Tersimpan
          </div>
          <div style="font-size:11.5px; color:#94A3B8;">Tugas telah ditandai selesai dan tersimpan di database.</div>

          <div class="report-box-mono">
Laporan Daily Hari ini<br>
Teknisi : Junifer Manua<br>
Tanggal : 04 oktober 2026<br>
Lokasi : TBM<br>
Pekerjaan : Ganti Thermal Paper Kasir<br>
Status : Selesai (10:25 WITA)<br>
-----<br>
Catatan :<br>
Kertas thermal diganti 1 roll baru, print test receipt jernih.
          </div>

          <div style="display:flex; gap:10px; margin-top:10px;">
            <div style="flex:1; border:1px solid #334155; color:#94A3B8; text-align:center; padding:10px; border-radius:8px; font-size:11.5px; font-weight:700;">Tutup</div>
            <div style="flex:2; background:#059669; color:#FFF; text-align:center; padding:10px; border-radius:8px; font-size:11.5px; font-weight:800; display:flex; align-items:center; justify-content:center; gap:6px;">
              <span>📲</span> Kirim ke WA / TG
            </div>
          </div>
        </div>
      </div>
      <div class="callout-box">
        <div class="callout-title">📲 1-Tap Share ke WA &amp; TG</div>
        <div class="callout-desc">Teks laporan otomatis diformat rapi standar IT Support KC BSG, siap dikirim ke grup koordinasi kantor.</div>
      </div>
    </div>

  </div>
</div>

</body>
</html>
`;

const htmlPath = path.join(OUT_DIR, 'PMA-App-Daily-Task-Showcase.html');
fs.writeFileSync(htmlPath, htmlContent);

const outPngPath = path.join(OUT_DIR, 'PMA-App-Daily-Task-Showcase.png');
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
