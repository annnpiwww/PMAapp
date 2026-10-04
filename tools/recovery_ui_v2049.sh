#!/usr/bin/env bash
# ==============================================================================
# Script Pemulihan (Recovery) Desain UI/UX BssparkingTimeMark ke versi v2.0.49
# ==============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${ROOT_DIR}/lib_v2049_backup"

if [[ ! -d "${BACKUP_DIR}" ]]; then
  echo "❌ Error: Direktori backup ${BACKUP_DIR} tidak ditemukan!" >&2
  exit 1
fi

echo "🔄 Memulai pemulihan UI/UX BssparkingTimeMark ke snapshot v2.0.49..."

# Restore lib
rm -rf "${ROOT_DIR}/lib"
cp -r "${BACKUP_DIR}" "${ROOT_DIR}/lib"

echo "✅ Berhasil! Desain UI/UX BssparkingTimeMark telah dipulihkan ke versi v2.0.49."
