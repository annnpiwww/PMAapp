#!/usr/bin/env python3
"""
PMA App (BssparkingTimeMark) UI Redesign Concepts Generator
Generates HTML mockups and renders PNGs for 3 distinct design concepts across 7 core screens:
  Concept A: Grouped List (iOS Settings / HIG Systemic)
  Concept B: Ops Board (Industrial Tactical / High-Density Operations)
  Concept C: Bold Type (Editorial Minimal / Typographic Hierarchy)
"""

import os
import subprocess
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

def get_font_css():
    return """
    @font-face {
      font-family: 'PlusJakartaSans';
      src: url('/home/annnpii/Product development annpii/BssparkingTimeMark/assets/fonts/PlusJakartaSans-Regular.ttf') format('truetype');
      font-weight: 400;
      font-style: normal;
    }
    @font-face {
      font-family: 'PlusJakartaSans';
      src: url('/home/annnpii/Product development annpii/BssparkingTimeMark/assets/fonts/PlusJakartaSans-Medium.ttf') format('truetype');
      font-weight: 500;
      font-style: normal;
    }
    @font-face {
      font-family: 'PlusJakartaSans';
      src: url('/home/annnpii/Product development annpii/BssparkingTimeMark/assets/fonts/PlusJakartaSans-SemiBold.ttf') format('truetype');
      font-weight: 600;
      font-style: normal;
    }
    @font-face {
      font-family: 'PlusJakartaSans';
      src: url('/home/annnpii/Product development annpii/BssparkingTimeMark/assets/fonts/PlusJakartaSans-Bold.ttf') format('truetype');
      font-weight: 700;
      font-style: normal;
    }
    @font-face {
      font-family: 'PlusJakartaSans';
      src: url('/home/annnpii/Product development annpii/BssparkingTimeMark/assets/fonts/PlusJakartaSans-ExtraBold.ttf') format('truetype');
      font-weight: 800;
      font-style: normal;
    }
    """

def wrap_html(title, body_content, theme="light", concept="A", extra_css=""):
    font_css = get_font_css()
    return f"""<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=390, height=844, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>{title}</title>
  <style>
    {font_css}
    * {{
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      -webkit-tap-highlight-color: transparent;
    }}
    body {{
      font-family: 'PlusJakartaSans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      width: 390px;
      height: 844px;
      overflow-x: hidden;
      overflow-y: auto;
      margin: 0 auto;
      position: relative;
      background: var(--bg);
      color: var(--text-primary);
      -webkit-font-smoothing: antialiased;
    }}
    /* Scrollbar hidden for mockups */
    body::-webkit-scrollbar {{
      display: none;
    }}
    {extra_css}
  </style>
</head>
<body class="concept-{concept.lower()} theme-{theme}">
  {body_content}
</body>
</html>
"""

