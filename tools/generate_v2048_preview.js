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
<title>BSS TimeMark - Release Preview v2.0.48</title>
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
    grid-template-columns: 1.15fr 1fr;
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

  /* Camera Topbar Showcase */
  .camera-mockup {
    background: #020617;
    border-radius: 14px;
    border: 1px solid rgba(255,255,255,0.12);
    padding: 14px;
    position: relative;
    overflow: hidden;
  }
  .mockup-label {
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.8px;
    color: #64748B;
    margin-bottom: 8px;
    font-weight: 700;
  }
  .topbar-container {
    background: rgba(15, 23, 42, 0.88);
    border: 1px solid rgba(255,255,255,0.1);
    border-radius: 10px;
    padding: 8px 12px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 12px;
  }
  .topbar-left {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .loc-badge {
    background: #2563EB;
    color: #FFFFFF;
    font-size: 11px;
    font-weight: 800;
    padding: 3px 8px;
    border-radius: 6px;
    letter-spacing: 0.5px;
  }
  .topbar-title {
    font-size: 13px;
    font-weight: 700;
    color: #FFFFFF;
  }
  .topbar-actions {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .topbar-btn {
    background: rgba(255,255,255,0.08);
    border: 1px solid rgba(255,255,255,0.12);
    color: #CBD5E1;
    font-size: 10px;
    font-weight: 600;
    padding: 3px 7px;
    border-radius: 6px;
    display: flex;
    align-items: center;
    gap: 3px;
  }
  .topbar-btn.cloud {
    background: rgba(37, 99, 235, 0.3);
    border-color: #3B82F6;
    color: #93C5FD;
  }

  /* Checkpoint Card Showcase */
  .checkpoint-card {
    background: rgba(15, 23, 42, 0.92);
    border: 1px solid rgba(255,255,255,0.14);
    border-left: 4px solid #3B82F6;
    border-radius: 10px;
    padding: 12px 14px;
  }
  .checkpoint-num {
    display: inline-block;
    background: rgba(59, 130, 246, 0.2);
    color: #60A5FA;
    font-size: 10px;
    font-weight: 800;
    padding: 2px 7px;
    border-radius: 4px;
    margin-bottom: 6px;
  }
  .checkpoint-title {
    font-size: 13px;
    font-weight: 700;
    color: #FFFFFF;
    line-height: 1.35;
    margin-bottom: 4px;
  }
  .checkpoint-desc {
    font-size: 11px;
    color: #94A3B8;
    line-height: 1.45;
  }
  .check-tag {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    margin-top: 8px;
    font-size: 10px;
    font-weight: 700;
    color: #34D399;
    background: rgba(16, 185, 129, 0.15);
    padding: 2px 8px;
    border-radius: 4px;
  }

  /* Rules Box */
  .rule-block {
    background: rgba(2, 6, 23, 0.6);
    border: 1px solid rgba(255,255,255,0.08);
    border-radius: 12px;
    padding: 14px;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .rule-title {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 13px;
    font-weight: 700;
    color: #F8FAFC;
  }
  .rule-steps {
    display: flex;
    flex-direction: column;
    gap: 6px;
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
  .dot-red { background: #EF4444; }
  .dot-green { background: #10B981; }
  .dot-blue { background: #3B82F6; }

  /* Highlight pill */
  .highlight-pill {
    background: rgba(239, 68, 68, 0.15);
    border: 1px solid rgba(239, 68, 68, 0.35);
    color: #FCA5A5;
    font-size: 10px;
    font-weight: 700;
    padding: 6px 10px;
    border-radius: 8px;
    display: flex;
    align-items: center;
    gap: 6px;
  }

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
        <p>Release v2.0.48 • Camera HUD & AI Validation SOP Polish</p>
      </div>
    </div>
    <div class="badge-group">
      <div class="version-tag">Version 2.0.48+56</div>
      <div class="success-tag">✓ 174 Tests Passed</div>
    </div>
  </div>

  <!-- Main Grid -->
  <div class="main-grid">
    
    <!-- Left Column: Camera UI Fixes -->
    <div class="card">
      <div class="card-header">
        <div class="card-title">
          <span class="icon">📸</span>
          <h2>Camera HUD & Text Truncate Fix</h2>
        </div>
        <span class="card-badge badge-blue">UI Refinement</span>
      </div>

      <!-- Live Mockup Component -->
      <div class="camera-mockup">
        <div class="mockup-label">Tampilan Kamera Lapangan (Fixed)</div>
        
        <!-- Topbar -->
        <div class="topbar-container">
          <div class="topbar-left">
            <span class="loc-badge">PBM</span>
            <span class="topbar-title">Maintenance</span>
          </div>
          <div class="topbar-actions">
            <span class="topbar-btn cloud">⚡ AI Cloud</span>
            <span class="topbar-btn">⏱ Off</span>
            <span class="topbar-btn">4:3</span>
            <span class="topbar-btn">⚡ Auto</span>
          </div>
        </div>

        <!-- Checkpoint Card -->
        <div class="checkpoint-card">
          <div class="checkpoint-num">POINT 5 OF 6</div>
          <div class="checkpoint-title">PC Kasir 1 - Port USB & Kerapian Kabel Belakang</div>
          <div class="checkpoint-desc">Port USB printer/scanner kasir terpasang kencang & kabel tersusun rapi.</div>
          <div class="check-tag">✓ Multi-line softWrap • Zero Ellipsis Truncate</div>
        </div>
      </div>

      <!-- What was fixed -->
      <div class="rule-block">
        <div class="rule-title">
          <span>🛠️ Detail Perbaikan Tampilan</span>
          <span class="card-badge badge-emerald">Fixed</span>
        </div>
        <div class="rule-steps">
          <div class="rule-item">
            <span class="rule-dot dot-green"></span>
            <span><strong>Header Tidak Terpotong:</strong> Lokasi <code>PBM</code> dan judul <code>Maintenance</code> tampil penuh, tidak lagi menjadi <code>P...</code>.</span>
          </div>
          <div class="rule-item">
            <span class="rule-dot dot-green"></span>
            <span><strong>Kartu Checkpoint Responsif:</strong> Judul (2 baris) & deskripsi SOP (3 baris) melipat rapi tanpa terpotong titik-titik (<code>...</code>).</span>
          </div>
          <div class="rule-item">
            <span class="rule-dot dot-green"></span>
            <span><strong>Aksi Kontrol Kompak:</strong> Tombol AI Cloud, Timer, Ratio, dan Flash dipadatkan sehingga muat di layar sempit 360px+.</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Right Column: AI Vision & SOP Rules -->
    <div class="card">
      <div class="card-header">
        <div class="card-title">
          <span class="icon">🤖</span>
          <h2>AI Vision & SOP Rules Update</h2>
        </div>
        <span class="card-badge badge-amber">Strict Validation</span>
      </div>

      <!-- Point 2: Update, Antivirus & Firewall -->
      <div class="rule-block">
        <div class="rule-title">
          <span>Poin 2: Update, Antivirus & Firewall</span>
          <span class="card-badge badge-blue">Wajib 3 Tab</span>
        </div>
        <div class="rule-steps">
          <div class="rule-item">
            <span class="rule-dot dot-red"></span>
            <span><strong>Windows Update:</strong> Status Paused / Updates Disabled.</span>
          </div>
          <div class="rule-item">
            <span class="rule-dot dot-red"></span>
            <span><strong>Antivirus:</strong> Real-time protection posisi <strong>OFF</strong>.</span>
          </div>
          <div class="rule-item">
            <span class="rule-dot dot-red"></span>
            <span><strong>Windows Firewall:</strong> Status Defender Firewall posisi <strong>OFF</strong>.</span>
          </div>
        </div>
        <div class="highlight-pill">
          ⚠️ Wajib terlihat 3 jendela/tab nonaktif. Jika hanya 1-2 tab, AI otomatis tolak (tidak_sesuai).
        </div>
      </div>

      <!-- Point 3: Keyboard & Mouse -->
      <div class="rule-block">
        <div class="rule-title">
          <span>Poin 3: Keyboard & Mouse Test</span>
          <span class="card-badge badge-emerald">2 Opsi Sah</span>
        </div>
        <div class="rule-steps">
          <div class="rule-item">
            <span class="rule-dot dot-blue"></span>
            <span><strong>Opsi A (KeyTest.com):</strong> Tampilan browser screen keyboard putih dengan tombol aktif teruji.</span>
          </div>
          <div class="rule-item">
            <span class="rule-dot dot-blue"></span>
            <span><strong>Opsi B (Notepad Test):</strong> Teks <code>1234567890qwertyuiopasdfghjklzxcvbnm</code> + F1-F12 + mouse pointer aktif.</span>
          </div>
        </div>
      </div>

    </div>

  </div>

  <!-- Bottom Badges -->
  <div class="feature-pills">
    <div class="feat-item"><div class="feat-dot"></div> Header Lokasi & Title Anti-Truncate</div>
    <div class="feat-item"><div class="feat-dot"></div> Checkpoint SOP Multi-Line Responsif</div>
    <div class="feat-item"><div class="feat-dot"></div> Validasi 3 Tab Windows Security</div>
    <div class="feat-item"><div class="feat-dot"></div> Dual Binary ARM64 & ARM32 Release</div>
  </div>
</div>

</body>
</html>
`;

const htmlPath = path.join(OUT_DIR, 'preview_v2048.html');
const pngPath = path.join(OUT_DIR, 'bss_preview_v2048.png');
const repoPngPath = path.join(__dirname, '..', 'bsstimemark', 'BSS-TimeMark-v2.0.48-Preview.png');

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
