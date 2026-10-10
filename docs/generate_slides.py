import base64
import os
import subprocess
import io
from PIL import Image

def get_base64_png(path, max_dim=None):
    im = Image.open(path)
    if im.mode != 'RGBA':
        im = im.convert('RGBA')
    if max_dim:
        im.thumbnail((max_dim, max_dim), Image.Resampling.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, format='PNG')
    return base64.b64encode(buf.getvalue()).decode('utf-8')

# 1. Logos
logo_round_b64 = get_base64_png('foto/splash_logo.png', max_dim=220)
with open('foto/bssfotologo_transparent.png', 'rb') as f:
    logo_white_text_b64 = base64.b64encode(f.read()).decode('utf-8')

# 2. Real Screenshots captured from live PWA https://bssparking-pma.vercel.app/
ss_login_b64 = get_base64_png('docs/screenshots/test_exact_typed.png', max_dim=780)
ss_camera_b64 = get_base64_png('docs/screenshots/tek_camera_viewfinder.png', max_dim=780)
ss_shift_b64 = get_base64_png('docs/screenshots/tek_shift_selector.png', max_dim=780)
ss_sop_picker_b64 = get_base64_png('docs/screenshots/tek_sop_picker.png', max_dim=780)
ss_sop_active_b64 = get_base64_png('docs/screenshots/tek_sop_active.png', max_dim=780)
ss_tek_drawer_b64 = get_base64_png('docs/screenshots/tek_drawer_clean.png', max_dim=780)
ss_tek_daily_b64 = get_base64_png('docs/screenshots/tek_daily_task_real.png', max_dim=780)
ss_spv_drawer_b64 = get_base64_png('docs/screenshots/spv_drawer.png', max_dim=780)
ss_spv_dispatch_b64 = get_base64_png('docs/screenshots/spv_task_dispatcher.png', max_dim=780)
ss_spv_status_b64 = get_base64_png('docs/screenshots/spv_status_tim.png', max_dim=780)

