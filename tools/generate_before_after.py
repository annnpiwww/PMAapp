import cairo
import math

WIDTH = 1920
HEIGHT = 1080

surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, WIDTH, HEIGHT)
ctx = cairo.Context(surface)

# Background canvas: Sleek deep slate
ctx.set_source_rgb(0.06, 0.08, 0.11)  # #0F141C
ctx.paint()

# Title Header Banner
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_source_rgb(1.0, 1.0, 1.0)
ctx.set_font_size(30)
ctx.move_to(60, 58)
ctx.show_text("BSS PARKING TIMEMARK — AUDIT UI/UX, FITUR & KONTRAST")

ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(16)
ctx.set_source_rgb(0.65, 0.70, 0.78)
ctx.move_to(60, 92)
ctx.show_text("Komparasi Desain Real Data: Mie Gacoan Gorontalo Jhon (MGGJ) — Gate In 1")

# Helper round rect
def draw_card(c, x, y, w, h, r, fill_rgb, border_rgb=None, border_w=1):
    c.new_sub_path()
    c.arc(x + w - r, y + r, r, -math.pi/2, 0)
    c.arc(x + w - r, y + h - r, r, 0, math.pi/2)
    c.arc(x + r, y + h - r, r, math.pi/2, math.pi)
    c.arc(x + r, y + r, r, math.pi, 3*math.pi/2)
    c.close_path()
    c.set_source_rgb(*fill_rgb)
    c.fill_preserve()
    if border_rgb:
        c.set_source_rgb(*border_rgb)
        c.set_line_width(border_w)
        c.stroke()
    else:
        c.new_path()

# Left Column: SEBELUM (BEFORE)
LX = 60
LY = 125
LW = 875
LH = 910

# Container Left
draw_card(ctx, LX, LY, LW, LH, 16, (0.09, 0.11, 0.14), (0.22, 0.25, 0.30), 2)

# Badge Header Left: SEBELUM (Lebih lebar biar tidak nabrak teks)
draw_card(ctx, LX + 25, LY + 20, 240, 36, 18, (0.45, 0.12, 0.12), (0.8, 0.25, 0.25), 1.5)
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(14)
ctx.set_source_rgb(1.0, 0.6, 0.6)
ctx.move_to(LX + 40, LY + 44)
ctx.show_text("SEBELUM (KONDISI AWAL)")

# Left Subtitle
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(13)
ctx.set_source_rgb(0.7, 0.72, 0.76)
ctx.move_to(LX + 285, LY + 43)
ctx.show_text("Kontras outdoor rendah • Istilah campur • Modal bertingkat")

# Mockup Phone Left
PX = LX + 35
PY = LY + 80
PW = 405
PH = 800
draw_card(ctx, PX, PY, PW, PH, 28, (0.96, 0.96, 0.97), (0.75, 0.75, 0.78), 2)

# Screen Top Appbar (Before)
draw_card(ctx, PX, PY, PW, 75, 0, (0.10, 0.26, 0.54)) # Navy
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(16)
ctx.set_source_rgb(1.0, 1.0, 1.0)
ctx.move_to(PX + 25, PY + 40)
ctx.show_text("Checklist Maintenance")
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(11)
ctx.set_source_rgb(0.8, 0.85, 0.95)
ctx.move_to(PX + 25, PY + 60)
ctx.show_text("Mie Gacoan Gorontalo • Gate 1")

# Screen Content Items (Before)
item_y = PY + 95

# Item 1: Printer Tiket (OK)
draw_card(ctx, PX + 15, item_y, PW - 30, 98, 10, (1.0, 1.0, 1.0), (0.85, 0.85, 0.87), 1)
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(13)
ctx.set_source_rgb(0.2, 0.2, 0.2)
ctx.move_to(PX + 30, item_y + 24)
ctx.show_text("1. Pembersihan total printer tiket")

# Pale green badge (low outdoor readability)
draw_card(ctx, PX + 30, item_y + 36, 85, 22, 6, (0.92, 0.98, 0.94), (0.7, 0.9, 0.8), 1)
ctx.set_font_size(11)
ctx.set_source_rgb(0.3, 0.6, 0.4)
ctx.move_to(PX + 42, item_y + 51)
ctx.show_text("✓ Sesuai")

ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(11)
ctx.set_source_rgb(0.5, 0.5, 0.55)
ctx.move_to(PX + 30, item_y + 78)
ctx.show_text("Ruang printer tampak bersih, bebas debu.")

