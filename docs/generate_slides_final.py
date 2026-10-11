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
<title>PMAapp — Panduan Penggunaan</title>
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
    padding: 7px 12px;
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
    display: grid;
    grid-template-columns: 1.15fr 0.85fr;
    gap: 25px;
    align-items: center;
    height: 100%;
  }}

  .cover-hero h1 {{
    font-size: 38px;
    font-weight: 900;
    line-height: 1.15;
    letter-spacing: -1px;
    color: #FFFFFF;
    margin-bottom: 14px;
  }}

  .cover-hero h1 span {{
    color: #FF6500;
    display: block;
  }}

  .cover-hero p {{
    font-size: 14px;
    color: #CBD5E1;
    line-height: 1.6;
    margin-bottom: 22px;
    max-width: 500px;
    font-weight: 500;
  }}

  .cover-pillars {{
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 12px;
    margin-bottom: 22px;
  }}

  .pillar-card {{
    background: rgba(255, 255, 255, 0.08);
    border: 1px solid rgba(255, 255, 255, 0.15);
    border-radius: 10px;
    padding: 12px;
    backdrop-filter: blur(10px);
  }}

  .pillar-card .icon {{
    font-size: 20px;
    margin-bottom: 6px;
    color: #FF6500;
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
    margin-bottom: 0;
  }}

  .cover-meta {{
    font-size: 10.5px;
    color: #94A3B8;
    line-height: 1.6;
  }}

  .cover-meta strong {{
    color: #FFFFFF;
  }}

  .cover-preview-card {{
    background: rgba(255, 255, 255, 0.06);
    border: 1.5px solid rgba(255, 255, 255, 0.15);
    border-radius: 20px;
    padding: 18px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
    box-shadow: 0 20px 45px rgba(0, 0, 0, 0.35);
  }}

  .cover-preview-card img.logo-round {{
    width: 80px;
    height: 80px;
    border-radius: 50%;
    box-shadow: 0 6px 16px rgba(0,0,0,0.3);
  }}

  .cover-preview-card h3 {{
    font-size: 18px;
    font-weight: 800;
    color: #FFFFFF;
    text-align: center;
  }}

  .cover-preview-card .badge {{
    background: #FF6500;
    color: #FFFFFF;
    font-size: 10.5px;
    font-weight: 800;
    padding: 4px 14px;
    border-radius: 12px;
    letter-spacing: 0.5px;
  }}

  /* Diagram Flow Slide 12 */
  .flow-container {{
    display: flex;
    flex-direction: column;
    gap: 12px;
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
    padding: 11px 9px;
    text-align: center;
    box-shadow: 0 2px 6px rgba(15, 44, 89, 0.04);
    display: flex;
    flex-direction: column;
    justify-content: space-between;
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
    font-weight: 800;
    font-size: 11px;
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 0 auto 6px auto;
  }}

  .flow-card.accent .flow-num {{
    background: #FF6500;
  }}

  .flow-card h4 {{
    font-size: 11px;
    font-weight: 800;
    color: #0F2C59;
    margin-bottom: 3.5px;
  }}

  .flow-card p {{
    font-size: 9.5px;
    color: #475569;
    line-height: 1.35;
  }}
</style>
</head>
<body>

<!-- ====================================================================== -->
<!-- SLIDE 1: COVER -->
<!-- ====================================================================== -->
<div class="slide dark-navy">
  <div class="slide-header">
    <div class="header-left">
      <span class="header-tag" style="background: #FF6500;">PANDUAN OPERASIONAL</span>
    </div>
    <div class="header-right">
      <img src="data:image/png;base64,{logo_white_text_b64}" alt="BSS Parking Logo" class="header-logo" />
    </div>
  </div>

  <div class="cover-grid">
    <div class="cover-hero">
      <h1>Panduan Penggunaan <span>PMAapp</span></h1>
      <p>
        Panduan untuk teknisi lapangan dan SPV dalam melakukan absensi, menjalankan checklist maintenance, mengelola tugas harian, dan memantau progres tim cabang.
      </p>

      <div class="cover-pillars">
        <div class="pillar-card">
          <div class="icon">📍</div>
          <h4>ABSENSI</h4>
          <p>Lokasi dan waktu sesuai sistem</p>
        </div>
        <div class="pillar-card">
          <div class="icon">🛡️</div>
          <h4>MAINTENANCE</h4>
          <p>Checklist dan foto bukti</p>
        </div>
        <div class="pillar-card">
          <div class="icon">📋</div>
          <h4>TUGAS HARIAN</h4>
          <p>Penugasan dan progres tim</p>
        </div>
      </div>

      <div class="cover-meta">
        <strong>Pengguna:</strong> Teknisi Lapangan &amp; Supervisor (SPV)<br>
        <strong>Dokumen:</strong> SOP-PMA-BSS-2026-v2.4 • <strong>Revisi sumber:</strong> Oktober 2026
      </div>
    </div>

    <div class="cover-preview-card">
      <img src="data:image/png;base64,{logo_round_b64}" alt="BSS Logo Round" class="logo-round" />
      <h3>BSS PARKING</h3>
      <div class="badge">SISTEM MANAJEMEN PARKIR</div>
      <p style="font-size: 11px; color: #CBD5E1; text-align: center; line-height: 1.5; margin-top: 4px;">
        Aplikasi operasional terintegrasi untuk absensi lokasi, checklist SOP perangkat pos, serta pembagian dan pemantauan tugas tim cabang.
      </p>
    </div>
  </div>

  <div class="slide-footer">
    <div class="footer-left">
      <span class="footer-brand">PMAapp</span>
      <span>•</span>
      <span>Sistem Manajemen Parkir</span>
      <span>•</span>
      <span class="footer-powered">PMAapp powered by annnpii</span>
    </div>
    <span class="slide-num">Halaman 01 / 12</span>
  </div>
