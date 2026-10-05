# Changelog — BSS Parking TimeMark

Semua pembaruan, perbaikan bug, dan penambahan fitur aplikasi **BSS Parking TimeMark** dicatat secara kronologis di dokumen ini.

## [2.0.64+72] — 2026-10-05

### 🎯 Highlight Utama
Perbaikan bug hilangnya/resetnya progress pengerjaan maintenance saat teknisi keluar dan kembali melanjutkan pengerjaan via tombol **"Kerjakan"** di Daily Tasks. Kini aplikasi otomatis mendeteksi progress berjalan dan langsung melanjutkan (*seamless auto-resume*) ke checklist tanpa mereset foto yang sudah terverifikasi sebelumnya.

---

### 🚀 Fitur & Perbaikan Detail
1. **Intelligent Auto-Resume Pengerjaan Maintenance (`DailyTaskService` & `TeknisiDailyTasksScreen`)**:
   - Menambahkan deteksi cerdas `DailyTaskService.getOngoingMaintenance(task)` yang memetakan tugas aktif teknisi ke draft pengerjaan yang belum selesai.
   - Tombol **"Kerjakan"** di kartu tugas otomatis beralih menjadi **"Lanjutkan"** jika ada foto yang sudah diverifikasi, lengkap dengan indikator progress bar dan badge *"Proses (X/Y)"*.
   - Saat ditekan, sistem langsung mengarahkan teknisi ke `MaintenanceChecklistScreen` dengan seluruh foto terverifikasi tetap utuh tanpa membuka setup dialog ulang.
2. **Keterhubungan Data Task & Submission (`MaintenanceSubmission`)**:
   - Penambahan field `taskId` dan metode `copyWith` pada `MaintenanceSubmission` untuk menyimpan asosiasi ID tugas PocketBase.
   - Saat checklist selesai 100%, sistem otomatis memanggil `DailyTaskService.completeTask(...)` di background untuk menandai status tugas selesai lengkap dengan foto bukti dan jam selesai.
3. **Kualitas & Verifikasi**:
   - 194/194 unit & widget tests lulus (100% green).
   - `flutter analyze`: 0 issues (clean).

---

## [2.0.63+71] — 2026-10-05

### 🎯 Highlight Utama
Perbaikan kontras status manless pada Dark Mode agar terbaca jelas (high-contrast amber badge & white text) serta pemulihan Google AI Studio API Key (`gemini-3.1-flash-lite`) untuk verifikasi checklist SOP visual otomatis di lapangan.

---

### 🚀 Fitur & Perbaikan Detail
1. **Dark Mode Status & Checklist Point Contrast (`MaintenanceChecklistScreen` & `TemplateListScreen`)**:
   - Status badge kuning (amber) menggunakan kontras tinggi `#FDE68A` dengan container transparan gelap `#78350F` (alpha 0.35) dan border `#D97706`.
   - Catatan temuan teknisi (`alasan`) kini berwarna putih terang `#F1F5F9` di dark mode (tidak lagi hitam pekat).
   - Seluruh background modal sheet, checklist checkpoint panduan, filter chip unit/status, dan kartu template SOP tersinkronisasi penuh dengan dark surface.
2. **Restorasi Google AI Studio Key (`AiVisionConfig`)**:
   - Menghubungkan kembali token resmi Google AI Studio Free Tier yang teruji aktif dengan model `gemini-3.1-flash-lite` via endpoint Google Cloud AI.
   - Mengatasi kendala gagal koneksi server AI pada perangkat Android di lapangan.
3. **Kualitas & Verifikasi**:
   - 189/189 unit & widget tests lulus (100% green).
   - `flutter analyze`: 0 issues (clean).

---

## [2.0.62+70] — 2026-10-05

### 🎯 Highlight Utama
Perbaikan kritis bug spam notifikasi pada modul Daily Task saat keluar-masuk aplikasi atau men-skrol status bar Android. Mengimplementasikan deduplikasi signature tugas pending, flag `onlyAlertOnce: true`, channel notifikasi Android mandiri (`bss_daily_tasks_channel`), serta throttling lifecycle kamera.

---

### 🚀 Fitur & Perbaikan Detail
1. **Deduplikasi Signature Pending Task (`NotificationService`)**:
   - Menghitung hash signature dari jumlah dan ID tugas pending. Jika daftar tugas tidak berubah, notifikasi diabaikan secara otomatis.
