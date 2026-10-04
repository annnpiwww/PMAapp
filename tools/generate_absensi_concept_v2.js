const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

const width = 2100;
const height = 1260;

const svg = `
<svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <!-- Background Gradient -->
    <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#080d18" />
      <stop offset="45%" stop-color="#0f172a" />
      <stop offset="100%" stop-color="#090f1f" />
    </linearGradient>

    <!-- Viewfinder Gradient -->
    <linearGradient id="viewfinderGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#1e293b" />
      <stop offset="60%" stop-color="#0f172a" />
      <stop offset="100%" stop-color="#020617" />
    </linearGradient>

    <!-- Watermark Card Gradient -->
    <linearGradient id="wmCardGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="rgba(15, 23, 42, 0.78)" />
      <stop offset="100%" stop-color="rgba(2, 6, 23, 0.96)" />
    </linearGradient>

    <!-- Drawer Gradient -->
    <linearGradient id="drawerGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#1e293b" />
      <stop offset="100%" stop-color="#0f172a" />
    </linearGradient>

    <filter id="shadow" x="-10%" y="-10%" width="120%" height="120%">
      <feDropShadow dx="0" dy="14" stdDeviation="18" flood-color="#000" flood-opacity="0.7" />
    </filter>
    <filter id="cardShadow" x="-5%" y="-5%" width="110%" height="110%">
      <feDropShadow dx="0" dy="6" stdDeviation="8" flood-color="#000" flood-opacity="0.5" />
    </filter>
    <filter id="glowGreen" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="3" stdDeviation="8" flood-color="#10b981" flood-opacity="0.6" />
    </filter>
    <filter id="glowBlue" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="3" stdDeviation="8" flood-color="#3b82f6" flood-opacity="0.6" />
    </filter>

    <style>
      .title-main { font-family: 'Plus Jakarta Sans', -apple-system, sans-serif; font-size: 38px; font-weight: 900; fill: #ffffff; letter-spacing: 0.5px; }
      .title-sub { font-family: 'Plus Jakarta Sans', -apple-system, sans-serif; font-size: 19px; font-weight: 600; fill: #94a3b8; }
      .mono-time { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, monospace; font-weight: 800; }
    </style>
  </defs>

  <!-- Background Canvas -->
  <rect width="${width}" height="${height}" fill="url(#bgGrad)" />
  <circle cx="240" cy="90" r="320" fill="#1e3a8a" opacity="0.15" />
  <circle cx="1860" cy="200" r="380" fill="#047857" opacity="0.12" />

  <!-- TOP HEADER BANNER -->
  <g transform="translate(80, 46)">
    <rect x="0" y="0" width="112" height="38" rx="19" fill="#1e40af" fill-opacity="0.3" stroke="#3b82f6" stroke-width="1.5" />
    <text x="56" y="24" text-anchor="middle" font-family="'Plus Jakarta Sans', sans-serif" font-size="12" font-weight="900" fill="#60a5fa" letter-spacing="1">REVISI FINAL</text>
    
    <text x="128" y="28" class="title-main">BSS TIMEMARK — KONSEP DETEKSI SHIFT &amp; ARSIP</text>
    <text x="0" y="70" class="title-sub">Shutter Kamera Standar Pro • Shortcut Shift Auto-Detect • Hitung Durasi Kerja Pulang • Menu Arsip di Hamburger</text>
  </g>

  <!-- ================= SCREEN 1: DETEKSI SHIFT MASUK ================= -->
  <g transform="translate(80, 146)">
    <!-- Section Label Tag -->
    <rect x="10" y="0" width="240" height="34" rx="10" fill="#065f46" fill-opacity="0.35" stroke="#10b981" stroke-width="1.5" />
    <circle cx="28" cy="17" r="5" fill="#10b981" />
    <text x="42" y="22" font-family="'Plus Jakarta Sans', sans-serif" font-size="13" font-weight="800" fill="#34d399">1. MASUK : SHIFT AUTO-DETECT</text>

    <!-- Phone Frame -->
    <g transform="translate(0, 48)" filter="url(#shadow)">
      <rect x="0" y="0" width="580" height="980" rx="36" fill="#020617" stroke="#334155" stroke-width="3.5" />

      <!-- Status Bar -->
      <text x="36" y="34" font-family="-apple-system, sans-serif" font-size="13" font-weight="700" fill="#ffffff">08:15</text>
      <g transform="translate(480, 22)">
        <path d="M0 12 L8 4 L16 12 Z" fill="#ffffff" />
        <rect x="22" y="3" width="22" height="11" rx="3" fill="none" stroke="#ffffff" stroke-width="1.5" />
        <rect x="24" y="5" width="14" height="7" rx="1.5" fill="#ffffff" />
      </g>

      <!-- Camera Top Bar -->
      <g transform="translate(24, 52)">
        <circle cx="20" cy="20" r="18" fill="rgba(0,0,0,0.5)" />
        <path d="M12 14 H28 M12 20 H28 M12 26 H28" stroke="#ffffff" stroke-width="2" stroke-linecap="round" />

        <rect x="52" y="4" width="70" height="32" rx="16" fill="rgba(0,0,0,0.5)" stroke="rgba(255,255,255,0.2)" />
        <text x="87" y="24" text-anchor="middle" font-family="sans-serif" font-size="12" font-weight="800" fill="#38bdf8">3:4 ▾</text>

        <rect x="130" y="4" width="72" height="32" rx="16" fill="rgba(0,0,0,0.5)" stroke="rgba(255,255,255,0.2)" />
        <text x="166" y="24" text-anchor="middle" font-family="sans-serif" font-size="12" font-weight="800" fill="#facc15">3s ▾</text>

        <circle cx="460" cy="20" r="18" fill="rgba(0,0,0,0.5)" />
        <path d="M460 11 L454 21 L460 21 L459 29 L466 18 L460 18 Z" fill="#facc15" />
        <circle cx="504" cy="20" r="18" fill="rgba(0,0,0,0.5)" />
        <path d="M497 20 A7 7 0 1 1 511 20" fill="none" stroke="#ffffff" stroke-width="2" />
      </g>

      <!-- Viewfinder Container -->
      <g transform="translate(20, 106)">
        <rect x="0" y="0" width="540" height="660" rx="20" fill="url(#viewfinderGrad)" />
        
        <!-- Viewfinder Reticle -->
        <circle cx="270" cy="250" r="40" fill="none" stroke="rgba(250, 204, 21, 0.45)" stroke-width="1.5" stroke-dasharray="6,4" />
        <circle cx="270" cy="250" r="4" fill="#facc15" />

        <!-- Zoom Controls on Right -->
        <g transform="translate(484, 180)">
          <circle cx="18" cy="18" r="18" fill="#ffffff" />
          <text x="18" y="23" text-anchor="middle" font-family="monospace" font-size="12" font-weight="900" fill="#0f172a">1x</text>
          <circle cx="18" cy="62" r="18" fill="rgba(0,0,0,0.55)" stroke="rgba(255,255,255,0.3)" />
          <text x="18" y="67" text-anchor="middle" font-family="monospace" font-size="12" font-weight="800" fill="#ffffff">2x</text>
          <circle cx="18" cy="106" r="18" fill="rgba(0,0,0,0.55)" stroke="rgba(255,255,255,0.3)" />
          <text x="18" y="111" text-anchor="middle" font-family="monospace" font-size="12" font-weight="800" fill="#ffffff">5x</text>
        </g>

        <!-- WATERMARK CARD: 100% SCALE PROPORSIONAL -->
        <g transform="translate(18, 470)" filter="url(#cardShadow)">
          <rect x="0" y="0" width="460" height="166" rx="14" fill="url(#wmCardGrad)" stroke="rgba(255,255,255,0.18)" stroke-width="1.2" />

          <!-- Top Row: Logo & Badge & Verified -->
          <g transform="translate(14, 14)">
            <rect x="0" y="0" width="56" height="24" rx="6" fill="#1e40af" />
            <text x="28" y="16" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="900" fill="#ffffff">BSS</text>

            <rect x="64" y="0" width="96" height="24" rx="6" fill="#10b981" />
            <text x="112" y="16" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="900" fill="#ffffff">Jam Masuk</text>

            <rect x="306" y="0" width="124" height="22" rx="4" fill="rgba(255,255,255,0.12)" stroke="rgba(255,255,255,0.25)" />
            <text x="368" y="15" text-anchor="middle" class="mono-time" font-size="10" fill="#38bdf8">TIMEMARK VERIFIED</text>
          </g>

          <!-- Middle Row: Big Time & Shift Status -->
          <g transform="translate(14, 48)">
            <text x="0" y="32" class="mono-time" font-size="34" fill="#ffffff">08:15</text>
            <rect x="112" y="6" width="3" height="30" rx="1.5" fill="#10b981" />
            <text x="126" y="20" font-family="sans-serif" font-size="13" font-weight="800" fill="#ffffff">Senin, 14 September 2026</text>
            <text x="126" y="36" font-family="sans-serif" font-size="11" font-weight="700" fill="#34d399">Shift 1 (03:00 - 11:00) • Standby POS</text>
          </g>

          <!-- Bottom Row: Address & GPS -->
          <g transform="translate(14, 102)">
            <rect x="0" y="2" width="3" height="34" rx="1.5" fill="#3b82f6" />
            <text x="12" y="16" font-family="sans-serif" font-size="13.5" font-weight="700" fill="#ffffff">Pelabuhan Kalimas Manado (PKM)</text>
            <text x="12" y="32" font-family="sans-serif" font-size="11.5" font-weight="500" fill="#94a3b8">Teknisi: Farhan Lakoro (Terdaftar Aktif)</text>
            <text x="12" y="48" class="mono-time" font-size="10" fill="#60a5fa">GPS: 1.500147, 124.850032 (Akurasi: 3.8m)</text>
          </g>
        </g>
      </g>

      <!-- BOTTOM BAR: SHUTTER LOGO KAMERA STANDAR & PILL DI ATASNYA -->
      <g transform="translate(0, 784)">
        <rect x="0" y="0" width="580" height="196" fill="#0f172a" />

        <!-- SHORTCUT PILL: MASUK : SHIFT(X) (DI ATAS SHUTTER) -->
        <g transform="translate(148, 14)" filter="url(#glowGreen)">
          <rect x="0" y="0" width="284" height="38" rx="19" fill="#064e3b" stroke="#10b981" stroke-width="1.6" />
          <circle cx="20" cy="19" r="6" fill="#34d399" />
          <text x="36" y="24" font-family="'Plus Jakarta Sans', sans-serif" font-size="13" font-weight="800" fill="#ffffff">Masuk : Shift 1 (03:00-11:00)</text>
          <text x="264" y="24" font-family="sans-serif" font-size="14" font-weight="900" fill="#a7f3d0">▾</text>
        </g>

        <!-- SHUTTER CONTROLS ROW -->
        <g transform="translate(36, 72)">
          <!-- Galeri -->
          <rect x="12" y="6" width="54" height="54" rx="14" fill="#1e293b" stroke="rgba(255,255,255,0.15)" stroke-width="1.5" />
          <text x="39" y="39" text-anchor="middle" font-size="24">🖼️</text>
          <text x="39" y="74" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="600" fill="#94a3b8">Galeri</text>

          <!-- PRO DUAL-RING SHUTTER BUTTON: TETAP LOGO KAMERA! -->
          <g transform="translate(216, 0)">
            <!-- Outer Ring -->
            <circle cx="37" cy="37" r="36" fill="none" stroke="#ffffff" stroke-width="3.5" />
            <!-- Inner Solid Button with Camera Icon -->
            <circle cx="37" cy="37" r="30" fill="#ffffff" />
            <path d="M26 31 L29 27 L45 27 L48 31 L52 31 A2 2 0 0 1 54 33 L54 45 A2 2 0 0 1 52 47 L22 47 A2 2 0 0 1 20 45 L20 33 A2 2 0 0 1 22 31 Z" fill="#0f2c59" />
            <circle cx="37" cy="39" r="5" fill="none" stroke="#ffffff" stroke-width="2" />
          </g>

          <!-- SOP Template Quick Picker -->
          <g transform="translate(442, 6)">
            <rect x="0" y="0" width="54" height="54" rx="14" fill="#1e293b" stroke="rgba(255,255,255,0.15)" stroke-width="1.5" />
            <text x="27" y="34" text-anchor="middle" font-size="22">📑</text>
            <text x="27" y="68" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="600" fill="#94a3b8">Absensi</text>
          </g>
        </g>
      </g>
    </g>
  </g>

  <!-- ================= SCREEN 2: MODE PULANG (TERHITUNG JAM KERJA) ================= -->
  <g transform="translate(760, 146)">
    <!-- Section Label Tag -->
    <rect x="10" y="0" width="250" height="34" rx="10" fill="#1e40af" fill-opacity="0.35" stroke="#3b82f6" stroke-width="1.5" />
    <circle cx="28" cy="17" r="5" fill="#3b82f6" />
    <text x="42" y="22" font-family="'Plus Jakarta Sans', sans-serif" font-size="13" font-weight="800" fill="#60a5fa">2. PULANG : HITUNG JAM KERJA</text>

    <!-- Phone Frame -->
    <g transform="translate(0, 48)" filter="url(#shadow)">
      <rect x="0" y="0" width="580" height="980" rx="36" fill="#020617" stroke="#334155" stroke-width="3.5" />

      <!-- Status Bar -->
      <text x="36" y="34" font-family="-apple-system, sans-serif" font-size="13" font-weight="700" fill="#ffffff">16:45</text>
      <g transform="translate(480, 22)">
        <path d="M0 12 L8 4 L16 12 Z" fill="#ffffff" />
        <rect x="22" y="3" width="22" height="11" rx="3" fill="none" stroke="#ffffff" stroke-width="1.5" />
        <rect x="24" y="5" width="14" height="7" rx="1.5" fill="#ffffff" />
      </g>

      <!-- Camera Top Bar -->
      <g transform="translate(24, 52)">
        <circle cx="20" cy="20" r="18" fill="rgba(0,0,0,0.5)" />
        <path d="M12 14 H28 M12 20 H28 M12 26 H28" stroke="#ffffff" stroke-width="2" stroke-linecap="round" />

        <rect x="52" y="4" width="70" height="32" rx="16" fill="rgba(0,0,0,0.5)" stroke="rgba(255,255,255,0.2)" />
        <text x="87" y="24" text-anchor="middle" font-family="sans-serif" font-size="12" font-weight="800" fill="#38bdf8">3:4 ▾</text>

        <rect x="130" y="4" width="72" height="32" rx="16" fill="rgba(0,0,0,0.5)" stroke="rgba(255,255,255,0.2)" />
        <text x="166" y="24" text-anchor="middle" font-family="sans-serif" font-size="12" font-weight="800" fill="#facc15">3s ▾</text>

        <circle cx="460" cy="20" r="18" fill="rgba(0,0,0,0.5)" />
        <path d="M460 11 L454 21 L460 21 L459 29 L466 18 L460 18 Z" fill="#facc15" />
        <circle cx="504" cy="20" r="18" fill="rgba(0,0,0,0.5)" />
        <path d="M497 20 A7 7 0 1 1 511 20" fill="none" stroke="#ffffff" stroke-width="2" />
      </g>

      <!-- Viewfinder Container -->
      <g transform="translate(20, 106)">
        <rect x="0" y="0" width="540" height="660" rx="20" fill="url(#viewfinderGrad)" />
        
        <!-- Zoom Controls on Right -->
        <g transform="translate(484, 180)">
          <circle cx="18" cy="18" r="18" fill="#ffffff" />
          <text x="18" y="23" text-anchor="middle" font-family="monospace" font-size="12" font-weight="900" fill="#0f172a">1x</text>
          <circle cx="18" cy="62" r="18" fill="rgba(0,0,0,0.55)" stroke="rgba(255,255,255,0.3)" />
          <text x="18" y="67" text-anchor="middle" font-family="monospace" font-size="12" font-weight="800" fill="#ffffff">2x</text>
          <circle cx="18" cy="106" r="18" fill="rgba(0,0,0,0.55)" stroke="rgba(255,255,255,0.3)" />
          <text x="18" y="111" text-anchor="middle" font-family="monospace" font-size="12" font-weight="800" fill="#ffffff">5x</text>
        </g>

        <!-- WATERMARK CARD: PULANG (DURASI KERJA OTOMATIS) -->
        <g transform="translate(18, 470)" filter="url(#cardShadow)">
          <rect x="0" y="0" width="460" height="166" rx="14" fill="url(#wmCardGrad)" stroke="rgba(255,255,255,0.18)" stroke-width="1.2" />

          <!-- Top Row: Logo & Badge & Verified -->
          <g transform="translate(14, 14)">
            <rect x="0" y="0" width="56" height="24" rx="6" fill="#1e40af" />
            <text x="28" y="16" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="900" fill="#ffffff">BSS</text>

            <rect x="64" y="0" width="168" height="24" rx="6" fill="#2563eb" />
            <text x="148" y="16" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="900" fill="#ffffff">Pulang (08:15 - 16:45)</text>

            <rect x="306" y="0" width="124" height="22" rx="4" fill="rgba(255,255,255,0.12)" stroke="rgba(255,255,255,0.25)" />
            <text x="368" y="15" text-anchor="middle" class="mono-time" font-size="10" fill="#38bdf8">TIMEMARK VERIFIED</text>
          </g>

          <!-- Middle Row: Big Time & Live Total Work Box -->
          <g transform="translate(14, 48)">
            <text x="0" y="32" class="mono-time" font-size="34" fill="#ffffff">16:45</text>
            <rect x="112" y="6" width="3" height="30" rx="1.5" fill="#2563eb" />
            <text x="126" y="20" font-family="sans-serif" font-size="13" font-weight="800" fill="#ffffff">Senin, 14 September 2026</text>
            <g transform="translate(126, 26)">
              <rect x="0" y="0" width="160" height="20" rx="5" fill="#10b981" fill-opacity="0.22" stroke="#10b981" stroke-width="1" />
              <text x="80" y="14" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="800" fill="#34d399">⏱️ Total Kerja: 8 Jam 30 Menit</text>
            </g>
          </g>

          <!-- Bottom Row: Address & Shift Pengganti -->
          <g transform="translate(14, 102)">
            <rect x="0" y="2" width="3" height="34" rx="1.5" fill="#10b981" />
            <text x="12" y="16" font-family="sans-serif" font-size="13.5" font-weight="700" fill="#ffffff">Pelabuhan Kalimas Manado (PKM)</text>
            <text x="12" y="32" font-family="sans-serif" font-size="11.5" font-weight="500" fill="#94a3b8">Shift Pengganti: Junifer Manua (Ready)</text>
            <text x="12" y="48" class="mono-time" font-size="10" fill="#60a5fa">GPS: 1.500147, 124.850032 (Presisi GPS)</text>
          </g>
        </g>
      </g>

      <!-- BOTTOM BAR: PILL PULANG (JAM KERJA) + SHUTTER TETAP KAMERA -->
      <g transform="translate(0, 784)">
        <rect x="0" y="0" width="580" height="196" fill="#0f172a" />

        <!-- SHORTCUT PILL: PULANG (JAM KERJA) (DI ATAS SHUTTER) -->
        <g transform="translate(150, 14)" filter="url(#glowBlue)">
          <rect x="0" y="0" width="280" height="38" rx="19" fill="#1e3a8a" stroke="#3b82f6" stroke-width="1.6" />
          <circle cx="20" cy="19" r="6" fill="#60a5fa" />
          <text x="36" y="24" font-family="'Plus Jakarta Sans', sans-serif" font-size="13" font-weight="800" fill="#ffffff">Pulang (Kerja: 8h 30m)</text>
          <text x="258" y="24" font-family="sans-serif" font-size="14" font-weight="900" fill="#bfdbfe">▾</text>
        </g>

        <!-- SHUTTER CONTROLS ROW -->
        <g transform="translate(36, 72)">
          <!-- Galeri -->
          <rect x="12" y="6" width="54" height="54" rx="14" fill="#1e293b" stroke="rgba(255,255,255,0.15)" stroke-width="1.5" />
          <text x="39" y="39" text-anchor="middle" font-size="24">🖼️</text>
          <text x="39" y="74" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="600" fill="#94a3b8">Galeri</text>

          <!-- PRO DUAL-RING SHUTTER BUTTON: TETAP LOGO KAMERA (DENGAN RING BIRU AKSEN) -->
          <g transform="translate(216, 0)">
            <circle cx="37" cy="37" r="36" fill="none" stroke="#3b82f6" stroke-width="3.5" />
            <circle cx="37" cy="37" r="30" fill="#ffffff" />
            <path d="M26 31 L29 27 L45 27 L48 31 L52 31 A2 2 0 0 1 54 33 L54 45 A2 2 0 0 1 52 47 L22 47 A2 2 0 0 1 20 45 L20 33 A2 2 0 0 1 22 31 Z" fill="#1e40af" />
            <circle cx="37" cy="39" r="5" fill="none" stroke="#ffffff" stroke-width="2" />
          </g>

          <!-- SOP Template Quick Picker -->
          <g transform="translate(442, 6)">
            <rect x="0" y="0" width="54" height="54" rx="14" fill="#1e293b" stroke="rgba(255,255,255,0.15)" stroke-width="1.5" />
            <text x="27" y="34" text-anchor="middle" font-size="22">📑</text>
            <text x="27" y="68" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="600" fill="#94a3b8">Absensi</text>
          </g>
        </g>
      </g>
    </g>
  </g>

  <!-- ================= SCREEN 3: MENU HAMBURGER & ARSIP ================= -->
  <g transform="translate(1440, 146)">
    <!-- Section Label Tag -->
    <rect x="10" y="0" width="250" height="34" rx="10" fill="#7c3aed" fill-opacity="0.35" stroke="#a855f7" stroke-width="1.5" />
    <circle cx="28" cy="17" r="5" fill="#c084fc" />
    <text x="42" y="22" font-family="'Plus Jakarta Sans', sans-serif" font-size="13" font-weight="800" fill="#e9d5ff">3. MENU HAMBURGER &gt; ARSIP</text>

    <!-- Phone Frame -->
    <g transform="translate(0, 48)" filter="url(#shadow)">
      <rect x="0" y="0" width="580" height="980" rx="36" fill="#020617" stroke="#334155" stroke-width="3.5" />

      <!-- Viewfinder Background Dimmed (Drawer open overlay) -->
      <rect x="0" y="0" width="580" height="980" rx="36" fill="#000000" fill-opacity="0.65" />

      <!-- SIDEBAR DRAWER PANEL (SLIDE FROM LEFT) -->
      <g transform="translate(0, 0)">
        <rect x="0" y="0" width="440" height="980" rx="36" fill="url(#drawerGrad)" stroke="#334155" stroke-width="2" />

        <!-- User Profile Header -->
        <g transform="translate(28, 60)">
          <!-- Avatar Circle -->
          <circle cx="34" cy="34" r="32" fill="#1e40af" stroke="#3b82f6" stroke-width="2.5" />
          <text x="34" y="42" text-anchor="middle" font-size="26">👨‍💻</text>

          <text x="80" y="28" font-family="'Plus Jakarta Sans', sans-serif" font-size="17" font-weight="900" fill="#ffffff">Farhan Lakoro</text>
          <rect x="80" y="36" width="144" height="20" rx="6" fill="#065f46" />
          <text x="152" y="50" text-anchor="middle" font-family="sans-serif" font-size="10.5" font-weight="800" fill="#34d399">Technical Support • IT</text>
        </g>
        <line x1="28" y1="140" x2="412" y2="140" stroke="rgba(255,255,255,0.1)" stroke-width="1" />

        <!-- SECTION: MENU UTAMA -->
        <g transform="translate(28, 160)">
          <text x="0" y="0" font-family="sans-serif" font-size="11" font-weight="800" fill="#64748b" letter-spacing="1">NAVIGASI APLIKASI</text>

          <!-- Item 1: Kamera Presensi -->
          <g transform="translate(0, 14)">
            <rect x="0" y="0" width="384" height="52" rx="12" fill="rgba(255,255,255,0.05)" />
            <text x="18" y="32" font-size="20">📷</text>
            <text x="54" y="32" font-family="'Plus Jakarta Sans', sans-serif" font-size="14" font-weight="700" fill="#ffffff">Kamera Presensi</text>
          </g>

          <!-- Item 2: HIGHLIGHTED MENU "ARSIP" (LEMBAR KERJA SAYA) -->
          <g transform="translate(0, 78)" filter="url(#glowGreen)">
            <rect x="0" y="0" width="384" height="60" rx="14" fill="#064e3b" stroke="#10b981" stroke-width="1.8" />
            <text x="18" y="37" font-size="24">📁</text>
            <text x="56" y="28" font-family="'Plus Jakarta Sans', sans-serif" font-size="15" font-weight="900" fill="#ffffff">Arsip (Lembar Kerja Saya)</text>
            <text x="56" y="48" font-family="sans-serif" font-size="11.5" font-weight="600" fill="#a7f3d0">Riwayat absensi &amp; export Sheets</text>
            <rect x="306" y="16" width="62" height="26" rx="8" fill="#10b981" />
            <text x="337" y="33" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="900" fill="#ffffff">45 HARI</text>
          </g>

          <!-- Item 3: Template SOP & Checklist -->
          <g transform="translate(0, 150)">
            <rect x="0" y="0" width="384" height="52" rx="12" fill="rgba(255,255,255,0.05)" />
            <text x="18" y="32" font-size="20">📋</text>
            <text x="54" y="32" font-family="'Plus Jakarta Sans', sans-serif" font-size="14" font-weight="700" fill="#ffffff">Template SOP &amp; Form</text>
          </g>

          <!-- Item 4: Maintenance Pos & Unit -->
          <g transform="translate(0, 214)">
            <rect x="0" y="0" width="384" height="52" rx="12" fill="rgba(255,255,255,0.05)" />
            <text x="18" y="32" font-size="20">🛠️</text>
            <text x="54" y="32" font-family="'Plus Jakarta Sans', sans-serif" font-size="14" font-weight="700" fill="#ffffff">Maintenance Checklist</text>
          </g>

          <!-- Item 5: Riwayat Foto Galeri -->
          <g transform="translate(0, 278)">
            <rect x="0" y="0" width="384" height="52" rx="12" fill="rgba(255,255,255,0.05)" />
            <text x="18" y="32" font-size="20">🖼️</text>
            <text x="54" y="32" font-family="'Plus Jakarta Sans', sans-serif" font-size="14" font-weight="700" fill="#ffffff">Galeri &amp; Log Foto</text>
          </g>
        </g>

        <!-- POPUP PREVIEW MODAL ARSIP / TIMESHEET (MINI VIEW) -->
        <g transform="translate(28, 550)" filter="url(#cardShadow)">
          <rect x="0" y="0" width="384" height="350" rx="16" fill="#0b1329" stroke="#1e293b" stroke-width="1.5" />
          
          <g transform="translate(16, 18)">
            <text x="0" y="14" font-family="'Plus Jakarta Sans', sans-serif" font-size="13.5" font-weight="800" fill="#38bdf8">Pratinjau Tabel Arsip (45 Hari)</text>
            <rect x="250" y="0" width="102" height="22" rx="6" fill="#10b981" fill-opacity="0.2" />
            <text x="301" y="15" text-anchor="middle" font-family="sans-serif" font-size="10.5" font-weight="800" fill="#34d399">CSV Ready</text>
          </g>

          <!-- Mini Table Rows -->
          <g transform="translate(16, 50)">
            <rect x="0" y="0" width="352" height="54" rx="10" fill="#15213b" />
            <rect x="10" y="14" width="60" height="24" rx="6" fill="#2563eb" />
            <text x="40" y="30" text-anchor="middle" font-family="sans-serif" font-size="10" font-weight="800" fill="#ffffff">Pulang</text>
            <text x="80" y="24" class="mono-time" font-size="12" fill="#ffffff">16:45 WITA</text>
            <text x="80" y="40" font-family="sans-serif" font-size="10" font-weight="600" fill="#34d399">Total Kerja: 8h 30m</text>
            <text x="250" y="24" font-family="sans-serif" font-size="11" font-weight="700" fill="#ffffff">PKM Kalimas</text>
            <text x="250" y="40" font-family="sans-serif" font-size="9.5" fill="#94a3b8">14/09/2026</text>
          </g>

          <g transform="translate(16, 114)">
            <rect x="0" y="0" width="352" height="54" rx="10" fill="#15213b" />
            <rect x="10" y="14" width="60" height="24" rx="6" fill="#10b981" />
            <text x="40" y="30" text-anchor="middle" font-family="sans-serif" font-size="10" font-weight="800" fill="#ffffff">Masuk</text>
            <text x="80" y="24" class="mono-time" font-size="12" fill="#ffffff">08:15 WITA</text>
            <text x="80" y="40" font-family="sans-serif" font-size="10" font-weight="600" fill="#94a3b8">Shift 1 (03-11)</text>
            <text x="250" y="24" font-family="sans-serif" font-size="11" font-weight="700" fill="#ffffff">PKM Kalimas</text>
            <text x="250" y="40" font-family="sans-serif" font-size="9.5" fill="#94a3b8">14/09/2026</text>
          </g>

          <!-- Bottom Action Button in Drawer -->
          <g transform="translate(16, 260)">
            <rect x="0" y="0" width="352" height="46" rx="12" fill="#10b981" />
            <text x="176" y="29" text-anchor="middle" font-family="'Plus Jakarta Sans', sans-serif" font-size="13" font-weight="800" fill="#ffffff">📊 Buka Lembar Kerja &amp; Export Sheets</text>
          </g>
        </g>
      </g>
    </g>
  </g>

  <!-- BOTTOM FOOTER -->
  <g transform="translate(80, 1200)">
    <line x1="0" y1="0" x2="1940" y2="0" stroke="#1e293b" stroke-width="1.5" />
    <text x="0" y="32" font-family="'Plus Jakarta Sans', sans-serif" font-size="13" font-weight="700" fill="#64748b">BSS Parking Engineering Division • Timemark Architecture Mockup v2.2 (Final Direction)</text>
    <text x="1940" y="32" text-anchor="end" font-family="'Plus Jakarta Sans', sans-serif" font-size="13" font-weight="800" fill="#3b82f6">Dual Knowledge Graph Verified (CodeGraph + Graphify)</text>
  </g>
</svg>
`;

async function main() {
  const artifactDir = '/home/annnpii/.gemini/antigravity-cli/brain/f7ccf0cd-8210-4425-98d6-40aa1457b05f';
  const outPath = path.join(artifactDir, 'bss_absensi_concept_v2.jpg');
  const tempPath = '/tmp/bss_absensi_concept_v2.jpg';

  console.log('Rendering concept mockup v2...');
  await sharp(Buffer.from(svg))
    .jpeg({ quality: 95 })
    .toFile(outPath);
  
  fs.copyFileSync(outPath, tempPath);
  console.log(`Saved to: ${outPath} and ${tempPath}`);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
