## 1. Login: `lib/features/auth/screens/login_screen.dart:7-434`
Opened from: SplashScreen (`lib/features/splash/screens/splash_screen.dart:108`), CameraDrawer logout (`lib/features/camera/widgets/camera_drawer.dart:71`)
Type: screen

### Fields
| UI element (top to bottom) | Source (field/variable + file:line) | Empty or edge value |
| Theme toggle pill | `ThemeService.isDarkMode` (`lib/features/auth/screens/login_screen.dart:63`) | 'Terang' if dark, 'Gelap' if light (`lib/features/auth/screens/login_screen.dart:118`) |
| Logo lingkaran | `Image.asset('foto/splash_logo.png')` (`lib/features/auth/screens/login_screen.dart:168`) | Fallback text 'PMA' (`lib/features/auth/screens/login_screen.dart:174`) |
| Judul aplikasi | Text 'PMA App' (`lib/features/auth/screens/login_screen.dart:192`) | Fixed string |
| Subjudul aplikasi | Text 'Absen, Maintenance & Daily Task' (`lib/features/auth/screens/login_screen.dart:204`) | Fixed string |
| Banner pesan error | `_errorMessage` (`lib/features/auth/screens/login_screen.dart:233`) | Hidden when null (`lib/features/auth/screens/login_screen.dart:233`) |
| Label username | Text 'Username' (`lib/features/auth/screens/login_screen.dart:264`) | Fixed string |
| Input field username | `_identityCtrl.text` (`lib/features/auth/screens/login_screen.dart:275`) | Hint 'Username' (`lib/features/auth/screens/login_screen.dart:286`) |
| Label kata sandi | Text 'Kata Sandi' (`lib/features/auth/screens/login_screen.dart:314`) | Fixed string |
| Input field kata sandi | `_passwordCtrl.text` (`lib/features/auth/screens/login_screen.dart:325`) | Hint 'Katasandi' (`lib/features/auth/screens/login_screen.dart:337`) |
| Tombol visibilitas sandi | `_obscurePassword` (`lib/features/auth/screens/login_screen.dart:326`) | Toggle icon visibility (`lib/features/auth/screens/login_screen.dart:349`) |
| Tombol login CTA | `_isLoading` (`lib/features/auth/screens/login_screen.dart:386`) | Label 'Login' (`lib/features/auth/screens/login_screen.dart:393`) or loader |
| Footer branding | Text 'PMAapp powered by annnpii' (`lib/features/auth/screens/login_screen.dart:411`) | Fixed string |

### Actions
| Label (verbatim) | Control | Handler (file:line) | Result |
| Beralih ke mode terang / Beralih ke mode gelap | Tooltip / InkWell | `ThemeService.toggleTheme(context)` (`lib/features/auth/screens/login_screen.dart:89`) | Switch app theme mode |
| Tampilkan kata sandi / Sembunyikan kata sandi | IconButton | `setState(() => _obscurePassword = !_obscurePassword)` (`lib/features/auth/screens/login_screen.dart:353`) | Toggle password obscure text |
| Katasandi (Enter) | TextField.onSubmitted | `_handleLogin()` (`lib/features/auth/screens/login_screen.dart:335`) | Submit credentials |
| Login | ElevatedButton | `_handleLogin()` (`lib/features/auth/screens/login_screen.dart:377`) | Validate and pushReplacement CameraCaptureScreen |

### States
- loading: CircularProgressIndicator inside login button (`lib/features/auth/screens/login_screen.dart:387-391`)
- empty: 'Username dan kata sandi wajib diisi.' (`lib/features/auth/screens/login_screen.dart:32`)
- error: 'Username dan kata sandi wajib diisi.' (`lib/features/auth/screens/login_screen.dart:32`), 'Username atau kata sandi salah' (`lib/features/auth/screens/login_screen.dart:53`), error card (`lib/features/auth/screens/login_screen.dart:234-258`)
- disabled: ElevatedButton disabled when `_isLoading == true` (`lib/features/auth/screens/login_screen.dart:377`)
- success: PushReplacement to CameraCaptureScreen (`lib/features/auth/screens/login_screen.dart:49-51`)
- offline: none in code

### Conditional
- Dark mode: `ThemeService.isDarkMode(context)` (`lib/features/auth/screens/login_screen.dart:63`) switches colors, borders, and theme toggle icon/label ('Terang' vs 'Gelap' `lib/features/auth/screens/login_screen.dart:118`)
- SPV vs teknisi: none in code
- Branch: none in code
- Web vs Android: none in code

### Copy
- 'Beralih ke mode terang' (`lib/features/auth/screens/login_screen.dart:93`)
- 'Beralih ke mode gelap' (`lib/features/auth/screens/login_screen.dart:93`)
- 'Terang' (`lib/features/auth/screens/login_screen.dart:118`)
- 'Gelap' (`lib/features/auth/screens/login_screen.dart:118`)
- 'PMA' (`lib/features/auth/screens/login_screen.dart:174`)
- 'PMA App' (`lib/features/auth/screens/login_screen.dart:192`)
- 'Absen, Maintenance & Daily Task' (`lib/features/auth/screens/login_screen.dart:204`)
- 'Username dan kata sandi wajib diisi.' (`lib/features/auth/screens/login_screen.dart:32`)
- 'Username atau kata sandi salah' (`lib/features/auth/screens/login_screen.dart:53`)
- 'Username' (`lib/features/auth/screens/login_screen.dart:264`)
- 'Kata Sandi' (`lib/features/auth/screens/login_screen.dart:314`)
- 'Katasandi' (`lib/features/auth/screens/login_screen.dart:337`)
- 'Tampilkan kata sandi' (`lib/features/auth/screens/login_screen.dart:347`)
- 'Sembunyikan kata sandi' (`lib/features/auth/screens/login_screen.dart:347`)
- 'Tombol masuk akun' (`lib/features/auth/screens/login_screen.dart:374`)
- 'Login' (`lib/features/auth/screens/login_screen.dart:393`)
- 'PMAapp powered by annnpii' (`lib/features/auth/screens/login_screen.dart:411`)

## 2. Drawer menu: `lib/features/camera/widgets/camera_drawer.dart:23-524`
Opened from: Hamburger menu button (`lib/features/camera/screens/camera_capture_screen.dart:2379-2380`)
Type: dialog

