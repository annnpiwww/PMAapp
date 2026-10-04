# Specification: Daily Task Reporting & Realtime Notification Architecture

**Author:** MiniMax Code (Mavis) & Product Owner  
**Date:** 2026-10-04  
**Project:** PMA App (`BssparkingTimeMark`)  
**Status:** Approved / Ready for Implementation  

---

## 1. Problem Statement & Motivation
Pada implementasi sebelumnya:
1. Setiap kali teknisi menyelesaikan 1 tugas harian (*task*), aplikasi langsung memunculkan dialog laporan harian final lengkap. Hal ini menyebabkan pengiriman format panjang yang berulang-ulang di grup WhatsApp (*spam chat*), membingungkan SPV dan rekan kerja.
2. Tidak ada validasi tegas (*hard-gate*) bahwa teknisi benar-benar telah mengambil dokumentasi foto ber-watermark dan mengisi catatan penyelesaian tugas sebelum menandai tugas selesai.
3. Teknisi di lapangan sering tidak menyadari ketika ada tugas baru yang ditugaskan di tengah shift kerja karena belum ada indikator angka tugas aktif di Sidebar maupun notifikasi realtime di sistem Android.

---

## 2. Functional Requirements & Design Decisions

### A. Level 1: Pelaporan Per-Task (Micro Report - Dokumentasi & Bukti Kerja)
1. **Hard Gate Validation**:
   - Teknisi **wajib** mengambil minimal 1 foto dokumentasi ber-watermark.
   - Teknisi **wajib** mengisi teks catatan laporan (`catatan_teknisi`, contoh: *"Selamat siang izin update backup server"*).
   - Jika salah satu kosong: Tombol **"Selesaikan Tugas"** terkunci (*disabled*) atau menampilkan pesan kesalahan validasi yang jelas.
2. **Action Penyelesaian**:
   - Status tugas di PocketBase & local cache berubah menjadi `completed` dengan timestamp jam selesai WITA.
   - Muncul modal konfirmasi singkat dengan tombol utama:
     **"Kirim Laporan"** (Langsung membuka WhatsApp dengan foto dokumentasi + teks caption):
     ```text
     Dokumentasi: [Judul Task]
     Notes: [Catatan teknisi]
     ```
   - Disertai opsi **"Tutup / Nanti Saja"** untuk teknisi di basement minim sinyal agar tidak terhambat.

### B. Level 2: Pelaporan Final Daily (Macro Report - Rekapitulasi Teks)
1. **Trigger & Aksesibilitas**:
   - Di bagian bawah layar `TeknisiDailyTasksScreen`, terdapat sticky bottom bar: **"Kirim Laporan Daily Hari Ini"**.
   - **Smart Threshold (Opsi B)**:
     - Jika seluruh task sudah berstatus `completed` (centang hijau), tombol menyala hijau (*primary highlight*).
     - Jika shift telah berakhir namun masih ada task berstatus `pending`, tombol tetap dapat ditekan dengan menyertakan daftar tugas yang belum selesai.
2. **Format Teks Laporan Final (Hanya Teks ke WhatsApp)**:
   ```text
   Laporan Daily Hari ini
   Teknisi : [Nama Teknisi]
   Tanggal : [DD MMMM YYYY]
   Lokasi : [POS Tag]

   Daftar list pekerjaan :
   1. [Judul Task 1] (Selesai [HH:mm] WITA)
      [Catatan teknisi task 1]
   2. [Judul Task 2] (Selesai [HH:mm] WITA)
      [Catatan teknisi task 2]

   [Jika ada yang belum selesai]:
   Pekerjaan Belum Selesai :
   - [Judul Task 3] (Pending)

   Status : [X] Selesai, [Y] Pending
   -----
   Notes:
   -
   ```
3. **Action Pengiriman**:
   - Tombol **"Kirim Laporan"** langsung membuka WhatsApp (`ShareHelper.shareToWhatsApp`) dengan teks di atas disalin otomatis ke clipboard dan diprefill ke chat WA.

### C. Level 3: Realtime Sidebar Badge & Android Local Notification
1. **Realtime Badge di Sidebar (`CameraCaptureScreen`)**:
   - Item menu `Daily Task` di Drawer memiliki badge pill angka realtime.
   - Angka menunjukkan jumlah task berstatus `pending` hari ini milik teknisi yang sedang login.
   - Jika ada 2 tugas pending: Badge menampilkan angka **`2`** berwarna oranye/merah.
   - Berkurang otomatis menjadi **`1`**, lalu berubah menjadi centang hijau **`✓`** saat seluruh tugas selesai.
2. **Android Local Notification (`NotificationService`)**:
   - Saat aplikasi melakukan sync harian atau mendeteksi daftar tugas teknisi:
     - Memicu notifikasi lokal Android di status bar:
       - **Judul**: `📋 Daily Task Hari Ini ([N] Tugas)`
       - **Isi**: Rangkuman baris tugas (contoh: `• Backup server... \n• Pengecatan markah...`).
     - Ketika notifikasi ditekan, langsung mengarahkan user ke `TeknisiDailyTasksScreen`.

---

## 3. Architecture & Data Flow

```
[PocketBase / Local Cache]
        │
        ▼ (Sync & Fetch Tasks)
[DailyTaskService] ────► [NotificationService] ──► Android Status Bar Notification
        │
        ├────────────────► [Drawer State / Badge] ──► Sidebar Badge (Realtime Count)
        │
        ▼
[TeknisiDailyTasksScreen]
        │
        ├──► [CustomTaskExecutionScreen] (Per-Task)
        │         ├── Validasi: Foto (>0) & Notes (NotEmpty)
        │         ├── Update PB: status='completed', jam_selesai, catatan_teknisi
        │         └── "Kirim Laporan" ──► WhatsApp: Foto + "Dokumentasi: ... Notes: ..."
        │
        └──► [Daily Summary Bottom Bar] (Final Rekap)
                  └── "Kirim Laporan" ──► WhatsApp: Format Laporan Daily Teks
```

---

## 4. Verification & Acceptance Criteria
1. **Hard Gate Per-Task**: Tombol simpan tidak dapat dieksekusi jika belum ambil foto atau catatan kosong.
2. **Direct WhatsApp Launch**: Klik "Kirim Laporan" langsung memanggil `ShareHelper.shareToWhatsApp` tanpa dialog Telegram.
3. **Format Ketepatan Teks**:
   - Per-task: `Dokumentasi: ...` + `Notes: ...`
   - Final daily: Header, `Daftar list pekerjaan :` tanpa tulisan `Catatan :` di item, section `Pekerjaan Belum Selesai :` jika ada pending, dan diakhiri `Notes:`.
4. **Sidebar Badge Realtime**: Berubah reaktif sesuai sisa tugas pending teknisi aktif.
5. **Android Notification**: Muncul notifikasi Android dengan daftar task hari ini.
6. **Code Quality**: `flutter analyze` 0 issues, semua unit tests lolos.
