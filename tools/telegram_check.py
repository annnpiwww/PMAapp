#!/usr/bin/env python3
"""Cek pesan/gambar terbaru yang masuk ke bot Telegram BSS.

Menarik foto resolusi tertinggi dan caption dari bot Telegram,
lalu menyimpannya ke lokasi standar:
  - /tmp/opencode/telegram_input.png
  - /tmp/opencode/telegram_caption.txt

Penggunaan:
    python3 tools/telegram_check.py --json
    python3 tools/telegram_check.py --peek
"""

import argparse
import json
import os
import shutil
import sys
import urllib.error
import urllib.parse
import urllib.request

ENV_FILE = os.environ.get("BSS_TG_ENV", os.path.expanduser("~/.config/bss_telegram.env"))
OFFSET_FILE = os.path.expanduser("~/.config/bss_telegram.offset")
OUT_DIR = "/tmp/opencode"
STD_PHOTO_PATH = os.path.join(OUT_DIR, "telegram_input.png")
STD_CAPTION_PATH = os.path.join(OUT_DIR, "telegram_caption.txt")


def load_env(path):
    vals = {}
    if os.path.exists(path):
        with open(path) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    vals[k.strip()] = v.strip().strip('"').strip("'")
    return vals


def api(token, method, params=None):
    url = f"https://api.telegram.org/bot{token}/{method}"
    data = urllib.parse.urlencode(params or {}).encode() if params else None
    req = urllib.request.Request(url, data=data)
    with urllib.request.urlopen(req, timeout=35) as r:
        return json.load(r)


def parse_arguments():
    parser = argparse.ArgumentParser(description="Periksa dan unduh foto/caption dari bot Telegram")
    parser.add_argument("--json", action="store_true", help="Keluarkan output dalam format JSON terstruktur")
    parser.add_argument("--peek", action="store_true", help="Jangan perbarui offset file (dry run)")
    parser.add_argument("--all", "--batch", dest="batch", action="store_true", help="Unduh SEMUA foto dan pesan dalam antrean batch (bukan cuma 1 terakhir)")
    return parser.parse_args()


