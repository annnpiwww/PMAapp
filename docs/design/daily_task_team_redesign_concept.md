# Konsep Redesain Antarmuka: SPV Daily Task Team PMA

Dokumen spesifikasi konsep redesain UI/UX untuk layar pemantauan dan pembagian tugas harian Supervisor (SPV) pada aplikasi BssparkingTimeMark. Disusun berdasarkan acuan visual `docs/design_references/`, karakteristik data riil `DailyTaskModel`, serta prinsip desain anti-slop, aksesibilitas WCAG AA, dan efisiensi operasional lapangan.

---

## 1. Audit Layar Eksisting (Evaluasi Kritis P0 sampai P3)

Audit dilakukan secara *read-only* pada file `lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart`, komponen kartu `lib/features/daily_tasks/widgets/spv_task_card.dart`, dialog dispatch, serta membandingkan konsistensi dengan `lib/features/daily_tasks/screens/teknisi_daily_tasks_screen.dart`. Bukti visual merujuk langsung pada tangkapan layar `docs/screenshots/live_spv_status_current.png`, `docs/screenshots/live_spv_beri_current.png`, `docs/screenshots/spv_status_tim.png`, dan `docs/screenshots/spv_kontrol_tim.png`.

Prinsip evaluasi mengacu pada pedoman `docs/design_references/design_system_motion_guidelines.md` Bagian 1 (UI vs UX Framework: *Frictionless goal solving*, *Wayfinding*, *Time-to-task*) dan `Screenshot_2026-11-03_11-43-08.png`.

```
RINGKASAN TEMUAN AUDIT
+-----+-------------------------------------------------------+-------------+
| Tkt | Deskripsi Masalah & Bukti Lapangan                    | Dampak      |
+-----+-------------------------------------------------------+-------------+
| P0  | Lokasi tugas (posTag) tenggelam di baris bawah kartu  | Kritis      |
| P1  | Header menumpuk (header bloat), boros ruang layar     | Tinggi      |
| P2  | Saturasi aksen berlebih & avatar inisial monoton      | Sedang      |
| P3  | Pemisahan kaku tab Beri Tugas vs Status Tim           | Rendah-Mod  |
+-----+-------------------------------------------------------+-------------+
```

### P0 (Kritis): Lokasi Pos (posTag) Tenggelam dan Hilang dari Fokus Utama
* **Bukti Kode & Visual:** Pada `spv_task_card.dart` (baris 215-227) dan tangkapan layar `live_spv_status_current.png`, lokasi pos hanya ditampilkan sebagai catatan kaki teks kecil berukuran 10.5sp di sebelah ikon emoji pin (`📍 PBM` atau `📍 PKM`). Kode singkatan pos operasional (`posTag`) yang seharusnya menjadi acuan cepat SPV justru tidak ditonjolkan.
* **Akar Masalah UX:** Dalam operasional parkir komersial multi-lokasi (seperti Kawasan Megamas, Novotel, Mega Mall), SPV membagi teknisi berdasarkan zona fisik pos. Menempatkan lokasi di baris paling bawah memperlambat *glanceability* saat memindai 10 sampai 20 tugas di bawah terik matahari. SPV terpaksa membaca judul tugas sampai selesai hanya untuk mengetahui tugas tersebut ada di pos mana.
* **Solusi Wajib:** `posTag` (contoh: PKM, PBM, NBM, MGNS, MGLG) wajib dinaikkan menjadi *anchor badge* visual di posisi kiri atas kartu dengan kontras tinggi.

### P1 (Tinggi): Header Menumpuk (Header Bloat) dan Navigasi Filter Berbelit
* **Bukti Kode & Visual:** Pada `live_spv_status_current.png`, area atas layar menghabiskan ruang vertikal hingga ~220dp dari total ketinggian layar standar 640dp (hampir 35% layar):
  1. AppBar judul + TabBar (`Beri Tugas` / `Status Tim`) memakan ~96dp.
  2. Baris kontrol tanggal, persentase ringkas, dan tombol oranye `Kontrol Tim` memakan ~48dp.
  3. Baris segmented filter status (`Selesai (2)`, `Belum Mulai (4)`, `Semua (6)`) memakan ~44dp.
  4. Jika filter teknisi aktif, muncul lagi banner tambahan `Filter Teknisi: X` memakan ~32dp.
