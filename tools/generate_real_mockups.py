import cairo
import math
import os

WIDTH = 2560
HEIGHT = 1440

surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, WIDTH, HEIGHT)
ctx = cairo.Context(surface)

# Background Studio Backdrop (Modern Tech Dark Slate with subtle radiant glow)
ctx.set_source_rgb(0.05, 0.07, 0.10)
ctx.paint()

# Radiant ambient lighting at center
pat = cairo.RadialGradient(WIDTH/2, HEIGHT/2, 200, WIDTH/2, HEIGHT/2, 1200)
pat.add_color_stop_rgba(0, 0.08, 0.12, 0.20, 0.6)
pat.add_color_stop_rgba(1, 0.02, 0.03, 0.05, 0.95)
ctx.set_source(pat)
ctx.paint()

def rounded_rect(c, x, y, w, h, r):
    c.new_sub_path()
    c.arc(x + w - r, y + r, r, -math.pi/2, 0)
    c.arc(x + w - r, y + h - r, r, 0, math.pi/2)
    c.arc(x + r, y + h - r, r, math.pi/2, math.pi)
    c.arc(x + r, y + r, r, math.pi, 3*math.pi/2)
    c.close_path()

def draw_card(c, x, y, w, h, r, fill_rgb, border_rgb=None, border_w=1.0):
    rounded_rect(c, x, y, w, h, r)
    c.set_source_rgb(*fill_rgb)
    c.fill_preserve()
    if border_rgb:
        c.set_source_rgb(*border_rgb)
        c.set_line_width(border_w)
        c.stroke()
    else:
        c.new_path()

# Header Brand & Title
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_source_rgb(1.0, 1.0, 1.0)
ctx.set_font_size(36)
ctx.move_to(80, 75)
ctx.show_text("PMA App — REAL AUDIT & REDESIGN MOCKUP")

ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(18)
ctx.set_source_rgb(0.60, 0.68, 0.80)
ctx.move_to(80, 112)
ctx.show_text("Data Riil Operasional: Mie Gacoan Gorontalo (MGGJ) Gate In 1 • Versi v2.0.86+94")

# Badge Status Header (Top Right)
draw_card(ctx, WIDTH - 480, 50, 400, 50, 25, (0.07, 0.18, 0.32), (0.15, 0.45, 0.85), 1.5)
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(15)
ctx.set_source_rgb(0.35, 0.75, 1.0)
ctx.move_to(WIDTH - 450, 81)
ctx.show_text("⚡ TASTE & IMPECCABLE REDESIGN")

# Draw Phone Device Mockup Helper
def draw_phone_frame(c, x, y, w, h, is_dark_bezel=True):
    # Outer drop shadow
    c.save()
    rounded_rect(c, x - 4, y - 4, w + 8, h + 8, 44)
    c.set_source_rgba(0, 0, 0, 0.5)
    c.fill()
    c.restore()

    # Outer Metal Bezel
    bezel_color = (0.18, 0.20, 0.24) if is_dark_bezel else (0.80, 0.82, 0.86)
    draw_card(c, x, y, w, h, 42, bezel_color, (0.35, 0.38, 0.44), 2.0)

    # Inner Screen Glass
    sx = x + 12
    sy = y + 12
    sw = w - 24
    sh = h - 24
    return (sx, sy, sw, sh)

def draw_status_bar(c, sx, sy, sw, is_dark_mode=False):
    c.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
    c.set_font_size(11)
    if is_dark_mode:
        c.set_source_rgb(0.9, 0.9, 0.95)
    else:
        c.set_source_rgb(0.15, 0.18, 0.22)
    c.move_to(sx + 24, sy + 24)
    c.show_text("14:32")

    # Camera Punch Hole at center
    c.arc(sx + sw/2, sy + 20, 7, 0, 2*math.pi)
    c.set_source_rgb(0.05, 0.05, 0.08)
    c.fill()

    # Battery & WiFi indicators
    c.move_to(sx + sw - 68, sy + 24)
    c.show_text("5G  98%")


