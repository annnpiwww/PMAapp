import os
from PIL import Image, ImageDraw, ImageFont

def create_atur_shift_visual():
    width = 1600
    height = 1100
    img = Image.new("RGB", (width, height), (15, 23, 42)) # Deep Slate Dark Background
    draw = ImageDraw.Draw(img)

    # Load system fonts
    try:
        font_title = ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", 34)
        font_subtitle = ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSans.ttf", 18)
        font_header = ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", 22)
        font_label = ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", 15)
        font_body = ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSans.ttf", 13)
        font_mono = ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSansMono-Bold.ttf", 13)
        font_tag = ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", 11)
    except:
        font_title = font_subtitle = font_header = font_label = font_body = font_mono = font_tag = ImageFont.load_default()

    # Brand Header Banner
    draw.rectangle([(0, 0), (width, 110)], fill=(26, 66, 138)) # BSS Blue
    draw.rectangle([(0, 106), (width, 110)], fill=(255, 101, 0)) # BSS Orange Accent Line
    draw.text((50, 24), "BSS PARKING TIMEMARK — ATUR SHIFT MODAL REDESIGN", fill=(255, 255, 255), font=font_title)
    draw.text((50, 68), "Penerapan Standar design.md: Scalable Technician Picker • 2x2 Bento Shift Grid • Dual-Coding • WCAG 2.2 AA", fill=(219, 234, 254), font=font_subtitle)

    # 2 Big Cards: Before (Left) vs Redesigned Implementation (Right)
    # Left: Before (Legacy crowded layout)
    card_w = 700
    card_h = 920
    x_left = 60
    y_top = 140

    # Draw Left Card (Before)
    draw.rounded_rectangle([(x_left, y_top), (x_left + card_w, y_top + card_h)], radius=18, fill=(30, 41, 59), outline=(71, 85, 105), width=2)
    # Badge Red
    draw.rounded_rectangle([(x_left + 24, y_top + 20), (x_left + 280, y_top + 54)], radius=8, fill=(220, 38, 38))
    draw.text((x_left + 36, y_top + 26), "KONDISI SEBELUMNYA", fill=(255, 255, 255), font=font_label)

    # Mock UI Inside Before
    ui_lx = x_left + 30
    ui_ly = y_top + 70
    draw.rounded_rectangle([(ui_lx, ui_ly), (ui_lx + card_w - 60, ui_ly + 800)], radius=16, fill=(255, 255, 255), outline=(226, 232, 240), width=1)
    
    # Dialog Header
    draw.text((ui_lx + 20, ui_ly + 18), "Atur Shift", fill=(15, 23, 42), font=font_header)
    draw.text((ui_lx + 20, ui_ly + 46), "Jadwal kerja & teknisi bertugas", fill=(100, 116, 139), font=font_body)
    draw.line([(ui_lx, ui_ly + 74), (ui_lx + card_w - 60, ui_ly + 74)], fill=(241, 245, 249), width=2)

    # Before Items
    draw.text((ui_lx + 20, ui_ly + 90), "NAMA TEKNISI BERTUGAS", fill=(148, 163, 184), font=font_tag)
    draw.rounded_rectangle([(ui_lx + 20, ui_ly + 108), (ui_lx + card_w - 80, ui_ly + 148)], radius=8, fill=(248, 250, 252), outline=(226, 232, 240))
    draw.text((ui_lx + 32, ui_ly + 120), "Junifer Manua", fill=(15, 23, 42), font=font_body)
    # Crowded chips
    draw.text((ui_lx + 20, ui_ly + 158), "Horizontal Single-Row Chips (Potensi Truncation jika nama panjang):", fill=(220, 38, 38), font=font_tag)
    chip_names = ["Junifer", "Ryan L", "Alessandro", "Raldy S"]
    cx = ui_lx + 20
    for name in chip_names:
        draw.rounded_rectangle([(cx, ui_ly + 176), (cx + 120, ui_ly + 206)], radius=6, fill=(241, 245, 249))
        draw.text((cx + 12, ui_ly + 184), name, fill=(71, 85, 105), font=font_body)
        cx += 130

    # Before: Shift in 1 single horizontal row of 4 columns (Very squished!)
    draw.text((ui_lx + 20, ui_ly + 230), "PILIH JADWAL SHIFT (1 Baris 4 Kolom Padat & Sempit)", fill=(148, 163, 184), font=font_tag)
    s_col_w = (card_w - 100) // 4
    for i, s_title in enumerate(["Shift 1", "Shift 2.2", "Shift 2", "Shift 3"]):
        sx = ui_lx + 20 + i * (s_col_w + 6)
        is_sel = (i == 0)
        draw.rounded_rectangle([(sx, ui_ly + 250), (sx + s_col_w, ui_ly + 310)], radius=8, fill=(26, 66, 138) if is_sel else (248, 250, 252), outline=(255, 101, 0) if is_sel else (226, 232, 240), width=2 if is_sel else 1)
        draw.text((sx + 10, ui_ly + 260), s_title, fill=(255, 255, 255) if is_sel else (15, 23, 42), font=font_label)
        draw.text((sx + 10, ui_ly + 284), "03:00-11:00", fill=(219, 234, 254) if is_sel else (100, 116, 139), font=font_tag)

    # Before Issues List Callout
    draw.rounded_rectangle([(ui_lx + 20, ui_ly + 340), (ui_lx + card_w - 80, ui_ly + 760)], radius=12, fill=(254, 242, 242), outline=(254, 202, 202))
    draw.text((ui_lx + 36, ui_ly + 356), "⚠️ Evaluasi Kelemahan UX Lama:", fill=(185, 28, 28), font=font_label)
    weaknesses = [
        "1. Tombol shift 4-kolom berdesakan horizontal, teks jam kecil.",
        "2. Pilihan shift aktif tidak memiliki dual-coding checkmark eksplisit.",
        "3. Summary card statis menimbulkan ambigu antara pilihan vs tersimpan.",
        "4. Chip nama teknisi overflow horizontal, tidak scalable jika tim bertambah.",
        "5. Tombol Close di header bar tanpa label semantik / accessibility tooltip.",
        "6. Tombol jenis absensi Masuk vs Pulang tanpa micro-copy 'Check In/Out'.",
        "7. Tidak ada visual feedback loading state saat tombol Simpan ditekan."
    ]
    wy = ui_ly + 395
    for w in weaknesses:
        draw.text((ui_lx + 36, wy), w, fill=(127, 29, 29), font=font_body)
        wy += 50

    # -------------------------------------------------------------
    # Right: Redesigned Implementation
    x_right = 840
    draw.rounded_rectangle([(x_right, y_top), (x_right + card_w, y_top + card_h)], radius=18, fill=(30, 41, 59), outline=(13, 148, 136), width=2)
    # Badge Green
    draw.rounded_rectangle([(x_right + 24, y_top + 20), (x_right + 340, y_top + 54)], radius=8, fill=(5, 150, 105))
    draw.text((x_right + 36, y_top + 26), "REDESAIN BARU (design.md)", fill=(255, 255, 255), font=font_label)

    # Mock UI Inside Redesigned
    ui_rx = x_right + 30
    ui_ry = y_top + 70
    draw.rounded_rectangle([(ui_rx, ui_ry), (ui_rx + card_w - 60, ui_ry + 820)], radius=16, fill=(255, 255, 255), outline=(226, 232, 240), width=1)
    
    # Dialog Header Clean
    draw.text((ui_rx + 20, ui_ry + 16), "Atur Shift & Absensi", fill=(15, 23, 42), font=font_header)
    draw.text((ui_rx + 20, ui_ry + 44), "Konfigurasi teknisi, jadwal kerja, dan status dinas", fill=(100, 116, 139), font=font_body)
    # Close button with tooltip
    draw.rounded_rectangle([(ui_rx + card_w - 110, ui_ry + 16), (ui_rx + card_w - 74, ui_ry + 52)], radius=8, fill=(241, 245, 249))
    draw.text((ui_rx + card_w - 97, ui_ry + 22), "✕", fill=(100, 116, 139), font=font_header)
    draw.line([(ui_rx, ui_ry + 68), (ui_rx + card_w - 60, ui_ry + 68)], fill=(241, 245, 249), width=2)

    # Section 1: Scalable Technician Input + Wrap Chips
    draw.text((ui_rx + 20, ui_ry + 80), "TEKNISI BERTUGAS (SIAPA)", fill=(26, 66, 138), font=font_tag)
    draw.rounded_rectangle([(ui_rx + 20, ui_ry + 98), (ui_rx + card_w - 80, ui_ry + 138)], radius=10, fill=(248, 250, 252), outline=(226, 232, 240))
    draw.text((ui_rx + 36, ui_ry + 108), "👤  Junifer Manua", fill=(15, 23, 42), font=font_body)

    # Section 2: Standby Pos + Location Picker Affordance
    draw.text((ui_rx + 20, ui_ry + 152), "LOKASI STANDBY POS (DI MANA)", fill=(26, 66, 138), font=font_tag)
    draw.rounded_rectangle([(ui_rx + 20, ui_ry + 170), (ui_rx + card_w - 80, ui_ry + 210)], radius=10, fill=(248, 250, 252), outline=(226, 232, 240))
    draw.text((ui_rx + 36, ui_ry + 180), "🏢  PBM (Pasar Bersehati Manado)", fill=(15, 23, 42), font=font_body)
    draw.rounded_rectangle([(ui_rx + card_w - 130, ui_ry + 174), (ui_rx + card_w - 86, ui_ry + 206)], radius=6, fill=(238, 242, 255))
    draw.text((ui_rx + card_w - 120, ui_ry + 182), "MAP", fill=(26, 66, 138), font=font_mono)

    # Section 3: 2x2 Bento Shift Grid (Huge readability improvement!)
    draw.text((ui_rx + 20, ui_ry + 225), "PILIH JADWAL SHIFT (2x2 BENTO GRID — Scannable & Dual-Coded)", fill=(26, 66, 138), font=font_tag)
    bento_w = (card_w - 90) // 2
    bento_h = 62
    
    # 2x2 Grid items
    grid_shifts = [
        ("Shift 1", "03:00 – 11:00 WITA", "Pagi • 8 Jam", True),
        ("Shift 2", "10:00 – 18:00 WITA", "Siang • 8 Jam", False),
        ("Shift 2.2", "10:00 – 14:00 WITA", "Paruh Waktu • 4 Jam", False),
        ("Shift 3", "14:00 – 22:00 WITA", "Sore-Malam • 8 Jam", False),
    ]
    for idx, (stitle, shours, sdur, is_act) in enumerate(grid_shifts):
        row = idx // 2
        col = idx % 2
        bx = ui_rx + 20 + col * (bento_w + 10)
        by = ui_ry + 245 + row * (bento_h + 8)
        
        bg_col = (239, 246, 255) if is_act else (248, 250, 252)
        border_col = (26, 66, 138) if is_act else (226, 232, 240)
        draw.rounded_rectangle([(bx, by), (bx + bento_w, by + bento_h)], radius=10, fill=bg_col, outline=border_col, width=2 if is_act else 1)
        
        draw.text((bx + 10, by + 6), stitle, fill=(26, 66, 138) if is_act else (15, 23, 42), font=font_label)
        draw.text((bx + bento_w - 26, by + 6), "✓" if is_act else "○", fill=(26, 66, 138) if is_act else (148, 163, 184), font=font_label)
        draw.text((bx + 10, by + 26), shours, fill=(30, 58, 138) if is_act else (71, 85, 105), font=font_mono)
        draw.text((bx + 10, by + 44), sdur, fill=(26, 66, 138) if is_act else (148, 163, 184), font=font_tag)

    # Custom Shift Bar
    draw.rounded_rectangle([(ui_rx + 20, ui_ry + 395), (ui_rx + card_w - 80, ui_ry + 435)], radius=10, fill=(248, 250, 252), outline=(226, 232, 240))
    draw.text((ui_rx + 36, ui_ry + 406), "⚙️  Custom Shift / Jadwal Khusus", fill=(15, 23, 42), font=font_body)
    draw.rounded_rectangle([(ui_rx + card_w - 130, ui_ry + 404), (ui_rx + card_w - 90, ui_ry + 426)], radius=12, fill=(203, 213, 225))

    # Section 4: Summary Confirmation Card (Selection vs Saved)
    draw.rounded_rectangle([(ui_rx + 20, ui_ry + 450), (ui_rx + card_w - 80, ui_ry + 520)], radius=10, fill=(241, 245, 249), outline=(203, 213, 225))
    draw.text((ui_rx + 32, ui_ry + 460), "ℹ️  Konfirmasi Pilihan Shift", fill=(71, 85, 105), font=font_tag)
    draw.rounded_rectangle([(ui_rx + card_w - 230, ui_ry + 458), (ui_rx + card_w - 95, ui_ry + 478)], radius=4, fill=(236, 253, 245), outline=(167, 243, 208))
    draw.text((ui_rx + card_w - 220, ui_ry + 462), "Aktif di Watermark", fill=(6, 95, 70), font=font_tag)
    draw.text((ui_rx + 32, ui_ry + 482), "Shift 1 (03:00 - 11:00)", fill=(26, 66, 138), font=font_label)
    draw.text((ui_rx + 32, ui_ry + 502), "Durasi wajib: 8 Jam • Estimasi pulang: Jam 11:00 WITA", fill=(100, 116, 139), font=font_tag)

    # Section 5: Attendance Type Selection (Masuk vs Pulang)
    draw.text((ui_rx + 20, ui_ry + 535), "JENIS LAPORAN ABSENSI", fill=(26, 66, 138), font=font_tag)
    half_btn_w = (card_w - 90) // 2
    # Masuk Card
    draw.rounded_rectangle([(ui_rx + 20, ui_ry + 555), (ui_rx + 20 + half_btn_w, ui_ry + 625)], radius=12, fill=(236, 253, 245), outline=(5, 150, 105), width=2)
    draw.text((ui_rx + 36, ui_ry + 568), "✓ Masuk", fill=(5, 150, 105), font=font_header)
    draw.text((ui_rx + 36, ui_ry + 596), "Check In Awal Dinas", fill=(4, 120, 87), font=font_tag)

    # Pulang Card
    draw.rounded_rectangle([(ui_rx + 30 + half_btn_w, ui_ry + 555), (ui_rx + card_w - 80, ui_ry + 625)], radius=12, fill=(248, 250, 252), outline=(226, 232, 240))
    draw.text((ui_rx + 46 + half_btn_w, ui_ry + 568), "Pulang", fill=(15, 23, 42), font=font_header)
    draw.text((ui_rx + 46 + half_btn_w, ui_ry + 596), "Check Out & Handover", fill=(100, 116, 139), font=font_tag)

    # Footer Actions
    draw.line([(ui_rx, ui_ry + 735), (ui_rx + card_w - 60, ui_ry + 735)], fill=(241, 245, 249), width=2)
    # Batal
    draw.rounded_rectangle([(ui_rx + 20, ui_ry + 750), (ui_rx + 20 + half_btn_w, ui_ry + 800)], radius=10, fill=(255, 255, 255), outline=(203, 213, 225), width=1)
    draw.text((ui_rx + 20 + (half_btn_w // 2) - 20, ui_ry + 764), "Batal", fill=(100, 116, 139), font=font_label)
    # Simpan Shift
    draw.rounded_rectangle([(ui_rx + 30 + half_btn_w, ui_ry + 750), (ui_rx + card_w - 80, ui_ry + 800)], radius=10, fill=(26, 66, 138))
    draw.text((ui_rx + 30 + half_btn_w + (half_btn_w // 2) - 50, ui_ry + 764), "✓ Simpan Shift", fill=(255, 255, 255), font=font_label)

    # Save artifact
    output_path = "/home/annnpii/Product development annpii/BssparkingTimeMark/BSS-Atur-Shift-Modal-Redesign-Showcase.png"
    img.save(output_path, quality=95)
    print(f"Generated visual artifact: {output_path}")

if __name__ == "__main__":
    create_atur_shift_visual()