def generate_concept_a():
    c_dir = os.path.join(BASE_DIR, "A")
    os.makedirs(c_dir, exist_ok=True)

    common_css = """
    :root {
      --bg: #F2F2F7;
      --surface: #FFFFFF;
      --text-primary: #000000;
      --text-secondary: #6C6C70;
      --accent: #007AFF;
      --accent-bg: rgba(0, 122, 255, 0.12);
      --divider: #E5E5EA;
      --success: #34C759;
      --success-bg: rgba(52, 199, 89, 0.12);
      --warning: #FF9500;
      --warning-bg: rgba(255, 149, 0, 0.12);
      --danger: #FF3B30;
      --danger-bg: rgba(255, 59, 48, 0.12);
      --card-radius: 10px;
    }
    body.theme-dark {
      --bg: #000000;
      --surface: #1C1C1E;
      --text-primary: #FFFFFF;
      --text-secondary: #8E8E93;
      --accent: #0A84FF;
      --accent-bg: rgba(10, 132, 255, 0.2);
      --divider: #38383A;
      --success: #30D158;
      --success-bg: rgba(48, 209, 88, 0.2);
      --warning: #FF9F0A;
      --warning-bg: rgba(255, 159, 10, 0.2);
      --danger: #FF453A;
      --danger-bg: rgba(255, 69, 58, 0.2);
    }
    .app-header {
      padding: 16px 16px 8px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      background: var(--bg);
      position: sticky;
      top: 0;
      z-index: 10;
    }
    .app-header h1 {
      font-size: 20px;
      font-weight: 700;
      letter-spacing: -0.3px;
    }
    .header-action {
      font-size: 14px;
      font-weight: 600;
      color: var(--accent);
      background: none;
      border: none;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 4px;
      min-height: 44px;
      padding: 0 4px;
    }
    .section-title {
      font-size: 12px;
      font-weight: 600;
      color: var(--text-secondary);
      text-transform: uppercase;
      letter-spacing: 0.5px;
      padding: 16px 16px 6px;
    }
    .grouped-box {
      margin: 0 16px 16px;
      background: var(--surface);
      border-radius: var(--card-radius);
      border: 0.5px solid var(--divider);
      overflow: hidden;
    }
    .list-row {
      display: flex;
      align-items: center;
      padding: 12px 14px;
      min-height: 48px;
      position: relative;
    }
    .list-row:not(:last-child)::after {
      content: '';
      position: absolute;
      left: 54px;
      right: 0;
      bottom: 0;
      height: 0.5px;
      background: var(--divider);
    }
    .row-icon {
      width: 28px;
      height: 28px;
      border-radius: 6px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 14px;
      margin-right: 12px;
      flex-shrink: 0;
    }
    .row-content {
      flex: 1;
      min-width: 0;
    }
    .row-title {
      font-size: 14px;
      font-weight: 600;
      line-height: 1.3;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .row-subtitle {
      font-size: 12px;
      color: var(--text-secondary);
      margin-top: 2px;
      line-height: 1.3;
    }
    .row-trailing {
      display: flex;
      align-items: center;
      gap: 6px;
      margin-left: 8px;
      flex-shrink: 0;
    }
    .pill {
      font-size: 12px;
      font-weight: 700;
      padding: 4px 8px;
      border-radius: 20px;
      display: inline-flex;
      align-items: center;
      gap: 4px;
    }
    .pill-success { background: var(--success-bg); color: var(--success); }
    .pill-warning { background: var(--warning-bg); color: var(--warning); }
    .pill-danger { background: var(--danger-bg); color: var(--danger); }
    .pill-neutral { background: rgba(120, 120, 128, 0.12); color: var(--text-secondary); }
    .pill-accent { background: var(--accent-bg); color: var(--accent); }

    .bottom-bar {
      position: sticky;
      bottom: 0;
      left: 0;
      right: 0;
      padding: 12px 16px 20px;
      background: var(--bg);
      border-top: 0.5px solid var(--divider);
      z-index: 20;
    }
    .btn-primary {
      width: 100%;
      height: 48px;
      background: var(--accent);
      color: #FFFFFF;
      font-size: 14px;
      font-weight: 700;
      border-radius: 10px;
      border: none;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      cursor: pointer;
    }
    .btn-tonal {
      width: 100%;
      height: 48px;
      background: var(--accent-bg);
      color: var(--accent);
      font-size: 14px;
      font-weight: 700;
      border-radius: 10px;
      border: none;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      cursor: pointer;
    }
    """

    # 1. camera_home.html
    body_cam = """
    <div style="background:#0F172A; width:100%; height:844px; display:flex; flex-direction:column; position:relative; color:#fff;">
      <!-- Top HUD Bar -->
      <div style="height:64px; display:flex; align-items:center; justify-content:space-between; padding:0 16px; background:rgba(0,0,0,0.5);">
        <div style="display:flex; align-items:center; gap:8px;">
          <div style="width:38px; height:38px; border-radius:19px; background:rgba(255,255,255,0.15); display:flex; align-items:center; justify-content:center; position:relative;">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2"><path d="M4 6h16M4 12h16M4 18h16"/></svg>
            <span style="position:absolute; top:-2px; right:-2px; background:#EF4444; color:#fff; font-size:10px; font-weight:800; padding:1px 5px; border-radius:10px;">2</span>
          </div>
          <div style="height:36px; padding:0 10px; border-radius:18px; background:rgba(255,255,255,0.15); display:flex; align-items:center; gap:4px; font-size:12px; font-weight:700;">
            <span>3:4</span>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="#fff"><path d="M7 10l5 5 5-5z"/></svg>
          </div>
          <div style="height:36px; padding:0 10px; border-radius:18px; background:rgba(255,255,255,0.15); display:flex; align-items:center; gap:4px; font-size:12px; font-weight:700;">
            <span>Timer</span>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="#fff"><path d="M7 10l5 5 5-5z"/></svg>
          </div>
        </div>
        <div style="display:flex; align-items:center; gap:8px;">
          <div style="width:38px; height:38px; border-radius:19px; background:rgba(255,255,255,0.15); display:flex; align-items:center; justify-content:center;">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2"><path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/></svg>
          </div>
          <div style="width:38px; height:38px; border-radius:19px; background:rgba(255,255,255,0.15); display:flex; align-items:center; justify-content:center;">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2"><path d="M20 4v5h-5M4 20v-5h5M4 4l16 16"/></svg>
          </div>
        </div>
      </div>

      <!-- Viewfinder Area -->
      <div style="flex:1; position:relative; background:#1E293B; display:flex; flex-direction:column; justify-content:space-between; padding:16px;">
        <!-- Watermark Overlay Inset -->
        <div style="background:rgba(15,23,42,0.85); border-radius:8px; padding:10px 12px; font-size:12px; line-height:1.4; border:1px solid rgba(255,255,255,0.1); width:fit-content; max-width:85%;">
          <div style="display:flex; align-items:center; gap:6px; margin-bottom:4px;">
            <span style="background:#0284C7; color:#fff; font-size:10px; font-weight:800; padding:1px 6px; border-radius:4px;">PBM</span>
            <span style="font-weight:700; color:#F8FAFC;">Pos Pasar Bersehati Manado</span>
          </div>
          <div style="color:#CBD5E1; font-size:11px;">Jl. Nusantara No. 123 Calaca Wenang Kota Manado</div>
          <div style="color:#94A3B8; font-size:10.5px; margin-top:2px;">1.4921° N, 124.8412° E · 08 Nov 2026, 09:30:15 WITA</div>
          <div style="color:#38BDF8; font-weight:700; font-size:10.5px; margin-top:2px;">SOP Barrier Gate Manless · VERIFIED #BSS-8941</div>
        </div>

        <!-- Right Zoom Controls -->
        <div style="position:absolute; right:12px; top:50%; transform:translateY(-50%); display:flex; flex-direction:column; gap:8px;">
          <div style="width:36px; height:36px; border-radius:18px; background:rgba(0,0,0,0.6); border:1px solid #fff; color:#fff; display:flex; align-items:center; justify-content:center; font-size:11px; font-weight:800;">1x</div>
          <div style="width:36px; height:36px; border-radius:18px; background:rgba(0,0,0,0.6); border:1px solid rgba(255,255,255,0.3); color:#fff; display:flex; align-items:center; justify-content:center; font-size:11px; font-weight:800;">2x</div>
          <div style="width:36px; height:36px; border-radius:18px; background:rgba(0,0,0,0.6); border:1px solid rgba(255,255,255,0.3); color:#fff; display:flex; align-items:center; justify-content:center; font-size:11px; font-weight:800;">5x</div>
        </div>

        <!-- Location Picker Button -->
        <div style="align-self:flex-end; width:38px; height:38px; border-radius:19px; background:rgba(0,0,0,0.7); border:1.5px solid #0284C7; display:flex; align-items:center; justify-content:center;">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#0284C7" stroke-width="2"><path d="M12 2a8 8 0 0 0-8 8c0 5.25 8 12 8 12s8-6.75 8-12a8 8 0 0 0-8-8z"/><circle cx="12" cy="10" r="3"/></svg>
        </div>
      </div>

      <!-- Bottom Controls Bar -->
      <div style="height:158px; background:rgba(0,0,0,0.7); display:flex; flex-direction:column; align-items:center; justify-content:center; padding:10px 24px;">
        <!-- Shift Shortcut Pill -->
        <div style="background:#1E293B; border:1px solid rgba(56,189,248,0.8); padding:6px 14px; border-radius:20px; display:flex; align-items:center; gap:6px; font-size:12px; font-weight:700; color:#fff; margin-bottom:12px;">
          <span style="width:8px; height:8px; border-radius:4px; background:#4ADE80;"></span>
          <span>Masuk : Shift Pagi (08:00 - 16:00)</span>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="#fff"><path d="M7 10l5 5 5-5z"/></svg>
        </div>

        <!-- Controls Row -->
        <div style="width:100%; display:flex; align-items:center; justify-content:space-between;">
          <!-- Gallery Button -->
          <div style="display:flex; flex-direction:column; align-items:center; gap:4px; width:48px;">
            <div style="width:44px; height:44px; border-radius:10px; background:#334155; border:1.5px solid rgba(255,255,255,0.4); display:flex; align-items:center; justify-content:center;">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><path d="M21 15l-5-5L5 21"/></svg>
            </div>
            <span style="font-size:11px; font-weight:600; color:#94A3B8;">Galeri</span>
          </div>

          <!-- Shutter Button -->
          <div style="width:72px; height:72px; border-radius:36px; border:3px solid #007AFF; padding:4px; display:flex; align-items:center; justify-content:center;">
            <div style="width:100%; height:100%; border-radius:30px; background:#FFFFFF; display:flex; align-items:center; justify-content:center;">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="#007AFF"><path d="M12 15a3 3 0 100-6 3 3 0 000 6z"/><path d="M9 2L7.17 4H4a2 2 0 00-2 2v12a2 2 0 002 2h16a2 2 0 002-2V6a2 2 0 00-2-2h-3.17L15 2H9zm3 15a5 5 0 110-10 5 5 0 010 10z"/></svg>
            </div>
          </div>

          <!-- SOP Shortcut Button -->
          <div style="display:flex; flex-direction:column; align-items:center; gap:4px; width:48px;">
            <div style="width:44px; height:44px; border-radius:10px; background:#334155; border:1.5px solid rgba(255,255,255,0.4); display:flex; align-items:center; justify-content:center;">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2"><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><path d="M14 2v6h6M16 13H8M16 17H8M10 9H8"/></svg>
            </div>
            <span style="font-size:11px; font-weight:600; color:#94A3B8;">SOP</span>
          </div>
        </div>
      </div>
    </div>
    """
    with open(os.path.join(c_dir, "camera_home.html"), "w", encoding="utf-8") as f:
        f.write(wrap_html("Camera Home - Concept A", body_cam, "light", "A", common_css))

    # 2. teknisi_tasks.html
    body_tasks = """
    <div class="app-header">
      <div>
        <h1>Daily Task</h1>
        <div style="font-size:12px; color:var(--text-secondary); margin-top:2px;">Budi Santoso · IT Support KC BSG</div>
      </div>
      <button class="header-action">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67"/></svg>
        <span>Refresh</span>
      </button>
    </div>

    <!-- Group 1: Progress Summary -->
    <div class="section-title">Status Pengerjaan</div>
    <div class="grouped-box">
      <div class="list-row" style="padding:14px;">
        <div class="row-icon" style="background:var(--accent-bg); color:var(--accent);">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>
        </div>
        <div class="row-content">
          <div style="font-size:16px; font-weight:700;">2 dari 4 Selesai</div>
          <div class="row-subtitle">Sisa 2 tugas hari ini</div>
        </div>
        <div class="row-trailing">
          <span class="pill pill-accent">50% Selesai</span>
        </div>
      </div>
      <div style="padding:0 14px 12px;">
        <div style="height:6px; background:var(--divider); border-radius:3px; overflow:hidden;">
          <div style="width:50%; height:100%; background:var(--accent);"></div>
        </div>
      </div>
      <div class="list-row" style="background:rgba(0,122,255,0.04);">
        <div class="row-icon" style="color:var(--accent);">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01" stroke="#fff" stroke-width="2"/></svg>
        </div>
        <div class="row-content">
          <div style="font-size:12px; color:var(--text-secondary); line-height:1.35;">Tugas selesai otomatis masuk ke Laporan Pulang saat absen dinas berakhir.</div>
        </div>
      </div>
    </div>

    <!-- Group 2: Tugas Hari Ini -->
    <div class="section-title">Tugas Hari Ini (4 Tugas)</div>
    <div class="grouped-box">
      <!-- Item 1: Selesai -->
      <div class="list-row">
        <div class="row-icon" style="background:var(--success-bg); color:var(--success);">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>
        </div>
        <div class="row-content">
          <div class="row-title" style="text-decoration:line-through; color:var(--text-secondary);">Cek Barrier Gate Masuk 1 & Sensor Loop</div>
          <div class="row-subtitle">Pos Pasar Bersehati · Maintenance · Selesai 09:30 WITA</div>
        </div>
        <div class="row-trailing">
          <span class="pill pill-success">Bukti Ada</span>
        </div>
      </div>

      <!-- Item 2: Selesai -->
      <div class="list-row">
        <div class="row-icon" style="background:var(--success-bg); color:var(--success);">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>
        </div>
        <div class="row-content">
          <div class="row-title" style="text-decoration:line-through; color:var(--text-secondary);">Ganti Kertas Thermal Printer Tiket Manless</div>
          <div class="row-subtitle">Gate 2 PBM · Tugas Khusus · Selesai 10:15 WITA</div>
        </div>
        <div class="row-trailing">
          <span class="pill pill-success">Bukti Ada</span>
        </div>
      </div>

      <!-- Item 3: Ongoing / Belum (Long text case) -->
      <div class="list-row">
        <div class="row-icon" style="background:var(--warning-bg); color:var(--warning);">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a10 10 0 100 20 10 10 0 000-20zm1 14h-2v-2h2v2zm0-4h-2V7h2v5z"/></svg>
        </div>
        <div class="row-content">
          <div class="row-title">Pembersihan Sensor Gate Kotor dan Kalibrasi Palang Penghalang Sedikit Miring</div>
          <div class="row-subtitle">Gate 1 PBM · Maintenance · Bersama Agus Setiawan</div>
          <div style="font-size:12px; color:var(--text-secondary); margin-top:4px;">Catatan: Pastikan baut angkur dikencangkan ulang dan sensor optik bebas debu pekat.</div>
        </div>
        <div class="row-trailing">
          <span class="pill pill-warning">Belum</span>
        </div>
      </div>

      <!-- Item 4: Belum -->
      <div class="list-row">
        <div class="row-icon" style="background:rgba(120,120,128,0.12); color:var(--text-secondary);">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="12" r="9"/></svg>
        </div>
        <div class="row-content">
          <div class="row-title">Pemeriksaan PC Server & Switch Hub Utama</div>
          <div class="row-subtitle">Server Utama PBM · Maintenance</div>
        </div>
        <div class="row-trailing">
          <button style="padding:6px 12px; font-size:12px; font-weight:700; background:var(--accent); color:#fff; border-radius:6px; border:none; cursor:pointer;">Kerjakan</button>
        </div>
      </div>
    </div>

    <!-- Group 3: Tugas Shift Sebelumnya -->
    <div class="section-title">Tugas Shift Sebelumnya (1 Belum Selesai)</div>
    <div class="grouped-box">
      <div class="list-row">
        <div class="row-icon" style="background:var(--danger-bg); color:var(--danger);">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
        </div>
        <div class="row-content">
          <div class="row-title">Perbaikan Kabel LAN Kasir 2 Putus Terinjak</div>
          <div class="row-subtitle">Lanjutan dari Farhan Lakoro · Kemarin 17:00 WITA</div>
        </div>
        <div class="row-trailing">
          <button style="padding:6px 12px; font-size:12px; font-weight:700; background:var(--accent); color:#fff; border-radius:6px; border:none; cursor:pointer;">Lanjutkan</button>
        </div>
      </div>
    </div>

    <!-- Bottom Bar Button -->
    <div class="bottom-bar">
      <button class="btn-primary">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M12 5v14M5 12h14"/></svg>
        <span>Catat Kerjaan Baru</span>
      </button>
    </div>
    """
    with open(os.path.join(c_dir, "teknisi_tasks.html"), "w", encoding="utf-8") as f:
        f.write(wrap_html("Teknisi Daily Tasks - Concept A", body_tasks, "light", "A", common_css))

    # 3. spv_dispatch.html
    body_spv = """
    <div class="app-header">
      <div style="display:flex; align-items:center; gap:8px;">
        <button style="background:none; border:none; cursor:pointer; min-height:44px; display:flex; align-items:center;">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="var(--text-primary)" stroke-width="2.5"><path d="M15 18l-6-6 6-6"/></svg>
        </button>
        <div>
          <h1>Penugasan Harian SPV</h1>
          <div style="font-size:12px; color:var(--text-secondary);">KC Manado · 08 Nov 2026</div>
        </div>
      </div>
      <div style="display:flex; align-items:center; gap:4px;">
        <button class="header-action" title="Format WA Briefing">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><path d="M8.59 13.51l6.83 3.98M15.41 6.51l-6.82 3.98"/></svg>
        </button>
        <button class="header-action" title="Kontrol Tim">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 21v-7M4 10V3M12 21v-9M12 8V3M20 21v-5M20 12V3M1 14h6M9 8h6M17 16h6"/></svg>
        </button>
      </div>
    </div>

    <!-- Group 1: Rekap Metrik -->
    <div class="section-title">Ringkasan Tim</div>
    <div class="grouped-box">
      <div class="list-row" style="padding:14px;">
        <div class="row-icon" style="background:var(--accent-bg); color:var(--accent);">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5s-3 1.34-3 3 1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z"/></svg>
        </div>
        <div class="row-content">
          <div style="font-size:16px; font-weight:700;">4 dari 6 Selesai (67%)</div>
          <div class="row-subtitle">2 tugas pending · 3 teknisi aktif dinas</div>
        </div>
        <div class="row-trailing">
          <span class="pill pill-warning">2 Pending</span>
        </div>
      </div>
    </div>

    <!-- Group 2: Filter Status & Teknisi -->
    <div class="section-title">Filter Tugas</div>
    <div style="padding:0 16px 12px; display:flex; gap:8px; overflow-x:auto;">
      <button style="padding:8px 14px; border-radius:20px; font-size:12px; font-weight:700; background:var(--accent); color:#fff; border:none; white-space:nowrap;">Semua (6)</button>
      <button style="padding:8px 14px; border-radius:20px; font-size:12px; font-weight:600; background:var(--surface); color:var(--text-secondary); border:0.5px solid var(--divider); white-space:nowrap;">Budi Santoso (3)</button>
      <button style="padding:8px 14px; border-radius:20px; font-size:12px; font-weight:600; background:var(--surface); color:var(--text-secondary); border:0.5px solid var(--divider); white-space:nowrap;">Farhan Lakoro (2)</button>
      <button style="padding:8px 14px; border-radius:20px; font-size:12px; font-weight:600; background:var(--surface); color:var(--text-secondary); border:0.5px solid var(--divider); white-space:nowrap;">Agus Setiawan (1)</button>
    </div>

    <!-- Group 3: Daftar Tugas Tim -->
    <div class="section-title">Daftar Tugas Petugas Lapangan</div>
    <div class="grouped-box">
      <!-- Item 1 -->
      <div class="list-row">
        <div class="row-icon" style="background:var(--warning-bg); color:var(--warning);">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a10 10 0 100 20 10 10 0 000-20zm1 14h-2v-2h2v2zm0-4h-2V7h2v5z"/></svg>
        </div>
        <div class="row-content">
          <div class="row-title">Pembersihan Sensor Gate Kotor & Kalibrasi Palang Miring</div>
          <div class="row-subtitle">Petugas: Budi Santoso · Pos Pasar Bersehati · Prioritas Tinggi</div>
        </div>
        <div class="row-trailing">
          <button style="padding:6px 10px; font-size:12px; font-weight:600; color:var(--accent); background:none; border:none; cursor:pointer;">Alihkan</button>
        </div>
      </div>

      <!-- Item 2 -->
      <div class="list-row">
        <div class="row-icon" style="background:var(--warning-bg); color:var(--warning);">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a10 10 0 100 20 10 10 0 000-20zm1 14h-2v-2h2v2zm0-4h-2V7h2v5z"/></svg>
        </div>
        <div class="row-content">
          <div class="row-title">Penggantian Switch Hub 8-Port di Pos Kasir 2</div>
          <div class="row-subtitle">Petugas: Farhan Lakoro · Pos Mega Mall Manado</div>
        </div>
        <div class="row-trailing">
          <button style="padding:6px 10px; font-size:12px; font-weight:600; color:var(--accent); background:none; border:none; cursor:pointer;">Alihkan</button>
        </div>
      </div>

      <!-- Item 3: Selesai -->
      <div class="list-row">
        <div class="row-icon" style="background:var(--success-bg); color:var(--success);">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>
        </div>
        <div class="row-content">
          <div class="row-title" style="text-decoration:line-through; color:var(--text-secondary);">Cek Barrier Gate Masuk 1</div>
          <div class="row-subtitle">Budi Santoso · Selesai 09:30 WITA · Lolos Verifikasi</div>
        </div>
        <div class="row-trailing">
          <span class="pill pill-success">Selesai</span>
        </div>
      </div>

      <!-- Item 4: Selesai -->
      <div class="list-row">
        <div class="row-icon" style="background:var(--success-bg); color:var(--success);">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>
        </div>
        <div class="row-content">
          <div class="row-title" style="text-decoration:line-through; color:var(--text-secondary);">Ganti Kertas Thermal Printer Gate 2</div>
          <div class="row-subtitle">Budi Santoso · Selesai 10:15 WITA</div>
        </div>
        <div class="row-trailing">
          <span class="pill pill-success">Selesai</span>
        </div>
      </div>
    </div>

    <!-- Bottom Bar Button -->
    <div class="bottom-bar">
      <button class="btn-primary">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M12 5v14M5 12h14"/></svg>
        <span>Buat Tugas Baru</span>
      </button>
    </div>
    """
    with open(os.path.join(c_dir, "spv_dispatch.html"), "w", encoding="utf-8") as f:
        f.write(wrap_html("SPV Task Dispatcher - Concept A", body_spv, "light", "A", common_css))

    # 4. location_detail.html & location_detail_dark.html & location_detail_ts13.html
    def build_location_detail_content(is_dark=False, ts13=False):
        theme_cls = "dark" if is_dark else "light"
        font_mult = "font-size: 1.3em;" if ts13 else ""
        return f"""
        <div class="app-header" style="{font_mult}">
          <div style="display:flex; align-items:center; gap:8px;">
            <button style="background:none; border:none; cursor:pointer; min-height:44px; display:flex; align-items:center;">
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="var(--text-primary)" stroke-width="2.5"><path d="M15 18l-6-6 6-6"/></svg>
            </button>
            <div>
              <h1>Detail Lokasi Maintenance</h1>
              <div style="font-size:12px; color:var(--text-secondary);">Periode November 2026</div>
            </div>
          </div>
          <button class="header-action">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67"/></svg>
          </button>
        </div>

        <!-- Section 1: Lokasi & Akses -->
        <div class="section-title">Informasi Pos & Lokasi</div>
        <div class="grouped-box">
          <div class="list-row" style="padding:14px;">
            <div class="row-icon" style="background:#0284C7; color:#fff; font-weight:800; font-size:11px;">PBM</div>
            <div class="row-content">
              <div style="font-size:16px; font-weight:700;">Pos Pasar Bersehati Manado</div>
              <div class="row-subtitle">Jl. Nusantara No. 123 Calaca Wenang Kota Manado</div>
            </div>
          </div>
          <div class="list-row">
            <div class="row-icon" style="color:var(--text-secondary);">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
            </div>
            <div class="row-content">
              <div style="font-size:13px; font-weight:600;">Teknisi Bertugas</div>
              <div class="row-subtitle">Budi Santoso (NPP-10123)</div>
            </div>
          </div>
          <div class="list-row">
            <div class="row-icon" style="color:var(--text-secondary);">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg>
            </div>
            <div class="row-content">
              <div style="font-size:13px; font-weight:600;">Waktu Inspeksi Terakhir</div>
              <div class="row-subtitle">03 Nov 2026 · 09:30 WITA</div>
            </div>
          </div>
          <div style="padding:10px 14px;">
            <button class="btn-tonal">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="3 11 22 2 13 21 11 13 3 11"/></svg>
              <span>Buka di Google Maps</span>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 13v6a2 2 0 01-2 2H5a2 2 0 01-2-2V8a2 2 0 012-2h6M15 3h6v6M10 14L21 3"/></svg>
            </button>
          </div>
        </div>

        <!-- Section 2: Progres Maintenance 4 Fase -->
        <div class="section-title" style="display:flex; justify-content:space-between; align-items:center;">
          <span>Progres Maintenance</span>
          <span style="font-weight:700; color:var(--accent);">1 / 4 Fase Selesai</span>
        </div>
        <div class="grouped-box">
          <div style="display:grid; grid-template-columns:repeat(4, 1fr); padding:10px 6px; gap:4px; text-align:center;">
            <!-- Fase 1 (Selected) -->
            <div style="background:var(--accent-bg); border:1.5px solid var(--accent); border-radius:8px; padding:8px 2px;">
              <div style="font-size:12px; font-weight:700; color:var(--accent);">Fase 1</div>
              <div style="font-size:16px; font-weight:800; margin:3px 0;">23/24</div>
              <span class="pill pill-warning" style="font-size:10.5px; padding:2px 4px;">Temuan</span>
            </div>
            <!-- Fase 2 -->
            <div style="background:var(--bg); border:0.5px solid var(--divider); border-radius:8px; padding:8px 2px;">
              <div style="font-size:12px; font-weight:600; color:var(--text-secondary);">Fase 2</div>
              <div style="font-size:14px; font-weight:700; color:var(--text-secondary); margin:3px 0;">8-14</div>
              <span class="pill pill-neutral" style="font-size:10.5px; padding:2px 4px;">Belum</span>
            </div>
            <!-- Fase 3 -->
            <div style="background:var(--bg); border:0.5px solid var(--divider); border-radius:8px; padding:8px 2px;">
              <div style="font-size:12px; font-weight:600; color:var(--text-secondary);">Fase 3</div>
              <div style="font-size:14px; font-weight:700; color:var(--text-secondary); margin:3px 0;">15-21</div>
              <span class="pill pill-neutral" style="font-size:10.5px; padding:2px 4px;">Belum</span>
            </div>
            <!-- Fase 4 -->
            <div style="background:var(--bg); border:0.5px solid var(--divider); border-radius:8px; padding:8px 2px;">
              <div style="font-size:12px; font-weight:600; color:var(--text-secondary);">Fase 4</div>
              <div style="font-size:14px; font-weight:700; color:var(--text-secondary); margin:3px 0;">22-31</div>
              <span class="pill pill-neutral" style="font-size:10.5px; padding:2px 4px;">Belum</span>
            </div>
          </div>
          <div class="list-row" style="background:var(--warning-bg); border-top:0.5px solid var(--divider);">
            <div class="row-icon" style="color:var(--warning);">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a10 10 0 100 20 10 10 0 000-20zm1 14h-2v-2h2v2zm0-4h-2V7h2v5z"/></svg>
            </div>
            <div class="row-content">
              <div style="font-size:12px; font-weight:700; color:var(--warning);">1 Temuan Terbuka Membutuhkan Perbaikan</div>
            </div>
          </div>
        </div>

        <!-- Section 3: Tabs (Checklist vs Temuan) -->
        <div style="padding:0 16px 8px; display:flex; gap:8px;">
          <button style="flex:1; height:38px; border-radius:8px; font-size:13px; font-weight:600; background:var(--surface); color:var(--text-secondary); border:0.5px solid var(--divider); cursor:pointer;">Checklist (24)</button>
          <button style="flex:1; height:38px; border-radius:8px; font-size:13px; font-weight:700; background:var(--accent); color:#fff; border:none; cursor:pointer;">Temuan (1)</button>
        </div>

        <!-- Section 4: Temuan List -->
        <div class="grouped-box">
          <div class="list-row" style="align-items:flex-start; padding:14px;">
            <div class="row-icon" style="background:var(--warning-bg); color:var(--warning); margin-top:2px;">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a10 10 0 100 20 10 10 0 000-20zm1 14h-2v-2h2v2zm0-4h-2V7h2v5z"/></svg>
            </div>
            <div class="row-content">
              <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:4px;">
                <span style="font-size:11px; font-weight:800; background:var(--danger-bg); color:var(--danger); padding:2px 6px; border-radius:4px;">URGENT</span>
                <span class="pill pill-warning" style="font-size:11px;">Belum Diperbaiki</span>
              </div>
              <div class="row-title" style="white-space:normal;">Sensor gate kotor dan palang penghalang sedikit miring butuh kalibrasi</div>
              <div style="font-size:12px; color:var(--text-secondary); margin-top:4px;">Alasan: Perlu dibersihkan segera dengan cairan pembersih khusus elektronik dan baut angkur dikencangkan ulang.</div>
              <div style="margin-top:12px;">
                <button class="btn-primary" style="height:42px; font-size:13px;">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M23 19a2 2 0 01-2 2H3a2 2 0 01-2-2V8a2 2 0 012-2h4l2-3h6l2 3h4a2 2 0 012 2z"/><circle cx="12" cy="13" r="4"/></svg>
                  <span>Tandai Sudah Diperbaiki</span>
                </button>
              </div>
            </div>
          </div>
        </div>
        """

    with open(os.path.join(c_dir, "location_detail.html"), "w", encoding="utf-8") as f:
        f.write(wrap_html("Location Detail - Concept A", build_location_detail_content(False), "light", "A", common_css))
    with open(os.path.join(c_dir, "location_detail_dark.html"), "w", encoding="utf-8") as f:
        f.write(wrap_html("Location Detail Dark - Concept A", build_location_detail_content(True), "dark", "A", common_css))
    with open(os.path.join(c_dir, "location_detail_ts13.html"), "w", encoding="utf-8") as f:
        f.write(wrap_html("Location Detail TS 1.3 - Concept A", build_location_detail_content(False, True), "light", "A", common_css))

    # 5. map_maintenance.html
    body_map = """
    <div class="app-header">
      <div style="display:flex; align-items:center; gap:8px;">
        <button style="background:none; border:none; cursor:pointer; min-height:44px; display:flex; align-items:center;">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="var(--text-primary)" stroke-width="2.5"><path d="M15 18l-6-6 6-6"/></svg>
        </button>
        <div>
          <h1>Map Maintenance</h1>
          <div style="font-size:12px; color:var(--text-secondary);">Monitoring Sebaran Wilayah</div>
        </div>
      </div>
      <button class="header-action">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67"/></svg>
      </button>
    </div>

    <!-- Filter Control Inset -->
    <div class="grouped-box" style="margin-bottom:8px;">
      <div style="display:flex; align-items:center; justify-content:space-between; padding:8px 12px;">
        <div style="display:flex; align-items:center; gap:6px;">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--accent)" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
          <span style="font-size:13px; font-weight:700;">Nov 2026</span>
        </div>
        <div style="height:18px; width:1px; background:var(--divider);"></div>
        <div style="display:flex; align-items:center; gap:6px;">
          <span style="font-size:13px; font-weight:600; color:var(--text-secondary);">Wilayah:</span>
          <span class="pill pill-accent" style="font-size:12px;">Manado (12 Pos)</span>
        </div>
      </div>
    </div>

    <!-- Phase Selector Inset -->
    <div style="padding:0 16px 8px; display:flex; gap:6px;">
      <button style="flex:1; height:34px; border-radius:8px; font-size:12px; font-weight:700; background:var(--accent); color:#fff; border:none;">Fase 1 (1-7)</button>
      <button style="flex:1; height:34px; border-radius:8px; font-size:12px; font-weight:600; background:var(--surface); color:var(--text-secondary); border:0.5px solid var(--divider);">Fase 2</button>
      <button style="flex:1; height:34px; border-radius:8px; font-size:12px; font-weight:600; background:var(--surface); color:var(--text-secondary); border:0.5px solid var(--divider);">Fase 3</button>
      <button style="flex:1; height:34px; border-radius:8px; font-size:12px; font-weight:600; background:var(--surface); color:var(--text-secondary); border:0.5px solid var(--divider);">Fase 4</button>
    </div>

    <!-- Map Canvas Simulation -->
    <div style="position:relative; width:100%; height:460px; background:#E5E7EB; border-top:1px solid var(--divider); border-bottom:1px solid var(--divider); overflow:hidden;">
      <!-- Simplified Map Grid Roads -->
      <svg width="100%" height="100%" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
            <path d="M 40 0 L 0 0 0 40" fill="none" stroke="#D1D5DB" stroke-width="1"/>
          </pattern>
        </defs>
        <rect width="100%" height="100%" fill="#E5E7EB"/>
        <path d="M 0 180 Q 150 120 390 260" fill="none" stroke="#93C5FD" stroke-width="12"/>
        <path d="M 120 0 L 180 460" fill="none" stroke="#FFFFFF" stroke-width="8"/>
        <path d="M 0 320 L 390 300" fill="none" stroke="#FFFFFF" stroke-width="6"/>
      </svg>

      <!-- Pin 1: Pasar Bersehati (Orange / Temuan) -->
      <div style="position:absolute; left:160px; top:190px; transform:translate(-50%, -100%); display:flex; flex-direction:column; align-items:center;">
        <div style="background:#FF9500; color:#fff; font-size:11px; font-weight:800; padding:4px 8px; border-radius:12px; box-shadow:0 2px 6px rgba(0,0,0,0.2); white-space:nowrap; display:flex; align-items:center; gap:4px;">
          <span>PBM</span>
          <span style="background:#fff; color:#FF9500; font-size:9px; border-radius:6px; padding:0 3px;">1</span>
        </div>
        <div style="width:0; height:0; border-left:5px solid transparent; border-right:5px solid transparent; border-top:6px solid #FF9500;"></div>
      </div>

      <!-- Pin 2: Mega Mall (Green / Aman) -->
      <div style="position:absolute; left:260px; top:120px; transform:translate(-50%, -100%); display:flex; flex-direction:column; align-items:center;">
        <div style="background:#34C759; color:#fff; font-size:11px; font-weight:800; padding:4px 8px; border-radius:12px; box-shadow:0 2px 6px rgba(0,0,0,0.2); white-space:nowrap;">
          <span>MMM (Aman)</span>
        </div>
        <div style="width:0; height:0; border-left:5px solid transparent; border-right:5px solid transparent; border-top:6px solid #34C759;"></div>
      </div>

      <!-- Pin 3: Mantos (Grey / Belum) -->
      <div style="position:absolute; left:80px; top:280px; transform:translate(-50%, -100%); display:flex; flex-direction:column; align-items:center;">
        <div style="background:#64748B; color:#fff; font-size:11px; font-weight:800; padding:4px 8px; border-radius:12px; box-shadow:0 2px 6px rgba(0,0,0,0.2); white-space:nowrap;">
          <span>MTS (Belum)</span>
        </div>
        <div style="width:0; height:0; border-left:5px solid transparent; border-right:5px solid transparent; border-top:6px solid #64748B;"></div>
      </div>

      <!-- Floating Map Controls -->
      <div style="position:absolute; right:12px; bottom:16px; display:flex; flex-direction:column; gap:8px;">
        <div style="width:40px; height:40px; border-radius:20px; background:#fff; border:0.5px solid var(--divider); display:flex; align-items:center; justify-content:center; box-shadow:0 2px 6px rgba(0,0,0,0.1);">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="var(--accent)" stroke-width="2"><circle cx="12" cy="12" r="8"/><line x1="12" y1="2" x2="12" y2="6"/><line x1="12" y1="18" x2="12" y2="22"/><line x1="2" y1="12" x2="6" y2="12"/><line x1="18" y1="12" x2="22" y2="12"/></svg>
        </div>
        <div style="width:40px; height:76px; border-radius:20px; background:#fff; border:0.5px solid var(--divider); display:flex; flex-direction:column; align-items:center; justify-content:space-around; box-shadow:0 2px 6px rgba(0,0,0,0.1);">
          <span style="font-size:18px; font-weight:700; color:var(--text-primary); cursor:pointer;">+</span>
          <div style="width:24px; height:0.5px; background:var(--divider);"></div>
          <span style="font-size:18px; font-weight:700; color:var(--text-primary); cursor:pointer;">-</span>
        </div>
      </div>
    </div>

    <!-- Active Selected Pos Preview Inset -->
    <div class="section-title">Pos Terpilih</div>
    <div class="grouped-box">
      <div class="list-row">
        <div class="row-icon" style="background:#FF9500; color:#fff; font-weight:800; font-size:11px;">PBM</div>
        <div class="row-content">
          <div class="row-title">Pos Pasar Bersehati Manado</div>
          <div class="row-subtitle">Fase 1: 23/24 Poin Sesuai (1 Temuan) · Budi Santoso</div>
        </div>
        <div class="row-trailing">
          <button style="padding:6px 12px; font-size:12px; font-weight:700; background:var(--accent); color:#fff; border-radius:6px; border:none; cursor:pointer;">Detail</button>
        </div>
      </div>
    </div>
    """
    with open(os.path.join(c_dir, "map_maintenance.html"), "w", encoding="utf-8") as f:
        f.write(wrap_html("Map Maintenance - Concept A", body_map, "light", "A", common_css))

    # 6. maintenance_checklist.html
    body_chk = """
    <div class="app-header">
      <div style="display:flex; align-items:center; gap:8px;">
        <button style="background:none; border:none; cursor:pointer; min-height:44px; display:flex; align-items:center;">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="var(--text-primary)" stroke-width="2.5"><path d="M15 18l-6-6 6-6"/></svg>
        </button>
        <div>
          <h1>Checklist Barrier Gate Manless</h1>
          <div style="font-size:12px; color:var(--text-secondary);">KC Manado · Pos Pasar Bersehati</div>
        </div>
      </div>
      <button class="header-action">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
      </button>
    </div>

    <!-- Progress Strip -->
    <div style="height:4px; background:var(--divider);">
      <div style="width:75%; height:100%; background:var(--accent);"></div>
    </div>

    <!-- Group 1: Unit & Progress Info -->
    <div class="section-title">Informasi Pengecekan</div>
    <div class="grouped-box">
      <div class="list-row">
        <div class="row-icon" style="background:var(--accent-bg); color:var(--accent);">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M19 3H5a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2V5a2 2 0 00-2-2zm-7 14l-5-5 1.41-1.41L12 14.17l7.59-7.59L21 8l-9 9z"/></svg>
        </div>
        <div class="row-content">
          <div style="font-size:14px; font-weight:700;">Gate 1 Masuk & Manless 1 Dicek</div>
          <div class="row-subtitle">18 dari 24 Foto Poin Selesai (75%)</div>
        </div>
        <div class="row-trailing">
          <span class="pill pill-warning">Proses</span>
        </div>
      </div>
    </div>

    <!-- Group 2: Filter Status & Unit -->
    <div class="section-title">Filter Poin SOP</div>
    <div style="padding:0 16px 10px; display:flex; gap:6px; overflow-x:auto;">
      <button style="padding:6px 12px; border-radius:16px; font-size:12px; font-weight:700; background:var(--accent); color:#fff; border:none; white-space:nowrap;">Semua (24)</button>
      <button style="padding:6px 12px; border-radius:16px; font-size:12px; font-weight:600; background:var(--surface); color:var(--text-secondary); border:0.5px solid var(--divider); white-space:nowrap;">Belum Foto (6)</button>
      <button style="padding:6px 12px; border-radius:16px; font-size:12px; font-weight:600; background:var(--surface); color:var(--text-secondary); border:0.5px solid var(--divider); white-space:nowrap;">Sesuai (17)</button>
      <button style="padding:6px 12px; border-radius:16px; font-size:12px; font-weight:600; background:var(--surface); color:var(--text-secondary); border:0.5px solid var(--divider); white-space:nowrap;">Perlu Cek (1)</button>
    </div>

    <!-- Group 3: Checklist Items List -->
    <div class="section-title">Daftar Poin Checklist SOP</div>
    <div class="grouped-box">
      <!-- Point 1: Sesuai -->
      <div class="list-row">
        <div class="row-icon" style="background:var(--success-bg); color:var(--success);">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>
        </div>
        <div class="row-content">
          <div class="row-title">Kerapian Bodi & Kebersihan Housing Barrier Gate</div>
          <div class="row-subtitle">Kondisi bodi bersih tanpa karat berlebih · Lolos AI</div>
        </div>
        <div class="row-trailing">
          <div style="width:36px; height:36px; border-radius:6px; background:#E2E8F0; display:flex; align-items:center; justify-content:center; font-size:10px; font-weight:700; color:#475569;">FOTO</div>
        </div>
      </div>

      <!-- Point 2: Sesuai -->
      <div class="list-row">
        <div class="row-icon" style="background:var(--success-bg); color:var(--success);">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>
        </div>
        <div class="row-content">
          <div class="row-title">Lampu Indikator LED Palang & Flashing Light</div>
          <div class="row-subtitle">Menyala normal saat palang buka dan tutup · Lolos AI</div>
        </div>
        <div class="row-trailing">
          <div style="width:36px; height:36px; border-radius:6px; background:#E2E8F0; display:flex; align-items:center; justify-content:center; font-size:10px; font-weight:700; color:#475569;">FOTO</div>
        </div>
      </div>

      <!-- Point 3: Perlu Cek / Temuan -->
      <div class="list-row">
        <div class="row-icon" style="background:var(--warning-bg); color:var(--warning);">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a10 10 0 100 20 10 10 0 000-20zm1 14h-2v-2h2v2zm0-4h-2V7h2v5z"/></svg>
        </div>
        <div class="row-content">
          <div class="row-title">Sensor Vehicle Loop Detector & Photocell Keamanan</div>
          <div class="row-subtitle">Sensor gate kotor dan palang penghalang sedikit miring</div>
        </div>
        <div class="row-trailing">
          <button style="padding:6px 10px; font-size:12px; font-weight:700; background:var(--warning-bg); color:var(--warning); border-radius:6px; border:none; cursor:pointer;">Ulang</button>
        </div>
      </div>

      <!-- Point 4: Belum Foto -->
      <div class="list-row">
        <div class="row-icon" style="background:rgba(120,120,128,0.12); color:var(--text-secondary);">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="12" r="9"/></svg>
        </div>
        <div class="row-content">
          <div class="row-title">Tombol Manual Push Button di Meja Kasir</div>
          <div class="row-subtitle">Belum diambil foto dokumentasi</div>
        </div>
        <div class="row-trailing">
          <button style="padding:6px 12px; font-size:12px; font-weight:700; background:var(--accent); color:#fff; border-radius:6px; border:none; cursor:pointer;">Ambil Foto</button>
        </div>
      </div>
    </div>

    <!-- Bottom Bar Button -->
    <div class="bottom-bar">
      <button class="btn-primary" disabled style="opacity:0.7;">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M19 21H5a2 2 0 01-2-2V5a2 2 0 012-2h11l5 5v11a2 2 0 01-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg>
        <span>Lengkapi 18/24 Foto Dulu</span>
      </button>
    </div>
    """
    with open(os.path.join(c_dir, "maintenance_checklist.html"), "w", encoding="utf-8") as f:
        f.write(wrap_html("Maintenance Checklist - Concept A", body_chk, "light", "A", common_css))

    # 7. attendance_archive.html
    body_arc = """
    <div class="app-header">
      <div style="display:flex; align-items:center; gap:8px;">
        <button style="background:none; border:none; cursor:pointer; min-height:44px; display:flex; align-items:center;">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="var(--text-primary)" stroke-width="2.5"><path d="M15 18l-6-6 6-6"/></svg>
        </button>
        <div>
          <h1>Riwayat Kerja</h1>
          <div style="font-size:12px; color:var(--text-secondary);">Catatan Absensi 30 Hari Terakhir</div>
        </div>
      </div>
      <div style="display:flex; align-items:center; gap:4px;">
        <button class="header-action" title="Export CSV">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 12v8a2 2 0 002 2h12a2 2 0 002-2v-8M16 6l-4-4-4 4M12 2v13"/></svg>
        </button>
      </div>
    </div>

    <!-- Group 1: Profile & Pos Info -->
    <div class="section-title">Profil Teknisi</div>
    <div class="grouped-box">
      <div class="list-row">
        <div class="row-icon" style="background:var(--accent-bg); color:var(--accent);">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/></svg>
        </div>
        <div class="row-content">
          <div style="font-size:15px; font-weight:700;">Budi Santoso</div>
          <div class="row-subtitle">IT Support KC BSG · Pos Pasar Bersehati (PBM)</div>
        </div>
        <div class="row-trailing">
          <span class="pill pill-accent">Aktif</span>
        </div>
      </div>
      <div class="list-row" style="background:rgba(0,122,255,0.04);">
        <div class="row-icon" style="color:var(--accent);">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01" stroke="#fff" stroke-width="2"/></svg>
        </div>
        <div class="row-content">
          <div style="font-size:12px; color:var(--text-secondary); line-height:1.35;">Catatan absensi dan foto verifikasi tersimpan otomatis selama 30 hari kalender.</div>
        </div>
      </div>
    </div>

    <!-- Group 2: Rekap KPI 30 Hari -->
    <div class="section-title">Statistik Kehadiran 30 Hari</div>
    <div class="grouped-box">
      <div style="display:grid; grid-template-columns:repeat(3, 1fr); text-align:center; padding:12px 0;">
        <div>
          <div style="font-size:20px; font-weight:800; color:var(--success);">24</div>
          <div style="font-size:12px; font-weight:600; color:var(--text-secondary); margin-top:2px;">Hadir</div>
        </div>
        <div style="border-left:0.5px solid var(--divider); border-right:0.5px solid var(--divider);">
          <div style="font-size:20px; font-weight:800; color:var(--accent);">24</div>
          <div style="font-size:12px; font-weight:600; color:var(--text-secondary); margin-top:2px;">Pulang</div>
        </div>
        <div>
          <div style="font-size:20px; font-weight:800; color:var(--warning);">1</div>
          <div style="font-size:12px; font-weight:600; color:var(--text-secondary); margin-top:2px;">Terlambat</div>
        </div>
      </div>
    </div>

    <!-- Group 3: Log Riwayat Absensi -->
    <div class="section-title">Riwayat Log Kehadiran</div>
    <div class="grouped-box">
      <!-- Entry 1 -->
      <div class="list-row">
        <div class="row-icon" style="background:var(--success-bg); color:var(--success);">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M11 7L9.6 8.4l2.6 2.6H2v2h10.2l-2.6 2.6L11 17l5-5-5-5zm9 12h-8v2h8c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2h-8v2h8v14z"/></svg>
        </div>
        <div class="row-content">
          <div class="row-title">Masuk Dinas · 08 Nov 2026</div>
          <div class="row-subtitle">08:05 WITA · Tepat Waktu · Kode #VER-9102</div>
        </div>
        <div class="row-trailing">
          <div style="width:36px; height:36px; border-radius:6px; background:#E2E8F0; display:flex; align-items:center; justify-content:center; font-size:10px; font-weight:700; color:#475569;">FOTO</div>
        </div>
      </div>

      <!-- Entry 2 -->
      <div class="list-row">
        <div class="row-icon" style="background:var(--accent-bg); color:var(--accent);">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M13 3h-2v10h2V3zm4.83 2.17l-1.42 1.42C17.99 7.86 19 9.81 19 12c0 3.87-3.13 7-7 7s-7-3.13-7-7c0-2.19 1.01-4.14 2.58-5.42L6.17 5.17C4.23 6.82 3 9.26 3 12c0 4.97 4.03 9 9 9s9-4.03 9-9c0-2.74-1.23-5.18-3.17-6.83z"/></svg>
        </div>
        <div class="row-content">
          <div class="row-title">Pulang Dinas · 07 Nov 2026</div>
          <div class="row-subtitle">16:45 WITA · Durasi 8j 40m · 3 Tugas Selesai</div>
        </div>
        <div class="row-trailing">
          <div style="width:36px; height:36px; border-radius:6px; background:#E2E8F0; display:flex; align-items:center; justify-content:center; font-size:10px; font-weight:700; color:#475569;">FOTO</div>
        </div>
      </div>

      <!-- Entry 3 (Terlambat case) -->
      <div class="list-row">
        <div class="row-icon" style="background:var(--warning-bg); color:var(--warning);">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10 10-4.5 10-10S17.5 2 12 2zm4.2 14.2L11 13V7h1.5v5.2l4.5 2.7-.8 1.3z"/></svg>
        </div>
        <div class="row-content">
          <div class="row-title">Masuk Dinas · 07 Nov 2026</div>
          <div class="row-subtitle">08:25 WITA · Terlambat 25 Menit · Kode #VER-8911</div>
        </div>
        <div class="row-trailing">
          <div style="width:36px; height:36px; border-radius:6px; background:#E2E8F0; display:flex; align-items:center; justify-content:center; font-size:10px; font-weight:700; color:#475569;">FOTO</div>
        </div>
      </div>
    </div>

    <!-- Bottom Bar Button -->
    <div class="bottom-bar">
      <button class="btn-primary">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>
        <span>Export ke Spreadsheet (CSV)</span>
      </button>
    </div>
    """
    with open(os.path.join(c_dir, "attendance_archive.html"), "w", encoding="utf-8") as f:
        f.write(wrap_html("Attendance Archive - Concept A", body_arc, "light", "A", common_css))