</div>

<!-- ====================================================================== -->
<!-- SLIDE 2: LOGIN & HAK AKSES -->
<!-- ====================================================================== -->
<div class="slide light">
  <div class="slide-header">
    <div class="header-left">
      <span class="header-tag">LOGIN</span>
      <div class="header-title-box">
        <h1>Login dan Hak Akses</h1>
        <p>Masuk menggunakan akun resmi cabang. Menu yang tersedia mengikuti peran akun.</p>
      </div>
    </div>
    <div class="header-brand-badge">
      <img src="data:image/png;base64,{logo_round_b64}" alt="BSS Logo" />
      <span>BSS PARKING • PMAapp</span>
    </div>
  </div>

  <div class="slide-body">
    <div class="content-col">
      <div class="callout-card">
        <div class="callout-badge">1</div>
        <div class="callout-content">
          <h3>Email / Username <span class="badge-pill blue">AKUN</span></h3>
          <p class="step-action"><b>Tindakan:</b> Masukkan email atau username resmi yang diberikan untuk akun cabang.</p>
          <p class="step-result"><b>Hasil:</b> Sistem memverifikasi identitas dan peran akun.</p>
          <p class="step-result"><b>Catatan:</b> Pastikan penulisannya benar.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">2</div>
        <div class="callout-content">
          <h3>Kata Sandi <span class="badge-pill">KEAMANAN</span></h3>
          <p class="step-action"><b>Tindakan:</b> Masukkan kata sandi.</p>
          <p class="step-result"><b>Hasil:</b> Karakter sandi terlindungi.</p>
          <p class="step-result"><b>Catatan:</b> Gunakan ikon mata jika perlu memeriksa ketikan sebelum masuk.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">3</div>
        <div class="callout-content">
          <h3>Tombol Masuk <span class="badge-pill orange">MASUK</span></h3>
          <p class="step-action"><b>Tindakan:</b> Ketuk tombol “Masuk”.</p>
          <p class="step-result"><b>Hasil:</b> Setelah berhasil, aplikasi membuka menu sesuai peran akun.</p>
          <p class="step-result"><b>Catatan:</b> Teknisi diarahkan ke antarmuka kamera/absensi, SPV ke menu pemantauan tim.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">4</div>
        <div class="callout-content">
          <h3>Mode Tampilan <span class="badge-pill">TEMA</span></h3>
          <p class="step-action"><b>Tindakan:</b> Gunakan pengaturan tema untuk memilih tampilan.</p>
          <p class="step-result"><b>Hasil:</b> Tampilan beralih antara tema Terang atau Gelap.</p>
          <p class="step-result"><b>Catatan:</b> Sesuaikan dengan kondisi pencahayaan pos kerja.</p>
        </div>
      </div>

      <div class="tip-box">
        💡 <b>Catatan:</b> Jika login gagal, periksa penulisan akun dan koneksi internet. Untuk reset kata sandi, hubungi SPV atau Koordinator IT cabang.
      </div>
    </div>

    <div class="phone-col">
      <div class="phone-frame">
        <div class="phone-speaker"></div>
        <div class="phone-screen">
          <img src="data:image/png;base64,{ss_login_b64}" alt="Login Screen" />
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
      <span>Panduan Operasional</span>
      <span>•</span>
      <span class="footer-powered">PMAapp powered by annnpii</span>
    </div>
    <span class="slide-num">Halaman 02 / 12</span>
  </div>
</div>