2. **Flag `onlyAlertOnce: true`**:
   - Mencegah Android memutar suara/getar ulang saat notifikasi di-refresh di background.
3. **Channel Notifikasi Android Terpisah (`bss_daily_tasks_channel`)**:
   - Memisahkan notifikasi tugas harian dari alarm shift (`Importance.max`), menggunakan prioritas standar tanpa getaran yang mengganggu.
4. **Lifecycle Resumed Throttle (`CameraCaptureScreen`)**:
   - Cooldown 4 detik pada pembaruan badge daily task untuk mencegah spam saat gestur buka-tutup notification shade.
5. **Kualitas & Verifikasi**:
   - 189/189 unit & widget test lulus (100% green).
   - `flutter analyze` 0 issues.

---

## [2.0.61+69] — 2026-10-04

### 🎯 Highlight Utama
Integrasi otomatis seluruh daftar pekerjaan Daily Task yang telah selesai maupun pending langsung ke dalam Laporan Pulang (`DailyPulangBottomSheet`). Mengeliminasi tombol sticky bar makro terpisah untuk mencegah pengiriman pesan ganda (spam) ke grup WhatsApp operasional. Teknisi cukup mengirim 1 kali Laporan Pulang lengkap beserta foto kepulangan.

---

### 🚀 Fitur & Perbaikan Detail
1. **Integrasi Daily Task ke Laporan Pulang (`DailyPulangBottomSheet`)**:
   - Menghapus sticky bar terpisah di layar daily task dan mengalirkan tugas selesai/pending langsung ke Laporan Pulang saat absen kepulangan teknisi.
   - Tombol interaktif "⚡ Sinkron Daily Task" di form Laporan Pulang untuk auto-fill 1-tap.
   - Format bernomor rapi dengan catatan teknisi di bawah setiap tugas tanpa kata "Catatan:".
2. **Pembaruan WhatsApp Formatter**:
   - `formatAutoNumberedList` di `WhatsAppReportService` menjaga baris catatan penjelasan di bawah setiap tugas bernomor tanpa penomoran ekstra.
3. **Kualitas & Verifikasi**:
   - 188/188 unit & widget test lulus (100% PASS).
   - `flutter analyze` 0 issues (100% Clean).

---

## [2.0.60+68] — 2026-10-04

### 🎯 Highlight Utama
Implementasi arsitektur pelaporan dua lapis (Micro Report per-task & Macro Report harian gabungan) khusus modul Daily Task dengan pengiriman langsung ke WhatsApp tanpa duplikasi foto, hard-gate validasi wajib foto dokumentasi + catatan teknisi, realtime pending badge di Sidebar Drawer dan Top Bar, serta Android Local Notification otomatis.

---

### 🚀 Fitur & Perbaikan Detail
1. **Hard-Gate Validasi & Micro Report Per-Task Direct WhatsApp**:
   - Teknisi wajib mengambil minimal 1 foto dokumentasi dan mengisi catatan sebelum tombol "Selesaikan Tugas" aktif.
   - Micro report langsung memanggil WhatsApp dengan foto dan caption ringkas.
2. **Realtime Badge & Notifikasi Lokal Android**:
   - Pending count badge live di top bar kamera dan menu sidebar drawer (`DailyTaskService.pendingCountNotifier`).
   - Android Local Notification (`notificationIdDailyTasks`) dengan style `BigTextStyleInformation` memuat rincian tugas pending hari ini.
3. **Kualitas & Verifikasi**:
   - 187/187 unit & widget test lulus.
   - Kompilasi split APK (arm64-v8a 22.4 MB, armeabi-v7a 20.1 MB, x86_64 23.9 MB).

---

## [2.0.58+66] — 2026-10-04

### 🎯 Highlight Utama
Peningkatan keamanan anti-fraud komprehensif, resiliensi jaringan lemah (fast-bypass AI), dan optimasi kebersihan workspace. Mengintegrasikan deteksi **Fake GPS / Mock Location pada Kamera Maintenance (`PointCameraView`)**, tombol pintas **Mode Sinyal Lemah (Offline Fast Bypass)** pada floating card HUD, pembersihan 643MB APK usang, inisialisasi Git tracking repositori, serta penataan ulang modul benchmarking.

---

