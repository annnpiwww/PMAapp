import os
"""Test JSON-mode + new 6s timeout + image compression."""
import requests
import base64
import time
import json
import urllib3
from PIL import Image, ImageDraw, ImageFont
import io

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

API_URL = "https://hermesagent.tailcb6f2e.ts.net/v1/chat/completions"
API_KEY = os.environ.get("BSS_AI_API_KEY", "")

# Simulate Flutter image pipeline: 480px wide JPEG q52
def make_compressed_jpeg_b64(label, bg, target_w=480, q=52):
    img = Image.new("RGB", (1080, 1440), color=bg)
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 48)
    except (OSError, IOError):
        font = ImageFont.load_default()
    draw.text((100, 600), label, fill=(255, 255, 255), font=font)
    # Compress like Flutter pipeline
    img = img.resize((target_w, int(target_w * 1440 / 1080)))
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=q)
    return base64.b64encode(buf.getvalue()).decode("utf-8")

SYSTEM_PROMPT = """You are BSS-Vision, strict SOP auditor. Be CONSERVATIVE.
Return ONE JSON only:
{"status":"sesuai"|"tidak_sesuai"|"perlu_cek_manual","confidenceScore":0-100,"alasan":"<=15 words ID","poinLolos":["..."],"poinGagal":["..."]}"""

CRITERIA = """1. Seragam BSS rapi
2. ID Card terpasang
3. Rambut rapi
4. Sepatu hitam
5. Wajah jelas tanpa masker"""

# Test models + payloads
MODELS = [
    ("ollama-cloud/gemma4:31b", True),
    ("ocrgambar", True),
    ("agy/gemini-3.1-flash-lite", True),
]

print("=" * 80)
print("  BSS-VISION OPTIMIZED: JSON-mode + 6s timeout + 480px JPEG q52")
print("=" * 80)

img_b64 = make_compressed_jpeg_b64("BSS Parking Personnel", (60, 90, 130))
print(f"Compressed image: {len(img_b64) // 1024} KB base64 (~{len(img_b64)*3//4//1024}KB raw)")

# Concatenate prompt + criteria to make single system msg
full_prompt = f"{SYSTEM_PROMPT}\n\nCRITERIA:\n{CRITERIA}"

for model_name, _ in MODELS:
    print(f"\n>>> {model_name}")
    times = []
    for run in range(3):
        payload = {
            "model": model_name,
            "messages": [
                {"role": "system", "content": full_prompt},
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": "Evaluasi foto ini terhadap SOP BSS Parking."},
                        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{img_b64}"}},
                    ],
                },
            ],
            "max_tokens": 350,
            "temperature": 0.0,
            "response_format": {"type": "json_object"},
            "reasoning": {"effort": "minimal"},
            "stream": False,
        }
        t0 = time.time()
        try:
            res = requests.post(API_URL, json=payload,
                                headers={"Authorization": f"Bearer {API_KEY}"},
                                timeout=6, verify=False)
            d = time.time() - t0
            times.append(d)
            if res.status_code == 200:
                content = res.json()["choices"][0]["message"]["content"]
                try:
                    parsed = json.loads(content)
                    print(f"  run {run+1}: {d:.2f}s | status={parsed.get('status')} | conf={parsed.get('confidenceScore')}")
                except (json.JSONDecodeError, TypeError):
                    print(f"  run {run+1}: {d:.2f}s | INVALID JSON: {content[:100]}")
            else:
                print(f"  run {run+1}: HTTP {res.status_code} ({d:.2f}s)")
        except requests.exceptions.Timeout:
            times.append(6.0)
            print(f"  run {run+1}: TIMEOUT 6s")
        except Exception as e:
            print(f"  run {run+1}: EXC: {e}")

    valid = [t for t in times if t < 5.5]
    if valid:
        avg = sum(valid) / len(valid)
        print(f"  AVG (valid): {avg:.2f}s | Total budget needed for primary: {avg:.2f}s")
    print(f"  Worst case (with 1 retry): {sum(sorted(times)[:2]):.2f}s")
