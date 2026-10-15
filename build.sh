#!/usr/bin/env bash
# =====================================================
# build.sh — BssparkingTimeMark Secure Build Script
# =====================================================
# Loads secrets from .env and passes them as --dart-define flags.
# Usage:
#   chmod +x build.sh
#   ./build.sh          # builds release APK
#   ./build.sh run      # runs debug with secrets injected
# =====================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ .env file not found!"
  echo "   Copy .env.example ke .env dan isi nilai-nilainya:"
  echo "   cp .env.example .env"
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

DART_DEFINES=(
  "--dart-define=BSS_AI_API_KEY=${BSS_AI_API_KEY:-}"
  "--dart-define=BSS_GSHEET_TOKEN=${BSS_GSHEET_TOKEN:-}"
  "--dart-define=BSS_GSHEET_SCRIPT_URL=${BSS_GSHEET_SCRIPT_URL:-}"
  "--dart-define=BSS_GSHEET_SPREADSHEET_URL=${BSS_GSHEET_SPREADSHEET_URL:-}"
)

if [[ "${1:-build}" == "run" ]]; then
  echo "🚀 Running debug with injected secrets..."
  flutter run "${DART_DEFINES[@]}" "${@:2}"
elif [[ "${1:-build}" == "split" ]]; then
  echo "📦 Building release split per ABI APKs (v32 & v64) with injected secrets..."
  flutter build apk --release --split-per-abi "${DART_DEFINES[@]}" "${@:2}"
  echo "✅ Split APKs ready at build/app/outputs/flutter-apk/"
elif [[ "${1:-build}" == "web" ]]; then
  echo "🌐 Building release Web PWA with injected secrets..."
  flutter build web --release --base-href "/" "${DART_DEFINES[@]}" "${@:2}"
  echo "✅ Web ready at build/web"
else
  echo "📦 Building release APK with injected secrets..."
  flutter build apk --release "${DART_DEFINES[@]}" "${@:2}"
  echo "✅ APK ready at build/app/outputs/flutter-apk/app-release.apk"
fi