### 🚀 Fitur & Perbaikan Detail
1. **Self-Hosted PocketBase Backend & Cloudflare Named Tunnel (CT 105 Proxmox)**:
   - Membuat CT 105 di Proxmox host (`100.82.50.49`) dengan PocketBase v0.40+ dan Cloudflare Named Tunnel HTTPS publik permanen (`https://bssparking.trakingduit.my.id`).
   - Menyediakan database tabel `users` (Role SPV & Teknisi) dan `daily_tasks` (Checklist harian, pos, tanggal, status, bukti pengerjaan).
2. **Multi-User Auth & Role-Gating Bersih (SPV & Teknisi)**:
   - Layar login standar production (`LoginScreen`) tanpa chip shortcut testing.
   - Hak akses dipisah total: Menu "Penugasan Teknisi" hanya muncul untuk SPV. User teknisi tidak bisa melihat/membuka menu penugasan maupun memilih teknisi lain.
   - Offline authentication fallback dan session persistence di storage lokal.
3. **Penugasan Teknisi & Pemantauan Progres (SPV)**:
   - Menu drawer khusus SPV untuk membuat tugas harian per teknisi, pos, dan checklist SOP.
   - Tab pemantauan status penyelesaian tugas tim secara real-time.
4. **Card Daily Teknisi di Viewfinder Kamera & Auto-Fill Pulang**:
   - Card interaktif mengambang di layar kamera teknisi menampilkan tugas hari ini dengan tombol *Kerjakan* (1-tap buka wizard maintenance/foto).
   - Saat absensi pulang (`DailyPulangBottomSheet`), kolom pekerjaan selesai otomatis terisi dari daily tasks yang sudah tuntas tanpa perlu ketik manual.
5. **Keamanan Anti-Mock GPS di Kamera Maintenance (`PointCameraView`)**:
   - Menambahkan guard deteksi Fake GPS/Mock Location sebelum pemotretan checklist perangkat.
   - Pilihan *Lanjut Darurat* otomatis memberi stempel `[⚠️ FAKE GPS DETECTED]` dan mengunci status ke Cek Manual SPV.
2. **Resiliensi Sinyal Lemah & Fast Bypass AI (`VerificationStepCard`)**:
   - Teknisi di area basement atau blind spot dapat langsung menekan tombol *Sinyal Lemah? Lewati & Simpan Cepat* pada HUD langkah verifikasi tanpa menunggu timeout jaringan cloud 25 detik.
3. **Pembersihan & Higienitas Repositori**:
   - Memangkas lebih dari 640MB APK lawas di folder `bsstimemark/` dan menghapus direktori duplikat `lib_v2049_backup/`.
   - Mengelompokkan skrip benchmark python ke direktori `tools/benchmarks/`.
   - Menginisialisasi repositori Git dan memperbarui `.gitignore`.
4. **Kualitas & Stabilitas**:
   - 183/183 pengujian unit & widget tests lulus (100% green).
   - Analisis kode statis bersih tanpa error (`flutter analyze`: 0 issues).

---

## [2.0.50+58] — 2026-09-22

### 🎯 Highlight Utama
Redesain UI/UX komprehensif versi **v2.0.50** mengadopsi standar Apple Human Interface Guidelines (HIG) dan pedoman desain bebas slop AI (*Anti-AI Slop*). Memperkenalkan palet warna **Putih, Biru BSS Navy (`#1A428A`), Safety Orange (`#FF6500`), dan Warm Cream (`#FAF7F0`)**. Dilengkapi sistem sudut continuous squircle (14px - 28px), umpan balik haptik taktil (*haptic punctuation*), angka monospace tabular untuk tanggal/waktu, serta pencadangan penuh snapshot UI v2.0.49 dengan skrip pemulihan instan (*one-click recovery*).

---

### 🚀 Fitur & Perbaikan Detail
1. **Pencadangan & Skrip Pemulihan UI v2.0.49**:
   - Snapshot lengkap source code `lib/` dicadangkan ke `lib_v2049_backup/`.
   - Skrip pemulihan otomatis tersedia di `tools/recovery_ui_v2049.sh` untuk mengembalikan UI lama kapan saja jika dibutuhkan.
2. **Sistem Desain & Tema Putih-Biru-Orange-Cream (`AppColors` & `AppTheme`)**:
   - Menghapus semua corak gradient ungu/indigo/blur murah (*anti-slop*).
   - Menetapkan Navy `#1A428A` sebagai warna primer dan Safety Orange `#FF6500` sebagai aksen tunggal yang terkunci untuk elemen CTA dan progress.
   - Mengaktifkan `fontFeatures: [FontFeature.tabularFigures()]` untuk semua angka jam, menit, tanggal, dan koordinat.