# ==============================================================================
# SECTION 1: SEBELUM REDESIGN (KIRI)
# ==============================================================================
COL_W = 1140
COL_H = 1220
Y_TOP = 150

# Left Panel Container
draw_card(ctx, 80, Y_TOP, COL_W, COL_H, 24, (0.08, 0.10, 0.13), (0.25, 0.28, 0.35), 2.0)

# Badge SEBELUM
draw_card(ctx, 110, Y_TOP + 25, 340, 42, 21, (0.42, 0.10, 0.10), (0.85, 0.25, 0.25), 1.5)
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(16)
ctx.set_source_rgb(1.0, 0.7, 0.7)
ctx.move_to(135, Y_TOP + 52)
ctx.show_text("⛔ SEBELUM REDESIGN (ORIGINAL)")

ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(14)
ctx.set_source_rgb(0.65, 0.68, 0.75)
ctx.move_to(475, Y_TOP + 51)
ctx.show_text("Flat Grey Form • Low Sunlight Contrast • Dialog Pop-up Bertingkat")

# --- PHONE 1 (KIRI): LOGIN SCREEN SEBELUM ---
P1_X = 120
P1_Y = Y_TOP + 95
P1_W = 510
P1_H = 1080
s1_x, s1_y, s1_w, s1_h = draw_phone_frame(ctx, P1_X, P1_Y, P1_W, P1_H)

# Canvas phone 1: Flat Dull White/Grey
draw_card(ctx, s1_x, s1_y, s1_w, s1_h, 32, (0.94, 0.94, 0.96))
draw_status_bar(ctx, s1_x, s1_y, s1_w, is_dark_mode=False)

# Header Title Sebelum
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(24)
ctx.set_source_rgb(0.2, 0.2, 0.25)
ctx.move_to(s1_x + 35, s1_y + 110)
ctx.show_text("BssparkingTimeMark")

ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(13)
ctx.set_source_rgb(0.5, 0.5, 0.55)
ctx.move_to(s1_x + 35, s1_y + 138)
ctx.show_text("Silakan login dengan akun Anda")

# Input Box 1 Sebelum: Standard grey outline box
draw_card(ctx, s1_x + 35, s1_y + 180, s1_w - 70, 60, 8, (1.0, 1.0, 1.0), (0.75, 0.75, 0.80), 1.2)
ctx.set_font_size(13)
ctx.set_source_rgb(0.55, 0.55, 0.60)
ctx.move_to(s1_x + 55, s1_y + 216)
ctx.show_text("Username")

# Input Box 2 Sebelum
draw_card(ctx, s1_x + 35, s1_y + 260, s1_w - 70, 60, 8, (1.0, 1.0, 1.0), (0.75, 0.75, 0.80), 1.2)
ctx.set_source_rgb(0.55, 0.55, 0.60)
ctx.move_to(s1_x + 55, s1_y + 296)
ctx.show_text("Password (••••••••)")

# Standard Material Blue Button (Tanpa tactile feel / generic flat)
draw_card(ctx, s1_x + 35, s1_y + 345, s1_w - 70, 56, 8, (0.13, 0.35, 0.75))
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(15)
ctx.set_source_rgb(1.0, 1.0, 1.0)
ctx.move_to(s1_x + 195, s1_y + 380)
ctx.show_text("LOGIN")

