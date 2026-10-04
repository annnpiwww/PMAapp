import time
import requests
import json
import base64
import os
from PIL import Image, ImageDraw, ImageFont
import io

API_URL = "https://pizza-namespace-brings-desert.trycloudflare.com/v1/chat/completions"
API_KEY = os.environ.get("BSS_AI_API_KEY", "")
MODEL = "gemini-3.7-flash-high"

def create_dummy_image(label, bg_color):
    img = Image.new('RGB', (720, 960), color=bg_color)
    draw = ImageDraw.Draw(img)
    draw.text((50, 400), label, fill=(255, 255, 255))
    buffer = io.BytesIO()
    img.save(buffer, format='JPEG', quality=80)
    return base64.b64encode(buffer.getvalue()).decode('utf-8')

# Try to capture from ADB device if connected
adb_img_b64 = None
try:
    os.system("adb -s 102682538I005259 exec-out screencap -p > /tmp/adb_screen.png")
    if os.path.exists("/tmp/adb_screen.png") and os.path.getsize("/tmp/adb_screen.png") > 1000:
        im = Image.open("/tmp/adb_screen.png").convert('RGB')
        im.thumbnail((720, 960))
        buf = io.BytesIO()
        im.save(buf, format='JPEG', quality=75)
        adb_img_b64 = base64.b64encode(buf.getvalue()).decode('utf-8')
        print("Captured live screen from Infinix device!")
except Exception as e:
    print(f"ADB capture failed: {e}")

test_cases = [
    ("1. Kamera Tertutup / Gelap Gulita (Gagal Total)", create_dummy_image("Layar Hitam Tertutup", (10, 10, 10))),
    ("2. Petugas Tanpa Seragam / Kaos Oblong (Gagal Grooming)", create_dummy_image("Petugas Kaos Santai & Celana Pendek", (70, 80, 120))),
]
if adb_img_b64:
    test_cases.append(("3. Live Camera Viewfinder Infinix (Real Frame)", adb_img_b64))

sop_criteria = [
    "Seragam resmi BSS Parking bersih, rapi & terkancing",
    "ID Card / Name Tag terpasang jelas di saku kiri",
    "Rambut rapi / Jilbab rapi sesuai standar grooming BSS",
    "Sepatu dinas pantofel / PDL hitam bersih",
    "Wajah terlihat jelas tanpa masker / kacamata hitam"
]

prompt = f"""Anda adalah AI Vision Inspector SOP BSS Parking. Evaluasi foto petugas berikut terhadap SOP BSS:
Kriteria:
{json.dumps(sop_criteria, indent=2)}

Balas HANYA dengan JSON valid (tanpa markdown atau komentar):
{{
  "status": "sesuai" | "tidak_sesuai" | "perlu_cek_manual",
  "confidenceScore": 0.0 - 1.0,
  "alasan": "penjelasan singkat dan lugas",
  "poinLolos": ["kriteria yang terpenuhi"],
  "poinGagal": ["kriteria yang dilanggar/tidak terpenuhi"]
}}"""

print("=== STARTING AI VISION LATENCY BENCHMARK ===")
for name, b64 in test_cases:
    payload = {
        "model": MODEL,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}"}}
                ]
            }
        ],
        "max_tokens": 600,
        "temperature": 0.2
    }
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {API_KEY}"
    }
    
    start_time = time.time()
    try:
        res = requests.post(API_URL, json=payload, headers=headers, timeout=20)
        elapsed = time.time() - start_time
        print(f"\n--- {name} ---")
        print(f"Latency: {elapsed:.2f} detik (HTTP {res.status_code})")
        if res.status_code == 200:
            raw_content = res.json()["choices"][0]["message"]["content"]
            # strip think tags if any
            import re
            cleaned = re.sub(r'<think>[\s\S]*?</think>', '', raw_content).strip()
            if cleaned.startswith("```json"):
                cleaned = cleaned[7:]
            if cleaned.endswith("```"):
                cleaned = cleaned[:-3]
            try:
                parsed = json.loads(cleaned.strip())
                print(f"Status: {parsed.get('status')}")
                print(f"Confidence: {parsed.get('confidenceScore')}")
                print(f"Alasan: {parsed.get('alasan')}")
                print(f"Poin Gagal ({len(parsed.get('poinGagal', []))}): {parsed.get('poinGagal')}")
            except Exception as e:
                print(f"Raw response: {cleaned[:200]}...")
        else:
            print(f"Error: {res.text[:200]}")
    except Exception as e:
        elapsed = time.time() - start_time
        print(f"\n--- {name} --- FAILED after {elapsed:.2f}s: {e}")

