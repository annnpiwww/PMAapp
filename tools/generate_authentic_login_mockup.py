import math
import os
from PIL import Image, ImageDraw, ImageFont

WIDTH = 2400
HEIGHT = 1400

# Base Background: Deep studio slate with soft ambient lighting
canvas = Image.new("RGBA", (WIDTH, HEIGHT), (15, 20, 28, 255))
draw = ImageDraw.Draw(canvas)

# Ambient glow behind phones
def create_radial_glow(img, center_x, center_y, radius, color):
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    for r in range(radius, 0, -20):
        alpha = int(color[3] * (1.0 - r / radius) * 0.15)
        gdraw.ellipse([center_x - r, center_y - r, center_x + r, center_y + r], fill=(color[0], color[1], color[2], alpha))
    return Image.alpha_composite(img, glow)

canvas = create_radial_glow(canvas, 600, 750, 600, (30, 68, 141, 100))
canvas = create_radial_glow(canvas, 1800, 750, 600, (255, 91, 0, 80))
draw = ImageDraw.Draw(canvas)

# Fonts
font_title = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 36)
font_subtitle = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 18)
font_badge = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 14)
font_detail = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 14)
font_phone_title = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 26)
font_phone_sub = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
font_label = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 12)
font_input = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 14)
font_btn = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 16)
font_footer = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 11)

# Header Title
draw.text((80, 50), "PMA App — KOMPARASI DESAIN LOGIN SCREEN", font=font_title, fill=(255, 255, 255))
draw.text((80, 100), "Versi Sekarang (Real UI Eksisting) vs Hasil Redesign (Impeccable & Taste Polish)", font=font_subtitle, fill=(160, 175, 200))

# Helper: Draw Smartphone Frame
def draw_phone_chassis(draw_obj, x, y, w, h):
    # Drop shadow
    for i in range(15, 0, -2):
        draw_obj.rounded_rectangle([x - i, y - i + 8, x + w + i, y + h + i + 8], radius=44, fill=(0, 0, 0, 20))
    # Bezel
    draw_obj.rounded_rectangle([x, y, x + w, y + h], radius=42, fill=(24, 28, 36), outline=(70, 78, 92), width=2)
    # Inner screen
    sx, sy, sw, sh = x + 12, y + 12, w - 24, h - 24
    return (sx, sy, sw, sh)

# Helper: Status bar
def draw_phone_status_bar(draw_obj, sx, sy, sw, is_dark=False):
    fill_col = (240, 245, 255) if is_dark else (30, 41, 59)
    draw_obj.text((sx + 30, sy + 22), "14:32", font=font_label, fill=fill_col)
    # Camera punch hole
    draw_obj.ellipse([sx + sw/2 - 7, sy + 18, sx + sw/2 + 7, sy + 32], fill=(10, 10, 15))
    draw_obj.text((sx + sw - 80, sy + 22), "5G  98%", font=font_label, fill=fill_col)


# ==============================================================================
# SISI KIRI: VERSI SEKARANG (REAL UI EKSISTING DARI SCREENSHOT USER)
# ==============================================================================
LEFT_CARD_X = 80
CARD_Y = 150
CARD_W = 1080
CARD_H = 1180

# Container Kiri
draw.rounded_rectangle([LEFT_CARD_X, CARD_Y, LEFT_CARD_X + CARD_W, CARD_Y + CARD_H], radius=24, fill=(20, 26, 36), outline=(50, 60, 78), width=2)

# Badge Kiri
draw.rounded_rectangle([LEFT_CARD_X + 35, CARD_Y + 30, LEFT_CARD_X + 430, CARD_Y + 75], radius=20, fill=(35, 55, 85), outline=(70, 120, 200), width=1)
draw.text((LEFT_CARD_X + 55, CARD_Y + 44), "📌 VERSI SEKARANG (REAL UI EKSISTING)", font=font_badge, fill=(180, 215, 255))
draw.text((LEFT_CARD_X + 450, CARD_Y + 45), "UI asli saat ini dari aplikasi PMA App", font=font_detail, fill=(140, 155, 175))

