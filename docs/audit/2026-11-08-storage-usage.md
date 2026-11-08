# Audit Penggunaan Supabase Storage (2026-11-08)

Audit ini dilakukan secara **READ-ONLY** via Supabase Management API untuk menganalisis penyebab kuota File Storage Supabase Free Plan (1 GB) terlampaui (2.02 GB / 2.66 GB aktual per SQL).

---

## 1. Ringkasan Storage per Project

| Project ID | Project Ref | Nama Project | Status | Akses SQL Storage | Total Storage Terpakai |
|---|---|---|---|---|---|
| `sxsjixnnlzhjinzcyhjb` | `sxsjixnnlzhjinzcyhjb` | **PmaManado** | `ACTIVE_HEALTHY` | Berhasil (via SQL) | **2,786.57 MB (~2.66 GB)** |
| `kqryfzhbcgiosvtsabhn` | `kqryfzhbcgiosvtsabhn` | **Curative** | `INACTIVE (Paused)` | Tidak (engine database mati) | N/A (Project Paused) |

> **Catatan Project Curative**: Project berstatus paused sehingga database engine tidak aktif dan tidak dapat di-query SQL tanpa me-unpause project. Project PmaManado sendiri sudah menggunakan ~2.66 GB, melampaui 100% dari total kuota org Free Tier (1.0 GB).

---

## 2. Rincian per Bucket (Project: PmaManado)

Query dieksekusi pada skema `storage.objects`:

```sql
select bucket_id, 
       count(*) as count, 
       sum((metadata->>'size')::bigint) as total_bytes,
       pg_size_pretty(sum((metadata->>'size')::bigint)) as total_pretty, 
       min(created_at) as min_created, 
       max(created_at) as max_created, 
       pg_size_pretty(avg((metadata->>'size')::bigint)::bigint) as avg_pretty,
       avg((metadata->>'size')::bigint)::bigint as avg_bytes
from storage.objects 
group by bucket_id 
order by sum((metadata->>'size')::bigint) desc;
```

### Hasil Query
| Bucket ID | Jumlah Objek | Total Ukuran | Rata-rata per Foto | Objek Tertua | Objek Terbaru |
|---|---|---|---|---|---|
| `task-proofs` | 3,879 | 2,786,568,825 bytes (**2,657 MB / ~2.66 GB**) | 718,373 bytes (**~702 kB**) | 2026-10-16 19:15:27 UTC | 2026-11-08 05:15:26 UTC |

---

## 3. Pertumbuhan per Bulan (`task-proofs`)

```sql
select date_trunc('month', created_at)::date as month, 
       count(*) as count, 
       sum((metadata->>'size')::bigint) as total_bytes,
       pg_size_pretty(sum((metadata->>'size')::bigint)) as total_size, 
       pg_size_pretty(avg((metadata->>'size')::bigint)::bigint) as avg_size 
from storage.objects 
where bucket_id = 'task-proofs' 
group by 1 
order by 1 desc;
```

### Hasil Query
| Bulan | Jumlah Objek | Total Ukuran | Rata-rata per Foto |
|---|---|---|---|
| **2026-11 (1-8 Nov, 8 hari)** | 1,940 | 1,460,830,868 bytes (**1,393 MB**) | 735 kB |
| **2026-10 (16-31 Okt, 16 hari)** | 1,939 | 1,325,737,957 bytes (**1,264 MB**) | 668 kB |

> **Analisis Laju Pertumbuhan**:
> - Di bulan November (8 hari berjalan), sistem mengunggah rata-rata **~242 foto/hari** dengan konsumsi storage **~174 MB/hari**.
> - Jika dibiarkan tanpa kompresi, storage akan bertambah sekitar **~5.2 GB - 5.5 GB per bulan**.

---

## 4. Top 10 Objek Terbesar

```sql
select name, 
       bucket_id, 
       (metadata->>'size')::bigint as size_bytes,
       pg_size_pretty((metadata->>'size')::bigint) as size_pretty, 
       created_at 
from storage.objects 
order by (metadata->>'size')::bigint desc 
limit 10;
```

