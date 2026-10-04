#!/usr/bin/env bash
# Orca Emulator Bridge untuk BssparkingTimeMark & opencode
set -euo pipefail

PACKAGE="com.bssparking.timemark.bssparking_timemark"
PROJECT_DIR="/home/annnpii/Product development annpii/BssparkingTimeMark"
APK_PATH="${PROJECT_DIR}/bsstimemark/BSS-TimeMark-v2.0.13-ARM64-Release.apk"

CMD="${1:-status}"

case "$CMD" in
  status)
    echo "=== ORCA EMULATOR STATUS ==="
    orca emulator devices || true
    echo "=== ADB DEVICES ==="
    adb devices
    ;;
  install)
    if [[ ! -f "$APK_PATH" ]]; then
      # Fallback ke apk terbaru yang ada
      APK_PATH=$(ls -t "${PROJECT_DIR}/bsstimemark/"*.apk | head -1)
    fi
    echo "Menginstall APK ke emulator via Orca: $APK_PATH"
    orca emulator install "$APK_PATH" --reinstall
    echo "✓ Sukses terinstall!"
    ;;
  launch)
    echo "Membuka aplikasi di emulator..."
    orca emulator launch "$PACKAGE"
    echo "✓ Aplikasi diluncurkan!"
    ;;
  inspect)
    echo "Membaca accessibility tree layar emulator..."
    orca emulator ax
    ;;
  screenshot)
    OUT_PNG="${2:-/tmp/opencode/orca_screen.png}"
    echo "Mengambil screenshot dari emulator..."
    adb exec-out screencap -p > "$OUT_PNG"
    echo "✓ Screenshot tersimpan di $OUT_PNG"
    if [[ -f "${PROJECT_DIR}/tools/telegram_notify.sh" ]]; then
      "${PROJECT_DIR}/tools/telegram_notify.sh" -p "$OUT_PNG" -c "[Orca Emulator] Live Screenshot Layar Emulator BSS TimeMark" || true
    fi
    ;;
  *)
    echo "Usage: $0 {status|install|launch|inspect|screenshot}"
    exit 1
    ;;
esac
