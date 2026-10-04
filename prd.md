# PRD — BSS Parking Timemark

**Versi:** 1.0 · **Status:** Draft · **Tech stack:** Flutter (mobile, Android/iOS)

---

## 1. Ringkasan

BSS Parking Timemark adalah aplikasi kamera internal untuk petugas lapangan BSS Parking (admin, leader, SPL). Aplikasi memaksa setiap foto operasional — absensi, briefing, kondisi lokasi — memakai timestamp & lokasi real-time yang tidak bisa direkayasa, lalu memverifikasi otomatis apakah foto sesuai standar grooming/SOP perusahaan sebelum diterima sebagai laporan resmi.

## 2. Latar Belakang & Masalah

- Laporan foto absensi/briefing selama ini rawan dimanipulasi: jam & lokasi bisa diedit, seragam tidak sesuai SOP tidak terpantau sampai direview manual.
- Review manual oleh supervisor lambat dan tidak konsisten antar cabang.
- Perlu standar visual yang seragam (lihat poster "Standarisasi Briefing" BSS Parking) yang bisa dicek otomatis saat foto diambil, bukan setelah laporan masuk.

## 3. Tujuan Produk

1. Setiap foto laporan punya timemark (jam, tanggal, lokasi GPS) yang **real-time dan tidak dapat diubah manual**.
2. Foto yang tidak sesuai SOP grooming/atribut **ditolak otomatis di lapangan** (petugas foto ulang saat itu juga), bukan ditemukan belakangan oleh supervisor.
3. Setiap foto punya **kode verifikasi unik** yang bisa ditelusuri.
4. Supervisor/HO punya **riwayat terpusat** semua submission per petugas/pos/cabang.
5. Kriteria SOP & foto contoh **bisa diubah dari aplikasi** (template) tanpa perlu update aplikasi.

## 4. Target Pengguna & Role

| Role | Kebutuhan |
|---|---|
| **Petugas lapangan** (admin, leader, SPL) | Ambil foto absensi/briefing/lokasi secepat mungkin, tahu langsung kalau fotonya ditolak dan kenapa. |
| **Supervisor/Koordinator area** | Lihat riwayat submission timnya, kelola template & kriteria SOP untuk area tanggung jawabnya. |
| **HO/Admin pusat** | Kelola seluruh template, lihat semua riwayat lintas cabang, audit kepatuhan. |

MVP: role Petugas & Supervisor. Role HO dengan multi-cabang bisa masuk fase v2.

## 5. Ruang Lingkup

**In scope (MVP):**
- Kamera timemark (foto + watermark waktu/lokasi terbakar ke gambar)
- Manajemen template (nama, jenis, daftar kriteria SOP teks, foto contoh, wajib-lokasi)
- Verifikasi SOP otomatis via AI vision, dengan modal penolakan + alasan
- Kode verifikasi unik per foto
- Riwayat/log submission dengan filter status
- Autentikasi user (login petugas, terikat ke nama/ID & pos/cabang)

**Out of scope (MVP, kandidat v2+):**
- Dashboard web untuk HO
- Export laporan otomatis (Excel/PDF harian)
- Geofencing (validasi radius terhadap titik pos yang terdaftar)
- Deteksi mock-location/jailbreak-root
- Multi-bahasa

## 6. User Flow (petugas)

1. Login → pilih pos/cabang (tersimpan di sesi).
2. Buka tab **Kamera** → pilih template (mis. Absensi Masuk).
3. Lihat daftar kriteria SOP template tsb → tekan **Ambil Foto**.
4. Kamera native terbuka → petugas foto.
5. Aplikasi otomatis: ambil timestamp device, ambil GPS, bakar watermark ke foto, generate kode verifikasi.
6. Foto dikirim ke layanan verifikasi AI → status *checking* (indikator scan).
7. **Jika tidak sesuai SOP:** modal alert muncul dengan alasan spesifik + poin yang gagal → tombol **Foto Ulang** (kembali ke langkah 4) atau **Batal**.
8. **Jika sesuai:** petugas bisa **Simpan** (submit) atau **Foto Ulang** kalau kurang puas.
9. Foto tersimpan ke riwayat, muncul di tab **Riwayat** dengan status & kode verifikasi.

