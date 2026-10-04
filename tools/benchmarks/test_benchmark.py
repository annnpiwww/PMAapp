import time
import requests
import json
import base64
import os
import io
import re
from PIL import Image, ImageDraw

API_URL = "https://pizza-namespace-brings-desert.trycloudflare.com/v1/chat/completions"
API_KEY = os.environ.get("BSS_AI_API_KEY", "")
MODEL = "gemini-3.7-flash-high"

def make_test_img(text, bg_color):
    img = Image.new('RGB', (640, 800), color=bg_color)
    draw = ImageDraw.Draw(img)
    draw.text((30, 350), text, fill=(255, 255, 255))
    buf = io.BytesIO()
    img.save(buf, format='JPEG', quality=80)
    return base64.b64encode(buf.getvalue()).decode('utf-8')

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

Balas HANYA dengan format JSON valid berikut (tanpa blok markdown ataupun teks lain):
{{
  "status": "sesuai" | "tidak_sesuai" | "perlu_cek_manual",
  "confidenceScore": 0.0 - 1.0,
  "alasan": "penjelasan singkat dan lugas dalam Bahasa Indonesia",
  "poinLolos": ["kriteria yang terpenuhi"],
  "poinGagal": ["kriteria yang dilanggar/tidak terpenuhi"]
}}"""

# Test 1: Kamera Gelap / Tertutup
img1 = make_test_img("TEST 1: KAMERA TERTUTUP / GELAP", (15, 15, 15))
# Test 2: Foto Pakaian Santai (Bukan Seragam)
img2 = make_test_img("TEST 2: PETUGAS KAOS & CELANA JEANS", (100, 60, 40))

tests = [
    ("Foto Gelap (Kamera Tertutup)", img1),
    ("Foto Non-Seragam (Kaos Santai)", img2)
]

for label, b64 in tests:
    print(f"\n==========================================")
    print(f"Testing: {label}")
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
        "max_tokens": 500,
        "temperature": 0.1
    }
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {API_KEY}"
    }
    t0 = time.time()
    try:
        r = requests.post(API_URL, json=payload, headers=headers, timeout=20)
        dt = time.time() - t0
        print(f"Status Code: {r.status_code} | Latency: {dt:.2f}s")
        if r.status_code == 200:
            content = r.json()["choices"][0]["message"]["content"]
            cleaned = re.sub(r'<think>[\s\S]*?</think>', '', content).strip()
            if cleaned.startswith("```json"):
                cleaned = cleaned[7:]
            if cleaned.startswith("```"):
                cleaned = cleaned[3:]
            if cleaned.endswith("```"):
                cleaned = cleaned[:-3]
            data = json.loads(cleaned.strip())
            print(f"AI Decision : {data.get('status')}")
            print(f"Confidence  : {data.get('confidenceScore')}")
            print(f"Alasan      : {data.get('alasan')}")
            print(f"Poin Gagal  : {data.get('poinGagal')}")
            print(f"Poin Lolos  : {data.get('poinLolos')}")
        else:
            print(f"Failed: {r.text}")
    except Exception as err:
        print(f"Request Error: {err}")