# Item 2: Dudukan Bawah (Warning - PALE AMBER)
item_y += 112
draw_card(ctx, PX + 15, item_y, PW - 30, 98, 10, (1.0, 1.0, 1.0), (0.85, 0.85, 0.87), 1)
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(13)
ctx.set_source_rgb(0.2, 0.2, 0.2)
ctx.move_to(PX + 30, item_y + 24)
ctx.show_text("6. Dudukan bawah manless ke pulau")

# Pale yellow/amber badge (hard to see under sunlight)
draw_card(ctx, PX + 30, item_y + 36, 120, 22, 6, (1.0, 0.97, 0.88), (0.98, 0.88, 0.70), 1)
ctx.set_font_size(11)
ctx.set_source_rgb(0.75, 0.60, 0.20)  # PALE & LOW CONTRAST
ctx.move_to(PX + 40, item_y + 51)
ctx.show_text("! Tidak Sesuai")

ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(11)
ctx.set_source_rgb(0.55, 0.55, 0.55)
ctx.move_to(PX + 30, item_y + 78)
ctx.show_text("Dudukan bawah tampak kotor berdebu.")

# Item 3: Modal konfirmasi menumpuk (Simulasi dialog kaku)
item_y += 125
draw_card(ctx, PX + 20, item_y, PW - 40, 180, 12, (1.0, 1.0, 1.0), (0.75, 0.75, 0.80), 2)
draw_card(ctx, PX + 20, item_y, PW - 40, 38, 0, (0.92, 0.93, 0.95))
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(12)
ctx.set_source_rgb(0.2, 0.2, 0.25)
ctx.move_to(PX + 35, item_y + 25)
ctx.show_text("Konfirmasi Submission (Per-Point)")

ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(11)
ctx.set_source_rgb(0.4, 0.4, 0.45)
ctx.move_to(PX + 35, item_y + 65)
ctx.show_text("Apakah Anda yakin ingin submit data ini?")
ctx.move_to(PX + 35, item_y + 85)
ctx.show_text("Foto harus lolos AI per-point validation.")

# Generic english button
draw_card(ctx, PX + 35, item_y + 115, 150, 42, 8, (0.88, 0.88, 0.90))
ctx.set_font_size(12)
ctx.set_source_rgb(0.3, 0.3, 0.35)
ctx.move_to(PX + 80, item_y + 142)
ctx.show_text("Cancel")

draw_card(ctx, PX + 200, item_y + 115, 150, 42, 8, (0.15, 0.40, 0.85))
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(12)
ctx.set_source_rgb(1.0, 1.0, 1.0)
ctx.move_to(PX + 230, item_y + 142)
ctx.show_text("Submit Form")

# Pain point callouts left
callout_x = LX + 465
callout_y = LY + 105
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(16)
ctx.set_source_rgb(1.0, 0.45, 0.45)
ctx.move_to(callout_x, callout_y)
ctx.show_text("TEMUAN AUDIT AWAL:")

points_before = [
    ("1. Visibilitas Outdoor Rendah", "Badge kuning muda pudar & sulit terbaca di bawah matahari."),
    ("2. Istilah Campur-Campur", "'Submit Submission' & 'Per-Point' membingungkan teknisi."),
    ("3. Kamera Tanpa Zoom Cepat", "Susah foto baut & sensor loop tanpa menempelkan fisik HP."),
    ("4. Tidak Ada Status Sync Offline", "Teknisi basement cemas data tersimpan aman atau hilang."),
    ("5. Dialog Menumpuk", "Banyak tombol popup konfirmasi yang memperlambat kerja.")
]

cy = callout_y + 35
for title, desc in points_before:
    draw_card(ctx, callout_x, cy, 380, 80, 8, (0.14, 0.16, 0.20), (0.28, 0.30, 0.36), 1)
    ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
    ctx.set_font_size(13)
    ctx.set_source_rgb(1.0, 0.75, 0.75)
    ctx.move_to(callout_x + 15, cy + 28)
    ctx.show_text(title)
    
    ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
    ctx.set_font_size(11)
    ctx.set_source_rgb(0.70, 0.72, 0.78)
    ctx.move_to(callout_x + 15, cy + 54)
    ctx.show_text(desc)
    cy += 98


# Right Column: SESUDAH (AFTER / SOLUSI)
RX = 985
RY = 125
RW = 875
RH = 910