### Hasil Query
| Nama File | Bucket | Ukuran | Tanggal Dibuat |
|---|---|---|---|
| `proof_task_1792975587185_3071_1_1793011690691.jpg` | `task-proofs` | 1,997 kB (2.05 MB) | 2026-10-26 10:48:13 UTC |
| `proof_task_1792975587185_3071_1_1793011740552.jpg` | `task-proofs` | 1,997 kB (2.05 MB) | 2026-10-26 10:49:03 UTC |
| `proof_task_1792975587185_3071_1_1793011792528.jpg` | `task-proofs` | 1,997 kB (2.05 MB) | 2026-10-26 10:49:55 UTC |
| `proof_task_1792975587185_3071_1_1793011716087.jpg` | `task-proofs` | 1,997 kB (2.05 MB) | 2026-10-26 10:48:38 UTC |
| `proof_task_1792975587185_3071_8_1793011791157.jpg` | `task-proofs` | 1,950 kB (2.00 MB) | 2026-10-26 10:49:54 UTC |
| `proof_task_1792975587185_3071_8_1793011707868.jpg` | `task-proofs` | 1,950 kB (2.00 MB) | 2026-10-26 10:48:31 UTC |
| `proof_task_1793236446312_7166_2_1793284341812.jpg` | `task-proofs` | 1,744 kB (1.79 MB) | 2026-10-29 14:32:24 UTC |
| `proof_task_1793236446312_7166_2_1793284304025.jpg` | `task-proofs` | 1,744 kB (1.79 MB) | 2026-10-29 14:31:46 UTC |
| `proof_task_1793236446312_7166_2_1793284266816.jpg` | `task-proofs` | 1,744 kB (1.79 MB) | 2026-10-29 14:31:09 UTC |
| `proof_task_1793236446312_7166_2_1793284267331.jpg` | `task-proofs` | 1,744 kB (1.79 MB) | 2026-10-29 14:31:10 UTC |

---

## 5. Simulasi Pengurangan Storage berdasarkan Retensi Waktu

Query SQL menghitung potensi storage yang dibebaskan jika diterapkan kebijakan penghapusan berkala:

```sql
select 
  count(*) filter (where created_at < now() - interval '30 days') as count_30d, 
  coalesce(pg_size_pretty(sum((metadata->>'size')::bigint) filter (where created_at < now() - interval '30 days')), '0 bytes') as size_30d, 
  count(*) filter (where created_at < now() - interval '60 days') as count_60d, 
  coalesce(pg_size_pretty(sum((metadata->>'size')::bigint) filter (where created_at < now() - interval '60 days')), '0 bytes') as size_60d, 
  count(*) filter (where created_at < now() - interval '90 days') as count_90d, 
  coalesce(pg_size_pretty(sum((metadata->>'size')::bigint) filter (where created_at < now() - interval '90 days')), '0 bytes') as size_90d
from storage.objects;
```

### Hasil Perhitungan SQL (Exact):
| Kebijakan Retensi | Objek Terkena | Storage Dibebaskan | Keterangan |
|---|---|---|---|
| **> 30 Hari** | **0** | **0 bytes** | Objek tertua berumur 23 hari (dibuat 16 Okt 2026) |
| **> 60 Hari** | **0** | **0 bytes** | Belum ada objek > 60 hari |
| **> 90 Hari** | **0** | **0 bytes** | Belum ada objek > 90 hari |

### Analisis Retensi Lebih Pendek (Tambahan):
| Kebijakan Retensi | Objek Terkena | Storage Dibebaskan | Persentase Pembebasan |
|---|---|---|---|
| **> 7 Hari** | 1,941 | **1,265 MB** | **~45.4%** |
| **> 14 Hari** | 1,059 | **666 MB** | **~23.9%** |
| **> 21 Hari** | 24 | **5.67 MB** | **~0.2%** |

---

## 6. Kesimpulan & Rekomendasi (Bahasa Indonesia)