# Modal Dialog Pop-up Konfirmasi Sebelum (Mengaburkan dan memperlambat alur)
draw_card(ctx, s1_x + 25, s1_y + 440, s1_w - 50, 450, 16, (1.0, 1.0, 1.0), (0.6, 0.6, 0.65), 2.0)
draw_card(ctx, s1_x + 25, s1_y + 440, s1_w - 50, 55, 16, (0.90, 0.92, 0.95))
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(15)
ctx.set_source_rgb(0.2, 0.25, 0.3)
ctx.move_to(s1_x + 45, s1_y + 475)
ctx.show_text("Konfirmasi Submit Tugas")

ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(13)
ctx.set_source_rgb(0.35, 0.35, 0.4)
ctx.move_to(s1_x + 45, s1_y + 530)
ctx.show_text("Apakah Anda yakin ingin submit?")
ctx.move_to(s1_x + 45, s1_y + 555)
ctx.show_text("Lokasi: Mie Gacoan Gorontalo")
ctx.move_to(s1_x + 45, s1_y + 580)
ctx.show_text("Gate In 1 (Manless Pos)")

# Pale warning box
draw_card(ctx, s1_x + 45, s1_y + 615, s1_w - 90, 80, 8, (1.0, 0.98, 0.90), (0.9, 0.8, 0.6), 1.0)
ctx.set_font_size(12)
ctx.set_source_rgb(0.65, 0.50, 0.15) # Pale amber (sukar dibaca saat matahari terik)
ctx.move_to(s1_x + 60, s1_y + 645)
ctx.show_text("⚠️ Warning: Validasi AI Per-Point")
ctx.move_to(s1_x + 60, s1_y + 670)
ctx.show_text("Semua item foto harus sesuai SOP.")

# Pop-up Buttons (Inggris campur)
draw_card(ctx, s1_x + 45, s1_y + 720, 180, 48, 8, (0.88, 0.89, 0.92))
ctx.set_font_size(13)
ctx.set_source_rgb(0.3, 0.35, 0.4)
ctx.move_to(s1_x + 105, s1_y + 750)
ctx.show_text("Cancel")

draw_card(ctx, s1_x + 240, s1_y + 720, 195, 48, 8, (0.13, 0.35, 0.75))
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(13)
ctx.set_source_rgb(1.0, 1.0, 1.0)
ctx.move_to(s1_x + 285, s1_y + 750)
ctx.show_text("Submit Form")


# --- PHONE 2 (KIRI): CHECKLIST MAINTENANCE SEBELUM ---
P2_X = 660
P2_Y = Y_TOP + 95
P2_W = 510
P2_H = 1080
s2_x, s2_y, s2_w, s2_h = draw_phone_frame(ctx, P2_X, P2_Y, P2_W, P2_H)

# Canvas phone 2
draw_card(ctx, s2_x, s2_y, s2_w, s2_h, 32, (0.95, 0.96, 0.97))
draw_status_bar(ctx, s2_x, s2_y, s2_w, is_dark_mode=False)

# Appbar Sebelum: Plain Dark Navy
draw_card(ctx, s2_x, s2_y + 40, s2_w, 80, 0, (0.10, 0.22, 0.48))
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(18)
ctx.set_source_rgb(1.0, 1.0, 1.0)
ctx.move_to(s2_x + 30, s2_y + 82)
ctx.show_text("Checklist Maintenance")
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(12)
ctx.set_source_rgb(0.75, 0.85, 0.95)
ctx.move_to(s2_x + 30, s2_y + 104)
ctx.show_text("Mie Gacoan Gorontalo • Gate In 1")

# Item 1 Sebelum: Pembersihan Printer
cy1 = s2_y + 145
draw_card(ctx, s2_x + 25, cy1, s2_w - 50, 150, 12, (1.0, 1.0, 1.0), (0.85, 0.86, 0.88), 1.0)
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(15)
ctx.set_source_rgb(0.2, 0.2, 0.25)
ctx.move_to(s2_x + 45, cy1 + 35)
ctx.show_text("1. Pembersihan total printer tiket")

# Pale Green Badge
draw_card(ctx, s2_x + 45, cy1 + 52, 110, 28, 6, (0.92, 0.98, 0.94), (0.7, 0.9, 0.75), 1.0)
ctx.set_font_size(12)
ctx.set_source_rgb(0.3, 0.65, 0.4)
ctx.move_to(s2_x + 60, cy1 + 71)
ctx.show_text("✓ Sesuai")

ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(12)
ctx.set_source_rgb(0.45, 0.48, 0.52)
ctx.move_to(s2_x + 45, cy1 + 108)
ctx.show_text("Ruang printer tampak bersih, bebas debu.")
ctx.move_to(s2_x + 45, cy1 + 128)
ctx.show_text("Kertas roll terpasang rapi.")