### Fields
| UI element (top to bottom) | Source (field/variable + file:line) | Empty or edge value |
| Header logo BSS | `Image.asset('foto/bssfotologo_transparent.png')` (`lib/features/camera/widgets/camera_drawer.dart:121`) | Fallback text 'BSS PARKING' (`lib/features/camera/widgets/camera_drawer.dart:125`) |
| Menu Penugasan Teknisi | Text 'Penugasan Teknisi' (`lib/features/camera/widgets/camera_drawer.dart:158`) | Visible only for supervisor (`lib/features/camera/widgets/camera_drawer.dart:143`) |
| Badge role SPV | Text 'SPV' (`lib/features/camera/widgets/camera_drawer.dart:163`) | Chip indicator (`lib/features/camera/widgets/camera_drawer.dart:162`) |
| Subtitle Penugasan Teknisi | Text 'Buat tugas dan pantau progres kerja teknisi' (`lib/features/camera/widgets/camera_drawer.dart:172`) | Fixed string |
| Menu Daily Task | Text 'Daily Task' (`lib/features/camera/widgets/camera_drawer.dart:202`) | Visible only for petugas (`lib/features/camera/widgets/camera_drawer.dart:189`) |
| Subtitle Daily Task | Text 'Daftar tugas harian yang harus dikerjakan' (`lib/features/camera/widgets/camera_drawer.dart:206`) | Fixed string |
| Badge pending task | `DailyTaskService.pendingCountNotifier` (`lib/features/camera/widgets/camera_drawer.dart:210`) | Chevron icon when count <= 0 (`lib/features/camera/widgets/camera_drawer.dart:229`) |
| Menu Riwayat Maintenance | Text 'Riwayat Maintenance' (`lib/features/camera/widgets/camera_drawer.dart:259`) | Fixed string |
| Subtitle Riwayat Maintenance | `drafts.length`, `completed.length` (`lib/features/camera/widgets/camera_drawer.dart:263-266`) | 'Daftar checklist unit' if both empty (`lib/features/camera/widgets/camera_drawer.dart:266`) |
| Badge draft count | `drafts.length` (`lib/features/camera/widgets/camera_drawer.dart:276`) | Chevron icon when drafts empty (`lib/features/camera/widgets/camera_drawer.dart:284`) |
| Menu Map Maintenance | Text 'Map Maintenance' (`lib/features/camera/widgets/camera_drawer.dart:307`) | Fixed string |
| Subtitle Map Maintenance | Text 'Lokasi sudah & belum maintenance' (`lib/features/camera/widgets/camera_drawer.dart:311`) | Fixed string |
| Menu Arsip Kehadiran | Text 'Arsip Kehadiran' (`lib/features/camera/widgets/camera_drawer.dart:336`) | Fixed string |
| Subtitle Arsip Kehadiran | Text 'Catatan absen masuk & pulang 30 hari terakhir' (`lib/features/camera/widgets/camera_drawer.dart:339`) | Fixed string |
| Badge 30 Hari | Text '30 Hari' (`lib/features/camera/widgets/camera_drawer.dart:348`) | Fixed chip badge |
| Menu Tema | `ThemeService.isDarkMode` (`lib/features/camera/widgets/camera_drawer.dart:370`) | 'Mode Terang' if dark, 'Mode Gelap' if light (`lib/features/camera/widgets/camera_drawer.dart:385`) |
| Subtitle Tema | `ThemeService.isDarkMode` (`lib/features/camera/widgets/camera_drawer.dart:370`) | 'Ganti ke tema terang' / 'Ganti ke tema gelap' (`lib/features/camera/widgets/camera_drawer.dart:389`) |
| Switch Tema | `Switch.adaptive` (`lib/features/camera/widgets/camera_drawer.dart:392`) | Boolean value (`lib/features/camera/widgets/camera_drawer.dart:393`) |
| Menu PWA iPhone | Text 'Pasang di iPhone (PWA)' (`lib/features/camera/widgets/camera_drawer.dart:418`) | Web platform only (`lib/features/camera/widgets/camera_drawer.dart:407`) |
| Subtitle PWA iPhone | Text 'Panduan pasang ke layar utama tanpa URL bar' (`lib/features/camera/widgets/camera_drawer.dart:422`) | Fixed string |
| Avatar inisial user | `user?.nama` (`lib/features/camera/widgets/camera_drawer.dart:442`) | 'U' if user null or empty (`lib/features/camera/widgets/camera_drawer.dart:442`) |
| Nama user login | `user?.nama` (`lib/features/camera/widgets/camera_drawer.dart:447`) | 'Belum Login' if null (`lib/features/camera/widgets/camera_drawer.dart:447`) |
| Subtitle cabang user | `BranchService.instance.currentBranch.name` (`lib/features/camera/widgets/camera_drawer.dart:451`) | 'IT Support <Branch>' |
| Icon keluar akun | `Icons.logout_rounded` (`lib/features/camera/widgets/camera_drawer.dart:455`) | Fixed icon |
| Footer brand | Text 'PMAapp powered by annnpii' (`lib/features/camera/widgets/camera_drawer.dart:478`) | Fixed string |
| Footer tagline | Text 'Project Maintenance Assembly' (`lib/features/camera/widgets/camera_drawer.dart:489`) | Fixed string |
| Footer versi app | `_appPackageInfo` (`lib/features/camera/widgets/camera_drawer.dart:500`) | 'Versi tidak terbaca' if error/loading (`lib/features/camera/widgets/camera_drawer.dart:504`) |

### Actions
| Label (verbatim) | Control | Handler (file:line) | Result |
| Penugasan Teknisi | ListTile | `Navigator.push` (`lib/features/camera/widgets/camera_drawer.dart:177`) | Navigate to SpvTaskDispatcherScreen |
| Daily Task | ListTile | `Navigator.push` (`lib/features/camera/widgets/camera_drawer.dart:234`) | Navigate to TeknisiDailyTasksScreen |
| Riwayat Maintenance | ListTile | `Navigator.push` (`lib/features/camera/widgets/camera_drawer.dart:287`) | Navigate to MaintenanceHistoryScreen |
| Map Maintenance | ListTile | `Navigator.push` (`lib/features/camera/widgets/camera_drawer.dart:317`) | Navigate to MaintenanceMapScreen |
| Arsip Kehadiran | ListTile | `Navigator.push` (`lib/features/camera/widgets/camera_drawer.dart:358`) | Navigate to AttendanceArchiveScreen |
| Mode Terang / Mode Gelap | Switch / ListTile | `ThemeService.toggleTheme(context)` (`lib/features/camera/widgets/camera_drawer.dart:396`, `400`) | Toggle app theme mode |
| Pasang di iPhone (PWA) | ListTile | `IosPwaInstallModal.show(context)` (`lib/features/camera/widgets/camera_drawer.dart:428`) | Open iOS PWA modal |
| Keluar Akun | IconButton / ListTile | `_confirmLogout(context)` (`lib/features/camera/widgets/camera_drawer.dart:457`, `459`) | Open logout confirmation dialog (`lib/features/camera/widgets/camera_drawer.dart:33`) |
| Batal | TextButton | `Navigator.pop(dCtx)` (`lib/features/camera/widgets/camera_drawer.dart:61`) | Dismiss logout confirmation dialog |
| Keluar | ElevatedButton | `AuthRepository.instance.logout()` (`lib/features/camera/widgets/camera_drawer.dart:69`) | Clear session, navigate to LoginScreen (`lib/features/camera/widgets/camera_drawer.dart:71`) |

### States
- loading: none in code (version shows 'Versi tidak terbaca' line 504 until future completes)
- empty: 'Belum Login' (`lib/features/camera/widgets/camera_drawer.dart:447`), 'Daftar checklist unit' (`lib/features/camera/widgets/camera_drawer.dart:266`)
- error: 'Versi tidak terbaca' (`lib/features/camera/widgets/camera_drawer.dart:504`)
- disabled: none in code
- success: none in code
- offline: none in code

### Conditional
- SPV vs teknisi: `user?.role == UserRole.supervisor` (`lib/features/camera/widgets/camera_drawer.dart:143`) shows 'Penugasan Teknisi'; `user?.role == UserRole.petugas` (`lib/features/camera/widgets/camera_drawer.dart:189`) shows 'Daily Task'
- Web vs Android: `kIsWeb` (`lib/features/camera/widgets/camera_drawer.dart:407`) shows 'Pasang di iPhone (PWA)'
- Branch: `BranchService.instance.currentBranch.name` (`lib/features/camera/widgets/camera_drawer.dart:451`) formats user affiliation
- Dark mode: `ThemeService.isDarkMode(context)` (`lib/features/camera/widgets/camera_drawer.dart:92`, `370`) switches colors, borders, and theme title ('Mode Terang' vs 'Mode Gelap' `lib/features/camera/widgets/camera_drawer.dart:385`)

### Copy
- 'Keluar Akun' (`lib/features/camera/widgets/camera_drawer.dart:43`, `456`)
- 'Yakin ingin keluar akun?' (`lib/features/camera/widgets/camera_drawer.dart:53`)
- 'Batal' (`lib/features/camera/widgets/camera_drawer.dart:62`)
- 'Keluar' (`lib/features/camera/widgets/camera_drawer.dart:80`)
- 'BSS PARKING' (`lib/features/camera/widgets/camera_drawer.dart:125`)
- 'Penugasan Teknisi' (`lib/features/camera/widgets/camera_drawer.dart:158`)
- 'SPV' (`lib/features/camera/widgets/camera_drawer.dart:163`)
- 'Buat tugas dan pantau progres kerja teknisi' (`lib/features/camera/widgets/camera_drawer.dart:172`)
- 'Daily Task' (`lib/features/camera/widgets/camera_drawer.dart:202`)
- 'Daftar tugas harian yang harus dikerjakan' (`lib/features/camera/widgets/camera_drawer.dart:206`)
- 'Riwayat Maintenance' (`lib/features/camera/widgets/camera_drawer.dart:259`)
- ' draft aktif • ' (`lib/features/camera/widgets/camera_drawer.dart:264`)
- ' selesai' (`lib/features/camera/widgets/camera_drawer.dart:264`)
- ' pekerjaan selesai' (`lib/features/camera/widgets/camera_drawer.dart:265`)
- 'Daftar checklist unit' (`lib/features/camera/widgets/camera_drawer.dart:265`)
- ' Draft' (`lib/features/camera/widgets/camera_drawer.dart:276`)
- 'Map Maintenance' (`lib/features/camera/widgets/camera_drawer.dart:307`)
- 'Lokasi sudah & belum maintenance' (`lib/features/camera/widgets/camera_drawer.dart:311`)
- 'Arsip Kehadiran' (`lib/features/camera/widgets/camera_drawer.dart:336`)
- 'Catatan absen masuk & pulang 30 hari terakhir' (`lib/features/camera/widgets/camera_drawer.dart:339`)
- '30 Hari' (`lib/features/camera/widgets/camera_drawer.dart:348`)
- 'Mode Terang' (`lib/features/camera/widgets/camera_drawer.dart:385`)
- 'Mode Gelap' (`lib/features/camera/widgets/camera_drawer.dart:385`)
- 'Ganti ke tema terang' (`lib/features/camera/widgets/camera_drawer.dart:389`)
- 'Ganti ke tema gelap' (`lib/features/camera/widgets/camera_drawer.dart:389`)
- 'Pasang di iPhone (PWA)' (`lib/features/camera/widgets/camera_drawer.dart:418`)
- 'Panduan pasang ke layar utama tanpa URL bar' (`lib/features/camera/widgets/camera_drawer.dart:422`)
- 'Belum Login' (`lib/features/camera/widgets/camera_drawer.dart:447`)
- 'IT Support ' (`lib/features/camera/widgets/camera_drawer.dart:451`)
- 'PMAapp powered by annnpii' (`lib/features/camera/widgets/camera_drawer.dart:478`)
- 'Project Maintenance Assembly' (`lib/features/camera/widgets/camera_drawer.dart:489`)
- 'Versi ' (`lib/features/camera/widgets/camera_drawer.dart:503`)
- 'Versi tidak terbaca' (`lib/features/camera/widgets/camera_drawer.dart:504`)