* **Akar Masalah UX:** Pada ponsel berlebar 360dp, area konten yang tersisa hanya mampu menampilkan 2 kartu tugas secara utuh tanpa *scrolling*. Lebih buruk lagi, untuk memfilter teknisi tertentu, SPV harus menekan tombol `Kontrol Tim`, yang memicu modal bottom sheet terpisah (`_showTeamControlBottomSheet`), memilih dropdown, dan menutup modal. Alur ini membuang waktu untuk tindakan yang dilakukan berulang kali setiap pergantian shift.
* **Solusi Wajib:** Satukan kontrol tanggal, metrik ringkas, dan filter teknisi ke dalam satu strip horizontal yang ringkas (*horizontal chip bar*), sehingga menyisakan ruang vertikal maksimal untuk daftar tugas.

### P2 (Sedang): Penggunaan Warna Aksen Oranye Berlebih (Color Fatigue) dan Avatar Kotak yang Sia-Sia
* **Bukti Kode & Visual:** Sesuai aturan `antislop-ui` (aturan R-29 dan R-01), warna aksen `#FF6500` (Safety Orange) saat ini dipakai hampir di semua tempat sekaligus: garis bawah tab aktif, badge persentase, tombol kontrol tim, badge status `Belum Mulai`, tag `SOP MTC`, hingga seleksi filter. Akibatnya, mata pengguna kehilangan titik fokus (*focal point*).
* **Akar Masalah UI:** Di samping saturasi warna, kotak avatar inisial ukuran 34x34dp di sisi kiri kartu (`RL`, `JM`, `RS`, `AS`) berulang terus-menerus ke bawah tanpa memberikan nilai tambah informasi, namun memakan 44dp lebar horizontal kartu yang sempit di layar 360dp.
* **Solusi Wajib:** Batasi warna Safety Orange khusus untuk tindakan utama (CTA) atau penanda perhatian khusus. Gantikan kotak inisial statis dengan tata letak teks yang lebih padat dan manfaatkan ruang horizontal untuk nama pos dan judul pekerjaan.

### P3 (Rendah ke Sedang): Pemisahan Rigid Antara Tab "Beri Tugas" dan "Status Tim"
* **Bukti Kode & Visual:** `spv_task_dispatcher_screen.dart` membelah dua mode kerja SPV ke dalam `TabBarView` terpisah: tab pertama untuk form pembuatan tugas (`_buildFormTugaskan`, baris 999), dan tab kedua untuk pemantauan (`_buildListPantau`, baris 1000).
* **Akar Masalah UX:** Dalam pola kerja nyata, SPV membuka layar untuk melihat status tim terlebih dahulu. Ketika melihat ada pos yang kosong atau ada kendala lapangan, SPV langsung ingin menambahkan tugas baru. Berpindah tab penuh membuat SPV kehilangan konteks daftar tugas yang sedang dipantau.
* **Solusi Wajib:** Jadikan daftar pemantauan tim sebagai layar utama (*single unified workspace*), sedangkan aksi pembuatan tugas dibuka melalui tombol aksi cepat / bottom sheet form yang adaptif.

---

## 2. Dua Arah Konsep Redesain (Maksimal 2 Konsep Terkurasi)

Penyusunan konsep mengacu pada token `docs/design_references/design_system_motion_guidelines.md` Bagian 2 (Preset A: Productivity & SaaS Dashboard "Flowly" & "Nexora"), Bagian 3 Katalog Micro-Interactions, serta screenshot referensi visual:
- `docs/design_references/Screenshot_2026-11-03_11-43-14.png` (Flowly: dashboard rapi, metrik minimalis, kartu tugas terstruktur).
- `docs/design_references/Screenshot_2026-11-03_11-43-25.png` (Nexora: elevasi gelap terkalibrasi dengan aksen fungsional).
- `docs/design_references/Screenshot_2026-11-03_11-42-52.png` (Pola menu dan modal bottom sheet M4 & M5).
- `docs/design_references/Screenshot_2026-11-03_11-43-03.png` (Pola pull-to-refresh R2 & R3).

