# Status Perbaikan Audit PMA App 2026-11-07

## Ringkasan
- Total 44 temuan audit telah dipetakan: 28 temuan sudah selesai diperbaiki dan diverifikasi, sedangkan 16 temuan belum dikerjakan (3 temuan celah server menunggu keputusan migrasi Supabase Auth, 13 temuan P1/P2/P3 belum dijadwalkan).
- Seluruh 8 poin arahan keputusan Aan telah diterapkan penuh ke dalam kode aplikasi.
- Status pengujian otomatis terakhir: 615 tes lulus (passed), 6 dilewati (skipped), 0 gagal (failed) di seluruh suite pengujian Flutter.
- Pemeriksaan ulang keamanan berstatus RELEASE_OK: tidak ada celah keamanan baru atau penurunan kualitas kode pada seluruh perubahan.
- Seluruh perubahan kode saat ini telah teruji di repositori lokal dan siap dikomit serta dirilis sebagai versi 2.0.133 setelah persetujuan Aan.

## Sudah Dibenerin

| No | ID | Masalah (Bahasa Awam) | Yang Diubah | Bukti Verifikasi |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `SEC-01` | Siapa saja bisa login ke akun orang lain dengan mengetik tanda bintang atau kutip di layar login | Input login dibersihkan dengan aturan karakter ketat, filter pencarian akun diubah ke perbandingan persis, dan 59 akun serta password bawaan dihapus | `test/auth_repository_test.dart` (7/7 passed) |
| 2 | `SEC-02` | Fungsi server `pos-locations` menerima perubahan koordinat pos tanpa cek login Supervisor | Fungsi server kini mewajibkan verifikasi akun Supervisor sebelum menerima data impor dan sudah aktif di-deploy | Live probe server mengembalikan respon HTTP 401 Unauthorized |
| 3 | `UI-01` | Menekan tombol hapus riwayat absen di satu cabang ikut menghapus riwayat seluruh cabang | Fungsi hapus diubah agar hanya menghapus data riwayat milik cabang yang sedang dibuka di layar | `test/attendance_archive_screen_test.dart` (4/4 passed) |
| 4 | `UI-02` | Tombol ekspor riwayat absen ke file Excel atau CSV macet di iPhone Safari | Ditambahkan jalur unduhan khusus web browser sehingga ekspor CSV berjalan lancar di Safari | `test/attendance_archive_screen_test.dart` (4/4 passed) |
| 5 | `CODE-01` | Laporan perawatan ke Google Sheets terduplikasi berulang kali saat sinyal putus nyambung | Respon pengalihan HTTP 302 dari Google kini dianggap sukses dan seluruh 19 kolom laporan tersimpan utuh saat offline | `test/round2_fixes_test.dart` |
| 6 | `CODE-02` | Teknisi dituduh curang jam HP diubah manual hanya karena mengunci layar lebih dari 5 menit | Patokan jam dihitung ulang dari server saat aplikasi aktif kembali dan tanda tuduhan curang otomatis hilang jika jam normal | `test/round2_fixes_test.dart` |
| 7 | `SEC-06` | Jam absen bisa dimajukan saat offline dan koordinat pos resmi dipakai otomatis saat GPS mati | Tombol jepret absen dikunci jika GPS belum mengunci atau pakai lokasi palsu, serta tidak lagi memalsukan koordinat pos | `test/round2_fixes_test.dart` |
| 8 | `CODE-03` | Foto yang buram sedikit atau gagal sinyal otomatis membuat pos jadi warna oranye di peta SPV | Status perlu cek manual kini dipisahkan dari temuan rusak sehingga pos tetap berwarna hijau aman | `test/round2_fixes_test.dart` |
| 9 | `CODE-04` | Pesan error koneksi AI masuk ke dalam pesan ringkasan laporan WhatsApp kantor | Teks kegagalan teknis disaring agar tidak dimasukkan ke dalam daftar kerusakan fisik pos | `test/whatsapp_report_test.dart` |
| 10 | `CODE-05` | Kalimat AI tidak ada debu dibaca sistem sebagai perangkat kotor dan divonis rusak | Ditambahkan aturan pembaca teks agar mengabaikan kata kotor jika didahului kata tidak ada atau bebas | `test/ai_false_positive_test.dart` |
| 11 | `CODE-06` | Status AI sesuai tidak ada masalah diputarbalikkan jadi MERAH karena ada kata tidak | Sistem kini mencocokkan kata utuh sesuai terlebih dahulu sebelum memeriksa kata tidak sesuai | `test/ai_false_positive_test.dart` |
| 12 | `CODE-07` | Foto yang dikirim ke AI terlalu kecil dan pecah sehingga monitor kasir dan kabel divonis rusak | Ukuran foto untuk analisis AI dinaikkan ke standar resolusi 864px dengan kualitas 72 | `test/ai_false_positive_test.dart` |
| 13 | `CODE-08` | Checklist mewajibkan foto pasta prosesor padahal kipas pendingin terpasang di komputer kasir | Syarat checklist diubah menjadi kipas dan heatsink bersih dari debu sesuai panduan kerja lapangan | `test/round2_fixes_test.dart` |
| 14 | `CODE-09` | Pemeriksaan darurat AI menganggap kalimat bahasa Inggris not blurry sebagai foto buram | Ditambahkan saringan kata sanggahan pada mode darurat agar kalimat not blurry tidak divonis rusak | `test/ai_false_positive_test.dart` |
| 15 | `CODE-11` | Kalimat penjelasan AI yang singkat dilewati sehingga arti kalimat berbalik menjadi vonis rusak | Batas minimal panjang kalimat diturunkan menjadi 4 huruf dan kata sanggahan dibersihkan dari kartu deteksi | `test/ai_technician_reason_single_sentence_test.dart` |
| 16 | `CODE-12` | Laporan WhatsApp stiker barrier gate tertukar dengan penutup sensor anti air | Kata kunci penyaring stiker receiver diperbaiki dan nomor urut titik cadangan disamakan | `test/barrier_report_and_history_test.dart` |
| 17 | `CODE-13` | Jam pulang dan status telat salah hitung untuk shift kerja yang melewati tengah malam | Perhitungan jam pulang kini menangani pergantian tanggal kalender dan teknisi yang telat bisa langsung absen pulang saat pergantian shift | `test/round2_fixes_test.dart`, `test/attendance_archive_screen_test.dart` |
| 18 | `CODE-14` | Pemeriksaan seragam kerja hari Minggu bisa diakali dengan memajukan tanggal di pengaturan HP | Penentuan hari kerja kini memakai jam resmi hasil verifikasi server, bukan tanggal setelan HP | `test/round2_fixes_test.dart` |
| 19 | `CODE-15` | Tugas harian teknisi tertukar karena sistem hanya mencocokkan 3 huruf nama depan | Sistem kini mencocokkan nama lengkap teknisi secara utuh dan proses klaim tugas dikunci di server agar tidak saling timpa | `test/round2_fixes_test.dart` |
| 20 | `UI-03` | Ketikan draf laporan tugas teknisi di web iPhone hilang jika browser tidak sengaja tertutup | Pemeriksaan berkas lokal disesuaikan agar aman untuk web peramban sehingga draf kerja bisa dipulihkan | `test/daily_task_execution_draft_and_fallback_test.dart` |
| 21 | `UI-04` | Bukti kerja tugas harian yang berupa rekaman video tidak bisa dilihat oleh Supervisor | Kartu rincian tugas selesai milik Supervisor kini dilengkapi tombol buka dan pemutar video bukti kerja | `test/completed_daily_task_modal_test.dart` |
| 22 | `UI-05` | Tombol menu atas di galeri foto pada tema terang tidak terlihat karena warnanya sama dengan latar | Warna tombol aksi dan judul di bagian atas galeri diganti menjadi putih terang dengan kontras tajam | `docs/screenshots/fix-2026-11-07/gallery_light_appbar_ts13.png` |
| 23 | `UI-06` | Tulisan pemberitahuan riwayat perawatan masih kosong tidak terbaca saat tema gelap aktif | Warna teks pemberitahuan draf kosong diubah menjadi putih terang di atas latar gelap pekat | `docs/screenshots/fix-2026-11-07/maintenance_history_dark_empty_ts13.png` |
| 24 | `UI-07` | Pilihan jadwal shift kantor HO Makassar ada yang kembar dan salah nama | Daftar shift kantor HO dirapikan menjadi empat jadwal resmi yaitu RSWS 1, RSWS 2, JP 1, dan JP 2 | `docs/screenshots/fix-2026-11-07/absensi_ho_shift_dialog_ts13.png` |
| 25 | `UI-08` | Teknisi dipaksa mengisi lembar serah terima pulang sebanyak dua kali berturut-turut | Lembar serah terima di menu shift dihapus dan dipusatkan satu pintu lewat lembar geser kamera | `docs/screenshots/fix-2026-11-07/absensi_dialog_pulang_ts13.png` |
| 26 | `UI-09` | Tombol bagikan bukti tugas berdesakan ke samping dan jendela tugas terkunci setelah kirim WA | Susunan tombol diubah menjadi menurun ke bawah dan jendela otomatis tertutup setelah dibagikan | `docs/screenshots/fix-2026-11-07/custom_task_post_save_dialog_ts13.png` |
| 27 | `UI-10` | Tulisan pesan error teknis bahasa Inggris muncul langsung di layar dan membingungkan teknisi | Pesan error teknis diganti dengan kalimat petunjuk bahasa Indonesia yang ramah dan mudah dipahami | `lib/features/maintenance/screens/point_camera_view.dart`, `lib/features/daily_tasks/screens/custom_task_execution_screen.dart` |
| 28 | `SEC-10` | Foto absensi teknisi menumpuk di galeri foto umum HP dan tidak pernah terhapus otomatis | Fitur simpan otomatis ke galeri umum HP dimatikan, dan foto di memori internal aplikasi otomatis dibersihkan setiap 7 hari | `test/round2_fixes_test.dart` |

