# Laporan Audit & Implementasi Retensi Penyimpanan (2026-11-08)

Laporan ini mendokumentasikan implementasi otomatisasi pembersihan berkala (*daily storage retention*) untuk bucket `task-proofs` pada project Supabase **PmaManado** (`sxsjixnnlzhjinzcyhjb`) guna memulihkan kuota penyimpanan Free Tier (1 GB).

---

## 1. Kebijakan & Aturan Retensi

Implementasi Edge Function `storage-retention` menerapkan tiga aturan pembersihan terukur:
1. **Aturan 1 (Orphan Task Proofs)**: Objek dengan prefix `proof_task_*` yang **TIDAK tercatat** pada kolom `foto_bukti` di tabel manapun (`daily_tasks_manado`, `daily_tasks_bali`, `daily_tasks_ho`) dan berumur **> 2 hari** dihapus.
2. **Aturan 2 (Aged Task Proofs)**: Objek dengan prefix `proof_task_*` yang berumur **> 7 hari** (baik tercatat aktif maupun tidak) dihapus.
3. **Aturan 3 (Aged Temuan Fix Proofs)**: Objek dengan prefix `proof_fix_*` yang berumur **> 30 hari** dihapus.

### 🛡️ Guard Pengaman Ketat (Hard Safety Caps)
- **Nama File Regex**: Hanya objek yang lolos regex `^proof_(task|fix)_[A-Za-z0-9_\-]+\.jpg$` yang dapat disentuh. File lain di luar pola ini (misal file konfigurasi, logo, template) diabaikan 100%.
- **Batas Durasi Minimum**: Sistem menolak eksekusi jika parameter batas waktu lebih rendah dari batas aman (orphan < 2 hari, task < 6 hari, fix < 29 hari).
- **Fail-Safe PostgREST**: Jika pembacaan tabel database `daily_tasks_*` mengalami kendala teknis/koneksi, Aturan 1 otomatis di-*skip* demi mencegah penghapusan foto aktif secara tidak sengaja, dan sistem hanya menjalankan Aturan 2 & 3.
- **Autentikasi Timing-Safe**: Pemanggilan Edge Function dilindungi header rahasia `x-cron-secret` yang divalidasi menggunakan perbandingan waktu konstan (*constant-time comparison*) untuk mencegah serangan *timing attack*.

---

## 2. Jadwal Eksekusi Otomatis (Cron)

- **Waktu Eksekusi Awal**: Setiap hari pukul **03:00 WITA** (**19:00 UTC**).
- **Ekstensi**: `pg_cron` dan `pg_net`.
- **Status Job**: Aktif (`active: true`).

### Rincian Baris Cron Job (`cron.job`):
| Field | Nilai |
|---|---|
| `jobid` | `1` |
| `jobname` | `storage-retention-daily` |
| `schedule` | `0 19 * * *` |
| `active` | `true` |
| `command` | `select net.http_post(url := 'https://sxsjixnnlzhjinzcyhjb.supabase.co/functions/v1/storage-retention', ...)` |

Kredensial disimpan terenkripsi di dalam **Supabase Vault** (`storage_retention_cron_secret`) dan didekripsi dinamis oleh Postgres saat cron mengeksekusi request HTTP via `pg_net`.

---

## 3. Hasil Pengujian Unit & Verifikasi Kode

Seluruh pengujian unit berjalan secara otomatis via Deno test runner dengan mocked client dan zero network dependency:
- `Auth: 401 without secret or with wrong secret` — **PASSED**
- `Safety Cap: refuse if cutoff below minimum allowed` — **PASSED**
- `Retention: 8-day-old proof_task deleted, 6-day-old kept` — **PASSED**
- `Retention: referenced 3-day-old kept and unreferenced 3-day-old deleted` — **PASSED**
- `Retention: table-read failure skips rule 1 (fail-safe)` — **PASSED**
- `Retention: proof_fix 31-day-old deleted, 26-day-old kept` — **PASSED**
- `Retention: foreign name "other.png" never deleted` — **PASSED**
- `Retention: dryRun counts correctly and deletes nothing` — **PASSED**
- `Pagination: handles > 1000 objects in storage and batches deletes in 100` — **PASSED**

---

## 4. Hasil Eksekusi Dry-Run

Pemanggilan Edge Function pertama dilakukan dengan parameter `{"dryRun": true}`:

