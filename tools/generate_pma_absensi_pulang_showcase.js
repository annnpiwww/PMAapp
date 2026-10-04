const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const OUT_DIR = '/home/annnpii/Product development annpii/BssparkingTimeMark';

const htmlContent = `<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>PMA App - Absensi & Daily Pulang Workflow Showcase (CP-07)</title>
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
    background: #0F172A;
    border-radius: 36px;
    border: 8px solid #1E293B;
    overflow: hidden;
    position: relative;
    box-shadow: 0 20px 50px rgba(0, 0, 0, 0.6);
    display: flex;
    flex-direction: column;
  }

  /* ---------------- PHONE 1: ATUR SHIFT MODAL ---------------- */
  .modal-white-sheet {
    background: #FFFFFF;
    color: #0F172A;
    border-top-left-radius: 28px;
    border-top-right-radius: 28px;
    padding: 20px 18px;
    margin-top: auto;
    border-top: 3px solid #1E448D;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .sheet-handle {
    width: 40px;
    height: 4px;
    background: #CBD5E1;
    border-radius: 2px;
    align-self: center;
    margin-bottom: 4px;
  }

  .shift-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
    margin-top: 8px;
  }

  .shift-card {
    border: 1.5px solid #E2E8F0;
    border-radius: 12px;
    padding: 10px;
    background: #F8FAFC;
    cursor: pointer;
  }

  .shift-card.active {
    border-color: #1E448D;
    background: #EFF6FF;
  }

  .shift-name {
    font-weight: 800;
    font-size: 12.5px;
    color: #0F172A;
  }

  .shift-card.active .shift-name {
    color: #1E448D;
  }

  .shift-time {
    font-size: 11px;
    color: #64748B;
    margin-top: 2px;
  }

  /* ---------------- PHONE 2: GROOMING SERAGAM AI ---------------- */
  .grooming-container {
    background: #0F172A;
    height: 100%;
    display: flex;
    flex-direction: column;
    justify-content: flex-end;
  }

  .ai-result-sheet {
    background: #FFFFFF;
    color: #0F172A;
    border-top-left-radius: 28px;
    border-top-right-radius: 28px;
    border-top: 3.5px solid #10B981;
    padding: 20px 18px;
  }

  .ai-badge-success {
    background: #ECFDF5;
    border: 1px solid #A7F3D0;
    border-radius: 12px;
    padding: 12px;
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 14px;
  }

  .ai-badge-success .icon {
    font-size: 20px;
    color: #059669;
  }

  .ai-badge-success h4 {
    font-size: 13px;
    font-weight: 800;
    color: #065F46;
  }

  .ai-badge-success p {
    font-size: 11px;
    color: #047857;
    margin-top: 2px;
  }

  /* ---------------- PHONE 3: DAILY PULANG HANDOVER ---------------- */
  .pulang-sheet {
    background: #FFFFFF;
    color: #0F172A;
    border-top-left-radius: 28px;
    border-top-right-radius: 28px;
    border-top: 3.5px solid #FF6500;
    padding: 20px 18px;
    margin-top: auto;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .auto-fill-box {
    background: #F8FAFC;
    border: 1px solid #CBD5E1;
    border-radius: 10px;
    padding: 10px 12px;
    font-family: ui-monospace, SFMono-Regular, monospace;
    font-size: 11px;
    color: #334155;
    line-height: 1.45;
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
        <h1>Checkpoint 7: Absensi &amp; Daily Pulang Workflow Showcase</h1>
        <p>Jadwal Shift • Verifikasi AI Grooming Seragam BSS • Auto-Fill Handover Pulang</p>
      </div>
    </div>
    <div class="status-tag">🟢 CHECKPOINT 7 COMPLETE</div>
  </div>

  <div class="grid">
    <!-- Screen 1: Atur Shift Modal -->
    <div class="screen-col">
      <div class="screen-label">
        <span class="num">1</span>
        <h3>Atur Shift Kerja &amp; Kategori</h3>
      </div>
      <div class="phone-frame">
        <div style="flex:1; background:radial-gradient(circle, #1E293B, #0F172A); display:flex; align-items:center; justify-content:center;">
          <div style="color:#64748B; font-size:12px;">Viewfinder Background</div>
        </div>

        <div class="modal-white-sheet">
          <div class="sheet-handle"></div>
          <div>
            <div style="font-size:15px; font-weight:800; color:#0F172A;">Atur Jadwal Shift Kerja</div>
            <div style="font-size:11.5px; color:#64748B;">Pilih jadwal kerja Anda hari ini</div>
          </div>

          <div class="shift-grid">
            <div class="shift-card active">
              <div class="shift-name">Shift 1 (Pagi)</div>
              <div class="shift-time">03:00 - 11:00 WITA</div>
            </div>
            <div class="shift-card">
              <div class="shift-name">Shift 2.1 (Normal)</div>
              <div class="shift-time">07:00 - 15:00 WITA</div>
            </div>
            <div class="shift-card">
              <div class="shift-name">Shift 2.2 (Mid)</div>
              <div class="shift-time">10:00 - 14:00 WITA</div>
            </div>
            <div class="shift-card">
              <div class="shift-name">Shift 3 (Malam)</div>
              <div class="shift-time">15:00 - 23:00 WITA</div>
            </div>
          </div>

          <div style="margin-top:10px;">
            <div style="background:#1E448D; color:#FFF; text-align:center; padding:12px; border-radius:10px; font-size:12.5px; font-weight:800;">Simpan Jadwal Shift →</div>
          </div>
        </div>
      </div>
      <div class="callout-box">
        <div class="callout-title">⏱️ 4 Pilihan Shift Terstandar</div>
        <div class="callout-desc">Tersedia shift 8 jam dan shift 4 jam dengan kalkulasi durasi kerja minimal otomatis.</div>
      </div>
    </div>

    <!-- Screen 2: Grooming Seragam AI -->
    <div class="screen-col">
      <div class="screen-label">
        <span class="num">2</span>
        <h3>Verifikasi Grooming Seragam BSS</h3>
      </div>
      <div class="phone-frame">
        <div class="grooming-container">
          <div style="flex:1; background:radial-gradient(circle, #1E293B, #0F172A); display:flex; align-items:center; justify-content:center;">
            <div style="color:#64748B; font-size:12px;">Foto Selfie Teknisi</div>
          </div>

          <div class="ai-result-sheet">
            <div class="sheet-handle"></div>
            <div class="ai-badge-success">
              <span class="icon">✓</span>
              <div>
                <h4>Grooming Lolos Verifikasi (98%)</h4>
                <p>Seragam resmi BSS &amp; ID Card terdeteksi sempurna</p>
              </div>
            </div>

            <div style="background:#F8FAFC; border:1px solid #E2E8F0; border-radius:10px; padding:10px; font-size:11.5px; color:#475569; margin-bottom:12px;">
              <div>• Kemeja Seragam BSS : <b>Sesuai Standar</b></div>
              <div>• Kerapian Rambut/Penampilan : <b>Rapi</b></div>
              <div>• ID Card / Tanda Pengenal : <b>Terbaca</b></div>
            </div>

            <div style="background:#059669; color:#FFF; text-align:center; padding:12px; border-radius:10px; font-size:12.5px; font-weight:800;">Lanjut Absensi Masuk (WITA) →</div>
          </div>
        </div>
      </div>
      <div class="callout-box">
        <div class="callout-title">👔 Standar Penampilan BSS</div>
        <div class="callout-desc">AI memverifikasi atribut seragam resmi BSS untuk menjamin kredibilitas teknisi di lokasi mitra KC BSG.</div>
      </div>
    </div>

    <!-- Screen 3: Daily Pulang Handover -->
    <div class="screen-col">
      <div class="screen-label">
        <span class="num">3</span>
        <h3>Handover Shift &amp; Auto-Fill Pulang</h3>
      </div>
      <div class="phone-frame">
        <div style="flex:1; background:radial-gradient(circle, #1E293B, #0F172A); display:flex; align-items:center; justify-content:center;">
          <div style="color:#64748B; font-size:12px;">Kamera Viewfinder Pulang</div>
        </div>

        <div class="pulang-sheet">
          <div class="sheet-handle"></div>
          <div>
            <div style="font-size:15px; font-weight:800; color:#0F172A;">Isi Daily Handover Pulang</div>
            <div style="font-size:11.5px; color:#64748B;">Pekerjaan hari ini otomatis terisi ke form</div>
          </div>

          <div>
            <div style="font-size:11.5px; font-weight:700; color:#475569; margin-bottom:4px;">Teknisi Pengganti Shift:</div>
            <div style="background:#F8FAFC; border:1px solid #CBD5E1; border-radius:8px; padding:8px 10px; font-size:12px; font-weight:600; color:#1E448D;">
              👤 Ryan Lumasuge (Shift 2)
            </div>
          </div>

          <div>
            <div style="font-size:11.5px; font-weight:700; color:#475569; margin-bottom:4px;">Pekerjaan Selesai (Auto-Filled):</div>
            <div class="auto-fill-box">
1. [✓] Maintenance: Pos Kasir (TBM)<br>
2. [✓] Ganti Thermal Paper Kasir<br>
3. [✓] Pengecekan Kabel LAN Server
            </div>
          </div>

          <div style="margin-top:6px;">
            <div style="background:#FF6500; color:#FFF; text-align:center; padding:12px; border-radius:10px; font-size:12.5px; font-weight:800;">Simpan Handover &amp; Foto Pulang →</div>
          </div>
        </div>
      </div>
      <div class="callout-box">
        <div class="callout-title">🔄 Seamless Handover Shift</div>
        <div class="callout-desc">Tugas maintenance &amp; daily task otomatis masuk ke form tanpa perlu mengetik ulang saat serah terima pos.</div>
      </div>
    </div>

  </div>
</div>

</body>
</html>
`;

const htmlPath = path.join(OUT_DIR, 'PMA-App-Absensi-Pulang-Showcase.html');
fs.writeFileSync(htmlPath, htmlContent);

const outPngPath = path.join(OUT_DIR, 'PMA-App-Absensi-Pulang-Showcase.png');
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