3. **Penyegaran Layar Kamera (`CameraCaptureScreen`)**:
   - Shutter button pro dual-ring dengan cincin Safety Orange dan haptic medium impact.
   - Tombol shortcut Galeri & SOP dengan container squircle 14px dan umpan balik haptic.
   - Header Drawer dengan badge `v2.0.50 PRO • NATIVE TACTILE`.
4. **Redesain Bottom Sheet Laporan Daily Pulang (`DailyPulangBottomSheet`)**:
   - Mengubah tampilan dari dark background lama menjadi kontainer putih modern dengan sudut squircle 28px.
   - Aksen garis atas Safety Orange, avatar inisial petugas rapi, dan tombol simpan taktil berhaptic.
5. **Penyegaran Dialog Kategori Absensi (`AbsensiKategoriDialog`)**:
   - Kontainer dialog squircle 24px, 4 kolom tombol shift sejajar dengan active border kontras tinggi.
   - Tombol simpan kategori Safety Orange taktil.
6. **Peningkatan Layar Checklist Maintenance & Galeri**:
   - Kartu checklist bersudut squircle 16px, thumbnail 12px, progress bar Safety Orange di AppBar.
   - Galeri foto dengan tombol download Safety Orange dan seleksi album cepat.
7. **Kualitas & Stabilitas**:
   - Analisis kode statis bersih tanpa error (`flutter analyze`: 0 issues).
   - Seluruh pengujian benchmark stress test lolos (100% green).
   - Knowledge graph AST tersinkronisasi via `graphify update .`.

---

## [2.0.49+57] — 2026-09-22

### 🎯 Highlight Utama
Penyempurnaan logika absensi terlambat & kepulangan shift (Opsi 1): Teknisi yang masuk terlambat (misal Shift 1 jam 03:00 - 11:00 masuk jam 06:00) kini **dapat melakukan absensi pulang tepat waktu saat jam akhir jadwal shift selesai (jam 11:00)** agar proses serah terima (*handover*) pos parkir ke petugas shift berikutnya berjalan lancar tanpa tertahan di pos. Sistem tetap mencatat durasi riil secara transparan dan mempertahankan *Early Departure Guard* untuk memblokir kepulangan sebelum jam shift berakhir jika durasi kerja belum genap.

---

### 🚀 Fitur & Perbaikan Detail
1. **Opsi 1 Kelayakan Pulang (`isEligibleForAutoPulang`)**:
   - Menghitung waktu akhir shift otomatis via `getScheduledPulangTime`.
   - Mengizinkan absensi pulang jika **jam akhir shift telah tiba (`now >= scheduledPulang`)** ATAU **durasi kerja normal terpenuhi ($\ge$ 8 jam / $\ge$ 4 jam)**.
   - Mengatasi kasus kebuntuan (*lockout*) teknisi yang terlambat di mana aplikasi sebelumnya memaksa menunggu hingga genap 8 jam di luar jadwal shift.
2. **Proteksi Pulang Cepat (*Early Departure Guard*)**:
   - Jika teknisi mencoba pulang sebelum jam shift berakhir DAN durasi belum terpenuhi, aplikasi menampilkan dialog informatif yang mencantumkan jam akhir shift, durasi yang sudah berjalan, serta sisa jam kerja normal.
3. **Penyelarasan Notifikasi Pengingat Pulang**:
   - `NotificationService.scheduleAbsenPulangNotification` kini menjadwalkan notifikasi pada waktu yang lebih awal antara jam akhir shift atau durasi kerja penuh, sehingga teknisi langsung diingatkan saat shiftnya berakhir.
4. **Kualitas & Stabilitas**:
   - Seluruh unit & widget tests lolos (100% green).
   - Analisis kode statis 0 issue (`flutter analyze` bersih).

---

## [2.0.48+56] — 2026-09-21

### 🎯 Highlight Utama
Perbaikan tampilan layar kamera maintenance (`PointCameraView`): perbaikan header lokasi & judul agar tidak terpotong (`P...`), optimalisasi lebar bar kontrol, dan checkpoint card multi-line responsif tanpa terpotong teksnya. Pembaruan aturan validasi AI Vision dan checklist: Poin 2 mewajibkan verifikasi 3 jendela/tab (Windows Update dinonaktifkan, Antivirus Real-time OFF, dan Windows Defender Firewall OFF) serta Poin 3 pengujian keyboard & mouse yang fleksibel (KeyTest.com atau Notepad dengan karakter lengkap & kursor aktif).