<!-- ====================================================================== -->
<!-- SLIDE 3: KAMERA DAN INFORMASI LOKASI -->
<!-- ====================================================================== -->
<div class="slide light">
  <div class="slide-header">
    <div class="header-left">
      <span class="header-tag">KAMERA UTAMA</span>
      <div class="header-title-box">
        <h1>Kamera dan Informasi Lokasi</h1>
        <p>Gunakan kamera aplikasi untuk mengambil foto bukti absensi dan maintenance.</p>
      </div>
    </div>
    <div class="header-brand-badge">
      <img src="data:image/png;base64,{logo_round_b64}" alt="BSS Logo" />
      <span>BSS PARKING • PMAapp</span>
    </div>
  </div>

  <div class="slide-body">
    <div class="content-col">
      <div class="callout-card">
        <div class="callout-badge">1</div>
        <div class="callout-content">
          <h3>Menu Samping <span class="badge-pill blue">MENU</span></h3>
          <p class="step-action"><b>Tindakan:</b> Ketuk ikon menu garis tiga (☰) di sudut kiri atas.</p>
          <p class="step-result"><b>Hasil:</b> Membuka Daily Task, riwayat maintenance, arsip absensi, dan panduan PWA.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">2</div>
        <div class="callout-content">
          <h3>Rasio dan Timer <span class="badge-pill">KAMERA</span></h3>
          <p class="step-action"><b>Tindakan:</b> Pilih rasio kamera sesuai kebutuhan atau aktifkan timer.</p>
          <p class="step-result"><b>Hasil:</b> Bidikan foto disesuaikan; timer membantu mengambil foto dengan posisi yang stabil.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">3</div>
        <div class="callout-content">
          <h3>Status Shift <span class="badge-pill green">SHIFT</span></h3>
          <p class="step-action"><b>Tindakan:</b> Periksa status absensi dan shift yang sedang dipilih sebelum melanjutkan.</p>
          <p class="step-result"><b>Hasil:</b> Menampilkan shift aktif atau membuka pengaturan shift kerja.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">4</div>
        <div class="callout-content">
          <h3>Tombol Foto <span class="badge-pill orange">FOTO</span></h3>
          <p class="step-action"><b>Tindakan:</b> Arahkan kamera ke objek atau wajah sesuai instruksi, lalu ambil foto.</p>
          <p class="step-result"><b>Hasil:</b> Foto tersimpan dengan data stempel waktu dan lokasi.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">5</div>
        <div class="callout-content">
          <h3>Katalog SOP <span class="badge-pill">CHECKLIST</span></h3>
          <p class="step-action"><b>Tindakan:</b> Ketuk ikon dokumen di sudut kanan bawah.</p>
          <p class="step-result"><b>Hasil:</b> Buka katalog untuk memilih template checklist maintenance.</p>
        </div>
      </div>

      <div class="tip-box blue">
        💡 <b>Catatan:</b> Pastikan izin kamera dan lokasi aktif. Informasi waktu dan lokasi pada foto mengikuti data yang disediakan aplikasi; akurasi bergantung pada izin dan layanan perangkat.
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
      <span>Panduan Operasional</span>
      <span>•</span>
      <span class="footer-powered">PMAapp powered by annnpii</span>
    </div>
    <span class="slide-num">Halaman 03 / 12</span>
  </div>
</div>

<!-- ====================================================================== -->
<!-- SLIDE 4: PILIH SHIFT DAN JENIS ABSENSI -->
<!-- ====================================================================== -->
<div class="slide light">
  <div class="slide-header">
    <div class="header-left">
      <span class="header-tag">PENGATURAN SHIFT</span>
      <div class="header-title-box">
        <h1>Pilih Shift dan Jenis Absensi</h1>
        <p>Periksa nama, lokasi tugas, dan shift sebelum mengambil foto absensi.</p>
      </div>
    </div>
    <div class="header-brand-badge">
      <img src="data:image/png;base64,{logo_round_b64}" alt="BSS Logo" />
      <span>BSS PARKING • PMAapp</span>
    </div>
  </div>

  <div class="slide-body">
    <div class="content-col">
      <div class="callout-card">
        <div class="callout-badge">1</div>
        <div class="callout-content">
          <h3>Nama Teknisi <span class="badge-pill blue">PROFIL</span></h3>
          <p class="step-action"><b>Tindakan:</b> Pastikan nama akun yang tampil sesuai dengan pengguna yang melakukan absensi.</p>
          <p class="step-result"><b>Hasil:</b> Nama teknisi tercatat pada data absensi cabang.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">2</div>
        <div class="callout-content">
          <h3>Lokasi Tugas <span class="badge-pill">LOKASI</span></h3>
          <p class="step-action"><b>Tindakan:</b> Pilih atau periksa lokasi tugas yang sesuai dengan penempatan kerja.</p>
          <p class="step-result"><b>Hasil:</b> Lokasi penugasan tervalidasi pada sistem.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">3</div>
        <div class="callout-content">
          <h3>Pilih Shift <span class="badge-pill green">JADWAL</span></h3>
          <p class="step-action"><b>Tindakan:</b> Pilih jadwal yang berlaku:</p>
          <p class="step-action" style="margin-top: 2px;">
            • <b>Shift 1 (03.00–11.00 WITA)</b><br>
            • <b>Shift 2 (10.00–18.00 WITA)</b><br>
            • <b>Shift 2.2 (10.00–14.00 WITA)</b><br>
            • <b>Shift 3 (14.00–22.00 WITA)</b>
          </p>
          <p class="step-result"><b>Hasil:</b> Jadwal kerja terkunci pada shift yang dipilih.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">4</div>
        <div class="callout-content">
          <h3>Jenis Absensi <span class="badge-pill orange">STATUS</span></h3>
          <p class="step-action"><b>Tindakan:</b> Pilih “Masuk” saat mulai kerja atau “Pulang” saat selesai kerja.</p>
          <p class="step-result"><b>Hasil:</b> Kamera siap mengambil foto sesuai jenis absensi yang dipilih.</p>
        </div>
      </div>

      <div class="tip-box">
        💡 <b>Catatan:</b> Panduan sumber menyebut durasi minimum 8 jam untuk Shift 1, 2, dan 3 serta 4 jam untuk Shift 2.2. Pastikan jadwal dan aturan ini sesuai ketentuan cabang yang berlaku.
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
      <span>Panduan Operasional</span>
      <span>•</span>
      <span class="footer-powered">PMAapp powered by annnpii</span>
    </div>
    <span class="slide-num">Halaman 04 / 12</span>
  </div>
</div>

