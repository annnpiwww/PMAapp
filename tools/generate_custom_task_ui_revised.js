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
<title>BSS TimeMark - Revisi Desain Tugas Khusus & Pelaporan</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Plus Jakarta Sans", sans-serif; }
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
    width: 1240px;
    background: radial-gradient(circle at 10% 10%, #0F172A 0%, #06090E 90%);
    border-radius: 24px;
    border: 1px solid rgba(255, 255, 255, 0.12);
    box-shadow: 0 40px 100px rgba(0, 0, 0, 0.95);
    padding: 28px 32px;
  }

  /* Header Bar */
  .header-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
    padding-bottom: 18px;
    margin-bottom: 24px;
  }
  .brand-group {
    display: flex;
    align-items: center;
    gap: 14px;
  }
  .app-icon {
    width: 46px;
    height: 46px;
    background: #FFFFFF;
    border: 2px solid #FF6500;
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
  }
  .app-icon img {
    width: 38px;
    height: 38px;
    object-fit: contain;
  }
  .brand-meta h1 {
    font-size: 20px;
    font-weight: 800;
    color: #FFFFFF;
  }
  .brand-meta p {
    font-size: 13px;
    color: #94A3B8;
  }
  .pill {
    padding: 5px 12px;
    border-radius: 9999px;
    font-size: 11px;
    font-weight: 700;
    background: rgba(255, 101, 0, 0.15);
    color: #FF8A3D;
    border: 1px solid rgba(255, 101, 0, 0.35);
  }

  /* 3 Main Columns */
  .screens-grid {
    display: grid;
    grid-template-columns: 360px 400px 410px;
    gap: 20px;
    margin-bottom: 20px;
  }

  /* Phone Frame */
  .phone-frame {
    background: #0F172A;
    border-radius: 32px;
    border: 2px solid rgba(255, 255, 255, 0.14);
    box-shadow: 0 16px 40px rgba(0, 0, 0, 0.7);
    overflow: hidden;
    display: flex;
    flex-direction: column;
    height: 600px;
  }
  .phone-notch {
    height: 22px;
    background: #020617;
    display: flex;
    justify-content: center;
    align-items: center;
  }
  .phone-notch::before {
    content: '';
    width: 50px;
    height: 8px;
    background: #1E293B;
    border-radius: 999px;
  }
  .phone-header {
    background: #1E293B;
    padding: 12px 16px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  }
  .phone-header-title {
    font-size: 14px;
    font-weight: 700;
    color: #FFFFFF;
  }
  .phone-header-sub {
    font-size: 11px;
    color: #94A3B8;
  }
  .phone-body {
    flex: 1;
    padding: 14px;
    display: flex;
    flex-direction: column;
    gap: 12px;
    background: #0A0F1D;
  }

  .step-label {
    background: #1E293B;
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 8px;
    padding: 6px 10px;
    font-size: 11px;
    font-weight: 700;
    color: #E2E8F0;
  }

  /* Card Task List */
  .task-card {
    background: #1E293B;
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 12px;
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .task-card.active-focus {
    border-color: #FF6500;
  }
  .task-title {
    font-size: 13px;
    font-weight: 700;
    color: #FFFFFF;
    line-height: 1.35;
  }
  .task-meta {
    font-size: 11px;
    color: #94A3B8;
  }
  .btn-kerjakan {
    align-self: flex-end;
    background: #FF6500;
    color: #FFFFFF;
    border: none;
    padding: 7px 16px;
    border-radius: 8px;
    font-size: 11px;
    font-weight: 700;
    cursor: pointer;
  }

  /* Exec Page */
  .exec-meta-box {
    background: #1E293B;
    border-radius: 10px;
    padding: 10px 12px;
    border: 1px solid rgba(255,255,255,0.06);
  }
  .exec-meta-title {
    font-size: 13px;
    font-weight: 700;
    color: #FFFFFF;
  }
  .exec-meta-loc {
    font-size: 11px;
    color: #FF8A3D;
    font-weight: 600;
    margin-top: 2px;
  }

  .field-label {
    font-size: 11px;
    font-weight: 700;
    color: #CBD5E1;
    margin-top: 2px;
  }

  /* Photo Slot */
  .photo-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 8px;
  }
  .photo-box {
    height: 84px;
    background: #1E293B;
    border-radius: 8px;
    border: 1px solid rgba(255,255,255,0.1);
    position: relative;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    justify-content: flex-end;
    padding: 4px;
  }
  .photo-box.btn-add {
    border: 2px dashed rgba(255, 101, 0, 0.5);
    background: rgba(255, 101, 0, 0.04);
    align-items: center;
    justify-content: center;
    cursor: pointer;
  }
  .photo-badge {
    font-size: 8px;
    font-weight: 700;
    background: rgba(0,0,0,0.7);
    color: #FFF;
    padding: 2px 4px;
    border-radius: 4px;
    width: fit-content;
  }

  /* Clean Textarea */
  .clean-textarea {
    background: #0F172A;
    border: 1px solid rgba(255,255,255,0.15);
    border-radius: 8px;
    padding: 10px;
    color: #F8FAFC;
    font-size: 11px;
    height: 80px;
    resize: none;
    font-family: inherit;
    width: 100%;
  }
  .clean-textarea::placeholder {
    color: #64748B;
  }

  /* Buttons */
  .btn-wa-share {
    background: #10B981;
    color: #FFFFFF;
    border: none;
    border-radius: 8px;
    padding: 10px;
    font-size: 11px;
    font-weight: 700;
    text-align: center;
    cursor: pointer;
  }
  .btn-save-task {
    background: #1E293B;
    color: #CBD5E1;
    border: 1px solid rgba(255,255,255,0.15);
    border-radius: 8px;
    padding: 9px;
    font-size: 11px;
    font-weight: 600;
    text-align: center;
    cursor: pointer;
  }

  /* Chat Preview Box */
  .chat-card {
    background: #0F172A;
    border-radius: 24px;
    border: 1px solid rgba(255,255,255,0.12);
    padding: 18px;
    display: flex;
    flex-direction: column;
    height: 600px;
  }
  .chat-header {
    font-size: 13px;
    font-weight: 700;
    color: #FFFFFF;
    border-bottom: 1px solid rgba(255,255,255,0.08);
    padding-bottom: 10px;
    margin-bottom: 14px;
    display: flex;
    justify-content: space-between;
  }
  .wa-bubble {
    background: #064E3B;
    border: 1px solid #059669;
    border-radius: 12px;
    padding: 14px;
    color: #F8FAFC;
    font-family: "SF Mono", "Consolas", monospace;
    font-size: 11px;
    line-height: 1.5;
    white-space: pre-wrap;
    box-shadow: 0 4px 16px rgba(0,0,0,0.5);
  }
  .wa-media-row {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 6px;
    margin-bottom: 10px;
  }
  .wa-thumb {
    height: 70px;
    background: #1E293B;
    border-radius: 6px;
    border: 1px solid rgba(255,255,255,0.1);
  }

  .trigger-box {
    margin-top: auto;
    background: rgba(16, 185, 129, 0.08);
    border: 1px solid rgba(16, 185, 129, 0.25);
    border-radius: 10px;
    padding: 12px;
  }
  .trigger-title {
    font-size: 11px;
    font-weight: 700;
    color: #34D399;
    margin-bottom: 4px;
  }
  .trigger-desc {
    font-size: 11px;
    color: #CBD5E1;
    line-height: 1.4;
  }
