# BssparkingTimeMark — Project Summary & AI Vision SOP Architecture

Dokumen ini memuat rangkuman teknis lengkap mengenai aplikasi **BssparkingTimeMark**, fitur-fiturnya, antarmuka pengguna (UI), integrasi AI Vision LLM, sistem verifikasi SOP, serta analisis teknis terkait error turn di DeepSeek Harness.

---

## 1. Analisis Error: Kenapa Turn DeepSeek Harness Gagal (400 & SSE stream ended)?

### Pesan Error
```text
13:43 turn failed [400]: Antigravity upstream error (400)
13:43 turn failed SSE stream ended without [DONE]
```

### Akar Masalah (Root Cause)
1. **Sesi Tersangkut Status Tool Interrupted**:
   - Berdasarkan analisis pada log sesi (`session-a867cf0a-af95...`), pada Step 41 terjadi gangguan proses (`ToolOutcomeUnknownError: The tool call was interrupted after being recorded`).
2. **State History Incompatible dengan Upstream Antigravity**:
   - Saat Anda mengirimkan pesan baru di dalam sesi yang sama, DeepSeek Harness mengirimkan seluruh riwayat obrolan (termasuk pesan tool interrupted dan attachment gambar Base64 dari step-step sebelumnya).
   - Antigravity / Gemini upstream memberlakukan validasi ketat terhadap alur tool-calling (setiap `tool-call` wajib memiliki balasan `tool-result` yang valid dan terstruktur). Adanya tool call yang terputus menyebabkan Antigravity menolak seluruh payload dengan **HTTP 400 Bad Request**.
3. **Koneksi Terputus Tanpa `[DONE]`**:
   - Karena upstream membatalkan koneksi secara mendadak saat parsing request, stream SSE terputus sebelum token penutup `[DONE]` terkirim, sehingga adapter memunculkan error `SSE stream ended without [DONE]`.

### Solusi:
* **Buka Chat Baru (New Session)** di DeepSeek Harness Web GUI. Sesi baru yang bersih dari riwayat tool call yang korup akan langsung berjalan lancar ke model `gemini-3.7-flash-high` atau `agent`.

---

## 2. Gambaran Umum Proyek (Project Overview)

**BssparkingTimeMark** adalah aplikasi mobile berbasis **Flutter (Dart)** yang dirancang untuk operasional lapangan tim **BSS Parking**. Aplikasi ini menggabungkan fitur **GPS TimeMark Camera** (watermark waktu & lokasi terverifikasi) dengan **AI Vision SOP Verification** (pemeriksaan otomatis kepatuhan atribut dan kesiapan pos parkir menggunakan kecerdasan buatan multimodal).

* **Tech Stack**: Flutter 3.11+ / Dart, Material Design 3.
* **Arsitektur**: Feature-Driven Architecture dengan pemisahan Core, Data Layer (Models, Repositories, Services), dan Presentation Layer (Screens, Widgets).

---

## 3. Fitur Utama (Core Features)

### A. TimeMark Camera & Watermarking
* **Live Camera Viewfinder**: Menggunakan `camera: ^0.11.0` dengan preview real-time.
* **Geotagging & Reverse Geocoding**: Mengambil koordinat GPS akurat (`geolocator`) dan menerjemahkannya ke nama jalan/area (`geocoding`).
* **Watermark Engine**:
  - Tanggal & waktu presisi (anti-fraud).
  - Koordinat GPS (Latitude/Longitude).
  - Alamat lengkap dan nama lokasi pos.
  - Nama petugas / ID pengguna.
  - Logo perusahaan & Kode verifikasi unik (`VerificationCode` hash) untuk mencegah manipulasi foto.
* **Customizer Watermark**: Kustomisasi tata letak (Header, Footer, Left/Right layout, opacity, dan font styling).

### B. AI Vision SOP Compliance Verification
* **Automated SOP Checking**: Menganalisis foto hasil jepretan kamera secara instan terhadap daftar kriteria SOP pos parkir.
* **Negative Statement Resolution (`SopCriteriaHelper`)**: Mengubah kriteria positif menjadi deteksi pelanggaran negatif jika kriteria tidak terpenuhi.
* **SOP Checklist Inspector**: Modal UI interaktif yang menampilkan status *LULUS / GAGAL* per poin kriteria, persentase kepatuhan (Confidence Score), dan ringkasan catatan perbaikan dari AI.