<!-- ====================================================================== -->
<!-- SLIDE 5: KATALOG TEMPLATE MAINTENANCE -->
<!-- ====================================================================== -->
<div class="slide light">
  <div class="slide-header">
    <div class="header-left">
      <span class="header-tag">KATALOG SOP</span>
      <div class="header-title-box">
        <h1>Katalog Template Maintenance</h1>
        <p>Pilih kategori sesuai perangkat atau area yang akan diperiksa. Setiap kategori memiliki titik dan jumlah foto wajib.</p>
      </div>
    </div>
    <div class="header-brand-badge">
      <img src="data:image/png;base64,{logo_round_b64}" alt="BSS Logo" />
      <span>BSS PARKING • PMAapp</span>
    </div>
  </div>

  <div class="slide-body">
    <div class="content-col">
      <div class="callout-card">
        <div class="callout-badge">1</div>
        <div class="callout-content">
          <h3>Absensi Masuk dan Pulang <span class="badge-pill green">ABSENSI</span></h3>
          <p class="step-action"><b>Tindakan:</b> Ambil foto absensi sesuai instruksi aplikasi.</p>
          <p class="step-result"><b>Hasil:</b> Foto absensi masuk/pulang tercatat lengkap dengan informasi lokasi.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">2</div>
        <div class="callout-content">
          <h3>Maintenance Pos Parkir <span class="badge-pill orange">9 FOTO</span></h3>
          <p class="step-action"><b>Tindakan:</b> Periksa kebersihan pos, kabel daya, stop kontak, meja kerja, dan kondisi fisik pos.</p>
          <p class="step-result"><b>Hasil:</b> 9 titik pos parkir terdokumentasi lengkap.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">3</div>
        <div class="callout-content">
          <h3>Maintenance Barrier Gate <span class="badge-pill orange">9 FOTO</span></h3>
          <p class="step-action"><b>Tindakan:</b> Periksa motor, pegas palang, sensor loop, arm karet, CCTV gate, dan panel kabel.</p>
          <p class="step-result"><b>Hasil:</b> Kondisi mekanik dan elektrik barrier gate terekam lengkap.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">4</div>
        <div class="callout-content">
          <h3>Maintenance Manless dan Pulau Gate <span class="badge-pill orange">8 FOTO</span></h3>
          <p class="step-action"><b>Tindakan:</b> Periksa dispenser tiket, printer thermal, reader RFID, intercom, dan tombol tiket.</p>
          <p class="step-result"><b>Hasil:</b> Seluruh modul pulau gate mandiri siap digunakan.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">5</div>
        <div class="callout-content">
          <h3>Maintenance Server dan Kasir <span class="badge-pill orange">6 FOTO</span></h3>
          <p class="step-action"><b>Tindakan:</b> Periksa komputer kasir, server, UPS, suhu ruang kontrol, dan switch LAN.</p>
          <p class="step-result"><b>Hasil:</b> Keandalan sistem komputerisasi dan jaringan pos terdata.</p>
        </div>
      </div>

      <div class="tip-box blue">
        💡 <b>Catatan:</b> Jumlah foto wajib mengikuti template yang tampil pada aplikasi. Pastikan kategori dan lokasi sudah benar sebelum memulai.
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
      <span>Panduan Operasional</span>
      <span>•</span>
      <span class="footer-powered">PMAapp powered by annnpii</span>
    </div>
    <span class="slide-num">Halaman 05 / 12</span>
  </div>
</div>

<!-- ====================================================================== -->
<!-- SLIDE 6: PILIH UNIT DAN TARGET FOTO -->
<!-- ====================================================================== -->
<div class="slide light">
  <div class="slide-header">
    <div class="header-left">
      <span class="header-tag">EKSEKUSI SOP</span>
      <div class="header-title-box">
        <h1>Pilih Unit dan Target Foto</h1>
        <p>Tentukan unit yang akan diperiksa sebelum mengambil foto checklist.</p>
      </div>
    </div>
    <div class="header-brand-badge">
      <img src="data:image/png;base64,{logo_round_b64}" alt="BSS Logo" />
      <span>BSS PARKING • PMAapp</span>
    </div>
  </div>

  <div class="slide-body">
    <div class="content-col">
      <div class="callout-card">
        <div class="callout-badge">1</div>
        <div class="callout-content">
          <h3>Periksa Kategori dan Lokasi <span class="badge-pill blue">KONFIRMASI</span></h3>
          <p class="step-action"><b>Tindakan:</b> Pastikan judul template maintenance dan lokasi pos sesuai dengan pekerjaan yang dilakukan.</p>
          <p class="step-result"><b>Hasil:</b> Jenis template dan lokasi pos terkonfirmasi dengan benar.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">2</div>
        <div class="callout-content">
          <h3>Rentang Nomor Unit <span class="badge-pill green">UNIT</span></h3>
          <p class="step-action"><b>Tindakan:</b> Gunakan tombol tambah [+] dan kurang [-] untuk memilih unit awal dan akhir.</p>
          <p class="step-result"><b>Hasil:</b> Nomor unit fisik tercatat pada laporan inspeksi.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">3</div>
        <div class="callout-content">
          <h3>Jumlah Foto Wajib <span class="badge-pill orange">TARGET</span></h3>
          <p class="step-action"><b>Tindakan:</b> Periksa jumlah foto yang dihitung otomatis berdasarkan jumlah unit dan titik checklist.</p>
          <p class="step-result"><b>Hasil:</b> Total target foto yang wajib diambil tampil jelas pada indikator.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">4</div>
        <div class="callout-content">
          <h3>Mulai Pemeriksaan <span class="badge-pill">MULAI</span></h3>
          <p class="step-action"><b>Tindakan:</b> Ketuk “Mulai Pemeriksaan” untuk membuka kamera dan mengambil foto tiap titik.</p>
          <p class="step-result"><b>Hasil:</b> Kamera terbuka untuk memandu pengambilan foto sesuai checklist titik demi titik.</p>
        </div>
      </div>

      <div class="tip-box">
        💡 <b>Catatan:</b> Laporan tidak dapat dikirim jika foto wajib belum lengkap. Foto harus menunjukkan kondisi perangkat sebenarnya di lapangan, bukan gambar pada layar monitor.
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
      <span>Panduan Operasional</span>
      <span>•</span>
      <span class="footer-powered">PMAapp powered by annnpii</span>
    </div>
    <span class="slide-num">Halaman 06 / 12</span>
  </div>