---

### Konsep A: "Operational Flow" (Disarankan untuk Alur Kerja Cepat Lapangan)

Konsep ini mengadaptasi tema produktivitas bersih (Preset A "Flowly") yang dipadatkan khusus untuk kebutuhan lapangan teknisi parkir. Layar dijadikan satu kanvas utama pemantauan, di mana filter teknisi, metrik status, dan pembuatan tugas dapat diakses dalam satu ketukan tanpa membuka modal bertingkat.

#### 1. Referensi Inspirasi
- **Visual & Layout:** `docs/design_references/Screenshot_2026-11-03_11-43-14.png` (Kartu ringkasan metrik angka besar, tag kategori berwarna lembut, baris tugas berjarak konsisten).
- **Motion & Interaksi:**
  - `T1 Worm Underline` / `T6 Badge Pop` (`design_system_motion_guidelines.md` Kategori 3): Indikator filter teknisi bergeser lentur dengan angka badge tugas aktif.
  - `M4 Bottom Sheet` & `M11 Button to Panel` (`design_system_motion_guidelines.md` Kategori 6): Tombol `+ Tugas Baru` meluncurkan form ringkas tanpa meninggalkan konteks pemantauan.
  - `C2 Strike & Sink` (`design_system_motion_guidelines.md` Kategori 5): Tugas yang diselesaikan otomatis turun ke kelompok selesai dengan transisi halus.

#### 2. Wireframe ASCII (Mobile 360dp)
```text
+------------------------------------+ (360dp)
| [<-] Daily Task Team PMA       [WA]|  AppBar (Navy #1A428A / Dark #111827)
+------------------------------------+
| [📅 Hari Ini v]  [⚡ 4/6 Selesai 67%] |  Sticky Sub-Header (Kompak 40dp)
+------------------------------------+
| (Semua 6) [Ryan 2] (Junifer 2) ... |  Horizontal Tech Filter Strip
+------------------------------------+
| [ Semua (6) ] [ Belum (4) ] [ OK 2]|  Segmented Status Pill
+------------------------------------+
| DAFTAR TUGAS HARI INI              |
|                                    |
| +--------------------------------+ |
| | [PKM] Pemasangan Speedbump     | |  Anchor Badge [PKM] mencolok di kiri
| |       Gate Out PKM             | |  Judul tugas tegas & tebal
| | 👤 Raldy Sangkop   ⏳ Belum    | |  Pelaksana + status chip lembut
| +--------------------------------+ |
|                                    |
| +--------------------------------+ |
| | [PBM] Maintenance 3 Pos Kasir  | |  Badge lokasi [PBM]
| |       SOP MTC • Handover: Ryan | |  Tag kategori & riwayat serah terima
| | 👤 Junifer + Alessandro        | |  Dukungan peserta bareng (pesertaList)
| | ✓ Selesai 13:18 WITA           | |  Status selesai warna hijau emerald
| +--------------------------------+ |
|                                    |
| +--------------------------------+ |
| | [MGNS] Backup Server & Foto    | |
| |        Catatan: HDD Penuh      | |  Indikator catatan teknisi
| | 👤 Junifer Manua   ⏳ Belum    | |
| +--------------------------------+ |
|                                    |
|       (Scrollable Task List)       |
|                                    |
|                [ + TUGAS BARU ]    |  Extended Floating Action Button
+------------------------------------+
```