## 3. Atur Shift: `lib/features/templates/widgets/absensi_kategori_dialog.dart:12-1367`
Opened from: Shortcut pill (`lib/features/camera/screens/camera_capture_screen.dart:3030`), Quick picker modal (`lib/features/camera/widgets/template_quick_picker_modal.dart:205`), Template list (`lib/features/templates/screens/template_list_screen.dart:56`)
Type: dialog

### Fields
| UI element (top to bottom) | Source (field/variable + file:line) | Empty or edge value |
| Header judul dialog | Text 'Atur Shift & Absensi' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:475`) | Fixed string |
| Header subjudul dialog | Text 'Jadwal shift & Lokasi standby' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:485`) | Fixed string |
| Tombol tutup dialog | Tooltip 'Tutup dialog' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:496`) | Icon `Icons.close_rounded` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:498`) |
| Header section teknisi | Text 'TEKNISI BERTUGAS' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:517`) | Subtitle 'Nama yang tercetak di watermark & laporan' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:518`) |
| Input field nama teknisi | `_teknisiCtrl.text` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:522`) | Hint 'Ketik nama teknisi' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:535`) |
| Card lokasi standby (Manado) | `BranchService.instance.currentBranch.defaultLocationTag` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:980`) | Fixed card 'Pasar Bersehati Manado' [PBM] (`lib/features/templates/widgets/absensi_kategori_dialog.dart:960`) |
| Input field lokasi (Bali/HO) | `_lokasiCtrl.text` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:836`) | Hint 'Tag pos standby (mis. PBKD, PCD, PGA)' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:846`) |
| Chips pos lokasi cepat | `BranchService.instance.getLocationTags()` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:870`) | Horizontal chip scroll (`lib/features/templates/widgets/absensi_kategori_dialog.dart:868`) |
| Header section jadwal shift | Text 'PILIH JADWAL SHIFT' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:569`) | Subtitle 'Jadwal shift teknisi' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:570`) |
| Bento card shift list | `_shiftCards` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:576`) | Title, hours, period per card (`lib/features/templates/widgets/absensi_kategori_dialog.dart:1040-1076`) |
| Toggle Custom Shift card | Text 'Custom Shift' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:1143`) | Subtitle 'Atur Shift sendiri' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:1153`) |
| Switch Custom Shift | `_isCustomShift` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:1163`) | Boolean toggle (`lib/features/templates/widgets/absensi_kategori_dialog.dart:1164`) |
| Field custom shift nama | `_customShiftCtrl.text` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:1182`) | Hint 'Nama shift (mis. Shift Khusus)' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:1183`) |
| Field custom shift jam | `_customShiftJamCtrl.text` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:1192`) | Hint 'Jam kerja (mis. 08:00 - 17:00)' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:1193`) |
| Header section jenis shift | Text 'JENIS SHIFT' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:611`) | Subtitle 'Jenis Shift' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:612`) |
| Card tipe Masuk | `_tipeLaporan == 'Masuk'` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:622`) | Label 'Masuk', sublabel 'Mulai Kerja' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:619-620`) |
| Card tipe Pulang | `_tipeLaporan == 'Pulang'` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:633`) | Label 'Pulang', sublabel 'Selesai & Handover' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:629-631`) |
| Tombol Batal | Text 'Batal' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:670`) | Tooltip 'Tutup tanpa menyimpan perubahan' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:658`) |
| Tombol Simpan Shift | `_isSaving` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:695`) | Text 'Simpan Shift' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:710`) or loader |