## 7. Functional Requirements

### 7.1 Kamera Timemark
- FR-1: Aplikasi wajib memakai kamera native device (bukan galeri) untuk mencegah upload foto lama.
- FR-2: Timestamp diambil dari jam sistem device pada saat capture diproses, ditampilkan format `DD Mon YYYY • HH:mm:ss WIB`, **tidak ada input manual untuk mengubahnya** di UI manapun.
- FR-3: Lokasi diambil via GPS device (`lat`, `lng`, akurasi meter) pada saat capture. Jika gagal (GPS off/izin ditolak) dan template `wajibLokasi = true`, foto ditandai `perlu_cek_manual` dan tetap bisa disimpan tapi flagged untuk supervisor.
- FR-4: Watermark (nama perusahaan, waktu, koordinat, kode verifikasi, nama template) di-*burn* langsung ke file gambar (bukan overlay UI yang bisa dihilangkan saat screenshot/crop).

### 7.2 Template & Kriteria SOP
- FR-5: CRUD template: nama, jenis (Absensi/Briefing/Lokasi/Custom), wajib-lokasi (boolean), daftar kriteria SOP (list teks, bisa ditambah/hapus/edit bebas).
- FR-6: Tiap template bisa punya sampai 4 **foto contoh SOP** (upload dari galeri/kamera) sebagai acuan visual untuk pemeriksaan AI dan sebagai referensi visual yang ditampilkan ke petugas sebelum memotret.
- FR-7: Hanya role Supervisor/HO yang bisa membuat/mengubah template (RBAC).

### 7.3 Verifikasi SOP (AI Vision)
- FR-8: Setelah watermark dibakar, foto (base64/compressed) + kriteria SOP template + foto contoh dikirim ke layanan verifikasi AI.
- FR-9: Respons wajib berupa status `sesuai` / `tidak_sesuai` / `tidak_dapat_diverifikasi`, alasan singkat, dan daftar poin kriteria yang gagal.
- FR-10: Jika `tidak_sesuai` → modal blocking muncul, petugas **tidak bisa submit** foto tersebut; hanya bisa foto ulang atau batal.
- FR-11: Jika `tidak_dapat_diverifikasi` (mis. layanan AI timeout/error) → foto tetap bisa disimpan tapi berstatus **Perlu Cek Manual**, supervisor mendapat notifikasi.

### 7.4 Kode Verifikasi
- FR-12: Setiap foto mendapat kode unik format `BSS-XXXXXXXX`, dihasilkan dari kombinasi timestamp + koordinat + random, di-generate di device saat capture (bukan setelah upload), dan dicetak di watermark maupun metadata log.

### 7.5 Riwayat/Log
- FR-13: List semua submission milik petugas yang login (atau seluruh tim untuk Supervisor), filter by status (Sesuai/Gagal/Perlu Cek Manual) dan by template.
- FR-14: Detail submission menampilkan foto full, waktu, lokasi, kode, alasan hasil verifikasi.
- FR-15: Data riwayat tersimpan di backend (bukan hanya lokal device) agar tidak hilang saat ganti HP / uninstall.

### 7.6 Autentikasi & Role
- FR-16: Login (email/username + password, atau SSO internal bila tersedia).
- FR-17: RBAC dua level minimum: Petugas, Supervisor.

## 8. Data Model (ringkas)

**Template**
```
id, nama, jenis (absensi|briefing|lokasi|custom),
wajibLokasi (bool), sopCriteria: [string],
contohFotoUrls: [string], createdBy, updatedAt
```

**Submission (log foto)**
```
id, templateId, userId, posId/cabangId,
imageUrl (watermarked), timestampCapture, timezone,
lokasi { lat, lng, akurasiMeter } | null,
kodeVerifikasi, status (sesuai|tidak_sesuai|perlu_cek_manual),
alasanAI, poinGagal: [string], createdAt
```