</style>
</head>
<body>

<div class="canvas">

  <!-- Header -->
  <div class="header-bar">
    <div class="brand-group">
      <div class="app-icon">
        ${logoBase64 ? `<img src="${logoBase64}" alt="BSS Logo">` : '<span>BSS</span>'}
      </div>
      <div class="brand-meta">
        <h1>BSS Parking TimeMark — Revisi Alur Tugas & Laporan</h1>
        <p>Gaya Bahasa Ringkas, Input Bebas Fluff, No Hardcoded Photo Count & Format WA/TG Bersih</p>
      </div>
    </div>
    <span class="pill">Versi Revisi Lapangan</span>
  </div>

  <!-- 3 Screens -->
  <div class="screens-grid">

    <!-- Screen 1: List Tugas -->
    <div class="phone-frame">
      <div class="phone-notch"></div>
      <div class="phone-header">
        <div>
          <div class="phone-header-title">Tugas Saya Hari Ini</div>
          <div class="phone-header-sub">Ryan Lumasuge</div>
        </div>
        <span style="font-size: 11px; color: #FF8A3D; font-weight: 700;">2 Tugas</span>
      </div>
      <div class="phone-body">
        <div class="step-label">1. Pilih Tugas & Klik Kerjakan</div>

        <!-- Task 1 -->
        <div class="task-card active-focus">
          <div class="task-title">Pengecatan markah panah lokasi TBM</div>
          <div class="task-meta">Lokasi: <strong>TBM</strong></div>
          <button class="btn-kerjakan">Kerjakan</button>
        </div>

        <!-- Task 2 -->
        <div class="task-card">
          <div class="task-title">Maintenance mingguan: Pembersihan manless lokasi TBM</div>
          <div class="task-meta">Lokasi: <strong>TBM</strong></div>
          <button class="btn-kerjakan" style="background:#334155;">Kerjakan</button>
        </div>

        <div style="margin-top:auto; font-size:10px; color:#94A3B8; line-height:1.4; padding:8px; background:#1E293B; border-radius:8px;">
          ✓ Hanya menampilkan singkatan nama lokasi (contoh: <strong>TBM</strong>).<br>
          ✓ Tombol <strong>Kerjakan</strong> di kanan bawah tiap kartu.
        </div>
      </div>
    </div>

    <!-- Screen 2: Lembar Pengerjaan -->
    <div class="phone-frame">
      <div class="phone-notch"></div>
      <div class="phone-header">
        <div class="phone-header-title">Kerjakan Tugas</div>
        <span style="font-size:11px; color:#94A3B8;">04/10/2026</span>
      </div>
      <div class="phone-body">
        <div class="step-label">2. Dokumentasi & Catatan</div>

        <div class="exec-meta-box">
          <div class="exec-meta-title">Pengecatan markah panah lokasi TBM</div>
          <div class="exec-meta-loc">Lokasi: TBM</div>
        </div>

        <!-- Foto Grid Bebas -->
        <div class="field-label">Foto Dokumentasi (Tambah Sesuai Kebutuhan)</div>
        <div class="photo-grid">
          <div class="photo-box" style="background:#334155;">
            <span class="photo-badge">Foto 1</span>
          </div>
          <div class="photo-box" style="background:#475569;">
            <span class="photo-badge">Foto 2</span>
          </div>
          <div class="photo-box btn-add">
            <span style="font-size:16px; color:#FF6500; font-weight:800;">+</span>
            <span style="font-size:8px; color:#FF6500; font-weight:700;">Tambah</span>
          </div>
        </div>

        <!-- Catatan Bersih -->
        <div class="field-label">Catatan</div>
        <textarea class="clean-textarea" placeholder="Catatan Laporan"></textarea>

        <!-- CTA Buttons -->
        <div style="display:flex; flex-direction:column; gap:8px; margin-top:auto;">
          <button class="btn-wa-share">Kirim ke WA / Telegram</button>
          <button class="btn-save-task">Selesai & Simpan</button>
        </div>
      </div>
    </div>

    <!-- Screen 3: Output WA / Telegram & Auto Trigger Pulang -->
    <div class="chat-card">
      <div class="chat-header">
        <span>Format Pesan WA / Telegram</span>
        <span style="color:#10B981;">Clean Text</span>
      </div>

      <!-- Bubble WA -->
      <div class="wa-bubble">