| Metrik | Hasil Dry-Run | Verifikasi SQL Database | Selisih (Delta) |
|---|---|---|---|
| **Total Objek Dipindai** | 3,879 | 3,879 | 0 (0%) |
| **Matched Orphan (>2d)** | 1,947 | 1,947 | 0 (0%) |
| **Matched Aged Task (>7d)** | 457 | 457 | 0 (0%) |
| **Matched Aged Fix (>30d)** | 0 | 0 | 0 (0%) |
| **Total Objek Kandidat** | **2,404** | **2,404** | **0 (0.0% — Presisi 100%)** |
| **Estimasi Bytes Dibebaskan** | **1,636,604,287 bytes (~1.56 GB)** | 1,636,604,287 bytes | 0 (0%) |
| **Objek Dihapus Nyata** | **0** | - | Sesuai ekspektasi dry-run |

---

## 5. Hasil Eksekusi Live (Pembersihan Aktual)

Pemanggilan Edge Function live dijalankan dengan parameter `{"dryRun": false}`:

| Metrik | Nilai Aktual | Keterangan |
|---|---|---|
| **Status Pemanggilan** | **HTTP 200 OK** | Berhasil tereksekusi tanpa kendala |
| **Objek Dihapus** | **2,404 objek** | Dihapus melalui Supabase Storage API dalam 25 batch |
| **Storage Dibebaskan** | **1,636,604,287 bytes (~1,636.6 MB / ~1.56 GB)** | Ruang penyimpanan aktual kembali bersih |
| **Jumlah Error** | **0** | Tidak ada kegagalan batch (*zero errors*) |

---

## 6. Perbandingan Status Bucket `task-proofs` (Sebelum vs Sesudah)

Pengukuran langsung pada tabel `storage.objects` via SQL Management API:

| Parameter | Sebelum Pembersihan | Setelah Pembersihan | Pengurangan / Selisih |
|---|---|---|---|
| **Jumlah Objek** | 3,879 file | **1,475 file** | **-2,404 file (-62.0%)** |
| **Total Ukuran (Bytes)** | 2,786,568,825 bytes | **1,149,964,538 bytes** | **-1,636,604,287 bytes** |
| **Total Ukuran (Pretty)** | **2,657 MB (~2.66 GB)** | **1,097 MB (~1.07 GB)** | **-1,560.7 MB (-58.7%)** |
| **Objek Tertua** | 2026-10-16 19:15:27 UTC | **2026-11-01 09:39:08 UTC** | File > 7 hari dibersihkan |
| **Objek Terbaru** | 2026-11-08 05:15:26 UTC | **2026-11-08 05:15:26 UTC** | Foto aktif terjaga utuh |

---

## 7. Kesimpulan Awal

Pembersihan tahap pertama berhasil membebaskan ~1.56 GB. Namun, karena aplikasi versi lama (<=2.0.133) di lapangan masih mengunggah duplikat dengan rasio ~10x, penyimpanan stabil di 1,097 MB (sedikit di atas batas 1 GB). Tahap kedua pembersihan agresif duplikat diterapkan di bawah ini.

---

## 8. Pembersihan Agresif Duplikat 6 Jam (2026-11-08 duplicate purge 6h)

### A. Analisis Masalah Duplikasi Cepat
Dari pengukuran 24 jam terakhir pada aplikasi versi lama:
- Terjadi pengunggahan 559 MB foto baru (rata-rata 781 kB per foto).
- Pada jendela 1 jam (02:00 WITA), dari 388 foto yang diunggah hanya terdapat 40 variasi ukuran file unik (~10x pengunggahan duplikat untuk foto yang sama).
- Kebijakan grace period 2 hari membuat penumpukan duplikat baru mempertahankan bucket di angka 1,097 MB.

### B. Aturan Duplikat Baru (Duplicate Twin Rule)
1. **Aturan 6 Jam**: Objek orphan (tidak ada di `daily_tasks_*.foto_bukti`) yang berusia **> 6 jam** dapat langsung dihapus **JIKA** terdapat objek lain dengan prefix kelompok sama (`proof_${keyPrefix}_${n}`) dan ukuran `metadata.size` yang identik yang **SUDAH TERCATAT (REFERENCED)** di database.
2. **Grace Period 2 Hari Tetap Aman**: Objek orphan yang belum memiliki kembaran terverifikasi di database tetap mempertahankan grace period 2 hari penuh untuk mencegah terhapusnya foto saat proses sync DB tertunda.
3. **Objek Aktif/Tercatat Tidak Pernah Dihapus**: Objek yang tercatat di database tidak akan pernah disentuh oleh aturan duplikat berapapun usianya (< 7 hari untuk task, < 30 hari untuk fix).

