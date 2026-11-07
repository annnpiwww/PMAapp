# Laporan Audit Gabungan PMA App 2026-11-07

## Ringkasan
- Skor audit UI/UX: 69.2/100 (Cukup, butuh perbaikan flow lapangan dan kontras tampilan).
- Skor audit Kode dan Logika AI: 6.4/10 (Cukup, arsitektur offline bagus tapi pemetaan status AI dan shift malam bermasalah).
- Skor audit Keamanan: 38/100 (FAIL P0 Blocker, celah otentikasi Supabase dan pembatasan hak akses masih terbuka).
- Total temuan setelah digabung dan dibersihkan dari duplikasi: 44 temuan unik (9 P0, 20 P1, 11 P2, 4 P3).
- 8 temuan warisan audit lama (SEC-KNOWN-01 s/d 09) masih berstatus open di server Supabase dan kode aplikasi.
- Bahaya 1: Siapa saja di internet bisa login jadi siapa saja hanya dengan mengetik tanda bintang `*` di layar login, lalu bisa ubah peran jadi Supervisor di browser, serta bisa memakai kuota Google Gemini kantor secara gratis tanpa batas.
- Bahaya 2: Riwayat absensi seluruh cabang (Manado, Bali, HO) bisa terhapus total tanpa sengaja hanya karena teknisi menekan tombol hapus saat melihat riwayat satu cabang.
- Bahaya 3: AI kamera terlalu gampang memvonis MERAH atau temuan palsu pada foto perawatan dan absensi karena foto diperkecil terlalu buram (420px), AI tidak paham kata sanggahan ("tidak ada debu" dianggap kotor), dan foto yang gagal koneksi otomatis dicatat sebagai kerusakan fisik di peta SPV.

## Prioritas Perbaikan

