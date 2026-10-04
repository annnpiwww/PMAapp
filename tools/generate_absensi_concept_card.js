const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

const width = 2100;
const height = 1260;

const svg = `
<svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <!-- Gradients -->
    <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#090d16" />
      <stop offset="50%" stop-color="#0f172a" />
      <stop offset="100%" stop-color="#0a0f1d" />
    </linearGradient>

    <linearGradient id="primaryGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#3b82f6" />
      <stop offset="100%" stop-color="#1d4ed8" />
    </linearGradient>

    <linearGradient id="greenShutter" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#10b981" />
      <stop offset="100%" stop-color="#059669" />
    </linearGradient>

    <linearGradient id="blueShutter" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#2563eb" />
      <stop offset="100%" stop-color="#1e40af" />
    </linearGradient>

    <linearGradient id="viewfinderGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#1e293b" />
      <stop offset="60%" stop-color="#0f172a" />
      <stop offset="100%" stop-color="#020617" />
    </linearGradient>

    <linearGradient id="wmCardGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="rgba(15, 23, 42, 0.75)" />
      <stop offset="100%" stop-color="rgba(2, 6, 23, 0.95)" />
    </linearGradient>

    <filter id="shadow" x="-10%" y="-10%" width="120%" height="120%">
      <feDropShadow dx="0" dy="12" stdDeviation="16" flood-color="#000" flood-opacity="0.65" />
    </filter>
    <filter id="cardShadow" x="-5%" y="-5%" width="110%" height="110%">
      <feDropShadow dx="0" dy="6" stdDeviation="8" flood-color="#000" flood-opacity="0.5" />
    </filter>
    <filter id="glowGreen" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="4" stdDeviation="10" flood-color="#10b981" flood-opacity="0.5" />
    </filter>
    <filter id="glowBlue" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="4" stdDeviation="10" flood-color="#3b82f6" flood-opacity="0.5" />
    </filter>

    <style>
      .title-main { font-family: 'Plus Jakarta Sans', -apple-system, sans-serif; font-size: 38px; font-weight: 900; fill: #ffffff; letter-spacing: 0.5px; }
      .title-sub { font-family: 'Plus Jakarta Sans', -apple-system, sans-serif; font-size: 19px; font-weight: 600; fill: #94a3b8; }
      .screen-title { font-family: 'Plus Jakarta Sans', -apple-system, sans-serif; font-size: 20px; font-weight: 800; fill: #f8fafc; }
      .screen-badge { font-family: 'Plus Jakarta Sans', -apple-system, sans-serif; font-size: 12px; font-weight: 800; }
      .app-text { font-family: 'Plus Jakarta Sans', -apple-system, sans-serif; font-size: 13px; fill: #f8fafc; }
      .app-muted { font-family: 'Plus Jakarta Sans', -apple-system, sans-serif; font-size: 11px; fill: #94a3b8; }
      .mono-time { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, monospace; font-weight: 800; }
    </style>
  </defs>

  <!-- Background -->
  <rect width="${width}" height="${height}" fill="url(#bgGrad)" />
  
  <!-- Subtle Header Pattern -->
  <circle cx="200" cy="80" r="300" fill="#1e3a8a" opacity="0.12" />
  <circle cx="1900" cy="150" r="400" fill="#065f46" opacity="0.1" />

  <!-- TOP HERO HEADER -->
  <g transform="translate(80, 50)">
    <rect x="0" y="0" width="84" height="42" rx="21" fill="#1e40af" fill-opacity="0.25" stroke="#3b82f6" stroke-width="1.5" />
    <text x="42" y="26" text-anchor="middle" font-family="'Plus Jakarta Sans', sans-serif" font-size="13" font-weight="800" fill="#60a5fa" letter-spacing="1">PROPOSAL FITUR</text>
    
    <text x="100" y="30" class="title-main">BSS PARKING TIMEMARK — KONSEP TRACKING ABSENSI</text>
    <text x="0" y="70" class="title-sub">Adopsi TimeMark: Shutter Dinamis (Jam Masuk / Pulang), Live Work Timer, &amp; Lembar Waktu Saya (Timesheet 45 Hari)</text>
  </g>

  <!-- 3 DEVICE PHONE SCREENS -->

  <!-- ================= SCREEN 1: JAM MASUK ================= -->
  <g transform="translate(80, 150)">
    <!-- Section Label Tag -->
    <rect x="10" y="0" width="220" height="34" rx="10" fill="#065f46" fill-opacity="0.3" stroke="#10b981" stroke-width="1.5" />
    <circle cx="28" cy="17" r="5" fill="#10b981" />
    <text x="42" y="22" font-family="'Plus Jakarta Sans', sans-serif" font-size="13" font-weight="800" fill="#34d399">1. STATE 1: SEBELUM MASUK</text>

    <!-- Phone Frame -->
    <g transform="translate(0, 48)" filter="url(#shadow)">
      <rect x="0" y="0" width="580" height="980" rx="36" fill="#020617" stroke="#334155" stroke-width="3.5" />

      <!-- Status Bar -->
      <text x="36" y="34" font-family="-apple-system, sans-serif" font-size="13" font-weight="700" fill="#ffffff">11:22</text>
      <g transform="translate(480, 22)">
        <path d="M0 12 L8 4 L16 12 Z" fill="#ffffff" />
        <rect x="22" y="3" width="22" height="11" rx="3" fill="none" stroke="#ffffff" stroke-width="1.5" />
        <rect x="24" y="5" width="14" height="7" rx="1.5" fill="#ffffff" />
      </g>

      <!-- Camera Top Bar -->
      <g transform="translate(24, 52)">
        <!-- Hamburger Menu -->
        <circle cx="20" cy="20" r="18" fill="rgba(0,0,0,0.5)" />
        <path d="M12 14 H28 M12 20 H28 M12 26 H28" stroke="#ffffff" stroke-width="2" stroke-linecap="round" />

        <!-- Ratio Pill -->
        <rect x="52" y="4" width="70" height="32" rx="16" fill="rgba(0,0,0,0.5)" stroke="rgba(255,255,255,0.2)" />
        <text x="87" y="24" text-anchor="middle" font-family="sans-serif" font-size="12" font-weight="800" fill="#38bdf8">3:4 ▾</text>

        <!-- Timer Pill -->
        <rect x="130" y="4" width="72" height="32" rx="16" fill="rgba(0,0,0,0.5)" stroke="rgba(255,255,255,0.2)" />
        <text x="166" y="24" text-anchor="middle" font-family="sans-serif" font-size="12" font-weight="800" fill="#facc15">3s ▾</text>

        <!-- Flash & Flip -->
        <circle cx="460" cy="20" r="18" fill="rgba(0,0,0,0.5)" />
        <path d="M460 11 L454 21 L460 21 L459 29 L466 18 L460 18 Z" fill="#facc15" />
        <circle cx="504" cy="20" r="18" fill="rgba(0,0,0,0.5)" />
        <path d="M497 20 A7 7 0 1 1 511 20" fill="none" stroke="#ffffff" stroke-width="2" />
      </g>

      <!-- Viewfinder Container -->
      <g transform="translate(20, 106)">
        <rect x="0" y="0" width="540" height="660" rx="20" fill="url(#viewfinderGrad)" />
        
        <!-- Viewfinder Focus Reticle -->
        <circle cx="270" cy="260" r="42" fill="none" stroke="rgba(250, 204, 21, 0.4)" stroke-width="1.5" stroke-dasharray="6,4" />
        <circle cx="270" cy="260" r="4" fill="#facc15" />

        <!-- Zoom Pill on Right -->
        <g transform="translate(484, 180)">
          <circle cx="18" cy="18" r="18" fill="#ffffff" />
          <text x="18" y="23" text-anchor="middle" font-family="monospace" font-size="12" font-weight="900" fill="#0f172a">1x</text>
          <circle cx="18" cy="62" r="18" fill="rgba(0,0,0,0.55)" stroke="rgba(255,255,255,0.3)" />
          <text x="18" y="67" text-anchor="middle" font-family="monospace" font-size="12" font-weight="800" fill="#ffffff">2x</text>
          <circle cx="18" cy="106" r="18" fill="rgba(0,0,0,0.55)" stroke="rgba(255,255,255,0.3)" />
          <text x="18" y="111" text-anchor="middle" font-family="monospace" font-size="12" font-weight="800" fill="#ffffff">5x</text>
        </g>

        <!-- WATERMARK CARD: 100% SCALE (DEFAULT PROPORSIONAL) -->
        <g transform="translate(18, 470)" filter="url(#cardShadow)">
          <rect x="0" y="0" width="460" height="166" rx="14" fill="url(#wmCardGrad)" stroke="rgba(255,255,255,0.18)" stroke-width="1.2" />

          <!-- Top Row: Logo & Badge & Verified -->
          <g transform="translate(14, 14)">
            <!-- BSS Badge -->
            <rect x="0" y="0" width="56" height="24" rx="6" fill="#1e40af" />
            <text x="28" y="16" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="900" fill="#ffffff">BSS</text>

            <!-- State Badge: Jam Masuk (HIJAU) -->
            <rect x="64" y="0" width="96" height="24" rx="6" fill="#10b981" />
            <text x="112" y="16" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="900" fill="#ffffff">Jam Masuk</text>

            <!-- Verified Tag -->
            <rect x="306" y="0" width="124" height="22" rx="4" fill="rgba(255,255,255,0.12)" stroke="rgba(255,255,255,0.25)" />
            <text x="368" y="15" text-anchor="middle" class="mono-time" font-size="10" fill="#38bdf8">TIMEMARK VERIFIED</text>
          </g>

          <!-- Middle Row: Big Time & Date -->
          <g transform="translate(14, 48)">
            <text x="0" y="32" class="mono-time" font-size="34" fill="#ffffff">11:23</text>
            <rect x="112" y="6" width="3" height="30" rx="1.5" fill="#10b981" />
            <text x="126" y="20" font-family="sans-serif" font-size="13" font-weight="800" fill="#ffffff">Minggu, 13 September 2026</text>
            <text x="126" y="36" font-family="sans-serif" font-size="11" font-weight="600" fill="#34d399">Shift 1 (03:00 - 11:00) • Standby POS</text>
          </g>

          <!-- Bottom Row: Address (DIBESARKAN 13px PROPORSIONAL) & GPS -->
          <g transform="translate(14, 102)">
            <rect x="0" y="2" width="3" height="34" rx="1.5" fill="#3b82f6" />
            <text x="12" y="16" font-family="sans-serif" font-size="13.5" font-weight="700" fill="#ffffff">Pelabuhan Kalimas Manado (PKM)</text>
            <text x="12" y="32" font-family="sans-serif" font-size="11.5" font-weight="500" fill="#94a3b8">Singkil Satu, Kec. Singkil, Kota Manado, Sulawesi Utara</text>
            <text x="12" y="48" class="mono-time" font-size="10" fill="#60a5fa">GPS: 1.500147, 124.850032 (Akurasi: 4.2m)</text>
          </g>
        </g>
      </g>

      <!-- BOTTOM BAR: CONTROLS & SHUTTER -->
      <g transform="translate(0, 784)">
        <rect x="0" y="0" width="580" height="196" fill="#0f172a" />

        <!-- SHORTCUT PILL: LEMBAR WAKTU SAYA (DI ATAS SHUTTER) -->
        <g transform="translate(180, 16)">
          <rect x="0" y="0" width="220" height="36" rx="18" fill="rgba(255,255,255,0.12)" stroke="rgba(255,255,255,0.25)" stroke-width="1.2" />
          <text x="26" y="23" font-family="sans-serif" font-size="13">📋</text>
          <text x="50" y="23" font-family="'Plus Jakarta Sans', sans-serif" font-size="12.5" font-weight="800" fill="#ffffff">Lembar Waktu Saya</text>
          <text x="194" y="23" font-family="sans-serif" font-size="13" font-weight="900" fill="#94a3b8">›</text>
        </g>

        <!-- SHUTTER CONTROLS ROW -->
        <g transform="translate(36, 72)">
          <!-- Galeri -->
          <rect x="12" y="6" width="54" height="54" rx="14" fill="#1e293b" stroke="rgba(255,255,255,0.15)" stroke-width="1.5" />
          <text x="39" y="39" text-anchor="middle" font-size="24">🖼️</text>
          <text x="39" y="74" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="600" fill="#94a3b8">Galeri</text>

          <!-- DYNAMIC SHUTTER: HIJAU "JAM MASUK" -->
          <g transform="translate(126, 0)" filter="url(#glowGreen)">
            <rect x="0" y="0" width="256" height="66" rx="33" fill="url(#greenShutter)" stroke="#ffffff" stroke-width="2.5" />
            <circle cx="36" cy="33" r="18" fill="rgba(255,255,255,0.2)" />
            <path d="M30 33 L35 38 L44 28" fill="none" stroke="#ffffff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" />
            <text x="64" y="40" font-family="'Plus Jakarta Sans', sans-serif" font-size="17" font-weight="900" fill="#ffffff" letter-spacing="1">JAM MASUK</text>
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

  <!-- ================= SCREEN 2: JAM PULANG & LIVE TIMER ================= -->
  <g transform="translate(760, 150)">
    <!-- Section Label Tag -->
    <rect x="10" y="0" width="240" height="34" rx="10" fill="#1e40af" fill-opacity="0.3" stroke="#3b82f6" stroke-width="1.5" />
    <circle cx="28" cy="17" r="5" fill="#3b82f6" />
    <text x="42" y="22" font-family="'Plus Jakarta Sans', sans-serif" font-size="13" font-weight="800" fill="#60a5fa">2. STATE 2: SESUDAH MASUK (ON DUTY)</text>

    <!-- Phone Frame -->
    <g transform="translate(0, 48)" filter="url(#shadow)">
      <rect x="0" y="0" width="580" height="980" rx="36" fill="#020617" stroke="#334155" stroke-width="3.5" />

      <!-- Status Bar -->
      <text x="36" y="34" font-family="-apple-system, sans-serif" font-size="13" font-weight="700" fill="#ffffff">17:31</text>
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
        
        <!-- Zoom Pill on Right -->
        <g transform="translate(484, 180)">
          <circle cx="18" cy="18" r="18" fill="#ffffff" />
          <text x="18" y="23" text-anchor="middle" font-family="monospace" font-size="12" font-weight="900" fill="#0f172a">1x</text>
          <circle cx="18" cy="62" r="18" fill="rgba(0,0,0,0.55)" stroke="rgba(255,255,255,0.3)" />
          <text x="18" y="67" text-anchor="middle" font-family="monospace" font-size="12" font-weight="800" fill="#ffffff">2x</text>
          <circle cx="18" cy="106" r="18" fill="rgba(0,0,0,0.55)" stroke="rgba(255,255,255,0.3)" />
          <text x="18" y="111" text-anchor="middle" font-family="monospace" font-size="12" font-weight="800" fill="#ffffff">5x</text>
        </g>

        <!-- WATERMARK CARD: MODE PULANG (AUTODETECT DURASI KERJA) -->
        <g transform="translate(18, 470)" filter="url(#cardShadow)">
          <rect x="0" y="0" width="460" height="166" rx="14" fill="url(#wmCardGrad)" stroke="rgba(255,255,255,0.18)" stroke-width="1.2" />

          <!-- Top Row: Logo & Badge & Verified -->
          <g transform="translate(14, 14)">
            <rect x="0" y="0" width="56" height="24" rx="6" fill="#1e40af" />
            <text x="28" y="16" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="900" fill="#ffffff">BSS</text>

            <!-- State Badge: Pulang (BIRU) + Rentang Jam -->
            <rect x="64" y="0" width="168" height="24" rx="6" fill="#2563eb" />
            <text x="148" y="16" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="900" fill="#ffffff">Pulang (11:23 - 17:30)</text>

            <!-- Verified Tag -->
            <rect x="306" y="0" width="124" height="22" rx="4" fill="rgba(255,255,255,0.12)" stroke="rgba(255,255,255,0.25)" />
            <text x="368" y="15" text-anchor="middle" class="mono-time" font-size="10" fill="#38bdf8">TIMEMARK VERIFIED</text>
          </g>

          <!-- Middle Row: Big Time & Work Duration Box -->
          <g transform="translate(14, 48)">
            <text x="0" y="32" class="mono-time" font-size="34" fill="#ffffff">17:30</text>
            <rect x="112" y="6" width="3" height="30" rx="1.5" fill="#2563eb" />
            <text x="126" y="20" font-family="sans-serif" font-size="13" font-weight="800" fill="#ffffff">Minggu, 13 September 2026</text>
            <g transform="translate(126, 26)">
              <rect x="0" y="0" width="144" height="18" rx="4" fill="#10b981" fill-opacity="0.2" stroke="#10b981" stroke-width="0.8" />
              <text x="72" y="13" text-anchor="middle" font-family="sans-serif" font-size="10.5" font-weight="800" fill="#34d399">⏱️ Total Kerja: 6h 7m</text>
            </g>
          </g>

          <!-- Bottom Row: Address & GPS -->
          <g transform="translate(14, 102)">
            <rect x="0" y="2" width="3" height="34" rx="1.5" fill="#10b981" />
            <text x="12" y="16" font-family="sans-serif" font-size="13.5" font-weight="700" fill="#ffffff">Pelabuhan Kalimas Manado (PKM)</text>
            <text x="12" y="32" font-family="sans-serif" font-size="11.5" font-weight="500" fill="#94a3b8">Shift Pengganti: Ryan Lumasuge (On Standby)</text>
            <text x="12" y="48" class="mono-time" font-size="10" fill="#60a5fa">GPS: 1.500158, 124.850058 (Verified Valid)</text>
          </g>
        </g>
      </g>

      <!-- BOTTOM BAR: LIVE TIMER & SHUTTER PULANG -->
      <g transform="translate(0, 784)">
        <rect x="0" y="0" width="580" height="196" fill="#0f172a" />

        <!-- LIVE WORK DURATION PILL (GLOWING HIJAU) -->
        <g transform="translate(170, 16)" filter="url(#glowGreen)">
          <rect x="0" y="0" width="240" height="36" rx="18" fill="#065f46" stroke="#10b981" stroke-width="1.5" />
          <circle cx="20" cy="18" r="6" fill="#34d399" />
          <text x="36" y="23" font-family="'Plus Jakarta Sans', sans-serif" font-size="12.5" font-weight="800" fill="#ffffff">Dalam Kerja: 6h 7m</text>
          <text x="214" y="23" font-family="sans-serif" font-size="13" font-weight="900" fill="#a7f3d0">›</text>
        </g>

        <!-- SHUTTER CONTROLS ROW -->
        <g transform="translate(36, 72)">
          <!-- Galeri -->
          <rect x="12" y="6" width="54" height="54" rx="14" fill="#1e293b" stroke="rgba(255,255,255,0.15)" stroke-width="1.5" />
          <text x="39" y="39" text-anchor="middle" font-size="24">🖼️</text>
          <text x="39" y="74" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="600" fill="#94a3b8">Galeri</text>

          <!-- DYNAMIC SHUTTER: BIRU "PULANG" -->
          <g transform="translate(126, 0)" filter="url(#glowBlue)">
            <rect x="0" y="0" width="256" height="66" rx="33" fill="url(#blueShutter)" stroke="#ffffff" stroke-width="2.5" />
            <circle cx="36" cy="33" r="18" fill="rgba(255,255,255,0.2)" />
            <path d="M42 33 L32 33 M37 27 L43 33 L37 39" fill="none" stroke="#ffffff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" />
            <text x="74" y="40" font-family="'Plus Jakarta Sans', sans-serif" font-size="17" font-weight="900" fill="#ffffff" letter-spacing="1">PULANG</text>
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

  <!-- ================= SCREEN 3: LEMBAR WAKTU SAYA (TIMESHEET) ================= -->
  <g transform="translate(1440, 150)">
    <!-- Section Label Tag -->
    <rect x="10" y="0" width="230" height="34" rx="10" fill="#7c3aed" fill-opacity="0.3" stroke="#a855f7" stroke-width="1.5" />
    <circle cx="28" cy="17" r="5" fill="#c084fc" />
    <text x="42" y="22" font-family="'Plus Jakarta Sans', sans-serif" font-size="13" font-weight="800" fill="#e9d5ff">3. LEMBAR WAKTU SAYA (SHEET)</text>

    <!-- Phone Frame -->
    <g transform="translate(0, 48)" filter="url(#shadow)">
      <rect x="0" y="0" width="580" height="980" rx="36" fill="#020617" stroke="#334155" stroke-width="3.5" />

      <!-- Status Bar -->
      <text x="36" y="34" font-family="-apple-system, sans-serif" font-size="13" font-weight="700" fill="#ffffff">17:35</text>
      <g transform="translate(480, 22)">
        <path d="M0 12 L8 4 L16 12 Z" fill="#ffffff" />
        <rect x="22" y="3" width="22" height="11" rx="3" fill="none" stroke="#ffffff" stroke-width="1.5" />
        <rect x="24" y="5" width="14" height="7" rx="1.5" fill="#ffffff" />
      </g>

      <!-- App Bar -->
      <g transform="translate(24, 52)">
        <circle cx="20" cy="20" r="18" fill="rgba(255,255,255,0.08)" />
        <path d="M23 13 L16 20 L23 27" stroke="#ffffff" stroke-width="2.5" fill="none" stroke-linecap="round" stroke-linejoin="round" />
        <text x="56" y="26" font-family="'Plus Jakarta Sans', sans-serif" font-size="18" font-weight="800" fill="#ffffff">Lembar Waktu Saya</text>
        <rect x="420" y="6" width="100" height="28" rx="14" fill="#1e40af" fill-opacity="0.3" stroke="#3b82f6" stroke-width="1" />
        <text x="470" y="24" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="700" fill="#60a5fa">Bulan Ini ▾</text>
      </g>

      <!-- Summary KPI Cards Row -->
      <g transform="translate(24, 114)">
        <rect x="0" y="0" width="254" height="68" rx="14" fill="#0f172a" stroke="#1e293b" stroke-width="1.2" />
        <text x="16" y="24" font-family="sans-serif" font-size="11" font-weight="600" fill="#94a3b8">Total Kehadiran</text>
        <text x="16" y="52" font-family="'Plus Jakarta Sans', sans-serif" font-size="22" font-weight="900" fill="#10b981">24 Hari</text>
        <text x="110" y="50" font-family="sans-serif" font-size="11" font-weight="700" fill="#34d399">100% On-Time</text>

        <rect x="274" y="0" width="254" height="68" rx="14" fill="#0f172a" stroke="#1e293b" stroke-width="1.2" />
        <text x="290" y="24" font-family="sans-serif" font-size="11" font-weight="600" fill="#94a3b8">Total Jam Kerja</text>
        <text x="290" y="52" font-family="'Plus Jakarta Sans', sans-serif" font-size="22" font-weight="900" fill="#38bdf8">192.5 Jam</text>
        <text x="430" y="50" font-family="sans-serif" font-size="11" font-weight="700" fill="#60a5fa">Rata 8.0h</text>
      </g>

      <!-- TABLE CONTAINER -->
      <g transform="translate(24, 198)">
        <rect x="0" y="0" width="532" height="570" rx="16" fill="#0b1329" stroke="#1e293b" stroke-width="1.2" />

        <!-- Table Header -->
        <rect x="0" y="0" width="532" height="42" rx="16" fill="#15213b" />
        <rect x="0" y="32" width="532" height="10" fill="#15213b" />
        <line x1="0" y1="42" x2="532" y2="42" stroke="#334155" stroke-width="1" />
        
        <text x="24" y="26" font-family="sans-serif" font-size="11.5" font-weight="800" fill="#94a3b8">FOTO</text>
        <text x="100" y="26" font-family="sans-serif" font-size="11.5" font-weight="800" fill="#94a3b8">STATUS</text>
        <text x="210" y="26" font-family="sans-serif" font-size="11.5" font-weight="800" fill="#94a3b8">WAKTU</text>
        <text x="310" y="26" font-family="sans-serif" font-size="11.5" font-weight="800" fill="#94a3b8">TANGGAL</text>
        <text x="420" y="26" font-family="sans-serif" font-size="11.5" font-weight="800" fill="#94a3b8">LOKASI</text>

        <!-- ROW 1 (Pulang Hari Ini) -->
        <g transform="translate(0, 44)">
          <rect x="14" y="12" width="60" height="74" rx="8" fill="#1e293b" stroke="rgba(255,255,255,0.1)" />
          <text x="44" y="54" text-anchor="middle" font-size="22">📸</text>
          
          <rect x="94" y="36" width="76" height="26" rx="6" fill="#2563eb" />
          <text x="132" y="53" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="800" fill="#ffffff">Pulang</text>

          <text x="210" y="46" class="mono-time" font-size="14" fill="#ffffff">17:30</text>
          <text x="210" y="64" font-family="sans-serif" font-size="10.5" font-weight="600" fill="#34d399">Durasi 6h 7m</text>

          <text x="310" y="46" font-family="sans-serif" font-size="12" font-weight="700" fill="#ffffff">13/09/2026</text>
          <text x="310" y="64" font-family="sans-serif" font-size="11" font-weight="500" fill="#94a3b8">Minggu</text>

          <text x="420" y="46" font-family="sans-serif" font-size="12" font-weight="800" fill="#38bdf8">PKM</text>
          <text x="420" y="64" font-family="sans-serif" font-size="10.5" font-weight="500" fill="#94a3b8">Kalimas</text>
        </g>
        <line x1="14" y1="144" x2="518" y2="144" stroke="#1e293b" stroke-width="1" />

        <!-- ROW 2 (Jam Masuk Hari Ini) -->
        <g transform="translate(0, 146)">
          <rect x="14" y="12" width="60" height="74" rx="8" fill="#1e293b" stroke="rgba(255,255,255,0.1)" />
          <text x="44" y="54" text-anchor="middle" font-size="22">📸</text>
          
          <rect x="94" y="36" width="92" height="26" rx="6" fill="#10b981" />
          <text x="140" y="53" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="800" fill="#ffffff">Jam Masuk</text>

          <text x="210" y="46" class="mono-time" font-size="14" fill="#ffffff">11:23</text>
          <text x="210" y="64" font-family="sans-serif" font-size="10.5" font-weight="600" fill="#94a3b8">Shift 1</text>

          <text x="310" y="46" font-family="sans-serif" font-size="12" font-weight="700" fill="#ffffff">13/09/2026</text>
          <text x="310" y="64" font-family="sans-serif" font-size="11" font-weight="500" fill="#94a3b8">Minggu</text>

          <text x="420" y="46" font-family="sans-serif" font-size="12" font-weight="800" fill="#38bdf8">PKM</text>
          <text x="420" y="64" font-family="sans-serif" font-size="10.5" font-weight="500" fill="#94a3b8">Kalimas</text>
        </g>
        <line x1="14" y1="246" x2="518" y2="246" stroke="#1e293b" stroke-width="1" />

        <!-- ROW 3 (Pulang Kemarin) -->
        <g transform="translate(0, 248)">
          <rect x="14" y="12" width="60" height="74" rx="8" fill="#1e293b" stroke="rgba(255,255,255,0.1)" />
          <text x="44" y="54" text-anchor="middle" font-size="22">📸</text>
          
          <rect x="94" y="36" width="76" height="26" rx="6" fill="#2563eb" />
          <text x="132" y="53" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="800" fill="#ffffff">Pulang</text>

          <text x="210" y="46" class="mono-time" font-size="14" fill="#ffffff">14:02</text>
          <text x="210" y="64" font-family="sans-serif" font-size="10.5" font-weight="600" fill="#34d399">Durasi 4h 0m</text>

          <text x="310" y="46" font-family="sans-serif" font-size="12" font-weight="700" fill="#ffffff">12/09/2026</text>
          <text x="310" y="64" font-family="sans-serif" font-size="11" font-weight="500" fill="#94a3b8">Sabtu</text>

          <text x="420" y="46" font-family="sans-serif" font-size="12" font-weight="800" fill="#f59e0b">PBM</text>
          <text x="420" y="64" font-family="sans-serif" font-size="10.5" font-weight="500" fill="#94a3b8">Bersehati</text>
        </g>
        <line x1="14" y1="348" x2="518" y2="348" stroke="#1e293b" stroke-width="1" />

        <!-- ROW 4 (Jam Masuk Kemarin) -->
        <g transform="translate(0, 350)">
          <rect x="14" y="12" width="60" height="74" rx="8" fill="#1e293b" stroke="rgba(255,255,255,0.1)" />
          <text x="44" y="54" text-anchor="middle" font-size="22">📸</text>
          
          <rect x="94" y="36" width="92" height="26" rx="6" fill="#10b981" />
          <text x="140" y="53" text-anchor="middle" font-family="sans-serif" font-size="11" font-weight="800" fill="#ffffff">Jam Masuk</text>

          <text x="210" y="46" class="mono-time" font-size="14" fill="#ffffff">10:00</text>
          <text x="210" y="64" font-family="sans-serif" font-size="10.5" font-weight="600" fill="#94a3b8">Shift 2.2</text>

          <text x="310" y="46" font-family="sans-serif" font-size="12" font-weight="700" fill="#ffffff">12/09/2026</text>
          <text x="310" y="64" font-family="sans-serif" font-size="11" font-weight="500" fill="#94a3b8">Sabtu</text>

          <text x="420" y="46" font-family="sans-serif" font-size="12" font-weight="800" fill="#f59e0b">PBM</text>
          <text x="420" y="64" font-family="sans-serif" font-size="10.5" font-weight="500" fill="#94a3b8">Bersehati</text>
        </g>

        <!-- Retention Disclaimer Banner -->
        <g transform="translate(0, 526)">
          <rect x="0" y="0" width="532" height="44" rx="14" fill="#0f172a" />
          <text x="266" y="27" text-anchor="middle" font-family="sans-serif" font-size="12" font-weight="600" fill="#64748b">🛡️ Hanya 45 hari terakhir dari catatan yang disimpan otomatis.</text>
        </g>
      </g>

      <!-- BOTTOM ACTION BAR: EXPORT & DELETE -->
      <g transform="translate(24, 792)">
        <rect x="0" y="0" width="532" height="150" rx="20" fill="#0f172a" stroke="#1e293b" stroke-width="1.2" />

        <!-- Button 1: Bagikan / Export Sheets (CSV) -->
        <g transform="translate(20, 20)">
          <rect x="0" y="0" width="492" height="52" rx="14" fill="#10b981" />
          <text x="180" y="32" font-size="18">📊</text>
          <text x="210" y="32" font-family="'Plus Jakarta Sans', sans-serif" font-size="14.5" font-weight="800" fill="#ffffff">Bagikan / Export ke Sheets (CSV)</text>
        </g>

        <!-- Button 2: Hapus & Sinkron -->
        <g transform="translate(20, 84)">
          <rect x="0" y="0" width="236" height="46" rx="12" fill="#1e293b" stroke="#334155" stroke-width="1" />
          <text x="70" y="28" font-size="15">🔄</text>
          <text x="96" y="28" font-family="sans-serif" font-size="12.5" font-weight="700" fill="#94a3b8">Refresh Data</text>

          <rect x="256" y="0" width="236" height="46" rx="12" fill="#450a0a" stroke="#991b1b" stroke-width="1" />
          <text x="326" y="28" font-size="15">🗑️</text>
          <text x="352" y="28" font-family="sans-serif" font-size="12.5" font-weight="700" fill="#fca5a5">Hapus Riwayat</text>
        </g>
      </g>
    </g>
  </g>

  <!-- BOTTOM FOOTER -->
  <g transform="translate(80, 1200)">
    <line x1="0" y1="0" x2="1940" y2="0" stroke="#1e293b" stroke-width="1.5" />
    <text x="0" y="32" font-family="'Plus Jakarta Sans', sans-serif" font-size="13" font-weight="700" fill="#64748b">BSS Parking Engineering Division • Timemark Architecture Mockup v2.1</text>
    <text x="1940" y="32" text-anchor="end" font-family="'Plus Jakarta Sans', sans-serif" font-size="13" font-weight="800" fill="#3b82f6">Dual Knowledge Graph Verified (CodeGraph + Graphify)</text>
  </g>
</svg>
`;

async function main() {
  const artifactDir = '/home/annnpii/.gemini/antigravity-cli/brain/f7ccf0cd-8210-4425-98d6-40aa1457b05f';
  const outPath = path.join(artifactDir, 'bss_absensi_tracking_concept.jpg');
  const tempPath = '/tmp/bss_absensi_tracking_concept.jpg';

  console.log('Rendering concept mockup image...');
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