1. **Penyebab Utama Kuota Penuh**:
   - Bucket tunggal `task-proofs` di project **PmaManado** memegang seluruh 2.66 GB (3,879 file).
   - Project **Curative** berstatus paused dan tidak berkontribusi pada penggunaan aktif saat ini.
   - Ukuran rata-rata foto bukti adalah **~718 kB** (bahkan beberapa mencapai **2 MB**) karena foto kamera HP diunggah tanpa kompresi pixel / downscale resolusi.

2. **Pencegahan Pertumbuhan (Mitigasi Telah Diimplementasikan)**:
   - Pada choke point upload `DailyTaskService.uploadProofPhoto`, foto bukti sekarang otomatis di-downscale sehingga sisi terpanjang maksimal **1280 px** (aspek rasio terjaga, no upscale) dengan JPEG quality **70**.
   - Hasil pengujian kompresi: ukuran foto bukti turun dari ~508 kB menjadi **~104 kB** (**penghematan ~79.3%**).
   - Estimasi rata-rata ukuran foto baru akan berkisar antara **80 - 120 kB**, memangkas laju konsumsi storage dari ~5.5 GB/bulan menjadi **< 1 GB/bulan**.

3. **Solusi untuk Kuota Free Plan (1 GB Limit)**:
   - Karena file tertua baru berumur 23 hari, aturan penghapusan > 30 hari saat ini belum membebaskan byte (0 bytes).
   - Jika ingin segera kembali di bawah kuota 1 GB sebelum batas 7 Desember 2026 tanpa upgrade paket:
     - Terapkan retensi **14 hari** (membebaskan ~666 MB, menyisakan ~2.0 GB).
     - Atau terapkan retensi **7 hari** (membebaskan ~1.26 GB, langsung mengembalikan penggunaan ke **~1.4 GB**, mendekati 1 GB).
     - Foto yang sudah dikompresi di masa mendatang akan membuat retensi 30 hari stabil di bawah kuota 1 GB.


---

## 7. Orphan & Duplikat Foto Bukti (Audit 2026-11-08)

### A. Root Cause Analisis Duplikasi Upload
1. **Mekanisme Kegagalan & Re-Upload**:
   - Alur `DailyTaskService.completeTask` awalnya mengunggah seluruh foto bukti lokal ke Supabase Storage terlebih dahulu, lalu mengirim PATCH pembaruan status task ke database.
   - Jika PATCH gagal (misalnya karena network timeout atau server error 500), `_enqueueCompletion` menyimpan path lokal (`/data/user/...`) ke antrean offline SharedPreferences.
   - `flushPendingCompletions()` dipanggil secara otomatis (unawaited) pada setiap pemuatan daftar task (`getTasksForTeknisi` dan `getAllTasksToday`).
   - Setiap kali proses flush berjalan, fungsi `completeTask` dipanggil kembali dari awal dan mengunggah ulang seluruh foto lokal ke storage dengan nama file baru berakhiran timestamp milidetik (`proof_${taskId}_${index + 1}_${millis}.jpg`).
2. **Konkurensi Tanpa Single-Flight Guard**:
   - Jika teknisi merefresh layar beberapa kali dalam waktu singkat, beberapa pemanggilan `flushPendingCompletions()` berjalan paralel bersamaan, memicu duplikasi upload hingga 4 kali untuk foto yang sama dalam rentang 2 menit.
3. **Mitigasi yang Telah Diterapkan**:
   - **Persistensi URL Remote**: Saat upload berhasil namun PATCH gagal, URL remote disimpan ke dalam queue. Pada retry/flush berikutnya, file dengan URL remote tidak lagi diunggah ulang ke storage.
   - **Single-Flight Guard**: Variabel `_activeFlushFuture` memastikan eksekusi flush yang tumpang tindih menggunakan Future yang sama tanpa upload ganda.

---

### B. Query & Hasil Analisis Objek Orphan (Tidak Terhubung di DB)