| No | Prioritas | Area | Masalah | Dampak ke teknisi/SPV | Lokasi file:line | Perbaikan singkat | Tukang | Effort | Sumber ID |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | P0 | Keamanan | Login Supabase membolehkan karakter bebas dan bocorkan password teks biasa | Siapa saja bisa login ke akun teknisi lain hanya dengan mengetik tanda bintang atau kutip | `lib/data/repositories/auth_repository.dart:26-48, 61` | Bersihkan input nama, pakai fungsi login aman di server tanpa kirim password ke HP | coder | M | SEC-01 |
| 2 | P0 | Keamanan | Fungsi server pos-locations menerima data tanpa cek login Supervisor | Siapa saja dari luar bisa mengubah titik koordinat pos parkir resmi cabang | `supabase/functions/pos-locations/index.ts:150-186, 273-317` | Tambahkan validasi akun Supervisor sebelum server mau menerima data import pos | coder | S | SEC-02 |
| 3 | P0 | Keamanan | Server AI Vision bisa dipakai publik tanpa login dan kunci API cadangan bocor di web | Kuota Gemini kantor bisa disedot pihak luar hingga habis dan teknisi gagal verifikasi foto | `supabase/functions/ai-vision/index.ts:20, 50-118`, `lib/data/models/ai_vision_config.dart:115-118`, `lib/data/services/ai_vision_service.dart:663-700` | Pasang token rahasia di fungsi server AI dan hapus kunci API cadangan dari aplikasi HP | coder | M | SEC-03, SEC-KNOWN-06, CODE-10 |
| 4 | P0 | Keamanan | Peran teknisi atau Supervisor hanya diperiksa di memori HP | Teknisi bisa menyamar jadi Supervisor dengan mudah lewat menu browser untuk buka semua menu rahasia | `lib/data/repositories/auth_repository.dart:90-92, 310-335`, `lib/data/services/storage_service.dart:16, 193-206` | Gunakan token resmi Supabase yang diverifikasi ke server tiap kali aplikasi dibuka | coder | M | SEC-04 |
| 5 | P0 | Keamanan | Hapus tugas selesai dan transfer tugas hanya dicegah di tampilan layar HP | Siapa saja yang tahu link server bisa menghapus tugas selesai atau memalsukan bukti kerja teknisi lain | `lib/data/services/daily_task_service.dart:165-177, 625-676, 793-806, 832-845` | Kunci izin tabel di server Supabase agar tugas yang sudah selesai tidak bisa dihapus siapapun | coder | M | SEC-05 |
| 6 | P0 | Data | Hapus riwayat absen di satu cabang menghapus riwayat seluruh cabang | Saat menghapus 2 catatan di Bali, seluruh riwayat absen di Manado dan HO ikut lenyap permanen | `lib/features/history/screens/attendance_archive_screen.dart:141, 167-227` | Ubah fungsi hapus agar hanya membuang catatan absen milik cabang yang sedang dilihat | coder | S | UI-01 |
| 7 | P0 | UI | Ekspor riwayat absen ke file CSV selalu macet dan mental di iPhone Safari | Pengguna iPhone tidak bisa ekspor laporan absensi ke format Excel atau CSV | `lib/features/history/screens/attendance_archive_screen.dart:1, 120-135, 677` | Berikan pemisah kode khusus web agar ekspor CSV memakai unduhan browser | ui | S | UI-02 |
| 8 | P0 | Data | Antrean kirim Google Sheets macet dan kirim data ganda terus menerus | Laporan perawatan terduplikasi berkali-kali di Google Sheets dan kolom laporan hilang separuh saat offline | `lib/data/services/google_sheets_service.dart:156, 168, 176-200, 238, 246` | Anggap respon pengalihan 302 dari Google sebagai sukses dan simpan semua kolom saat offline | coder | S | CODE-01 |
| 9 | P0 | Kode | Teknisi yang mengunci HP lebih dari 5 menit dicap jam diubah manual | Teknisi jujur dituduh berbuat curang di watermark foto karena jam jeda HP tidur dianggap manipulasi | `lib/data/services/secure_time_service.dart:105-120, 129-134` | Hitung ulang patokan waktu dari jam server saat HP bangun dan hilangkan cap permanen | coder | S | CODE-02 |
| 10 | P1 | Keamanan | Teknisi bisa ubah jam HP saat offline dan koordinat pos dipakai otomatis saat GPS mati | Bukti foto absensi bisa dimajukan atau dimundurkan dan teknisi bisa absen di luar lokasi pos | `lib/data/services/secure_time_service.dart:30-34, 150-164`, `lib/data/services/location_service.dart:1582-1605`, `lib/features/camera/screens/camera_capture_screen.dart:1258-1294` | Simpan patokan jam server terakhir dan cap tanda merah jika GPS tidak mengunci atau pakai lokasi palsu | coder | M | SEC-06 |
| 11 | P1 | Keamanan | Link Google Sheets tidak dikunci sandi dan rentan formula berbahaya | Orang luar bisa mengirim data palsu ke Google Sheets kantor atau menyisipkan kode formula | `lib/data/services/google_sheets_service.dart:18-28, 130-165`, `lib/features/history/screens/attendance_archive_screen.dart:109-118` | Pasang token rahasia pada webhook Google Sheets dan netralkan karakter awal formula | coder | S | SEC-08 |
| 12 | P1 | AI | Foto yang ragu atau gagal sinyal otomatis jadi temuan rusak di peta SPV | Titik pos berubah jadi warna oranye ada temuan padahal alat aslinya dalam kondisi normal | `lib/data/services/maintenance_log_service.dart:126-138`, `lib/features/maintenance/screens/point_camera_view.dart:44-55, 669-689` | Pisahkan status perlu cek manual dari status temuan rusak di peta dan Google Sheets | coder | S | CODE-03 |
| 13 | P1 | AI | Tulisan error koneksi AI masuk ke ringkasan laporan WhatsApp | Pesan WhatsApp resmi ke grup kantor menampilkan error sistem sebagai kerusakan fisik pos | `lib/data/services/whatsapp_report_service.dart:319-327, 465-472, 1297-1299` | Saring teks kegagalan koneksi agar tidak dijadikan poin laporan kerusakan pos | coder | S | CODE-04 |
| 14 | P1 | AI | Kata sanggahan tidak ada debu dibaca AI sebagai perangkat kotor | Foto yang bersih divonis MERAH tidak sesuai hanya karena kalimat AI memuat kata kotor | `lib/data/services/ai_vision_service.dart:118-161, 1030-1046` | Perbaiki pembaca teks agar mengabaikan kata kotor jika didahului kata tidak ada atau bebas | coder | S | CODE-05 |
| 15 | P1 | AI | Status sesuai tidak ada masalah dipaksa jadi MERAH karena ada kata tidak | Laporan yang lolos pemeriksaan diputarbalikkan menjadi gagal oleh pemotong status | `lib/data/services/ai_vision_service.dart:996-1010` | Cek kata utuh sesuai terlebih dahulu sebelum memeriksa kata tidak sesuai | coder | S | CODE-06 |
| 16 | P1 | AI | Ukuran foto untuk AI terlalu kecil dan buram (hanya 420px kualitas 50) | Tulisan layar monitor dan kabel kecil pecah sehingga AI sering vonis foto buram | `lib/core/utils/image_watermark_processor.dart:74-75, 87, 133` | Naikkan ukuran foto untuk AI ke lebar 864px kualitas 72 sesuai standar sistem | coder | S | CODE-07 |
| 17 | P1 | AI | Syarat periksa pasta prosesor dan baut aspal bertentangan dengan petunjuk AI | Teknisi disuruh foto pasta prosesor padahal kipas heatsink terpasang di komputer kasir | `lib/data/services/ai_vision_service.dart:802, 891, 900, 923`, `lib/features/maintenance/screens/maintenance_checklist_screen.dart:498, 672-686` | Samakan teks instruksi pemeriksaan dengan petunjuk AI agar tidak menuntut bongkar heatsink | coder | S | CODE-08 |
| 18 | P1 | AI | Teks darurat AI menganggap kalimat tidak blur sebagai foto buram | Verifikasi darurat memvonis MERAH pada foto yang jelas dan terang | `lib/data/services/ai_vision_service.dart:1077-1202` | Jangan vonis MERAH jika ada kata not blurry atau tidak gelap pada teks darurat | coder | M | CODE-09 |
| 19 | P1 | AI | Potongan alasan AI kurang dari 10 huruf dilewati sehingga artinya terbalik | Alasan Aman dilewati dan sistem malah mengambil potongan kalimat kekurangan kecil | `lib/data/services/ai_vision_service.dart:219-235`, `lib/features/maintenance/screens/maintenance_checklist_screen.dart:1185-1241` | Turunkan batas minimal kalimat jadi 4 huruf dan bersihkan kata sanggahan di kartu deteksi | coder | S | CODE-11 |
| 20 | P1 | AI | Laporan stiker barrier gate tertukar dengan penutup sensor anti air | Laporan WhatsApp barrier gate menampilkan nama komponen yang salah urutan | `lib/data/services/whatsapp_report_service.dart:233-236, 1117, 1662`, `lib/features/maintenance/screens/maintenance_checklist_screen.dart:448-501` | Perbaiki kata kunci saringan stiker receiver dan samakan nomor titik cadangan | coder | M | CODE-12 |
| 21 | P1 | Kode | Jam absen pulang dan status telat salah hitung untuk shift lewat tengah malam | Teknisi shift malam tidak bisa absen pulang tepat waktu dan catatan telat di arsip kacau | `lib/data/services/absensi_setup_service.dart:199-220`, `lib/features/history/screens/attendance_archive_screen.dart:322-350` | Tambahkan penanganan pergantian hari pada jadwal shift malam (22.00-06.00 dan 24.00-08.00) | coder | M | CODE-13 |
| 22 | P1 | Kode | Pemeriksaan pakaian dinas hari Minggu bisa diakali dengan ganti tanggal HP | Teknisi bisa bebas pakaian di hari kerja biasa dengan memajukan jam HP ke hari Minggu | `lib/data/services/absensi_setup_service.dart:340-351`, `lib/features/camera/screens/camera_capture_screen.dart:1400` | Gunakan jam hasil verifikasi server untuk menentukan hari kerja, bukan jam bawaan HP | coder | S | CODE-14 |
| 23 | P1 | Kode | Tugas harian teknisi tertukar karena sistem hanya mencocokkan 3 huruf nama | Teknisi menerima notifikasi tugas milik orang lain dan dua teknisi bisa saling timpa klaim tugas | `lib/data/services/daily_task_service.dart:209-224, 765-828` | Samakan nama lengkap secara utuh dan kunci status tugas sebelum klaim disetujui server | coder | M | CODE-15 |
| 24 | P1 | UI | Pemulihan draf tugas harian di web iPhone gagal dan catatan terhapus | Teknisi yang mengisi laporan di web iPhone kehilangan seluruh ketikan jika halaman tertutup | `lib/features/daily_tasks/screens/custom_task_execution_screen.dart:2, 67, 75, 89, 100` | Pastikan pengecekan file lokal aman untuk browser web sebelum catatan dipulihkan | ui | S | UI-03 |
| 25 | P1 | UI | Bukti tugas yang hanya berupa rekaman video tidak muncul di detail SPV | SPV mengira teknisi tidak kirim bukti kerja padahal teknisi melampirkan video pengujian | `lib/features/daily_tasks/widgets/completed_daily_task_modal.dart:365, 398`, `lib/features/daily_tasks/widgets/spv_task_card.dart:445` | Tampilkan pemutar video atau tombol buka video pada kartu tugas yang sudah selesai | ui | M | UI-04 |
| 26 | P1 | UI | Tombol menu galeri foto di tema terang tidak terlihat sama sekali | Tombol Pilih dan ikon folder warnanya sama persis dengan warna latar belakang atas | `lib/features/history/screens/gallery_screen.dart:238, 260-264, 271, 283-292` | Ganti warna tombol atas galeri menjadi putih terang agar terbaca jelas oleh mata | ui | S | UI-05 |
| 27 | P1 | UI | Tulisan riwayat perawatan kosong di tema gelap tidak terbaca | Layar riwayat terlihat seperti layar mati gelap gulita saat draf masih kosong | `lib/features/maintenance/screens/maintenance_history_screen.dart:66-90, 283-305` | Ubah warna tulisan pesan kosong menjadi putih terang saat mode gelap aktif | ui | S | UI-06 |
| 28 | P1 | UI | Pilihan shift kantor HO Makassar ada yang kembar dan salah nama | Teknisi HO bingung memilih jadwal shift dan sistem otomatis melempar ke shift manual | `lib/features/templates/widgets/absensi_kategori_dialog.dart:165-193, 221-225` | Samakan daftar kartu shift HO dengan data cabang resmi (RSWS 1, RSWS 2, JP 1, JP 2) | ui | S | UI-07 |
| 29 | P1 | UI | Teknisi dipaksa mengisi laporan serah terima pulang sebanyak dua kali | Setelah selesai isi form pulang di dialog shift, teknisi ditagih lagi lembar yang sama di kamera | `lib/features/templates/widgets/absensi_kategori_dialog.dart:456-478, 1426-1704`, `lib/features/camera/screens/camera_capture_screen.dart:1030` | Hapus form kembar di dialog shift dan pusatkan pengisian form pulang lewat lembar kamera | ui | M | UI-08 |
| 30 | P1 | UI | Jendela selesai tugas dengan foto dan video terkunci dan tombol berdesakan | Teknisi tidak bisa langsung kembali ke daftar tugas setelah membagikan bukti ke WhatsApp | `lib/features/daily_tasks/screens/custom_task_execution_screen.dart:385-433` | Susun tombol bagi bukti secara menurun dan tutup jendela otomatis setelah dibagikan | ui | S | UI-09 |
| 31 | P1 | UI | Pesan error teknis bahasa Inggris muncul langsung di layar teknisi | Teknisi bingung melihat tulisan error kode program yang rumit saat kamera atau file gagal | `lib/features/maintenance/screens/point_camera_view.dart:182, 798`, `lib/features/daily_tasks/screens/custom_task_execution_screen.dart:151` | Ganti tulisan error teknis dengan petunjuk ramah bahasa Indonesia yang mudah dipahami | ui | S | UI-10 |
| 32 | P2 | Keamanan | Browser web menyimpan file aset lama selama 1 tahun tanpa pembaruan | SPV yang membuka web bisa melihat tampilan lama yang rusak setelah rilis versi baru | `vercel.json:26-33`, `web/index.html:65-82` | Atur ulang pengaturan simpan web agar browser selalu mengecek versi file terbaru | coder | S | SEC-07 |
| 33 | P2 | Keamanan | Karakter persen pada pencarian nama teknisi bisa memanggil semua data | Pencarian teknisi di server bisa bocor atau menampilkan data tugas yang tidak sesuai | `lib/data/services/daily_task_service.dart:237-248, 1163-1166` | Bersihkan karakter tanda persen dan nama file sebelum dikirimkan ke server | coder | S | SEC-09 |
| 34 | P2 | Keamanan | Foto absen tersimpan selamanya di galeri umum HP dan memori browser 30 hari | Foto teknisi berserakan di galeri foto HP dan data wajah tersimpan lama di browser bersama | `lib/data/services/photo_cleanup_service.dart:7-53`, `lib/features/camera/screens/camera_capture_screen.dart:1624-1628` | Hapus foto dari memori web saat logout dan batasi penyimpanan galeri sesuai izin pengguna | coder | S | SEC-10 |
| 35 | P2 | Kode | Laporan perawatan malam terbagi dua tanggal berbeda di server | Laporan yang dimulai jam 23.45 dan selesai jam 00.20 urutan jamnya kacau di peta SPV | `lib/data/services/maintenance_log_service.dart:151-159, 412-427` | Ambil tanggal dan jam laporan murni dari waktu selesai pengerjaan perawatan | coder | S | CODE-16 |
| 36 | P2 | Kode | Buka layar utama membaca ulang ratusan data absen yang membebani HP | Aplikasi terasa patah patah atau lambat merespon saat teknisi membuka menu utama | `lib/data/services/storage_service.dart:69-161, 249-260` | Simpan data absen di memori sementara agar tidak perlu bongkar pasang data tiap detik | coder | S | CODE-17 |
| 37 | P2 | Kode | Tiap kali ambil foto titik perawatan, ribuan data disimpan ulang ke HP | Jeda waktu setelah memotret terasa berat karena HP memproses ulang seluruh titik pos | `lib/features/maintenance/screens/maintenance_checklist_screen.dart:865-875`, `lib/data/services/storage_service.dart:495-535` | Simpan draf perawatan secara efisien tanpa harus menyusun ulang data lama | coder | S | CODE-18 |
| 38 | P2 | UI | Tulisan tugas harian terpotong di HP Android layar kecil dengan huruf besar | Nama pos yang panjang dan jumlah foto terpotong ke samping kanan layar | `lib/features/daily_tasks/screens/custom_task_execution_screen.dart:566-625` | Bungkus tulisan nama pos dan jumlah foto agar bisa turun ke baris bawah dengan rapi | ui | S | UI-11 |
| 39 | P2 | UI | Tulisan status Terlambat dan lencana AI terpotong di riwayat kerja | Informasi riwayat absensi menabrak tepi layar pada HP dengan pengaturan font besar | `lib/features/history/screens/attendance_archive_screen.dart:804-815, 865-959` | Atur lencana status riwayat agar fleksibel menyesuaikan lebar layar HP | ui | S | UI-12 |
| 40 | P2 | UI | Tanggal album foto di galeri menabrak jumlah foto di layar kecil | Tulisan hari dan tanggal panjang bertumpuk dengan kotak info jumlah foto | `lib/features/history/screens/gallery_screen.dart:500-528` | Berikan ruang lentur pada teks tanggal agar otomatis memendek jika ruang sempit | ui | S | UI-13 |
| 41 | P2 | UI | Tombol jalan pintas shift di kamera terlalu kecil dan susah dipencet jempol | Teknisi kesulitan memencet tombol ganti shift di pojok kamera saat tangan satu memegang alat | `lib/features/camera/screens/camera_capture_screen.dart:2896-2951` | Perbesar area sentuh tombol menjadi minimal 44x44 titik dan perjelas ukuran tulisan | ui | S | UI-14 |
| 42 | P2 | UI | Tombol lampu kilat dan tombol kembali di kamera perawatan terlalu sempit | Teknisi sering salah memencet tombol senter di ruang server yang gelap | `lib/features/maintenance/screens/point_camera_view.dart:827-996` | Lebarkan area sentuh tombol atas kamera perawatan agar mudah ditekan jari teknisi | ui | M | UI-15 |
| 43 | P2 | UI | Layar peta perawatan tetap silau putih saat aplikasi diatur ke tema gelap | SPV yang memeriksa peta di malam hari silau karena peta belum mendukung tema gelap | `lib/features/maintenance/screens/maintenance_map_screen.dart:15-39, 698`, `lib/features/maintenance/screens/maintenance_location_detail_screen.dart:183` | Sesuaikan palet warna kartu dan panel peta dengan pengaturan tema gelap aplikasi | ui | M | UI-16 |
| 44 | P2 | UI | Judul perawatan di bagian atas terpotong menjadi tulisan tidak jelas | Teknisi tidak bisa membaca area pos mana yang sedang dikerjakan dari baris judul | `lib/features/maintenance/screens/maintenance_checklist_screen.dart:1645-1695` | Buang kata awalan yang tidak penting agar nama pos utama muat dibaca seutuhnya | ui | S | UI-17 |

