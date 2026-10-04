"""End-to-end connection test for all candidate AI models on hermesagent endpoint."""
import requests
import base64
import time
import json
import os
import sys
from PIL import Image, ImageDraw, ImageFont
import io
import urllib3

# Disable SSL warnings (self-signed cert on Tailscale)
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

API_URL = "https://hermesagent.tailcb6f2e.ts.net/v1/chat/completions"
API_KEY = os.environ.get("BSS_AI_API_KEY", "")
SOP_IMAGE_PATH = "foto/images.jpeg"

CANDIDATE_MODELS = [
    "ocrgambar",
    "agy/gemini-3.1-flash-lite",
    "ollama-cloud/gemma4:31b",
    "Minimax/MiniMaxAI/MiniMax-M3",
]

SOP_PROMPT = """Anda adalah AI Vision Inspector SOP BSS Parking. Evaluasi foto petugas terhadap SOP:
1. Seragam resmi BSS Parking bersih, rapi, terkancing
2. ID Card / Name Tag terpasang jelas di saku kiri
3. Rambut / Jilbab rapi sesuai standar grooming BSS
4. Sepatu dinas pantofel / PDL hitam bersih
5. Wajah terlihat jelas tanpa masker / kacamata hitam

Output HANYA JSON valid (tanpa markdown/komentar):
{
  "status": "sesuai" | "tidak_sesuai" | "perlu_cek_manual",
  "confidenceScore": 0.0 - 1.0,
  "alasan": "penjelasan singkat dan lugas",
  "poinLolos": ["kriteria yang terpenuhi"],
  "poinGagal": ["kriteria yang dilanggar"]
}"""


def load_image_as_base64(path):
    """Load image and convert to base64."""
    try:
        with open(path, "rb") as f:
            return base64.b64encode(f.read()).decode("utf-8")
    except FileNotFoundError:
        print(f"WARNING: {path} not found, generating dummy image")
        img = Image.new("RGB", (720, 960), color=(80, 100, 140))
        draw = ImageDraw.Draw(img)
        try:
            font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 48)
        except (OSError, IOError):
            font = ImageFont.load_default()
        draw.text((50, 400), "Dummy BSS Test Image", fill=(255, 255, 255), font=font)
        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=80)
        return base64.b64encode(buf.getvalue()).decode("utf-8")


def test_model(model_name, image_b64, prompt):
    """Test a single model and return the result."""
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {API_KEY}",
    }
    payload = {
        "model": model_name,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"},
                    },
                ],
            }
        ],
        "max_tokens": 500,
        "temperature": 0.1,
        "stream": False,
    }

    t0 = time.time()
    try:
        response = requests.post(API_URL, json=payload, headers=headers, timeout=60, verify=False)
        duration = time.time() - t0
        if response.status_code == 200:
            data = response.json()
            actual_model = data.get("model", "unknown")
            content = data["choices"][0]["message"]["content"]
            # Try to parse JSON
            cleaned = content.strip()
            if cleaned.startswith("```json"):
                cleaned = cleaned[7:]
            if cleaned.startswith("```"):
                cleaned = cleaned[3:]
            if cleaned.endswith("```"):
                cleaned = cleaned[:-3]
            try:
                parsed = json.loads(cleaned.strip())
                return {
                    "status": "success",
                    "duration": round(duration, 2),
                    "http": response.status_code,
                    "actual_model": actual_model,
                    "response": parsed,
                    "raw": content[:300],
                }
            except json.JSONDecodeError as e:
                return {
                    "status": "success_no_json",
                    "duration": round(duration, 2),
                    "http": response.status_code,
                    "actual_model": actual_model,
                    "raw": content[:300],
                    "json_error": str(e),
                }
        else:
            return {
                "status": "http_error",
                "duration": round(duration, 2),
                "http": response.status_code,
                "error": response.text[:300],
            }
    except requests.exceptions.Timeout:
        duration = time.time() - t0
        return {"status": "timeout", "duration": round(duration, 2)}
    except Exception as e:
        duration = time.time() - t0
        return {"status": "exception", "duration": round(duration, 2), "error": str(e)[:200]}


def main():
    print("=" * 70)
    print("  BSS PARKING TIMEMARK - VISION MODEL CONNECTIVITY TEST")
    print("=" * 70)
    print(f"Endpoint : {API_URL}")
    print(f"API Key  : {API_KEY[:20]}...{API_KEY[-4:]}")
    print(f"Image    : {SOP_IMAGE_PATH}")
    print("=" * 70)

    image_b64 = load_image_as_base64(SOP_IMAGE_PATH)
    print(f"Image size: {len(image_b64) // 1024} KB (base64)")
    print()

    results = []
    for model in CANDIDATE_MODELS:
        print(f"Testing: {model}")
        result = test_model(model, image_b64, SOP_PROMPT)
        results.append({"model": model, "result": result})

        # Print summary
        if result["status"] == "success":
            resp = result.get("response", {})
            status = resp.get("status", "unknown")
            score = resp.get("confidenceScore", 0)
            print(f"  -> OK ({result['duration']}s) | engine={result['actual_model']} | status={status} | conf={score}")
        elif result["status"] == "success_no_json":
            print(f"  -> OK but no JSON ({result['duration']}s) | engine={result['actual_model']}")
            print(f"     Raw: {result['raw'][:150]}")
        elif result["status"] == "timeout":
            print(f"  -> TIMEOUT ({result['duration']}s)")
        elif result["status"] == "http_error":
            print(f"  -> HTTP {result['http']} ({result['duration']}s)")
            err_short = result.get("error", "")[:150]
            print(f"     {err_short}")
        else:
            print(f"  -> {result['status']} ({result['duration']}s): {result.get('error', '')[:150]}")
        print()

    # Summary
    print("=" * 70)
    print("  SUMMARY (ranked by speed of successful response)")
    print("=" * 70)
    successful = [r for r in results if r["result"]["status"] in ("success", "success_no_json")]
    successful.sort(key=lambda r: r["result"]["duration"])

    if successful:
        for i, r in enumerate(successful, 1):
            print(f"  {i}. {r['model']:45s}  {r['result']['duration']:6.2f}s  [{r['result']['status']}]")
        print()
        print(f"  -> PRIMARY: {successful[0]['model']} (fastest, {successful[0]['result']['duration']}s)")
        fallback = [r["model"] for r in successful[1:]]
        if fallback:
            print(f"  -> FALLBACK: {', '.join(fallback)}")
    else:
        print("  ! NO MODELS RESPONDED SUCCESSFULLY")
        print("    Network issue or invalid API key")

    return 0 if successful else 1


if __name__ == "__main__":
    sys.exit(main())