</div>

<!-- ====================================================================== -->
<!-- SLIDE 7: MENU SAMPING TEKNISI -->
<!-- ====================================================================== -->
<div class="slide light">
  <div class="slide-header">
    <div class="header-left">
      <span class="header-tag">NAVIGASI TEKNISI</span>
      <div class="header-title-box">
        <h1>Menu Samping Teknisi</h1>
        <p>Gunakan menu samping untuk membuka tugas, riwayat maintenance, arsip absensi, dan profil.</p>
      </div>
    </div>
    <div class="header-brand-badge">
      <img src="data:image/png;base64,{logo_round_b64}" alt="BSS Logo" />
      <span>BSS PARKING • PMAapp</span>
    </div>
  </div>

  <div class="slide-body">
    <div class="content-col">
      <div class="callout-card">
        <div class="callout-badge">1</div>
        <div class="callout-content">
          <h3>Daily Task <span class="badge-pill orange">TUGAS</span></h3>
          <p class="step-action"><b>Tindakan:</b> Buka daftar tugas harian yang diberikan SPV dan periksa status setiap tugas.</p>
          <p class="step-result"><b>Hasil:</b> Menampilkan daftar tugas khusus dan maintenance yang perlu diselesaikan.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">2</div>
        <div class="callout-content">
          <h3>Riwayat Maintenance <span class="badge-pill">RIWAYAT</span></h3>
          <p class="step-action"><b>Tindakan:</b> Lihat checklist yang telah dikirim beserta foto bukti yang tersedia.</p>
          <p class="step-result"><b>Hasil:</b> Daftar laporan checklist maintenance terdahulu dapat ditinjau kembali.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">3</div>
        <div class="callout-content">
          <h3>Arsip Absensi <span class="badge-pill green">ABSENSI</span></h3>
          <p class="step-action"><b>Tindakan:</b> Lihat catatan absensi masuk dan pulang untuk periode yang tersedia di aplikasi.</p>
          <p class="step-result"><b>Hasil:</b> Catatan kehadiran dan foto absensi per shift dapat dipantau mandiri.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">4</div>
        <div class="callout-content">
          <h3>Profil dan Panduan PWA <span class="badge-pill blue">PROFIL</span></h3>
          <p class="step-action"><b>Tindakan:</b> Periksa informasi akun. Buka panduan PWA jika perlu menambahkan aplikasi ke layar utama ponsel.</p>
          <p class="step-result"><b>Hasil:</b> Akun terverifikasi dan shortcut aplikasi dapat dipasang di layar ponsel.</p>
        </div>
      </div>

      <div class="tip-box blue">
        💡 <b>Catatan:</b> Untuk memasang PWA di iPhone, buka aplikasi melalui Safari, ketuk Bagikan, lalu pilih “Tambahkan ke Layar Utama”. Nama menu dapat berbeda menurut versi browser.
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
      <span>Panduan Operasional</span>
      <span>•</span>
      <span class="footer-powered">PMAapp powered by annnpii</span>
    </div>
    <span class="slide-num">Halaman 07 / 12</span>
  </div>
</div>

<!-- ====================================================================== -->
<!-- SLIDE 8: DAILY TASK DAN LAPORAN PULANG -->
<!-- ====================================================================== -->
<div class="slide light">
  <div class="slide-header">
    <div class="header-left">
      <span class="header-tag">TUGAS HARIAN</span>
      <div class="header-title-box">
        <h1>Daily Task dan Laporan Pulang</h1>
        <p>Selesaikan tugas yang diberikan dan periksa statusnya sebelum absensi pulang.</p>
      </div>
    </div>
    <div class="header-brand-badge">
      <img src="data:image/png;base64,{logo_round_b64}" alt="BSS Logo" />
      <span>BSS PARKING • PMAapp</span>
    </div>
  </div>

  <div class="slide-body">
    <div class="content-col">
      <div class="callout-card">
        <div class="callout-badge">1</div>
        <div class="callout-content">
          <h3>Ringkasan Progres <span class="badge-pill green">PROGRES</span></h3>
          <p class="step-action"><b>Tindakan:</b> Periksa jumlah tugas selesai dan tugas yang masih tersisa.</p>
          <p class="step-result"><b>Hasil:</b> Progres tugas shift terpantau jelas pada kartu ringkasan atas.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">2</div>
        <div class="callout-content">
          <h3>Laporan Pulang <span class="badge-pill blue">LAPORAN</span></h3>
          <p class="step-action"><b>Tindakan:</b> Periksa draf laporan pulang yang terintegrasi dari tugas harian.</p>
          <p class="step-result"><b>Hasil:</b> Tugas yang selesai dapat masuk ke draf laporan pulang sesuai mekanisme aplikasi. Periksa kembali sebelum mengirim.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">3</div>
        <div class="callout-content">
          <h3>Detail Tugas <span class="badge-pill">DETAIL</span></h3>
          <p class="step-action"><b>Tindakan:</b> Ketuk kartu tugas untuk membaca instruksi, lokasi, dan kebutuhan foto bukti.</p>
          <p class="step-result"><b>Hasil:</b> Rincian instruksi pengerjaan terbuka secara lengkap.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">4</div>
        <div class="callout-content">
          <h3>Simpan Penyelesaian <span class="badge-pill green">STATUS</span></h3>
          <p class="step-action"><b>Tindakan:</b> Unggah foto bukti dan simpan tugas.</p>
          <p class="step-result"><b>Hasil:</b> Periksa apakah status berubah menjadi selesai beserta jam pencatatan.</p>
        </div>
      </div>

      <div class="tip-box">
        💡 <b>Catatan:</b> Sebelum absensi pulang, pastikan status tugas dan isi draf laporan sudah benar. Jika ada tugas yang belum tercatat, periksa statusnya atau hubungi SPV.
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
      <span>Panduan Operasional</span>
      <span>•</span>
      <span class="footer-powered">PMAapp powered by annnpii</span>
    </div>
    <span class="slide-num">Halaman 08 / 12</span>
  </div>