#### 3. Hirarki Informasi (Information Hierarchy)
1. **Level 1 (Anchor Utama):** Lokasi Pos (`posTag` seperti PKM, PBM, NBM). Ditampilkan dalam kapsul tebal di sudut kiri atas setiap kartu.
2. **Level 2 (Inti Pekerjaan):** Judul tugas (`judul`) dan jenis pekerjaan (`kategori` = SOP MTC atau Tugas Khusus).
3. **Level 3 (Pelaksana):** Nama teknisi utama (`teknisiNama`) beserta teknisi pendamping (`pesertaList`).
4. **Level 4 (Status & Waktu):** Status penyelesaian (`status`), jam selesai (`jamSelesai`), serta log serah terima (`handoverDari`).
5. **Level 5 (Detail Pendukung):** Foto bukti (`fotoBuktiUrls`) dan catatan teknisi (`catatanTeknisi`).

#### 4. Daftar Komponen UI (Component Breakdown)
- **Compact Operational Header (Tinggi: 40dp):** Menyatukan pemilih tanggal cepat (`Hari Ini`, `Besok`, `Kemarin`) dengan progress pill ringkas persentase selesai. Dilengkapi tombol aksi bagikan laporan briefing WhatsApp/Telegram di sisi kanan.
- **Horizontal Technician Filter Strip (Tinggi: 38dp):** Baris chip mendatar yang dapat digeser halus (*horizontal scroll*). Setiap chip menampilkan nama panggilan teknisi dan badge jumlah tugas aktif.
- **Location-Anchor Task Card:** Kartu kontainer bersudut radius 14dp, dengan garis tepi halus 1px (`#E6E2D8` pada tema terang atau `#1E293B` pada tema gelap). Bagian kiri atas memuat *badge* singkatan pos (`posTag`) berlatar biru navy lembut atau netral kontras.
- **Quick Action Speed-Dial / FAB:** Tombol mengambang di kanan bawah layar untuk membuat tugas dadakan (`Tugas Khusus`) atau jadwal berkala (`Maintenance SOP`).

#### 5. Spesifikasi 5 Status Layar (Mandatory States)
1. **Empty State (Belum Ada Tugas):**
   - Ilustrasi: Ikon clipboard tenang dengan garis minimalis (bukan ilustrasi kartun generik).
   - Teks: "Belum ada tugas tercatat untuk [Hari Ini / Tanggal Terpilih]."
   - Sub-teks: "Tekan tombol di bawah untuk membagikan tugas baru atau jadwalkan rutin shift."
   - Aksi: Tombol `+ Buat Tugas Pertama`.
2. **Loading State:**
   - Skeleton shimmer berstruktur persis bentuk kartu (blok abu-abu halus untuk tag pos, judul, dan status) beranimasi *pulse* lembut 1.2 detik. Menghindari spinner melingkar tunggal yang membosankan.
3. **Offline Cache State:**
   - Banner tipis setinggi 28dp di bawah header: latar oranye lembut transparan (`#FFF7ED` / gelap: `#1E293B`) dengan ikon awan bergaris miring dan teks: "Mode Offline: Menampilkan data tersimpan lokal. Pembaruan akan disinkronkan saat sinyal stabil."
4. **All Done State (Semua Tugas Tuntas 100%):**
   - Kartu banner selamat bernuansa hijau emerald lembut (`#ECFDF5` / gelap: `#064E3B` border tipis `#10B981`).
   - Teks: "Semua tugas shift tuntas (6/6). Siap buat laporan penutupan atau serah terima shift."
   - Aksi: Tombol cepat `Kirim Laporan Selesai ke WA`.
5. **Overdue / Pending Alert State (Mendekati Akhir Shift Belum Selesai):**
   - Kartu tugas yang masih berstatus `pending` setelah jam 10:00 WITA (untuk Shift 1 Pagi) mendapatkan garis tepi aksen amber halus (`#F59E0B`) dan penanda kecil "Perlu Atensi / Alihkan". Memudahkan SPV untuk segera menekan opsi `Alihkan Tugas` ke shift berikutnya.

---

### Konsep B: "Tactical Location Bento" (Pendekatan Pengelompokan Berbasis Zona Pos)