---

### 🚀 Fitur & Perbaikan Detail
1. **Header & Bar Kontrol Kamera Bebas Terpotong**:
   - Location tag (seperti `PBM`) diberi kontainer badge tersendiri.
   - Judul `Maintenance` tampil utuh tanpa terpotong `P...`.
   - Tombol kontrol kanan (`AI Cloud`, Timer, Ratio, Flash) dibuat lebih kompak dan proporsional untuk semua resolusi layar HP.
2. **Kartu Checkpoint Kamera Multi-Line**:
   - Judul checkpoint (`maxLines: 2`) dan deskripsi SOP (`maxLines: 3`) dapat melipat baris secara rapi (`softWrap: true`).
   - Tidak ada lagi teks SOP yang terpotong elipsis (`...`).
3. **Validasi AI Vision Poin 2 (Update, Antivirus & Firewall)**:
   - Evaluasi wajib melihat 3 kondisi sekaligus: Windows Update nonaktif/paused, Antivirus Real-time protection OFF, dan Windows Defender Firewall OFF.
   - Penolakan tegas (`tidak_sesuai`) jika salah satu komponen keamanan masih aktif.
4. **Validasi AI Vision Poin 3 (Keyboard & Mouse)**:
   - Mendukung Opsi A: Browser `keytest.com` dengan tombol aktif berwarna / layout putih.
   - Mendukung Opsi B: Notepad dengan ketikan lengkap `1234567890qwertyuiopasdfghjklzxcvbnm` + F1-F12 + kursor mouse aktif.
5. **Kualitas & Stabilitas**:
   - 174/174 unit & widget tests lolos (100% green).
   - Analisis kode statis 0 issue (`flutter analyze` bersih).

---

## [2.0.44+52] — 2026-09-19

### 🎯 Highlight Utama
Dukungan penuh pemeliharaan **Linux Server & Windows Kasir** pada template *Maintenance: Server & Kasir*, dilengkapi **Selector OS Server (Linux vs Windows)** di dialog setup, standarisasi checkpoint & panduan terminal khusus Linux (`df -h`, `ufw status`, console input test), rubrik evaluasi AI Vision berbasis observasi faktual nyata, pelaporan WhatsApp bersih anti-embel "linux df -h" dan anti-kata "Normal", serta penyediaan binary APK Release terpisah untuk **ARM 64-bit** dan **ARM 32-bit**.

---

### 🚀 Fitur Baru & Peningkatan (Features & Enhancements)

#### 1. Pemilih OS Server di Dialog Setup (`MaintenanceSetupDialog`)
- Teknisi dapat memilih jenis OS yang berjalan di PC Server: **Linux Server** (CLI / Terminal) atau **Windows Server**.
- Penyesuaian otomatis:
  - **Server & Kasir Terpisah**: Server Utama (Unit 1) mengikuti OS yang dipilih, sementara Komputer Kasir (Unit 2..N) otomatis berorientasi Windows.
  - **Server & Kasir Gabung (All-in-One)**: Menyesuaikan seluruh 6 poin pada komputer tunggal tersebut.

#### 2. Checkpoint & Tutorial Perintah Terminal Linux di HP Teknisi
- **Poin 1 (Storage & Temp)**: Panduan pengecekan kapasitas partisi root via terminal `df -h /` (Avail > 20GB / Use% < 80%) & pembersihan `/tmp`.
- **Poin 2 (Firewall & Auto-Update)**: Panduan pengecekan `sudo ufw status` (inactive) / `systemctl status firewalld` & `unattended-upgrades`.
- **Poin 3 (Fungsi Keyboard & Input Console)**: Panduan pengetikan teks tes `TEST 1234567890 BSS OK` di prompt shell terminal atau nano.

#### 3. AI Vision Factual Observation Audit untuk Linux & Windows
- Rubrik evaluasi AI Vision di `ai_vision_service.dart` diperluas untuk mengenali layar gelap console terminal Linux dan layar desktop Windows.
- AI menghasilkan kalimat observasi faktual nyata dari apa yang diverifikasi di foto monitor, bukan sekadar kata generik "sesuai" atau "normal".