## Kenapa AI Sering Kasih Temuan Palsu
- Foto yang dikirim ke AI diperkecil terlalu ekstrem menjadi lebar 420px dengan kompresi kasar (kualitas 50), padahal standar sistem adalah 864px kualitas 72. Akibatnya teks layar monitor terminal kasir, lampu indikator loop detector, angka LCD avometer, dan tali ID card menjadi buram berpiksel dan divonis bermasalah oleh AI.
- Pemroses respon AI buta terhadap kata sanggahan. Kalimat AI seperti "tidak ada debu atau kotoran" langsung dibaca sebagai "perangkat tampak kotor atau berdebu" hanya karena menemukan kata "kotor", lalu membalik status lolos menjadi vonis MERAH.
- Pengecekan teks status awal mendahulukan kata "tidak" sebelum kata "sesuai". Kalimat AI yang menyatakan "status: sesuai (tidak ada masalah)" dipaksa berubah menjadi gagal karena sistem membaca kata "tidak" terlebih dahulu.
- Sistem menganggap semua foto yang ragu-ragu, terkena pantulan cahaya, atau gagal koneksi internet (timeout) sebagai temuan kerusakan fisik di peta SPV dan laporan Google Sheets, padahal teknisi hanya terkendala sinyal atau silau lampu pos.
- Instruksi pemeriksaan SOP di aplikasi menuntut teknisi membongkar kipas pendingin untuk memperlihatkan pasta prosesor, padahal aturan internal AI melarang menuntut pasta prosesor terlihat pada komputer kasir yang sedang aktif beroperasi.
- Mode pemeriksaan otomatis darurat langsung mencap foto buram dan gagal jika kalimat AI dalam bahasa Inggris memuat kata "not blurry" (tidak buram), karena sistem hanya mencari kata "blurry" tanpa melihat kata sanggah di depannya.
- Terdapat 12 kasus contoh nyata (repro cases) yang membuktikan kegagalan logika ini dapat dipicu secara berulang pada kondisi operasional sehari-hari.

