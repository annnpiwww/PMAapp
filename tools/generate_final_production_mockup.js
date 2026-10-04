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
<title>BSS Parking TimeMark - Mockup Final 4 Layar Produksi</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Plus Jakarta Sans", sans-serif; }
  
  body {
    background: #06090F;
    color: #F8FAFC;
    padding: 24px;
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
  }

  .artboard {
    width: 1480px;
    background: #0B1120;
    border-radius: 20px;
    border: 1px solid #1E293B;
    box-shadow: 0 24px 70px rgba(0, 0, 0, 0.85);
    padding: 28px 32px;
  }

  /* Header Bar */
  .header-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px solid #1E293B;
    padding-bottom: 18px;
    margin-bottom: 24px;
  }
  .brand-group {
    display: flex;
    align-items: center;
    gap: 14px;
  }
  .app-icon {
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
  .app-icon img {
    width: 38px;
    height: 38px;
    object-fit: contain;
  }
  .brand-title {
    font-size: 19px;
    font-weight: 700;
    color: #FFFFFF;
  }
  .brand-subtitle {
    font-size: 12px;
    color: #94A3B8;
    margin-top: 2px;
  }
  .version-tag {
    background: #111827;
    border: 1px solid #334155;
    color: #FF8A3D;
    padding: 5px 12px;
    border-radius: 6px;
    font-size: 11px;
    font-weight: 700;
  }

  /* 4 Phones Grid */
  .screens-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 20px;
    margin-bottom: 20px;
  }

  /* Realistic Phone Shell (360x640 ratio scaled) */
  .phone-frame {
    background: #0F172A;
    border-radius: 22px;
    border: 1px solid #334155;
    box-shadow: 0 12px 30px rgba(0, 0, 0, 0.6);
    height: 630px;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }
  .phone-top-bar {
    background: #111827;
    border-bottom: 1px solid #1E293B;
    padding: 12px 14px;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .phone-top-title {
    font-size: 13px;
    font-weight: 700;
    color: #FFFFFF;
  }
  .phone-top-role {
    font-size: 10px;
    font-weight: 600;
    color: #94A3B8;
    background: #1E293B;
    padding: 2px 6px;
    border-radius: 4px;
  }
  .phone-body {
    flex: 1;
    padding: 14px;
    display: flex;
    flex-direction: column;
    gap: 10px;
    background: #0B1120;
    overflow-y: hidden;
  }

  /* Typography & Input Fields */
  .field-label {
    font-size: 11px;
    font-weight: 600;
    color: #CBD5E1;
    margin-bottom: 4px;
    display: block;
  }
  .req {
    color: #EF4444;
  }
  .text-input {
    background: #111827;
    border: 1px solid #334155;
    border-radius: 8px;
    padding: 10px 12px;
    font-size: 12px;
    color: #F8FAFC;
    width: 100%;
    min-height: 42px;
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .text-input.active {
    border-color: #FF6500;
  }
  
  /* Buttons */
  .btn-base {
    min-height: 46px;
    border-radius: 8px;
    font-size: 12px;
    font-weight: 700;
    display: flex;
    align-items: center;
    justify-content: center;
    border: none;
    cursor: pointer;
    width: 100%;
    gap: 6px;
  }
  .btn-orange {
    background: #FF6500;
    color: #FFFFFF;
  }
  .btn-emerald {
    background: #10B981;
    color: #FFFFFF;
  }
  .btn-slate {
    background: #1E293B;
    color: #CBD5E1;
    border: 1px solid #334155;
  }

  /* Status Pills (Baru, Dikerjakan, Selesai) */
  .status-pill {
    font-size: 9px;
    font-weight: 700;
    padding: 2px 6px;
    border-radius: 4px;
    display: inline-block;
  }
  .status-baru {
    background: rgba(245, 158, 11, 0.15);
    color: #FBBF24;
    border: 1px solid rgba(245, 158, 11, 0.3);
  }
  .status-dikerjakan {
    background: rgba(59, 130, 246, 0.15);
    color: #60A5FA;
    border: 1px solid rgba(59, 130, 246, 0.3);
  }
  .status-selesai {
    background: rgba(16, 185, 129, 0.15);
    color: #34D399;
    border: 1px solid rgba(16, 185, 129, 0.3);
  }

  /* Screen 1: Login Box */
  .login-container {
    background: #111827;
    border: 1px solid #1E293B;
    border-radius: 12px;
    padding: 16px 14px;
    margin-top: 14px;
    display: flex;
    flex-direction: column;
    align-items: center;
  }
  .login-avatar-circle {
    width: 54px;
    height: 54px;
    background: #FFFFFF;
    border: 2px solid #FF6500;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-bottom: 10px;
  }
  .login-avatar-circle img {
    width: 46px;
    height: 46px;
    object-fit: contain;
  }

  /* Screen 2: SPV Task Form */
  .seg-type {
    display: grid;
    grid-template-columns: 1fr 1fr;
    background: #111827;
    border: 1px solid #334155;
    border-radius: 8px;
    padding: 2px;
  }
  .seg-btn {
    font-size: 11px;
    font-weight: 600;
    text-align: center;
    padding: 7px;
    border-radius: 6px;
    color: #94A3B8;
  }
  .seg-btn.on {
    background: #FF6500;
    color: #FFFFFF;
  }

  /* Screen 3: Pengerjaan Teknisi */
  .task-header-card {
    background: #111827;
    border: 1px solid #1E293B;
    border-radius: 8px;
    padding: 10px 12px;
  }
  .task-header-title {
    font-size: 12px;
    font-weight: 700;
    color: #FFFFFF;
  }
  .task-header-loc {
    font-size: 11px;
    color: #FF8A3D;
    font-weight: 600;
    margin-top: 2px;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .photo-deck-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 8px;
  }
  .photo-slot-box {
    height: 74px;
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
  .photo-slot-box.add {
    border: 1px dashed #FF6500;
    background: rgba(255, 101, 0, 0.04);
    align-items: center;
    justify-content: center;
    cursor: pointer;
  }
  .badge-tag {
    font-size: 8px;
    font-weight: 700;
    background: rgba(0, 0, 0, 0.7);
    color: #FFFFFF;
    padding: 1px 4px;
    border-radius: 3px;
    width: fit-content;
  }
  .btn-remove-photo {
    position: absolute;
    top: 3px;
    right: 3px;
    width: 15px;
    height: 15px;
    background: #EF4444;
    color: #FFFFFF;
    border-radius: 50%;
    font-size: 9px;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .textarea-note {
    background: #111827;
    border: 1px solid #334155;
    border-radius: 8px;
    padding: 8px 10px;
    color: #F8FAFC;
    font-size: 11px;
    height: 60px;
    resize: none;
    width: 100%;
  }

  /* Screen 4: Post-Save Dialog & Output */
  .save-confirm-box {
    background: #111827;
    border: 1px solid #10B981;
    border-radius: 10px;
    padding: 12px;
  }
  .confirm-title {
    font-size: 12px;
    font-weight: 700;
    color: #34D399;
    display: flex;
    align-items: center;
    gap: 6px;
    margin-bottom: 6px;
  }
  .clean-bubble {
    background: #064E3B;
    border: 1px solid #059669;
    border-radius: 8px;
    padding: 10px;
    color: #F8FAFC;
    font-size: 10px;
    line-height: 1.45;
    font-family: monospace;
    white-space: pre-wrap;
    margin-top: 6px;
  }
  .pulang-preview-box {
    background: #111827;
    border: 1px solid #1E293B;
    border-radius: 8px;
    padding: 10px;
    margin-top: auto;
  }
  .pulang-sub {
    font-size: 10px;
    color: #94A3B8;
    margin-bottom: 4px;
  }

  /* Bottom Audit Table */
  .footer-audit {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 16px;
    border-top: 1px solid #1E293B;
    padding-top: 20px;
  }
  .audit-col h4 {
    font-size: 12px;
    font-weight: 700;
    color: #F8FAFC;
    margin-bottom: 4px;
  }
  .audit-col p {
    font-size: 11px;
    color: #94A3B8;
    line-height: 1.35;
  }
  .audit-status-tag {
    font-size: 9px;
    font-weight: 700;
    padding: 2px 6px;
    border-radius: 3px;
    display: inline-block;
    margin-top: 4px;
  }
  .tag-live {
    background: rgba(16, 185, 129, 0.15);
    color: #34D399;
    border: 1px solid rgba(16, 185, 129, 0.3);
  }
  .tag-ui {
    background: rgba(59, 130, 246, 0.15);
    color: #60A5FA;
    border: 1px solid rgba(59, 130, 246, 0.3);
  }
</style>
</head>
<body>

<div class="artboard">

  <!-- Header -->
  <div class="header-bar">
    <div class="brand-group">
      <div class="app-icon">
        ${logoBase64 ? `<img src="${logoBase64}" alt="BSS Logo">` : '<span>BSS</span>'}
      </div>
      <div>
        <div class="brand-title">BSS Parking TimeMark — Mockup Final Produksi</div>
        <div class="brand-subtitle">Responsif HP, Manual Lokasi SPV, Status Riil & Alur Penyimpanan Terverifikasi</div>
      </div>
    </div>
    <div class="version-tag">Production Candidate v2.0.50</div>
  </div>

  <!-- 4 Phones Layout -->
  <div class="screens-grid">

    <!-- 1. Login -->
    <div class="phone-frame">
      <div class="phone-top-bar">
        <span class="phone-top-title">Login</span>
        <span class="phone-top-role">Autentikasi</span>
      </div>
      <div class="phone-body">
        <div class="login-container">
          <div class="login-avatar-circle">
            ${logoBase64 ? `<img src="${logoBase64}" alt="BSS Logo">` : '<span>BSS</span>'}
          </div>
          <div style="font-size:15px; font-weight:700; color:#FFFFFF;">BSS TimeMark</div>
          <div style="font-size:11px; color:#94A3B8; margin-bottom:16px;">Absensi, Maintenance & Daily Task</div>

          <div style="width:100%; margin-bottom:10px;">
            <label class="field-label">Email atau Username <span class="req">*</span></label>
            <div class="text-input active">
              <span>ryan@bssparking.id</span>
            </div>
          </div>

          <div style="width:100%; margin-bottom:14px;">
            <label class="field-label">Kata Sandi <span class="req">*</span></label>
            <div class="text-input">
              <span>••••••••••</span>
              <span style="font-size:11px; color:#64748B;">Lihat</span>
            </div>
          </div>

          <button class="btn-base btn-orange">Masuk</button>
        </div>

        <div style="margin-top:auto; font-size:10px; color:#94A3B8; line-height:1.4; padding:8px; background:#111827; border-radius:6px;">
          ✓ Kredensial demo dihapus di production.<br>
          ✓ Persistent labels & inline error handling.
        </div>
      </div>
    </div>

    <!-- 2. Form Penugasan SPV -->
    <div class="phone-frame">
      <div class="phone-top-bar">
        <span class="phone-top-title">Beri Tugas</span>
        <span class="phone-top-role">Supervisor</span>
      </div>
      <div class="phone-body">
        <div>
          <label class="field-label">Jenis Tugas <span class="req">*</span></label>
          <div class="seg-type">
            <div class="seg-btn on">Tugas Khusus</div>
            <div class="seg-btn">Maintenance SOP</div>
          </div>
        </div>

        <div>
          <label class="field-label">Pilih Teknisi <span class="req">*</span></label>
          <div class="text-input">
            <span>Ryan Lumasuge</span>
            <span style="color:#94A3B8;">▾</span>
          </div>
        </div>

        <div>
          <label class="field-label">Lokasi <span class="req">*</span></label>
          <div class="text-input active">
            <span>TBM</span>
          </div>
        </div>

        <div>
          <label class="field-label">Detail Pekerjaan <span class="req">*</span></label>
          <div class="text-input">
            <span>Pengecatan markah panah lokasi TBM</span>
          </div>
        </div>

        <div>
          <label class="field-label">Catatan (Opsional)</label>
          <div class="text-input" style="color:#64748B;">
            <span>Instruksi khusus jika ada</span>
          </div>
        </div>

        <button class="btn-base btn-orange" style="margin-top:auto;">Kirim Tugas</button>
      </div>
    </div>

    <!-- 3. Pengerjaan Tugas Teknisi -->
    <div class="phone-frame">
      <div class="phone-top-bar">
        <span class="phone-top-title">Pengerjaan Tugas</span>
        <span class="phone-top-role">Teknisi</span>
      </div>
      <div class="phone-body">
        <div class="task-header-card">
          <div class="task-header-title">Pengecatan markah panah lokasi TBM</div>
          <div class="task-header-loc">
            <span>Lokasi: TBM</span>
            <span class="status-pill status-baru">Baru</span>
          </div>
        </div>

        <div>
          <label class="field-label">Foto Dokumentasi (Opsional)</label>
          <div class="photo-deck-grid">
            <div class="photo-slot-box" style="background:#1E293B;">
              <span class="badge-tag">Foto 1</span>
              <div class="btn-remove-photo">✕</div>
            </div>
            <div class="photo-slot-box" style="background:#334155;">
              <span class="badge-tag">Foto 2</span>
              <div class="btn-remove-photo">✕</div>
            </div>
            <div class="photo-slot-box add">
              <span style="font-size:16px; color:#FF6500; font-weight:700;">+</span>
              <span style="font-size:8px; color:#FF6500; font-weight:600;">Tambah</span>
            </div>
          </div>
        </div>

        <div>
          <label class="field-label">Catatan</label>
          <textarea class="textarea-note" placeholder="Catatan Laporan"></textarea>
        </div>

        <!-- Single Primary CTA -->
        <button class="btn-base btn-orange" style="margin-top:auto;">Selesaikan Tugas</button>
      </div>
    </div>

    <!-- 4. Konfirmasi Pasca-Simpan & Output -->
    <div class="phone-frame">
      <div class="phone-top-bar">
        <span class="phone-top-title">Laporan Tersimpan</span>
        <span class="phone-top-role">Terkonfirmasi</span>
      </div>
      <div class="phone-body">
        <div class="save-confirm-box">
          <div class="confirm-title">
            <span>✓</span> Laporan Berhasil Disimpan
          </div>
          <div style="font-size:10px; color:#94A3B8; margin-bottom:8px;">
            Data telah tersimpan di PocketBase.
          </div>
          <button class="btn-base btn-emerald" style="min-height:38px; font-size:11px; margin-bottom:6px;">
            Kirim ke WhatsApp / Telegram
          </button>
          <button class="btn-base btn-slate" style="min-height:34px; font-size:10px;">
            Tutup
          </button>
        </div>

        <div>
          <label class="field-label">Ringkasan Laporan:</label>
          <div class="clean-bubble">Laporan Daily Hari ini
Teknisi : Ryan
Tanggal : 04 Oktober 2026
Lokasi : TBM
Pekerjaan : Pengecatan markah panah lokasi TBM
Status : Selesai (13:45 WITA)
----
Catatan :
"Catatan Laporan"</div>
        </div>

        <!-- Integrasi Menu Pulang Existing -->
        <div class="pulang-preview-box">
          <div class="pulang-sub">Otomatis Terisi di Menu Pulang:</div>
          <div style="font-size:10px; color:#E2E8F0; display:flex; align-items:center; gap:4px;">
            <span style="color:#10B981; font-weight:bold;">[✓]</span> Pengecatan markah panah lokasi TBM
          </div>
        </div>
      </div>
    </div>

  </div>

  <!-- Bottom Verification & System Integrity -->
  <div class="footer-audit">
    <div class="audit-col">
      <h4>1. Form Login</h4>
      <p>Zero kredensial demo di production, persistent label, validasi format, dan loading state aman.</p>
      <span class="audit-status-tag tag-live">100% Implemented</span>
    </div>
    <div class="audit-col">
      <h4>2. Penugasan SPV</h4>
      <p>Satu field manual murni "Lokasi" (tanpa quick-select), validasi field wajib (*), dan anti-double submit.</p>
      <span class="audit-status-tag tag-live">100% Implemented</span>
    </div>
    <div class="audit-col">
      <h4>3. Pengerjaan Teknisi</h4>
      <p>Layar mandiri CustomTaskExecutionScreen: multi-foto dinamis, hapus foto, single CTA Selesaikan Tugas.</p>
      <span class="audit-status-tag tag-live">100% Implemented</span>
    </div>
    <div class="audit-col">
      <h4>4. Laporan & Absen Pulang</h4>
      <p>Simpan server dulu baru bagikan ke WA/TG. Auto-fill centang hijau [✓] di rute kepulangan existing.</p>
      <span class="audit-status-tag tag-live">100% Implemented</span>
    </div>
  </div>

</div>

</body>
</html>
`;

const htmlPath = path.join(OUT_DIR, 'final_production_mockup.html');
const pngPath = path.join(OUT_DIR, 'BSS-TimeMark-Final-Production-Mockup.png');
const repoPngPath = path.join(__dirname, '..', 'BSS-TimeMark-Final-Production-Mockup.png');

fs.writeFileSync(htmlPath, htmlContent, 'utf8');

try {
  execSync(
    `google-chrome-stable --headless=new --disable-gpu --no-sandbox --hide-scrollbars --screenshot="${pngPath}" --window-size=1540,820 "file://${htmlPath}"`,
    { stdio: 'inherit' }
  );
  fs.copyFileSync(pngPath, repoPngPath);
  console.log(`[Final Mockup Generated] Saved to ${pngPath} and ${repoPngPath}`);
  console.log(`File size: ${fs.statSync(repoPngPath).size} bytes`);
} catch (err) {
  console.error('[Final Mockup Error]', err.message);
  process.exit(1);
}