# Container Right
draw_card(ctx, RX, RY, RW, RH, 16, (0.08, 0.13, 0.18), (0.16, 0.40, 0.60), 2)

# Badge Header Right: SESUDAH
draw_card(ctx, RX + 25, RY + 20, 260, 36, 18, (0.05, 0.35, 0.25), (0.2, 0.8, 0.5), 1.5)
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(14)
ctx.set_source_rgb(0.5, 1.0, 0.7)
ctx.move_to(RX + 40, LY + 44)
ctx.show_text("SESUDAH (REKOMENDASI)")

ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(13)
ctx.set_source_rgb(0.7, 0.85, 0.95)
ctx.move_to(RX + 305, LY + 43)
ctx.show_text("Kontras solid outdoor • Istilah lugas • Zoom & Quick Sync")

# Mockup Phone Right
QX = RX + 35
QY = RY + 80
QW = 405
QH = 800
draw_card(ctx, QX, QY, QW, QH, 28, (0.98, 0.97, 0.94), (0.2, 0.45, 0.75), 2.5) # Warm Ivory surface

# Screen Top Appbar (After: Tactical Header with Offline Queue Badge)
draw_card(ctx, QX, QY, QW, 78, 0, (0.10, 0.26, 0.54)) # BSS Royal Blue
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(16)
ctx.set_source_rgb(1.0, 1.0, 1.0)
ctx.move_to(QX + 25, QY + 38)
ctx.show_text("Pengecekan Manless")

ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(11)
ctx.set_source_rgb(0.9, 0.92, 0.98)
ctx.move_to(QX + 25, QY + 60)
ctx.show_text("MGGJ • Gate In 1")

# Offline Sync Queue Badge (Top Right)
draw_card(ctx, QX + 235, QY + 24, 150, 30, 15, (0.05, 0.15, 0.35), (0.3, 0.6, 0.9), 1.2)
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(10)
ctx.set_source_rgb(0.4, 0.8, 1.0)
ctx.move_to(QX + 248, QY + 44)
ctx.show_text("☁️ 2 Antrean Sync")

# Camera Quick Bar / Pinch Zoom Tool
item_y2 = QY + 92
draw_card(ctx, QX + 15, item_y2, QW - 30, 50, 10, (0.94, 0.92, 0.87), (0.85, 0.80, 0.72), 1)
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(11)
ctx.set_source_rgb(0.1, 0.25, 0.5)
ctx.move_to(QX + 28, item_y2 + 30)
ctx.show_text("ALAT KAMERA:")

# Zoom Pills (1x, 2x)
draw_card(ctx, QX + 145, item_y2 + 10, 48, 30, 6, (1.0, 0.4, 0.0)) # Safety Orange
ctx.set_source_rgb(1.0, 1.0, 1.0)
ctx.move_to(QX + 158, item_y2 + 30)
ctx.show_text("1x")

draw_card(ctx, QX + 200, item_y2 + 10, 48, 30, 6, (1.0, 1.0, 1.0), (0.8, 0.8, 0.8), 1)
ctx.set_source_rgb(0.3, 0.3, 0.3)
ctx.move_to(QX + 213, item_y2 + 30)
ctx.show_text("2x")

# Haptic Icon pill
draw_card(ctx, QX + 260, item_y2 + 10, 115, 30, 6, (0.9, 0.95, 0.92))
ctx.set_font_size(10)
ctx.set_source_rgb(0.1, 0.5, 0.3)
ctx.move_to(QX + 272, item_y2 + 30)
ctx.show_text("📳 Haptic Aktif")

# Item 1: Printer Tiket (High Contrast Emerald)
item_y2 += 62
draw_card(ctx, QX + 15, item_y2, QW - 30, 105, 10, (1.0, 1.0, 1.0), (0.88, 0.85, 0.80), 1)
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(13)
ctx.set_source_rgb(0.1, 0.1, 0.15)
ctx.move_to(QX + 30, item_y2 + 25)
ctx.show_text("1. Pembersihan printer tiket")

# High Contrast Solid Emerald Badge
draw_card(ctx, QX + 30, item_y2 + 36, 100, 26, 6, (0.05, 0.55, 0.35))
ctx.set_font_size(11)
ctx.set_source_rgb(1.0, 1.0, 1.0)
ctx.move_to(QX + 44, item_y2 + 54)
ctx.show_text("✅ SESUAI")

ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(11)
ctx.set_source_rgb(0.3, 0.3, 0.35)
ctx.move_to(QX + 30, item_y2 + 82)
ctx.show_text("Ruang kertas printer bersih bebas debu.")