Konsep ini mengambil inspirasi dari `docs/design_references/Screenshot_2026-11-03_11-43-25.png` (Nexora Dark Theme) dan prinsip `minimalist-ui` (koleksi bento grid fungsional, tanpa bayangan tebal, dengan pengelompokan lokasi yang tegas).

#### 1. Referensi Inspirasi
- **Visual & Layout:** `docs/design_references/Screenshot_2026-11-03_11-43-25.png` (Struktur bento tertata rapat, garis pembatas 1px yang presisi, kontras teks tinggi) dan `~/.gemini/skills/minimalist-ui/SKILL.md` (tipografi teratur, tanpa gradien oranye/ungu sembarangan).
- **Motion & Interaksi:**
  - `M10 Fold Down` (`design_system_motion_guidelines.md` Kategori 6): Bagian pos dapat dilipat (*accordion collapse*) jika SPV ingin fokus pada satu pos tertentu.
  - `S2 Reveal Actions` (`design_system_motion_guidelines.md` Kategori 4): Geser kartu ke kiri untuk langsung memunculkan tombol cepat `Alihkan` atau `Hapus`.

#### 2. Wireframe ASCII (Mobile 360dp)
```text
+------------------------------------+ (360dp)
| [<-] Kontrol Tim PMA           [WA]|  AppBar
+------------------------------------+
| [PKM 3]  [PBM 2]  [NBM 1]  [MGNS 1]|  Location Hub Pills (Tab Horisontal)
+------------------------------------+
| SUMMARY: 4/7 Selesai (57%)         |  Bar Metrik Taktis Bento
+------------------------------------+
| ZONA: PKM (Kawasan Megamas) [2/3]  |  Header Grup Pos Lapangan
| +--------------------------------+ |
| | [v] Gate Out 1-6 PBM           | |  Tugas selesai (dicoret halus)
| |     Ryan Lumasuge • 03:15 WITA | |  Pelaksana & jam tuntas
| +--------------------------------+ |
| | [ ] Pemasangan Speedbump       | |  Tugas tertunda
| |     Raldy Sangkop • Belum      | |  Opsi geser untuk alihkan
| +--------------------------------+ |
|                                    |
| ZONA: PBM (Mega Mall)       [1/2]  |  Header Grup Pos Kedua
| +--------------------------------+ |
| | [v] Maintenance Pos Kasir      | |
| |     Junifer Manua • 13:18 WITA | |
| +--------------------------------+ |
| | [ ] Testing Printer Bluetooth  | |
| |     Junifer Manua • Belum      | |
| +--------------------------------+ |
|                                    |
| [ + Tambah Tugas ]  [ Bagikan WA ] |  Sticky Bottom Dock (Dua Tombol)
+------------------------------------+
```

#### 3. Hirarki Informasi
1. **Level 1:** Zona Lokasi Pos Fisik (`posTag` & `posName`) sebagai induk pengelompokan (*grouping header*).
2. **Level 2:** Sub-tugas di dalam pos tersebut beserta status centang (*done state*).
3. **Level 3:** Nama teknisi yang bertanggung jawab di pos tersebut.
4. **Level 4:** Jam eksekusi dan catatan kendala pos.

#### 4. Daftar Komponen UI
- **Location Hub Selector:** Kumpulan tombol kapsul di bagian atas untuk melompat langsung ke pos yang diinginkan.
- **Bento Group Container:** Kontainer persegi dengan sudut 10dp bergaris tepi tipis yang mengelompokkan semua pekerjaan dalam satu lokasi fisik.
- **Dual Action Bottom Dock:** Docking tetap di bawah layar dengan dua tombol seimbang: `+ Tambah Tugas` dan `Bagikan WA`.

