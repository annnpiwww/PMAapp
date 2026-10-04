# Design Specification: Technician PIN Lock & Dynamic Support Name

- Date: 2026-08-29
- Author: Antigravity / Opencode
- Target Project: BssparkingTimeMark (Flutter)

---

## 1. Objectives & Context
Aplikasi BSS Parking TimeMark melayani 2 fungsi penting:
1. **Operasional Petugas Lapangan**: Absensi grooming petugas dan briefing shift (didukung AI Vision).
2. **Maintenance Teknisi BSS**: Inspeksi pemeliharaan Barrier Gate, Manless, Pos Kasir, dan Server.

Untuk mencegah petugas operasional umum mengakses atau mengisi form teknisi secara tidak sengaja, fitur maintenance diproteksi dengan **PIN Akses Teknisi** (Default PIN: `123321`). Selain itu, untuk mendukung 100+ teknisi lapangan tanpa bentrok nama, teknisi dapat memasukkan/mengganti **Nama Support** secara langsung saat membuka dialog maintenance dan nama tersebut langsung menjadi identitas pelaporan resmi WhatsApp (tanpa NIP/NPP).

---

## 2. Architectural Components & Flow

### 2.1 PIN Verification Modal (`TechnicianPinDialog`)
- Ketika user memilih template kategori Maintenance (`maintBarrier`, `maintPos`, `maintManless`, `maintServer` / `isPerPoint`):
  - Sistem menampilkan dialog PIN: *"Akses Khusus Teknisi BSS - Masukkan PIN"*.
  - User memasukkan PIN (default: `123321`).
  - Pin tersimpan di `StorageService` (`_keyTechnicianPin`), sehingga dapat diubah melalui menu Pengaturan.
  - Jika PIN benar, dialog tertutup dan langsung membuka `MaintenanceSetupDialog`.
  - Jika PIN salah, muncul getar/shake feedback dan pesan *"PIN Teknisi Salah!"*.

### 2.2 Dynamic Support Name in `MaintenanceSetupDialog`
- Pada `MaintenanceSetupDialog` (sebelum membuka checklist), terdapat field:
  - **Nama Teknisi / Support**: Text field editable dengan default nama user aktif (atau teks terakhir yang dipakai teknisi).
  - Teknisi dapat mengetik nama siapa saja (contoh: *Ryan Lumasuge*, *Agus Paputungan*, dll.).
- Nilai nama ini akan disimpan ke dalam `MaintenanceSubmission.userName` dan otomatis dipakai sebagai identitas pelaporan WhatsApp.

### 2.3 WhatsApp Report Format (Clean Name, No NIP/NPP)
Teks format laporan WhatsApp baku:
```text
Selamat Pagi
Izin melaporkan hasil maintenance BG, Palang, IPCAM, dan Sensor Lokasi NBM
Tanggal 21 Agustus 2026
Support Ryan Lumasuge

Note:
1. [Poin 1 kondisi]
2. [Poin 2 kondisi]
...
Terima kasih 🙏
```

---

## 3. Data Model & Storage
- `StorageService`:
  - `getTechnicianPin()` -> `String` (default: `'123321'`).
  - `saveTechnicianPin(String pin)` -> `Future<void>`.
  - `getLastTechnicianName()` -> `String` (menyimpan nama teknisi terakhir yang dipakai agar tidak perlu ketik ulang setiap kali buka).
  - `saveLastTechnicianName(String name)` -> `Future<void>`.
- `MaintenanceSubmission`:
  - Menyimpan `userName` yang diinputkan dari dialog setup.

---

## 4. Verification & Testing
- Unit test verifikasi PIN check (benar vs salah).
- Unit test format WhatsApp dengan custom support name.
- Build APK debug dan install ke HP via ADB.