# Item 2: Dudukan Bawah (High Contrast Deep Amber / Sunlight Proof)
item_y2 += 118
draw_card(ctx, QX + 15, item_y2, QW - 30, 105, 10, (1.0, 1.0, 1.0), (0.88, 0.85, 0.80), 1)
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(13)
ctx.set_source_rgb(0.1, 0.1, 0.15)
ctx.move_to(QX + 30, item_y2 + 25)
ctx.show_text("6. Dudukan bawah manless")

# Solid Deep Amber Badge (Ultra Readable in Sunlight)
draw_card(ctx, QX + 30, item_y2 + 36, 140, 26, 6, (0.75, 0.25, 0.05))
ctx.set_font_size(11)
ctx.set_source_rgb(1.0, 1.0, 1.0)
ctx.move_to(QX + 42, item_y2 + 54)
ctx.show_text("⚠️ TIDAK SESUAI")

ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(11)
ctx.set_source_rgb(0.3, 0.3, 0.35)
ctx.move_to(QX + 30, item_y2 + 82)
ctx.show_text("Dudukan kotor, debu tebal di sudut.")

# AI Assistant Insight Card (One-Liner Direct Fact)
item_y2 += 120
draw_card(ctx, QX + 15, item_y2, QW - 30, 98, 10, (0.92, 0.95, 1.0), (0.6, 0.75, 0.95), 1.2)
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(12)
ctx.set_source_rgb(0.1, 0.3, 0.65)
ctx.move_to(QX + 30, item_y2 + 24)
ctx.show_text("🤖 Analisis AI Gemini (1 Kalimat Fakta):")

ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
ctx.set_font_size(11)
ctx.set_source_rgb(0.15, 0.25, 0.45)
ctx.move_to(QX + 30, item_y2 + 48)
ctx.show_text("\"Baut dudukan tampak kendor & berdebu.")
ctx.move_to(QX + 30, item_y2 + 68)
ctx.show_text("Disarankan pembersihan & pengencangan.\"")

# Bottom Action Button: Kirim Laporan (Lugas, Orange BSS Safety)
draw_card(ctx, QX + 20, QY + QH - 75, QW - 40, 54, 10, (1.0, 0.40, 0.0)) # BSS Safety Orange
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(15)
ctx.set_source_rgb(1.0, 1.0, 1.0)
ctx.move_to(QX + 120, QY + QH - 42)
ctx.show_text("🚀 KIRIM LAPORAN")

# Callout improvements Right
callout_rx = RX + 465
callout_ry = LY + 105
ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(16)
ctx.set_source_rgb(0.4, 0.9, 0.6)
ctx.move_to(callout_rx, callout_ry)
ctx.show_text("PENINGKATAN REALISTIS:")

points_after = [
    ("1. High-Contrast Outdoor Ready", "Badge status tajam solid, bebas silau di bawah matahari."),
    ("2. Copywriting Bahasa Lapangan", "'Kirim Laporan', 'Pengecekan Manless', tanpa istilah campur."),
    ("3. Kamera Taktikal (Quick Zoom 2x)", "Bisa cek detail baut & kabel tanpa menempelkan fisik HP."),
    ("4. Offline Queue Indicator", "Badge antrean sync jelas: teknisi tahu data aman saat offline."),
    ("5. AI 1-Kalimat Fakta Lapangan", "Gemini langsung sebut temuan fisik tanpa basa-basi pembuka.")
]

ry_c = callout_ry + 35
for title, desc in points_after:
    draw_card(ctx, callout_rx, ry_c, 380, 80, 8, (0.10, 0.20, 0.25), (0.20, 0.45, 0.50), 1)
    ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
    ctx.set_font_size(13)
    ctx.set_source_rgb(0.65, 1.0, 0.8)
    ctx.move_to(callout_rx + 15, ry_c + 28)
    ctx.show_text(title)
    
    ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
    ctx.set_font_size(11)
    ctx.set_source_rgb(0.75, 0.85, 0.90)
    ctx.move_to(callout_rx + 15, ry_c + 54)
    ctx.show_text(desc)
    ry_c += 98

surface.write_to_png("docs/screenshots/audit_before_after_comparison.png")
print("Comparison image generated cleanly at docs/screenshots/audit_before_after_comparison.png")