#### 4. Format Laporan WhatsApp Bersih & Faktual
- Judul poin laporan WhatsApp tetap bersih tanpa embel-embel teknis (misal `1. *Pembersihan storage & file temp* :`).
- Menghilangkan kata "Normal", langsung menampilkan hasil observasi faktual AI Vision (`p.alasan`).

---

### 📦 Binary Releases
- **ARM 64-bit Release (22 MB)**: `bsstimemark/BSS-TimeMark-v2.0.44-ARM64-Release.apk`
- **ARM 32-bit Release (20 MB)**: `bsstimemark/BSS-TimeMark-v2.0.44-ARM32-Release.apk`

---

## [2.0.43+51] — 2026-09-19

### 🎯 Highlight Utama
Pembaruan versi resmi ke `v2.0.43+51` dengan output build spesifik arsitektur terpisah: **ARM 64-bit (`arm64-v8a`)** dan **ARM 32-bit (`armeabi-v7a`)**. Pembaruan ini memastikan instalasi lebih ringan, cepat, dan kompatibel optimal sesuai arsitektur hardware masing-masing perangkat tanpa beban overhead multi-ABI.

---

### 📦 Binary Releases
- **ARM 64-bit Release (22 MB)**: `bsstimemark/BSS-TimeMark-v2.0.43-ARM64-Release.apk`
  - Dikhususkan untuk seluruh perangkat Android 64-bit modern.
- **ARM 32-bit Release (20 MB)**: `bsstimemark/BSS-TimeMark-v2.0.43-ARM32-Release.apk`
  - Dikhususkan untuk perangkat Android 32-bit / tipe lama.

---

### 🛠️ Rincian Perubahan
- **Pubspec & App Version**: Bump version dari `2.0.42+50` ke `2.0.43+51`.
- **Drawer Branding**: Teks versi pada drawer menu kamera diperbarui menjadi `Bssparking Timemark v2.0.43 (Universal Cloud AI)`.
- **Integritas Sistem**: 161/161 unit & widget test passing (100% green), static analysis 0 issues.

---

## [2.0.42+50] — 2026-09-19

### 🎯 Highlight Utama
Rilis stabil lapangan komprehensif yang memperbaiki masalah watermark absensi masuk/pulang, mengeliminasi duplikasi penyimpanan galeri saat foto ulang (retake), membuka akses instan riwayat maintenance tanpa ganjalan PIN, menyediakan arsip pekerjaan selesai 100%, standarisasi 9 poin baku checklist barrier gate, fitur download multi-select di galeri, serta menyediakan binary APK Universal (32-bit & 64-bit) dan ARM64.

---

### 🚀 Fitur Baru & Peningkatan (Features & Enhancements)

#### 1. Layar Riwayat Maintenance & Tab Selesai 100%
- **Tab Dual Mode**:
  - **Draft Berjalan**: Menampilkan seluruh sesi pengerjaan checklist yang belum selesai lengkap dengan persentase progress dan tombol resume.
  - **Selesai 100%**: Mengarsipkan seluruh pekerjaan maintenance yang telah rampung lengkap dengan rincian tanggal, jam, status per poin, dan tombol kirim ulang laporan.
- **Card Clickable (Tap-to-Resume)**:
  - Seluruh permukaan kartu draft dibungkus `InkWell`, memungkinkan teknisi mengetuk di area mana saja pada kartu untuk melanjutkan pengerjaan.
- **Styling TabBar Kontras Tinggi**:
  - Teks tab aktif putih tegas (`Colors.white`, font weight 800) dan teks tab tidak aktif putih 70% di atas AppBar biru primer BSS, dengan indikator garis bawah putih 3px.
- **Akses Langsung Tanpa PIN**:
  - Ganjalan dialog PIN teknisi pada drawer samping telah dicabut untuk menu *Riwayat Maintenance*, mempercepat alur kerja harian teknisi.
- **Shortcut History di Checklist**:
  - Menambahkan tombol pintas `IconButton(Icons.history_rounded)` langsung pada AppBar layar checklist maintenance.

#### 2. Standarisasi 1:1 9 Poin Baku Checklist & Laporan Barrier Gate
- **Template Standar**:
  - Template `tpl_maint_barrier` di `TemplateRepository` distandarisasi memuat persis 9 poin baku checklist teknisi lapangan.