### Actions
| Label (verbatim) | Control | Handler (file:line) | Result |
| Tutup dialog | IconButton | `Navigator.pop(context)` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:499`) | Dismiss dialog |
| Ketik nama teknisi | TextField | `onChanged` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:523`) | Clear `_teknisiError` |
| Tag pos standby | TextField | `onChanged` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:838`) | Update `_lokasiStandby` |
| <Tag POS> | InkWell | `_lokasiCtrl.text = tag` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:888`) | Select POS chip tag |
| <Shift Card Title> | InkWell | `_onShiftSelected(fullValue)` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:1018`) | Select predefined shift |
| Custom Shift | InkWell / Switch | `_onCustomShiftToggled()` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:1110`, `1169`) | Toggle custom shift inputs |
| Shift : | TextField | `_onCustomShiftChanged()` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:1230`) | Sync custom shift name |
| Jam : | TextField | `_onCustomShiftChanged()` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:1230`) | Sync custom shift hours |
| Masuk | InkWell | `_onTipeChanged('Masuk')` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:625`) | Set check-in attendance mode |
| Pulang | InkWell | `_onTipeChanged('Pulang')` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:636`) | Validate shift end; show warning or set check-out mode |
| Mengerti | TextButton | `Navigator.pop(ctx)` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:345`) | Dismiss 'Belum Waktunya Pulang' dialog |
| Batal | OutlinedButton | `Navigator.pop(context)` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:660`) | Dismiss dialog without saving |
| Simpan Shift | ElevatedButton | `_saveData()` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:686`) | Persist shift/location/type and dismiss |

### States
- loading: CircularProgressIndicator inside Simpan Shift button when `_isSaving == true` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:696-700`)
- empty: 'Nama teknisi wajib diisi' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:367`)
- error: 'Nama teknisi wajib diisi' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:367`), 'Belum ada catatan absen masuk aktif hari ini.' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:301`), 'Belum Waktunya Pulang' dialog (`lib/features/templates/widgets/absensi_kategori_dialog.dart:333`)
- disabled: Batal & Simpan Shift buttons disabled when `_isSaving == true` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:660`, `686`)
- success: Pop dialog and invoke `widget.onSaved?.call()` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:417-419`)
- offline: none in code

### Conditional
- Branch Manado: `BranchService.instance.currentBranch == AppBranch.manado` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:781`) locks location to 'Pasar Bersehati Manado' [PBM]; Bali/HO shows editable location card (`lib/features/templates/widgets/absensi_kategori_dialog.dart:786-880`)
- Branch Shifts: `BranchService.instance.currentBranch` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:183`) switches between Manado (5 shifts), Bali (6 shifts), and HO (10 shifts)
- Custom shift active: `_isCustomShift` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:1176`) reveals custom shift name and jam inputs
- Dark mode: `ThemeService.isDarkMode(context)` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:426`) updates surfaces, borders, and typography
- SPV vs teknisi: category locked to `AbsensiKategori.teknisi` (`lib/features/templates/widgets/absensi_kategori_dialog.dart:197`)
- Web vs Android: none in code

### Copy
- 'Belum ada catatan absen masuk aktif hari ini.' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:301`)
- 'Belum Waktunya Pulang' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:333`)
- 'Absen pulang belum bisa dilakukan karena shift belum selesai.\n\n' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:336`)
- '• Jadwal Akhir Shift: Jam ' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:337`)
- '• Durasi Berjalan: ' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:338`)
- '• Sisa Waktu Shift: ' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:339`)
- ' lagi\n\n' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:339`)
- 'Absen pulang bisa dilakukan setelah jam ' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:340`)
- ' atau setelah durasi shift selesai.' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:340`)
- 'Mengerti' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:346`)
- 'Nama teknisi wajib diisi' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:367`)
- 'Atur Shift & Absensi' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:475`)
- 'Jadwal shift & Lokasi standby' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:486`)
- 'Tutup dialog' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:496`)
- 'TEKNISI BERTUGAS' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:517`)
- 'Nama yang tercetak di watermark & laporan' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:518`)
- 'Ketik nama teknisi' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:535`)
- 'PILIH JADWAL SHIFT' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:569`)
- 'Jadwal shift teknisi' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:570`)
- 'JENIS SHIFT' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:611`)
- 'Masuk' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:619`)
- 'Mulai Kerja' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:620`)
- 'Pulang' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:630`)
- 'Selesai & Handover' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:631`)
- 'Tutup tanpa menyimpan perubahan' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:658`)
- 'Batal' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:670`)
- 'Simpan konfigurasi shift dan terapkan ke watermark' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:684`)
- 'Simpan Shift' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:710`)
- 'LOKASI STANDBY' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:813`, `947`)
- 'Isi manual' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:824`)
- 'Tag pos standby (mis. PBKD, PCD, PGA)' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:846`)
- 'Pasar Bersehati Manado' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:960`)
- 'PBKD' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:959`)
- 'Custom Shift' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:1143`)
- 'Atur Shift sendiri' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:1153`)
- 'Shift :' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:1180`)
- 'Nama shift (mis. Shift Khusus)' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:1183`)
- 'Jam :' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:1190`)
- 'Jam kerja (mis. 08:00 - 17:00)' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:1193`)
- (DASH) 'Shift 1 (03:00 - 11:00)' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:50`)
- (DASH) '03:00 - 11:00 WITA' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:51`)
- (DASH) 'Pagi • 8 Jam' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:52`)
- (DASH) 'Sore-Malam • 8 Jam' (`lib/features/templates/widgets/absensi_kategori_dialog.dart:76`)

## 4. Absen Pulang: `lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:13-761`
Opened from: Shortcut pill (`lib/features/camera/screens/camera_capture_screen.dart:3024`), Shutter button intercept guard (`lib/features/camera/screens/camera_capture_screen.dart:1033`)
Type: bottom sheet

### Fields
| UI element (top to bottom) | Source (field/variable + file:line) | Empty or edge value |
| Handle bar | Container (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:269-276`) | Visual drag affordance |
| Icon header | `Icons.assignment_turned_in_rounded` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:292`) | Fixed icon |
| Judul header | Text 'Handover & Laporan Pulang' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:303`) | Fixed string |
| Subjudul header | Text 'Ringkasan tugas & serah terima shift' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:313`) | Fixed string |
| Tombol tutup | Tooltip 'Tutup' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:324`) | Icon `Icons.close_rounded` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:336`) |
| Banner error validasi | `_errorMessage` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:351`) | Hidden when null (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:351`) |
| Label Teknisi Selanjutnya | Text 'Teknisi Shift Selanjutnya *' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:388-401`) | Fixed string with red asterisk |
| Dropdown Teknisi Selanjutnya | `_selectedNextShift` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:415`) | List `_rekanItOptions` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:43-46`) |
| Label Pekerjaan Selesai | Text 'Pekerjaan Selesai Hari Ini *' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:484-497`) | Fixed string with red asterisk |
| Tombol Sinkron Daily Task | `_isLoadingDailyTasks`, `_syncedCompletedCount` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:515-530`) | 'Sinkron Daily Task' or 'Sinkron (N Selesai)' |
| Input Pekerjaan Selesai | `_selesaiCtrl.text` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:561`) | Hint 'Tulis pekerjaan yang selesai hari ini...' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:575`) |
| Counter Pekerjaan Selesai | `_selesaiCtrl.text.length` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:592`) | Format 'N/2000' |
| Toggle Belum Selesai | Text 'Ada pekerjaan belum selesai?' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:630`) | Icon `Icons.pending_actions_rounded` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:623`) |
| Switch Belum Selesai | `_adaPekerjaanBelum` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:640`) | Boolean toggle |
| Input Pekerjaan Belum | `_belumCtrl.text` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:677`) | Hint '1. Nama pekerjaan (Pos)\nAlasan: kenapa belum selesai' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:692`) |
| Counter Pekerjaan Belum | `_belumCtrl.text.length` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:705`) | Format 'N/2000' |
| Tombol submit CTA | Text 'Simpan & Lanjut Foto Pulang' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:743`) | Icon `Icons.check_circle_rounded` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:740`) |

### Actions
| Label (verbatim) | Control | Handler (file:line) | Result |
| Tutup | IconButton | `Navigator.pop(context, false)` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:341`) | Dismiss bottom sheet returning false |
| <Nama Teknisi / Tanpa Pengganti> | DropdownButton | `onChanged` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:463`) | Select incoming technician |
| Sinkron Daily Task / Sinkron (N Selesai) | InkWell | `_autoFillFromDailyTasks(force: true)` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:501`) | Fetch completed & pending tasks |
| Ada pekerjaan belum selesai? | Switch | `onChanged` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:645`) | Toggle pending tasks section |
| Simpan & Lanjut Foto Pulang | ElevatedButton | `_handleSave()` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:727`) | Validate, save handover, and pop returning true |