def generate_concept_b():
    c_dir = os.path.join(BASE_DIR, "B")
    os.makedirs(c_dir, exist_ok=True)

    common_css = """
    :root {
      --bg: #F1F5F9;
      --panel: #FFFFFF;
      --band: #E2E8F0;
      --text-primary: #0F172A;
      --text-secondary: #475569;
      --accent: #0F766E;
      --accent-bg: rgba(15, 118, 110, 0.1);
      --divider: #CBD5E1;
      --rail-success: #059669;
      --rail-warning: #D97706;
      --rail-danger: #DC2626;
      --rail-neutral: #64748B;
    }
    body.theme-dark {
      --bg: #0B1120;
      --panel: #131C2E;
      --band: #0F172A;
      --text-primary: #F8FAFC;
      --text-secondary: #94A3B8;
      --accent: #14B8A6;
      --accent-bg: rgba(20, 184, 166, 0.15);
      --divider: #1E293B;
      --rail-success: #10B981;
      --rail-warning: #F59E0B;
      --rail-danger: #EF4444;
      --rail-neutral: #475569;
    }
    .ops-header {
      background: var(--panel);
      border-bottom: 2px solid var(--accent);
      padding: 14px 16px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      position: sticky;
      top: 0;
      z-index: 10;
    }
    .ops-header h1 {
      font-size: 16px;
      font-weight: 800;
      letter-spacing: -0.2px;
      text-transform: uppercase;
    }
    .band-separator {
      height: 8px;
      background: var(--band);
      width: 100%;
    }
    .ops-section {
      background: var(--panel);
      padding: 12px 16px;
    }
    .section-label {
      font-size: 12px;
      font-weight: 800;
      color: var(--text-secondary);
      text-transform: uppercase;
      letter-spacing: 0.8px;
      margin-bottom: 8px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .ops-row {
      display: flex;
      align-items: flex-start;
      padding: 10px 14px;
      border-left: 4px solid var(--rail-neutral);
      background: var(--panel);
      margin-bottom: 6px;
      border-top: 1px solid var(--divider);
      border-right: 1px solid var(--divider);
      border-bottom: 1px solid var(--divider);
    }
    .ops-row.rail-success { border-left-color: var(--rail-success); }
    .ops-row.rail-warning { border-left-color: var(--rail-warning); }
    .ops-row.rail-danger { border-left-color: var(--rail-danger); }

    .ops-row-title {
      font-size: 13.5px;
      font-weight: 700;
      line-height: 1.3;
    }
    .ops-row-meta {
      font-size: 12px;
      color: var(--text-secondary);
      margin-top: 3px;
      line-height: 1.3;
    }
    .badge-square {
      font-size: 11px;
      font-weight: 800;
      padding: 2px 6px;
      border-radius: 3px;
      text-transform: uppercase;
      letter-spacing: 0.4px;
    }
    .btn-tactical {
      height: 44px;
      background: var(--accent);
      color: #FFFFFF;
      font-size: 13px;
      font-weight: 800;
      letter-spacing: 0.3px;
      border-radius: 4px;
      border: none;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      cursor: pointer;
      width: 100%;
      text-transform: uppercase;
    }
    .btn-tactical-outline {
      height: 44px;
      background: transparent;
      color: var(--accent);
      border: 1.5px solid var(--accent);
      font-size: 13px;
      font-weight: 800;
      letter-spacing: 0.3px;
      border-radius: 4px;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      cursor: pointer;
      width: 100%;
      text-transform: uppercase;
    }
    .sticky-action-bar {
      position: sticky;
      bottom: 0;
      left: 0;
      right: 0;
      padding: 10px 16px 18px;
      background: var(--panel);
      border-top: 1px solid var(--divider);
      box-shadow: 0 -2px 6px rgba(0,0,0,0.06);
      z-index: 20;
    }
    """

    # 1. camera_home.html
    body_cam = """
    <div style="background:#000000; width:100%; height:844px; display:flex; flex-direction:column; position:relative; color:#fff;">
      <!-- Ops Top HUD -->
      <div style="height:56px; display:flex; align-items:center; justify-content:space-between; padding:0 16px; background:#0F172A; border-bottom:2px solid #0F766E;">
        <div style="display:flex; align-items:center; gap:8px;">
          <button style="width:36px; height:36px; background:#1E293B; border:1px solid #334155; border-radius:4px; display:flex; align-items:center; justify-content:center; cursor:pointer;">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2"><path d="M4 6h16M4 12h16M4 18h16"/></svg>
          </button>
          <span style="font-size:12px; font-weight:800; background:#DC2626; padding:2px 6px; border-radius:2px;">2 PENDING</span>
        </div>
        <div style="display:flex; align-items:center; gap:8px; font-size:12px; font-weight:800;">
          <span style="padding:4px 8px; background:#1E293B; border:1px solid #334155; border-radius:4px;">RATIO 3:4</span>
          <span style="padding:4px 8px; background:#1E293B; border:1px solid #334155; border-radius:4px;">FLASH AUTO</span>
        </div>
      </div>

      <!-- Viewfinder with Crosshair Guide -->
      <div style="flex:1; position:relative; background:#0F172A; display:flex; flex-direction:column; justify-content:space-between; padding:16px;">
        <!-- Watermark Tactical Box -->
        <div style="background:rgba(0,0,0,0.85); border-left:4px solid #0F766E; padding:8px 12px; font-size:11.5px; border-top:1px solid #334155; border-right:1px solid #334155; border-bottom:1px solid #334155; max-width:90%;">
          <div style="display:flex; align-items:center; gap:6px; margin-bottom:2px;">
            <span style="background:#0F766E; color:#fff; font-size:10px; font-weight:800; padding:1px 5px; border-radius:2px;">PBM</span>
            <span style="font-weight:800;">POS PASAR BERSEHATI MANADO</span>
          </div>
          <div style="color:#94A3B8; font-size:10.5px;">Jl. Nusantara No. 123 Calaca Wenang Kota Manado</div>
          <div style="color:#38BDF8; font-size:10.5px; margin-top:2px;">GPS: 1.4921 N, 124.8412 E · 08-NOV-2026 09:30:15 WITA</div>
          <div style="color:#4ADE80; font-size:10px; font-weight:800; margin-top:2px;">SOP BARRIER GATE MANLESS · AUTH #BSS-8941</div>
        </div>

        <!-- Tactical Crosshair Center -->
        <div style="position:absolute; left:50%; top:50%; transform:translate(-50%, -50%); width:60px; height:60px; border:1px dashed rgba(255,255,255,0.4); pointer-events:none;"></div>

        <!-- Location Pin Tactical Button -->
        <div style="align-self:flex-end; width:40px; height:40px; background:#1E293B; border:1px solid #0F766E; border-radius:4px; display:flex; align-items:center; justify-content:center;">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#0F766E" stroke-width="2"><circle cx="12" cy="12" r="8"/><path d="M12 2v4M12 18v4M2 12h4M18 12h4"/></svg>
        </div>
      </div>

      <!-- Bottom Ops Console -->
      <div style="background:#0F172A; border-top:1px solid #334155; padding:12px 16px 20px;">
        <!-- Status Bar -->
        <div style="background:#1E293B; border-left:4px solid #10B981; padding:6px 12px; display:flex; justify-content:space-between; align-items:center; font-size:12px; margin-bottom:12px;">
          <span style="font-weight:800; color:#4ADE80;">SHIFT PAGI (08:00 - 16:00)</span>
          <span style="color:#94A3B8;">DURASI 1j 30m</span>
        </div>

        <div style="display:flex; align-items:center; justify-content:space-between;">
          <button style="width:54px; height:54px; background:#1E293B; border:1px solid #334155; border-radius:4px; color:#fff; font-size:11px; font-weight:800; display:flex; flex-direction:column; align-items:center; justify-content:center; gap:3px;">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><path d="M21 15l-5-5L5 21"/></svg>
            <span>GALERI</span>
          </button>

          <button style="width:72px; height:54px; background:#0F766E; border:2px solid #14B8A6; border-radius:4px; color:#fff; font-size:13px; font-weight:800; display:flex; align-items:center; justify-content:center; cursor:pointer;">
            <svg width="28" height="28" viewBox="0 0 24 24" fill="#fff"><path d="M12 15a3 3 0 100-6 3 3 0 000 6z"/><path d="M9 2L7.17 4H4a2 2 0 00-2 2v12a2 2 0 002 2h16a2 2 0 002-2V6a2 2 0 00-2-2h-3.17L15 2H9zm3 15a5 5 0 110-10 5 5 0 010 10z"/></svg>
          </button>

          <button style="width:54px; height:54px; background:#1E293B; border:1px solid #334155; border-radius:4px; color:#fff; font-size:11px; font-weight:800; display:flex; flex-direction:column; align-items:center; justify-content:center; gap:3px;">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2"><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/></svg>
            <span>SOP</span>
          </button>
        </div>
      </div>
    </div>
    """
    with open(os.path.join(c_dir, "camera_home.html"), "w", encoding="utf-8") as f:
        f.write(wrap_html("Camera Home - Concept B", body_cam, "dark", "B", common_css))

    # 2. teknisi_tasks.html
    body_tasks = """
    <div class="ops-header">
      <div>
        <h1>Daily Task Teknisi</h1>
        <div style="font-size:12px; color:var(--text-secondary); margin-top:2px;">Budi Santoso · IT Support KC BSG</div>
      </div>
      <button style="padding:4px 8px; background:var(--band); border:1px solid var(--divider); border-radius:3px; font-size:11px; font-weight:800; color:var(--text-primary); cursor:pointer;">REFRESH</button>
    </div>

    <!-- Ops Metric Board -->
    <div class="ops-section" style="padding-top:14px; padding-bottom:14px;">
      <div class="section-label">
        <span>STATUS PENGERJAAN HARIAN</span>
        <span style="color:var(--accent);">2 / 4 SELESAI</span>
      </div>
      <div style="display:grid; grid-template-columns:repeat(3, 1fr); gap:8px; margin-top:8px;">
        <div style="border:1px solid var(--divider); padding:8px; border-radius:4px; text-align:center;">
          <div style="font-size:18px; font-weight:800; color:var(--text-primary);">4</div>
          <div style="font-size:11px; font-weight:700; color:var(--text-secondary);">TOTAL</div>
        </div>
        <div style="border:1px solid var(--divider); padding:8px; border-radius:4px; text-align:center;">
          <div style="font-size:18px; font-weight:800; color:var(--rail-success);">2</div>
          <div style="font-size:11px; font-weight:700; color:var(--rail-success);">SELESAI</div>
        </div>
        <div style="border:1px solid var(--divider); padding:8px; border-radius:4px; text-align:center;">
          <div style="font-size:18px; font-weight:800; color:var(--rail-warning);">2</div>
          <div style="font-size:11px; font-weight:700; color:var(--rail-warning);">PENDING</div>
        </div>
      </div>
    </div>

    <div class="band-separator"></div>

    <!-- Ops Task Rows: Full-bleed bands with Left Rails -->
    <div class="ops-section">
      <div class="section-label">
        <span>TUGAS HARI INI (4 TUGAS)</span>
      </div>

      <!-- Row 1: Selesai -->
      <div class="ops-row rail-success">
        <div style="flex:1;">
          <div style="display:flex; justify-content:space-between;">
            <span class="ops-row-title" style="text-decoration:line-through; color:var(--text-secondary);">Cek Barrier Gate Masuk 1 & Sensor Loop</span>
            <span class="badge-square" style="background:rgba(5,150,105,0.15); color:var(--rail-success);">SELESAI</span>
          </div>
          <div class="ops-row-meta">Pos Pasar Bersehati · Selesai 09:30 WITA · Bukti Tersimpan</div>
        </div>
      </div>

      <!-- Row 2: Selesai -->
      <div class="ops-row rail-success">
        <div style="flex:1;">
          <div style="display:flex; justify-content:space-between;">
            <span class="ops-row-title" style="text-decoration:line-through; color:var(--text-secondary);">Ganti Kertas Thermal Printer Tiket Manless</span>
            <span class="badge-square" style="background:rgba(5,150,105,0.15); color:var(--rail-success);">SELESAI</span>
          </div>
          <div class="ops-row-meta">Gate 2 PBM · Selesai 10:15 WITA · Laporan OK</div>
        </div>
      </div>

      <!-- Row 3: Pending / Critical (Long text case) -->
      <div class="ops-row rail-warning">
        <div style="flex:1;">
          <div style="display:flex; justify-content:space-between;">
            <span class="ops-row-title">Pembersihan Sensor Gate Kotor dan Kalibrasi Palang Penghalang Sedikit Miring</span>
            <span class="badge-square" style="background:rgba(217,119,6,0.15); color:var(--rail-warning);">PROSES</span>
          </div>
          <div class="ops-row-meta">Gate 1 PBM · Bersama Agus Setiawan · Prioritas Tinggi</div>
          <div style="font-size:11.5px; color:var(--text-secondary); margin-top:4px;">Instruksi: Bersihkan sensor optik dan kencangkan baut angkur dudukan.</div>
          <div style="margin-top:8px; display:flex; gap:8px;">
            <button style="padding:6px 12px; background:var(--accent); color:#fff; border:none; border-radius:3px; font-size:11px; font-weight:800; cursor:pointer;">LANJUTKAN</button>
            <button style="padding:6px 12px; background:transparent; border:1px solid var(--divider); color:var(--text-secondary); border-radius:3px; font-size:11px; font-weight:700; cursor:pointer;">OPER KE LAIN</button>
          </div>
        </div>
      </div>

      <!-- Row 4: Pending -->
      <div class="ops-row rail-neutral">
        <div style="flex:1;">
          <div style="display:flex; justify-content:space-between;">
            <span class="ops-row-title">Pemeriksaan PC Server & Switch Hub Utama</span>
            <span class="badge-square" style="background:rgba(100,116,139,0.15); color:var(--rail-neutral);">BELUM</span>
          </div>
          <div class="ops-row-meta">Server Utama PBM · Maintenance Berkala</div>
          <div style="margin-top:8px;">
            <button style="padding:6px 14px; background:var(--accent); color:#fff; border:none; border-radius:3px; font-size:11px; font-weight:800; cursor:pointer;">KERJAKAN</button>
          </div>
        </div>
      </div>
    </div>

    <div class="band-separator"></div>

    <!-- Shift Sebelumnya -->
    <div class="ops-section">
      <div class="section-label">
        <span>TUGAS OPERAN SHIFT SEBELUMNYA</span>
      </div>
      <div class="ops-row rail-danger">
        <div style="flex:1;">
          <div style="display:flex; justify-content:space-between;">
            <span class="ops-row-title">Perbaikan Kabel LAN Kasir 2 Putus Terinjak</span>
            <span class="badge-square" style="background:rgba(220,38,38,0.15); color:var(--rail-danger);">OPERAN</span>
          </div>
          <div class="ops-row-meta">Lanjutan dari Farhan Lakoro · Ditinggal Kemarin 17:00 WITA</div>
          <div style="margin-top:8px;">
            <button style="padding:6px 12px; background:var(--accent); color:#fff; border:none; border-radius:3px; font-size:11px; font-weight:800; cursor:pointer;">AMBIL ALIH</button>
          </div>
        </div>
      </div>
    </div>

    <!-- Sticky Bottom Bar -->
    <div class="sticky-action-bar">
      <button class="btn-tactical">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M12 5v14M5 12h14"/></svg>
        <span>CATAT KERJAAN LAPANGAN</span>
      </button>
    </div>
    """
    with open(os.path.join(c_dir, "teknisi_tasks.html"), "w", encoding="utf-8") as f:
        f.write(wrap_html("Teknisi Daily Tasks - Concept B", body_tasks, "light", "B", common_css))

    # 3. spv_dispatch.html
    body_spv = """
    <div class="ops-header">
      <div style="display:flex; align-items:center; gap:8px;">
        <button style="background:none; border:none; cursor:pointer; min-height:44px; display:flex; align-items:center;">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="var(--text-primary)" stroke-width="2.5"><path d="M15 18l-6-6 6-6"/></svg>
        </button>
        <div>
          <h1>KONTROL DISPATCH SPV</h1>
          <div style="font-size:12px; color:var(--text-secondary);">KC Manado · 08 Nov 2026</div>
        </div>
      </div>
      <div style="display:flex; gap:6px;">
        <button style="padding:6px 10px; background:var(--band); border:1px solid var(--divider); border-radius:3px; font-size:11px; font-weight:800; cursor:pointer;">BRIEFING WA</button>
      </div>
    </div>

    <!-- Ops Metric Bar -->
    <div class="ops-section" style="padding-top:12px; padding-bottom:12px;">
      <div style="display:grid; grid-template-columns:repeat(4, 1fr); gap:6px; text-align:center;">
        <div style="background:var(--band); padding:8px 4px; border-radius:3px;">
          <div style="font-size:16px; font-weight:800;">6</div>
          <div style="font-size:10.5px; font-weight:700; color:var(--text-secondary);">TOTAL</div>
        </div>
        <div style="background:rgba(5,150,105,0.12); padding:8px 4px; border-radius:3px;">
          <div style="font-size:16px; font-weight:800; color:var(--rail-success);">4</div>
          <div style="font-size:10.5px; font-weight:700; color:var(--rail-success);">SELESAI</div>
        </div>
        <div style="background:rgba(217,119,6,0.12); padding:8px 4px; border-radius:3px;">
          <div style="font-size:16px; font-weight:800; color:var(--rail-warning);">2</div>
          <div style="font-size:10.5px; font-weight:700; color:var(--rail-warning);">PENDING</div>
        </div>
        <div style="background:rgba(15,118,110,0.12); padding:8px 4px; border-radius:3px;">
          <div style="font-size:16px; font-weight:800; color:var(--accent);">67%</div>
          <div style="font-size:10.5px; font-weight:700; color:var(--accent);">RATE</div>
        </div>
      </div>
    </div>

    <div class="band-separator"></div>

    <!-- Technician Selector Strip -->
    <div class="ops-section" style="padding-top:8px; padding-bottom:8px;">
      <div style="display:flex; gap:6px; overflow-x:auto;">
        <button style="padding:6px 10px; background:var(--accent); color:#fff; border:none; border-radius:3px; font-size:11.5px; font-weight:800; white-space:nowrap;">SEMUA PETUGAS (6)</button>
        <button style="padding:6px 10px; background:var(--band); border:1px solid var(--divider); border-radius:3px; font-size:11.5px; font-weight:700; white-space:nowrap;">BUDI SANTOSO (3)</button>
        <button style="padding:6px 10px; background:var(--band); border:1px solid var(--divider); border-radius:3px; font-size:11.5px; font-weight:700; white-space:nowrap;">FARHAN LAKORO (2)</button>
        <button style="padding:6px 10px; background:var(--band); border:1px solid var(--divider); border-radius:3px; font-size:11.5px; font-weight:700; white-space:nowrap;">AGUS SETIAWAN (1)</button>
      </div>
    </div>

    <div class="band-separator"></div>

    <!-- Ops Task Table / Rows -->
    <div class="ops-section">
      <div class="section-label">
        <span>DAFTAR TUGAS LAPANGAN AKTIF</span>
      </div>

      <div class="ops-row rail-warning">
        <div style="flex:1;">
          <div style="display:flex; justify-content:space-between;">
            <span class="ops-row-title">Pembersihan Sensor Gate Kotor & Kalibrasi Palang Miring</span>
            <span class="badge-square" style="background:rgba(217,119,6,0.15); color:var(--rail-warning);">PENDING</span>
          </div>
          <div class="ops-row-meta">Petugas: Budi Santoso · Pos Pasar Bersehati · Prioritas Tinggi</div>
          <div style="margin-top:8px; display:flex; gap:8px;">
            <button style="padding:4px 10px; background:var(--band); border:1px solid var(--divider); font-size:11px; font-weight:800; cursor:pointer;">ALIHKAN</button>
            <button style="padding:4px 10px; background:transparent; border:1px solid #DC2626; color:#DC2626; font-size:11px; font-weight:800; cursor:pointer;">HAPUS</button>
          </div>
        </div>
      </div>

      <div class="ops-row rail-warning">
        <div style="flex:1;">
          <div style="display:flex; justify-content:space-between;">
            <span class="ops-row-title">Penggantian Switch Hub 8-Port Pos Kasir 2</span>
            <span class="badge-square" style="background:rgba(217,119,6,0.15); color:var(--rail-warning);">PENDING</span>
          </div>
          <div class="ops-row-meta">Petugas: Farhan Lakoro · Pos Mega Mall Manado</div>
          <div style="margin-top:8px; display:flex; gap:8px;">
            <button style="padding:4px 10px; background:var(--band); border:1px solid var(--divider); font-size:11px; font-weight:800; cursor:pointer;">ALIHKAN</button>
            <button style="padding:4px 10px; background:transparent; border:1px solid #DC2626; color:#DC2626; font-size:11px; font-weight:800; cursor:pointer;">HAPUS</button>
          </div>
        </div>
      </div>

      <div class="ops-row rail-success">
        <div style="flex:1;">
          <div style="display:flex; justify-content:space-between;">
            <span class="ops-row-title" style="text-decoration:line-through; color:var(--text-secondary);">Cek Barrier Gate Masuk 1 & Sensor Loop</span>
            <span class="badge-square" style="background:rgba(5,150,105,0.15); color:var(--rail-success);">SELESAI</span>
          </div>
          <div class="ops-row-meta">Budi Santoso · Selesai 09:30 WITA · Lolos Verifikasi</div>
        </div>
      </div>

      <div class="ops-row rail-success">
        <div style="flex:1;">
          <div style="display:flex; justify-content:space-between;">
            <span class="ops-row-title" style="text-decoration:line-through; color:var(--text-secondary);">Ganti Kertas Thermal Printer Gate 2</span>
            <span class="badge-square" style="background:rgba(5,150,105,0.15); color:var(--rail-success);">SELESAI</span>
          </div>
          <div class="ops-row-meta">Budi Santoso · Selesai 10:15 WITA</div>
        </div>
      </div>
    </div>

    <!-- Sticky Bottom Bar -->
    <div class="sticky-action-bar">
      <button class="btn-tactical">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M12 5v14M5 12h14"/></svg>
        <span>DISPATCH TUGAS BARU</span>
      </button>
    </div>
    """
    with open(os.path.join(c_dir, "spv_dispatch.html"), "w", encoding="utf-8") as f:
        f.write(wrap_html("SPV Task Dispatcher - Concept B", body_spv, "light", "B", common_css))

    # 4. location_detail.html & location_detail_dark.html
    def build_location_detail_ops(is_dark=False):
        return f"""
        <div class="ops-header">
          <div style="display:flex; align-items:center; gap:8px;">
            <button style="background:none; border:none; cursor:pointer; min-height:44px; display:flex; align-items:center;">
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="var(--text-primary)" stroke-width="2.5"><path d="M15 18l-6-6 6-6"/></svg>
            </button>
            <div>
              <h1>DETAIL LOKASI POS</h1>
              <div style="font-size:12px; color:var(--text-secondary);">PERIODE NOVEMBER 2026</div>
            </div>
          </div>
          <span class="badge-square" style="background:#0F766E; color:#fff;">PBM</span>
        </div>

        <!-- Section 1: Location Facts Table -->
        <div class="ops-section">
          <div style="font-size:16px; font-weight:800; line-height:1.2;">POS PASAR BERSEHATI MANADO</div>
          <div style="font-size:12px; color:var(--text-secondary); margin-top:4px;">Jl. Nusantara No. 123 Calaca Wenang Kota Manado</div>
          <div style="display:grid; grid-template-columns:1fr 1fr; gap:8px; margin-top:10px; border-top:1px solid var(--divider); padding-top:10px;">
            <div>
              <div style="font-size:11px; font-weight:700; color:var(--text-secondary);">TEKNISI PIC</div>
              <div style="font-size:13px; font-weight:700;">Budi Santoso</div>
            </div>
            <div>
              <div style="font-size:11px; font-weight:700; color:var(--text-secondary);">INSPEKSI TERAKHIR</div>
              <div style="font-size:13px; font-weight:700;">03-Nov-2026 09:30</div>
            </div>
          </div>
          <div style="margin-top:12px;">
            <button class="btn-tactical-outline">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="3 11 22 2 13 21 11 13 3 11"/></svg>
              <span>BUKA PANDUAN GOOGLE MAPS</span>
            </button>
          </div>
        </div>

        <div class="band-separator"></div>

        <!-- Section 2: Progres 4 Fase Table -->
        <div class="ops-section">
          <div class="section-label">
            <span>PROGRES 4 FASE BULANAN</span>
            <span style="color:var(--accent);">1 / 4 FASE LENGKAP</span>
          </div>

          <div style="display:grid; grid-template-columns:repeat(4, 1fr); gap:4px; text-align:center;">
            <div style="border-top:3px solid var(--rail-warning); background:var(--band); padding:8px 2px;">
              <div style="font-size:11px; font-weight:800;">FASE 1</div>
              <div style="font-size:16px; font-weight:800; margin:2px 0;">23/24</div>
              <span class="badge-square" style="background:rgba(217,119,6,0.15); color:var(--rail-warning);">TEMUAN</span>
            </div>
            <div style="border-top:3px solid var(--rail-neutral); background:var(--band); padding:8px 2px;">
              <div style="font-size:11px; font-weight:800; color:var(--text-secondary);">FASE 2</div>
              <div style="font-size:13px; font-weight:700; color:var(--text-secondary); margin:2px 0;">8-14</div>
              <span class="badge-square" style="background:rgba(100,116,139,0.15); color:var(--rail-neutral);">BELUM</span>
            </div>
            <div style="border-top:3px solid var(--rail-neutral); background:var(--band); padding:8px 2px;">
              <div style="font-size:11px; font-weight:800; color:var(--text-secondary);">FASE 3</div>
              <div style="font-size:13px; font-weight:700; color:var(--text-secondary); margin:2px 0;">15-21</div>
              <span class="badge-square" style="background:rgba(100,116,139,0.15); color:var(--rail-neutral);">BELUM</span>
            </div>
            <div style="border-top:3px solid var(--rail-neutral); background:var(--band); padding:8px 2px;">
              <div style="font-size:11px; font-weight:800; color:var(--text-secondary);">FASE 4</div>
              <div style="font-size:13px; font-weight:700; color:var(--text-secondary); margin:2px 0;">22-31</div>
              <span class="badge-square" style="background:rgba(100,116,139,0.15); color:var(--rail-neutral);">BELUM</span>
            </div>
          </div>
        </div>

        <div class="band-separator"></div>

        <!-- Section 3: Temuan List Section -->
        <div class="ops-section">
          <div class="section-label">
            <span>DAFTAR TEMUAN (1 BUTUH TINDAKAN)</span>
          </div>

          <div class="ops-row rail-warning" style="flex-direction:column; gap:6px;">
            <div style="display:flex; justify-content:space-between; width:100%;">
              <span class="badge-square" style="background:rgba(220,38,38,0.15); color:var(--rail-danger);">URGENT</span>
              <span class="badge-square" style="background:rgba(217,119,6,0.15); color:var(--rail-warning);">BELUM DIPERBAIKI</span>
            </div>
            <div class="ops-row-title">Sensor gate kotor dan palang penghalang sedikit miring butuh kalibrasi</div>
            <div class="ops-row-meta">Alasan: Perlu dibersihkan segera dengan cairan pembersih khusus elektronik dan baut dudukan angkur dikencangkan.</div>
            <div style="margin-top:10px; width:100%;">
              <button class="btn-tactical">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M23 19a2 2 0 01-2 2H3a2 2 0 01-2-2V8a2 2 0 012-2h4l2-3h6l2 3h4a2 2 0 012 2z"/><circle cx="12" cy="13" r="4"/></svg>
                <span>TANDAI SUDAH DIPERBAIKI (FOTO)</span>
              </button>
            </div>
          </div>
        </div>
        """
    with open(os.path.join(c_dir, "location_detail.html"), "w", encoding="utf-8") as f:
        f.write(wrap_html("Location Detail - Concept B", build_location_detail_ops(False), "light", "B", common_css))
    with open(os.path.join(c_dir, "location_detail_dark.html"), "w", encoding="utf-8") as f:
        f.write(wrap_html("Location Detail Dark - Concept B", build_location_detail_ops(True), "dark", "B", common_css))

    # 5. map_maintenance.html
    body_map = """
    <div class="ops-header">
      <div style="display:flex; align-items:center; gap:8px;">
        <button style="background:none; border:none; cursor:pointer; min-height:44px; display:flex; align-items:center;">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="var(--text-primary)" stroke-width="2.5"><path d="M15 18l-6-6 6-6"/></svg>
        </button>
        <div>
          <h1>MONITORING SEBARAN MAP</h1>
          <div style="font-size:12px; color:var(--text-secondary);">12 POS TERDAFTAR DI MANADO</div>
        </div>
      </div>
      <button style="padding:4px 8px; background:var(--band); border:1px solid var(--divider); border-radius:3px; font-size:11px; font-weight:800; cursor:pointer;">UPDATE</button>
    </div>

    <!-- Ops Filter Header Band -->
    <div class="ops-section" style="padding-top:8px; padding-bottom:8px; display:flex; gap:8px; align-items:center; justify-content:space-between;">
      <div style="font-size:12px; font-weight:800;">PERIODE: NOV 2026</div>
      <div style="font-size:12px; font-weight:800; color:var(--accent);">WILAYAH: MANADO</div>
      <div style="font-size:11px; font-weight:800; background:var(--band); padding:4px 8px; border-radius:3px;">FASE 1</div>
    </div>

    <div class="band-separator"></div>

    <!-- Map Canvas (Edge-to-edge) -->
    <div style="position:relative; width:100%; height:480px; background:#CBD5E1; overflow:hidden;">
      <svg width="100%" height="100%">
        <rect width="100%" height="100%" fill="#E2E8F0"/>
        <line x1="0" y1="200" x2="390" y2="200" stroke="#94A3B8" stroke-width="8"/>
        <line x1="180" y1="0" x2="180" y2="480" stroke="#94A3B8" stroke-width="8"/>
      </svg>

      <!-- Pin 1 -->
      <div style="position:absolute; left:180px; top:200px; transform:translate(-50%, -100%);">
        <div style="background:#D97706; color:#fff; font-size:11px; font-weight:800; padding:4px 8px; border:1px solid #fff; border-radius:3px; display:flex; align-items:center; gap:4px;">
          <span>PBM: 1 TEMUAN</span>
        </div>
      </div>

      <!-- Pin 2 -->
      <div style="position:absolute; left:280px; top:120px; transform:translate(-50%, -100%);">
        <div style="background:#059669; color:#fff; font-size:11px; font-weight:800; padding:4px 8px; border:1px solid #fff; border-radius:3px;">
          <span>MMM: AMAN</span>
        </div>
      </div>

      <!-- Controls -->
      <div style="position:absolute; right:12px; bottom:16px; display:flex; flex-direction:column; gap:6px;">
        <button style="width:36px; height:36px; background:#0F172A; color:#fff; border:1px solid #334155; border-radius:4px; font-size:16px; font-weight:800;">+</button>
        <button style="width:36px; height:36px; background:#0F172A; color:#fff; border:1px solid #334155; border-radius:4px; font-size:16px; font-weight:800;">-</button>
      </div>
    </div>

    <div class="band-separator"></div>

    <!-- Detail Strip -->
    <div class="ops-section">
      <div style="display:flex; justify-content:space-between; align-items:center;">
        <div>
          <div style="font-size:13.5px; font-weight:800;">POS PASAR BERSEHATI MANADO</div>
          <div style="font-size:11.5px; color:var(--text-secondary);">Fase 1: 23/24 Poin Sesuai · 1 Temuan</div>
        </div>
        <button style="padding:8px 14px; background:var(--accent); color:#fff; border:none; border-radius:3px; font-size:11.5px; font-weight:800; cursor:pointer;">BUKA</button>
      </div>
    </div>
    """
    with open(os.path.join(c_dir, "map_maintenance.html"), "w", encoding="utf-8") as f:
        f.write(wrap_html("Map Maintenance - Concept B", body_map, "light", "B", common_css))

    # 6. maintenance_checklist.html
    body_chk = """
    <div class="ops-header">
      <div style="display:flex; align-items:center; gap:8px;">
        <button style="background:none; border:none; cursor:pointer; min-height:44px; display:flex; align-items:center;">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="var(--text-primary)" stroke-width="2.5"><path d="M15 18l-6-6 6-6"/></svg>
        </button>
        <div>
          <h1>CHECKLIST SOP BARRIER GATE</h1>
          <div style="font-size:12px; color:var(--text-secondary);">KC Manado · Pos Pasar Bersehati</div>
        </div>
      </div>
      <span class="badge-square" style="background:rgba(217,119,6,0.15); color:var(--rail-warning);">PROSES</span>
    </div>

    <!-- Ops Progress Matrix -->
    <div class="ops-section" style="padding-top:10px; padding-bottom:10px;">
      <div style="display:flex; justify-content:space-between; font-size:12px; font-weight:800; margin-bottom:4px;">
        <span>PROGRES POIN DOKUMENTASI</span>
        <span>18 / 24 POIN (75%)</span>
      </div>
      <div style="height:6px; background:var(--band); border-radius:2px; overflow:hidden;">
        <div style="width:75%; height:100%; background:var(--accent);"></div>
      </div>
    </div>

    <div class="band-separator"></div>

    <!-- Filter Segment -->
    <div class="ops-section" style="padding-top:6px; padding-bottom:6px; display:flex; gap:6px; overflow-x:auto;">
      <button style="padding:6px 10px; background:var(--accent); color:#fff; border:none; border-radius:3px; font-size:11.5px; font-weight:800; white-space:nowrap;">SEMUA (24)</button>
      <button style="padding:6px 10px; background:var(--band); border:1px solid var(--divider); border-radius:3px; font-size:11.5px; font-weight:700; white-space:nowrap;">BELUM FOTO (6)</button>
      <button style="padding:6px 10px; background:var(--band); border:1px solid var(--divider); border-radius:3px; font-size:11.5px; font-weight:700; white-space:nowrap;">SESUAI (17)</button>
      <button style="padding:6px 10px; background:var(--band); border:1px solid var(--divider); border-radius:3px; font-size:11.5px; font-weight:700; white-space:nowrap;">PERLU CEK (1)</button>
    </div>

    <div class="band-separator"></div>

    <!-- Checklist Rows -->
    <div class="ops-section">
      <div class="section-label"><span>POIN EVALUASI</span></div>

      <div class="ops-row rail-success">
        <div style="flex:1;">
          <div style="display:flex; justify-content:space-between;">
            <span class="ops-row-title">Kerapian Bodi & Kebersihan Housing Barrier Gate</span>
            <span class="badge-square" style="background:rgba(5,150,105,0.15); color:var(--rail-success);">SESUAI</span>
          </div>
          <div class="ops-row-meta">Housing bersih bebas karat · Terverifikasi AI</div>
        </div>
      </div>

      <div class="ops-row rail-success">
        <div style="flex:1;">
          <div style="display:flex; justify-content:space-between;">
            <span class="ops-row-title">Lampu Indikator LED Palang & Flashing Light</span>
            <span class="badge-square" style="background:rgba(5,150,105,0.15); color:var(--rail-success);">SESUAI</span>
          </div>
          <div class="ops-row-meta">Menyala normal saat buka dan tutup · Terverifikasi AI</div>
        </div>
      </div>

      <div class="ops-row rail-warning">
        <div style="flex:1;">
          <div style="display:flex; justify-content:space-between;">
            <span class="ops-row-title">Sensor Vehicle Loop Detector & Photocell Keamanan</span>
            <span class="badge-square" style="background:rgba(217,119,6,0.15); color:var(--rail-warning);">PERLU CEK</span>
          </div>
          <div class="ops-row-meta">Sensor kotor & palang miring · Foto perlu diperbarui</div>
          <div style="margin-top:6px;">
            <button style="padding:4px 10px; background:var(--rail-warning); color:#fff; border:none; border-radius:3px; font-size:11px; font-weight:800; cursor:pointer;">FOTO ULANG</button>
          </div>
        </div>
      </div>

      <div class="ops-row rail-neutral">
        <div style="flex:1;">
          <div style="display:flex; justify-content:space-between;">
            <span class="ops-row-title">Tombol Manual Push Button di Meja Kasir</span>
            <span class="badge-square" style="background:rgba(100,116,139,0.15); color:var(--rail-neutral);">BELUM</span>
          </div>
          <div class="ops-row-meta">Belum ada foto dokumentasi</div>
          <div style="margin-top:6px;">
            <button style="padding:4px 10px; background:var(--accent); color:#fff; border:none; border-radius:3px; font-size:11px; font-weight:800; cursor:pointer;">AMBIL FOTO</button>
          </div>
        </div>
      </div>
    </div>

    <!-- Sticky Bottom Bar -->
    <div class="sticky-action-bar">
      <button class="btn-tactical" disabled style="opacity:0.7;">
        <span>LENGKAPI 18/24 FOTO DOKUMENTASI DULU</span>
      </button>
    </div>
    """
    with open(os.path.join(c_dir, "maintenance_checklist.html"), "w", encoding="utf-8") as f:
        f.write(wrap_html("Maintenance Checklist - Concept B", body_chk, "light", "B", common_css))

    # 7. attendance_archive.html
    body_arc = """
    <div class="ops-header">
      <div style="display:flex; align-items:center; gap:8px;">
        <button style="background:none; border:none; cursor:pointer; min-height:44px; display:flex; align-items:center;">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="var(--text-primary)" stroke-width="2.5"><path d="M15 18l-6-6 6-6"/></svg>
        </button>
        <div>
          <h1>ARSIP LOG KEHADIRAN</h1>
          <div style="font-size:12px; color:var(--text-secondary);">RETENSI OTOMATIS 30 HARI</div>
        </div>
      </div>
      <button style="padding:6px 10px; background:var(--band); border:1px solid var(--divider); border-radius:3px; font-size:11px; font-weight:800; cursor:pointer;">CSV</button>
    </div>

    <!-- Ops Technician Info -->
    <div class="ops-section">
      <div style="display:flex; justify-content:space-between; align-items:center;">
        <div>
          <div style="font-size:15px; font-weight:800;">BUDI SANTOSO</div>
          <div style="font-size:12px; color:var(--text-secondary);">IT Support KC BSG · Pos Pasar Bersehati</div>
        </div>
        <span class="badge-square" style="background:#0F766E; color:#fff;">PBM</span>
      </div>
    </div>

    <div class="band-separator"></div>

    <!-- KPI Grid -->
    <div class="ops-section" style="padding-top:10px; padding-bottom:10px;">
      <div style="display:grid; grid-template-columns:repeat(3, 1fr); gap:6px; text-align:center;">
        <div style="background:var(--band); padding:8px 4px; border-radius:3px;">
          <div style="font-size:18px; font-weight:800; color:var(--rail-success);">24</div>
          <div style="font-size:11px; font-weight:800; color:var(--text-secondary);">HADIR</div>
        </div>
        <div style="background:var(--band); padding:8px 4px; border-radius:3px;">
          <div style="font-size:18px; font-weight:800; color:var(--accent);">24</div>
          <div style="font-size:11px; font-weight:800; color:var(--text-secondary);">PULANG</div>
        </div>
        <div style="background:var(--band); padding:8px 4px; border-radius:3px;">
          <div style="font-size:18px; font-weight:800; color:var(--rail-warning);">1</div>
          <div style="font-size:11px; font-weight:800; color:var(--text-secondary);">TELAT</div>
        </div>
      </div>
    </div>

    <div class="band-separator"></div>

    <!-- Logs Table -->
    <div class="ops-section">
      <div class="section-label"><span>CATATAN TIMEMARK HARIAN</span></div>

      <div class="ops-row rail-success">
        <div style="flex:1;">
          <div style="display:flex; justify-content:space-between;">
            <span class="ops-row-title">MASUK DINAS · 08-NOV-2026</span>
            <span class="badge-square" style="background:rgba(5,150,105,0.15); color:var(--rail-success);">TEPAT WAKTU</span>
          </div>
          <div class="ops-row-meta">08:05 WITA · AUTH #VER-9102 · FOTO OK</div>
        </div>
      </div>

      <div class="ops-row rail-neutral">
        <div style="flex:1;">
          <div style="display:flex; justify-content:space-between;">
            <span class="ops-row-title">PULANG DINAS · 07-NOV-2026</span>
            <span class="badge-square" style="background:rgba(100,116,139,0.15); color:var(--rail-neutral);">8J 40M</span>
          </div>
          <div class="ops-row-meta">16:45 WITA · 3 TUGAS SELESAI · LAPORAN PULANG SYNC</div>
        </div>
      </div>

      <div class="ops-row rail-warning">
        <div style="flex:1;">
          <div style="display:flex; justify-content:space-between;">
            <span class="ops-row-title">MASUK DINAS · 07-NOV-2026</span>
            <span class="badge-square" style="background:rgba(217,119,6,0.15); color:var(--rail-warning);">TELAT 25M</span>
          </div>
          <div class="ops-row-meta">08:25 WITA · AUTH #VER-8911 · FOTO OK</div>
        </div>
      </div>
    </div>

    <!-- Sticky Bottom Bar -->
    <div class="sticky-action-bar">
      <button class="btn-tactical">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/></svg>
        <span>EXPORT DATA KE EXCEL / CSV</span>
      </button>
    </div>
    """
    with open(os.path.join(c_dir, "attendance_archive.html"), "w", encoding="utf-8") as f:
        f.write(wrap_html("Attendance Archive - Concept B", body_arc, "light", "B", common_css))