- **Format Laporan WhatsApp & Telegram Rapi**:
  - Pemetaan poin 1:1 di `WhatsAppReportService` dengan header unit dinamis (`Gate : 1 Unit (Gate 1)` s/d `Gate : X Unit (Gate 1 - Gate X)`).
  - Penandaan status visual jelas antara item normal vs item berkendala/rusak.

#### 3. Manajemen Galeri & Unduh Massal (Multi-Select Download)
- **Unduh Foto Individual**:
  - Tombol simpan langsung (`ShareHelper.savePhotoToGallery`) pada dialog preview foto.
- **Mode Pilih Massal ("Pilih")**:
  - Mode seleksi banyak foto dengan indikator centang visual dan border highlight.
  - Tombol aksi *"Pilih Semua"* dan *"Batal Semua"*.
  - Floating bottom action bar dengan tombol *"Download (X Foto)"* yang menyimpan foto ke album penyimpanan lokal `'BSS Parking'`.

---

### 🐛 Perbaikan Bug (Bug Fixes)

#### 1. Jaminan Watermark Absensi Masuk & Pulang Terbakar Sempurna
- **Akar Masalah**:
  - Fungsi `commitRecord()` sebelumnya menyimpan `capturedPath` sebelum proses rendering watermark (`watermarkFuture`) selesai diproses. Akibatnya, foto yang dikirim ke WhatsApp/Telegram atau disimpan ke riwayat adalah foto mentah kamera (*raw camera snapshot*) tanpa banner watermark.
- **Perbaikan**:
  - Menambahkan jaminan mutlak `await watermarkFuture.timeout(const Duration(seconds: 10))` di dalam `commitRecord()`.
  - Banner tag (Absensi Masuk / Pulang), jam digital real-time, logo BSS Parking, tanggal, alamat POS, dan koordinat GPS dipastikan terbakar permanen pada file JPEG sebelum disimpan atau dibagikan.

#### 2. Eliminasi Duplikasi Penyimpanan Galeri & Dukungan Retake Bebas
- **Akar Masalah**:
  - Auto-save di background yang berjalan sebelum konfirmasi verifikasi modal AI menyebabkan foto tersimpan 2x di galeri perangkat. Selain itu, foto yang dibatalkan / difoto ulang (*retake*) terlanjur tersimpan di album foto teknisi.
- **Perbaikan**:
  - Menghapus panggilan auto-save background prematur. Foto hanya disimpan ke galeri satu kali saat teknisi menekan tombol *"Selesai verifikasi, Kirim Laporan"* atau tombol share WhatsApp / Telegram.
  - Menambahkan tombol *"Foto Ulang"* pada `SopVerificationModal` bahkan saat verifikasi AI valid 100%, sehingga teknisi bebas mengambil ulang foto tanpa mengunci status atau membalik shift.

#### 3. Proteksi Ukuran & Memory Decode
- Null-safety checks eksplisit pada hasil keluaran isolate watermark.
- Pembatasan downscaling decoding maksimal 1920px (Full HD) di `image_watermark_processor.dart` untuk mencegah error Out-of-Memory (OOM) pada sensor kamera beresolusi tinggi (48MP–108MP) dengan waktu render tetap di bawah 600ms.

---

### 📱 Kompatibilitas Perangkat & Binary Release

- **Universal Fat Binary APK (59 MB)**:
  - Konfigurasi `abiFilters` memuat arsitektur `arm64-v8a` dan `armeabi-v7a`.
  - Kompatibel penuh untuk diinstal pada seluruh smartphone Android (baik Android 32-bit HP jadul maupun Android 64-bit HP baru) tanpa error *"App not installed"*.
  - Lokasi: `build/app/outputs/flutter-apk/BSS-Timemark-v2.0.42-universal.apk` & `bsstimemark/BSS-TimeMark-v2.0.42-Universal-Release.apk`.
- **ARM64 Light Binary APK (22 MB)**:
  - Binary khusus perangkat 64-bit berukuran ramping (<25MB) yang kompatibel dengan batas unggah Telegram Bot API (50MB).
  - Lokasi: `build/app/outputs/flutter-apk/BSS-Timemark-v2.0.42-arm64.apk`.

---

### 🧪 Verifikasi & Kualitas Kode
- **Unit & Widget Testing**: 161/161 tests lulus 100% green (`flutter test`).
- **Static Analysis**: 0 issues found (`flutter analyze`).
- **Knowledge Graph**: Ter-update via `graphify update .`.
- **Telegram Notification**: Preview visual dan binary APK sukses terkirim ke Telegram bot DHS.
