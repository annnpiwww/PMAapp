# Design Spec: Multi-Cabang Universal (Manado & Bali) — BSS Parking TimeMark (PMA App)

- **Tanggal**: 2026-10-09
- **Status**: Approved (Brainstorming Selesai)
- **Target Versi**: v2.0.75+83
- **Tujuan**: Mengimplementasikan arsitektur Multi-Cabang dalam 1 APK Universal untuk mendukung operasional KC Manado dan KC Bali secara dinamis, terisolasi, dan mandiri tanpa rebuild APK berkala.

---

## 1. Konteks & Latar Belakang

Aplikasi PMA App yang awalnya beroperasi di KC Manado (KC BSG) kini diperluas untuk mencakup KC Bali (dan persiapan KC Makassar). Masing-masing cabang memiliki karakteristik operasional yang berbeda:
1. **Identitas Cabang**: Nama cabang dan pimpinan SPV berbeda.
2. **Daftar Teknisi**: Tim teknisi terpisah per wilayah geografis.
3. **Jadwal Shift**: Waktu kerja shift berbeda (Manado mulai 03:00, Bali mulai 06:00).
4. **Lokasi Pos**: Daftar pos pengelolaan terpisah (15 pos di Bali, beberapa pos di Manado).
5. **Format Rekap Tim**: Format WhatsApp rekapitulasi SPV memuat nama cabang dan SPV yang sesuai.

Diputuskan menggunakan **Opsi B (1 APK Universal)**, di mana seluruh cabang menggunakan satu file APK yang sama dan sistem menyesuaikan diri secara otomatis berdasarkan cabang aktif pengguna.

---

## 2. Arsitektur & Model Data

### A. `BranchService` & `BranchConfig`
Membuat class abstraksi konfigurasi cabang di `lib/data/services/branch_service.dart`:
```dart
enum AppBranch {
  manado(
    code: 'MDO',
    name: 'KC Manado',
    recapHeader: 'REKAP DAILY TEAM PMA KC BSG',
    defaultSpv: 'Farhan Lakoro',
    defaultLocationTag: 'PBM',
  ),
  bali(
    code: 'DPS',
    name: 'KC Bali',
    recapHeader: 'REKAP DAILY TEAM PMA KC BALI',
    defaultSpv: 'Indra Yohana',
    defaultLocationTag: 'PBKD',
  );

  final String code;
  final String name;
  final String recapHeader;
  final String defaultSpv;
  final String defaultLocationTag;

  const AppBranch({
    required this.code,
    required this.name,
    required this.recapHeader,
    required this.defaultSpv,
    required this.defaultLocationTag,
  });
}
```

### B. Pemetaan Data Cabang

#### 1. KC Manado
- **SPV**: Farhan Lakoro (`farhan lakoro` / `flakoro05`, `farhan@bssparking.id`)
- **Teknisi**:
  1. Ryan Lumasuge (`ryan lumasuge` / `teknisi123`)
  2. Raldy Sangkop (`raldy sangkop` / `teknisi123`)
  3. Junifer Manua (`junifer manua` / `teknisi123`)
  4. Alessandro Sulistyo (`alessandro sulistyo` / `teknisi123`)
- **Shift (4 Jadwal)**:
  1. `Shift 1 (03:00 - 11:00)`
  2. `Shift 2.2 (10:00 - 14:00)`
  3. `Shift 2 (10:00 - 18:00)`
  4. `Shift 3 (14:00 - 22:00)`
- **Lokasi Utama**: `PBM`, `PKM`, `MEGAMAS`, `TBM`, `MTC`
- **Kop Rekap WhatsApp**: `REKAP DAILY TEAM PMA KC BSG` (SPV: FARHAN LAKORO)

#### 2. KC Bali
- **SPV**: I Putu Indra Yohana (`indra@pma.com` / `spvbali`)
- **Teknisi (5 Akun, Default Password: `teknisi123`)**:
  1. Putu Hyan Parta Wijaya (`parta@pma.com`)
  2. Alif Candra Triantoro (`toro@pma.com`)
  3. I Putu Gede Suardana Putra (`suardana@pma.com`)
  4. Aditya Caesar Bagaskara (`dika@pma.com`)
  5. Anak Agung Gede Agung Yustikawangsa (`cokagung@pma.com`)
- **Shift (6 Jadwal)**:
  1. `Shift 1 (06.00 - 14.00)`
  2. `Shift 2 (14.00 - 22.00)`
  3. `Shift 3 (22.00 - 06.00)`
  4. `Shift 4 (08.30 - 16.30)`
  5. `Shift 2.2 (18.00 - 22.00)`
  6. `Shift 4.1 (08.00 - 12.00)`