**User**
```
id, nama, role (petugas|supervisor|ho), posId/cabangId, status
```

## 9. Non-Functional Requirements

- **NFR-1 Performa:** waktu dari tekan "Ambil Foto" sampai hasil verifikasi tampil ≤ 5 detik pada koneksi 4G normal.
- **NFR-2 Offline resiliency:** jika tidak ada koneksi saat capture, foto (dengan watermark & kode yang sudah digenerate di device) disimpan ke antrian lokal dan otomatis diverifikasi + diupload saat koneksi kembali tersedia.
- **NFR-3 Keamanan data:** foto & lokasi petugas adalah data sensitif — transit terenkripsi (HTTPS/TLS), storage backend terenkripsi at-rest.
- **NFR-4 Reliabilitas jam & lokasi:** ambil waktu dari device tapi validasi kasar terhadap waktu server (NTP/response header) untuk mendeteksi device yang jamnya sudah diubah manual secara ekstrem.
- **NFR-5 Ukuran file:** foto watermark dikompresi ke ~200–400 KB agar upload cepat di lokasi dengan sinyal lemah.

## 10. Arsitektur Teknis & Tech Stack (Flutter)

### 10.1 Gambaran arsitektur
```
[Flutter App] --(HTTPS)--> [Backend API (BFF)] --> [DB + Object Storage]
                                     |
                                     +--> [Layanan AI Vision (Claude API)]
                                     +--> [Auth service]
```
Poin penting: **panggilan ke Claude Vision API TIDAK dilakukan langsung dari aplikasi Flutter.** API key harus disimpan di backend, bukan di client, agar tidak bisa diekstrak dari APK/IPA. Backend menerima gambar dari app, meneruskan ke Claude API, lalu mengembalikan hasil `sesuai/tidak_sesuai` ke app.

### 10.2 Package Flutter yang direkomendasikan

| Kebutuhan | Package |
|---|---|
| Kamera native | `camera` (custom UI) atau `image_picker` dengan `ImageSource.camera` (lebih simpel & stabil) |
| Lokasi GPS | `geolocator` + `permission_handler` |
| Watermark ke gambar | `image` (package pure-Dart untuk menggambar teks/overlay ke canvas bitmap) |
| Kompresi gambar | `flutter_image_compress` |
| HTTP ke backend | `dio` (interceptor, retry, upload progress) |
| Penyimpanan lokal (antrian offline, cache) | `hive` atau `sqflite` |
| State management | `riverpod` atau `bloc` |
| Format tanggal & timezone WIB | `intl` + `timezone` |
| Hash/kode verifikasi | `crypto` (hash dari timestamp+lat+lng+random) |
| Notifikasi lokal (hasil verifikasi selesai di background) | `flutter_local_notifications` |
| Environment config (base URL, dsb) | `flutter_dotenv` atau `--dart-define` |

### 10.3 Struktur modul aplikasi (disarankan)
```
lib/
  core/           # tema, konstanta, util (format waktu, hash kode)
  data/
    models/       # Template, Submission, User
    repositories/ # TemplateRepository, SubmissionRepository, AuthRepository
    services/     # ApiClient (dio), LocationService, WatermarkService
  features/
    auth/
    kamera/       # flow ambil foto -> watermark -> kirim verifikasi -> hasil
    template/     # list, editor, upload foto contoh
    riwayat/
  widgets/        # komponen UI reusable (badge status, modal SOP gagal, dst)
```

### 10.4 Backend (di luar scope Flutter tapi wajib disiapkan bersamaan)
- Endpoint minimum: `POST /auth/login`, `GET /templates`, `POST /templates`, `POST /submissions` (upload foto + metadata → trigger verifikasi AI → simpan hasil), `GET /submissions?filter=...`.
- Bisa dibangun cepat dengan Firebase (Auth + Firestore + Storage + Cloud Functions untuk proxy ke Claude API) atau backend custom (Node/Go) + Postgres + S3-compatible storage — pilih sesuai kapasitas tim BSS Parking.

