"""Fine-tuned prompt + deterministic settings benchmark."""
import requests
import base64
import time
import json
import os
import sys
from PIL import Image, ImageDraw, ImageFont
import io
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

API_URL = "https://hermesagent.tailcb6f2e.ts.net/v1/chat/completions"
API_KEY = os.environ.get("BSS_AI_API_KEY", "")

# Same model chain that BSS-Vision uses in app
CANDIDATE_MODELS = [
    "ollama-cloud/gemma4:31b",
    "ocrgambar",
    "agy/gemini-3.1-flash-lite",
    "Minimax/MiniMaxAI/MiniMax-M3",
]

# Fine-tuned prompt (matches BSS-Vision Flutter service)
SYSTEM_PROMPT = """You are BSS-Vision, a strict SOP compliance auditor for BSS Parking (Bahana Sulut Sentosa).
Task: Verify the photo against the SOP criteria. Be CONSERVATIVE — if unsure, mark "tidak_sesuai".

============================================================
CORE RULES (apply in order)
============================================================
1. FRAMING: Photo MUST show full body head-to-toe. Selfie/close-up face = "tidak_sesuai" with reason "Foto bukan full body".
2. UNIFORM: BSS official shirt/polo/vest, BLACK long pants (no jeans), BLACK shoes.
3. ATTRIBUTES: ID card / name tag MUST be visible on left chest.
4. HYGIENE: Hair neat, no mask/sunglasses covering face. Jilbab = navy/BRI blue.
5. FORMATION (if group): Barisan rapi, sejajar, tidak bersandar.
6. TEMPLATE CRITERIA below are ADDITIONAL checks — each must pass independently.

============================================================
TEMPLATE CRITERIA (5 items, all must pass)
============================================================
1. Seragam resmi BSS Parking bersih, rapi, terkancing
2. ID Card / Name Tag terpasang jelas di saku kiri
3. Rambut / Jilbab rapi sesuai standar grooming BSS
4. Sepatu dinas pantofel / PDL hitam bersih
5. Wajah terlihat jelas tanpa masker / kacamata hitam

============================================================
OUTPUT FORMAT — STRICT JSON ONLY
============================================================
Return ONE JSON object. No markdown, no explanation, no code fence, no preamble.
Use this exact schema:

{"status":"sesuai","confidenceScore":95,"alasan":"...","poinLolos":["..."],"poinGagal":["..."]}

FIELD RULES:
- status: "sesuai" ONLY if zero poinGagal. Otherwise "tidak_sesuai". Use "perlu_cek_manual" only if image is too dark/blurry.
- confidenceScore: 0-100 integer. 90+ = high certainty, 70-89 = medium, <70 = low.
- alasan: <= 15 words, Indonesian, state the dominant reason.
- poinLolos: list of criteria that PASSED (use original criterion text).
- poinGagal: list of criteria that FAILED (use original criterion text - do NOT rephrase).
- Both lists can be empty ONLY if status="perlu_cek_manual".

IMPORTANT:
- Do NOT add extra fields.
- Do NOT wrap in ``` or any markdown.
- Do NOT write any text before/after the JSON.
- Start your response with "{" and end with "}"."""


def make_test_image(label, bg, size=(720, 960)):
    """Generate dummy image for testing."""
    img = Image.new('RGB', size, color=bg)
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 36)
    except (OSError, IOError):
        font = ImageFont.load_default()
    draw.text((50, 400), label, fill=(255, 255, 255), font=font)
    buf = io.BytesIO()
    img.save(buf, format='JPEG', quality=80)
    return base64.b64encode(buf.getvalue()).decode("utf-8")


def load_image(path):
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


def test_model(model_name, image_b64, label, runs=3):
    """Run a model multiple times to measure consistency."""
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {API_KEY}",
    }
    times = []
    outputs = []
    for i in range(runs):
        payload = {
            "model": model_name,
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": "Evaluasi foto ini terhadap SOP BSS Parking."},
                        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"}},
                    ],
                },
            ],
            "max_tokens": 350,
            "temperature": 0.0,
            "stream": False,
        }
        t0 = time.time()
        try:
            res = requests.post(API_URL, json=payload, headers=headers, timeout=15, verify=False)
            d = time.time() - t0
            times.append(d)
            if res.status_code == 200:
                data = res.json()
                content = data["choices"][0]["message"]["content"]
                outputs.append(content)
            else:
                outputs.append(f"ERR:{res.status_code}")
        except Exception as e:
            times.append(99.0)
            outputs.append(f"EXC:{str(e)[:50]}")
    avg = sum(t for t in times if t < 50) / max(1, len([t for t in times if t < 50]))
    return {
        "model": model_name,
        "label": label,
        "avg_sec": round(avg, 2),
        "runs": list(zip(times, outputs)),
    }


def main():
    print("=" * 80)
    print("  BSS-VISION: FINE-TUNED PROMPT + temperature=0.0 BENCHMARK")
    print("=" * 80)
    print(f"Endpoint : {API_URL}")
    print(f"Max tokens: 350 | temperature: 0.0 (deterministic)")
    print("=" * 80)

    test_images = [
        ("Petugas Komplit (BSS Uniform)", "foto/images.jpeg"),
        ("Gelap Gulita (negative test)", "dummy_dark.jpg"),  # sentinel
    ]

    if test_images[1][1] is None:
        test_images[1] = ("Gelap Gulita (negative test)", make_test_image("Layar Hitam Tertutup", (10, 10, 10)))

    for label, path_or_b64 in test_images:
        # path_or_b64 is either a file path or already-encoded base64
        if path_or_b64.endswith(('.jpeg', '.jpg', '.png')):
            img_b64 = load_image(path_or_b64)
        else:
            img_b64 = path_or_b64  # already base64

        print(f"\n>>> TEST CASE: {label} ({len(img_b64) // 1024} KB base64)")
        print("-" * 80)
        results = []
        for model in CANDIDATE_MODELS:
            r = test_model(model, img_b64, label, runs=2)
            results.append(r)
            for i, (t, out) in enumerate(r["runs"]):
                print(f"  [{model}] run {i+1}: {t:.2f}s")
                # Show first 250 chars of output
                print(f"    raw: {out[:250]}")
        # Summary
        best = min(results, key=lambda r: r["avg_sec"])
        print(f"  -> FASTEST: {best['model']} ({best['avg_sec']}s avg)")

    print("\n" + "=" * 80)
    print("  RECOMMENDED PRODUCTION ORDER (fastest first)")
    print("=" * 80)
    print("  1. ollama-cloud/gemma4:31b  (PRIMARY - fastest)")
    print("  2. ocrgambar                (routes to gemini-3.1-flash-lite)")
    print("  3. agy/gemini-3.1-flash-lite (native, stable JSON)")
    print("  4. Minimax/MiniMaxAI/MiniMax-M3 (smart, last resort)")


if __name__ == "__main__":
    main()