## Optimasi: Perlu atau Tidak

| Item Optimasi | Keputusan | Alasan |
| :--- | :--- | :--- |
| 1. Antrean gagal kirim tugas diunggah bergantian satu per satu | Tidak perlu | Antrean offline jarang melebihi 3 tugas dan upload bergantian mencegah jaringan seluler macet di basement |
| 2. Pengecekan tugas ganda saat offline dikirim bergantian satu per satu | Tidak perlu | Jumlah antrean sedikit (1 sampai 5 tugas) dan jeda berhenti saat sinyal putus mencegah beban berlebih di server |
| 3. Antrean kirim Google Sheets dikirim berulang tanpa jeda henti | Optimise now | Jika terjadi kendala koneksi puluhan baris antrean bisa menahan aplikasi hingga berlipat lipat 12 detik |
| 4. Dua tugas rutin pagi SPV dibuat secara bergantian | Tidak perlu | Hanya terjadi sekali dalam sehari secara manual oleh SPV dan selisih waktu sangat kecil (sekitar 0.15 detik) |
| 5. Unduh seluruh data pos parkir dari 3 cabang sekaligus saat awal | Tidak perlu | Total data sangat kecil (hanya 45 baris atau 12 KB) dan disimpan agar SPV bisa ganti cabang tanpa loading ulang |
| 6. Unduh seluruh data teknisi dari 3 cabang sekaligus saat awal | Tidak perlu | Total data sangat ringkas (hanya 16 baris atau 2 KB) dan dibutuhkan saat login untuk menentukan cabang akun |
| 7. Server fungsi pos-locations menolak penyimpanan cache peramban | Tidak perlu | Jalur server ini hanya dipakai untuk mengubah data bukan untuk membaca data berulang ulang |
| 8. Unduh data pos dan teknisi berjalan tiap kali aplikasi dibuka | Tidak perlu | Berjalan di latar belakang tanpa menahan layar pembuka sehingga daftar teknisi selalu yang paling baru |
| 9. Penyusunan ulang data absen dan draf perawatan berulang di memori HP | Optimise now | Membaca ulang 150 data absen berulang kali saat tombol dipencet membuat layar patah patah di HP kelas menengah |
| 10. Daftar tugas harian teknisi memuat seluruh baris kartu sekaligus | Tidak perlu | Tugas per teknisi hanya berkisar 2 sampai 8 tugas per hari sehingga penghematan memori hampir tidak terasa |
| 11. Daftar monitoring SPV memuat seluruh kartu tugas sekaligus | Tidak perlu | Jumlah tugas per cabang jarang melebihi 25 kartu dan gambar foto bukti sudah dibatasi ukurannya di memori |
| 12. Pemuatan foto bukti tugas SPV memakai resolusi asli tanpa batas memori | Optimise now | Membatasi ukuran gambar foto bukti dari server menghemat penggunaan memori RAM HP hingga 75 persen |

