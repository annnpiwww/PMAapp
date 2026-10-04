import os
import time
import requests
import json
import base64
import re
from PIL import Image, ImageDraw
import io

API_URL = "https://pizza-namespace-brings-desert.trycloudflare.com/v1/chat/completions"
API_KEY = os.environ.get("BSS_AI_API_KEY", "")
MODEL = "gemini-3.7-flash-high"

def make_test_img(text, bg_color):
    img = Image.new('RGB', (480, 640), color=bg_color)
    draw = ImageDraw.Draw(img)
    draw.text((30, 300), text, fill=(255, 255, 255))
    buf = io.BytesIO()
    img.save(buf, format='JPEG', quality=70)
    return base64.b64encode(buf.getvalue()).decode('utf-8')

sop_criteria = [
    "Seragam resmi BSS Parking bersih, rapi & terkancing",
    "ID Card / Name Tag terpasang jelas di saku kiri",
    "Rambut rapi / Jilbab rapi sesuai standar grooming BSS",
    "Sepatu dinas pantofel / PDL hitam bersih",
    "Wajah terlihat jelas tanpa masker / kacamata hitam"
]

prompt_optimized = f"""Inspeksi cepat foto petugas BSS Parking terhadap kriteria berikut:
{json.dumps(sop_criteria)}

Kembalikan HANYA JSON tanpa format lain atau markdown:
{{"status":"sesuai"|"tidak_sesuai"|"perlu_cek_manual","confidenceScore":0.95,"alasan":"singkat maksimal 15 kata","poinLolos":[],"poinGagal":[]}}"""

img2 = make_test_img("PETUGAS KAOS SANTAI", (100, 60, 40))

for i in range(2):
    t0 = time.time()
    payload = {
        "model": MODEL,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt_optimized},
                    {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{img2}"}}
                ]
            }
        ],
        "max_tokens": 250,
        "temperature": 0.0
    }
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {API_KEY}"}
    r = requests.post(API_URL, json=payload, headers=headers, timeout=20)
    dt = time.time() - t0
    print(f"Run {i+1}: {dt:.2f}s (HTTP {r.status_code})")
    if r.status_code == 200:
        content = r.json()["choices"][0]["message"]["content"]
        cleaned = re.sub(r'<think>[\s\S]*?</think>', '', content).strip()
        print("Response:", cleaned[:150])