#### 5. Spesifikasi 5 Status Layar
1. **Empty State:** Kotak bento abu-abu kosong bertuliskan "Semua pos parkir beroperasi normal. Belum ada penugasan perawatan atau perbaikan hari ini."
2. **Loading State:** Shimmer grid 2 kolom yang merepresentasikan blok lokasi pos.
3. **Offline Cache State:** Ikon satelit offline pada status bar bento dengan indikator waktu sinkronisasi terakhir.
4. **All Done State:** Setiap kartu bento grup pos berubah warna garis tepinya menjadi hijau sukses dengan tanda centang penuh di header zona.
5. **Overdue / Pending Alert State:** Header grup pos berkedip dengan aksen peringatan jika masih ada tugas pending yang melewati jam operasional pos.

---

## 3. Rekomendasi Arah Desain dan Alasan Strategis

### Arah Terpilih: KONSEP A ("Operational Flow")

### Alasan Strategis (Why Concept A):
1. **Sesuai dengan Alur Nyata SPV Lapangan (Persona Fit):**
   Supervisor parkir di Manado dan cabang lain mengelola penugasan berdasarkan **orang (teknisi)** dan **shift kehadiran**. SPV perlu memverifikasi apakah Ryan, Raldy, atau Junifer sudah menerima beban kerja yang seimbang hari ini. Konsep A menempatkan teknisi sebagai filter cepat, namun menempatkan `posTag` sebagai identitas visual utama kartu.
2. **Efisiensi Ruang Layar Ponsel 360dp (Screen Real Estate):**
   Konsep B (pengelompokan pos bento) menambahkan terlalu banyak header grup yang memakan ruang vertikal jika dalam satu pos hanya ada 1 tugas. Konsep A jauh lebih hemat ruang (*compact*) sehingga mampu menampilkan 4 sampai 5 kartu tugas sekaligus pada layar 360dp tanpa terhalang header berulang.
3. **Kemudahan Integrasi Kode (Zero Regression):**
   Struktur data `DailyTaskService.tasksForBranch` pada dasarnya adalah flat list `List<DailyTaskModel>`. Konsep A tidak membutuhkan perubahan struktur data di backend atau model, sehingga Tukang Coder dapat mengimplementasikannya secara langsung tanpa risiko regresi logika transfer tugas maupun share laporan.

---

## 4. Matriks Token Desain yang Digunakan Ulang (Theme Tokens Reuse)

Tidak ada pembuatan palet warna baru sembarangan. Seluruh elemen memanfaatkan token resmi yang sudah didefinisikan dalam `lib/core/constants/app_colors.dart` dan sistem tema aplikasi:

```
MATRIKS TOKEN DESAIN RESMI (AppColors)
+-----------------------+-----------------------+-----------------------+
| Peran Desain          | Tema Terang (Light)   | Tema Gelap (Dark)     |
+-----------------------+-----------------------+-----------------------+
| Latar Belakang Layar  | AppColors.background  | AppColors.            |
|                       | (#FAF8F5 - Warm Bone) | darkBackground        |
|                       |                       | (#0B1120 - Obsidian)  |
+-----------------------+-----------------------+-----------------------+
| Permukaan Kartu Tugas | AppColors.surface     | AppColors.darkSurface |
|                       | (#FFFFFF - Pure White)| (#111827 - Slate Navy)|
+-----------------------+-----------------------+-----------------------+
| Garis Tepi (Borders)  | AppColors.cardBorder  | AppColors.darkBorder  |
|                       | (#E6E2D8 - Tactile)   | (#1E293B - Slate 800) |
+-----------------------+-----------------------+-----------------------+
| Brand Utama (AppBar)  | AppColors.primary     | AppColors.            |
|                       | (#1A428A - Royal Blue)| darkBackground        |
|                       |                       | (#0B1120 / #111827)   |
+-----------------------+-----------------------+-----------------------+
| Aksen Utama (Fokus)   | AppColors.accent      | AppColors.accent      |
|                       | (#FF6500 - Safety Org)| (#FF6500 - Safety Org)|
+-----------------------+-----------------------+-----------------------+
| Status Sukses / Done  | AppColors.success     | AppColors.success     |
|                       | (#059669 - Emerald)   | (#10B981 - Mint Emer) |
| Latar Sukses          | AppColors.successLight| #064E3B (Opacity 0.2) |
|                       | (#ECFDF5)             |                       |
+-----------------------+-----------------------+-----------------------+
| Status Pending / Wait | AppColors.warning     | AppColors.warning     |
|                       | (#FF8A00 - Amber Org) | (#F59E0B - Amber Glow)|
| Latar Pending         | AppColors.warningLight| #451A03 (Opacity 0.2) |
|                       | (#FFF7ED)             |                       |
+-----------------------+-----------------------+-----------------------+
| Anchor PosTag Badge   | Container Biru Navy   | Container Slate 800   |
|                       | Latar: #EFF6FF        | Latar: #1E293B        |
|                       | Teks: #1D4ED8 (Bold)  | Teks: #60A5FA (Bold)  |
+-----------------------+-----------------------+-----------------------+
| Tipografi Utama       | PlusJakartaSans Bold  | PlusJakartaSans Bold  |
| Tipografi Monospace   | JetBrains/System Mono | JetBrains/System Mono |
|                       | (Khusus Preview WA)   | (Khusus Preview WA)   |
+-----------------------+-----------------------+-----------------------+
| Radius Sudut          | AppColors.radiusCard  | AppColors.radiusCard  |
|                       | (16.0dp untuk kartu,  | (16.0dp untuk kartu,  |
|                       | 6.0dp untuk badge pos)| 6.0dp untuk badge pos)|
+-----------------------+-----------------------+-----------------------+
```