def generate_concept_c():
    c_dir = os.path.join(BASE_DIR, "C")
    os.makedirs(c_dir, exist_ok=True)

    common_css = """
    :root {
      --bg: #FAF9F6;
      --hero-surface: #FFFFFF;
      --text-primary: #18181B;
      --text-secondary: #71717A;
      --accent: #2563EB;
      --accent-bg: rgba(37, 99, 235, 0.08);
      --line: #E4E4E7;
      --timeline-dot: #2563EB;
      --success: #16A34A;
      --warning: #EA580C;
      --danger: #DC2626;
    }
    body.theme-dark {
      --bg: #090D16;
      --hero-surface: #111827;
      --text-primary: #F4F4F5;
      --text-secondary: #A1A1AA;
      --accent: #3B82F6;
      --accent-bg: rgba(59, 130, 246, 0.15);
      --line: #27272A;
      --timeline-dot: #60A5FA;
      --success: #22C55E;
      --warning: #F97316;
      --danger: #EF4444;
    }
    .editorial-header {
      padding: 24px 20px 12px;
      display: flex;
      justify-content: space-between;
      align-items: flex-end;
    }
    .editorial-header h1 {
      font-size: 26px;
      font-weight: 800;
      letter-spacing: -0.6px;
      line-height: 1.1;
    }
    .editorial-hero {
      margin: 12px 20px 20px;
      padding: 20px;
      background: var(--hero-surface);
      border: 1px solid var(--line);
      border-radius: 8px;
      box-shadow: 0 4px 12px rgba(15, 23, 42, 0.05);
    }
    .big-numeral {
      font-size: 36px;
      font-weight: 800;
      letter-spacing: -1px;
      line-height: 1.0;
      color: var(--text-primary);
    }
    .timeline-container {
      padding: 0 20px 20px;
      position: relative;
    }
    .timeline-item {
      position: relative;
      padding-left: 28px;
      padding-bottom: 24px;
    }
    .timeline-item:not(:last-child)::before {
      content: '';
      position: absolute;
      left: 7px;
      top: 14px;
      bottom: 0;
      width: 2px;
      background: var(--line);
    }
    .timeline-item::after {
      content: '';
      position: absolute;
      left: 3px;
      top: 5px;
      width: 10px;
      height: 10px;
      border-radius: 5px;
      background: var(--timeline-dot);
    }
    .timeline-item.success::after { background: var(--success); }
    .timeline-item.warning::after { background: var(--warning); }
    .timeline-item.neutral::after { background: var(--text-secondary); }

    .editorial-title {
      font-size: 15px;
      font-weight: 700;
      line-height: 1.3;
    }
    .editorial-meta {
      font-size: 12.5px;
      color: var(--text-secondary);
      margin-top: 4px;
      line-height: 1.35;
    }
    .btn-bold {
      height: 48px;
      background: var(--accent);
      color: #FFFFFF;
      font-size: 14px;
      font-weight: 700;
      border-radius: 8px;
      border: none;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      cursor: pointer;
      width: 100%;
    }
    """

    # 1. camera_home.html
    body_cam = """
    <div style="background:#090D16; width:100%; height:844px; display:flex; flex-direction:column; position:relative; color:#fff;">
      <div style="padding:16px 20px; display:flex; justify-content:space-between; align-items:center;">
        <span style="font-size:18px; font-weight:800; letter-spacing:-0.4px;">KAMERA VERIFIKASI</span>
        <span style="font-size:12px; font-weight:700; color:#60A5FA;">2 TUGAS PENDING</span>
      </div>

      <!-- Hero Viewfinder Surface (The ONE elevated hero) -->
      <div style="margin:0 16px; flex:1; background:#111827; border-radius:8px; border:1px solid #27272A; box-shadow:0 4px 16px rgba(0,0,0,0.5); position:relative; display:flex; flex-direction:column; justify-content:space-between; padding:16px;">
        <div style="background:rgba(9,13,22,0.9); padding:10px 14px; border-radius:6px; font-size:12px; line-height:1.4;">
          <div style="font-size:16px; font-weight:800; color:#fff;">Pos Pasar Bersehati Manado</div>
          <div style="color:#A1A1AA; font-size:11.5px;">Jl. Nusantara No. 123 Calaca Wenang Kota Manado</div>
          <div style="color:#38BDF8; font-size:11px; margin-top:4px;">WITA: 08 Nov 2026, 09:30 · GPS: 1.4921 N, 124.8412 E</div>
        </div>

        <div style="display:flex; justify-content:space-between; align-items:center;">
          <span style="font-size:12px; font-weight:700; background:rgba(255,255,255,0.1); padding:4px 8px; border-radius:4px;">RASIO 3:4 · TIMER OFF</span>
          <span style="font-size:12px; font-weight:700; background:rgba(37,99,235,0.3); color:#93C5FD; padding:4px 8px; border-radius:4px;">1x ZOOM</span>
        </div>
      </div>

      <!-- Controls Row (Unenclosed) -->
      <div style="padding:20px; display:flex; flex-direction:column; gap:16px; align-items:center;">
        <div style="font-size:12.5px; font-weight:700; color:#4ADE80; display:flex; align-items:center; gap:6px;">
          <span style="width:8px; height:8px; border-radius:4px; background:#4ADE80;"></span>
          <span>Shift Pagi (08:00 - 16:00) · Sedang Dinas</span>
        </div>

        <div style="width:100%; display:flex; justify-content:space-around; align-items:center;">
          <span style="font-size:13px; font-weight:700; color:#A1A1AA; cursor:pointer;">Galeri Foto</span>
          <div style="width:68px; height:68px; border-radius:34px; background:#2563EB; display:flex; align-items:center; justify-content:center; cursor:pointer;">
            <svg width="28" height="28" viewBox="0 0 24 24" fill="#fff"><path d="M12 15a3 3 0 100-6 3 3 0 000 6z"/><path d="M9 2L7.17 4H4a2 2 0 00-2 2v12a2 2 0 002 2h16a2 2 0 002-2V6a2 2 0 00-2-2h-3.17L15 2H9zm3 15a5 5 0 110-10 5 5 0 010 10z"/></svg>
          </div>
          <span style="font-size:13px; font-weight:700; color:#A1A1AA; cursor:pointer;">Pilih SOP</span>
        </div>
      </div>
    </div>
    """
    with open(os.path.join(c_dir, "camera_home.html"), "w", encoding="utf-8") as f:
        f.write(wrap_html("Camera Home - Concept C", body_cam, "dark", "C", common_css))

    # 2. teknisi_tasks.html
    body_tasks = """
    <div class="editorial-header">
      <div>
        <div style="font-size:12px; font-weight:700; color:var(--text-secondary); text-transform:uppercase; letter-spacing:0.8px;">Tugas Lapangan</div>
        <h1>Daily Task</h1>
      </div>
      <div style="font-size:12px; font-weight:600; color:var(--text-secondary);">Budi Santoso</div>
    </div>

    <!-- ONE Hero Surface -->
    <div class="editorial-hero">
      <div style="display:flex; justify-content:space-between; align-items:flex-end;">
        <div>
          <div class="big-numeral">2 <span style="font-size:22px; color:var(--text-secondary); font-weight:600;">/ 4</span></div>
          <div style="font-size:13px; font-weight:600; color:var(--text-secondary); margin-top:4px;">Tugas telah selesai dikerjakan</div>
        </div>
        <span style="font-size:13px; font-weight:700; color:var(--accent);">50% Selesai</span>
      </div>
    </div>

    <!-- Timeline of Tasks (Boxless) -->
    <div class="timeline-container">
      <div style="font-size:12px; font-weight:700; color:var(--text-secondary); text-transform:uppercase; margin-bottom:16px;">Jadwal Hari Ini</div>

      <!-- Item 1: Selesai -->
      <div class="timeline-item success">
        <div class="editorial-title" style="text-decoration:line-through; color:var(--text-secondary);">Cek Barrier Gate Masuk 1 & Sensor Loop</div>
        <div class="editorial-meta">Pos Pasar Bersehati · Selesai 09:30 WITA · Lolos Verifikasi</div>
      </div>

      <!-- Item 2: Selesai -->
      <div class="timeline-item success">
        <div class="editorial-title" style="text-decoration:line-through; color:var(--text-secondary);">Ganti Kertas Thermal Printer Tiket Manless</div>
        <div class="editorial-meta">Gate 2 PBM · Selesai 10:15 WITA</div>
      </div>

      <!-- Item 3: Ongoing / Warning -->
      <div class="timeline-item warning">
        <div class="editorial-title">Pembersihan Sensor Gate Kotor dan Kalibrasi Palang Penghalang Sedikit Miring</div>
        <div class="editorial-meta">Gate 1 PBM · Bersama Agus Setiawan · Prioritas Tinggi</div>
        <div style="margin-top:8px;">
          <button style="padding:6px 14px; background:var(--accent); color:#fff; font-size:12px; font-weight:700; border-radius:6px; border:none; cursor:pointer;">Kerjakan Sekarang</button>
        </div>
      </div>

      <!-- Item 4: Belum -->
      <div class="timeline-item neutral">
        <div class="editorial-title">Pemeriksaan PC Server & Switch Hub Utama</div>
        <div class="editorial-meta">Server Utama PBM · Maintenance Rutin</div>
      </div>
    </div>

    <div style="padding:0 20px 20px;">
      <button class="btn-bold">
        <span>Catat Kerjaan Baru</span>
      </button>
    </div>
    """
    with open(os.path.join(c_dir, "teknisi_tasks.html"), "w", encoding="utf-8") as f:
        f.write(wrap_html("Teknisi Daily Tasks - Concept C", body_tasks, "light", "C", common_css))

    # 3. spv_dispatch.html
    body_spv = """
    <div class="editorial-header">
      <div>
        <div style="font-size:12px; font-weight:700; color:var(--text-secondary); text-transform:uppercase; letter-spacing:0.8px;">Kontrol Supervisor</div>
        <h1>Penugasan Tim</h1>
      </div>
      <div style="font-size:13px; font-weight:700; color:var(--accent);">KC Manado</div>
    </div>

    <!-- ONE Hero Metric Surface -->
    <div class="editorial-hero">
      <div style="display:flex; justify-content:space-between; align-items:flex-end;">
        <div>
          <div class="big-numeral">4 <span style="font-size:22px; color:var(--text-secondary); font-weight:600;">/ 6</span></div>
          <div style="font-size:13px; font-weight:600; color:var(--text-secondary); margin-top:4px;">Tugas teknisi terselesaikan hari ini</div>
        </div>
        <div style="text-align:right;">
          <div style="font-size:18px; font-weight:800; color:var(--warning);">2 Pending</div>
          <div style="font-size:12px; color:var(--text-secondary);">3 Teknisi Aktif</div>
        </div>
      </div>
    </div>

    <!-- Boxless Tasks List -->
    <div style="padding:0 20px;">
      <div style="font-size:12px; font-weight:700; color:var(--text-secondary); text-transform:uppercase; margin-bottom:14px;">Daftar Tugas Aktif</div>

      <div style="padding:12px 0; border-bottom:1px solid var(--line);">
        <div style="display:flex; justify-content:space-between;">
          <div class="editorial-title">Pembersihan Sensor Gate Kotor & Kalibrasi Palang Miring</div>
          <span style="font-size:12px; font-weight:800; color:var(--warning);">PENDING</span>
        </div>
        <div class="editorial-meta">Petugas: Budi Santoso · Pos Pasar Bersehati</div>
        <div style="margin-top:6px;">
          <button style="padding:4px 10px; background:transparent; border:1px solid var(--accent); color:var(--accent); font-size:11px; font-weight:700; border-radius:4px; cursor:pointer;">Alihkan Tugas</button>
        </div>
      </div>

      <div style="padding:12px 0; border-bottom:1px solid var(--line);">
        <div style="display:flex; justify-content:space-between;">
          <div class="editorial-title">Penggantian Switch Hub 8-Port Pos Kasir 2</div>
          <span style="font-size:12px; font-weight:800; color:var(--warning);">PENDING</span>
        </div>
        <div class="editorial-meta">Petugas: Farhan Lakoro · Pos Mega Mall Manado</div>
      </div>

      <div style="padding:12px 0; border-bottom:1px solid var(--line);">
        <div style="display:flex; justify-content:space-between;">
          <div class="editorial-title" style="text-decoration:line-through; color:var(--text-secondary);">Cek Barrier Gate Masuk 1 & Sensor Loop</div>
          <span style="font-size:12px; font-weight:800; color:var(--success);">SELESAI</span>
        </div>
        <div class="editorial-meta">Budi Santoso · Selesai 09:30 WITA</div>
      </div>
    </div>

    <div style="padding:20px;">
      <button class="btn-bold">
        <span>Dispatch Tugas Baru</span>
      </button>
    </div>
    """
    with open(os.path.join(c_dir, "spv_dispatch.html"), "w", encoding="utf-8") as f:
        f.write(wrap_html("SPV Task Dispatcher - Concept C", body_spv, "light", "C", common_css))

    # 4. location_detail.html & location_detail_dark.html
    def build_location_detail_bold(is_dark=False):
        return f"""
        <div class="editorial-header">
          <div>
            <div style="font-size:12px; font-weight:700; color:var(--text-secondary); text-transform:uppercase; letter-spacing:0.8px;">Maintenance Lokasi</div>
            <h1>Pasar Bersehati</h1>
          </div>
          <span style="font-size:12px; font-weight:800; background:rgba(37,99,235,0.15); color:var(--accent); padding:4px 8px; border-radius:4px;">PBM</span>
        </div>

        <!-- ONE Hero Surface -->
        <div class="editorial-hero">
          <div style="font-size:12px; font-weight:700; color:var(--text-secondary); text-transform:uppercase;">Ringkasan 4 Fase</div>
          <div style="display:flex; justify-content:space-between; align-items:flex-end; margin-top:8px;">
            <div>
              <div class="big-numeral">1 <span style="font-size:22px; color:var(--text-secondary); font-weight:600;">/ 4</span></div>
              <div style="font-size:12px; color:var(--text-secondary); margin-top:4px;">Fase November Selesai</div>
            </div>
            <div style="text-align:right;">
              <div style="font-size:14px; font-weight:800; color:var(--warning);">Fase 1: 1 Temuan</div>
              <div style="font-size:11.5px; color:var(--text-secondary);">23 dari 24 Poin Sesuai</div>
            </div>
          </div>
        </div>

        <!-- Location Meta Rows (Unenclosed) -->
        <div style="padding:0 20px 16px;">
          <div style="padding:8px 0; border-bottom:1px solid var(--line); font-size:13px;">
            <span style="color:var(--text-secondary);">Alamat:</span> <strong>Jl. Nusantara No. 123 Calaca Wenang</strong>
          </div>
          <div style="padding:8px 0; border-bottom:1px solid var(--line); font-size:13px;">
            <span style="color:var(--text-secondary);">Teknisi:</span> <strong>Budi Santoso (NPP-10123)</strong>
          </div>
          <div style="padding:8px 0; border-bottom:1px solid var(--line); font-size:13px;">
            <span style="color:var(--text-secondary);">Waktu Inspeksi:</span> <strong>03 Nov 2026, 09:30 WITA</strong>
          </div>
          <div style="margin-top:12px;">
            <button class="btn-bold" style="background:var(--accent-bg); color:var(--accent);">
              <span>Buka Petunjuk di Google Maps</span>
            </button>
          </div>
        </div>

        <!-- Temuan Section (Boxless) -->
        <div style="padding:0 20px;">
          <div style="font-size:12px; font-weight:700; color:var(--text-secondary); text-transform:uppercase; margin-bottom:12px;">Temuan Terbuka</div>

          <div style="padding:14px 0; border-bottom:1px solid var(--line);">
            <div style="display:flex; justify-content:space-between; align-items:center;">
              <span style="font-size:11px; font-weight:800; color:var(--danger); background:rgba(220,38,38,0.1); padding:2px 6px; border-radius:4px;">URGENT</span>
              <span style="font-size:12px; font-weight:800; color:var(--warning);">BELUM DIPERBAIKI</span>
            </div>
            <div class="editorial-title" style="margin-top:6px;">Sensor gate kotor dan palang penghalang sedikit miring butuh kalibrasi</div>
            <div class="editorial-meta">Perlu dibersihkan segera dengan cairan pembersih khusus elektronik dan baut angkur dikencangkan ulang.</div>
            <div style="margin-top:12px;">
              <button class="btn-bold">
                <span>Tandai Sudah Diperbaiki (Ambil Foto Bukti)</span>
              </button>
            </div>
          </div>
        </div>
        """
    with open(os.path.join(c_dir, "location_detail.html"), "w", encoding="utf-8") as f:
        f.write(wrap_html("Location Detail - Concept C", build_location_detail_bold(False), "light", "C", common_css))
    with open(os.path.join(c_dir, "location_detail_dark.html"), "w", encoding="utf-8") as f:
        f.write(wrap_html("Location Detail Dark - Concept C", build_location_detail_bold(True), "dark", "C", common_css))

    # 5. map_maintenance.html
    body_map = """
    <div class="editorial-header">
      <div>
        <div style="font-size:12px; font-weight:700; color:var(--text-secondary); text-transform:uppercase;">Sebaran Peta</div>
        <h1>Map Maintenance</h1>
      </div>
      <div style="font-size:12px; font-weight:700; color:var(--accent);">Manado · Nov 2026</div>
    </div>

    <div style="padding:0 20px 10px; display:flex; gap:12px; font-size:13px; font-weight:700;">
      <span style="color:var(--accent); border-bottom:2px solid var(--accent); padding-bottom:4px;">Fase 1 (1-7)</span>
      <span style="color:var(--text-secondary);">Fase 2</span>
      <span style="color:var(--text-secondary);">Fase 3</span>
      <span style="color:var(--text-secondary);">Fase 4</span>
    </div>

    <!-- Map Canvas -->
    <div style="width:100%; height:460px; background:#E5E7EB; position:relative; overflow:hidden;">
      <svg width="100%" height="100%">
        <rect width="100%" height="100%" fill="#E5E7EB"/>
        <circle cx="180" cy="200" r="14" fill="#EA580C"/>
        <circle cx="180" cy="200" r="6" fill="#FFFFFF"/>
        <circle cx="280" cy="140" r="12" fill="#16A34A"/>
        <circle cx="280" cy="140" r="5" fill="#FFFFFF"/>
      </svg>
      <div style="position:absolute; left:180px; top:220px; font-size:11.5px; font-weight:800; color:#18181B; transform:translateX(-50%);">Pos Pasar Bersehati</div>
      <div style="position:absolute; left:280px; top:160px; font-size:11.5px; font-weight:800; color:#18181B; transform:translateX(-50%);">Mega Mall (Aman)</div>
    </div>

    <!-- Selected Pos Summary -->
    <div style="padding:16px 20px;">
      <div style="font-size:12px; font-weight:700; color:var(--text-secondary); text-transform:uppercase;">Detail Titik Peta</div>
      <div style="font-size:16px; font-weight:800; margin-top:2px;">Pos Pasar Bersehati Manado</div>
      <div style="font-size:12.5px; color:var(--text-secondary); margin-top:2px;">Fase 1: 23 dari 24 Poin Sesuai (1 Temuan) · Budi Santoso</div>
      <div style="margin-top:10px;">
        <button class="btn-bold">
          <span>Buka Detail Inspeksi</span>
        </button>
      </div>
    </div>
    """
    with open(os.path.join(c_dir, "map_maintenance.html"), "w", encoding="utf-8") as f:
        f.write(wrap_html("Map Maintenance - Concept C", body_map, "light", "C", common_css))

    # 6. maintenance_checklist.html
    body_chk = """
    <div class="editorial-header">
      <div>
        <div style="font-size:12px; font-weight:700; color:var(--text-secondary); text-transform:uppercase;">Checklist SOP</div>
        <h1>Barrier Gate</h1>
      </div>
      <div style="font-size:12px; font-weight:700; color:var(--accent);">Pos Pasar Bersehati</div>
    </div>

    <!-- Hero Progress -->
    <div class="editorial-hero">
      <div style="display:flex; justify-content:space-between; align-items:flex-end;">
        <div>
          <div class="big-numeral">18 <span style="font-size:22px; color:var(--text-secondary); font-weight:600;">/ 24</span></div>
          <div style="font-size:12px; color:var(--text-secondary); margin-top:4px;">Foto dokumentasi poin lengkap</div>
        </div>
        <span style="font-size:13px; font-weight:700; color:var(--warning);">6 Belum Foto</span>
      </div>
    </div>

    <!-- Checklist Points -->
    <div style="padding:0 20px;">
      <div style="font-size:12px; font-weight:700; color:var(--text-secondary); text-transform:uppercase; margin-bottom:12px;">Poin Evaluasi SOP</div>

      <div style="padding:12px 0; border-bottom:1px solid var(--line);">
        <div style="display:flex; justify-content:space-between;">
          <div class="editorial-title">Kerapian Bodi & Kebersihan Housing Barrier Gate</div>
          <span style="font-size:12px; font-weight:800; color:var(--success);">SESUAI</span>
        </div>
        <div class="editorial-meta">Housing bersih bebas karat pekat · Lolos AI</div>
      </div>

      <div style="padding:12px 0; border-bottom:1px solid var(--line);">
        <div style="display:flex; justify-content:space-between;">
          <div class="editorial-title">Lampu Indikator LED Palang & Flashing Light</div>
          <span style="font-size:12px; font-weight:800; color:var(--success);">SESUAI</span>
        </div>
        <div class="editorial-meta">Menyala normal saat buka tutup · Lolos AI</div>
      </div>

      <div style="padding:12px 0; border-bottom:1px solid var(--line);">
        <div style="display:flex; justify-content:space-between;">
          <div class="editorial-title">Sensor Vehicle Loop Detector & Photocell Keamanan</div>
          <span style="font-size:12px; font-weight:800; color:var(--warning);">PERLU CEK</span>
        </div>
        <div class="editorial-meta">Sensor kotor & palang penghalang sedikit miring</div>
      </div>

      <div style="padding:12px 0; border-bottom:1px solid var(--line);">
        <div style="display:flex; justify-content:space-between;">
          <div class="editorial-title">Tombol Manual Push Button di Meja Kasir</div>
          <span style="font-size:12px; font-weight:800; color:var(--text-secondary);">BELUM FOTO</span>
        </div>
        <div class="editorial-meta">Foto dokumentasi wajib diambil</div>
      </div>
    </div>

    <div style="padding:20px;">
      <button class="btn-bold" disabled style="opacity:0.7;">
        <span>Lengkapi 18/24 Foto Dulu</span>
      </button>
    </div>
    """
    with open(os.path.join(c_dir, "maintenance_checklist.html"), "w", encoding="utf-8") as f:
        f.write(wrap_html("Maintenance Checklist - Concept C", body_chk, "light", "C", common_css))

    # 7. attendance_archive.html
    body_arc = """
    <div class="editorial-header">
      <div>
        <div style="font-size:12px; font-weight:700; color:var(--text-secondary); text-transform:uppercase;">Riwayat Kerja</div>
        <h1>Arsip Absensi</h1>
      </div>
      <div style="font-size:12px; font-weight:700; color:var(--accent);">30 Hari Terakhir</div>
    </div>

    <!-- ONE Hero Metric -->
    <div class="editorial-hero">
      <div style="display:flex; justify-content:space-around; text-align:center;">
        <div>
          <div class="big-numeral" style="color:var(--success);">24</div>
          <div style="font-size:12px; font-weight:700; color:var(--text-secondary); margin-top:2px;">HADIR</div>
        </div>
        <div style="border-left:1px solid var(--line); border-right:1px solid var(--line); padding:0 20px;">
          <div class="big-numeral" style="color:var(--accent);">24</div>
          <div style="font-size:12px; font-weight:700; color:var(--text-secondary); margin-top:2px;">PULANG</div>
        </div>
        <div>
          <div class="big-numeral" style="color:var(--warning);">1</div>
          <div style="font-size:12px; font-weight:700; color:var(--text-secondary); margin-top:2px;">TELAT</div>
        </div>
      </div>
    </div>

    <!-- Timeline Records -->
    <div class="timeline-container">
      <div style="font-size:12px; font-weight:700; color:var(--text-secondary); text-transform:uppercase; margin-bottom:16px;">Catatan Timemark</div>

      <div class="timeline-item success">
        <div class="editorial-title">Masuk Dinas · 08 Nov 2026</div>
        <div class="editorial-meta">08:05 WITA · Tepat Waktu · Kode #VER-9102</div>
      </div>

      <div class="timeline-item neutral">
        <div class="editorial-title">Pulang Dinas · 07 Nov 2026</div>
        <div class="editorial-meta">16:45 WITA · Durasi 8j 40m · 3 Tugas Selesai</div>
      </div>

      <div class="timeline-item warning">
        <div class="editorial-title">Masuk Dinas · 07 Nov 2026</div>
        <div class="editorial-meta">08:25 WITA · Terlambat 25 Menit · Kode #VER-8911</div>
      </div>
    </div>

    <div style="padding:0 20px 20px;">
      <button class="btn-bold">
        <span>Export Spreadsheet (CSV)</span>
      </button>
    </div>
    """
    with open(os.path.join(c_dir, "attendance_archive.html"), "w", encoding="utf-8") as f:
        f.write(wrap_html("Attendance Archive - Concept C", body_arc, "light", "C", common_css))