## Butuh Keputusan Aan

1. **Status Perlu Cek Manual di Peta dan Laporan Perawatan (CODE-03)**
   - Saat foto terkena silau lampu, buram sedikit, atau sinyal internet putus, sistem memberi status "Perlu Cek Manual". Apakah titik pos di peta SPV harus tetap berubah jadi warna oranye (Ada Temuan), atau tetap hijau (Aman) dengan tanda khusus di detailnya saja?
   - Pilihan A (Disarankan): Titik pos tetap hijau (Aman), dan status perlu cek manual hanya dicatat sebagai pengingat untuk diperiksa mata telanjang oleh SPV, bukan dianggap alat rusak.
   - Pilihan B: Titik pos tetap jadi oranye jika AI menilai foto kurang jelas, tetapi jika penyebabnya murni sinyal putus atau mode kilat maka titik pos tetap hijau.

2. **Pengisian Laporan Serah Terima Pulang Ganda (UI-08)**
   - Saat ini teknisi yang memilih absen Pulang diminta mengisi form serah terima di menu shift, lalu saat menekan tombol kamera diminta lagi mengisi lembar serah terima kedua.
   - Pilihan A (Disarankan): Hapus form serah terima di menu shift, jadikan satu pintu pengisian serah terima hanya lewat lembar geser di kamera yang sudah otomatis merangkum tugas harian teknisi.
   - Pilihan B: Pertahankan keduanya dan hubungkan data ketikannya agar teknisi tidak perlu mengetik ulang dua kali.

