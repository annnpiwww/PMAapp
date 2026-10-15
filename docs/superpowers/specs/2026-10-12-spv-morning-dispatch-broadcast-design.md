# SPV Morning Dispatch Broadcast (WA & Telegram Format) - Design Document

**Status:** Approved by User (SPV Farhan)  
**Date:** 2026-10-12  
**Target Module:** `lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart`, `lib/data/services/daily_task_service.dart`, `lib/data/services/storage_service.dart`

---

## 1. Problem Statement & User Goal
Setiap pagi, SPV Farhan mengalokasikan daily task ke teknisi-teknisi di KC Manado (dan KC Bali). Selain diinput ke sistem aplikasi BssparkingTimeMark, Mas Farhan harus mengirimkan pesan broadcast briefing pagi ke grup WhatsApp / Telegram tim.

Format pesan yang biasa digunakan:
```text
Selamat pagi
List pekerjaan hari ini 

Shift 1 (03:00 - 11:00) : Raldy Sangkop
1. Ganti pcless Gatein ojek dengan pcless stok kc

Shift 2 (10:00 - 14:00) : Ryan Lumasuge
1. Maintenance mingguan : Pembersihan pos parkir -- PPM

Shift 3 (14:00 - 22:00) : Junifer Manua
1. Pemasangan box pannel lokasi MPP
2. Maintenance mingguan : Pembersihan pos MPP
3. Backup server, hapus foto, upload cloud & HDD MPP

Tetap semangat team🔥
```

Saat ini, Mas Farhan harus menulis ulang secara manual di WhatsApp. Dibutuhkan tombol cepat di aplikasi yang menyinkronkan tugas-tugas yang telah di-assign hari itu, mengelompokkannya per shift teknisi, dan menyediakan tombol salin format (copy to clipboard) serta tombol kirim langsung ke WhatsApp/Telegram.

---

## 2. Architecture & Design Principles (Pragmatic / Ponytail)
1. **Zero Database / Schema Migration**:
   - `DailyTaskModel` dan koleksi PocketBase `daily_tasks` tidak diubah sama sekali.
   - Penugasan shift dikelola per teknisi (bukan per task), karena 1 teknisi bertugas pada 1 jadwal shift per hari.
2. **Smart Local Memory**:
   - Pilihan shift tiap teknisi disimpan di cache lokal (`StorageService`) sehingga besok pagi pilihan shift terakhir otomatis terisi (default).
3. **Dual Action Buttons**:
   - **Salin Format (Copy to Clipboard)**: Menggunakan `Clipboard.setData()` disertai feedback SnackBar hijau.
   - **Kirim ke WA/Telegram (Share)**: Menggunakan `SharePlus.instance.share()`.

---

## 3. Data Flow & Components

### 3.1 Formatter Logic (`DailyTaskService`)
Menambahkan fungsi statis:
```dart
static String formatMorningDispatchReport({
  required List<DailyTaskModel> tasks,
  required Map<String, String> techShiftMap, // e.g. {'Raldy Sangkop': 'Shift 1 (03:00 - 11:00)'}
  AppBranch? branch,
});
```

**Aturan formatting**:
- Header:
  ```text
  Selamat pagi
  List pekerjaan hari ini 
  ```
- Shift diurutkan berdasarkan urutan shift resmi cabang (`BranchService.instance.getShifts()`):
  - Manado: Shift 1, Shift 2.2, Shift 2, Shift 3.
  - Bali: Shift 1, Shift 2, Shift 3, Shift 4, dll.
- Teknisi yang tidak memiliki task pada tanggal tersebut tidak dimunculkan.
- Tugas di bawah teknisi dinomori `1. `, `2. `, dst. Format judul: `${task.judul}`.
- Penutup:
  ```text
  Tetap semangat team🔥
  ```

### 3.2 Penyimpanan Shift Teknisi (`StorageService`)
- Key: `'spv_tech_shift_preferences'`
- API:
  - `static Map<String, String> getSpvTechShifts()`
  - `static Future<void> saveSpvTechShift(String techName, String shift)`

### 3.3 UI Integration (`SpvTaskDispatcherScreen`)
- **AppBar Action Button**:
  Menambahkan icon button di kanan atas AppBar:
  - Icon: `Icons.copy_all_rounded` / `Icons.share_rounded`
  - Tooltip: `'Format Briefing WA'`
  - Badge kecil penanda jumlah task hari ini jika ada.
- **Morning Dispatch Modal BottomSheet (`_showMorningDispatchBottomSheet`)**:
  - **Header**: Judul "Format Briefing Tim" & tombol tutup.
  - **Daftar Teknisi & Shift Selector**:
    Card ringkas berisi teknisi yang punya tugas hari ini dengan dropdown pilihan shift mereka. Perubahan dropdown langsung meng-update live preview dan tersimpan ke cache.
  - **Live Text Preview Box**:
    Container dengan latar kontras lembut dan teks monospaced/rapi menampilkan hasil generate secara real-time.
  - **Action Buttons Row**:
    - Tombol "Salin Format" (Outlined / Primary dengan Icon Copy).
    - Tombol "Kirim WA / Share" (Hijau WhatsApp `#25D366` dengan Icon Share).

---

## 4. Verification & Testing Strategy
1. **Unit Tests (`test/daily_task_morning_dispatch_test.dart`)**:
   - Test formatting dengan 1 teknisi 1 tugas.
   - Test formatting dengan beberapa teknisi di shift berbeda (Shift 1, Shift 2, Shift 3) dan multiple tasks per teknisi.
   - Test urutan shift (Shift 1 harus muncul sebelum Shift 2, dst).
   - Test fallback jika shift belum diset.
2. **Analyzer**:
   - `flutter analyze` 0 issues.
3. **Manual Flow Check**:
   - Buka screen SPV Task Dispatcher.
   - Klik icon AppBar.
   - Verifikasi dropdown teknisi aktif, ganti shift, teks preview berubah instan, klik Salin Format.