### C. Pembaruan Jadwal Cron (Setiap 6 Jam)
Jadwal `pg_cron` diperbarui dari harian menjadi setiap 6 jam (`0 */6 * * *` UTC) agar pembersihan duplikat berjalan berkala tanpa menunggu malam hari.

Rincian baris `cron.job` aktif:
```json
[
  {
    "jobid": 2,
    "jobname": "storage-retention-daily",
    "schedule": "0 */6 * * *",
    "active": true,
    "command": "\n  select net.http_post(\n    url := 'https://sxsjixnnlzhjinzcyhjb.supabase.co/functions/v1/storage-retention',\n    headers := jsonb_build_object(\n      'Content-Type', 'application/json',\n      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'storage_retention_cron_secret')\n    ),\n    body := '{}'::jsonb\n  );\n  "
  }
]
```

### D. Hasil Pengujian Unit Baru (10 Tests Passed)
Suite `supabase/functions/storage-retention/index_test.ts`:
- `extractGroupPrefix: correctly extracts prefix before last millis timestamp` — **PASSED**
- `Auth: 401 without secret or with wrong secret` — **PASSED**
- `Safety Cap: refuse if cutoff below minimum allowed` — **PASSED**
- `Requirement 4(a): orphan >6h with referenced same-size twin -> deleted` — **PASSED**
- `Requirement 4(b): young orphan without twin -> kept` — **PASSED**
- `Requirement 4(c): orphan >2d without twin -> deleted` — **PASSED**
- `Requirement 4(d): referenced object never deleted regardless of age (under 7d)` — **PASSED**
- `Requirement 4(e): proof_task >7d and proof_fix >30d retention unchanged` — **PASSED**
- `Retention: dry_run body flag counts correctly and deletes nothing` — **PASSED**
- `Retention: table-read failure skips orphan rules (fail-safe)` — **PASSED**

### E. Hasil Eksekusi Dry-Run
Pemanggilan Edge Function dengan `{"dry_run": true}`:
- `scanned`: 1,475 objek
- `matchedDuplicateOrphan`: 1,060 objek
- `matchedOrphan`: 0 objek
- `matchedTask`: 0 objek
- `matchedFix`: 0 objek
- `totalMatched`: 1,060 objek
- `deleted`: 0 objek
- `bytesFreed`: 889,515,021 bytes (**848.3 MB**)
- `errors`: 0
- **Verifikasi Jalur**: Dikonfirmasi **0 (nol) objek terdaftar/aktif** yang masuk daftar hapus.

### F. Hasil Eksekusi Live Purge (Aktual)
Pemanggilan Edge Function live dengan `{"dry_run": false}`:
- `deleted`: **1,060 objek** (dihapus via Storage API dalam 11 batch)
- `bytesFreed`: **889,515,021 bytes (~848.3 MB / 889.5 MB)**
- `errors`: **0**

### G. Status Akhir Bucket `task-proofs` (Re-Measure SQL)
Query pengukuran aktual pada `storage.objects`:
```sql
select bucket_id, count(*), sum((metadata->>'size')::bigint)/1048576 as size_mb, pg_size_pretty(sum((metadata->>'size')::bigint)) as size_pretty
from storage.objects
group by 1;
```

Hasil:
| Parameter | Sebelum Purge 6 Jam | Setelah Purge 6 Jam | Perubahan / Penurunan |
|---|---|---|---|
| **Jumlah Objek** | 1,475 file | **415 file** | **-1,060 file (-71.9%)** |
| **Total Ukuran (Bytes)** | 1,149,964,538 bytes | **260,449,517 bytes** | **-889,515,021 bytes** |
| **Total Ukuran (MB)** | 1,097 MB (~1.07 GB) | **248.38 MB (~248 MB)** | **-848.3 MB (-77.3%)** |
| **Status Kuota Free Tier (1 GB)** | Melampaui (107%) | **Sangat Aman (24.2%)** | **Tersedia Headroom ~776 MB** |
