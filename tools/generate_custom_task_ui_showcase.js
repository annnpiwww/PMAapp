const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const OUT_DIR = '/tmp/bss_preview';
if (!fs.existsSync(OUT_DIR)) {
  fs.mkdirSync(OUT_DIR, { recursive: true });
}

// Baca logo jika ada
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
<title>BSS TimeMark - Rancangan UI/UX Tugas Khusus & Pelaporan</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, "Plus Jakarta Sans", sans-serif; }
  body {
    background: #06090E;
    color: #F8FAFC;
    padding: 28px;
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
  }
  .canvas {
    width: 1420px;
    background: radial-gradient(circle at 10% 10%, #111827 0%, #06090E 90%);
    border-radius: 28px;
    border: 1px solid rgba(255, 255, 255, 0.12);
    box-shadow: 0 40px 100px rgba(0, 0, 0, 0.95);
    padding: 32px 36px;
  }

  /* Header Bar */
  .header-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
    padding-bottom: 22px;
    margin-bottom: 28px;
  }
  .brand-group {
    display: flex;
    align-items: center;
    gap: 16px;
  }
  .app-icon {
    width: 52px;
    height: 52px;
    background: #FFFFFF;
    border: 2px solid #FF6500;
    border-radius: 14px;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    box-shadow: 0 6px 20px rgba(255, 101, 0, 0.35);
  }
  .app-icon img {
    width: 44px;
    height: 44px;
    object-fit: contain;
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
    border-radius: 9999px;
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 0.5px;
    text-transform: uppercase;
  }
  .pill-amber {
    background: rgba(245, 158, 11, 0.15);
    color: #FBBF24;
    border: 1px solid rgba(245, 158, 11, 0.35);
  }
  .pill-emerald {
    background: rgba(16, 185, 129, 0.15);
    color: #34D399;
    border: 1px solid rgba(16, 185, 129, 0.35);
  }
  .pill-blue {
    background: rgba(59, 130, 246, 0.15);
    color: #60A5FA;
    border: 1px solid rgba(59, 130, 246, 0.35);
  }

  /* 3 Phones + 1 Telegram Bubble Grid */
  .screens-grid {
    display: grid;
    grid-template-columns: 320px 360px 320px 360px;
    gap: 22px;
    margin-bottom: 24px;
  }

  /* Phone Mockup Frame */
  .phone-frame {
    background: #0F172A;
    border-radius: 36px;
    border: 2px solid rgba(255, 255, 255, 0.15);
    box-shadow: 0 20px 50px rgba(0, 0, 0, 0.8), inset 0 0 0 2px rgba(255, 255, 255, 0.05);
    overflow: hidden;
    display: flex;
    flex-direction: column;
    height: 640px;
    position: relative;
  }
  .phone-notch {
    height: 24px;
    background: #020617;
    display: flex;
    justify-content: center;
    align-items: center;
    position: relative;
  }
  .phone-notch::before {
    content: '';
    width: 60px;
    height: 10px;
    background: #1E293B;
    border-radius: 999px;
  }
  .phone-header {
    background: #1E293B;
    padding: 12px 14px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  }
  .phone-header-title {
    font-size: 13px;
    font-weight: 700;
    color: #FFFFFF;
  }
  .phone-header-sub {
    font-size: 10px;
    color: #94A3B8;
  }
  .phone-body {
    flex: 1;
    overflow-y: hidden;
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 10px;
    background: #0A0F1D;
  }

  /* Step Badge on Phone */
  .step-label {
    background: rgba(30, 41, 59, 0.8);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 10px;
    padding: 6px 10px;
    font-size: 11px;
    font-weight: 700;
    color: #CBD5E1;
    display: flex;
    align-items: center;
    gap: 6px;
    margin-bottom: 4px;
  }
  .step-label strong {
    color: #FF6500;
  }

  /* Screen 1: Task Cards */
  .task-card {
    background: #1E293B;
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 14px;
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 8px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.3);
  }
  .task-card.active-focus {
    border-color: #FF6500;
    box-shadow: 0 0 16px rgba(255, 101, 0, 0.25);
  }
  .task-card-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
  }
  .task-title {
    font-size: 12px;
    font-weight: 700;
    color: #FFFFFF;
    line-height: 1.35;
  }
  .task-cat-badge {
    font-size: 9px;
    font-weight: 700;
    padding: 3px 8px;
    border-radius: 6px;
    text-transform: uppercase;
  }
  .cat-khusus {
    background: rgba(245, 158, 11, 0.2);
    color: #FBBF24;
    border: 1px solid rgba(245, 158, 11, 0.3);
  }
  .cat-maint {
    background: rgba(59, 130, 246, 0.2);
    color: #60A5FA;
    border: 1px solid rgba(59, 130, 246, 0.3);
  }
  .task-meta {
    font-size: 10px;
    color: #94A3B8;
    display: flex;
    gap: 8px;
  }
  .task-card-action {
    display: flex;
    justify-content: flex-end;
    margin-top: 4px;
  }
  .btn-kerjakan {
    background: #FF6500;
    color: #FFFFFF;
    border: none;
    padding: 7px 14px;
    border-radius: 8px;
    font-size: 11px;
    font-weight: 700;
    display: flex;
    align-items: center;
    gap: 5px;
    cursor: pointer;
    box-shadow: 0 3px 8px rgba(255, 101, 0, 0.4);
  }

  /* Screen 2: Custom Task Execution */
  .exec-box {
    background: #1E293B;
    border-radius: 12px;
    padding: 10px;
    border: 1px solid rgba(255,255,255,0.06);
  }
  .exec-title {
    font-size: 12px;
    font-weight: 800;
    color: #FFFFFF;
    margin-bottom: 2px;
  }
  .exec-sub {
    font-size: 10px;
    color: #94A3B8;
  }
  .section-label {
    font-size: 10px;
    font-weight: 700;
    color: #E2E8F0;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin: 4px 0 2px 0;
  }

  /* Dynamic Photo Grid */
  .photo-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 8px;
  }
  .photo-slot {
    height: 78px;
    background: #0F172A;
    border-radius: 10px;
    border: 1px solid rgba(255,255,255,0.1);
    position: relative;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    justify-content: flex-end;
    padding: 4px;
  }
  .photo-slot.slot-mock-1 {
    background: linear-gradient(180deg, rgba(0,0,0,0.1), rgba(0,0,0,0.85)), #334155;
  }
  .photo-slot.slot-mock-2 {
    background: linear-gradient(180deg, rgba(0,0,0,0.1), rgba(0,0,0,0.85)), #475569;
  }
  .photo-slot.slot-add {
    border: 2px dashed rgba(255, 101, 0, 0.4);
    background: rgba(255, 101, 0, 0.05);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    cursor: pointer;
  }
  .photo-tag {
    font-size: 8px;
    font-weight: 700;
    color: #FFFFFF;
    background: rgba(0,0,0,0.65);
    padding: 2px 4px;
    border-radius: 4px;
    width: fit-content;
  }
  .photo-watermark-mini {
    font-size: 7px;
    color: #F8FAFC;
    line-height: 1.1;
    margin-top: 1px;
  }

  /* Note Area */
  .note-textarea {
    background: #0F172A;
    border: 1px solid rgba(255,255,255,0.12);
    border-radius: 10px;
    padding: 8px 10px;
    color: #F1F5F9;
    font-size: 10px;
    line-height: 1.35;
    height: 72px;
    font-family: inherit;
    resize: none;
    width: 100%;
  }

  /* Dual Action CTA */
  .dual-cta {
    display: flex;
    flex-direction: column;
    gap: 6px;
    margin-top: auto;
  }
  .btn-share-wa {
    background: linear-gradient(135deg, #10B981, #059669);
    color: #FFFFFF;
    border: none;
    border-radius: 10px;
    padding: 9px;
    font-size: 11px;
    font-weight: 700;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    box-shadow: 0 4px 12px rgba(16, 185, 129, 0.35);
  }
  .btn-save-task {
    background: #1E293B;
    color: #FFFFFF;
    border: 1px solid rgba(255,255,255,0.15);
    border-radius: 10px;
    padding: 8px;
    font-size: 11px;
    font-weight: 600;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 5px;
  }

  /* Screen 3: Pulang Bottom Sheet */
  .pulang-card {
    background: #1E293B;
    border-radius: 14px;
    padding: 12px;
    border: 1px solid rgba(255,255,255,0.08);
  }
  .pulang-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 8px;
  }
  .pulang-header h4 {
    font-size: 12px;
    font-weight: 700;
    color: #FFFFFF;
  }
  .pulang-list-box {
    background: #0F172A;
    border-radius: 10px;
    padding: 8px 10px;
    border: 1px solid rgba(16, 185, 129, 0.3);
  }
  .pulang-task-row {
    display: flex;
    align-items: flex-start;
    gap: 6px;
    font-size: 10px;
    color: #E2E8F0;
    margin-bottom: 6px;
    line-height: 1.3;
  }
  .check-icon {
    color: #10B981;
    font-weight: 900;
    font-size: 11px;
  }
  .btn-absen-pulang {
    background: linear-gradient(135deg, #EF4444, #B91C1C);
    color: #FFFFFF;
    border: none;
    border-radius: 10px;
    padding: 10px;
    font-size: 11px;
    font-weight: 700;
    text-align: center;
    box-shadow: 0 4px 12px rgba(239, 68, 68, 0.35);
    margin-top: 10px;
  }

  /* Screen 4: Live Message Bubble (WA / Telegram) */
  .chat-preview-card {
    background: #1E293B;
    border-radius: 24px;
    border: 1px solid rgba(255,255,255,0.12);
    padding: 18px;
    display: flex;
    flex-direction: column;
    height: 640px;
  }
  .chat-app-bar {
    display: flex;
    align-items: center;
    gap: 10px;
    padding-bottom: 12px;
    border-bottom: 1px solid rgba(255,255,255,0.08);
    margin-bottom: 14px;
  }
  .chat-avatar {
    width: 36px;
    height: 36px;
    border-radius: 50%;
    background: #2563EB;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 800;
    font-size: 14px;
    color: #FFFFFF;
  }
  .chat-info h3 {
    font-size: 13px;
    color: #FFFFFF;
    font-weight: 700;
  }
  .chat-info p {
    font-size: 10px;
    color: #10B981;
  }
  .chat-bubble {
    background: #0B3B24;
    border: 1px solid rgba(16, 185, 129, 0.3);
    border-radius: 16px 16px 4px 16px;
    padding: 14px;
    color: #F8FAFC;
    font-size: 11px;
    line-height: 1.45;
    margin-left: 20px;
    position: relative;
    box-shadow: 0 6px 16px rgba(0,0,0,0.4);
  }
  .chat-bubble-photos {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 6px;
    margin-bottom: 10px;
  }
  .chat-thumb {
    height: 80px;
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
  .bubble-time {
    font-size: 9px;
    color: #A7F3D0;
    text-align: right;
    margin-top: 6px;
  }

  /* Bottom Feature Highlights */
  .footer-summary {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 14px;
    border-top: 1px solid rgba(255,255,255,0.08);
    padding-top: 20px;
  }
  .summary-item {
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 14px;
    padding: 12px 14px;
  }
  .summary-item h5 {
    font-size: 12px;
    font-weight: 700;
    color: #F8FAFC;
    margin-bottom: 4px;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .summary-item p {
    font-size: 11px;
    color: #94A3B8;
    line-height: 1.35;
  }
</style>
</head>
<body>

<div class="canvas">

  <!-- Header Section -->
  <div class="header-bar">
    <div class="brand-group">
      <div class="app-icon">
        ${logoBase64 ? `<img src="${logoBase64}" alt="BSS Logo">` : '<span>BSS</span>'}
      </div>
      <div class="brand-meta">
        <h1>BSS Parking TimeMark — Alur Tugas Khusus & Pelaporan Lapangan</h1>
        <p>Arsitektur UI/UX: Dynamic Multi-Foto Dokumentasi, Smart Report Generator WA/Telegram & Auto-Trigger Absensi Pulang</p>
      </div>
    </div>
    <div class="header-badges">
      <span class="pill pill-amber">Kategori Khusus / Custom</span>
      <span class="pill pill-emerald">Zero Duplicate Work</span>
      <span class="pill pill-blue">PocketBase v0.40+</span>
    </div>
  </div>

  <!-- 4-Column Layout: Step 1, Step 2, Step 3, Chat Bubble -->
  <div class="screens-grid">

    <!-- Screen 1: List Tugas Daily -->
    <div class="phone-frame">
      <div class="phone-notch"></div>
      <div class="phone-header">
        <div>
          <div class="phone-header-title">Tugas Saya Hari Ini</div>
          <div class="phone-header-sub">Ryan Lumasuge (Teknisi)</div>
        </div>
        <span class="pill pill-amber" style="padding: 2px 8px; font-size: 9px;">2 TUGAS</span>
      </div>
      <div class="phone-body">
        <div class="step-label"><strong>Langkah 1:</strong> List Tugas & Tombol Kerjakan</div>

        <!-- Task 1: Khusus (Focus) -->
        <div class="task-card active-focus">
          <div class="task-card-header">
            <span class="task-cat-badge cat-khusus">Tugas Khusus</span>
            <span style="font-size: 10px; color: #FBBF24; font-weight: 700;">● Pending</span>
          </div>
          <div class="task-title">Pengecatan pulau dan markah panah lokasi TBM</div>
          <div class="task-meta">
            <span>📍 Pos Gate Utama (TBM)</span>
          </div>
          <div class="task-card-action">
            <button class="btn-kerjakan">
              <span>Kerjakan</span> ➔
            </button>
          </div>
        </div>

        <!-- Task 2: Maintenance -->
        <div class="task-card">
          <div class="task-card-header">
            <span class="task-cat-badge cat-maint">Maintenance Pos</span>
            <span style="font-size: 10px; color: #FBBF24; font-weight: 700;">● Pending</span>
          </div>
          <div class="task-title">Maintenance mingguan: Pembersihan manless lokasi TBM</div>
          <div class="task-meta">
            <span>📍 Pos Gate Utama (GATE 1)</span>
          </div>
          <div class="task-card-action">
            <button class="btn-kerjakan" style="background:#334155; color:#CBD5E1;">
              <span>Kerjakan</span> ➔
            </button>
          </div>
        </div>

        <div style="background: rgba(255,101,0,0.08); border: 1px solid rgba(255,101,0,0.25); border-radius: 10px; padding: 10px; font-size: 10px; color: #FDA4AF; line-height: 1.35; margin-top: auto;">
          👆 <strong>Logika Routing:</strong> Tugas khusus (tanpa template SOP) otomatis membuka <em>CustomTaskExecutionScreen</em> di Langkah 2!
        </div>
      </div>
    </div>

    <!-- Screen 2: Custom Task Execution Screen -->
    <div class="phone-frame">
      <div class="phone-notch"></div>
      <div class="phone-header">
        <div style="display:flex; align-items:center; gap:8px;">
          <span style="font-size:14px; color:#FFFFFF;">‹</span>
          <div>
            <div class="phone-header-title">Lembar Pengerjaan Tugas</div>
            <div class="phone-header-sub">Kategori Khusus / Custom</div>
          </div>
        </div>
        <span class="pill pill-amber" style="padding: 2px 8px; font-size: 9px;">PROSES</span>
      </div>
      <div class="phone-body">
        <div class="step-label"><strong>Langkah 2:</strong> Multi-Foto & Catatan</div>

        <div class="exec-box">
          <div class="exec-title">Pengecatan markah panah lokasi TBM</div>
          <div class="exec-sub">Diberikan oleh: SPV Farhan Lakoro</div>
        </div>

        <!-- Section Multi Foto -->
        <div class="section-label">Dokumentasi Foto (Bebas Jumlah)</div>
        <div class="photo-grid">
          <div class="photo-slot slot-mock-1">
            <span class="photo-tag">Foto 1 (Awal)</span>
            <span class="photo-watermark-mini">BSS 04/10 11:20<br>Pos TBM Ryan</span>
          </div>
          <div class="photo-slot slot-mock-2">
            <span class="photo-tag">Foto 2 (Selesai)</span>
            <span class="photo-watermark-mini">BSS 04/10 13:45<br>Markah Panah</span>
          </div>
          <div class="photo-slot slot-add">
            <span style="font-size: 18px; color: #FF6500; font-weight: 800;">+</span>
            <span style="font-size: 8px; color: #FF6500; font-weight: 700; margin-top: 2px;">Tambah Foto</span>
          </div>
        </div>

        <!-- Section Catatan Draft -->
        <div class="section-label">Catatan Pelaporan (Auto-Fill)</div>
        <textarea class="note-textarea">Selamat siang, izin melaporkan pengecatan markah panah dilokasi TBM sudah selesai dikerjakan, Terimakasih.</textarea>

        <!-- Action Buttons -->
        <div class="dual-cta">
          <button class="btn-share-wa">
            <span>📲</span> Bagikan Laporan (WA / Telegram)
          </button>
          <button class="btn-save-task">
            <span>💾</span> Simpan & Tandai Selesai
          </button>
        </div>
      </div>
    </div>

    <!-- Screen 3: Auto-Trigger Absensi Pulang -->
    <div class="phone-frame">
      <div class="phone-notch"></div>
      <div class="phone-header">
        <div>
          <div class="phone-header-title">Absensi Kepulangan Shift</div>
          <div class="phone-header-sub">Jam 17:00 WITA (Shift Selesai)</div>
        </div>
        <span class="pill pill-emerald" style="padding: 2px 8px; font-size: 9px;">SIAP PULANG</span>
      </div>
      <div class="phone-body">
        <div class="step-label"><strong>Langkah 3:</strong> Auto-Fill Pekerjaan Selesai</div>

        <div class="pulang-card">
          <div class="pulang-header">
            <h4>Ringkasan Tugas Hari Ini</h4>
            <span style="font-size: 10px; color: #10B981; font-weight: 700;">2/2 SELESAI</span>
          </div>
          <div style="font-size: 10px; color: #94A3B8; margin-bottom: 8px;">
            Kolom "Pekerjaan Selesai" otomatis terisi tanpa perlu ketik manual:
          </div>

          <div class="pulang-list-box">
            <div class="pulang-task-row">
              <span class="check-icon">✓</span>
              <span><strong>Pengecatan markah panah lokasi TBM</strong><br><span style="color:#94A3B8;">Selesai 13:45 WITA (Catatan: Cat kering)</span></span>
            </div>
            <div class="pulang-task-row" style="margin-bottom: 0;">
              <span class="check-icon">✓</span>
              <span><strong>Maintenance mingguan: Pembersihan manless</strong><br><span style="color:#94A3B8;">Selesai 15:30 WITA (SOP Lolos)</span></span>
            </div>
          </div>

          <div style="font-size: 10px; color: #94A3B8; margin-top: 10px;">
            Handover Rekan Shift / Pos:
          </div>
          <div style="background:#0F172A; border-radius:8px; padding:6px 8px; font-size:10px; color:#F1F5F9; margin-top:4px;">
            Pos Gate Utama diserahterimakan ke Shift Malam (Aman & Bersih)
          </div>

          <button class="btn-absen-pulang" style="width: 100%;">
            📸 Jepret Foto & Kirim Absensi Pulang
          </button>
        </div>

        <div style="background: rgba(16,185,129,0.08); border: 1px solid rgba(16,185,129,0.25); border-radius: 10px; padding: 10px; font-size: 10px; color: #6EE7B7; line-height: 1.35; margin-top: auto;">
          ✅ <strong>Anti-Double Input:</strong> Semua checklist dan tugas custom yang telah selesai hari ini langsung sinkron jadi data absensi pulang!
        </div>
      </div>
    </div>

    <!-- Column 4: WhatsApp & Telegram Message Bubble Output -->
    <div class="chat-preview-card">
      <div class="chat-app-bar">
        <div class="chat-avatar">BSS</div>
        <div class="chat-info">
          <h3>Grup Operasional BSS Manado</h3>
          <p>WhatsApp / Telegram Live Output</p>
        </div>
      </div>

      <div style="font-size: 10px; color: #94A3B8; margin-bottom: 8px;">
        Format pesan otomatis saat tombol <em>"Bagikan Laporan"</em> ditekan:
      </div>

      <!-- Chat Bubble -->
      <div class="chat-bubble">
        <!-- 2 Photo Thumbnails inside message -->
        <div class="chat-bubble-photos">
          <div class="chat-thumb" style="background:#1E293B;">
            <span style="font-size:7px; background:rgba(0,0,0,0.7); padding:2px 4px; border-radius:3px; color:#FFF;">Foto 1: Kondisi Awal</span>
          </div>
          <div class="chat-thumb" style="background:#334155;">
            <span style="font-size:7px; background:rgba(0,0,0,0.7); padding:2px 4px; border-radius:3px; color:#FFF;">Foto 2: Hasil Akhir</span>
          </div>
        </div>

        <strong>LAPORAN TUGAS HARIAN TEKNISI BSS</strong><br>
        ━━━━━━━━━━━━━━━━━━━━<br>
        👤 <strong>Teknisi:</strong> Ryan Lumasuge<br>
        📅 <strong>Tanggal:</strong> 04 Oktober 2026<br>
        📍 <strong>Lokasi:</strong> Pos Gate Utama - TBM<br>
        🎯 <strong>Pekerjaan:</strong> Pengecatan markah panah lokasi TBM<br>
        ⏰ <strong>Status:</strong> SELESAI (13:45 WITA)<br>
        ━━━━━━━━━━━━━━━━━━━━<br>
        📝 <strong>Catatan:</strong><br>
        <em>"Selamat siang, izin melaporkan pengecatan markah panah dilokasi TBM sudah selesai dikerjakan, Terimakasih."</em>
        <div class="bubble-time">13:46 ✓✓</div>
      </div>

      <div style="background: rgba(59,130,246,0.1); border: 1px solid rgba(59,130,246,0.3); border-radius: 12px; padding: 12px; font-size: 10px; color: #93C5FD; line-height: 1.4; margin-top: auto;">
        💡 <strong>Kelebihan Format Ini:</strong>
        <ul style="margin-left: 14px; margin-top: 4px;">
          <li>Foto asli terlampir langsung di pesan chat.</li>
          <li>Format teks baku & profesional tanpa teknisi capek ngetik ulang.</li>
          <li>Kredensial dan record di PocketBase ikut terupdate real-time.</li>
        </ul>
      </div>
    </div>

  </div>

  <!-- Bottom Pillars (Impeccable & Anti-AI Slop) -->
  <div class="footer-summary">
    <div class="summary-item">
      <h5><span>🎯</span> Dynamic Slot Foto</h5>
      <p>Teknisi bebas jepret 1, 2, 3, atau lebih foto dokumentasi sesuai kebutuhan riil pos lapangan.</p>
    </div>
    <div class="summary-item">
      <h5><span>✍️</span> Smart Auto-Fill Catatan</h5>
      <p>Salam (pagi/siang/sore) dan narasi draft otomatis terisi, namun tetap bisa diedit leluasa.</p>
    </div>
    <div class="summary-item">
      <h5><span>📲</span> Direct WhatsApp/Telegram</h5>
      <p>Integrasi langsung membagikan bundle foto ber-watermark + teks laporan resmi ke grup koordinasi.</p>
    </div>
    <div class="summary-item">
      <h5><span>🔄</span> Auto-Trigger Pulang</h5>
      <p>Data pekerjaan langsung mengalir ke format absensi kepulangan tanpa pekerjaan ganda.</p>
    </div>
  </div>

</div>

</body>
</html>
`;

const htmlPath = path.join(OUT_DIR, 'custom_task_ui_showcase.html');
const pngPath = path.join(OUT_DIR, 'BSS-TimeMark-Custom-Task-Workflow-Showcase.png');
const repoPngPath = path.join(__dirname, '..', 'BSS-TimeMark-Custom-Task-Workflow-Showcase.png');

fs.writeFileSync(htmlPath, htmlContent, 'utf8');

try {
  execSync(
    `google-chrome-stable --headless=new --disable-gpu --no-sandbox --hide-scrollbars --screenshot="${pngPath}" --window-size=1480,940 "file://${htmlPath}"`,
    { stdio: 'inherit' }
  );
  fs.copyFileSync(pngPath, repoPngPath);
  console.log(`[Showcase Generated] Saved to ${pngPath} and ${repoPngPath}`);
  console.log(`File size: ${fs.statSync(repoPngPath).size} bytes`);
} catch (err) {
  console.error('[Showcase Error]', err.message);
  process.exit(1);
}