### States
- loading: CircularProgressIndicator inside sync button when `_isLoadingDailyTasks == true` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:516-522`)
- empty: Validation errors for empty next technician (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:171`), empty selesai text (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:180`), empty belum text when toggle active (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:192`)
- error: 'Pilih teknisi shift berikutnya.' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:171`), 'Tulis pekerjaan yang sudah selesai.' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:180`), 'Tulis pekerjaan yang belum selesai, atau matikan opsi jika tidak ada.' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:192`), 'Tulis alasan kenapa belum selesai untuk: <job>' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:200`)
- disabled: Sync button disabled when `_isLoadingDailyTasks == true` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:501`)
- success: Navigator pops returning `true` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:220`)
- offline: Fallback to `DailyTaskService.getCachedTasksLocally()` in catch block (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:132-148`)

### Conditional
- Toggle pending tasks: `_adaPekerjaanBelum` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:657`) shows multiline TextField for unfinished work
- Error banner: `_errorMessage != null` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:351`) renders red warning container
- Branch technicians: `BranchService.instance.getTechnicians()` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:44`) populates dropdown options per branch
- Dark mode: `ThemeService.isDarkMode(context)` (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:226`) adjusts sheet background, input containers, and text colors
- SPV vs teknisi: none in code
- Web vs Android: none in code

### Copy
- 'Shift Terakhir / Tidak Ada Pengganti' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:40`)
- 'Pilih teknisi shift berikutnya.' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:171`)
- 'Tulis pekerjaan yang sudah selesai.' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:180`)
- 'Tulis pekerjaan yang belum selesai, atau matikan opsi jika tidak ada.' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:192`)
- 'Tulis alasan kenapa belum selesai untuk: ' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:200`)
- 'Handover & Laporan Pulang' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:303`)
- 'Ringkasan tugas & serah terima shift' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:313`)
- 'Tutup' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:324`)
- 'Teknisi Shift Selanjutnya ' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:388`)
- 'Pekerjaan Selesai Hari Ini ' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:484`)
- 'Sinkron Daily Task' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:530`)
- 'Sinkron (' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:528`)
- ' Selesai)' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:528`)
- 'Tulis pekerjaan yang selesai hari ini...\nContoh: Pengecekan gate barrier, pembersihan printer pos, update sistem' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:575`)
- 'Ada pekerjaan belum selesai?' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:630`)
- '1. Nama pekerjaan (Pos)\nAlasan: kenapa belum selesai' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:692`)
- 'Simpan & Lanjut Foto Pulang' (`lib/features/camera/widgets/daily_pulang_bottom_sheet.dart:743`)

## 5. Pilih Lokasi: `lib/features/locations/widgets/location_picker_modal.dart:10-501`
Opened from: Shortcut location button (`lib/features/camera/screens/camera_capture_screen.dart:2280-2282`)
Type: bottom sheet

### Fields
| UI element (top to bottom) | Source (field/variable + file:line) | Empty or edge value |
| Handle bar | Container (`lib/features/locations/widgets/location_picker_modal.dart:227-234`) | Visual drag affordance |
| Judul header lokasi | `BranchService.instance.currentBranch.name` (`lib/features/locations/widgets/location_picker_modal.dart:247`) | Format 'Pilih Lokasi (<Cabang>)' |
| Tombol refresh GPS | Tooltip 'Refresh GPS' (`lib/features/locations/widgets/location_picker_modal.dart:259`) | Icon `Icons.refresh_rounded` (`lib/features/locations/widgets/location_picker_modal.dart:257`) |
| Banner status GPS live | `_isLoadingGps`, `_currentGps` (`lib/features/locations/widgets/location_picker_modal.dart:282-285`) | 'Mencari sinyal GPS...' or coordinates string |
| Alamat status GPS live | `_currentGps!.fullAddress` (`lib/features/locations/widgets/location_picker_modal.dart:296`) | 'Mengukur jarak ke lokasi terdekat...' if loading (`lib/features/locations/widgets/location_picker_modal.dart:295`) |
| Tombol simpan lokasi GPS | Text 'Simpan Lokasi' (`lib/features/locations/widgets/location_picker_modal.dart:311`) | Icon `Icons.add_location` (`lib/features/locations/widgets/location_picker_modal.dart:310`) |
| Search bar lokasi | `_searchQuery` (`lib/features/locations/widgets/location_picker_modal.dart:323`) | Hint 'Cari nama lokasi, tag, cabang...' (`lib/features/locations/widgets/location_picker_modal.dart:326`) |
| Subjudul daftar lokasi | Text 'Daftar Lokasi (Urut Jarak Terdekat):' (`lib/features/locations/widgets/location_picker_modal.dart:357`) | Fixed string |
| Link kelola lokasi | Text 'Kelola Semua Lokasi' (`lib/features/locations/widgets/location_picker_modal.dart:375`) | Fixed string |
| Badge tag POS card | `pos.locationTag` (`lib/features/locations/widgets/location_picker_modal.dart:430`) | Background `pos.tagColor` (`lib/features/locations/widgets/location_picker_modal.dart:426`) |
| Nama POS card | `pos.posName` (`lib/features/locations/widgets/location_picker_modal.dart:439`) | Bold styling if active (`lib/features/locations/widgets/location_picker_modal.dart:442`) |
| Alamat POS card | `pos.fullAddress` (`lib/features/locations/widgets/location_picker_modal.dart:449`) | Max 2 lines (`lib/features/locations/widgets/location_picker_modal.dart:452`) |
| Jarak POS card | `item['distanceText']` (`lib/features/locations/widgets/location_picker_modal.dart:464`) | Formatted distance string |
| Checkmark POS aktif | `Icons.check_circle` (`lib/features/locations/widgets/location_picker_modal.dart:474`) | Visible if `pos.posId == activePos.posId` (`lib/features/locations/widgets/location_picker_modal.dart:472`) |
| Dialog Simpan Lokasi Baru | Title 'Simpan Lokasi GPS Saat Ini' (`lib/features/locations/widgets/location_picker_modal.dart:81`) | Input form modal (`lib/features/locations/widgets/location_picker_modal.dart:76-186`) |

### Actions
| Label (verbatim) | Control | Handler (file:line) | Result |
| Refresh GPS | IconButton | `_fetchGpsAndRank()` (`lib/features/locations/widgets/location_picker_modal.dart:258`) | Re-read device GPS and recalculate distances |
| Simpan Lokasi | TextButton.icon | `_saveCurrentGpsAsNewPos()` (`lib/features/locations/widgets/location_picker_modal.dart:309`) | Open dialog to save current GPS as new POS |
| Cari nama lokasi, tag, cabang... | TextField | `onChanged` (`lib/features/locations/widgets/location_picker_modal.dart:348`) | Filter location list |
| Clear search | IconButton | `setState(() => _searchQuery = '')` (`lib/features/locations/widgets/location_picker_modal.dart:332`) | Reset search query |
| Kelola Semua Lokasi | TextButton | `Navigator.push(LocationManagementScreen)` (`lib/features/locations/widgets/location_picker_modal.dart:367`) | Open location management screen |
| <POS Card Tile> | ListTile | `widget.onLocationSelected(pos)` (`lib/features/locations/widgets/location_picker_modal.dart:480`) | Set current active POS and dismiss modal |
| Batal | TextButton | `Navigator.pop(dlgCtx)` (`lib/features/locations/widgets/location_picker_modal.dart:146`) | Dismiss save location dialog |
| Simpan & Jadikan Aktif | ElevatedButton | `LocationService.addLocation(newPos)` (`lib/features/locations/widgets/location_picker_modal.dart:168`) | Save new POS, set active, dismiss |

### States
- loading: CircularProgressIndicator when `_isLoadingGps == true` (`lib/features/locations/widgets/location_picker_modal.dart:387`), text 'Mencari sinyal GPS perangkat...' (`lib/features/locations/widgets/location_picker_modal.dart:283`)
- empty: 'Tidak ada lokasi cocok dengan "<query>"' (`lib/features/locations/widgets/location_picker_modal.dart:394`), 'Belum ada daftar lokasi' (`lib/features/locations/widgets/location_picker_modal.dart:395`)
- error: none in code
- disabled: none in code
- success: SnackBar 'Lokasi aktif: <pos> [<tag>]' (`lib/features/locations/widgets/location_picker_modal.dart:484`), SnackBar 'Lokasi "<pos>" disimpan dan jadi aktif!' (`lib/features/locations/widgets/location_picker_modal.dart:176`)
- offline: none in code

### Conditional
- Branch in title: `BranchService.instance.currentBranch.name` (`lib/features/locations/widgets/location_picker_modal.dart:247`)
- Tag auto-prefix in dialog: `currentBranch == AppBranch.bali ? 'DPS-...' : 'POS-...'` (`lib/features/locations/widgets/location_picker_modal.dart:64`)
- GPS loaded: `!_isLoadingGps` (`lib/features/locations/widgets/location_picker_modal.dart:307`) reveals 'Simpan Lokasi' button
- Search active: `_searchQuery.isNotEmpty` (`lib/features/locations/widgets/location_picker_modal.dart:329`) reveals clear icon
- Dark mode: `ThemeService.isDarkMode(context)` (`lib/features/locations/widgets/location_picker_modal.dart:205`) controls dark surface background and borders
- SPV vs teknisi: none in code
- Web vs Android: none in code

### Copy
- 'Lokasi Baru (GPS Live)' (`lib/features/locations/widgets/location_picker_modal.dart:62`)
- 'Simpan Lokasi GPS Saat Ini' (`lib/features/locations/widgets/location_picker_modal.dart:81`)
- 'Nama Lokasi *' (`lib/features/locations/widgets/location_picker_modal.dart:91`)
- 'Tag Card *' (`lib/features/locations/widgets/location_picker_modal.dart:99`)
- 'Cabang / Area' (`lib/features/locations/widgets/location_picker_modal.dart:106`)
- 'Pilih Warna Tag Badge Card:' (`lib/features/locations/widgets/location_picker_modal.dart:113`)
- 'Batal' (`lib/features/locations/widgets/location_picker_modal.dart:147`)
- 'Simpan & Jadikan Aktif' (`lib/features/locations/widgets/location_picker_modal.dart:182`)
- 'Lokasi "' (`lib/features/locations/widgets/location_picker_modal.dart:176`)
- '" disimpan dan jadi aktif!' (`lib/features/locations/widgets/location_picker_modal.dart:176`)
- 'Pilih Lokasi (' (`lib/features/locations/widgets/location_picker_modal.dart:247`)
- 'Refresh GPS' (`lib/features/locations/widgets/location_picker_modal.dart:259`)
- 'Mencari sinyal GPS perangkat...' (`lib/features/locations/widgets/location_picker_modal.dart:283`)
- 'Mengukur jarak ke lokasi terdekat...' (`lib/features/locations/widgets/location_picker_modal.dart:295`)
- 'Simpan Lokasi' (`lib/features/locations/widgets/location_picker_modal.dart:311`)
- 'Cari nama lokasi, tag, cabang...' (`lib/features/locations/widgets/location_picker_modal.dart:326`)
- 'Daftar Lokasi (Urut Jarak Terdekat):' (`lib/features/locations/widgets/location_picker_modal.dart:357`)
- 'Kelola Semua Lokasi' (`lib/features/locations/widgets/location_picker_modal.dart:375`)
- 'Tidak ada lokasi cocok dengan "' (`lib/features/locations/widgets/location_picker_modal.dart:394`)
- 'Belum ada daftar lokasi' (`lib/features/locations/widgets/location_picker_modal.dart:395`)
- 'Lokasi aktif: ' (`lib/features/locations/widgets/location_picker_modal.dart:484`)

## 6. Kamera per poin (HUD only, not watermark internals): `lib/features/maintenance/screens/point_camera_view.dart:28-1503`
Opened from: Poin card foto button (`lib/features/maintenance/screens/maintenance_checklist_screen.dart:983-991`, `3048`)
Type: full-screen

### Fields
| UI element (top to bottom) | Source (field/variable + file:line) | Empty or edge value |
| Tombol kembali | Tooltip 'Kembali' (`lib/features/maintenance/screens/point_camera_view.dart:836`) | Icon `Icons.arrow_back_ios_new_rounded` (`lib/features/maintenance/screens/point_camera_view.dart:833`) |
| Badge Tag Lokasi | `_activeLocation.locationTag` (`lib/features/maintenance/screens/point_camera_view.dart:857`) | 'BSS' if empty (`lib/features/maintenance/screens/point_camera_view.dart:860`) |
| Judul mode kamera | Text 'Maintenance' (`lib/features/maintenance/screens/point_camera_view.dart:870`) | Fixed string |
| Pill status AI | `_isOfflineFastMode` (`lib/features/maintenance/screens/point_camera_view.dart:885`) | 'Kilat' (amber) or 'AI Cloud' (green) (`lib/features/maintenance/screens/point_camera_view.dart:906`) |
| Pill timer capture | `_timerSeconds` (`lib/features/maintenance/screens/point_camera_view.dart:924`) | 'Off' or '<N>s' (`lib/features/maintenance/screens/point_camera_view.dart:944`) |
| Pill rasio kamera | `_selectedRatio` (`lib/features/maintenance/screens/point_camera_view.dart:957`) | 'Full', '3:4', or '1:1' (`lib/features/maintenance/screens/point_camera_view.dart:967-969`) |
| Tombol toggle flash | `_flashMode` (`lib/features/maintenance/screens/point_camera_view.dart:987-993`) | Off / Auto / Torch / On icons (`lib/features/maintenance/screens/point_camera_view.dart:988-993`) |
| Card ringkasan poin SOP | `widget.point.label` (`lib/features/maintenance/screens/point_camera_view.dart:1032`) | Icon `Icons.assignment_turned_in_rounded` (`lib/features/maintenance/screens/point_camera_view.dart:1023`) |
| Deskripsi panduan poin | `widget.point.deskripsi` (`lib/features/maintenance/screens/point_camera_view.dart:1047`) | Hidden if empty (`lib/features/maintenance/screens/point_camera_view.dart:1044`) |
| Reticle tap-to-focus | `_showFocusRing`, `_focusPoint` (`lib/features/maintenance/screens/point_camera_view.dart:1174`) | Yellow square reticle at touch coordinate |
| Pill instruksi status HUD | `_statusText` (`lib/features/maintenance/screens/point_camera_view.dart:1299`) | Hidden when `_isCapturing == true` (`lib/features/maintenance/screens/point_camera_view.dart:1290`) |
| Tombol switch kamera | `_cameras.length > 1` (`lib/features/maintenance/screens/point_camera_view.dart:1310`) | Tooltip 'Ganti Kamera Depan/Belakang' (`lib/features/maintenance/screens/point_camera_view.dart:1321`) |
| Shutter button pro | `_isCapturing` (`lib/features/maintenance/screens/point_camera_view.dart:1354`) | Shutter icon `Icons.camera_alt_rounded` (`lib/features/maintenance/screens/point_camera_view.dart:1363`) or loader |
| Tombol tutup kamera | Tooltip 'Tutup Kamera' (`lib/features/maintenance/screens/point_camera_view.dart:1380`) | Icon `Icons.close_rounded` (`lib/features/maintenance/screens/point_camera_view.dart:1379`) |
| Tombol bypass barang | Text 'Barang tidak terpasang di lokasi?' (`lib/features/maintenance/screens/point_camera_view.dart:1391`) | Icon `Icons.do_not_disturb_alt_rounded` (`lib/features/maintenance/screens/point_camera_view.dart:1389`) |
| Floating step verifikasi | `VerificationStepCard` (`lib/features/maintenance/screens/point_camera_view.dart:1427`) | Visible when `_isCapturing == true` (`lib/features/maintenance/screens/point_camera_view.dart:1421`) |
| Overlay countdown | `_isCountingDown` (`lib/features/maintenance/screens/point_camera_view.dart:1436`) | Circle `_countdownValue` (`lib/features/maintenance/screens/point_camera_view.dart:1454`), button 'Batal' |

### Actions
| Label (verbatim) | Control | Handler (file:line) | Result |
| Kembali | IconButton | `Navigator.pop(context)` (`lib/features/maintenance/screens/point_camera_view.dart:837`) | Close camera view |
| Kilat / AI Cloud | GestureDetector | `_toggleAiMode()` (`lib/features/maintenance/screens/point_camera_view.dart:881`) | Toggle offline fast mode vs cloud AI vision |
| Off / <N>s | GestureDetector | `_cycleTimer()` (`lib/features/maintenance/screens/point_camera_view.dart:920`) | Cycle timer (0s -> 3s -> 5s -> 10s -> 0s) |
| Full / 3:4 / 1:1 | GestureDetector | `_cycleRatio()` (`lib/features/maintenance/screens/point_camera_view.dart:958`) | Cycle camera aspect ratio |
| Flash | IconButton | `_toggleFlash()` (`lib/features/maintenance/screens/point_camera_view.dart:1004`) | Cycle flash mode (off -> auto -> always -> torch -> off) |
| Viewfinder tap | GestureDetector.onTapDown | `_handleTapToFocus` (`lib/features/maintenance/screens/point_camera_view.dart:1155`) | Focus lens and exposure on tapped coordinate |
| Ganti Kamera Depan/Belakang | IconButton | `_toggleCameraFlip()` (`lib/features/maintenance/screens/point_camera_view.dart:1322`) | Toggle front and back camera |
| Shutter (Capture) | GestureDetector | `_startTimedCapture()` (`lib/features/maintenance/screens/point_camera_view.dart:1332`) | Start timer or take photo and verify |
| Tutup Kamera | IconButton | `Navigator.pop(context)` (`lib/features/maintenance/screens/point_camera_view.dart:1381`) | Close camera view |
| Barang tidak terpasang di lokasi? | TextButton.icon | `_confirmTidakTerpasang()` (`lib/features/maintenance/screens/point_camera_view.dart:1388`) | Open confirmation dialog to mark item as not installed |
| Ya, Tidak Terpasang | ElevatedButton | `Navigator.pop` with result (`lib/features/maintenance/screens/point_camera_view.dart:1264`) | Mark point as `tidakTerpasang` without taking photo |
| Batal (Countdown) | GestureDetector | `_cancelTimer()` (`lib/features/maintenance/screens/point_camera_view.dart:1470`) | Cancel active timer countdown |
| Coba Lagi | ElevatedButton | `_initCam()` (`lib/features/maintenance/screens/point_camera_view.dart:1107`) | Retry camera initialization |

### States
- loading: CircularProgressIndicator on camera init (`lib/features/maintenance/screens/point_camera_view.dart:1126`), shutter button processing (`lib/features/maintenance/screens/point_camera_view.dart:1358`), VerificationStepCard (`lib/features/maintenance/screens/point_camera_view.dart:1427`)
- empty: 'Tidak ada sensor kamera ditemukan' (`lib/features/maintenance/screens/point_camera_view.dart:172`)
- error: 'Kamera gagal diinisialisasi. Pastikan izin kamera aktif lalu coba lagi.' (`lib/features/maintenance/screens/point_camera_view.dart:184`), 'Kamera gagal dimulai (<error>)' (`lib/features/maintenance/screens/point_camera_view.dart:257`), 'Gagal memproses foto. Silakan ambil ulang.' (`lib/features/maintenance/screens/point_camera_view.dart:801`)
- disabled: Switch camera and bypass buttons disabled during capture/countdown (`lib/features/maintenance/screens/point_camera_view.dart:1322`, `1388`)
- success: Navigator pops with `MaintenancePointResult` (`lib/features/maintenance/screens/point_camera_view.dart:695`, `793`)
- offline: '⚡ Mode Kilat: Selesai' (`lib/features/maintenance/screens/point_camera_view.dart:646`), '⚡ Mode Offline Cepat: Foto tersimpan!' (`lib/features/maintenance/screens/point_camera_view.dart:664`), 'Mode Offline: Foto tersimpan aman di HP. Perlu cek manual.' (`lib/features/maintenance/screens/point_camera_view.dart:739`)

### Conditional
- Camera count: `_cameras.length > 1` (`lib/features/maintenance/screens/point_camera_view.dart:1310`) displays switch camera button
- Web platform / iOS: `kIsWeb && defaultTargetPlatform == TargetPlatform.iOS` (`lib/features/maintenance/screens/point_camera_view.dart:341`, `370`) warns flash torch unsupported on iOS browsers
- AI mode: `_isOfflineFastMode` (`lib/features/maintenance/screens/point_camera_view.dart:885`) switches pill between 'Kilat' and 'AI Cloud'
- Capturing state: `_isCapturing` (`lib/features/maintenance/screens/point_camera_view.dart:1421`) shows `VerificationStepCard`
- Countdown active: `_isCountingDown` (`lib/features/maintenance/screens/point_camera_view.dart:1436`) shows timer countdown overlay
- SPV vs teknisi: none in code
- Branch: `_activeLocation.locationTag` and `_activeLocation.tagColor` (`lib/features/maintenance/screens/point_camera_view.dart:849-864`)

### Copy
- 'Arahkan kamera ke objek' (`lib/features/maintenance/screens/point_camera_view.dart:89`)
- 'Menyiapkan kamera...' (`lib/features/maintenance/screens/point_camera_view.dart:160`)
- 'Tidak ada sensor kamera ditemukan' (`lib/features/maintenance/screens/point_camera_view.dart:172`)
- 'Kamera gagal diinisialisasi. Pastikan izin kamera aktif lalu coba lagi.' (`lib/features/maintenance/screens/point_camera_view.dart:184`)
- 'iPhone tidak mengizinkan flash dinyalakan dari browser. Nyalakan flash di aplikasi Kamera HP, atau pakai APK BSS di Android.' (`lib/features/maintenance/screens/point_camera_view.dart:379-380`)
- 'Lampu kilat tidak bisa diaktifkan di perangkat ini.' (`lib/features/maintenance/screens/point_camera_view.dart:381`)
- 'Mode Kilat aktif: foto langsung disimpan, tanpa AI Vision (hemat waktu & sinyal)' (`lib/features/maintenance/screens/point_camera_view.dart:417`)
- 'AI Cloud Aktif: Verifikasi SOP otomatis via Gemini Vision AI Online' (`lib/features/maintenance/screens/point_camera_view.dart:419`)
- 'Fake GPS Terdeteksi' (`lib/features/maintenance/screens/point_camera_view.dart:481`)
- 'Aplikasi mendeteksi Mock Location / Fake GPS aktif pada perangkat ini.\n\nMatikan Fake GPS untuk melanjutkan checklist maintenance sesuai lokasi fisik pos.\n\nKalau kamu pilih Lanjut Darurat, foto ditandai [FAKE GPS DETECTED] dan otomatis jadi Cek Manual buat diaudit Supervisor.' (`lib/features/maintenance/screens/point_camera_view.dart:487-490`)
- 'Batal / Matikan Fake GPS' (`lib/features/maintenance/screens/point_camera_view.dart:495`)
- 'Lanjut Darurat (Ditandai SPV)' (`lib/features/maintenance/screens/point_camera_view.dart:503`)
- 'Memproses foto' (`lib/features/maintenance/screens/point_camera_view.dart:518`)
- '⚡ Mode Kilat: Selesai' (`lib/features/maintenance/screens/point_camera_view.dart:646`)
- '⚡ Mode Offline Cepat: Foto tersimpan!' (`lib/features/maintenance/screens/point_camera_view.dart:664`)
- 'Sedang diverifikasi' (`lib/features/maintenance/screens/point_camera_view.dart:710`)
- 'Gagal memproses foto. Silakan ambil ulang.' (`lib/features/maintenance/screens/point_camera_view.dart:801`)
- 'Kembali' (`lib/features/maintenance/screens/point_camera_view.dart:836`)
- 'Maintenance' (`lib/features/maintenance/screens/point_camera_view.dart:870`)
- 'Kilat' (`lib/features/maintenance/screens/point_camera_view.dart:906`)
- 'AI Cloud' (`lib/features/maintenance/screens/point_camera_view.dart:906`)
- 'Off' (`lib/features/maintenance/screens/point_camera_view.dart:944`)
- 'Full' (`lib/features/maintenance/screens/point_camera_view.dart:968`)
- '3:4' (`lib/features/maintenance/screens/point_camera_view.dart:969`)
- '1:1' (`lib/features/maintenance/screens/point_camera_view.dart:969`)
- 'Flash' (`lib/features/maintenance/screens/point_camera_view.dart:1003`)
- 'Pastikan izin kamera di browser/HP aktif atau tutup aplikasi lain yang sedang menggunakan kamera.' (`lib/features/maintenance/screens/point_camera_view.dart:1101`)
- 'Coba Lagi' (`lib/features/maintenance/screens/point_camera_view.dart:1109`)
- 'Barang tidak terpasang?' (`lib/features/maintenance/screens/point_camera_view.dart:1259`)
- ' akan ditandai TIDAK TERPASANG / tidak ada di lokasi, tanpa perlu foto.' (`lib/features/maintenance/screens/point_camera_view.dart:1261`)
- 'Batal' (`lib/features/maintenance/screens/point_camera_view.dart:1263`, `1483`)
- 'Ya, Tidak Terpasang' (`lib/features/maintenance/screens/point_camera_view.dart:1264`)
- 'Ganti Kamera Depan/Belakang' (`lib/features/maintenance/screens/point_camera_view.dart:1321`)
- 'Tutup Kamera' (`lib/features/maintenance/screens/point_camera_view.dart:1380`)
- 'Barang tidak terpasang di lokasi?' (`lib/features/maintenance/screens/point_camera_view.dart:1391`)
- 'Foto dalam ' (`lib/features/maintenance/screens/point_camera_view.dart:1465`)
- ' detik' (`lib/features/maintenance/screens/point_camera_view.dart:1465`)

## 7. Galeri: `lib/features/history/screens/gallery_screen.dart:15-858`
Opened from: Thumbnail / Galeri Foto button (`lib/features/camera/screens/camera_capture_screen.dart:3125-3127`)
Type: screen

### Fields
| UI element (top to bottom) | Source (field/variable + file:line) | Empty or edge value |
| Judul AppBar | `_isMultiSelect`, `_showAllFlat` (`lib/features/history/screens/gallery_screen.dart:253-254`) | 'N Terpilih', 'Semua Foto', or 'Folder Foto' |
| Subjudul AppBar | `allPhotos.length`, `albums.length` (`lib/features/history/screens/gallery_screen.dart:261`) | 'N Foto' or 'N Folder' |
| Tombol mode tampilan | `_showAllFlat` (`lib/features/history/screens/gallery_screen.dart:279`) | Icons `folder_copy_rounded` or `grid_view_rounded` |
| Tombol Pilih | Text 'Pilih' (`lib/features/history/screens/gallery_screen.dart:297`) | Visible when `allPhotos.isNotEmpty` (`lib/features/history/screens/gallery_screen.dart:286`) |
| Tombol Pilih/Batal Semua | `_selectedImagePaths` (`lib/features/history/screens/gallery_screen.dart:321`) | 'Batal Semua' or 'Pilih Semua' (`lib/features/history/screens/gallery_screen.dart:322-323`) |
| Tombol Batal multi-select | Text 'Batal' (`lib/features/history/screens/gallery_screen.dart:335`) | Fixed string |
| State kosong galeri | Text 'Belum Ada Foto Tersimpan' (`lib/features/history/screens/gallery_screen.dart:362`) | Subtitle 'Foto absensi dan maintenance ber-watermark akan muncul di sini.' (`lib/features/history/screens/gallery_screen.dart:372`) |
| Cover thumbnail album | `AppFileImage(album.coverImagePath)` (`lib/features/history/screens/gallery_screen.dart:442`) | Fallback icon `Icons.folder_rounded` (`lib/features/history/screens/gallery_screen.dart:447`) |
| Badge jumlah foto album | `album.photos.length` (`lib/features/history/screens/gallery_screen.dart:460`) | Pill bottom-right on thumbnail |
| Icon kategori album | `album.icon`, `album.badgeColor` (`lib/features/history/screens/gallery_screen.dart:486`) | Circle badge indicator |
| Judul album | `album.title` (`lib/features/history/screens/gallery_screen.dart:491`) | Template / submission name |
| Subjudul album | `album.subtitle` (`lib/features/history/screens/gallery_screen.dart:506`) | POS name or formatted date |
| Tanggal album | `album.date` (`lib/features/history/screens/gallery_screen.dart:521`) | Formatted full date string |
| Label count album | Text '${album.photos.length} Foto ❯' (`lib/features/history/screens/gallery_screen.dart:533`) | Fixed trailing indicator |
| Thumbnail item grid foto | `AppFileImage(item.imagePath)` (`lib/features/history/screens/gallery_screen.dart:733`) | Fallback icon `Icons.broken_image_rounded` (`lib/features/history/screens/gallery_screen.dart:738`) |
| Indicator centang seleksi | `_selectedImagePaths.contains` (`lib/features/history/screens/gallery_screen.dart:750`) | Visible when `_isMultiSelect == true` (`lib/features/history/screens/gallery_screen.dart:742`) |
| Indicator zoom foto | `Icons.zoom_in_rounded` (`lib/features/history/screens/gallery_screen.dart:770`) | Top-right overlay circle icon |
| Judul item foto | `item.title` (`lib/features/history/screens/gallery_screen.dart:782`) | Max 1 line (`lib/features/history/screens/gallery_screen.dart:783`) |
| Subjudul item foto | `item.subtitle` (`lib/features/history/screens/gallery_screen.dart:794`) | Max 1 line (`lib/features/history/screens/gallery_screen.dart:795`) |
| Timestamp item foto | `item.timestamp` (`lib/features/history/screens/gallery_screen.dart:804`) | Formatted date and time string |
| Tombol Download (Bottom bar) | `_selectedImagePaths.length`, `_isDownloading` (`lib/features/history/screens/gallery_screen.dart:203-205`) | 'Menyimpan Foto...' or 'Download (N Foto)' |

### Actions
| Label (verbatim) | Control | Handler (file:line) | Result |
| Lihat Folder / Lihat Semua Foto | IconButton | `setState(() => _showAllFlat = !_showAllFlat)` (`lib/features/history/screens/gallery_screen.dart:283`) | Toggle between album list and flat grid |
| Pilih | TextButton.icon | `setState(() => _isMultiSelect = true)` (`lib/features/history/screens/gallery_screen.dart:290`) | Enter multi-select mode |
| Pilih Semua / Batal Semua | TextButton | `setState(...)` (`lib/features/history/screens/gallery_screen.dart:311`) | Select or deselect all photos |
| Batal | TextButton | `setState(() => _isMultiSelect = false)` (`lib/features/history/screens/gallery_screen.dart:330`) | Exit multi-select mode |
| <Album Card Item> | InkWell | `setState(() => _selectedAlbum = album)` (`lib/features/history/screens/gallery_screen.dart:422`) | Drill down into album folder view |
| Kembali | IconButton | `setState(() => _selectedAlbum = null)` (`lib/features/history/screens/gallery_screen.dart:570`) | Return from album drill-down to folder list |
| <Photo Card Item> (Tap) | GestureDetector | `PhotoPreviewDialog.show` (`lib/features/history/screens/gallery_screen.dart:694`) | Open high-resolution photo preview |
| <Photo Card Item> (Long Press) | GestureDetector | `setState(() => _isMultiSelect = true)` (`lib/features/history/screens/gallery_screen.dart:678`) | Enter multi-select and select tapped item |
| <Photo Card Item> (Select Tap) | GestureDetector | `setState(...)` (`lib/features/history/screens/gallery_screen.dart:686`) | Toggle photo selection |
| Download (N Foto) | ElevatedButton.icon | `_downloadSelectedPhotos()` (`lib/features/history/screens/gallery_screen.dart:193`) | Save selected photos to gallery/downloads |

### States
- loading: CircularProgressIndicator inside download button when `_isDownloading == true` (`lib/features/history/screens/gallery_screen.dart:195-199`)
- empty: 'Belum Ada Foto Tersimpan' (`lib/features/history/screens/gallery_screen.dart:362`), 'Foto absensi dan maintenance ber-watermark akan muncul di sini.' (`lib/features/history/screens/gallery_screen.dart:372`)
- error: 'Gagal mengunduh foto' / 'Gagal menyimpan foto ke Galeri HP' (`lib/features/history/screens/gallery_screen.dart:158-159`)
- disabled: Download button disabled when `_selectedImagePaths.isEmpty || _isDownloading` (`lib/features/history/screens/gallery_screen.dart:191`)
- success: SnackBar '<N> foto diunduh ke Files/Downloads (bukan Galeri)' (Web) / '<N> foto tersimpan di Galeri HP (Album BSS Parking)' (Android) (`lib/features/history/screens/gallery_screen.dart:154-156`)
- offline: none in code

### Conditional
- Web vs Android: `kIsWeb` (`lib/features/history/screens/gallery_screen.dart:54`, `88`, `154`, `440`) determines file existence check and download feedback wording ('Files/Downloads' on Web vs 'Galeri HP (Album BSS Parking)' on Android)
- Multi-select active: `_isMultiSelect` (`lib/features/history/screens/gallery_screen.dart:253`, `274`, `346`, `577`, `742`) toggles appbar header, selection action buttons, and bottom action bar
- Album folder view: `_selectedAlbum != null` (`lib/features/history/screens/gallery_screen.dart:238`) renders folder drill-down view instead of folder list
- View mode: `_showAllFlat` (`lib/features/history/screens/gallery_screen.dart:380`) switches between flat grid and album folder list
- Dark mode: `ThemeService.isDarkMode(context)` (`lib/features/history/screens/gallery_screen.dart:169`, `230`, `389`, `557`, `655`) adapts surfaces, borders, and typography
- SPV vs teknisi: none in code
- Branch: none in code

### Copy
- ' foto diunduh ke Files/Downloads (bukan Galeri)' (`lib/features/history/screens/gallery_screen.dart:155`)
- ' foto tersimpan di Galeri HP (Album BSS Parking)' (`lib/features/history/screens/gallery_screen.dart:156`)
- 'Gagal mengunduh foto' (`lib/features/history/screens/gallery_screen.dart:158`)
- 'Gagal menyimpan foto ke Galeri HP' (`lib/features/history/screens/gallery_screen.dart:159`)
- 'Menyimpan Foto...' (`lib/features/history/screens/gallery_screen.dart:203`)
- 'Download (' (`lib/features/history/screens/gallery_screen.dart:204`)
- ' Foto)' (`lib/features/history/screens/gallery_screen.dart:204`)
- ' Terpilih' (`lib/features/history/screens/gallery_screen.dart:253`, `578`)
- 'Semua Foto' (`lib/features/history/screens/gallery_screen.dart:254`)
- 'Folder Foto' (`lib/features/history/screens/gallery_screen.dart:254`)
- ' Foto' (`lib/features/history/screens/gallery_screen.dart:261`, `591`)
- ' Folder' (`lib/features/history/screens/gallery_screen.dart:261`)
- 'Lihat Folder' (`lib/features/history/screens/gallery_screen.dart:277`)
- 'Lihat Semua Foto' (`lib/features/history/screens/gallery_screen.dart:277`)
- 'Pilih' (`lib/features/history/screens/gallery_screen.dart:297`)
- 'Batal Semua' (`lib/features/history/screens/gallery_screen.dart:322`, `624`)
- 'Pilih Semua' (`lib/features/history/screens/gallery_screen.dart:323`, `625`)
- 'Batal' (`lib/features/history/screens/gallery_screen.dart:335`, `637`)
- 'Belum Ada Foto Tersimpan' (`lib/features/history/screens/gallery_screen.dart:362`)
- 'Foto absensi dan maintenance ber-watermark akan muncul di sini.' (`lib/features/history/screens/gallery_screen.dart:372`)
- ' Foto ❯' (`lib/features/history/screens/gallery_screen.dart:533`)
- 'Kembali' (`lib/features/history/screens/gallery_screen.dart:567`)
- 'Pilih Foto' (`lib/features/history/screens/gallery_screen.dart:601`)