html_content = f"""<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>PMAapp — Panduan Operasional & Fitur Aplikasi</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800;900&display=swap');

  @page {{
    size: 297mm 210mm;
    margin: 0;
  }}

  * {{
    box-sizing: border-box;
    margin: 0;
    padding: 0;
  }}

  body {{
    font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
    color: #0F172A;
    background-color: #CBD5E1;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }}

  .slide {{
    width: 297mm;
    height: 210mm;
    page-break-after: always;
    page-break-inside: avoid;
    position: relative;
    overflow: hidden;
    background: #FFFFFF;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    padding: 13mm 18mm 10mm 18mm;
  }}

  /* Theme: Dark Navy */
  .slide.dark-navy {{
    background: linear-gradient(135deg, #071224 0%, #0F2C59 55%, #163E7A 100%);
    color: #FFFFFF;
  }}

  /* Theme: Clean White with subtle gradient */
  .slide.light {{
    background: linear-gradient(180deg, #F8FAFC 0%, #F1F5F9 100%);
    color: #0F172A;
  }}

  /* Slide Header */
  .slide-header {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1.8px solid #E2E8F0;
    padding-bottom: 3mm;
    margin-bottom: 3.5mm;
  }}

  .dark-navy .slide-header {{
    border-bottom: 1.8px solid rgba(255, 255, 255, 0.15);
  }}

  .header-left {{
    display: flex;
    align-items: center;
    gap: 12px;
  }}

  .header-tag {{
    font-size: 10px;
    font-weight: 800;
    letter-spacing: 0.8px;
    text-transform: uppercase;
    padding: 3.5px 9px;
    border-radius: 6px;
    background: #0F2C59;
    color: #FFFFFF;
    white-space: nowrap;
  }}

  .header-tag.spv {{
    background: #FF6500;
  }}

  .header-tag.sop {{
    background: #0F2C59;
  }}

  .header-title-box h1 {{
    font-size: 19px;
    font-weight: 800;
    color: #0F2C59;
    line-height: 1.2;
    letter-spacing: -0.3px;
  }}

  .dark-navy .header-title-box h1 {{
    color: #FFFFFF;
  }}

  .header-title-box p {{
    font-size: 11px;
    color: #64748B;
    font-weight: 600;
    margin-top: 1.5px;
  }}

  .dark-navy .header-title-box p {{
    color: #94A3B8;
  }}

  .header-right {{
    display: flex;
    align-items: center;
    gap: 10px;
  }}

  .header-brand-badge {{
    display: flex;
    align-items: center;
    gap: 7px;
    background: #FFFFFF;
    border: 1.5px solid #CBD5E1;
    border-radius: 20px;
    padding: 3px 10px 3px 5px;
    box-shadow: 0 2px 5px rgba(0, 0, 0, 0.04);
  }}

  .header-brand-badge img {{
    width: 22px;
    height: 22px;
    border-radius: 50%;
  }}

  .header-brand-badge span {{
    font-size: 10.5px;
    font-weight: 800;
    color: #0F2C59;
    letter-spacing: 0.5px;
  }}

  .dark-navy .header-logo {{
    height: 32px;
    object-fit: contain;
  }}

  /* Main Slide Content Grid */
  .slide-body {{
    flex: 1;
    display: grid;
    grid-template-columns: 1.28fr 0.92fr;
    gap: 18px;
    align-items: center;
    min-height: 0;
  }}

  /* Content Cards Column */
  .content-col {{
    display: flex;
    flex-direction: column;
    gap: 7px;
    justify-content: center;
  }}

  .intro-text {{
    font-size: 11.5px;
    color: #334155;
    line-height: 1.45;
    margin-bottom: 2px;
    font-weight: 500;
  }}

  .dark-navy .intro-text {{
    color: #E2E8F0;
  }}

  .callout-card {{
    background: #FFFFFF;
    border: 1.5px solid #E2E8F0;
    border-radius: 10px;
    padding: 7.5px 12px;
    display: flex;
    align-items: flex-start;
    gap: 10px;
    box-shadow: 0 2px 7px rgba(15, 44, 89, 0.04);
  }}

  .callout-badge {{
    width: 23px;
    height: 23px;
    border-radius: 50%;
    background: #FF6500;
    color: #FFFFFF;
    font-weight: 800;
    font-size: 11.5px;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    box-shadow: 0 2px 5px rgba(255, 101, 0, 0.3);
    margin-top: 1px;
  }}

  .callout-badge.blue {{
    background: #0F2C59;
    box-shadow: 0 2px 5px rgba(15, 44, 89, 0.3);
  }}

  .callout-content {{
    flex: 1;
  }}

  .callout-content h3 {{
    font-size: 12.5px;
    font-weight: 800;
    color: #0F2C59;
    margin-bottom: 2px;
    display: flex;
    align-items: center;
    justify-content: space-between;
  }}

  .callout-content .step-action {{
    font-size: 10.5px;
    color: #334155;
    line-height: 1.4;
    font-weight: 500;
  }}

  .callout-content .step-action b {{
    color: #0F2C59;
    font-weight: 700;
  }}

  .callout-content .step-result {{
    font-size: 10px;
    color: #64748B;
    line-height: 1.35;
    margin-top: 1.5px;
    font-weight: 500;
  }}

  .callout-content .step-result b {{
    color: #475569;
    font-weight: 700;
  }}

  .badge-pill {{
    display: inline-block;
    font-size: 9px;
    font-weight: 700;
    padding: 1.5px 6px;
    border-radius: 8px;
    background: #E2E8F0;
    color: #0F2C59;
    vertical-align: middle;
  }}

  .badge-pill.orange {{
    background: #FFEDD5;
    color: #C2410C;
  }}

  .badge-pill.green {{
    background: #DCFCE7;
    color: #15803D;
  }}

  .badge-pill.blue {{
    background: #E0E7FF;
    color: #3730A3;
  }}

  /* Tip / Troubleshooting Box at bottom of content column */
  .tip-box {{
    background: #FFF7ED;
    border: 1px solid #FED7AA;
    border-left: 3.5px solid #FF6500;
    border-radius: 8px;
    padding: 6px 10px;
    font-size: 10px;
    color: #9A3412;
    line-height: 1.35;
    margin-top: 2px;
  }}

  .tip-box.blue {{
    background: #EFF6FF;
    border: 1px solid #BFDBFE;
    border-left: 3.5px solid #0F2C59;
    color: #1E3A8A;
  }}

  .tip-box b {{
    font-weight: 700;
  }}

  /* Phone Mockup Column */
  .phone-col {{
    display: flex;
    justify-content: center;
    align-items: center;
    height: 100%;
  }}

  .phone-frame {{
    position: relative;
    width: 236px;
    height: 506px;
    background: #0A0F1D;
    border-radius: 36px;
    padding: 5px;
    box-shadow: 0 18px 40px rgba(15, 44, 89, 0.25), 0 2px 10px rgba(0, 0, 0, 0.16);
    border: 3.5px solid #1E293B;
  }}

  /* Subtle speaker bar on outer bezel */
  .phone-speaker {{
    position: absolute;
    top: 2px;
    left: 50%;
    transform: translateX(-50%);
    width: 42px;
    height: 3px;
    background: #334155;
    border-radius: 2px;
    z-index: 25;
  }}

  .phone-screen {{
    position: relative;
    width: 100%;
    height: 100%;
    border-radius: 28px;
    overflow: hidden;
    background: #000000;
  }}

  .phone-screen img {{
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }}

  /* Floating Pointer Badges on Screenshot */
  .pin {{
    position: absolute;
    width: 22px;
    height: 22px;
    border-radius: 50%;
    background: #FF6500;
    color: #FFFFFF;
    font-weight: 900;
    font-size: 11px;
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: 0 0 0 2.2px #FFFFFF, 0 3px 8px rgba(0, 0, 0, 0.5);
    transform: translate(-50%, -50%);
    z-index: 20;
  }}

  .pin.blue {{
    background: #0F2C59;
  }}

  /* Slide Footer */
  .slide-footer {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-top: 1.5px solid #E2E8F0;
    padding-top: 2.5mm;
    margin-top: 1.5mm;
    font-size: 10px;
    color: #64748B;
    font-weight: 600;
  }}

  .dark-navy .slide-footer {{
    border-top: 1.5px solid rgba(255, 255, 255, 0.15);
    color: #94A3B8;
  }}

  .footer-left {{
    display: flex;
    align-items: center;
    gap: 7px;
  }}

  .footer-brand {{
    color: #0F2C59;
    font-weight: 800;
  }}

  .dark-navy .footer-brand {{
    color: #FFFFFF;
  }}

  .footer-love {{
    font-weight: 700;
    color: #FF6500;
  }}

  .slide-num {{
    background: #E2E8F0;
    color: #0F2C59;
    padding: 2.5px 9px;
    border-radius: 10px;
    font-weight: 800;
    font-size: 10px;
  }}

  .dark-navy .slide-num {{
    background: rgba(255, 255, 255, 0.2);
    color: #FFFFFF;
  }}

  /* Cover Slide Styles */
  .cover-grid {{
    flex: 1;
    display: grid;
    grid-template-columns: 1.25fr 0.75fr;
    gap: 25px;
    align-items: center;
  }}

  .cover-logo-box {{
    display: flex;
    align-items: center;
    gap: 16px;
    margin-bottom: 20px;
  }}

  .cover-logo-circle {{
    width: 82px;
    height: 82px;
    border-radius: 50%;
    background: #FFFFFF;
    padding: 4px;
    border: 3px solid #FF6500;
    box-shadow: 0 8px 22px rgba(255, 101, 0, 0.35);
  }}

  .cover-logo-circle img {{
    width: 100%;
    height: 100%;
    border-radius: 50%;
    object-fit: cover;
  }}

  .cover-badge {{
    display: inline-block;
    padding: 5px 12px;
    background: rgba(255, 255, 255, 0.15);
    border: 1px solid rgba(255, 255, 255, 0.3);
    border-radius: 16px;
    font-size: 11px;
    font-weight: 800;
    letter-spacing: 1.2px;
    text-transform: uppercase;
    color: #F8FAFC;
    margin-bottom: 10px;
  }}

  .cover-title {{
    font-size: 38px;
    font-weight: 900;
    line-height: 1.15;
    color: #FFFFFF;
    letter-spacing: -0.5px;
    margin-bottom: 10px;
  }}

  .cover-title span {{
    color: #FF6500;
  }}

  .cover-subtitle {{
    font-size: 14.5px;
    color: #CBD5E1;
    font-weight: 500;
    line-height: 1.5;
    margin-bottom: 18px;
  }}

  .cover-pillars {{
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 10px;
    margin-bottom: 14px;
  }}

  .pillar-card {{
    background: rgba(255, 255, 255, 0.08);
    border: 1px solid rgba(255, 255, 255, 0.15);
    border-radius: 10px;
    padding: 10px;
  }}

  .pillar-card h4 {{
    font-size: 12px;
    font-weight: 800;
    color: #FFFFFF;
    margin-bottom: 3px;
  }}

  .pillar-card p {{
    font-size: 10px;
    color: #94A3B8;
    line-height: 1.35;
  }}

  .cover-meta {{
    display: flex;
    gap: 14px;
    background: rgba(0, 0, 0, 0.25);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 8px;
    padding: 8px 12px;
    font-size: 10.5px;
    color: #CBD5E1;
  }}

  .cover-meta span b {{
    color: #FFFFFF;
  }}

  /* Diagram Flow Slide 12 */
  .flow-container {{
    display: flex;
    flex-direction: column;
    gap: 10px;
    width: 100%;
  }}

  .flow-row {{
    display: grid;
    grid-template-columns: repeat(5, 1fr);
    gap: 10px;
  }}

  .flow-card {{
    background: #FFFFFF;
    border: 1.5px solid #CBD5E1;
    border-radius: 10px;
    padding: 10px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    box-shadow: 0 3px 8px rgba(15, 44, 89, 0.04);
  }}

  .flow-card.accent {{
    border-color: #FF6500;
    background: #FFF7ED;
  }}

  .flow-num {{
    width: 22px;
    height: 22px;
    border-radius: 50%;
    background: #0F2C59;
    color: #FFFFFF;
    font-size: 11px;
    font-weight: 800;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-bottom: 6px;
  }}

  .flow-card.accent .flow-num {{
    background: #FF6500;
  }}

  .flow-card h4 {{
    font-size: 11.5px;
    font-weight: 800;
    color: #0F2C59;
    margin-bottom: 3px;
  }}

  .flow-card p {{
    font-size: 9.8px;
    color: #475569;
    line-height: 1.35;
  }}
</style>
</head>
<body>

<!-- ====================================================================== -->
<!-- SLIDE 1: COVER & PENGENALAN PMAapp -->
<!-- ====================================================================== -->
<div class="slide dark-navy">
  <div class="slide-header">
    <div class="header-left">
      <span class="header-tag">Buku Panduan Operasional</span>
      <span style="font-size: 11px; color: #94A3B8; font-weight: 700;">Dokumen Resmi: SOP-PMA-BSS-2026-v2.4 • Revisi: Oktober 2026</span>
    </div>
    <img src="data:image/png;base64,{logo_white_text_b64}" class="header-logo" alt="BSS Parking" />
  </div>

  <div class="cover-grid">
    <div>
      <div class="cover-logo-box">
        <div class="cover-logo-circle">
          <img src="data:image/png;base64,{logo_round_b64}" alt="PMA Logo" />
        </div>
        <div>
          <span class="cover-badge">PMAapp Platform</span>
          <h1 class="cover-title">Project Maintenance<br><span>Assembly</span></h1>
        </div>
      </div>

      <p class="cover-subtitle">
        Panduan aplikasi lapangan untuk Teknisi dan SPV: absen pakai GPS, checklist inspeksi alat parkir, tugas harian, dan pantauan tim cabang secara live.
      </p>

      <div class="cover-pillars">
        <div class="pillar-card">
          <h4>Absen Pakai GPS</h4>
          <p>Lokasi GPS dan jam WITA resmi dari jaringan, tidak bisa dimanipulasi.</p>
        </div>
        <div class="pillar-card">
          <h4>SOP Maintenance</h4>
          <p>Checklist foto untuk pos parkir, barrier gate, dispenser tiket, dan server.</p>
        </div>
        <div class="pillar-card">
          <h4>Daily Task & SPV</h4>
          <p>Bagi tugas cepat, otomatis masuk laporan pulang, dan pantau progres tim secara live.</p>
        </div>
      </div>

      <div class="cover-meta">
        <span>Sasaran: <b>Teknisi Lapangan & Supervisor (SPV)</b></span>
        <span>•</span>
        <span>Lokasi Acuan: <b>KC Manado & Semua Cabang</b></span>
        <span>•</span>
        <span>Status: <b>Terverifikasi</b></span>
      </div>
    </div>

    <div class="phone-col">
      <div class="phone-frame">
        <div class="phone-speaker"></div>
        <div class="phone-screen">
          <img src="data:image/png;base64,{ss_login_b64}" alt="Login Screen" />
        </div>
      </div>
    </div>
  </div>

  <div class="slide-footer">
    <div class="footer-left">
      <span class="footer-brand">PMAapp</span>
      <span>•</span>
      <span>Sistem Manajemen Parkir & Time Mark</span>
      <span>•</span>
      <span class="footer-love">PMA App ❤️ Made by annnpii</span>
    </div>
    <span class="slide-num">Halaman 01 / 12</span>
  </div>
</div>

<!-- ====================================================================== -->
<!-- SLIDE 2: AUTENTIKASI & LOGIN -->
<!-- ====================================================================== -->
<div class="slide light">
  <div class="slide-header">
    <div class="header-left">
      <span class="header-tag">Login</span>
      <div class="header-title-box">
        <h1>Login & Hak Akses</h1>
        <p>Login aman, peran SPV atau Teknisi dikenali otomatis</p>
      </div>
    </div>
    <div class="header-brand-badge">
      <img src="data:image/png;base64,{logo_round_b64}" alt="BSS Logo" />
      <span>BSS PARKING</span>
    </div>
  </div>

  <div class="slide-body">
    <div class="content-col">
      <p class="intro-text">
        Login pakai akun resmi cabang. Aplikasi otomatis mengenali peran akun dan menampilkan menu yang sesuai:
      </p>

      <div class="callout-card">
        <div class="callout-badge">1</div>
        <div class="callout-content">
          <h3>Email / Username <span class="badge-pill blue">Akun</span></h3>
          <p class="step-action"><b>Tindakan:</b> Ketik email resmi cabang (contoh: <code>farhan@pma.com</code> untuk SPV atau <code>junifer@pma.com</code> untuk Teknisi).</p>
          <p class="step-result"><b>Hasil:</b> Sistem mengecek cabang dan peran akun.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">2</div>
        <div class="callout-content">
          <h3>Kata Sandi <span class="badge-pill">Keamanan</span></h3>
          <p class="step-action"><b>Tindakan:</b> Masukkan kata sandi. Ketuk ikon mata di sisi kanan kalau mau mengecek ketikan.</p>
          <p class="step-result"><b>Hasil:</b> Sandi tersembunyi, tidak bisa diintip orang di sekitar pos parkir.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">3</div>
        <div class="callout-content">
          <h3>Tombol Masuk <span class="badge-pill orange">Arah Otomatis</span></h3>
          <p class="step-action"><b>Tindakan:</b> Ketuk tombol oranye "Masuk".</p>
          <p class="step-result"><b>Hasil:</b> Teknisi langsung ke kamera absen, SPV ke menu pembagian tugas tim.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">4</div>
        <div class="callout-content">
          <h3>Mode Tampilan <span class="badge-pill">Kenyamanan</span></h3>
          <p class="step-action"><b>Tindakan:</b> Ketuk tombol tema di pojok kanan atas untuk ganti mode Terang atau Gelap.</p>
          <p class="step-result"><b>Hasil:</b> Tampilan menyesuaikan cahaya di pos. Mode gelap lebih hemat baterai di luar ruangan.</p>
        </div>
      </div>

      <div class="tip-box">
        💡 <b>Gagal Login:</b> Kalau muncul "Akun tidak ditemukan", cek lagi penulisan email dan pastikan ponsel terhubung internet. Untuk reset kata sandi, hubungi SPV atau Koordinator IT cabang.
      </div>
    </div>

    <div class="phone-col">
      <div class="phone-frame">
        <div class="phone-speaker"></div>
        <div class="phone-screen">
          <img src="data:image/png;base64,{ss_login_b64}" alt="Login Real Screen" />
          <div class="pin" style="top: 50.8%; left: 88%;">1</div>
          <div class="pin" style="top: 61.2%; left: 88%;">2</div>
          <div class="pin" style="top: 70.0%; left: 88%;">3</div>
          <div class="pin" style="top: 3.8%; left: 70%;">4</div>
        </div>
      </div>
    </div>
  </div>

  <div class="slide-footer">
    <div class="footer-left">
      <span class="footer-brand">PMAapp</span>
      <span>•</span>
      <span>Login & Autentikasi</span>
      <span>•</span>
      <span class="footer-love">PMA App ❤️ Made by annnpii</span>
    </div>
    <span class="slide-num">Halaman 02 / 12</span>
  </div>
</div>

<!-- ====================================================================== -->
<!-- SLIDE 3: KAMERA VIEWFINDER & GEOTAGGING -->
<!-- ====================================================================== -->
<div class="slide light">
  <div class="slide-header">
    <div class="header-left">
      <span class="header-tag">Kamera Utama</span>
      <div class="header-title-box">
        <h1>Kamera & Geotagging</h1>
        <p>Foto bukti absen dan inspeksi, otomatis dicap lokasi GPS dan jam WITA</p>
      </div>
    </div>
    <div class="header-brand-badge">
      <img src="data:image/png;base64,{logo_round_b64}" alt="BSS Logo" />
      <span>BSS PARKING</span>
    </div>
  </div>

  <div class="slide-body">
    <div class="content-col">
      <p class="intro-text">
        Kamera adalah fitur utama teknisi. Setiap foto otomatis dicap lokasi dan jam resmi yang tidak bisa diubah:
      </p>

      <div class="callout-card">
        <div class="callout-badge">1</div>
        <div class="callout-content">
          <h3>Menu Samping (☰) <span class="badge-pill blue">Navigasi</span></h3>
          <p class="step-action"><b>Tindakan:</b> Ketuk ikon tiga garis di pojok kiri atas.</p>
          <p class="step-result"><b>Hasil:</b> Buka menu samping: Daily Task, riwayat maintenance, arsip absen 30 hari, dan panduan PWA.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">2</div>
        <div class="callout-content">
          <h3>Rasio & Timer Kamera <span class="badge-pill">Komposisi</span></h3>
          <p class="step-action"><b>Tindakan:</b> Pilih rasio 3:4 untuk framing standar pos. Pakai timer hitung mundur untuk selfie berseragam.</p>
          <p class="step-result"><b>Hasil:</b> Foto rapi dan tidak goyang saat tombol shutter ditekan.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">3</div>
        <div class="callout-content">
          <h3>Status Shift <span class="badge-pill green">Status Aktif</span></h3>
          <p class="step-action"><b>Tindakan:</b> Ketuk label status di bagian bawah (contoh: <code>Masuk : Shift 3</code>) kalau perlu ganti shift.</p>
          <p class="step-result"><b>Hasil:</b> Buka form shift untuk ganti shift atau absen pulang.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">4</div>
        <div class="callout-content">
          <h3>Tombol Shutter <span class="badge-pill orange">Ambil Foto</span></h3>
          <p class="step-action"><b>Tindakan:</b> Arahkan kamera ke objek atau wajah berseragam, lalu ketuk tombol lingkaran oranye besar.</p>
          <p class="step-result"><b>Hasil:</b> Foto otomatis dicap koordinat GPS dan jam WITA.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">5</div>
        <div class="callout-content">
          <h3>Pintasan Katalog SOP <span class="badge-pill">Pintasan</span></h3>
          <p class="step-action"><b>Tindakan:</b> Ketuk ikon lembar dokumen di pojok kanan bawah layar kamera.</p>
          <p class="step-result"><b>Hasil:</b> Buka daftar template inspeksi tanpa keluar dari kamera.</p>
        </div>
      </div>

      <div class="tip-box blue">
        💡 <b>Izin Lokasi & Kamera:</b> Pastikan izin kamera dan lokasi (GPS) di browser ponsel diatur ke <b>Izinkan (Allow)</b>. Jam foto diambil dari server jaringan NTP, jadi tidak terpengaruh jam ponsel.
      </div>
    </div>

    <div class="phone-col">
      <div class="phone-frame">
        <div class="phone-speaker"></div>
        <div class="phone-screen">
          <img src="data:image/png;base64,{ss_camera_b64}" alt="Camera Viewfinder" />
          <div class="pin" style="top: 4.5%; left: 8.5%;">1</div>
          <div class="pin" style="top: 4.5%; left: 35.0%;">2</div>
          <div class="pin" style="top: 84.5%; left: 75.0%;">3</div>
          <div class="pin" style="top: 92.5%; left: 50.0%;">4</div>
          <div class="pin" style="top: 92.5%; left: 87.0%;">5</div>
        </div>
      </div>
    </div>
  </div>

  <div class="slide-footer">
    <div class="footer-left">
      <span class="footer-brand">PMAapp</span>
      <span>•</span>
      <span>Kamera & Geotagging Absen</span>
      <span>•</span>
      <span class="footer-love">PMA App ❤️ Made by annnpii</span>
    </div>
    <span class="slide-num">Halaman 03 / 12</span>
  </div>
</div>

<!-- ====================================================================== -->
<!-- SLIDE 4: ATUR SHIFT KERJA & STATUS ABSENSI -->
<!-- ====================================================================== -->
<div class="slide light">
  <div class="slide-header">
    <div class="header-left">
      <span class="header-tag">Pengaturan Shift</span>
      <div class="header-title-box">
        <h1>Pengaturan Shift</h1>
        <p>Pilih shift dan syarat jam kerja minimal sebelum absen pulang</p>
      </div>
    </div>
    <div class="header-brand-badge">
      <img src="data:image/png;base64,{logo_round_b64}" alt="BSS Logo" />
      <span>BSS PARKING</span>
    </div>
  </div>

  <div class="slide-body">
    <div class="content-col">
      <p class="intro-text">
        Form shift memastikan jam kerja tercatat sesuai jadwal resmi cabang BSS Parking:
      </p>

      <div class="callout-card">
        <div class="callout-badge">1</div>
        <div class="callout-content">
          <h3>Nama Petugas <span class="badge-pill blue">Cek Profil</span></h3>
          <p class="step-action"><b>Tindakan:</b> Cek nama teknisi yang tampil (contoh: <b>Junifer Manua</b>).</p>
          <p class="step-result"><b>Hasil:</b> Nama tercetak di cap foto dan rekap absen cabang.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">2</div>
        <div class="callout-content">
          <h3>Lokasi Tugas <span class="badge-pill">Posisi Kerja</span></h3>
          <p class="step-action"><b>Tindakan:</b> Pastikan lokasi sesuai pos jaga (contoh: <b>PBM - Pasar Bersehati Manado</b>).</p>
          <p class="step-result"><b>Hasil:</b> Sistem mengecek lokasi pos teknisi.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">3</div>
        <div class="callout-content">
          <h3>Pilihan Shift BSS <span class="badge-pill green">Jam Kerja</span></h3>
          <p class="step-action"><b>Tindakan:</b> Pilih shift hari ini:</p>
          <p class="step-action" style="margin-top: 2px;">
            • <b>Shift 1 (03:00 - 11:00 WITA)</b>: Pagi (8 Jam)<br>
            • <b>Shift 2 (10:00 - 18:00 WITA)</b>: Siang (8 Jam)<br>
            • <b>Shift 2.2 (10:00 - 14:00 WITA)</b>: Paruh Waktu (4 Jam)<br>
            • <b>Shift 3 (14:00 - 22:00 WITA)</b>: Sore-Malam (8 Jam)
          </p>
          <p class="step-result"><b>Hasil:</b> Shift terkunci. Telat dihitung dari jam mulai shift.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">4</div>
        <div class="callout-content">
          <h3>Jenis Shift (Masuk atau Pulang) <span class="badge-pill orange">Status</span></h3>
          <p class="step-action"><b>Tindakan:</b> Pilih <b>Masuk</b> saat mulai kerja, atau <b>Pulang</b> saat selesai.</p>
          <p class="step-result"><b>Hasil:</b> Setelah disimpan, kamera siap untuk foto masuk atau pulang.</p>
        </div>
      </div>

      <div class="tip-box">
        💡 <b>Jam Kerja Minimal:</b> Absen pulang baru bisa diproses setelah jam kerja minimal terpenuhi (8 jam untuk Shift 1, 2, 3; 4 jam untuk Shift 2.2). Telat masuk tercatat otomatis kalau check-in lewat jam mulai shift.
      </div>
    </div>

    <div class="phone-col">
      <div class="phone-frame">
        <div class="phone-speaker"></div>
        <div class="phone-screen">
          <img src="data:image/png;base64,{ss_shift_b64}" alt="Shift Selector Screen" />
          <div class="pin" style="top: 24.5%; left: 85%;">1</div>
          <div class="pin" style="top: 32.5%; left: 88%;">2</div>
          <div class="pin" style="top: 50.0%; left: 82%;">3</div>
          <div class="pin" style="top: 78.5%; left: 82%;">4</div>
        </div>
      </div>
    </div>
  </div>

  <div class="slide-footer">
    <div class="footer-left">
      <span class="footer-brand">PMAapp</span>
      <span>•</span>
      <span>Pengaturan Shift & Status Absen</span>
      <span>•</span>
      <span class="footer-love">PMA App ❤️ Made by annnpii</span>
    </div>
    <span class="slide-num">Halaman 04 / 12</span>
  </div>
</div>

<!-- ====================================================================== -->
<!-- SLIDE 5: KATALOG TEMPLATE SOP MAINTENANCE -->
<!-- ====================================================================== -->
<div class="slide light">
  <div class="slide-header">
    <div class="header-left">
      <span class="header-tag">Katalog SOP</span>
      <div class="header-title-box">
        <h1>Katalog Template SOP Hardware</h1>
        <p>Titik inspeksi alat parkir dan jumlah foto wajib tiap titik</p>
      </div>
    </div>
    <div class="header-brand-badge">
      <img src="data:image/png;base64,{logo_round_b64}" alt="BSS Logo" />
      <span>BSS PARKING</span>
    </div>
  </div>

  <div class="slide-body">
    <div class="content-col">
      <p class="intro-text">
        Tiap kategori hardware punya jumlah foto wajib sendiri. Ketuk kartu untuk mulai mengatur unit yang diperiksa:
      </p>

      <div class="callout-card">
        <div class="callout-badge">1</div>
        <div class="callout-content">
          <h3>SOP Absen Masuk & Pulang <span class="badge-pill green">Absen</span></h3>
          <p class="step-action"><b>Tindakan:</b> Foto absen berseragam BSS Parking di pos jaga.</p>
          <p class="step-result"><b>Hasil:</b> Foto dicek lewat jam WITA dan radius lokasi tugas.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">2</div>
        <div class="callout-content">
          <h3>Perawatan Pos Parkir <span class="badge-pill orange">9 Foto Wajib</span></h3>
          <p class="step-action"><b>Tindakan:</b> Cek kebersihan pos, kabel power, stop kontak, kebersihan meja kerja, dan kondisi fisik pos.</p>
          <p class="step-result"><b>Hasil:</b> 1 titik = 1 foto, supaya pos selalu siap pakai.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">3</div>
        <div class="callout-content">
          <h3>Perawatan Barrier Gate <span class="badge-pill orange">9 Foto Wajib</span></h3>
          <p class="step-action"><b>Tindakan:</b> Cek motor barrier, pegas palang, sensor loop kendaraan, arm karet, CCTV gate, dan panel kabel.</p>
          <p class="step-result"><b>Hasil:</b> Palang tidak macet saat jam sibuk.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">4</div>
        <div class="callout-content">
          <h3>Perawatan Manless & Pulau Gate <span class="badge-pill orange">8 Foto Wajib</span></h3>
          <p class="step-action"><b>Tindakan:</b> Cek dispenser tiket otomatis, printer thermal, reader RFID, intercom, dan tombol tiket.</p>
          <p class="step-result"><b>Hasil:</b> Mesin tiket mandiri siap melayani pengendara 24 jam.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">5</div>
        <div class="callout-content">
          <h3>Perawatan Server & Kasir <span class="badge-pill orange">6 Foto Wajib</span></h3>
          <p class="step-action"><b>Tindakan:</b> Cek komputer kasir, CPU server pusat, UPS (cadangan daya), suhu ruang kontrol, dan switch LAN.</p>
          <p class="step-result"><b>Hasil:</b> Data transaksi parkir cabang tetap aman dan stabil.</p>
        </div>
      </div>

      <div class="tip-box blue">
        💡 <b>Cara Memilih:</b> Ketuk salah satu kartu di atas untuk membuka form pengaturan unit yang akan diperiksa.
      </div>
    </div>

    <div class="phone-col">
      <div class="phone-frame">
        <div class="phone-speaker"></div>
        <div class="phone-screen">
          <img src="data:image/png;base64,{ss_sop_picker_b64}" alt="SOP Quick Picker Screen" />
          <div class="pin" style="top: 31.0%; left: 14%;">1</div>
          <div class="pin" style="top: 46.0%; left: 14%;">2</div>
          <div class="pin" style="top: 60.0%; left: 14%;">3</div>
          <div class="pin" style="top: 74.0%; left: 14%;">4</div>
          <div class="pin" style="top: 89.0%; left: 14%;">5</div>
        </div>
      </div>
    </div>
  </div>

  <div class="slide-footer">
    <div class="footer-left">
      <span class="footer-brand">PMAapp</span>
      <span>•</span>
      <span>Katalog SOP Hardware</span>
      <span>•</span>
      <span class="footer-love">PMA App ❤️ Made by annnpii</span>
    </div>
    <span class="slide-num">Halaman 05 / 12</span>
  </div>
</div>

<!-- ====================================================================== -->
<!-- SLIDE 6: KONFIGURASI SOP UNIT & TARGET FOTO -->
<!-- ====================================================================== -->
<div class="slide light">
  <div class="slide-header">
    <div class="header-left">
      <span class="header-tag">Eksekusi SOP</span>
      <div class="header-title-box">
        <h1>Pengaturan Unit & Target Foto</h1>
        <p>Pilih nomor unit, jumlah foto wajib dihitung otomatis</p>
      </div>
    </div>
    <div class="header-brand-badge">
      <img src="data:image/png;base64,{logo_round_b64}" alt="BSS Logo" />
      <span>BSS PARKING</span>
    </div>
  </div>

  <div class="slide-body">
    <div class="content-col">
      <p class="intro-text">
        Sebelum foto, pilih nomor unit yang dikerjakan. Sistem otomatis menghitung jumlah foto wajib:
      </p>

      <div class="callout-card">
        <div class="callout-badge">1</div>
        <div class="callout-content">
          <h3>Cek Modul SOP & Lokasi Pos <span class="badge-pill blue">Konfirmasi</span></h3>
          <p class="step-action"><b>Tindakan:</b> Cek judul SOP yang dipilih (contoh: <b>Manless & Pulau Gate</b>) dan lokasi pos (<b>Pasar Bersehati Manado</b>).</p>
          <p class="step-result"><b>Hasil:</b> Pastikan jenis SOP dan lokasi sudah benar sebelum mulai.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">2</div>
        <div class="callout-content">
          <h3>Rentang Nomor Unit <span class="badge-pill green">Pilih Unit</span></h3>
          <p class="step-action"><b>Tindakan:</b> Ketuk <b>[+]</b> dan <b>[-]</b> untuk memilih nomor unit awal dan akhir (contoh: Manless 1 s/d Manless 1).</p>
          <p class="step-result"><b>Hasil:</b> Unit yang dipilih tercatat di laporan.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">3</div>
        <div class="callout-content">
          <h3>Jumlah Foto Wajib <span class="badge-pill orange">Target</span></h3>
          <p class="step-action"><b>Tindakan:</b> Lihat badge hijau penghitung foto: <b>Wajib diambil: 8 Foto (1 Manless × 8 foto poin)</b>.</p>
          <p class="step-result"><b>Hasil:</b> Teknisi tahu persis berapa foto yang harus diambil.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">4</div>
        <div class="callout-content">
          <h3>Mulai Pemeriksaan <span class="badge-pill">Buka Kamera</span></h3>
          <p class="step-action"><b>Tindakan:</b> Ketuk tombol biru "Mulai Pemeriksaan" di pojok kanan bawah form.</p>
          <p class="step-result"><b>Hasil:</b> Kamera terbuka dan memandu foto tiap titik sampai jumlah wajib terpenuhi.</p>
        </div>
      </div>

      <div class="tip-box">
        💡 <b>Syarat Kirim Laporan:</b> Laporan SOP tidak bisa dikirim kalau fotonya kurang dari jumlah wajib. Foto harus alat aslinya di lapangan, bukan layar monitor atau objek lain.
      </div>
    </div>

    <div class="phone-col">
      <div class="phone-frame">
        <div class="phone-speaker"></div>
        <div class="phone-screen">
          <img src="data:image/png;base64,{ss_sop_active_b64}" alt="SOP Active Setup Screen" />
          <div class="pin" style="top: 37.0%; left: 14%;">1</div>
          <div class="pin" style="top: 57.0%; left: 88%;">2</div>
          <div class="pin" style="top: 66.0%; left: 14%;">3</div>
          <div class="pin" style="top: 76.0%; left: 88%;">4</div>
        </div>
      </div>
    </div>
  </div>

  <div class="slide-footer">
    <div class="footer-left">
      <span class="footer-brand">PMAapp</span>
      <span>•</span>
      <span>Pengaturan Unit & Target Foto SOP</span>
      <span>•</span>
      <span class="footer-love">PMA App ❤️ Made by annnpii</span>
    </div>
    <span class="slide-num">Halaman 06 / 12</span>
  </div>
</div>

<!-- ====================================================================== -->
<!-- SLIDE 7: PUSAT MENU & DRAWER TEKNISI -->
<!-- ====================================================================== -->
<div class="slide light">
  <div class="slide-header">
    <div class="header-left">
      <span class="header-tag">Navigasi Teknisi</span>
      <div class="header-title-box">
        <h1>Menu Samping Teknisi</h1>
        <p>Akses cepat ke tugas harian, riwayat maintenance, dan arsip absen</p>
      </div>
    </div>
    <div class="header-brand-badge">
      <img src="data:image/png;base64,{logo_round_b64}" alt="BSS Logo" />
      <span>BSS PARKING</span>
    </div>
  </div>

  <div class="slide-body">
    <div class="content-col">
      <p class="intro-text">
        Menu samping berisi semua fitur pendukung teknisi dalam satu panel yang bisa dibuka kapan saja:
      </p>

      <div class="callout-card">
        <div class="callout-badge">1</div>
        <div class="callout-content">
          <h3>Daily Task <span class="badge-pill orange">Prioritas</span></h3>
          <p class="step-action"><b>Tindakan:</b> Ketuk <b>Daily Task</b> di baris teratas.</p>
          <p class="step-result"><b>Hasil:</b> Menampilkan tugas harian dari SPV beserta statusnya.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">2</div>
        <div class="callout-content">
          <h3>Riwayat Maintenance <span class="badge-pill">Arsip Foto</span></h3>
          <p class="step-action"><b>Tindakan:</b> Ketuk <b>Riwayat Maintenance</b>.</p>
          <p class="step-result"><b>Hasil:</b> Melihat checklist yang sudah dikirim, lengkap dengan foto alat.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">3</div>
        <div class="callout-content">
          <h3>Arsip Absen (30 Hari) <span class="badge-pill green">Riwayat Absen</span></h3>
          <p class="step-action"><b>Tindakan:</b> Ketuk <b>Arsip Absen</b>.</p>
          <p class="step-result"><b>Hasil:</b> Menampilkan absen masuk dan pulang 30 hari terakhir.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">4</div>
        <div class="callout-content">
          <h3>Profil & Panduan PWA <span class="badge-pill blue">Akun</span></h3>
          <p class="step-action"><b>Tindakan:</b> Cek profil (contoh: <b>Junifer Manua • IT Support KC Manado</b>) dan buka panduan PWA iPhone.</p>
          <p class="step-result"><b>Hasil:</b> Memastikan akun aktif dan aplikasi bisa dibuka layar penuh.</p>
        </div>
      </div>

      <div class="tip-box blue">
        💡 <b>Panduan PWA iPhone:</b> Buka alamat aplikasi di Safari, ketuk ikon <b>Bagikan (Share)</b>, lalu pilih <b>Tambahkan ke Layar Utama (Add to Home Screen)</b>. Aplikasi akan terbuka layar penuh tanpa bilah alamat browser.
      </div>
    </div>

    <div class="phone-col">
      <div class="phone-frame">
        <div class="phone-speaker"></div>
        <div class="phone-screen">
          <img src="data:image/png;base64,{ss_tek_drawer_b64}" alt="Teknisi Drawer Screen" />
          <div class="pin" style="top: 20.5%; left: 80%;">1</div>
          <div class="pin" style="top: 28.5%; left: 80%;">2</div>
          <div class="pin" style="top: 36.5%; left: 80%;">3</div>
          <div class="pin" style="top: 63.5%; left: 80%;">4</div>
        </div>
      </div>
    </div>
  </div>

  <div class="slide-footer">
    <div class="footer-left">
      <span class="footer-brand">PMAapp</span>
      <span>•</span>
      <span>Menu Samping & Profil</span>
      <span>•</span>
      <span class="footer-love">PMA App ❤️ Made by annnpii</span>
    </div>
    <span class="slide-num">Halaman 07 / 12</span>
  </div>
</div>

<!-- ====================================================================== -->
<!-- SLIDE 8: EKSEKUSI DAILY TASK TEKNISI -->
<!-- ====================================================================== -->
<div class="slide light">
  <div class="slide-header">
    <div class="header-left">
      <span class="header-tag">Tugas Harian</span>
      <div class="header-title-box">
        <h1>Daily Task & Laporan Pulang</h1>
        <p>Tugas harian yang selesai otomatis masuk ke draf absen pulang</p>
      </div>
    </div>
    <div class="header-brand-badge">
      <img src="data:image/png;base64,{logo_round_b64}" alt="BSS Logo" />
      <span>BSS PARKING</span>
    </div>
  </div>

  <div class="slide-body">
    <div class="content-col">
      <p class="intro-text">
        Daily Task berisi tugas dari SPV. Tugas yang selesai langsung masuk laporan, tanpa perlu diketik ulang:
      </p>

      <div class="callout-card">
        <div class="callout-badge">1</div>
        <div class="callout-content">
          <h3>Ringkasan Progres <span class="badge-pill green">Status Live</span></h3>
          <p class="step-action"><b>Tindakan:</b> Lihat indikator di bagian atas (contoh: <b>1 dari 1 Selesai</b> dengan badge hijau <b>Semua Selesai</b>).</p>
          <p class="step-result"><b>Hasil:</b> Tahu berapa tugas yang masih tersisa di shift ini.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">2</div>
        <div class="callout-content">
          <h3>Sinkron ke Absen Pulang <span class="badge-pill blue">Hemat Waktu</span></h3>
          <p class="step-action"><b>Tindakan:</b> Baca kotak info biru tentang integrasi tugas ke laporan pulang.</p>
          <p class="step-result"><b>Hasil:</b> Semua tugas yang selesai otomatis masuk draf Laporan Pulang, tanpa diketik ulang.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">3</div>
        <div class="callout-content">
          <h3>Kartu Tugas <span class="badge-pill">Detail</span></h3>
          <p class="step-action"><b>Tindakan:</b> Ketuk kartu tugas (contoh: badge <b>Maintenance</b>, judul <b>Maintenance 3 Pos Kasir - PBM</b>).</p>
          <p class="step-result"><b>Hasil:</b> Membuka instruksi, lokasi pos, dan form upload foto bukti.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">4</div>
        <div class="callout-content">
          <h3>Jam Selesai <span class="badge-pill green">Tercatat</span></h3>
          <p class="step-action"><b>Tindakan:</b> Upload foto bukti, lalu simpan tugas.</p>
          <p class="step-result"><b>Hasil:</b> Kartu bertanda badge hijau <b>✓ Selesai (13:18)</b> dan jam selesai tercatat di dashboard SPV.</p>
        </div>
      </div>

      <div class="tip-box">
        💡 <b>Auto-Sync Absen Pulang:</b> Teknisi tidak perlu menulis ulang daftar pekerjaan saat jam kerja berakhir. Cukup pastikan semua tugas di Daily Task berstatus selesai sebelum absen pulang.
      </div>
    </div>

    <div class="phone-col">
      <div class="phone-frame">
        <div class="phone-speaker"></div>
        <div class="phone-screen">
          <img src="data:image/png;base64,{ss_tek_daily_b64}" alt="Daily Task Screen" />
          <div class="pin" style="top: 13.0%; left: 82%;">1</div>
          <div class="pin" style="top: 20.5%; left: 12%;">2</div>
          <div class="pin" style="top: 32.5%; left: 12%;">3</div>
          <div class="pin" style="top: 45.5%; left: 82%;">4</div>
        </div>
      </div>
    </div>
  </div>

  <div class="slide-footer">
    <div class="footer-left">
      <span class="footer-brand">PMAapp</span>
      <span>•</span>
      <span>Daily Task & Sinkronisasi</span>
      <span>•</span>
      <span class="footer-love">PMA App ❤️ Made by annnpii</span>
    </div>
    <span class="slide-num">Halaman 08 / 12</span>
  </div>
</div>

<!-- ====================================================================== -->
<!-- SLIDE 9: PUSAT MENU & HAK AKSES SUPERVISOR (SPV) -->
<!-- ====================================================================== -->
<div class="slide light">
  <div class="slide-header">
    <div class="header-left">
      <span class="header-tag spv">Menu SPV</span>
      <div class="header-title-box">
        <h1>Menu & Hak Akses SPV</h1>
        <p>Menu khusus SPV untuk membagi tugas dan memantau tim</p>
      </div>
    </div>
    <div class="header-brand-badge">
      <img src="data:image/png;base64,{logo_round_b64}" alt="BSS Logo" />
      <span>BSS PARKING</span>
    </div>
  </div>

  <div class="slide-body">
    <div class="content-col">
      <p class="intro-text">
        Saat login sebagai SPV (contoh: <code>farhan@pma.com</code>), aplikasi menampilkan menu khusus koordinator cabang:
      </p>

      <div class="callout-card">
        <div class="callout-badge">1</div>
        <div class="callout-content">
          <h3>Penugasan Teknisi [SPV] <span class="badge-pill orange">Menu Utama</span></h3>
          <p class="step-action"><b>Tindakan:</b> Ketuk menu teratas <b>Penugasan Teknisi [SPV]</b> di menu samping.</p>
          <p class="step-result"><b>Hasil:</b> Buka SPV Task Dispatcher untuk buat tugas baru dan lihat status semua teknisi.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">2</div>
        <div class="callout-content">
          <h3>Riwayat Maintenance Cabang <span class="badge-pill">Pantau</span></h3>
          <p class="step-action"><b>Tindakan:</b> Ketuk menu <b>Riwayat Maintenance</b>.</p>
          <p class="step-result"><b>Hasil:</b> Menampilkan semua checklist dari semua pos dan gerbang, bukan hanya milik satu akun.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">3</div>
        <div class="callout-content">
          <h3>Mode Tampilan & Panduan PWA <span class="badge-pill">Pengaturan</span></h3>
          <p class="step-action"><b>Tindakan:</b> Pakai switch tema terang/gelap dan buka panduan instalasi PWA di ponsel SPV.</p>
          <p class="step-result"><b>Hasil:</b> Tampilan menyesuaikan cahaya sekitar dan aplikasi terbuka seperti aplikasi biasa.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">4</div>
        <div class="callout-content">
          <h3>Profil SPV <span class="badge-pill blue">Akses Cabang</span></h3>
          <p class="step-action"><b>Tindakan:</b> Cek kartu identitas SPV (contoh: <b>Farhan Lakoro • IT Support KC Manado</b>).</p>
          <p class="step-result"><b>Hasil:</b> Memastikan akses SPV aktif untuk mengecek laporan dan membagikan rekap cabang.</p>
        </div>
      </div>

      <div class="tip-box">
        💡 <b>Beda Peran:</b> Menu "Penugasan Teknisi [SPV]" hanya muncul di akun SPV. Akun teknisi tidak bisa melihat atau membukanya.
      </div>
    </div>

    <div class="phone-col">
      <div class="phone-frame">
        <div class="phone-speaker"></div>
        <div class="phone-screen">
          <img src="data:image/png;base64,{ss_spv_drawer_b64}" alt="SPV Drawer Screen" />
          <div class="pin" style="top: 21.0%; left: 80%;">1</div>
          <div class="pin" style="top: 29.0%; left: 80%;">2</div>
          <div class="pin" style="top: 45.0%; left: 88%;">3</div>
          <div class="pin" style="top: 64.0%; left: 80%;">4</div>
        </div>
      </div>
    </div>
  </div>

  <div class="slide-footer">
    <div class="footer-left">
      <span class="footer-brand">PMAapp</span>
      <span>•</span>
      <span>Menu & Hak Akses SPV</span>
      <span>•</span>
      <span class="footer-love">PMA App ❤️ Made by annnpii</span>
    </div>
    <span class="slide-num">Halaman 09 / 12</span>
  </div>
</div>

<!-- ====================================================================== -->
<!-- SLIDE 10: SPV TASK DISPATCHER (PEMBAGIAN TUGAS) -->
<!-- ====================================================================== -->
<div class="slide light">
  <div class="slide-header">
    <div class="header-left">
      <span class="header-tag spv">SPV Dispatcher</span>
      <div class="header-title-box">
        <h1>SPV Task Dispatcher: Pembagian Tugas Tim</h1>
        <p>Buat tugas cepat: pilih teknisi, lokasi pos, lalu tulis instruksi</p>
      </div>
    </div>
    <div class="header-brand-badge">
      <img src="data:image/png;base64,{logo_round_b64}" alt="BSS Logo" />
      <span>BSS PARKING</span>
    </div>
  </div>

  <div class="slide-body">
    <div class="content-col">
      <p class="intro-text">
        SPV bisa membagi tugas langsung dari ponsel, tanpa chat manual yang rawan terlewat:
      </p>

      <div class="callout-card">
        <div class="callout-badge">1</div>
        <div class="callout-content">
          <h3>Jenis Tugas <span class="badge-pill orange">Kategori</span></h3>
          <p class="step-action"><b>Tindakan:</b> Pilih tab <b>Tugas Khusus</b> untuk perbaikan mendadak atau darurat, atau <b>Maintenance SOP</b> untuk checklist rutin alat.</p>
          <p class="step-result"><b>Hasil:</b> Isian form menyesuaikan jenis tugas.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">2</div>
        <div class="callout-content">
          <h3>Pilih Teknisi <span class="badge-pill">Penerima</span></h3>
          <p class="step-action"><b>Tindakan:</b> Ketuk dropdown "Pilih Teknisi" lalu pilih teknisi yang aktif (contoh: <b>Ryan Lumasuge</b>, <b>Junifer Manua</b>, atau <b>Raldy Sangkop</b>).</p>
          <p class="step-result"><b>Hasil:</b> Tugas langsung masuk ke akun teknisi tersebut.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">3</div>
        <div class="callout-content">
          <h3>Lokasi & Instruksi <span class="badge-pill blue">Detail Tugas</span></h3>
          <p class="step-action"><b>Tindakan:</b> Ketik lokasi pos (contoh: <b>PBM - Pasar Bersehati</b>) dan tulis instruksinya (contoh: <i>Pengecatan markah panah lokasi TBM</i>).</p>
          <p class="step-result"><b>Hasil:</b> Teknisi tahu persis apa yang harus dikerjakan.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">4</div>
        <div class="callout-content">
          <h3>Kirim Tugas <span class="badge-pill green">Kirim Langsung</span></h3>
          <p class="step-action"><b>Tindakan:</b> Ketuk tombol oranye "Kirim Tugas" di bagian bawah form.</p>
          <p class="step-result"><b>Hasil:</b> Tugas langsung muncul di Daily Task teknisi dan tercatat di tab Status Tim.</p>
        </div>
      </div>

      <div class="tip-box">
        💡 <b>Kirim Langsung:</b> Pastikan ponsel terhubung internet saat menekan "Kirim Tugas". Tugas yang terkirim langsung terlihat di Daily Task teknisi tanpa perlu refresh.
      </div>
    </div>

    <div class="phone-col">
      <div class="phone-frame">
        <div class="phone-speaker"></div>
        <div class="phone-screen">
          <img src="data:image/png;base64,{ss_spv_dispatch_b64}" alt="SPV Dispatcher Screen" />
          <div class="pin" style="top: 19.5%; left: 14%;">1</div>
          <div class="pin" style="top: 29.0%; left: 88%;">2</div>
          <div class="pin" style="top: 45.0%; left: 88%;">3</div>
          <div class="pin" style="top: 69.0%; left: 88%;">4</div>
        </div>
      </div>
    </div>
  </div>

  <div class="slide-footer">
    <div class="footer-left">
      <span class="footer-brand">PMAapp</span>
      <span>•</span>
      <span>Pembagian Tugas Tim</span>
      <span>•</span>
      <span class="footer-love">PMA App ❤️ Made by annnpii</span>
    </div>
    <span class="slide-num">Halaman 10 / 12</span>
  </div>
</div>

<!-- ====================================================================== -->
<!-- SLIDE 11: MONITORING PROGRES TIM & REKAP REALTIME (SPV) -->
<!-- ====================================================================== -->
<div class="slide light">
  <div class="slide-header">
    <div class="header-left">
      <span class="header-tag spv">Monitoring Live</span>
      <div class="header-title-box">
        <h1>Pantau Progres Tim (SPV)</h1>
        <p>Dashboard status semua teknisi, filter tugas, dan rekap laporan cabang</p>
      </div>
    </div>
    <div class="header-brand-badge">
      <img src="data:image/png;base64,{logo_round_b64}" alt="BSS Logo" />
      <span>BSS PARKING</span>
    </div>
  </div>

  <div class="slide-body">
    <div class="content-col">
      <p class="intro-text">
        Tab Status Tim menampilkan aktivitas harian semua teknisi cabang:
      </p>

      <div class="callout-card">
        <div class="callout-badge">1</div>
        <div class="callout-content">
          <h3>Persentase Tugas Selesai <span class="badge-pill orange">Metrik Live</span></h3>
          <p class="step-action"><b>Tindakan:</b> Lihat indikator live di atas kartu tugas: <b>⚡ 5/14 (35%)</b>.</p>
          <p class="step-result"><b>Hasil:</b> SPV langsung tahu persentase tugas cabang yang sudah selesai hari ini.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">2</div>
        <div class="callout-content">
          <h3>Filter Tugas <span class="badge-pill">Saring Cepat</span></h3>
          <p class="step-action"><b>Tindakan:</b> Ketuk tombol filter: <b>[Selesai (5)]</b>, <b>[Belum Mulai (9)]</b>, atau <b>[Semua (14)]</b>.</p>
          <p class="step-result"><b>Hasil:</b> Daftar hanya menampilkan tugas sesuai filter, jadi tugas yang tertunda mudah ditindaklanjuti.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">3</div>
        <div class="callout-content">
          <h3>Rincian per Teknisi <span class="badge-pill">Siapa Mengerjakan Apa</span></h3>
          <p class="step-action"><b>Tindakan:</b> Lihat inisial teknisi (<b>[RL] Ryan</b>, <b>[JM] Junifer</b>, <b>[AS] Alessandro</b>), judul tugas, dan lokasi pos (📍 MGNW / PBM).</p>
          <p class="step-result"><b>Hasil:</b> Tahu pembagian beban kerja dan posisi tiap teknisi.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">4</div>
        <div class="callout-content">
          <h3>Jam Selesai & Catatan <span class="badge-pill green">Verifikasi</span></h3>
          <p class="step-action"><b>Tindakan:</b> Cek stempel waktu hijau <b>✓ Selesai · 13:18 WITA</b> dan buka dropdown <b>Catatan tersedia</b>.</p>
          <p class="step-result"><b>Hasil:</b> SPV mengecek hasil kerja sebelum membuat rekap cabang.</p>
        </div>
      </div>

      <div class="tip-box">
        💡 <b>Tombol Kontrol Tim:</b> Ketuk tombol oranye "Kontrol Tim" di pojok kanan atas untuk membuat ringkasan harian tim yang siap disalin ke grup operasional cabang.
      </div>
    </div>

    <div class="phone-col">
      <div class="phone-frame">
        <div class="phone-speaker"></div>
        <div class="phone-screen">
          <img src="data:image/png;base64,{ss_spv_status_b64}" alt="SPV Status Tim Screen" />
          <div class="pin" style="top: 15.0%; left: 54%;">1</div>
          <div class="pin" style="top: 20.5%; left: 84%;">2</div>
          <div class="pin" style="top: 35.0%; left: 15%;">3</div>
          <div class="pin" style="top: 38.0%; left: 85%;">4</div>
        </div>
      </div>
    </div>
  </div>

  <div class="slide-footer">
    <div class="footer-left">
      <span class="footer-brand">PMAapp</span>
      <span>•</span>
      <span>Pantau Progres Tim</span>
      <span>•</span>
      <span class="footer-love">PMA App ❤️ Made by annnpii</span>
    </div>
    <span class="slide-num">Halaman 11 / 12</span>
  </div>
</div>

<!-- ====================================================================== -->
<!-- SLIDE 12: ALUR KERJA HARIAN, STANDAR MUTU & PANDUAN KENDALA -->
<!-- ====================================================================== -->
<div class="slide light">
  <div class="slide-header">
    <div class="header-left">
      <span class="header-tag sop">Standar Operasional</span>
      <div class="header-title-box">
        <h1>Alur Kerja, Standar Mutu & Kendala</h1>
        <p>Alur kerja harian, standar data, dan solusi kendala di lapangan</p>
      </div>
    </div>
    <div class="header-brand-badge">
      <img src="data:image/png;base64,{logo_round_b64}" alt="BSS Logo" />
      <span>BSS PARKING</span>
    </div>
  </div>

  <div class="slide-body" style="grid-template-columns: 1fr; align-items: start;">
    <div class="flow-container">
      <p class="intro-text">
        Alur kerja yang wajib dijalankan semua petugas di setiap cabang BSS Parking:
      </p>

      <div class="flow-row">
        <div class="flow-card">
          <div>
            <div class="flow-num">1</div>
            <h4>Login Akun</h4>
            <p>Login pakai akun cabang (@pma.com). Pastikan izin GPS di ponsel aktif.</p>
          </div>
        </div>

        <div class="flow-card">
          <div>
            <div class="flow-num">2</div>
            <h4>Absensi Masuk</h4>
            <p>Pilih shift (1, 2, 2.2, atau 3). Ambil selfie berseragam dengan cap lokasi & WITA.</p>
          </div>
        </div>

        <div class="flow-card accent">
          <div>
            <div class="flow-num">3</div>
            <h4>Tugas & SOP</h4>
            <p>Selesaikan Daily Task dan checklist SOP (Pos, Barrier Gate, Manless, Server/Kasir).</p>
          </div>
        </div>

        <div class="flow-card">
          <div>
            <div class="flow-num">4</div>
            <h4>Absensi Pulang</h4>
            <p>Setelah jam kerja selesai, absen pulang. Tugas yang selesai otomatis masuk laporan.</p>
          </div>
        </div>

        <div class="flow-card">
          <div>
            <div class="flow-num">5</div>
            <h4>Pengecekan SPV</h4>
            <p>SPV pantau progres tim, cek bukti foto, dan ekspor rekap cabang.</p>
          </div>
        </div>
      </div>

      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px; margin-top: 6px;">
        <div style="background: #FFFFFF; border: 1.5px solid #CBD5E1; border-radius: 10px; padding: 12px; box-shadow: 0 2px 6px rgba(15,44,89,0.03);">
          <h3 style="font-size: 13px; color: #0F2C59; font-weight: 800; margin-bottom: 6px; display: flex; align-items: center; gap: 6px;">
            <span style="color: #FF6500;">🛡️</span> Standar Mutu
          </h3>
          <ul style="font-size: 10.5px; color: #334155; line-height: 1.55; padding-left: 16px; font-weight: 500;">
            <li><b>Waktu Jaringan (WITA)</b>: Semua jam absen memakai waktu jaringan resmi, bukan jam ponsel.</li>
            <li><b>Lokasi Pos</b>: Semua foto absen dan SOP otomatis mencantumkan lokasi pos parkir yang aktif.</li>
            <li><b>Foto Kondisi Asli</b>: Setiap checklist wajib foto kondisi nyata alat di lapangan.</li>
            <li><b>Tugas Dibagi Lewat SPV</b>: Pembagian tugas lewat SPV supaya tidak tumpang tindih.</li>
          </ul>
        </div>

        <div style="background: #FFFFFF; border: 1.5px solid #CBD5E1; border-radius: 10px; padding: 12px; box-shadow: 0 2px 6px rgba(15,44,89,0.03);">
          <h3 style="font-size: 13px; color: #0F2C59; font-weight: 800; margin-bottom: 6px; display: flex; align-items: center; gap: 6px;">
            <span style="color: #0F2C59;">🔧</span> Penanganan Kendala Cepat
          </h3>
          <ul style="font-size: 10.5px; color: #334155; line-height: 1.55; padding-left: 16px; font-weight: 500;">
            <li><b>Sinyal / Internet Lemah</b>: Form tersimpan sebagai draf di ponsel dan otomatis terunggah saat sinyal kembali.</li>
            <li><b>Izin Kamera / GPS Tidak Muncul</b>: Buka setelan browser ponsel, ubah izin Camera & Location ke "Allow".</li>
            <li><b>Gagal Absen Pulang</b>: Pastikan jam kerja minimal terpenuhi (8 jam untuk Shift 1, 2, 3; 4 jam untuk Shift 2.2).</li>
            <li><b>Bantuan Akun</b>: Hubungi Koordinator IT cabang atau SPV kalau butuh verifikasi akun.</li>
          </ul>
        </div>
      </div>
    </div>
  </div>

  <div class="slide-footer">
    <div class="footer-left">
      <span class="footer-brand">PMAapp</span>
      <span>•</span>
      <span>Panduan Operasional Lapangan • v2.4</span>
      <span>•</span>
      <span class="footer-love">PMA App ❤️ Made by annnpii</span>
    </div>
    <span class="slide-num">Halaman 12 / 12</span>
  </div>
</div>

</body>
</html>
"""

with open('docs/slides_compiled.html', 'w', encoding='utf-8') as f:
    f.write(html_content)

print('Compiled HTML slides saved to docs/slides_compiled.html')

# Generate PDF using headless Chrome
cmd = [
    '/usr/bin/google-chrome-stable',
    '--headless=new',
    '--disable-gpu',
    '--no-sandbox',
    '--print-to-pdf-no-header',
    '--print-to-pdf=docs/PMAapp_Tutorial_Guide.pdf',
    'docs/slides_compiled.html'
]
print('Rendering PDF via Chrome...')
res = subprocess.run(cmd, capture_output=True, text=True)
if res.returncode == 0:
    print('PDF successfully generated at docs/PMAapp_Tutorial_Guide.pdf!')
    os.makedirs('web/docs', exist_ok=True)
    subprocess.run(['cp', 'docs/PMAapp_Tutorial_Guide.pdf', 'web/docs/PMAapp_Tutorial_Guide.pdf'])
    print('Copied to web/docs/PMAapp_Tutorial_Guide.pdf')
else:
    print('Chrome render failed:', res.stderr)