# Item 2 Sebelum: Dudukan Bawah (Pale Yellow Badge)
cy2 = cy1 + 175
draw_card(ctx, s2_x + 25, cy2, s2_w - 50, 150, 12, (1.0, 1.0, 1.0), (0.85, 0.86, 0.88), 1.0)
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(15)
ctx.set_source_rgb(0.2, 0.2, 0.25)
ctx.move_to(s2_x + 45, cy2 + 35)
ctx.show_text("6. Dudukan bawah manless ke pulau")

# Pale Yellow Badge (Sangat sulit terlihat di bawah matahari)
draw_card(ctx, s2_x + 45, cy2 + 52, 140, 28, 6, (1.0, 0.98, 0.88), (0.95, 0.88, 0.65), 1.0)
ctx.set_font_size(12)
ctx.set_source_rgb(0.70, 0.55, 0.15) # Pale & low contrast
ctx.move_to(s2_x + 58, cy2 + 71)
ctx.show_text("! Tidak Sesuai")

ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(12)
ctx.set_source_rgb(0.45, 0.48, 0.52)
ctx.move_to(s2_x + 45, cy2 + 108)
ctx.show_text("Dudukan kotor, debu tebal pada sudut.")
ctx.move_to(s2_x + 45, cy2 + 128)
ctx.show_text("Baut pondasi dynabolt mulai kendor.")

# Camera Viewfinder Sebelum (Tanpa quick zoom pills, tombol sempit)
cy3 = cy2 + 185
draw_card(ctx, s2_x + 25, cy3, s2_w - 50, 360, 16, (0.1, 0.12, 0.15))
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(13)
ctx.set_source_rgb(0.7, 0.75, 0.85)
ctx.move_to(s2_x + 45, cy3 + 35)
ctx.show_text("CAMERA HUD (SEBELUM)")

# Viewfinder dummy box
draw_card(ctx, s2_x + 45, cy3 + 55, s2_w - 90, 200, 8, (0.05, 0.06, 0.08), (0.3, 0.35, 0.45), 1.0)
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(11)
ctx.set_source_rgb(0.6, 0.65, 0.75)
ctx.move_to(s2_x + 60, cy3 + 95)
ctx.show_text("GPS: 0.5432 N, 123.0621 E (Teks tipis)")
ctx.move_to(s2_x + 60, cy3 + 120)
ctx.show_text("Tombol zoom: [TIDAK ADA SHORTCUT]")
ctx.move_to(s2_x + 60, cy3 + 145)
ctx.show_text("Pinch-to-zoom manual sulit saat pakai sarung tangan")

# Shutter button sebelum (kecil 52dp)
c_cx = s2_x + s2_w/2
c_cy = cy3 + 300
ctx.arc(c_cx, c_cy, 28, 0, 2*math.pi)
ctx.set_source_rgb(0.85, 0.85, 0.88)
ctx.fill()


# ==============================================================================
# SECTION 2: SESUDAH REDESIGN (KANAN)
# ==============================================================================
RX_TOP = WIDTH/2 + 20
draw_card(ctx, RX_TOP, Y_TOP, COL_W, COL_H, 24, (0.07, 0.12, 0.18), (0.15, 0.45, 0.70), 2.0)

# Badge SESUDAH
draw_card(ctx, RX_TOP + 30, Y_TOP + 25, 360, 42, 21, (0.05, 0.35, 0.22), (0.2, 0.85, 0.50), 1.5)
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(16)
ctx.set_source_rgb(0.5, 1.0, 0.7)
ctx.move_to(RX_TOP + 55, Y_TOP + 52)
ctx.show_text("✨ SESUDAH REDESIGN (IMPECCABLE)")

ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(14)
ctx.set_source_rgb(0.68, 0.85, 0.95)
ctx.move_to(RX_TOP + 415, Y_TOP + 51)
ctx.show_text("Tactile R20 Card • Plus Jakarta Sans • Sunlight Proof • Quick Zoom")


