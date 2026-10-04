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
<title>BSS Parking TimeMark - Mockup Produksi UI/UX</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Plus Jakarta Sans", sans-serif; }
  
  body {
    background: #090E17;
    color: #F8FAFC;
    padding: 24px;
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
  }

  .canvas {
    width: 1480px;
    background: #0D1525;
    border-radius: 20px;
    border: 1px solid #1E293B;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.7);
    padding: 28px 32px;
  }

  /* Top Bar */
  .top-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px solid #1E293B;
    padding-bottom: 18px;
    margin-bottom: 24px;
  }
  .brand-left {
    display: flex;
    align-items: center;
    gap: 14px;
  }
  .brand-logo {
    width: 44px;
    height: 44px;
    background: #FFFFFF;
    border: 2px solid #FF6500;
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
  }
  .brand-logo img {
    width: 38px;
    height: 38px;
    object-fit: contain;
  }
  .brand-text h1 {
    font-size: 19px;
    font-weight: 700;
    color: #FFFFFF;
  }
  .brand-text p {
    font-size: 12px;
    color: #94A3B8;
    margin-top: 2px;
  }
  .status-tag {
    background: #1E293B;
    border: 1px solid #334155;
    color: #E2E8F0;
    padding: 5px 12px;
    border-radius: 6px;
    font-size: 11px;
    font-weight: 600;
  }

  /* 4 Phones Grid */
  .phones-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 20px;
  }

  /* Realistic Mobile Frame */
  .mobile-frame {
    background: #0B1120;
    border-radius: 24px;
    border: 1px solid #334155;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
    height: 620px;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }
  .screen-header {
    background: #111827;
    border-bottom: 1px solid #1F2937;
    padding: 12px 14px;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .screen-title {
    font-size: 13px;
    font-weight: 700;
    color: #FFFFFF;
  }
  .screen-role {
    font-size: 10px;
    font-weight: 600;
    color: #94A3B8;
    background: #1F2937;
    padding: 2px 6px;
    border-radius: 4px;
  }
  .screen-content {
    flex: 1;
    padding: 14px;
    display: flex;
    flex-direction: column;
    gap: 10px;
    overflow-y: hidden;
    background: #0B1120;
  }

  /* Common UI Elements */
  .label-text {
    font-size: 11px;
    font-weight: 600;
    color: #CBD5E1;
    margin-bottom: 4px;
    display: block;
  }
  .req-star {
    color: #EF4444;
  }
  .input-box {
    background: #111827;
    border: 1px solid #334155;
    border-radius: 8px;
    padding: 9px 12px;
    font-size: 12px;
    color: #F8FAFC;
    width: 100%;
    min-height: 42px;
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .input-box.focus {
    border-color: #FF6500;
  }
  .btn-action {
    min-height: 44px;
    border-radius: 8px;
    font-size: 12px;
    font-weight: 600;
    display: flex;
    align-items: center;
    justify-content: center;
    border: none;
    cursor: pointer;
    width: 100%;
  }
  .btn-primary {
    background: #FF6500;
    color: #FFFFFF;
  }
  .btn-secondary {
    background: #1E293B;
    color: #CBD5E1;
    border: 1px solid #334155;
  }
  .btn-success {
    background: #10B981;
    color: #FFFFFF;
  }

  /* Screen 1: Login Specifics */
  .login-box {
    background: #111827;
    border: 1px solid #1F2937;
    border-radius: 14px;
    padding: 18px 14px;
    margin-top: 20px;
    display: flex;
    flex-direction: column;
    align-items: center;
  }
  .login-avatar {
    width: 56px;
    height: 56px;
    background: #FFFFFF;
    border: 2px solid #FF6500;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-bottom: 12px;
  }
  .login-avatar img {
    width: 48px;
    height: 48px;
    object-fit: contain;
  }
  .login-title-text {
    font-size: 15px;
    font-weight: 700;
    color: #FFFFFF;
  }
  .login-sub-text {
    font-size: 11px;
    color: #94A3B8;
    margin-bottom: 18px;
  }

  /* Screen 2: SPV Task Form */
  .task-type-segment {
    display: grid;
    grid-template-columns: 1fr 1fr;
    background: #111827;
    border: 1px solid #334155;
    border-radius: 8px;
    padding: 3px;
  }
  .seg-item {
    font-size: 11px;
    font-weight: 600;
    text-align: center;
    padding: 6px;
    border-radius: 6px;
    color: #94A3B8;
  }
  .seg-item.active {
    background: #FF6500;
    color: #FFFFFF;
  }

  /* Screen 3: Teknisi Execution */
  .detail-card {
    background: #111827;
    border: 1px solid #1F2937;
    border-radius: 10px;
    padding: 10px 12px;
  }
  .detail-job {
    font-size: 12px;
    font-weight: 700;
    color: #FFFFFF;
  }
  .detail-loc {
    font-size: 11px;
    color: #FF8A3D;
    font-weight: 600;
    margin-top: 2px;
  }
  .photo-row {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 8px;
  }
  .thumb-slot {
    height: 76px;
    background: #1E293B;
    border-radius: 8px;
    border: 1px solid #334155;
    position: relative;
    display: flex;
    flex-direction: column;
    justify-content: flex-end;
    padding: 4px;
    overflow: hidden;
  }
  .thumb-slot.add-slot {
    border: 1px dashed #FF6500;
    background: rgba(255, 101, 0, 0.04);
    align-items: center;
    justify-content: center;
    cursor: pointer;
  }
  .slot-label {
    font-size: 8px;
    font-weight: 700;
    background: rgba(0, 0, 0, 0.7);
    color: #FFFFFF;
    padding: 1px 4px;
    border-radius: 3px;
    width: fit-content;
  }
  .del-btn {
    position: absolute;
    top: 3px;
    right: 3px;
    width: 14px;
    height: 14px;
    background: #EF4444;
    color: #FFFFFF;
    border-radius: 50%;
    font-size: 9px;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .textarea-box {
    background: #111827;
    border: 1px solid #334155;
    border-radius: 8px;
    padding: 8px 10px;
    color: #F8FAFC;
    font-size: 11px;
    height: 64px;
    resize: none;
    width: 100%;
  }

  /* Screen 4: Post-Save Dialog & Output */
  .dialog-card {
    background: #111827;
    border: 1px solid #10B981;
    border-radius: 12px;
    padding: 12px;
  }
  .success-header {
    display: flex;
    align-items: center;
    gap: 6px;
    color: #34D399;
    font-size: 12px;
    font-weight: 700;
    margin-bottom: 8px;
  }
  .report-text-bubble {
    background: #064E3B;
    border: 1px solid #059669;
    border-radius: 8px;
    padding: 10px;
    color: #F8FAFC;
    font-size: 10px;
    line-height: 1.45;
    font-family: monospace;
    white-space: pre-wrap;
  }
  .pulang-preview {
    background: #111827;
    border: 1px solid #1F2937;
    border-radius: 8px;
    padding: 10px;
    margin-top: auto;
  }
  .pulang-title {
    font-size: 10px;
    color: #94A3B8;
    margin-bottom: 4px;
  }
  .pulang-item {
    font-size: 10px;
    color: #E2E8F0;
    display: flex;
    align-items: center;
    gap: 4px;
  }
</style>
</head>
<body>

<div class="canvas">
  <div class="top-bar">
    <div class="brand-left">
      <div class="brand-logo">
        ${logoBase64 ? `<img src="${logoBase64}" alt="BSS Logo">` : '<span>BSS</span>'}
      </div>
      <div class="brand-text">
        <h1>BSS Parking TimeMark — Konsep UI/UX Siap Produksi</h1>
        <p>Audit Minimalis: Field Manual Lokasi SPV, Single CTA Selesaikan Tugas & Format Bersih</p>
      </div>
    </div>
    <div class="status-tag">Ready for Production</div>
  </div>

  <div class="phones-grid">

    <!-- 1. Form Login -->
    <div class="mobile-frame">
      <div class="screen-header">
        <span class="screen-title">Login</span>
        <span class="screen-role">Autentikasi</span>
      </div>
      <div class="screen-content">
        <div class="login-box">
          <div class="login-avatar">
            ${logoBase64 ? `<img src="${logoBase64}" alt="BSS Logo">` : '<span>BSS</span>'}
          </div>
          <div class="login-title-text">BSS TimeMark</div>
          <div class="login-sub-text">Absensi, Maintenance & Daily Task</div>

          <div style="width:100%; margin-bottom:10px;">
            <label class="label-text">Email atau Username <span class="req-star">*</span></label>
            <div class="input-box focus">
              <span>ryan@bssparking.id</span>
            </div>
          </div>

          <div style="width:100%; margin-bottom:14px;">
            <label class="label-text">Kata Sandi <span class="req-star">*</span></label>
            <div class="input-box">
              <span>••••••••••</span>
              <span style="font-size:11px; color:#64748B;">Lihat</span>
            </div>
          </div>

          <button class="btn-action btn-primary">Masuk</button>
        </div>

        <div style="margin-top:auto; font-size:10px; color:#94A3B8; line-height:1.4; padding:8px; background:#111827; border-radius:6px;">
          ✓ Kredensial demo dihapus di production.<br>
          ✓ Validasi input & loading state aman.
        </div>
      </div>
    </div>

    <!-- 2. Form Penugasan SPV -->
    <div class="mobile-frame">
      <div class="screen-header">
        <span class="screen-title">Beri Tugas</span>
        <span class="screen-role">Supervisor</span>
      </div>
      <div class="screen-content">
        <!-- Jenis Tugas -->
        <div>
          <label class="label-text">Jenis Tugas <span class="req-star">*</span></label>
          <div class="task-type-segment">
            <div class="seg-item active">Tugas Khusus</div>
            <div class="seg-item">Maintenance SOP</div>
          </div>
        </div>

        <!-- Pilih Teknisi -->
        <div>
          <label class="label-text">Pilih Teknisi <span class="req-star">*</span></label>
          <div class="input-box">
            <span>Ryan Lumasuge</span>
            <span style="color:#94A3B8;">▾</span>
          </div>
        </div>

        <!-- Lokasi (Manual Murni) -->
        <div>
          <label class="label-text">Lokasi <span class="req-star">*</span></label>
          <div class="input-box focus">
            <span>TBM</span>
          </div>
        </div>

        <!-- Detail Pekerjaan -->
        <div>
          <label class="label-text">Detail Pekerjaan <span class="req-star">*</span></label>
          <div class="input-box">
            <span>Pengecatan markah panah lokasi TBM</span>
          </div>
        </div>

        <button class="btn-action btn-primary" style="margin-top:auto;">Kirim Tugas</button>
      </div>
    </div>

    <!-- 3. Eksekusi Tugas Teknisi -->
    <div class="mobile-frame">
      <div class="screen-header">
        <span class="screen-title">Pengerjaan Tugas</span>
        <span class="screen-role">Teknisi</span>
      </div>
      <div class="screen-content">
        <div class="detail-card">
          <div class="detail-job">Pengecatan markah panah lokasi TBM</div>
          <div class="detail-loc">Lokasi: TBM</div>
        </div>

        <!-- Foto Dokumentasi Fleksibel -->
        <div>
          <label class="label-text">Foto Dokumentasi (Opsional)</label>
          <div class="photo-row">
            <div class="thumb-slot" style="background:#1E293B;">
              <span class="slot-label">Foto 1</span>
              <div class="del-btn">✕</div>
            </div>
            <div class="thumb-slot" style="background:#334155;">
              <span class="slot-label">Foto 2</span>
              <div class="del-btn">✕</div>
            </div>
            <div class="thumb-slot add-slot">
              <span style="font-size:16px; color:#FF6500; font-weight:700;">+</span>
              <span style="font-size:8px; color:#FF6500; font-weight:600;">Tambah</span>
            </div>
          </div>
        </div>

        <!-- Catatan Singkat -->
        <div>
          <label class="label-text">Catatan</label>
          <textarea class="textarea-box" placeholder="Catatan Laporan"></textarea>
        </div>

        <!-- Single Primary Action -->
        <button class="btn-action btn-primary" style="margin-top:auto;">Selesaikan Tugas</button>
      </div>
    </div>

    <!-- 4. Post-Save Dialog & Sinkronisasi -->
    <div class="mobile-frame">
      <div class="screen-header">
        <span class="screen-title">Laporan Tersimpan</span>
        <span class="screen-role">Sinkron</span>
      </div>
      <div class="screen-content">
        <!-- Konfirmasi Sukses Simpan Server -->
        <div class="dialog-card">
          <div class="success-header">
            <span>✓</span> Laporan Berhasil Disimpan
          </div>
          <div style="font-size:10px; color:#94A3B8; margin-bottom:8px;">
            Data telah tersimpan di PocketBase. Kirim ringkasan ke WA atau Telegram?
          </div>
          <button class="btn-action btn-success" style="min-height:36px; font-size:11px; margin-bottom:6px;">
            Kirim ke WhatsApp / Telegram
          </button>
          <button class="btn-action btn-secondary" style="min-height:32px; font-size:10px;">
            Tutup
          </button>
        </div>

        <!-- Preview Pesan WA Singkat -->
        <div style="margin-top:4px;">
          <label class="label-text">Format Pesan:</label>
          <div class="report-text-bubble">Laporan Daily Hari ini
Teknisi : Ryan
Tanggal : 04 Oktober 2026
Lokasi : TBM
Pekerjaan : Pengecatan markah panah lokasi TBM
Status : Selesai (13:45)
----
Catatan :
"Catatan Laporan"</div>
        </div>

        <!-- Sinkronisasi Absen Pulang Existing -->
        <div class="pulang-preview">
          <div class="pulang-title">Otomatis Terisi di Menu Pulang:</div>
          <div class="pulang-item">
            <span style="color:#10B981; font-weight:bold;">✓</span> Pengecatan markah panah lokasi TBM
          </div>
        </div>
      </div>
    </div>

  </div>
</div>

</body>
</html>
`;

const htmlPath = path.join(OUT_DIR, 'production_ui_showcase.html');
const pngPath = path.join(OUT_DIR, 'BSS-TimeMark-Production-UI-Showcase.png');
const repoPngPath = path.join(__dirname, '..', 'BSS-TimeMark-Production-UI-Showcase.png');

fs.writeFileSync(htmlPath, htmlContent, 'utf8');

try {
  execSync(
    `google-chrome-stable --headless=new --disable-gpu --no-sandbox --hide-scrollbars --screenshot="${pngPath}" --window-size=1540,780 "file://${htmlPath}"`,
    { stdio: 'inherit' }
  );
  fs.copyFileSync(pngPath, repoPngPath);
  console.log(`[Production Showcase Generated] Saved to ${pngPath} and ${repoPngPath}`);
  console.log(`File size: ${fs.statSync(repoPngPath).size} bytes`);
} catch (err) {
  console.error('[Production Showcase Error]', err.message);
  process.exit(1);
}