</div>

<!-- ====================================================================== -->
<!-- SLIDE 9: MENU DAN HAK AKSES SPV -->
<!-- ====================================================================== -->
<div class="slide light">
  <div class="slide-header">
    <div class="header-left">
      <span class="header-tag spv">MENU SPV</span>
      <div class="header-title-box">
        <h1>Menu dan Hak Akses SPV</h1>
        <p>Akun SPV menyediakan fitur untuk membagikan tugas dan memantau pekerjaan tim cabang.</p>
      </div>
    </div>
    <div class="header-brand-badge">
      <img src="data:image/png;base64,{logo_round_b64}" alt="BSS Logo" />
      <span>BSS PARKING • PMAapp</span>
    </div>
  </div>

  <div class="slide-body">
    <div class="content-col">
      <div class="callout-card">
        <div class="callout-badge">1</div>
        <div class="callout-content">
          <h3>Penugasan Teknisi <span class="badge-pill orange">TUGAS</span></h3>
          <p class="step-action"><b>Tindakan:</b> Buka menu penugasan untuk membuat tugas baru dan memilih teknisi penerima.</p>
          <p class="step-result"><b>Hasil:</b> Masuk ke modul dispatch tugas khusus dan maintenance tim.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">2</div>
        <div class="callout-content">
          <h3>Riwayat Maintenance Cabang <span class="badge-pill">RIWAYAT</span></h3>
          <p class="step-action"><b>Tindakan:</b> Lihat checklist maintenance yang tercatat untuk lokasi cabang sesuai hak akses.</p>
          <p class="step-result"><b>Hasil:</b> Seluruh arsip inspeksi seluruh pos cabang dapat diaudit terpusat.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">3</div>
        <div class="callout-content">
          <h3>Mode Tampilan dan Panduan PWA <span class="badge-pill">PENGATURAN</span></h3>
          <p class="step-action"><b>Tindakan:</b> Pilih tema tampilan dan buka panduan pemasangan aplikasi jika diperlukan.</p>
          <p class="step-result"><b>Hasil:</b> Kenyamanan visual disesuaikan dan shortcut terpasang di perangkat SPV.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">4</div>
        <div class="callout-content">
          <h3>Profil SPV <span class="badge-pill blue">AKUN</span></h3>
          <p class="step-action"><b>Tindakan:</b> Periksa informasi profil dan pastikan akun memiliki akses SPV yang sesuai.</p>
          <p class="step-result"><b>Hasil:</b> Otoritas pengelolaan operasional cabang terkonfirmasi aktif.</p>
        </div>
      </div>

      <div class="tip-box">
        💡 <b>Catatan:</b> Menu penugasan SPV hanya tersedia untuk akun dengan hak akses SPV. Jika menu tidak muncul, hubungi pengelola akun cabang.
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
      <span>Panduan Operasional</span>
      <span>•</span>
      <span class="footer-powered">PMAapp powered by annnpii</span>
    </div>
    <span class="slide-num">Halaman 09 / 12</span>
  </div>
</div>

