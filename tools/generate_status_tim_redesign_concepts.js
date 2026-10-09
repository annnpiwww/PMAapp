const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const OUT_DIR = '/tmp/opencode/redesign_concepts';
if (!fs.existsSync(OUT_DIR)) {
  fs.mkdirSync(OUT_DIR, { recursive: true });
}

// -------------------------------------------------------------
// HTML & CSS Shared Components
// -------------------------------------------------------------
const htmlContent = `<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Redesign Status Tim - PMA BssparkingTimeMark</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Plus Jakarta Sans", sans-serif; }
  
  body {
    background: #06090E;
    color: #F8FAFC;
    padding: 30px;
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
  }

  .showcase-container {
    width: 1540px;
    background: #0B1120;
    border-radius: 24px;
    border: 1px solid #1E293B;
    box-shadow: 0 30px 90px rgba(0, 0, 0, 0.9);
    padding: 32px 36px;
  }

  /* Header */
  .main-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px solid #1E293B;
    padding-bottom: 20px;
    margin-bottom: 28px;
  }
  .brand-badge {
    display: flex;
    align-items: center;
    gap: 14px;
  }
  .logo-box {
    width: 44px;
    height: 44px;
    background: #111827;
    border: 2px solid #FF6500;
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 900;
    color: #FF6500;
    font-size: 16px;
    letter-spacing: 0.5px;
  }
  .brand-title h1 {
    font-size: 20px;
    font-weight: 800;
    color: #FFFFFF;
  }
  .brand-title p {
    font-size: 12px;
    color: #94A3B8;
  }
  .header-meta {
    text-align: right;
  }
  .header-meta .tag {
    display: inline-block;
    background: rgba(255, 101, 0, 0.15);
    color: #FF6500;
    font-size: 11px;
    font-weight: 700;
    padding: 4px 10px;
    border-radius: 20px;
    border: 1px solid rgba(255, 101, 0, 0.3);
  }

  /* Grid Concepts */
  .concepts-grid {
    display: grid;
    grid-template-columns: 1fr 1fr 1fr;
    gap: 28px;
  }

  /* Phone Mockup Frame */
  .phone-card {
    background: #0F172A;
    border-radius: 20px;
    border: 1px solid #334155;
    padding: 16px;
    display: flex;
    flex-direction: column;
  }
  .phone-header {
    margin-bottom: 14px;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .phone-header .badge-concept {
    font-size: 11px;
    font-weight: 800;
    padding: 4px 10px;
    border-radius: 6px;
    letter-spacing: 0.5px;
  }
  .badge-a { background: #FF6500; color: #FFF; }
  .badge-b { background: #3B82F6; color: #FFF; }
  .badge-bs { background: #10B981; color: #FFF; }
  
  .phone-frame {
    width: 100%;
    height: 720px;
    background: #080D1A;
    border-radius: 24px;
    border: 3px solid #1E293B;
    overflow: hidden;
    position: relative;
    display: flex;
    flex-direction: column;
    box-shadow: 0 16px 36px rgba(0, 0, 0, 0.6);
  }

  /* Status Bar */
  .status-bar {
    height: 28px;
    background: #0B1120;
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0 16px;
    font-size: 10px;
    color: #94A3B8;
    font-weight: 600;
    border-bottom: 1px solid #1E293B;
  }

  /* Concept Summary Footer */
  .concept-desc {
    margin-top: 14px;
    font-size: 12px;
    color: #CBD5E1;
    line-height: 1.5;
  }
  .concept-desc strong {
    color: #FFF;
  }
  .feature-list {
    margin-top: 8px;
    list-style: none;
    font-size: 11px;
    color: #94A3B8;
  }
  .feature-list li {
    margin-bottom: 4px;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .feature-list li::before {
    content: "•";
    color: #FF6500;
    font-weight: bold;
  }

  /* ------------------- STYLING KONSEP A ------------------- */
  .konsep-a-appbar {
    background: #111827;
    padding: 10px 14px;
    border-bottom: 1px solid #1E293B;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .appbar-title {
    font-size: 13.5px;
    font-weight: 800;
    color: #FFFFFF;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .appbar-actions {
    display: flex;
    gap: 6px;
    align-items: center;
  }
  .btn-control-tim {
    background: rgba(255, 101, 0, 0.15);
    border: 1px solid #FF6500;
    color: #FF6500;
    font-size: 10.5px;
    font-weight: 700;
    padding: 5px 9px;
    border-radius: 8px;
    display: flex;
    align-items: center;
    gap: 5px;
  }
  
  /* Quick Top Toolbar */
  .quick-toolbar {
    background: #0D1527;
    padding: 8px 12px;
    border-bottom: 1px solid #1E293B;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .toolbar-row-1 {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .date-indicator {
    font-size: 11px;
    color: #E2E8F0;
    font-weight: 700;
    display: flex;
    align-items: center;
    gap: 4px;
  }
  .mini-rekap-pill {
    background: rgba(16, 185, 129, 0.15);
    border: 1px solid rgba(16, 185, 129, 0.35);
    color: #10B981;
    font-size: 10px;
    font-weight: 800;
    padding: 3px 8px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    gap: 4px;
  }

  /* Status Filter Pills (Selesai, Belum Mulai, Semua) */
  .status-pills-row {
    display: flex;
    gap: 6px;
  }
  .status-pill {
    flex: 1;
    text-align: center;
    padding: 6px 0;
    border-radius: 8px;
    font-size: 11px;
    font-weight: 700;
  }
  .status-pill.active {
    background: #FF6500;
    color: #FFF;
    box-shadow: 0 2px 8px rgba(255, 101, 0, 0.4);
  }
  .status-pill.inactive {
    background: #111827;
    border: 1px solid #1E293B;
    color: #94A3B8;
  }

  /* Horizontal Tech Chips */
  .tech-chips-scroll {
    display: flex;
    gap: 6px;
    overflow-x: hidden;
    padding-bottom: 2px;
  }
  .tech-chip {
    white-space: nowrap;
    padding: 3.5px 8px;
    border-radius: 12px;
    font-size: 10px;
    font-weight: 600;
    display: flex;
    align-items: center;
    gap: 4px;
  }
  .tech-chip.active {
    background: rgba(255, 101, 0, 0.2);
    border: 1px solid #FF6500;
    color: #FFF;
  }
  .tech-chip.inactive {
    background: #111827;
    border: 1px solid #1E293B;
    color: #94A3B8;
  }

  /* Task Scroll Feed */
  .task-feed {
    flex: 1;
    padding: 10px 12px;
    overflow-y: hidden;
    display: flex;
    flex-direction: column;
    gap: 7px;
  }

  /* Ultra-Compact Task Card (Konsep A) */
  .compact-card {
    background: #111827;
    border: 1px solid #1E293B;
    border-radius: 10px;
    padding: 8px 10px;
    display: flex;
    flex-direction: column;
    gap: 4px;
    border-left: 3px solid #334155;
  }
  .compact-card.done {
    border-left: 3px solid #10B981;
    background: rgba(17, 24, 39, 0.95);
  }
  .compact-card.pending {
    border-left: 3px solid #FF6500;
  }
  .card-top-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .tech-name-tag {
    font-size: 11px;
    font-weight: 700;
    color: #CBD5E1;
    display: flex;
    align-items: center;
    gap: 5px;
  }
  .tech-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
  }
  .dot-green { background: #10B981; }
  .dot-orange { background: #FF6500; }

  .badge-status-pill {
    font-size: 10px;
    font-weight: 700;
    padding: 2px 7px;
    border-radius: 6px;
  }
  .badge-status-pill.done {
    background: rgba(16, 185, 129, 0.15);
    color: #10B981;
  }
  .badge-status-pill.pending {
    background: rgba(255, 101, 0, 0.15);
    color: #FF6500;
  }

  .task-main-title {
    font-size: 12px;
    font-weight: 700;
    color: #FFFFFF;
    line-height: 1.3;
  }
  .task-main-title.strikethrough {
    color: #94A3B8;
    text-decoration: line-through;
  }

  .card-bottom-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 10px;
    color: #64748B;
  }
  .loc-text {
    display: flex;
    align-items: center;
    gap: 3px;
    color: #94A3B8;
    font-weight: 600;
  }
  .notes-indicator-pill {
    background: rgba(59, 130, 246, 0.12);
    color: #60A5FA;
    padding: 1.5px 5px;
    border-radius: 4px;
    font-size: 9.5px;
    font-weight: 600;
  }

  /* ------------------- STYLING KONSEP B ------------------- */
  .konsep-b-appbar {
    background: #0B1120;
    padding: 12px 14px;
    border-bottom: 1px solid #1E293B;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .b-top-action {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .btn-b-control {
    background: #FF6500;
    color: #FFF;
    font-size: 11px;
    font-weight: 800;
    padding: 6px 12px;
    border-radius: 20px;
    display: flex;
    align-items: center;
    gap: 5px;
    box-shadow: 0 2px 10px rgba(255, 101, 0, 0.35);
  }
  
  .b-segment-bar {
    background: #0F172A;
    padding: 8px 12px;
    border-bottom: 1px solid #1E293B;
  }
  .b-segment-group {
    background: #080D1A;
    border: 1px solid #1E293B;
    border-radius: 10px;
    display: flex;
    padding: 3px;
  }
  .b-segment-item {
    flex: 1;
    text-align: center;
    padding: 6px 0;
    font-size: 11px;
    font-weight: 700;
    border-radius: 8px;
    color: #94A3B8;
  }
  .b-segment-item.active {
    background: #1E293B;
    color: #FF6500;
    border: 1px solid rgba(255, 101, 0, 0.4);
  }

  /* Card Model B: High-Scan Grid */
  .card-model-b {
    background: #111827;
    border: 1px solid #1E293B;
    border-radius: 12px;
    padding: 10px 12px;
    display: flex;
    gap: 10px;
  }
  .avatar-initial {
    width: 32px;
    height: 32px;
    border-radius: 8px;
    background: #1E293B;
    color: #FF6500;
    font-weight: 800;
    font-size: 11.5px;
    display: flex;
    align-items: center;
    justify-content: center;
    border: 1px solid rgba(255, 101, 0, 0.3);
  }
  .avatar-initial.done {
    color: #10B981;
    border-color: rgba(16, 185, 129, 0.3);
    background: rgba(16, 185, 129, 0.1);
  }
  .card-b-content {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 3px;
  }
  .card-b-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .card-b-header .name {
    font-size: 11.5px;
    font-weight: 700;
    color: #F8FAFC;
  }
  .card-b-header .time {
    font-size: 10px;
    color: #10B981;
    font-weight: 700;
  }

  /* ------------------- STYLING BOTTOM SHEET ------------------- */
  .sheet-modal-backdrop {
    background: rgba(4, 7, 13, 0.7);
    height: 100%;
    display: flex;
    flex-direction: column;
    justify-content: flex-end;
  }
  .sheet-container {
    background: #111827;
    border-top: 1px solid #334155;
    border-radius: 20px 20px 0 0;
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 14px;
    box-shadow: 0 -10px 40px rgba(0, 0, 0, 0.8);
  }
  .sheet-handle {
    width: 38px;
    height: 4px;
    background: #334155;
    border-radius: 2px;
    margin: 0 auto -4px auto;
  }
  .sheet-title-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .sheet-title {
    font-size: 14px;
    font-weight: 800;
    color: #FFFFFF;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .sheet-rekap-box {
    background: #0B1120;
    border: 1px solid #1E293B;
    border-radius: 12px;
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .progress-track {
    height: 6px;
    background: #1E293B;
    border-radius: 3px;
    overflow: hidden;
  }
  .progress-bar-fill {
    height: 100%;
    width: 28%;
    background: #FF6500;
  }
  .stat-grid-sheet {
    display: grid;
    grid-template-columns: 1fr 1fr 1fr;
    gap: 6px;
    text-align: center;
  }
  .stat-box-sheet {
    background: #111827;
    border: 1px solid #1E293B;
    border-radius: 8px;
    padding: 6px 4px;
  }
  .stat-box-sheet .val { font-size: 13px; font-weight: 800; color: #FFF; }
  .stat-box-sheet .lbl { font-size: 9.5px; color: #94A3B8; }

  .sheet-section-title {
    font-size: 11px;
    font-weight: 700;
    color: #94A3B8;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
  .btn-share-rekap-sheet {
    background: rgba(37, 211, 102, 0.15);
    border: 1px solid #25D366;
    color: #25D366;
    font-size: 12px;
    font-weight: 800;
    padding: 10px;
    border-radius: 10px;
    text-align: center;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
  }
</style>
</head>
<body>

<div class="showcase-container">
  
  <!-- Main Header -->
  <div class="main-header">
    <div class="brand-badge">
      <div class="logo-box">PMA</div>
      <div class="brand-title">
        <h1>Redesign Status Tim: Mobile-First &amp; Task-Focused</h1>
        <p>Solusi Zero-Scroll: Eliminasi Card Header Raksasa &bull; Fokus Instan ke Pekerjaan &bull; Data Riil Lapangan KC BSG</p>
      </div>
    </div>
    <div class="header-meta">
      <div class="tag">SPV : FARHAN LAKORO</div>
      <div style="font-size: 11px; color: #64748B; margin-top: 4px;">Selasa, 06 Okt 2026 &bull; Total: 7 Tugas</div>
    </div>
  </div>

  <!-- Concepts Comparison Grid -->
  <div class="concepts-grid">

    <!-- ==============================================
         KONSEP 1 (A): Inline Streamline & Quick-Bar
         ============================================== -->
    <div class="phone-card">
      <div class="phone-header">
        <span class="badge-concept badge-a">KONSEP A: INLINE STREAMLINE</span>
        <span style="font-size: 11px; color: #FF6500; font-weight: 700;">★ Recommended</span>
      </div>

      <div class="phone-frame">
        <!-- Status Bar -->
        <div class="status-bar">
          <span>09:49</span>
          <span>●●● 4G &bull; 95%</span>
        </div>

        <!-- Mini Appbar -->
        <div class="konsep-a-appbar">
          <div class="appbar-title">
            <span>📋 Status Tim</span>
          </div>
          <div class="appbar-actions">
            <div class="btn-control-tim">
              <span>🎛️ Kontrol Tim</span>
            </div>
          </div>
        </div>

        <!-- Quick Top Bar: Tanggal + Mini Rekap + Quick Status + Tech Chips -->
        <div class="quick-toolbar">
          <div class="toolbar-row-1">
            <div class="date-indicator">
              <span>📅 Hari Ini (06 Okt)</span>
            </div>
            <div class="mini-rekap-pill">
              <span>⚡ 2/7 Selesai (28%)</span>
            </div>
          </div>

          <!-- Status Filter: Selesai (2), Belum Mulai (5), Semua (7) -->
          <div class="status-pills-row">
            <div class="status-pill active">Selesai (2)</div>
            <div class="status-pill inactive">Belum Mulai (5)</div>
            <div class="status-pill inactive">Semua (7)</div>
          </div>

          <!-- Horizontal Tech Chips -->
          <div class="tech-chips-scroll">
            <div class="tech-chip active">Semua</div>
            <div class="tech-chip inactive">Ryan (1/2)</div>
            <div class="tech-chip inactive">Raldy (0/2)</div>
            <div class="tech-chip inactive">Junifer (0/2)</div>
            <div class="tech-chip inactive">Alessandro (1/1)</div>
          </div>
        </div>

        <!-- Direct Task Feed: 5-6 Items Visible Instantly -->
        <div class="task-feed">
          
          <!-- Item 1: Selesai -->
          <div class="compact-card done">
            <div class="card-top-row">
              <div class="tech-name-tag">
                <span class="tech-dot dot-green"></span>
                <span>Ryan Lumasuge</span>
              </div>
              <span class="badge-status-pill done">✓ Selesai · 09:49 WITA</span>
            </div>
            <div class="task-main-title strikethrough">Backup server, hapus foto, upload cloud &amp; HDD</div>
            <div class="card-bottom-row">
              <span class="loc-text">📍 NBM</span>
              <span class="notes-indicator-pill">📝 Catatan tersedia</span>
            </div>
          </div>

          <!-- Item 2: Selesai -->
          <div class="compact-card done">
            <div class="card-top-row">
              <div class="tech-name-tag">
                <span class="tech-dot dot-green"></span>
                <span>Alessandro Sulistyo</span>
              </div>
              <span class="badge-status-pill done">✓ Selesai · 11:15 WITA</span>
            </div>
            <div class="task-main-title strikethrough">Maintenance PC Kasir &amp; Sensor Loop</div>
            <div class="card-bottom-row">
              <span class="loc-text">📍 TBM · SOP MTC</span>
              <span class="notes-indicator-pill">📝 Catatan tersedia</span>
            </div>
          </div>

          <!-- Item 3: Belum Mulai -->
          <div class="compact-card pending">
            <div class="card-top-row">
              <div class="tech-name-tag">
                <span class="tech-dot dot-orange"></span>
                <span>Raldy Sangkop</span>
              </div>
              <span class="badge-status-pill pending">◷ Belum Mulai</span>
            </div>
            <div class="task-main-title">Backup server, hapus foto, upload cloud &amp; HDD</div>
            <div class="card-bottom-row">
              <span class="loc-text">📍 MGMK</span>
              <span>Prioritas Pagi</span>
            </div>
          </div>

          <!-- Item 4: Belum Mulai -->
          <div class="compact-card pending">
            <div class="card-top-row">
              <div class="tech-name-tag">
                <span class="tech-dot dot-orange"></span>
                <span>Junifer Manua</span>
              </div>
              <span class="badge-status-pill pending">◷ Belum Mulai</span>
            </div>
            <div class="task-main-title">Ganti housing Gateout 1–6</div>
            <div class="card-bottom-row">
              <span class="loc-text">📍 PBM</span>
              <span>Baut kendor</span>
            </div>
          </div>

          <!-- Item 5: Belum Mulai -->
          <div class="compact-card pending">
            <div class="card-top-row">
              <div class="tech-name-tag">
                <span class="tech-dot dot-orange"></span>
                <span>Ryan Lumasuge</span>
              </div>
              <span class="badge-status-pill pending">◷ Belum Mulai</span>
            </div>
            <div class="task-main-title">Testing PSU &amp; Fan stok</div>
            <div class="card-bottom-row">
              <span class="loc-text">📍 PBM</span>
              <span>Stok cadangan</span>
            </div>
          </div>

        </div>
      </div>

      <div class="concept-desc">
        <strong>Konsep A: Inline Streamline &amp; Quick-Bar</strong>
        <p>Seluruh filter dibuat ultra-ramping di atas (< 100px). Card pekerjaan langsung terlihat 5-6 item tanpa scrolling sama sekali.</p>
        <ul class="feature-list">
          <li>Rekap Tim diubah jadi mini pill ("⚡ 2/7 Selesai").</li>
          <li>Quick Filter Pill 3 opsi: Selesai, Belum Mulai, Semua.</li>
          <li>Tech chips horizontal langsung filter 1-tap.</li>
          <li>Tombol "Kontrol Tim" membuka rekap &amp; setelan mendalam.</li>
        </ul>
      </div>
    </div>


    <!-- ==============================================
         KONSEP 2 (B): Focus Feed & Minimal Top
         ============================================== -->
    <div class="phone-card">
      <div class="phone-header">
        <span class="badge-concept badge-b">KONSEP B: MINIMAL TOP &amp; AVATAR</span>
        <span style="font-size: 11px; color: #94A3B8;">Clean &amp; Modern</span>
      </div>

      <div class="phone-frame">
        <!-- Status Bar -->
        <div class="status-bar">
          <span>09:49</span>
          <span>●●● 4G &bull; 95%</span>
        </div>

        <!-- Minimal Appbar -->
        <div class="konsep-b-appbar">
          <div>
            <div style="font-size: 14px; font-weight: 800; color: #FFF;">Status Tim</div>
            <div style="font-size: 10px; color: #94A3B8;">06 Okt 2026 &bull; 2/7 Selesai</div>
          </div>
          <div class="b-top-action">
            <div class="btn-b-control">
              <span>🎛️ Kontrol Tim</span>
            </div>
          </div>
        </div>

        <!-- Quick Segment Bar: Selesai (2), Belum Mulai (5), Semua (7) -->
        <div class="b-segment-bar">
          <div class="b-segment-group">
            <div class="b-segment-item active">Selesai (2)</div>
            <div class="b-segment-item">Belum Mulai (5)</div>
            <div class="b-segment-item">Semua (7)</div>
          </div>
        </div>

        <!-- Task Feed Model B (Avatar Initial + Structured Grid) -->
        <div class="task-feed">
          
          <!-- Item 1 -->
          <div class="card-model-b">
            <div class="avatar-initial done">RL</div>
            <div class="card-b-content">
              <div class="card-b-header">
                <span class="name">Ryan Lumasuge</span>
                <span class="time">✓ 09:49 WITA</span>
              </div>
              <div style="font-size: 12px; font-weight: 700; color: #94A3B8; text-decoration: line-through;">
                Backup server, hapus foto, upload cloud &amp; HDD
              </div>
              <div style="display:flex; justify-content:space-between; margin-top: 2px;">
                <span style="font-size: 10.5px; color: #E2E8F0; font-weight: 600;">📍 NBM</span>
                <span class="notes-indicator-pill">Catatan ada</span>
              </div>
            </div>
          </div>

          <!-- Item 2 -->
          <div class="card-model-b">
            <div class="avatar-initial done">AS</div>
            <div class="card-b-content">
              <div class="card-b-header">
                <span class="name">Alessandro Sulistyo</span>
                <span class="time">✓ 11:15 WITA</span>
              </div>
              <div style="font-size: 12px; font-weight: 700; color: #94A3B8; text-decoration: line-through;">
                Maintenance PC Kasir &amp; Sensor Loop
              </div>
              <div style="display:flex; justify-content:space-between; margin-top: 2px;">
                <span style="font-size: 10.5px; color: #E2E8F0; font-weight: 600;">📍 TBM</span>
                <span class="notes-indicator-pill">Catatan ada</span>
              </div>
            </div>
          </div>

          <!-- Item 3 -->
          <div class="card-model-b">
            <div class="avatar-initial">RS</div>
            <div class="card-b-content">
              <div class="card-b-header">
                <span class="name">Raldy Sangkop</span>
                <span style="font-size: 10px; color: #FF6500; font-weight: 700;">◷ Belum</span>
              </div>
              <div style="font-size: 12px; font-weight: 700; color: #FFFFFF;">
                Backup server, hapus foto, upload cloud &amp; HDD
              </div>
              <div style="display:flex; justify-content:space-between; margin-top: 2px;">
                <span style="font-size: 10.5px; color: #94A3B8; font-weight: 600;">📍 MGMK</span>
                <span style="font-size: 10px; color: #64748B;">Pagi</span>
              </div>
            </div>
          </div>

          <!-- Item 4 -->
          <div class="card-model-b">
            <div class="avatar-initial">JM</div>
            <div class="card-b-content">
              <div class="card-b-header">
                <span class="name">Junifer Manua</span>
                <span style="font-size: 10px; color: #FF6500; font-weight: 700;">◷ Belum</span>
              </div>
              <div style="font-size: 12px; font-weight: 700; color: #FFFFFF;">
                Ganti housing Gateout 1–6
              </div>
              <div style="display:flex; justify-content:space-between; margin-top: 2px;">
                <span style="font-size: 10.5px; color: #94A3B8; font-weight: 600;">📍 PBM</span>
                <span style="font-size: 10px; color: #64748B;">Siang</span>
              </div>
            </div>
          </div>

          <!-- Item 5 -->
          <div class="card-model-b">
            <div class="avatar-initial">RL</div>
            <div class="card-b-content">
              <div class="card-b-header">
                <span class="name">Ryan Lumasuge</span>
                <span style="font-size: 10px; color: #FF6500; font-weight: 700;">◷ Belum</span>
              </div>
              <div style="font-size: 12px; font-weight: 700; color: #FFFFFF;">
                Testing PSU &amp; Fan stok
              </div>
              <div style="display:flex; justify-content:space-between; margin-top: 2px;">
                <span style="font-size: 10.5px; color: #94A3B8; font-weight: 600;">📍 PBM</span>
                <span style="font-size: 10px; color: #64748B;">Stok</span>
              </div>
            </div>
          </div>

        </div>
      </div>

      <div class="concept-desc">
        <strong>Konsep B: Minimal Top &amp; Initial Avatar</strong>
        <p>Header paling ringkas. Filter status berupa Segmented Control elegan. Card menampilkan inisial teknisi untuk identifikasi instan.</p>
        <ul class="feature-list">
          <li>Avatar badge inisial teknisi (RL, AS, RS, JM).</li>
          <li>Header ultra-ramping (< 50px).</li>
          <li>Fokus 100% pada list pekerjaan.</li>
          <li>Seluruh kontrol lanjutan ada di tombol "Kontrol Tim".</li>
        </ul>
      </div>
    </div>


    <!-- ==============================================
         BOTTOM SHEET "KONTROL TIM" (SHARED)
         ============================================== -->
    <div class="phone-card">
      <div class="phone-header">
        <span class="badge-concept badge-bs">BOTTOM SHEET: KONTROL TIM</span>
        <span style="font-size: 11px; color: #10B981; font-weight: 700;">Modal Preview</span>
      </div>

      <div class="phone-frame">
        <!-- Status Bar -->
        <div class="status-bar">
          <span>09:49</span>
          <span>●●● 4G &bull; 95%</span>
        </div>

        <!-- Backdrop with Sheet Open -->
        <div class="sheet-modal-backdrop">
          
          <div class="sheet-container">
            <div class="sheet-handle"></div>

            <div class="sheet-title-row">
              <div class="sheet-title">
                <span>🎛️ Kontrol Tim &amp; Rekap Harian</span>
              </div>
              <div style="font-size: 11px; color: #94A3B8;">Tutup ✕</div>
            </div>

            <!-- Rekap Progress Card di dalam Bottom Sheet -->
            <div class="sheet-rekap-box">
              <div style="display:flex; justify-content:space-between; align-items:center;">
                <span style="font-size:12px; font-weight:700; color:#FFF;">Progress Tim PMA KC BSG</span>
                <span style="font-size:11px; font-weight:800; color:#FF6500;">28% Selesai</span>
              </div>
              <div class="progress-track">
                <div class="progress-bar-fill"></div>
              </div>
              <div class="stat-grid-sheet">
                <div class="stat-box-sheet">
                  <div class="val">7</div>
                  <div class="lbl">Total Tugas</div>
                </div>
                <div class="stat-box-sheet">
                  <div class="val" style="color:#10B981;">2</div>
                  <div class="lbl">Selesai</div>
                </div>
                <div class="stat-box-sheet">
                  <div class="val" style="color:#FF6500;">5</div>
                  <div class="lbl">Belum Mulai</div>
                </div>
              </div>
            </div>

            <!-- Pilihan Tanggal -->
            <div>
              <div class="sheet-section-title">Pilih Tanggal Operasional</div>
              <div style="display:flex; gap:6px; margin-top:6px;">
                <div style="flex:1; background:#FF6500; color:#FFF; font-size:11px; font-weight:700; text-align:center; padding:6px; border-radius:8px;">Hari Ini</div>
                <div style="flex:1; background:#0B1120; border:1px solid #1E293B; color:#94A3B8; font-size:11px; font-weight:600; text-align:center; padding:6px; border-radius:8px;">Kemarin</div>
                <div style="flex:1; background:#0B1120; border:1px solid #1E293B; color:#94A3B8; font-size:11px; font-weight:600; text-align:center; padding:6px; border-radius:8px;">Pilih 📅</div>
              </div>
            </div>

            <!-- Filter Teknisi Lengkap -->
            <div>
              <div class="sheet-section-title">Filter Teknisi Lapangan</div>
              <div style="display:flex; flex-wrap:wrap; gap:6px; margin-top:6px;">
                <div style="background:rgba(255,101,0,0.2); border:1px solid #FF6500; color:#FFF; font-size:10.5px; font-weight:700; padding:4px 9px; border-radius:14px;">Semua (7)</div>
                <div style="background:#0B1120; border:1px solid #1E293B; color:#94A3B8; font-size:10.5px; padding:4px 9px; border-radius:14px;">Ryan (1/2)</div>
                <div style="background:#0B1120; border:1px solid #1E293B; color:#94A3B8; font-size:10.5px; padding:4px 9px; border-radius:14px;">Raldy (0/2)</div>
                <div style="background:#0B1120; border:1px solid #1E293B; color:#94A3B8; font-size:10.5px; padding:4px 9px; border-radius:14px;">Junifer (0/2)</div>
                <div style="background:#0B1120; border:1px solid #1E293B; color:#94A3B8; font-size:10.5px; padding:4px 9px; border-radius:14px;">Alessandro (1/1)</div>
              </div>
            </div>

            <!-- Tombol Bagikan Rekap WA -->
            <div class="btn-share-rekap-sheet">
              <span>📲</span> Bagikan Rekap Tim ke WhatsApp
            </div>

          </div>

        </div>
      </div>

      <div class="concept-desc">
        <strong>Bottom Sheet: "Kontrol Tim"</strong>
        <p>Membuka saat tombol "Kontrol Tim" ditekan di Konsep A atau Konsep B. Menyimpan semua fungsi berat agar layar utama bersih.</p>
        <ul class="feature-list">
          <li>Rekap Tim lengkap dengan tombol share WA standar.</li>
          <li>Pemilih tanggal (Hari Ini, Kemarin, Custom).</li>
          <li>Filter teknisi granular.</li>
          <li>Menjaga layar utama 100% fokus pada task feed.</li>
        </ul>
      </div>
    </div>

  </div>

</div>

</body>
</html>
`;

const htmlPath = path.join(OUT_DIR, 'status_tim_redesign_concepts.html');
fs.writeFileSync(htmlPath, htmlContent);

const outPngPath = path.join(OUT_DIR, 'PMA-Status-Tim-Redesign-Showcase.png');
try {
  execSync(`google-chrome-stable --headless --disable-gpu --screenshot="${outPngPath}" --window-size=1600,1050 "${htmlPath}"`, { stdio: 'inherit' });
  console.log('SUCCESS: Rendered showcase to ' + outPngPath);
} catch (e) {
  console.error('Failed to render screenshot', e);
}