def main():
    args = parse_arguments()
    token = load_env(ENV_FILE).get("BSS_TG_BOT_TOKEN", "")
    if not token:
        err = {"status": "error", "message": f"BSS_TG_BOT_TOKEN belum diisi di {ENV_FILE}"}
        if args.json:
            print(json.dumps(err))
        else:
            print("ERROR:", err["message"], file=sys.stderr)
        return 1

    offset = 0
    if os.path.exists(OFFSET_FILE):
        try:
            offset = int(open(OFFSET_FILE).read().strip() or "0")
        except ValueError:
            offset = 0

    try:
        res = api(token, "getUpdates", {"offset": offset, "timeout": 0})
        updates = res.get("result", [])
    except Exception as e:
        err = {"status": "error", "message": f"Gagal menghubungi Telegram API: {e}"}
        if args.json:
            print(json.dumps(err))
        else:
            print("ERROR:", err["message"], file=sys.stderr)
        return 1

    if not updates:
        out = {"status": "empty", "has_photo": False, "message": "Tidak ada pesan baru."}
        if args.json:
            print(json.dumps(out))
        else:
            print("Tidak ada pesan baru.")
        return 0

    os.makedirs(OUT_DIR, exist_ok=True)
    batch_dir = os.path.join(OUT_DIR, "batch")
    os.makedirs(batch_dir, exist_ok=True)
    new_offset = offset

    items = []
    target_update = None
    target_file_id = None
    target_caption = ""
    target_ext = ".png"

    # Iterasi semua update
    for idx, u in enumerate(updates, 1):
        new_offset = max(new_offset, u["update_id"] + 1)
        msg = u.get("message") or u.get("edited_message") or {}
        text = msg.get("text") or msg.get("caption") or ""
        photos = msg.get("photo") or []
        doc = msg.get("document") or {}
        sender = msg.get("chat", {}).get("first_name", "Unknown")
        chat_id = msg.get("chat", {}).get("id")
        date_ts = msg.get("date")

        file_id = None
        ext = ".jpg"
        if photos:
            file_id = photos[-1]["file_id"]
            ext = ".jpg"
        elif doc and doc.get("mime_type", "").startswith("image/"):
            file_id = doc.get("file_id")
            ext = os.path.splitext(doc.get("file_name", ""))[1] or ".png"

        item_info = {
            "index": idx,
            "update_id": u["update_id"],
            "chat_id": chat_id,
            "sender": sender,
            "date": date_ts,
            "text": text,
            "has_photo": bool(file_id),
            "photo_path": None,
        }

        if file_id:
            target_update = u
            target_file_id = file_id
            target_caption = text
            target_ext = ext

            # Unduh setiap foto ke batch folder jika mode batch atau multiple updates
            try:
                finfo = api(token, "getFile", {"file_id": file_id})
                fpath = finfo["result"]["file_path"]
                raw_ext = os.path.splitext(fpath)[1] or ext
                batch_photo_path = os.path.join(batch_dir, f"photo_{idx:02d}_{u['update_id']}{raw_ext}")
                urllib.request.urlretrieve(f"https://api.telegram.org/file/bot{token}/{fpath}", batch_photo_path)
                item_info["photo_path"] = batch_photo_path

                # Simpan caption pendamping
                if text:
                    batch_cap_path = os.path.join(batch_dir, f"caption_{idx:02d}_{u['update_id']}.txt")
                    with open(batch_cap_path, "w", encoding="utf-8") as cf:
                        cf.write(text)
            except Exception as e:
                if not args.json:
                    print(f"Peringatan: Gagal mengunduh foto item {idx}: {e}", file=sys.stderr)

        elif text:
            # Simpan chat murni
            batch_text_path = os.path.join(batch_dir, f"chat_{idx:02d}_{u['update_id']}.txt")
            with open(batch_text_path, "w", encoding="utf-8") as tf:
                tf.write(text)

        items.append(item_info)

    # Simpan manifest batch
    manifest_path = os.path.join(batch_dir, "manifest.json")
    with open(manifest_path, "w", encoding="utf-8") as mf:
        json.dump(items, mf, indent=2, ensure_ascii=False)

    downloaded_path = None
    backup_path = None
    # Tetap sediakan single-file legacy path untuk kompatibilitas
    if target_file_id and target_update:
        # Cari file yang sudah terdownload di batch_dir
        last_photo_item = next((it for it in reversed(items) if it["has_photo"] and it["photo_path"]), None)
        if last_photo_item and os.path.exists(last_photo_item["photo_path"]):
            backup_path = last_photo_item["photo_path"]
            shutil.copyfile(backup_path, STD_PHOTO_PATH)
            downloaded_path = STD_PHOTO_PATH
            with open(STD_CAPTION_PATH, "w", encoding="utf-8") as cf:
                cf.write(target_caption)

    # Perbarui offset jika bukan mode peek
    if not args.peek:
        with open(OFFSET_FILE, "w") as fh:
            fh.write(str(new_offset))

    photo_items = [it for it in items if it["has_photo"]]
    result = {
        "status": "success",
        "has_photo": bool(photo_items),
        "total_updates": len(updates),
        "total_photos": len(photo_items),
        "batch_dir": batch_dir,
        "manifest_path": manifest_path,
        "items": items,
        "latest_photo_path": downloaded_path,
        "latest_caption": target_caption,
    }

    if args.json:
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        print(f"Status: {result['status']}")
        print(f"Total pesan/update masuk: {len(updates)}")
        print(f"Total foto terunduh: {len(photo_items)}")
        if photo_items:
            print(f"Folder batch: {batch_dir}")
            for p in photo_items:
                print(f"  - [{p['index']}] Foto: {p['photo_path']} | Caption: {p['text']}")
        if not photo_items and updates:
            print("Pesan teks baru masuk tanpa foto.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