# --- PHONE 3 (KANAN): LOGIN SCREEN SESUDAH (IMPECCABLE TASTE) ---
P3_X = RX_TOP + 40
P3_Y = Y_TOP + 95
P3_W = 510
P3_H = 1080
s3_x, s3_y, s3_w, s3_h = draw_phone_frame(ctx, P3_X, P3_Y, P3_W, P3_H)

# Canvas phone 3: Warm Ivory & Professional Enterprise Slate
draw_card(ctx, s3_x, s3_y, s3_w, s3_h, 32, (0.98, 0.97, 0.95)) # Warm Ivory
draw_status_bar(ctx, s3_x, s3_y, s3_w, is_dark_mode=False)

# Theme Toggle Pill (Top Right)
draw_card(ctx, s3_x + s3_w - 120, s3_y + 40, 95, 32, 16, (1.0, 1.0, 1.0), (0.85, 0.88, 0.92), 1.0)
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(11)
ctx.set_source_rgb(0.12, 0.27, 0.55)
ctx.move_to(s3_x + s3_w - 105, s3_y + 61)
ctx.show_text("🌙 Gelap")

# Sleek Brand Pill Badge
draw_card(ctx, s3_x + s3_w/2 - 130, s3_y + 90, 260, 32, 16, (0.92, 0.95, 1.0), (0.75, 0.85, 0.98), 1.0)
# Dot orange
ctx.arc(s3_x + s3_w/2 - 110, s3_y + 106, 4, 0, 2*math.pi)
ctx.set_source_rgb(1.0, 0.42, 0.0)
ctx.fill()
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(10)
ctx.set_source_rgb(0.12, 0.27, 0.55)
ctx.move_to(s3_x + s3_w/2 - 98, s3_y + 110)
ctx.show_text("PORTAL OPERASIONAL LAPANGAN")

# Logo BSS Resmi Berpendar Orange
l_cx = s3_x + s3_w/2
l_cy = s3_y + 175
ctx.arc(l_cx, l_cy, 42, 0, 2*math.pi)
ctx.set_source_rgb(0.12, 0.27, 0.55) # BSS Primary
ctx.fill()
ctx.arc(l_cx, l_cy, 42, 0, 2*math.pi)
ctx.set_source_rgb(1.0, 0.42, 0.0) # Accent border
ctx.set_line_width(2.5)
ctx.stroke()

ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(20)
ctx.set_source_rgb(1.0, 1.0, 1.0)
ctx.move_to(l_cx - 24, l_cy + 8)
ctx.show_text("PMA")

# Title App
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(24)
ctx.set_source_rgb(0.06, 0.09, 0.16)
ctx.move_to(s3_x + s3_w/2 - 60, s3_y + 248)
ctx.show_text("PMA App")

ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(12)
ctx.set_source_rgb(0.40, 0.45, 0.55)
ctx.move_to(s3_x + s3_w/2 - 142, s3_y + 272)
ctx.show_text("Absen Waktu, Maintenance & Tugas")

# Tactile Card Container R20
c3_y = s3_y + 295
draw_card(ctx, s3_x + 30, c3_y, s3_w - 60, 480, 20, (1.0, 1.0, 1.0), (0.88, 0.91, 0.95), 1.2)

# Field 1: Email / Username
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(12)
ctx.set_source_rgb(0.28, 0.33, 0.42)
ctx.move_to(s3_x + 55, c3_y + 40)
ctx.show_text("Email atau Username")