Laporan Daily Hari ini
Teknisi : Ryan
Tanggal : 04 Oktober 2026
Lokasi : TBM
Pekerjaan : Pengecatan markah panah lokasi TBM
Status : Selesai (13:45)
----
Catatan :
"Pengecatan markah selesai, cat kering siap dilalui kendaraan"
      </div>

      <!-- Auto Trigger ke UI Pulang Existing -->
      <div class="trigger-box">
        <div class="trigger-title">Otomatis Terisi di Menu Pulang Existing:</div>
        <div class="trigger-desc">
          Saat teknisi absen pulang di rute pulang aplikasi:<br>
          <strong style="color:#34D399;">Pekerjaan Selesai:</strong><br>
          ✅ Pengecatan markah panah lokasi TBM<br>
          ✅ Maintenance mingguan: Pembersihan manless lokasi TBM
        </div>
      </div>

      <div style="font-size:10px; color:#94A3B8; margin-top:10px; line-height:1.4;">
        * Tidak ada tombol pulang ganda atau istilah kaku.<br>
        * Absen pulang tetap lewat alur pulang yang sudah ada.
      </div>
    </div>

  </div>

</div>

</body>
</html>
`;

const htmlPath = path.join(OUT_DIR, 'custom_task_ui_revised.html');
const pngPath = path.join(OUT_DIR, 'BSS-TimeMark-Custom-Task-Workflow-Revised.png');
const repoPngPath = path.join(__dirname, '..', 'BSS-TimeMark-Custom-Task-Workflow-Revised.png');

fs.writeFileSync(htmlPath, htmlContent, 'utf8');

try {
  execSync(
    `google-chrome-stable --headless=new --disable-gpu --no-sandbox --hide-scrollbars --screenshot="${pngPath}" --window-size=1280,780 "file://${htmlPath}"`,
    { stdio: 'inherit' }
  );
  fs.copyFileSync(pngPath, repoPngPath);
  console.log(`[Showcase Revised Generated] Saved to ${pngPath} and ${repoPngPath}`);
} catch (err) {
  console.error('[Showcase Error]', err.message);
  process.exit(1);
}