3. **Batasan Tombol Hapus Riwayat Absensi di HP (UI-01)**
   - Tombol tempat sampah merah di riwayat kerja saat ini menghapus seluruh rekaman absen di HP tanpa pandang cabang.
   - Pilihan A (Disarankan): Tombol hapus hanya membuang riwayat milik cabang yang sedang aktif dipilih di layar.
   - Pilihan B: Tombol hapus riwayat dikunci total dan hanya bisa diakses oleh akun Supervisor setelah memasukkan kata sandi.

4. **Kunci Absen Pulang Jika Teknisi Telat Parah Melewati Jam Pulang (CODE-13)**
   - Jika teknisi shift 1 (06.00-14.00) baru sempat absen masuk jam 14.05 karena lupa, sistem saat ini mengunci tombol absen pulang selama 8 jam ke depan (baru bisa pulang jam 22.05).
   - Pilihan A (Disarankan): Izinkan teknisi yang telat masuk untuk langsung absen pulang saat jam pergantian shift tiba tanpa harus menunggu 8 jam.
   - Pilihan B: Berikan batas waktu kerja minimal (misalnya wajib menunggu minimal 4 jam) sebelum tombol absen pulang terbuka.

5. **Kewajiban Periksa Pasta Prosesor Kasir dan Server (CODE-08)**
   - Di SOP checklist tertulis wajib periksa pasta pendingin prosesor baru dioleskan, sementara di panduan AI tertulis teknisi tidak boleh disuruh membongkar heatsink komputer kasir yang aktif.
   - Pilihan A (Disarankan): Ubah poin SOP menjadi "Pembersihan kipas dan heatsink dari debu", tanpa menuntut pasta prosesor terlihat di foto.
   - Pilihan B: Tetap wajib periksa pasta prosesor hanya saat jadwal perawatan tahunan besar.