---

## 5. Pertanyaan Terbuka untuk Aan (Open Questions for Aan)

Seluruh elemen dalam konsep ini berakar kuat pada field data riil `DailyTaskModel` (`teknisiNama`, `posName`, `posTag`, `judul`, `deskripsi`, `status`, `jamSelesai`, `pesertaList`, `handover`). Tidak ada data fiktif yang dimasukkan ke dalam desain.

Berikut adalah daftar pertanyaan terbuka untuk Aan terkait potensi pengembangan logika data ke depan:

1. **Penanda Tingkat Urgensi / Prioritas Tugas:**
   Saat ini model `DailyTaskModel` hanya membedakan kategori `maintenance` dan `khusus`. Apakah Aan membutuhkan penanda tingkat urgensi (misalnya: `Darurat / P0` untuk gate macet total vs `Rutin / P1`) agar kartu darurat dapat diberi warna pembatas merah khusus?
2. **Estimasi Waktu Target Selesai (Target Jam Selesai):**
   Saat ini sistem hanya mencatat `jamSelesai` ketika tugas dirampungkan oleh teknisi. Apakah SPV memerlukan kolom input target jam selesai (misalnya: "Harus selesai sebelum jam 11:00 WITA") saat membagikan tugas?
3. **Validasi Geofence / Koordinat GPS Penyelesaian Tugas:**
   Model saat ini menyimpan teks `posTag` dan `posName`. Apakah saat teknisi menekan tombol selesai pada tugas tertentu, sistem perlu mencocokkan koordinat lokasi teknisi secara otomatis dengan radius pos parkir terkait?
4. **Sub-Checklist Sederhana pada Tugas Khusus:**
   Kategori `maintenance` sudah memiliki template checklist terstandarisasi (`templateId`), sedangkan `khusus` hanya memiliki satu baris judul dan deskripsi. Apakah untuk tugas khusus yang kompleks Aan ingin menambahkan checklist sub-task interaktif?
5. **Mode Tampilan Multi-Cabang untuk Supervisor Area / HO:**
   Logika saat ini memfilter tugas hanya untuk cabang aktif via `DailyTaskService.tasksForBranch`. Apakah ada peran SPV Area atau akun Head Office (HO) yang memerlukan filter lintas cabang (Manado, Bali, Balikpapan) dalam satu layar pantau tim?

---

*Spesifikasi konsep disusun oleh Tukang Design (Principal Product Designer & UI/UX Specialist) untuk Orca Multi-Agent Squad.*