### C. Manajemen Template & Kartu Laporan
* **Template Dinamis**:
  - Template Briefing / Apel Pagi.
  - Template Petugas Pos Masuk / Pos Keluar.
  - Template Patroli & Kebersihan Lajur Parkir.
  - Template Kesiapan Peralatan (EDC & Barrier Gate).
* **Editor Template**: Memungkinkan admin/leader menambah, mengubah, atau menyusun kriteria SOP khusus per lokasi parkir.

### D. Penyimpanan Lokal & Berbagi Cepat (Offline-First)
* **Penyimpanan Lokal**: Riwayat laporan disimpan menggunakan `shared_preferences` dan file storage lokal (`path_provider`).
* **Simpan ke Galeri**: Foto dengan watermark resolusi penuh disimpan ke galeri perangkat (`gal`).
* **Ekspor & Share**: Bagikan foto bukti kerja langsung ke WhatsApp, Email, atau grup koordinasi (`share_plus`).

---

## 4. Antarmuka Pengguna (UI / UX)

1. **Main Shell & Navigation (`main_shell_screen.dart`)**:
   - Navigasi utama dengan tab Beranda, Kamera, Template, Riwayat, dan Pengaturan.
2. **Camera Capture Screen (`camera_capture_screen.dart`)**:
   - Tampilan viewfinder kamera bersih dengan live watermark preview.
   - Switch flash, grid line, orientasi kamera, dan tombol capture responsif.
3. **SOP Verification Modal (`sop_verification_modal.dart`)**:
   - Bottom sheet modern dengan indikator badge warna:
     - 🟢 **Hijau**: Kriteria Terpenuhi.
     - 🔴 **Merah**: Pelanggaran SOP (lengkap dengan penjelasan kesalahan).
     - 🟡 **Kuning**: Peringatan / Evaluasi Lanjutan.
4. **Template Management Screen (`card_template_management_screen.dart`)**:
   - Daftar template berbasis kartu visual interaktif.
5. **AI Vision Settings (`ai_vision_settings_screen.dart`)**:
   - Pengaturan konfigurasi custom endpoint LLM (URL, Model ID, API Key, Temperature, Max Tokens).

---

## 5. Koneksi LLM & AI Vision Pipeline

Sistem AI Vision diimplementasikan pada `lib/data/services/ai_vision_service.dart`:

```text
[Kamera Foto] ➔ [Kompresi/Base64] ➔ [Prompt + SOP Schema] ➔ [OmniRoute / Gemini / DeepSeek API] ➔ [JSON Result Parser] ➔ [SOP Modal UI]
```

* **Format Payload**: Mengirimkan gambar dalam format `image/jpeg` (Base64) bersama dengan sistem prompt instruksi evaluator SOP.
* **Structured JSON Output**:
  AI diwajibkan mengembalikan respon JSON valid dengan struktur:
  ```json
  {
    "overall_status": "pass" | "fail" | "warning",
    "score": 95,
    "summary": "Petugas mengenakan seragam lengkap dan area pos rapi.",
    "criteria_results": [
      {
        "criterion": "Seragam resmi BSS Parking rapi",
        "passed": true,
        "note": "Seragam lengkap terkancing"
      }
    ]
  }
  ```
* **BYO-LLM Support**: Kompatibel dengan OpenAI Vision API, Gemini 2.5/3.7 Vision, dan DeepSeek Multimodal.

---

## 6. Standar Operasional Prosedur (SOP) yang Didukung

1. **Grooming & Atribut Petugas**:
   - Seragam resmi BSS Parking bersih, rapi, dan terkancing.
   - ID Card / Name tag terpasang jelas di saku kiri.
   - Standar kerapian rambut / jilbab rapi.
   - Sepatu dinas hitam (Pantofel / PDL).
   - Wajah terlihat jelas (tidak tertutup masker/kacamata hitam).
2. **Kesiapan Pos & Lajur Parkir**:
   - Area booth/pos bebas dari tumpukan barang pribadi.
   - Barrier gate, sensor loop, dan rambu tarif terlihat jelas.
   - Tidak ada genangan air atau sampah di lajur kendaraan.
   - Lampu penerangan pos menyala normal.
3. **Peralatan Kerja & Kasir**:
   - Mesin EDC dan printer karcis aktif online.
   - Roll kertas karcis terpasang (cadangan min. 2 roll).
   - Laci uang kasir terkunci dan meja transaksi rapi.
   - Radio komunikasi (HT) dan senter siap pakai.