# Phone Chassis Kiri
P1_W, P1_H = 520, 1030
P1_X = LEFT_CARD_X + 50
P1_Y = CARD_Y + 105
s1_x, s1_y, s1_w, s1_h = draw_phone_chassis(draw, P1_X, P1_Y, P1_W, P1_H)

# Load screenshot asli user
user_shot_path = "/home/annnpii/.gemini/antigravity/brain/80666ec8-61aa-4dc9-b839-e7307a5ee2ad/.user_uploaded/media_1791974456110_0221f662.png"
user_img = Image.open(user_shot_path).convert("RGBA")

# Screen background matching user screenshot
screen_left = Image.new("RGBA", (s1_w, s1_h), (248, 249, 250, 255))
draw_sl = ImageDraw.Draw(screen_left)

# Resize & paste user screenshot inside screen neatly
user_img_resized = user_img.resize((s1_w - 40, int((s1_w - 40) * (user_img.height / user_img.width))), Image.Resampling.LANCZOS)
paste_y = (s1_h - user_img_resized.height) // 2 + 10
screen_left.paste(user_img_resized, (20, paste_y), user_img_resized)

# Draw status bar on top of screen
draw_phone_status_bar(draw_sl, 0, 0, s1_w, is_dark=False)

# Mask rounded screen corners
mask_left = Image.new("L", (s1_w, s1_h), 0)
ImageDraw.Draw(mask_left).rounded_rectangle([0, 0, s1_w, s1_h], radius=32, fill=255)
canvas.paste(screen_left, (s1_x, s1_y), mask_left)

# Catatan Analisis Sisi Kiri
nx = LEFT_CARD_X + 600
ny = CARD_Y + 120
draw.text((nx, ny), "KARAKTERISTIK UI SEKARANG:", font=font_badge, fill=(200, 220, 255))
ny += 30

points_current = [
    ("1. Layout Bersih & Simpel", "Komposisi terpusat, logo BSS berlingkar orange glow, dan field card putih."),
    ("2. Kontras Outdoor Lapangan", "Border input dan placeholder relatif tipis (#E2E8F0 & #94A3B8), sedikit pudar di bawah sinar terik."),
    ("3. Action Affordance", "Tombol 'Masuk' orange solid datar; belum ada efek depth atau tactile direction."),
    ("4. Visual Focus State", "Perlu feedback visual yang lebih tegas saat field sedang aktif / fokus diketik teknisi."),
    ("5. Accessibility & Touch", "Area sentuh form sudah proporsional, bisa disempurnakan dengan micro-haptic cue.")
]

for title, desc in points_current:
    draw.rounded_rectangle([nx, ny, nx + 440, ny + 95], radius=12, fill=(26, 34, 48), outline=(45, 58, 80), width=1)
    draw.text((nx + 16, ny + 14), title, font=font_label, fill=(160, 205, 255))
    # Wrap text
    draw.text((nx + 16, ny + 40), desc[:48], font=font_detail, fill=(190, 200, 215))
    if len(desc) > 48:
        draw.text((nx + 16, ny + 62), desc[48:], font=font_detail, fill=(190, 200, 215))
    ny += 115


# ==============================================================================
# SISI KANAN: HASIL REDESIGN (IMPECCABLE & TASTE POLISH)
# ==============================================================================
RIGHT_CARD_X = 1240

# Container Kanan
draw.rounded_rectangle([RIGHT_CARD_X, CARD_Y, RIGHT_CARD_X + CARD_W, CARD_Y + CARD_H], radius=24, fill=(18, 28, 38), outline=(30, 90, 160), width=2)