## Keputusan Aan yang Sudah Diterapkan
1. **Status Perlu Cek Manual Bukan Temuan Rusak**: Pos dengan status foto perlu cek manual tetap berwarna hijau aman di peta monitoring dan hanya dicatat sebagai pengingat untuk diperiksa langsung oleh mata SPV.
2. **Form Pulang Satu Pintu**: Formulir serah terima di menu pilihan shift dihapus total, seluruh pengisian laporan pulang dipusatkan satu pintu lewat lembar kamera yang sudah otomatis merangkum tugas harian.
3. **Hapus Riwayat Khusus Cabang Aktif**: Tombol hapus riwayat absensi hanya membuang catatan milik cabang yang sedang dipilih teknisi, data cabang lain tetap aman dan tidak ikut terhapus.
4. **Telat Masuk Boleh Langsung Pulang Saat Pergantian Shift**: Teknisi yang telat masuk tidak lagi dikunci selama 8 jam ke depan, melainkan bisa langsung absen pulang begitu jam pergantian shift kerja tiba.
5. **Syarat Pemeriksaan Pasta Prosesor Diganti**: SOP checklist diubah menjadi "Kipas dan heatsink bersih dari debu", sehingga teknisi tidak perlu membongkar kipas pendingin komputer kasir.
6. **Login Darurat Offline Hanya Akun Terdaftar**: Sebanyak 59 akun dan password bawaan yang tertanam di kode program telah dihapus total; login offline darurat di HP kini hanya bisa dipakai oleh akun yang sudah pernah sukses login online di HP tersebut.
7. **Kunci Jepret Absen Jika GPS Mati atau Palsu**: Jika sinyal GPS belum mengunci atau terdeteksi aplikasi lokasi palsu, tombol jepret kamera dikunci dan memunculkan kotak pesan peringatan dengan tombol Coba Lagi setelah berpindah ke area terbuka.
8. **Foto Absen Tidak Masuk Galeri Umum**: Pengambilan foto absen tidak lagi menyimpan file ke galeri foto umum HP teknisi, melainkan disimpan di folder internal aplikasi yang dibersihkan otomatis setiap 7 hari.