- **15 Lokasi Pengelolaan**:
  `PBKD`, `PCD`, `PKRD`, `PAS`, `PSD`, `PGA`, `TBB`, `TBG`, `KIH`, `BMS`, `BMK`, `SPD`, `GYS`, `PBB`, `RSPM`
- **Kop Rekap WhatsApp**: `REKAP DAILY TEAM PMA KC BALI` (SPV: Indra Yohana)

---

## 3. UI/UX Flow & Integrasi Modul

### A. Halaman Login (`login_screen.dart`)
1. Menambahkan pill switch cabang di bagian atas card login:
   - `[ 📍 KC Manado ]`  `[ 📍 KC Bali ]`
2. Menyimpan cabang aktif ke `StorageService.setActiveBranch(branch)`.
3. Auto-Detection saat login:
   - Jika akun berakhiran `@pma.com` atau login dengan akun Indra / Parta / Toro / Suardana / Dika / Cok Agung, sistem otomatis menetapkan cabang ke `KC Bali`.
   - Jika akun Farhan / Ryan / Raldy / Junifer / Alessandro, sistem menetapkan cabang ke `KC Manado`.

### B. Form Absensi & Auto-Detect Shift (`absensi_kategori_dialog.dart` & `absensi_setup_service.dart`)
1. Daftar nama teknisi yang ditampilkan otomatis terisolasi sesuai cabang aktif.
2. Daftar jadwal shift otomatis menyesuaikan cabang aktif.
3. Fungsi `autoDetectShift()` mengadopsi jam cabang aktif:
   - KC Bali: mendeteksi waktu antara 06:00, 14:00, 22:00, 08:30, dll.
   - KC Manado: tetap mendeteksi waktu shift 03:00, 10:00, 14:00.

### C. Menu Daily Tasks & SPV Dispatcher (`spv_task_dispatcher_screen.dart`)
1. Dropdown pilihan teknisi saat SPV membuat tugas memuat teknisi cabang aktif.
2. Kolom lokasi default menyesuaikan pos cabang aktif (`PBKD` untuk Bali, `TBM` untuk Manado).
3. Autocomplete pos lokasi memuat 15 pos Bali atau pos Manado.

### D. Rekapitulasi Tim WhatsApp (`daily_task_service.dart`)
Memperbarui fungsi `formatSpvTeamRecap`:
```dart
static String formatSpvTeamRecap({
  required String tanggal,
  required List<DailyTaskModel> tasks,
  String? spvName,
  String? cabangName,
})
```
- Menghasilkan header dinamis:
  - Jika KC Bali: `REKAP DAILY TEAM PMA KC BALI\nSPV : ${spvName ?? 'Indra Yohana'}`
  - Jika KC Manado: `REKAP DAILY TEAM PMA KC BSG\nSPV : ${spvName ?? 'FARHAN LAKORO'}`

### E. Watermark Foto Timemark
- Tetap menampilkan label standar **"Absensi"** (tidak diubah menjadi nama cabang sesuai permintaan user).
- Pos lokasi pada watermark foto mengacu pada lokasi yang dipilih teknisi (`PBKD`, `PCD`, dll).

---

## 4. Keamanan & Offline Fallback

1. **PocketBase Server**:
   - Akun SPV dan teknisi Bali didaftarkan ke PocketBase server di `https://bssparking.trakingduit.my.id`.
2. **Offline Fallback (`auth_repository.dart`)**:
   - Menambahkan akun Bali ke `hardcodedAccounts` di `AuthRepository` lengkap dengan cabang `KC Bali`, sehingga teknisi di basement tanpa sinyal tetap dapat login dengan lancar.

---

## 5. Rencana Verifikasi & Testing

1. **Unit & Widget Tests**:
   - Test branch config & model (`AppBranch.bali` vs `AppBranch.manado`).
   - Test `formatSpvTeamRecap` menghasilkan format `REKAP DAILY TEAM PMA KC BALI SPV Indra Yohana`.
   - Test isolasi teknisi & shift per cabang.
   - Test login offline fallback akun Bali (`indra@pma.com`, `toro@pma.com`, dll).
2. **Statistik Kualitas**:
   - Seluruh test eksisting (222 tests) tetap 100% lulus (zero regression).
   - `flutter analyze`: 0 issues found.
3. **Build & Release**:
   - Kompilasi APK v2.0.75+83 dan pengiriman ke bot Telegram user.