<!-- ====================================================================== -->
<!-- SLIDE 10: PEMBAGIAN TUGAS TIM -->
<!-- ====================================================================== -->
<div class="slide light">
  <div class="slide-header">
    <div class="header-left">
      <span class="header-tag spv">SPV DISPATCHER</span>
      <div class="header-title-box">
        <h1>Pembagian Tugas Tim</h1>
        <p>SPV dapat mengirim tugas melalui aplikasi dengan menentukan jenis pekerjaan, teknisi, lokasi, dan instruksi.</p>
      </div>
    </div>
    <div class="header-brand-badge">
      <img src="data:image/png;base64,{logo_round_b64}" alt="BSS Logo" />
      <span>BSS PARKING • PMAapp</span>
    </div>
  </div>

  <div class="slide-body">
    <div class="content-col">
      <div class="callout-card">
        <div class="callout-badge">1</div>
        <div class="callout-content">
          <h3>Jenis Tugas <span class="badge-pill orange">KATEGORI</span></h3>
          <p class="step-action"><b>Tindakan:</b> Pilih “Tugas Khusus” untuk pekerjaan tertentu atau “Maintenance SOP” untuk checklist rutin, sesuai pilihan yang tersedia.</p>
          <p class="step-result"><b>Hasil:</b> Form pengisian disesuaikan dengan jenis penugasan.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">2</div>
        <div class="callout-content">
          <h3>Pilih Teknisi <span class="badge-pill">PENERIMA</span></h3>
          <p class="step-action"><b>Tindakan:</b> Pilih teknisi penerima dari daftar akun yang tersedia.</p>
          <p class="step-result"><b>Hasil:</b> Tugas diarahkan secara spesifik ke teknisi yang dipilih.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">3</div>
        <div class="callout-content">
          <h3>Lokasi dan Instruksi <span class="badge-pill blue">DETAIL</span></h3>
          <p class="step-action"><b>Tindakan:</b> Tuliskan lokasi tugas serta instruksi yang spesifik, termasuk hasil yang diharapkan atau foto bukti jika diperlukan.</p>
          <p class="step-result"><b>Hasil:</b> Teknisi memahami detail pekerjaan yang harus dilaksanakan.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">4</div>
        <div class="callout-content">
          <h3>Kirim Tugas <span class="badge-pill green">KIRIM</span></h3>
          <p class="step-action"><b>Tindakan:</b> Ketuk “Kirim Tugas”, lalu pastikan tugas muncul pada Daily Task teknisi.</p>
          <p class="step-result"><b>Hasil:</b> Penugasan tersimpan ke sistem dan langsung tercatat pada tab Status Tim.</p>
        </div>
      </div>

      <div class="tip-box">
        💡 <b>Catatan:</b> Pastikan perangkat terhubung ke internet saat mengirim tugas. Jika tugas belum muncul, periksa status pengiriman sebelum mengirim ulang.
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
      <span>Panduan Operasional</span>
      <span>•</span>
      <span class="footer-powered">PMAapp powered by annnpii</span>
    </div>
    <span class="slide-num">Halaman 10 / 12</span>
  </div>
</div>

<!-- ====================================================================== -->
<!-- SLIDE 11: PANTAU PROGRES TIM -->
<!-- ====================================================================== -->
<div class="slide light">
  <div class="slide-header">
    <div class="header-left">
      <span class="header-tag spv">MONITORING</span>
      <div class="header-title-box">
        <h1>Pantau Progres Tim</h1>
        <p>Gunakan Status Tim untuk melihat progres tugas, rincian teknisi, dan catatan penyelesaian.</p>
      </div>
    </div>
    <div class="header-brand-badge">
      <img src="data:image/png;base64,{logo_round_b64}" alt="BSS Logo" />
      <span>BSS PARKING • PMAapp</span>
    </div>
  </div>

  <div class="slide-body">
    <div class="content-col">
      <div class="callout-card">
        <div class="callout-badge">1</div>
        <div class="callout-content">
          <h3>Progres Tugas <span class="badge-pill orange">PROGRES</span></h3>
          <p class="step-action"><b>Tindakan:</b> Periksa jumlah atau persentase tugas selesai dibandingkan total tugas pada periode yang ditampilkan.</p>
          <p class="step-result"><b>Hasil:</b> Capaian kerja cabang dapat diketahui secara cepat.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">2</div>
        <div class="callout-content">
          <h3>Filter Status <span class="badge-pill">FILTER</span></h3>
          <p class="step-action"><b>Tindakan:</b> Gunakan filter untuk menampilkan tugas selesai, belum mulai, atau semua tugas.</p>
          <p class="step-result"><b>Hasil:</b> Daftar tugas terfilter rapi untuk mempermudah pengecekan tugas tertunda.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">3</div>
        <div class="callout-content">
          <h3>Detail Tugas <span class="badge-pill">DETAIL</span></h3>
          <p class="step-action"><b>Tindakan:</b> Periksa nama teknisi, judul tugas, dan lokasi pekerjaan.</p>
          <p class="step-result"><b>Hasil:</b> Mengetahui penempatan dan pembagian beban kerja masing-masing petugas.</p>
        </div>
      </div>

      <div class="callout-card">
        <div class="callout-badge">4</div>
        <div class="callout-content">
          <h3>Waktu Selesai dan Catatan <span class="badge-pill green">REKAP</span></h3>
          <p class="step-action"><b>Tindakan:</b> Periksa waktu penyelesaian dan catatan yang tersedia sebelum membuat rekap cabang.</p>
          <p class="step-result"><b>Hasil:</b> Laporan terverifikasi sebelum diringkas ke laporan operasional cabang.</p>
        </div>
      </div>

      <div class="tip-box">
        💡 <b>Catatan:</b> Gunakan tombol kontrol tim untuk membuat ringkasan harian jika fitur tersedia. Pastikan data yang akan dibagikan sudah diperiksa.
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
      <span>Panduan Operasional</span>
      <span>•</span>
      <span class="footer-powered">PMAapp powered by annnpii</span>
    </div>
    <span class="slide-num">Halaman 11 / 12</span>
  </div>
</div>