## Belum Dikerjakan

| No | ID | Masalah (Bahasa Awam) | Alasan Belum Dikerjakan |
| :--- | :--- | :--- | :--- |
| 1 | `SEC-03` | Jalur server fungsi AI Vision bisa diakses publik tanpa login resmi | Menunggu keputusan migrasi Supabase Auth (kunci API cadangan di HP sudah dibersihkan, tetapi penguncian fungsi server proxy butuh token akun resmi) |
| 2 | `SEC-04` | Peran akun teknisi atau Supervisor hanya dicek di memori HP | Menunggu keputusan migrasi Supabase Auth agar pengecekan peran akun divalidasi langsung oleh server lewat token resmi |
| 3 | `SEC-05` | Larangan hapus tugas yang sudah selesai hanya dicegah di tampilan layar HP | Menunggu keputusan migrasi Supabase Auth dan penguncian izin tabel di database server (aturan RLS) |
| 4 | `SEC-08` | Tautan kirim Google Sheets belum dikunci sandi rahasia dan rentan formula | Temuan prioritas P1, menunggu penjadwalan perbaikan tahap berikutnya |
| 5 | `SEC-07` | Browser web menyimpan file aset lama hingga 1 tahun tanpa pembaruan | Temuan prioritas P2, belum dijadwalkan |
| 6 | `SEC-09` | Karakter persen pada pencarian nama teknisi bisa memanggil semua data | Temuan prioritas P2, belum dijadwalkan |
| 7 | `CODE-16` | Laporan perawatan tengah malam terbagi menjadi dua tanggal berbeda di server | Temuan prioritas P2, belum dijadwalkan |
| 8 | `CODE-17` | Layar utama membaca ulang ratusan data absen yang membebani memori HP | Temuan prioritas P2, belum dijadwalkan |
| 9 | `CODE-18` | Tiap kali memotret titik perawatan, ribuan data disimpan ulang ke memori HP | Temuan prioritas P2, belum dijadwalkan |
| 10 | `UI-11` | Tulisan tugas harian terpotong di HP layar kecil dengan setelan huruf besar | Temuan prioritas P2, belum dijadwalkan |
| 11 | `UI-12` | Lencana status terlambat dan lencana AI terpotong di riwayat absensi | Temuan prioritas P2, belum dijadwalkan |
| 12 | `UI-13` | Teks tanggal album di galeri foto menabrak kotak jumlah foto di layar sempit | Temuan prioritas P2, belum dijadwalkan |
| 13 | `UI-14` | Tombol jalan pintas shift di pojok kamera terlalu kecil untuk ditekan jempol | Temuan prioritas P2, belum dijadwalkan |
| 14 | `UI-15` | Tombol senter dan tombol kembali di kamera perawatan terlalu sempit | Temuan prioritas P2, belum dijadwalkan |
| 15 | `UI-16` | Layar peta perawatan tetap berwarna putih silau saat tema gelap diaktifkan | Temuan prioritas P2, belum dijadwalkan |
| 16 | `UI-17` | Judul checklist perawatan di bilah atas terpotong menjadi tulisan tidak jelas | Temuan prioritas P2, belum dijadwalkan |