draw_card(ctx, s3_x + 55, c3_y + 52, s3_w - 110, 56, 14, (0.97, 0.98, 0.99), (0.80, 0.84, 0.90), 1.2)
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(13)
ctx.set_source_rgb(0.1, 0.15, 0.22)
ctx.move_to(s3_x + 75, c3_y + 86)
ctx.show_text("farhan.lakoro@bssparking.com")

# Field 2: Kata Sandi
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(12)
ctx.set_source_rgb(0.28, 0.33, 0.42)
ctx.move_to(s3_x + 55, c3_y + 138)
ctx.show_text("Kata Sandi Akun")

draw_card(ctx, s3_x + 55, c3_y + 150, s3_w - 110, 56, 14, (0.97, 0.98, 0.99), (1.0, 0.42, 0.0), 1.8) # Focus Highlight Orange!
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(14)
ctx.set_source_rgb(0.1, 0.15, 0.22)
ctx.move_to(s3_x + 75, c3_y + 185)
ctx.show_text("••••••••••••••")

# Tombol Taktil Safety Orange
draw_card(ctx, s3_x + 55, c3_y + 240, s3_w - 110, 58, 14, (1.0, 0.42, 0.0))
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(15)
ctx.set_source_rgb(1.0, 1.0, 1.0)
ctx.move_to(s3_x + 135, c3_y + 276)
ctx.show_text("MASUK APLIKASI  ➔")

# Enterprise Security Badge Footer
draw_card(ctx, s3_x + 50, c3_y + 360, s3_w - 100, 75, 12, (0.94, 0.96, 1.0), (0.80, 0.88, 0.98), 1.0)
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(11)
ctx.set_source_rgb(0.12, 0.27, 0.55)
ctx.move_to(s3_x + 75, c3_y + 392)
ctx.show_text("🛡️ ENKRIPSI & KEAMANAN SISTEM")

ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(10)
ctx.set_source_rgb(0.35, 0.45, 0.60)
ctx.move_to(s3_x + 75, c3_y + 414)
ctx.show_text("v2.0.86+94 • BSS Enterprise Parking Protocol")


# --- PHONE 4 (KANAN): CAMERA HUD & MAINTENANCE CHECKLIST SESUDAH ---
P4_X = RX_TOP + 580
P4_Y = Y_TOP + 95
P4_W = 510
P4_H = 1080
s4_x, s4_y, s4_w, s4_h = draw_phone_frame(ctx, P4_X, P4_Y, P4_W, P4_H)

# Canvas phone 4: Dark Slate Tactical Field HUD
draw_card(ctx, s4_x, s4_y, s4_w, s4_h, 32, (0.06, 0.09, 0.14)) # Tactical Deep Slate
draw_status_bar(ctx, s4_x, s4_y, s4_w, is_dark_mode=True)

# Top Bar Tactical
draw_card(ctx, s4_x, s4_y + 40, s4_w, 75, 0, (0.08, 0.13, 0.22))
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(16)
ctx.set_source_rgb(1.0, 1.0, 1.0)
ctx.move_to(s4_x + 25, s4_y + 75)
ctx.show_text("Pengecekan Gate In 1")

ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(11)
ctx.set_source_rgb(0.4, 0.8, 1.0)
ctx.move_to(s4_x + 25, s4_y + 98)
ctx.show_text("Mie Gacoan Gorontalo (MGGJ)")

# Offline Queue pill top right
draw_card(ctx, s4_x + s4_w - 150, s4_y + 55, 125, 28, 14, (0.03, 0.25, 0.18), (0.2, 0.8, 0.5), 1.0)
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(10)
ctx.set_source_rgb(0.4, 1.0, 0.7)
ctx.move_to(s4_x + s4_w - 138, s4_y + 73)
ctx.show_text("☁️ Tersinkron")

# Real Viewfinder with Tactical Reticle
v_y = s4_y + 125
draw_card(ctx, s4_x + 18, v_y, s4_w - 36, 460, 18, (0.02, 0.04, 0.07), (0.2, 0.4, 0.6), 1.5)