def render_screens_to_png():
    screens = [
        "camera_home",
        "teknisi_tasks",
        "spv_dispatch",
        "location_detail",
        "location_detail_dark",
        "map_maintenance",
        "maintenance_checklist",
        "attendance_archive"
    ]

    for concept in ["A", "B", "C"]:
        c_dir = os.path.join(BASE_DIR, concept)
        screen_list = list(screens)
        if concept == "A":
            screen_list.append("location_detail_ts13")

        png_paths = []
        for s in screen_list:
            html_path = os.path.join(c_dir, f"{s}.html")
            png_path = os.path.join(c_dir, f"{s}.png")
            if not os.path.exists(html_path):
                continue
            cmd = [
                "google-chrome-stable",
                "--headless",
                "--disable-gpu",
                "--force-device-scale-factor=2",
                "--window-size=390,844",
                f"--screenshot={png_path}",
                f"file://{html_path}"
            ]
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            if res.returncode == 0:
                print(f"Rendered: {concept}/{s}.png")
                # Exclude dark / ts13 variants from the primary 7-screen overview
                if s in ["camera_home", "teknisi_tasks", "spv_dispatch", "location_detail", "map_maintenance", "maintenance_checklist", "attendance_archive"]:
                    png_paths.append(png_path)
            else:
                print(f"Error rendering {concept}/{s}: {res.stderr.decode()}", file=sys.stderr)

        # Generate overview comparison sheet (all 7 core screens side by side)
        if len(png_paths) >= 7:
            overview_path = os.path.join(c_dir, "overview.png")
            # Using montage to layout 7 screens in a row or 2 rows
            # montage -geometry +10+10 -tile 7x1 or 4x2
            montage_cmd = [
                "montage",
                "-geometry", "+12+12",
                "-tile", "4x2",
                "-background", "#F1F5F9"
            ] + png_paths + [overview_path]
            res = subprocess.run(montage_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            if res.returncode == 0:
                print(f"Rendered Overview: {concept}/overview.png")
            else:
                print(f"Error creating overview for {concept}: {res.stderr.decode()}", file=sys.stderr)

if __name__ == "__main__":
    print("Generating Concept A HTML...")
    generate_concept_a()
    print("Generating Concept B HTML...")
    generate_concept_b()
    print("Generating Concept C HTML...")
    generate_concept_c()
    print("Rendering HTML mockups to PNG @2x...")
    render_screens_to_png()
    print("All concepts generated and rendered successfully.")
