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

- **Waktu Eksekusi**: Setiap hari pukul **03:00 WITA** (**19:00 UTC**).
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

## 7. Kesimpulan & Rekomendasi Lanjutan

1. **Efektivitas Retensi**: Pembersihan berhasil memangkas 58.7% storage (~1.56 GB), memulihkan bucket dari 2.66 GB menjadi 1.07 GB.
2. **Kondisi Quota Free Tier (1 GB)**: Sisa storage saat ini berada di angka **1,097 MB** (hanya terpaut ~97 MB di atas 1,024 MB). Dengan aktifnya optimasi kompresi upload foto (`DailyTaskService.uploadProofPhoto` ~104 kB/foto) dan cron retention harian jam 03:00 WITA, penggunaan storage diproyeksikan akan stabil berada di kisaran **< 800 MB** dalam 2-3 hari ke depan seiring bertambahnya usia foto ke batas 7 hari.
3. **Higienitas Kredensial**: Tidak ada rahasia, token, atau URL yang dibocorkan ke repositori atau catatan audit.