# Watermark GPS Overlay Card (Semi-transparent dark glass)
draw_card(ctx, s4_x + 30, v_y + 18, s4_w - 60, 85, 12, (0.05, 0.08, 0.12), (0.25, 0.35, 0.50), 1.0)
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(11)
ctx.set_source_rgb(1.0, 0.75, 0.2)
ctx.move_to(s4_x + 45, v_y + 42)
ctx.show_text("📍 MIE GACOAN GORONTALO (MGGJ)")

ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(10)
ctx.set_source_rgb(0.85, 0.90, 0.95)
ctx.move_to(s4_x + 45, v_y + 64)
ctx.show_text("GPS: 0.5432° N, 123.0621° E • Akurasi 3.2m")
ctx.move_to(s4_x + 45, v_y + 84)
ctx.show_text("Waktu: 14 Okt 2026 14:32:05 WITA • Shift Pagi")

# Tactical Viewfinder Crosshair in center
vx_c = s4_x + s4_w/2
vy_c = v_y + 220
ctx.set_source_rgb(0.3, 0.7, 1.0)
ctx.set_line_width(2.0)
# Top-left corner
ctx.move_to(vx_c - 120, vy_c - 60)
ctx.line_to(vx_c - 90, vy_c - 60)
ctx.move_to(vx_c - 120, vy_c - 60)
ctx.line_to(vx_c - 120, vy_c - 30)
# Top-right corner
ctx.move_to(vx_c + 120, vy_c - 60)
ctx.line_to(vx_c + 90, vy_c - 60)
ctx.move_to(vx_c + 120, vy_c - 60)
ctx.line_to(vx_c + 120, vy_c - 30)
# Bottom-left corner
ctx.move_to(vx_c - 120, vy_c + 60)
ctx.line_to(vx_c - 90, vy_c + 60)
ctx.move_to(vx_c - 120, vy_c + 60)
ctx.line_to(vx_c - 120, vy_c + 30)
# Bottom-right corner
ctx.move_to(vx_c + 120, vy_c + 60)
ctx.line_to(vx_c + 90, vy_c + 60)
ctx.move_to(vx_c + 120, vy_c + 60)
ctx.line_to(vx_c + 120, vy_c + 30)
ctx.stroke()

# Quick Zoom Pills (44x44dp touch target)
z_y = v_y + 395
# Pill 0.5x
draw_card(ctx, vx_c - 110, z_y, 48, 36, 10, (0.12, 0.16, 0.22), (0.3, 0.35, 0.45), 1.0)
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(11)
ctx.set_source_rgb(0.7, 0.75, 0.85)
ctx.move_to(vx_c - 100, z_y + 23)
ctx.show_text("0.5x")

# Pill 1x (Active Safety Orange)
draw_card(ctx, vx_c - 50, z_y, 48, 36, 10, (1.0, 0.42, 0.0))
ctx.set_source_rgb(1.0, 1.0, 1.0)
ctx.move_to(vx_c - 38, z_y + 23)
ctx.show_text("1x")

# Pill 2x
draw_card(ctx, vx_c + 10, z_y, 48, 36, 10, (0.12, 0.16, 0.22), (0.3, 0.35, 0.45), 1.0)
ctx.set_source_rgb(0.7, 0.75, 0.85)
ctx.move_to(vx_c + 22, z_y + 23)
ctx.show_text("2x")

# Pill 5x
draw_card(ctx, vx_c + 70, z_y, 48, 36, 10, (0.12, 0.16, 0.22), (0.3, 0.35, 0.45), 1.0)
ctx.set_source_rgb(0.7, 0.75, 0.85)
ctx.move_to(vx_c + 82, z_y + 23)
ctx.show_text("5x")

# Real Checklist Cards (High-Contrast Outdoor Sunlight Proof)
c_top = v_y + 480