**SQL Query**:
```sql
with referenced_photos as (
  select jsonb_array_elements_text(foto_bukti) as url from daily_tasks_manado where foto_bukti is not null
  union
  select jsonb_array_elements_text(foto_bukti) as url from daily_tasks_bali where foto_bukti is not null
  union
  select jsonb_array_elements_text(foto_bukti) as url from daily_tasks_ho where foto_bukti is not null
),
parsed_names as (
  select distinct
    regexp_replace(url, '^.*/([^/?#]+).*$', '\1') as filename
  from referenced_photos
  where url is not null and url != ''
),
storage_files as (
  select
    name,
    (metadata->>'size')::bigint as size_bytes,
    created_at
  from storage.objects
  where bucket_id = 'task-proofs'
)
select
  case when r.filename is not null then 'Referenced (Aktif di DB)' else 'Orphan (Tidak ada di DB)' end as kategori,
  count(*) as jumlah_file,
  pg_size_pretty(sum(s.size_bytes)) as total_size,
  sum(s.size_bytes) as total_bytes,
  round(100.0 * sum(s.size_bytes) / (select sum(size_bytes) from storage_files), 1) as persentase
from storage_files s
left join parsed_names r on s.name = r.filename
group by 1 order by total_bytes desc;
```

**Hasil Pengukuran**:
| Kategori | Jumlah File | Total Ukuran | Total Bytes | Persentase |
|---|---|---|---|---|
| **Orphan (Tidak ada di DB)** | **3,157** | **2,305 MB** (~2.25 GB) | 2,416,516,182 | **86.7%** |
| **Referenced (Aktif di DB)** | 722 | 353 MB | 370,052,643 | 13.3% |
| **Total Keseluruhan** | **3,879** | **2,657 MB** | 2,786,568,825 | **100.0%** |

> **Catatan**: Sebanyak **86.7% storage (2.3 GB)** terpakai oleh file orphan hasil retry/duplikasi upload yang tidak tercatat pada row task aktif di database.

---

### C. Query & Hasil Analisis Grup Duplikat

**SQL Query**:
```sql
with groups as (
  select
    substring(name from '^(proof_.*_[0-9]+)_[0-9]+\.jpg$') as group_prefix,
    count(*) as cnt,
    sum((metadata->>'size')::bigint) as total_bytes,
    sum((metadata->>'size')::bigint) - max((metadata->>'size')::bigint) as redundant_bytes,
    min(created_at) as earliest_upload,
    max(created_at) as latest_upload
  from storage.objects
  where bucket_id = 'task-proofs'
  group by 1
  having count(*) > 1
)
select
  count(*) as duplicate_groups,
  sum(cnt) as total_files_in_groups,
  sum(cnt) - count(*) as extra_duplicate_files,
  pg_size_pretty(sum(total_bytes)) as total_group_size,
  pg_size_pretty(sum(redundant_bytes)) as duplicate_extra_size,
  sum(redundant_bytes) as redundant_bytes
from groups;
```

**Hasil Pengukuran**:
| Metrik | Nilai | Keterangan |
|---|---|---|
| **Grup Duplikat Terdeteksi** | **477 grup** | Pasangan `(taskId, index)` yang diunggah > 1 kali |
| **Total File dalam Grup Duplikat** | **3,522 file** | Dari 3,879 total file di bucket (90.8%) |
| **File Duplikat Ekstra (Sampah Redundan)** | **3,045 file** | File salinan berlebih di luar 1 file utama |
| **Ukuran Duplikat Ekstra (Waste Storage)** | **2,218 MB** (~2.22 GB) | 2,326,217,906 bytes yang terbuang sia-sia |

---

### D. Potensi Pembersihan di Masa Depan (Bila Diizinkan Mandor)
- Membersihkan 3,045 file duplikat ekstra akan **langsung membebaskan ~2.22 GB storage**.
- Hal ini akan menurunkan total storage bucket `task-proofs` dari **2.66 GB** menjadi **~439 MB**, seketika menempatkan proyek kembali aman di bawah batas Free plan 1 GB tanpa menghapus satu pun foto tugas yang valid.