<!-- ====================================================================== -->
<!-- SLIDE 12: ALUR KERJA, STANDAR, DAN KENDALA -->
<!-- ====================================================================== -->
<div class="slide light">
  <div class="slide-header">
    <div class="header-left">
      <span class="header-tag sop">STANDAR OPERASIONAL</span>
      <div class="header-title-box">
        <h1>Alur Kerja, Standar, dan Kendala</h1>
        <p>Ikuti urutan kerja berikut dan periksa kembali data sebelum menutup shift.</p>
      </div>
    </div>
    <div class="header-brand-badge">
      <img src="data:image/png;base64,{logo_round_b64}" alt="BSS Logo" />
      <span>BSS PARKING • PMAapp</span>
    </div>
  </div>

  <div class="slide-body" style="grid-template-columns: 1fr; align-items: start;">
    <div class="flow-container">
      <div class="flow-row">
        <div class="flow-card">
          <div>
            <div class="flow-num">1</div>
            <h4>Login</h4>
            <p>Masuk dengan akun cabang dan pastikan izin kamera serta lokasi aktif.</p>
          </div>
        </div>

        <div class="flow-card">
          <div>
            <div class="flow-num">2</div>
            <h4>Absensi Masuk</h4>
            <p>Pilih shift yang benar dan ambil foto sesuai instruksi aplikasi.</p>
          </div>
        </div>

        <div class="flow-card accent">
          <div>
            <div class="flow-num">3</div>
            <h4>Tugas dan Maintenance</h4>
            <p>Selesaikan Daily Task dan checklist maintenance sesuai lokasi dan unit.</p>
          </div>
        </div>

        <div class="flow-card">
          <div>
            <div class="flow-num">4</div>
            <h4>Absensi Pulang</h4>
            <p>Periksa tugas serta persyaratan jam kerja sebelum melakukan absensi pulang.</p>
          </div>
        </div>

        <div class="flow-card">
          <div>
            <div class="flow-num">5</div>
            <h4>Pemeriksaan SPV</h4>
            <p>SPV memantau progres, meninjau bukti foto, dan membuat rekap cabang.</p>
          </div>
        </div>
      </div>

      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px; margin-top: 6px;">
        <div style="background: #FFFFFF; border: 1.5px solid #CBD5E1; border-radius: 10px; padding: 12px; box-shadow: 0 2px 6px rgba(15,44,89,0.03);">
          <h3 style="font-size: 13px; color: #0F2C59; font-weight: 800; margin-bottom: 6px; display: flex; align-items: center; gap: 6px;">
            <span style="color: #FF6500;">🛡️</span> STANDAR OPERASIONAL
          </h3>
          <ul style="font-size: 10.5px; color: #334155; line-height: 1.55; padding-left: 16px; font-weight: 500;">
            <li><b>Waktu:</b> Gunakan informasi waktu yang dicatat oleh aplikasi.</li>
            <li><b>Lokasi:</b> Pastikan lokasi tugas benar dan izin lokasi aktif saat diperlukan.</li>
            <li><b>Foto bukti:</b> Ambil foto kondisi perangkat sebenarnya di lapangan.</li>
            <li><b>Penugasan:</b> Ikuti instruksi tugas yang diberikan melalui SPV.</li>
          </ul>
        </div>

        <div style="background: #FFFFFF; border: 1.5px solid #CBD5E1; border-radius: 10px; padding: 12px; box-shadow: 0 2px 6px rgba(15,44,89,0.03);">
          <h3 style="font-size: 13px; color: #0F2C59; font-weight: 800; margin-bottom: 6px; display: flex; align-items: center; gap: 6px;">
            <span style="color: #0F2C59;">🔧</span> PENANGANAN KENDALA
          </h3>
          <ul style="font-size: 10.5px; color: #334155; line-height: 1.55; padding-left: 16px; font-weight: 500;">
            <li><b>Koneksi lemah:</b> Periksa koneksi dan status sinkronisasi. Pastikan data benar-benar terkirim.</li>
            <li><b>Izin kamera/lokasi:</b> Buka setelan browser atau ponsel dan izinkan Camera serta Location.</li>
            <li><b>Gagal absen pulang:</b> Periksa persyaratan durasi shift dan status absensi.</li>
            <li><b>Masalah akun:</b> Hubungi SPV atau Koordinator IT cabang untuk pemeriksaan akun.</li>
          </ul>
        </div>
      </div>
    </div>
  </div>

  <div class="slide-footer">
    <div class="footer-left">
      <span class="footer-brand">PMAapp</span>
      <span>•</span>
      <span>Panduan Operasional</span>
      <span>•</span>
      <span class="footer-powered">PMAapp powered by annnpii</span>
    </div>
    <span class="slide-num">Halaman 12 / 12</span>
  </div>
</div>

</body>
</html>
"""

# Simpan HTML final
with open('docs/PMAapp_Tutorial_Guide_Final.html', 'w', encoding='utf-8') as f:
    f.write(html_content)

print('Compiled HTML slides saved to docs/PMAapp_Tutorial_Guide_Final.html')

# Generate PDF using headless Chrome
cmd = [
    '/usr/bin/google-chrome-stable',
    '--headless=new',
    '--disable-gpu',
    '--no-sandbox',
    '--print-to-pdf-no-header',
    '--print-to-pdf=docs/PMAapp_Tutorial_Guide_Final.pdf',
    'docs/PMAapp_Tutorial_Guide_Final.html'
]
print('Rendering PDF via Chrome...')
res = subprocess.run(cmd, capture_output=True, text=True)
if res.returncode == 0:
    print('PDF successfully generated at docs/PMAapp_Tutorial_Guide_Final.pdf!')
    os.makedirs('web/docs', exist_ok=True)
    subprocess.run(['cp', 'docs/PMAapp_Tutorial_Guide_Final.pdf', 'web/docs/PMAapp_Tutorial_Guide_Final.pdf'])
    print('Copied to web/docs/PMAapp_Tutorial_Guide_Final.pdf')
else:
    print('Chrome render failed:', res.stderr)