## Efek ke Pengguna Setelah Update
1. **Wajib Login Online Pertama Kali**: Teknisi wajib melakukan login secara online minimal satu kali saat ponsel terhubung ke internet. Setelah itu, akun tersebut baru bisa dipakai untuk login darurat saat offline tanpa internet di HP yang sama.
2. **Kamera Absen Terkunci Jika GPS Mati**: Teknisi yang berada di area tanpa sinyal GPS (seperti di basement parkir tertutup) atau menyalakan aplikasi fake GPS tidak bisa menekan tombol jepret foto. Muncul kotak pesan instruksi untuk berpindah ke area terbuka dan menekan tombol Coba Lagi.
3. **Galeri Ponsel Bersih dari Foto Absensi**: Foto wajah dan absensi teknisi tidak lagi mengotori album foto galeri ponsel pribadi dan file di dalam aplikasi akan terhapus otomatis setelah 7 hari.
4. **Peta Monitoring SPV Lebih Akurat**: Titik pos parkir tidak lagi mendadak berubah menjadi warna oranye (rusak) hanya karena foto sedikit gelap atau sinyal putus nyambung, sehingga Supervisor bisa fokus pada pos yang benar-benar rusak.

## Langkah Berikutnya
1. **Rilis Versi 2.0.133**: Melakukan komit atas seluruh 28 perbaikan yang sudah selesai dan teruji, lalu membuat paket rilis aplikasi baru untuk didistribusikan ke teknisi dan Supervisor.
2. **Keputusan Migrasi Login Supabase Auth**: Menjadwalkan migrasi sistem otentikasi ke Supabase Auth resmi untuk menuntaskan 3 celah keamanan server yang tersisa (`SEC-03`, `SEC-04`, `SEC-05`) serta mengaktifkan aturan perlindungan tabel database (RLS).
3. **Penjadwalan Tahap Lanjutan**: Menjadwalkan penyelesaian bertahap untuk sisa perbaikan tampilan layar kecil dan optimasi memori (P2 dan P3) sesuai kebutuhan operasional lapangan.