# Badge Kanan
draw.rounded_rectangle([RIGHT_CARD_X + 35, CARD_Y + 30, RIGHT_CARD_X + 460, CARD_Y + 75], radius=20, fill=(20, 60, 45), outline=(50, 180, 110), width=1)
draw.text((RIGHT_CARD_X + 55, CARD_Y + 44), "✨ HASIL REDESIGN (IMPECCABLE POLISH)", font=font_badge, fill=(120, 255, 180))
draw.text((RIGHT_CARD_X + 480, CARD_Y + 45), "Tetap setia pada identitas asli PMA App", font=font_detail, fill=(160, 210, 200))

# Phone Chassis Kanan
P2_W, P2_H = 520, 1030
P2_X = RIGHT_CARD_X + 50
P2_Y = CARD_Y + 105
s2_x, s2_y, s2_w, s2_h = draw_phone_chassis(draw, P2_X, P2_Y, P2_W, P2_H)

# Canvas Screen Kanan
screen_right = Image.new("RGBA", (s2_w, s2_h), (250, 248, 245, 255)) # Warm Ivory surface
draw_sr = ImageDraw.Draw(screen_right)
draw_phone_status_bar(draw_sr, 0, 0, s2_w, is_dark=False)

# Theme Toggle subtle at top-right
draw_sr.rounded_rectangle([s2_w - 110, 45, s2_w - 25, 78], radius=16, fill=(255, 255, 255), outline=(226, 232, 240), width=1)
draw_sr.text((s2_w - 95, 54), "🌙 Gelap", font=font_label, fill=(30, 68, 141))

# Center Form Layout
cx = s2_w // 2

# Logo BSS Parking
logo_path = "foto/splash_logo.png"
if os.path.exists(logo_path):
    logo_raw = Image.open(logo_path).convert("RGBA")
    logo_resized = logo_raw.resize((84, 84), Image.Resampling.LANCZOS)
    
    # Outer ring glow
    draw_sr.ellipse([cx - 48, 110, cx + 48, 206], fill=(255, 107, 0, 60))
    draw_sr.ellipse([cx - 45, 113, cx + 45, 203], fill=(255, 255, 255), outline=(255, 107, 0), width=3)
    
    # Mask round logo
    lmask = Image.new("L", (84, 84), 0)
    ImageDraw.Draw(lmask).ellipse([0, 0, 84, 84], fill=255)
    screen_right.paste(logo_resized, (cx - 42, 116), lmask)
    draw_sr = ImageDraw.Draw(screen_right)

# Title PMA App (Bold Plus Jakarta Sans style)
draw_sr.text((cx - 65, 222), "PMA App", font=font_phone_title, fill=(15, 23, 42))
draw_sr.text((cx - 128, 262), "Absen, Maintenance & Daily Task", font=font_phone_sub, fill=(100, 116, 139))

# Elevated Form Card R24 with dual shadow
card_box_y = 305
card_w = s2_w - 60
card_h = 420
card_x1 = 30
card_x2 = card_x1 + card_w

# Card shadow
for i in range(12, 0, -2):
    draw_sr.rounded_rectangle([card_x1 - i, card_box_y - i + 4, card_x2 + i, card_box_y + card_h + i + 4], radius=26, fill=(0, 0, 0, 8))

# Card container
draw_sr.rounded_rectangle([card_x1, card_box_y, card_x2, card_box_y + card_h], radius=24, fill=(255, 255, 255), outline=(226, 232, 240), width=2)

# Field 1: Email atau Username
fx = card_x1 + 25
fw = card_w - 50
draw_sr.text((fx, card_box_y + 30), "Email atau Username", font=font_label, fill=(71, 85, 105))
# Input box
draw_sr.rounded_rectangle([fx, card_box_y + 50, fx + fw, card_box_y + 112], radius=14, fill=(248, 250, 252), outline=(203, 213, 225), width=1)
draw_sr.text((fx + 16, card_box_y + 72), "@", font=font_phone_title, fill=(148, 163, 184))
draw_sr.text((fx + 52, card_box_y + 72), "Masukkan email", font=font_input, fill=(148, 163, 184))