# Item 1: Printer Tiket Manless
draw_card(ctx, s4_x + 18, c_top, s4_w - 36, 110, 14, (0.10, 0.15, 0.24), (0.2, 0.3, 0.45), 1.2)
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(13)
ctx.set_source_rgb(0.95, 0.98, 1.0)
ctx.move_to(s4_x + 35, c_top + 30)
ctx.show_text("1. Pembersihan Printer Tiket")

# Solid Emerald Badge
draw_card(ctx, s4_x + s4_w - 140, c_top + 15, 105, 26, 6, (0.05, 0.55, 0.32))
ctx.set_font_size(10)
ctx.set_source_rgb(1.0, 1.0, 1.0)
ctx.move_to(s4_x + s4_w - 128, c_top + 32)
ctx.show_text("✓ SESUAI")

ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(11)
ctx.set_source_rgb(0.75, 0.82, 0.90)
ctx.move_to(s4_x + 35, c_top + 62)
ctx.show_text("Thermal head bersih, roll tiket terisi penuh.")
ctx.move_to(s4_x + 35, c_top + 84)
ctx.show_text("Test cetak barcode: QR Code terbaca instan.")

# Item 2: Sensor Loop & Dudukan Barrier (High-Contrast Solid Amber)
c_top2 = c_top + 125
draw_card(ctx, s4_x + 18, c_top2, s4_w - 36, 110, 14, (0.10, 0.15, 0.24), (0.2, 0.3, 0.45), 1.2)
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(13)
ctx.set_source_rgb(0.95, 0.98, 1.0)
ctx.move_to(s4_x + 35, c_top2 + 30)
ctx.show_text("6. Dudukan Bawah Manless")

# Solid Deep Amber Badge (Sunlight Proof)
draw_card(ctx, s4_x + s4_w - 180, c_top2 + 15, 145, 26, 6, (0.75, 0.28, 0.05))
ctx.set_font_size(10)
ctx.set_source_rgb(1.0, 1.0, 1.0)
ctx.move_to(s4_x + s4_w - 168, c_top2 + 32)
ctx.show_text("⚠️ PERLU TINDAKAN")

ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(11)
ctx.set_source_rgb(0.75, 0.82, 0.90)
ctx.move_to(s4_x + 35, c_top2 + 62)
ctx.show_text("Debu tebal pada sudut housing & baut kendor.")
ctx.move_to(s4_x + 35, c_top2 + 84)
ctx.show_text("AI Insight: Disarankan pengencangan baut M10.")

# AI Assistant One-Liner Box
c_top3 = c_top2 + 125
draw_card(ctx, s4_x + 18, c_top3, s4_w - 36, 95, 12, (0.05, 0.15, 0.30), (0.2, 0.5, 0.85), 1.2)
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(11)
ctx.set_source_rgb(0.4, 0.85, 1.0)
ctx.move_to(s4_x + 35, c_top3 + 28)
ctx.show_text("🤖 Asisten AI Lapangan:")

ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(10)
ctx.set_source_rgb(0.85, 0.92, 1.0)
ctx.move_to(s4_x + 35, c_top3 + 52)
ctx.show_text("\"Bukti foto tajam & koordinat GPS valid.")
ctx.move_to(s4_x + 35, c_top3 + 72)
ctx.show_text("Pengecekan siap disubmit ke SPV.\"")

# Bottom Shutter & Submit Trigger
b_shutter_y = c_top3 + 115
# Outer Ring
ctx.arc(s4_x + s4_w/2, b_shutter_y + 36, 36, 0, 2*math.pi)
ctx.set_source_rgb(1.0, 0.42, 0.0)
ctx.fill()
# Inner Core
ctx.arc(s4_x + s4_w/2, b_shutter_y + 36, 28, 0, 2*math.pi)
ctx.set_source_rgb(1.0, 1.0, 1.0)
ctx.fill()

out_path = "docs/screenshots/real_mockup_before_after.png"
os.makedirs(os.path.dirname(out_path), exist_ok=True)
surface.write_to_png(out_path)
print(f"SUCCESS: Real mockup comparison written to {out_path}")