## 11. Watermark & Kode Verifikasi — Spesifikasi Teknis

1. Setelah foto diambil, decode ke bitmap di memory.
2. Ambil `DateTime.now()` device + hasil `Geolocator.getCurrentPosition()`.
3. Generate kode: `BSS-` + hash(timestamp + lat + lng + random) (8 karakter, uppercase).
4. Gambar strip semi-transparan di bagian bawah foto berisi: logo/nama perusahaan, waktu format WIB, koordinat + akurasi (atau "Lokasi tidak terdeteksi"), kode verifikasi, nama template.
5. Encode ulang jadi JPEG kualitas ~75%, compress lagi bila > 400 KB.
6. Field waktu & lokasi ini **tidak pernah ditampilkan sebagai input yang bisa diedit** di UI manapun — nilainya read-only, langsung dari sensor device.

## 12. Keamanan & Mitigasi Kecurangan

| Risiko | Mitigasi MVP | Mitigasi v2 |
|---|---|---|
| Ubah jam device manual | Watermark dari jam device + cek kasar terhadap waktu server saat upload; foto dengan selisih besar ditandai mencurigakan | Validasi waktu penuh via server-timestamp sebagai sumber kebenaran |
| Fake GPS / mock location | — | Deteksi `isMockLocation` (Android) & tolak/tandai submission |
| Upload foto lama dari galeri | Kamera native only, tidak ada tombol pilih dari galeri di flow submission | Cek metadata EXIF & watermark AI untuk deteksi foto re-capture (foto dari foto) |
| Foto orang lain dipakai petugas lain | — | Face-match ke foto profil petugas (butuh consent & kebijakan privasi tambahan) |

## 13. Integrasi AI Vision (Verifikasi SOP)

- Input ke layanan AI: foto yang sudah di-watermark + daftar kriteria SOP (teks) template + foto contoh SOP (jika ada) sebagai referensi visual.
- Output wajib terstruktur (JSON): `{ sesuai: bool, alasan: string, poin_gagal: string[] }`.
- Backend yang menyimpan API key & melakukan rate-limiting/retry, bukan aplikasi Flutter.
- Perlu monitoring akurasi: sediakan tombol "Laporkan hasil keliru" di app agar supervisor bisa override manual dan hasil override dipakai untuk evaluasi kualitas prompt/kriteria dari waktu ke waktu.

## 14. Roadmap

**MVP (fase 1)**
- Login, 3 template default (Absensi, Briefing, Lokasi), kamera + watermark + kode verifikasi, verifikasi AI, riwayat per petugas, modal penolakan.

**Fase 2**
- Role Supervisor (kelola template, lihat riwayat tim), antrian offline, notifikasi hasil.

**Fase 3**
- Dashboard web HO, export laporan, geofencing pos, deteksi mock-location.

## 15. Metrik Keberhasilan

- % foto yang ditolak otomatis di lapangan (naik = SOP makin tersaring sebelum sampai supervisor).
- Rata-rata waktu review manual supervisor per hari (target turun signifikan setelah rollout).
- % submission berstatus "perlu cek manual" (target rendah — indikator reliabilitas GPS/AI).
- Tingkat komplain "hasil AI salah" yang di-override supervisor (dipantau untuk perbaikan kriteria SOP/prompt).

## 16. Asumsi & Pertanyaan Terbuka

- Asumsi: setiap petugas punya smartphone dengan GPS & kamera aktif dan kuota data untuk upload foto per shift.
- Perlu diputuskan: backend dibangun sendiri atau pakai Firebase untuk mempercepat MVP?
- Perlu diputuskan: apakah nomor pos/cabang di-hardcode per akun, atau petugas memilih pos saat login?
- Perlu kebijakan privasi tertulis untuk penyimpanan data lokasi & foto petugas (terutama jika nanti masuk face-match).