6. **Penyimpanan Password Teknisi dan Supervisor di Kode Aplikasi (SEC-01, SEC-KNOWN-02)**
   - Saat ini terdapat 59 akun dan password bawaan yang tertanam di kode program untuk keperluan darurat saat mati lampu total.
   - Pilihan A (Disarankan): Hapus akun tertanam pada versi web peramban, dan di versi HP Android batasi login darurat hanya untuk akun yang sudah pernah berhasil login online sebelumnya di HP tersebut.
   - Pilihan B: Pertahankan login darurat dengan password sementara yang diacak dan diperbarui berkala dari server.

7. **Tindakan Jika Sinyal GPS Mati di Basement atau Terdeteksi Lokasi Palsu (SEC-06)**
   - Saat GPS tidak mengunci di dalam gedung parkir, aplikasi otomatis memasukkan titik koordinat pos resmi, atau jika aplikasi lokasi palsu menyala teknisi tetap bisa lanjut memotret.
   - Pilihan A (Disarankan): Jangan pernah memalsukan koordinat pos ke foto; jika GPS mati atau terdeteksi lokasi palsu, tempelkan tulisan merah besar "GPS TIDAK MENGUNCI" atau "LOKASI PALSU TERDETEKSI" langsung di atas foto bukti.
   - Pilihan B: Kunci total tombol jepret kamera jika GPS mati atau terdeteksi aplikasi lokasi palsu sampai teknisi berpindah ke area ber-GPS.

