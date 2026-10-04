#!/usr/bin/env bash
# Kirim ringkasan perubahan & file APK ke bot Telegram (Bot API).
# Kredensial TIDAK disimpan di repo, tapi di file env lokal:
#   ~/.config/bss_telegram.env  (chmod 600)
# Isi file env:
#   BSS_TG_BOT_TOKEN="123456:ABC-..."
#   BSS_TG_CHAT_ID="987654321"
#
# Pakai:
#   telegram_notify.sh -m "ringkasan perubahan..."
#   telegram_notify.sh -d "/path/app.apk" -c "caption opsional"
#   telegram_notify.sh -p "/path/ss.png" -c "caption opsional"
set -euo pipefail

ENV_FILE="${BSS_TG_ENV:-$HOME/.config/bss_telegram.env}"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

TOKEN="${BSS_TG_BOT_TOKEN:-}"
CHAT="${BSS_TG_CHAT_ID:-}"

if [[ -z "$TOKEN" || -z "$CHAT" ]]; then
  echo "ERROR: BSS_TG_BOT_TOKEN / BSS_TG_CHAT_ID belum diisi di $ENV_FILE" >&2
  exit 1
fi

MODE="message"
FILE=""
CAPTION=""
MSG=""

while getopts "m:d:p:c:" opt; do
  case "$opt" in
    m) MSG="$OPTARG" ;;
    d) MODE="document"; FILE="$OPTARG" ;;
    p) MODE="photo"; FILE="$OPTARG" ;;
    c) CAPTION="$OPTARG" ;;
  esac
done

API="https://api.telegram.org/bot${TOKEN}"

if [[ "$MODE" == "photo" ]]; then
  if [[ -z "$FILE" || ! -f "$FILE" ]]; then
    echo "ERROR: file tidak ketemu: $FILE" >&2
    exit 1
  fi
  # Decode %0A to real newlines if present
  if [[ "$CAPTION" =~ %0[Aa] ]]; then
    CAPTION="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.unquote(sys.argv[1]))' "$CAPTION")"
  fi
  RESP=$(curl -sS --fail --max-time 300 --retry 3 --retry-all-errors --retry-delay 10 --ipv4 \
    -X POST "${API}/sendPhoto" \
    -F "chat_id=${CHAT}" \
    -F "photo=@${FILE}" \
    -F "parse_mode=HTML" \
    --form-string "caption=${CAPTION:-Screenshot perubahan BssparkingTimeMark}")
  echo "$RESP"
  if echo "$RESP" | grep -q '"ok":true'; then
    echo "OK: screenshot terkirim."
  else
    echo "ERROR: gagal kirim screenshot Telegram: $RESP" >&2
    exit 1
  fi
elif [[ "$MODE" == "document" ]]; then
  if [[ -z "$FILE" || ! -f "$FILE" ]]; then
    echo "ERROR: file tidak ketemu: $FILE" >&2
    exit 1
  fi
  if [[ "$CAPTION" =~ %0[Aa] ]]; then
    CAPTION="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.unquote(sys.argv[1]))' "$CAPTION")"
  fi
  RESP=$(curl -sS --fail --max-time 600 --retry 3 --retry-all-errors --retry-delay 10 --ipv4 \
    -X POST "${API}/sendDocument" \
    -F "chat_id=${CHAT}" \
    -F "document=@${FILE}" \
    -F "parse_mode=HTML" \
    --form-string "caption=${CAPTION:-File terbaru BssparkingTimeMark}")
  echo "$RESP"
  if echo "$RESP" | grep -q '"ok":true'; then
    echo "OK: dokumen terkirim."
  else
    echo "ERROR: gagal kirim dokumen Telegram: $RESP" >&2
    exit 1
  fi
else
  if [[ -z "$MSG" ]]; then
    echo "ERROR: pesan kosong. Pakai -m \"teks\"" >&2
    exit 1
  fi
  if [[ "$MSG" =~ %0[Aa] ]]; then
    MSG="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.unquote(sys.argv[1]))' "$MSG")"
  fi
  RESP=$(curl -sS --fail --max-time 30 \
    -X POST "${API}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "$(python3 -c 'import json,sys; print(json.dumps({"chat_id": sys.argv[1], "text": sys.argv[2], "parse_mode": "HTML"}))' "$CHAT" "$MSG")")
  echo "$RESP"
  if echo "$RESP" | grep -q '"ok":true'; then
    echo "OK: ringkasan terkirim."
  else
    echo "ERROR: gagal kirim pesan Telegram: $RESP" >&2
    exit 1
  fi
fi