# Field 2: Kata Sandi (Focused State with Safety Orange Accent Highlight!)
draw_sr.text((fx, card_box_y + 135), "Kata Sandi", font=font_label, fill=(71, 85, 105))
draw_sr.rounded_rectangle([fx, card_box_y + 155, fx + fw, card_box_y + 217], radius=14, fill=(248, 250, 252), outline=(255, 107, 0), width=2) # Focused border!
draw_sr.text((fx + 18, card_box_y + 175), "🔒", font=font_label, fill=(255, 107, 0))
draw_sr.text((fx + 52, card_box_y + 175), "Masukkan kata sandi", font=font_input, fill=(100, 116, 139))
draw_sr.text((fx + fw - 42, card_box_y + 175), "👁", font=font_label, fill=(148, 163, 184))

# Tombol Masuk: Safety Orange Tactile Button with directional affordance
btn_y = card_box_y + 255
btn_h = 56
# Shadow button
draw_sr.rounded_rectangle([fx, btn_y + 3, fx + fw, btn_y + btn_h + 3], radius=14, fill=(255, 107, 0, 100))
draw_sr.rounded_rectangle([fx, btn_y, fx + fw, btn_y + btn_h], radius=14, fill=(255, 91, 0)) # Pure Safety Orange
draw_sr.text((cx - 30, btn_y + 18), "Masuk", font=font_btn, fill=(255, 255, 255))

# Footer below card
draw_sr.text((cx - 86, card_box_y + card_h + 35), "PMAapp powered by annnpii", font=font_footer, fill=(148, 163, 184))

# Mask rounded screen corners right
mask_right = Image.new("L", (s2_w, s2_h), 0)
ImageDraw.Draw(mask_right).rounded_rectangle([0, 0, s2_w, s2_h], radius=32, fill=255)
canvas.paste(screen_right, (s2_x, s2_y), mask_right)

# Catatan Peningkatan Sisi Kanan
mx = RIGHT_CARD_X + 600
my = CARD_Y + 120
draw.text((mx, my), "PENINGKATAN REDESIGN (TASTE POLISH):", font=font_badge, fill=(140, 255, 200))
my += 30

points_redesign = [
    ("1. 100% Selaras Copy & Elemen", "Tidak ada badge liar. Teks, logo BSS, dan label persis seperti desain aslimu."),
    ("2. Tactile Micro-Elevation (R24)", "Card putih diberikan dual-layer diffuse shadow r24 yang hangat & mewah."),
    ("3. Focus State Highlight (Orange)", "Border field berubah orange menyala saat aktif, memperjelas posisi kursor."),
    ("4. Sunlight-Proof High Contrast", "Border dan label input lebih solid, tetap terbaca tajam di bawah sinar matahari."),
    ("5. Seamless Theme Mode", "Dukungan mode Gelap & Terang instan yang adaptif terhadap kondisi cahaya lapangan.")
]

for title, desc in points_redesign:
    draw.rounded_rectangle([mx, my, mx + 440, my + 95], radius=12, fill=(20, 36, 42), outline=(35, 75, 70), width=1)
    draw.text((mx + 16, my + 14), title, font=font_label, fill=(120, 255, 180))
    draw.text((mx + 16, my + 40), desc[:48], font=font_detail, fill=(180, 215, 205))
    if len(desc) > 48:
        draw.text((mx + 16, my + 62), desc[48:], font=font_detail, fill=(180, 215, 205))
    my += 115

out_file = "docs/screenshots/authentic_login_before_after.png"
os.makedirs(os.path.dirname(out_file), exist_ok=True)
canvas.save(out_file, "PNG")
print(f"SUCCESS: Saved authentic login comparison to {out_file}")