8. **Penyimpanan Otomatis Foto ke Galeri Umum HP Android (SEC-10)**
   - Setiap kali teknisi mengambil foto absen, foto wajah dan data pribadi teknisi otomatis tersimpan ke galeri umum HP di album BSS Parking dan tidak pernah dihapus otomatis.
   - Pilihan A (Disarankan): Foto hanya disimpan di dalam memori internal aplikasi yang otomatis dibersihkan setiap 7 hari setelah berhasil dibagikan ke WhatsApp kantor.
   - Pilihan B: Tetap simpan di galeri foto umum HP agar teknisi memiliki arsip pribadi foto kerjanya.

## Usulan Urutan Kerja

- **Batch 1: Keamanan Kritis dan Penyelamatan Data (P0 Blocker)**
  - Pekerjaan: Kunci celah filter login Supabase, pasang pengaman pada fungsi server pos-locations dan AI Vision, batasi penghapusan riwayat absen per cabang, perbaiki ekspor CSV iPhone web, perbaiki antrean kirim Google Sheets, dan atasi cap palsu jam HP di SecureTimeService.
  - Sasaran temuan: SEC-01, SEC-02, SEC-03, SEC-04, SEC-05, UI-01, UI-02, CODE-01, CODE-02.
  - Tukang: coder dan ui.
- **Batch 2: Perbaikan Logika AI dan Anti Manipulasi Jam (P1 Fungsional Utama)**
  - Pekerjaan: Perbaiki pembacaan kata sanggahan pada respon AI, naikkan resolusi foto AI ke 864px, selaraskan syarat SOP pasta prosesor kasir, hilangkan tulisan error teknis di WhatsApp, serta perbaiki logika shift malam dan klaim tugas harian.
  - Sasaran temuan: CODE-03, CODE-04, CODE-05, CODE-06, CODE-07, CODE-08, CODE-09, CODE-11, CODE-12, CODE-13, CODE-14, CODE-15, SEC-06, SEC-08.
  - Tukang: coder dan sec.
- **Batch 3: Perbaikan Tampilan Lapangan dan Alur Kerja Teknisi (P1 UI/UX)**
  - Pekerjaan: Perbaiki kontras tombol atas galeri dan teks riwayat kosong, pulihkan draf kerja di web iPhone, tampilkan bukti video tugas di modal SPV, rapikan nama shift HO Makassar, hilangkan form serah terima ganda, dan ganti pesan error teknis menjadi bahasa Indonesia ramah.
  - Sasaran temuan: UI-03, UI-04, UI-05, UI-06, UI-07, UI-08, UI-09, UI-10.
  - Tukang: ui.
- **Batch 4: Kenyamanan Ukuran Layar Kecil dan Optimasi Memori (P2 dan P3)**
  - Pekerjaan: Cegah teks terpotong pada HP huruf besar, lebarkan tombol senter dan tombol kembali kamera ke 44x44 titik, pasang tema gelap pada peta perawatan, optimalkan penyimpanan data absen di memori HP, dan batasi ukuran foto bukti tugas SPV.
  - Sasaran temuan: UI-11, UI-12, UI-13, UI-14, UI-15, UI-16, UI-17, CODE-16, CODE-17, CODE-18, SEC-07, SEC-09, SEC-10, serta pembersihan token P3.
  - Tukang: ui dan coder.

## Tidak Dicek
- Pengujian hapus data langsung di database server Supabase dan Google Sheets asli sengaja tidak dijalankan untuk menjaga keutuhan data produksi kantor.
- Kamera fisik dan sensor satelit GPS asli diuji lewat simulasi logika kode program karena pengujian dijalankan di lingkungan komputer server tanpa perangkat fisik Android di tangan.
- Aliran panggilan video asli dan batas waktu koneksi langsung internet pihak ketiga diaudit berdasarkan penanganan kode aplikasi tanpa membebani biaya panggilan API berbayar.
- Pengujian rekaman video web khusus peramban Safari iOS diaudit berdasarkan jalur kode program web tanpa menggunakan unit fisik iPhone langsung di meja pengujian.
