# PMAapp — Project Context & System Architecture

Dokumen ini adalah ringkasan arsitektur sistem **PMAapp** yang dirancang sebagai basis pengetahuan (*knowledge context*) untuk **Gemini 4 Argon**.

---

## 1. Profil Proyek
* **Nama Aplikasi**: PMAapp
* **Framework**: Flutter (Dart)
* **Target Platform**: Android & iOS
* **Tipe Arsitektur**: Feature-first / Clean layered architecture (`core/`, `data/`, `features/`)
* **Brand Identity & Warna**: Putih, Biru, Orange, Cream (`lib/core/constants/app_colors.dart`)

---

## 2. Struktur Modul & Fitur (`lib/features/`)
1. **`auth/`**: Autentikasi pengguna, manajemen sesi, dan hak akses petugas/operator.
2. **`camera/`**: Modul kamera utama untuk pengambilan foto bukti, penandaan waktu (*Time Marking* / watermark metadata lokasi, koordinat, dan timestamp).
3. **`daily_tasks/`**: Manajemen tugas harian, checklist operasional shift, dan pelaporan tugas lapangan.
4. **`history/`**: Riwayat pencatatan waktu, log aktivitas kendaraan/tugas, dan filter pencarian data.
5. **`locations/`**: Pemetaan lokasi parkir/operasional, tagging area, dan geolokasi.
6. **`maintenance/`**: Pelaporan kendala sarana, fasilitas, dan tiket maintenance.
7. **`settings/`**: Konfigurasi aplikasi, preferensi printer bluetooth/hardware, profil, dan aturan sistem.
8. **`templates/`**: Format template watermark, format laporan, dan skema export/share.
9. **`splash/`**: Alur inisialisasi aplikasi, pemeriksaan sesi, dan bootstrap data.

---

## 3. Direktori Inti Lainnya
* **`lib/core/`**: Berisi constants (`app_colors.dart`), utilities (`share_helper.dart`), service helper, theme, dan helper format.
* **`lib/data/`**: Repositori lokal, SQLite/shared preferences, caching, dan model payload.

---

## 4. Standar Kualitas & Aturan Coding
* **Zero-Breaking Policy**: Selalu pertahankan backward compatibility; ubah sesedikit mungkin file untuk menyelesaikan masalah.
* **Null Safety & Strict Typing**: Hindari penggunaan tipe `dynamic` yang tidak terkontrol.
* **UI/UX Konsisten**: Mengikuti palet warna signature PMAapp (Putih, Biru, Orange, Cream), responsif, dan anti-overflow.
* **Verifikasi**: Setiap solusi harus menyertakan langkah verifikasi (`flutter test`, `flutter analyze`).

---

## 5. Instruksi Khusus untuk Gemini 4 Argon
Setiap kali diminta merancang fitur atau memperbaiki bug di **PMAapp**:
1. Gunakan penalaran mendalam (*deep reasoning*) untuk menemukan akar masalah (*root cause*).
2. Tentukan target file secara presisi (path lengkap dari `lib/...`).
3. Berikan output yang siap dieksekusi oleh executor lokal (Antigravity 3.8) tanpa placeholder atau kode menggantung.
