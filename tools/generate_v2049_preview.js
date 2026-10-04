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
<title>BSS TimeMark - Release Preview v2.0.49</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Plus Jakarta Sans", sans-serif; }
  body {
    background: #070B12;
    color: #F8FAFC;
    padding: 24px;
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
  }
  .canvas {
    width: 1200px;
    background: radial-gradient(circle at 10% 15%, #151D33 0%, #080C16 85%);
    border-radius: 24px;
    border: 1px solid rgba(255,255,255,0.12);
    box-shadow: 0 32px 80px rgba(0,0,0,0.85);
    padding: 28px 32px;
  }
  
  /* Top Banner */
  .brand-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px solid rgba(255,255,255,0.08);
    padding-bottom: 18px;
    margin-bottom: 22px;
  }
  .brand-title {
    display: flex;
    align-items: center;
    gap: 14px;
  }
  .logo-icon {
    width: 44px;
    height: 44px;
    background: linear-gradient(135deg, #2563EB, #1D4ED8);
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 900;
    font-size: 20px;
    color: #fff;
    box-shadow: 0 4px 16px rgba(37,99,235,0.5);
  }
  .brand-text h1 {
    font-size: 20px;
    font-weight: 800;
    letter-spacing: 0.3px;
    color: #FFFFFF;
  }
  .brand-text p {
    font-size: 13px;
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
    padding: 6px 14px;
    border-radius: 20px;
    font-size: 12px;
    font-weight: 700;
  }
  .success-tag {
    background: rgba(16, 185, 129, 0.2);
    border: 1px solid #10B981;
    color: #34D399;
    padding: 6px 14px;
    border-radius: 20px;
    font-size: 12px;
    font-weight: 700;
  }

  /* Main Grid */
  .main-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 22px;
  }

  .card {
    background: rgba(15, 23, 42, 0.65);
    border: 1px solid rgba(255,255,255,0.08);
    border-radius: 16px;
    padding: 20px;
    display: flex;
    flex-direction: column;
    gap: 16px;
  }
  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .card-title {
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .card-title span.icon {
    font-size: 18px;
  }
  .card-title h2 {
    font-size: 16px;
    font-weight: 700;
    color: #F1F5F9;
  }
  .card-badge {
    font-size: 11px;
    font-weight: 700;
    padding: 4px 10px;
    border-radius: 12px;
  }
  .badge-blue { background: rgba(59, 130, 246, 0.2); color: #60A5FA; border: 1px solid rgba(59, 130, 246, 0.4); }
  .badge-amber { background: rgba(245, 158, 11, 0.2); color: #FBBF24; border: 1px solid rgba(245, 158, 11, 0.4); }
  .badge-emerald { background: rgba(16, 185, 129, 0.2); color: #34D399; border: 1px solid rgba(16, 185, 129, 0.4); }
  .badge-red { background: rgba(239, 68, 68, 0.2); color: #F87171; border: 1px solid rgba(239, 68, 68, 0.4); }

  /* Scenario Comparison Box */
  .scenario-box {
    background: rgba(2, 6, 23, 0.6);
    border: 1px solid rgba(255,255,255,0.08);
    border-radius: 12px;
    padding: 14px;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .scenario-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 12px;
    font-weight: 700;
    color: #94A3B8;
  }
  .timeline {
    display: flex;
    align-items: center;
    justify-content: space-between;
    position: relative;
    padding: 10px 0;
  }
  .timeline::before {
    content: '';
    position: absolute;
    top: 50%;
    left: 20px;
    right: 20px;
    height: 2px;
    background: rgba(255,255,255,0.12);
    z-index: 1;
  }
  .time-point {
    position: relative;
    z-index: 2;
    background: #0F172A;
    border: 2px solid #3B82F6;
    border-radius: 8px;
    padding: 6px 10px;
    text-align: center;
  }
  .time-point.late {
    border-color: #F59E0B;
  }
  .time-point.end {
    border-color: #10B981;
  }
  .time-point .label {
    font-size: 10px;
    color: #94A3B8;
  }
  .time-point .time {
    font-size: 12px;
    font-weight: 800;
    color: #FFFFFF;
  }

  /* Status Pill */
  .status-row {
    display: flex;
    gap: 10px;
  }
  .status-box {
    flex: 1;
    border-radius: 10px;
    padding: 10px 12px;
    font-size: 11px;
    line-height: 1.45;
  }
  .box-before {
    background: rgba(239, 68, 68, 0.12);
    border: 1px solid rgba(239, 68, 68, 0.3);
    color: #FCA5A5;
  }
  .box-after {
    background: rgba(16, 185, 129, 0.12);
    border: 1px solid rgba(16, 185, 129, 0.3);
    color: #6EE7B7;
  }

  /* Rule block */
  .rule-steps {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .rule-item {
    display: flex;
    align-items: flex-start;
    gap: 8px;
    font-size: 11px;
    color: #CBD5E1;
    line-height: 1.4;
  }
  .rule-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    margin-top: 5px;
    flex-shrink: 0;
  }
  .dot-green { background: #10B981; }
  .dot-amber { background: #F59E0B; }
  .dot-blue { background: #3B82F6; }

  /* Bottom Badges */
  .feature-pills {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 12px;
    margin-top: 20px;
    padding-top: 16px;
    border-top: 1px solid rgba(255,255,255,0.08);
  }
  .feat-item {
    background: rgba(255,255,255,0.04);
    border: 1px solid rgba(255,255,255,0.06);
    border-radius: 10px;
    padding: 10px 12px;
    font-size: 11px;
    font-weight: 600;
    color: #E2E8F0;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .feat-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: #3B82F6;
    flex-shrink: 0;
  }
</style>
</head>
<body>

<div class="canvas">
  <!-- Top Banner -->
  <div class="brand-bar">
    <div class="brand-title">
      <div class="logo-icon">BSS</div>
      <div class="brand-text">
        <h1>BSS Parking TimeMark</h1>
        <p>Release v2.0.49 • Logika Absensi Terlambat & Handover Shift Operasional (Opsi 1)</p>
      </div>
    </div>
    <div class="badge-group">
      <div class="version-tag">Version 2.0.49+57</div>
      <div class="success-tag">✓ 174 Tests Passed</div>
    </div>
  </div>

  <!-- Main Grid -->
  <div class="main-grid">
    
    <!-- Left Column: Kasus Keterlambatan Shift -->
    <div class="card">
      <div class="card-header">
        <div class="card-title">
          <span class="icon">⏱️</span>
          <h2>Kasus Shift Lapangan: Terlambat Masuk</h2>
        </div>
        <span class="card-badge badge-amber">Skenario Shift 1</span>
      </div>

      <!-- Timeline illustration -->
      <div class="scenario-box">
        <div class="scenario-header">
          <span>JADWAL SHIFT 1: 03:00 - 11:00 (8 JAM)</span>
          <span style="color:#F59E0B;">Masuk Terlambat</span>
        </div>
        <div class="timeline">
          <div class="time-point">
            <div class="label">Jadwal Mulai</div>
            <div class="time">03:00</div>
          </div>
          <div class="time-point late">
            <div class="label">Masuk Riil</div>
            <div class="time">06:00</div>
          </div>
          <div class="time-point end">
            <div class="label">Akhir Shift</div>
            <div class="time">11:00</div>
          </div>
        </div>
      </div>

      <!-- Before vs After -->
      <div class="status-row">
        <div class="status-box box-before">
          <strong>❌ Versi Sebelumnya:</strong><br>
          Saat jam 11:00 tiba (shift selesai), teknisi <strong>terkunci</strong> tidak bisa absen pulang karena baru bekerja 5 jam (kurang 3 jam dari kuota 8 jam). Dipaksa tunggu di pos sampai jam 14:00.
        </div>
        <div class="status-box box-after">
          <strong>✅ Versi v2.0.49 (Opsi 1):</strong><br>
          Saat jam 11:00 tiba, teknisi <strong>bisa langsung absen pulang</strong> agar pos parkir bisa diserahterimakan (handover) ke Shift 2. Durasi kerja riil tercatat jujur: 5 jam.
        </div>
      </div>
    </div>

    <!-- Right Column: Logika & Proteksi Anti-Curang -->
    <div class="card">
      <div class="card-header">
        <div class="card-title">
          <span class="icon">🛡️</span>
          <h2>Aturan Logika & Proteksi Kepulangan</h2>
        </div>
        <span class="card-badge badge-emerald">Opsi 1 Aktif</span>
      </div>

      <div class="scenario-box">
        <div class="rule-steps">
          <div class="rule-item">
            <span class="rule-dot dot-green"></span>
            <span><strong>1. Boleh Pulang Saat Shift Selesai:</strong> Jika waktu sekarang $\ge$ jam akhir shift (Shift 1: 11:00, Shift 2.2: 14:00, Shift 2: 18:00, Shift 3: 22:00), tombol Pulang otomatis aktif.</span>
          </div>
          <div class="rule-item">
            <span class="rule-dot dot-blue"></span>
            <span><strong>2. Boleh Pulang Jika Durasi Penuh:</strong> Jika sudah bekerja $\ge$ 8 jam (atau $\ge$ 4 jam Shift 2.2), teknisi juga diizinkan pulang (misal dinas fleksibel).</span>
          </div>
          <div class="rule-item">
            <span class="rule-dot dot-amber"></span>
            <span><strong>3. Early Departure Guard (Anti-Pulang Cepat):</strong> Jika mencoba pulang sebelum jam shift selesai (misal jam 09:00) DAN durasi belum genap, sistem memblokir dengan dialog informatif.</span>
          </div>
          <div class="rule-item">
            <span class="rule-dot dot-green"></span>
            <span><strong>4. Penyelarasan Notifikasi:</strong> Alarm pengingat kepulangan otomatis berbunyi pada jam akhir shift teknisi.</span>
          </div>
        </div>
      </div>

      <div class="status-box" style="background:rgba(37,99,235,0.15);border:1px solid rgba(59,130,246,0.35);color:#93C5FD;">
        💡 <strong>Transparansi Laporan:</strong> Catatan kehadiran, watermark foto, dan laporan harian WhatsApp tetap mencatat durasi kerja riil (misal: 5 Jam), sehingga SPV & HRD memiliki data faktual yang akurat.
      </div>

    </div>

  </div>

  <!-- Bottom Badges -->
  <div class="feature-pills">
    <div class="feat-item"><div class="feat-dot"></div> Handover Pos Lancar & Tepat Waktu</div>
    <div class="feat-item"><div class="feat-dot"></div> Early Departure Guard Tetap Mengunci</div>
    <div class="feat-item"><div class="feat-dot"></div> Notifikasi Pengingat Sesuai Jam Shift</div>
    <div class="feat-item"><div class="feat-dot"></div> Dual Binary ARM64 & ARM32 Release</div>
  </div>
</div>

</body>
</html>
`;

const htmlPath = path.join(OUT_DIR, 'preview_v2049.html');
const pngPath = path.join(OUT_DIR, 'bss_preview_v2049.png');
const repoPngPath = path.join(__dirname, '..', 'bsstimemark', 'BSS-TimeMark-v2.0.49-Preview.png');

fs.writeFileSync(htmlPath, htmlContent, 'utf8');

try {
  execSync(
    `google-chrome-stable --headless=new --disable-gpu --no-sandbox --hide-scrollbars --screenshot="${pngPath}" --window-size=1260,860 "file://${htmlPath}"`,
    { stdio: 'inherit' }
  );
  fs.copyFileSync(pngPath, repoPngPath);
  console.log(`[Preview Generated] Saved to ${pngPath} and ${repoPngPath}`);
  console.log(`Size: ${fs.statSync(repoPngPath).size} bytes`);
} catch (err) {
  console.error('[Preview Error]', err.message);
  process.exit(1);
}
