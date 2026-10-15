from PIL import Image

logo = Image.open('foto/bssfotologo_transparent.png')

def make_icon(size, pad_ratio=0.10, bg=(30, 68, 141, 255)):
    canvas = Image.new('RGBA', (size, size), bg)
    pad = int(size * pad_ratio)
    target_w = size - (pad * 2)
    target_h = int(target_w * (logo.height / logo.width))
    resized = logo.resize((target_w, target_h), Image.Resampling.LANCZOS)
    px = pad
    py = (size - target_h) // 2
    canvas.paste(resized, (px, py), mask=resized)
    return canvas

# 1. Favicon (64x64)
make_icon(64, pad_ratio=0.08).save('web/favicon.png', 'PNG')

# 2. Standard PWA Icons (192x192 & 512x512)
make_icon(192, pad_ratio=0.10).save('web/icons/Icon-192.png', 'PNG')
make_icon(512, pad_ratio=0.10).save('web/icons/Icon-512.png', 'PNG')

# 3. Maskable PWA Icons (Safe zone with 18% margin)
make_icon(192, pad_ratio=0.18).save('web/icons/Icon-maskable-192.png', 'PNG')
make_icon(512, pad_ratio=0.18).save('web/icons/Icon-maskable-512.png', 'PNG')
print("Official BSS Parking PWA icons generated successfully!")

