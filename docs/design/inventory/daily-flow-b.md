## 1. Setup Maintenance: `lib/features/maintenance/widgets/maintenance_setup_dialog.dart:12-2280`
Opened from: `lib/features/camera/screens/camera_capture_screen.dart:451`, `lib/features/camera/widgets/template_quick_picker_modal.dart:214`, `lib/features/daily_tasks/screens/teknisi_daily_tasks_screen.dart:738`, `lib/features/templates/screens/template_list_screen.dart:674`
Type: dialog

### Fields
| UI element (top to bottom) | Source (field/variable + file:line) | Empty or edge value |
| Header Icon | `_unitIcon` (`maintenance_setup_dialog.dart:668`) | `Icons.build_rounded` (`maintenance_setup_dialog.dart:195`) |
| Header Title | `widget.initialTemplate.nama` / `_unitTitle` (`maintenance_setup_dialog.dart:676-679`) | `'Pilih Unit Maintenance'` (`maintenance_setup_dialog.dart:155`) |
| Header Subtitle | `_unitSubtitle` (`maintenance_setup_dialog.dart:690-698`) | `'Pilih unit yang dicek'` (`maintenance_setup_dialog.dart:174`) |
| Nama Teknisi / Support Input | `_supportNameController.text` (`maintenance_setup_dialog.dart:708`) | fallback `'Teknisi BSS'` if empty (`maintenance_setup_dialog.dart:307`) |
| Lokasi Parkir Dropdown | `_selectedLocation` (`maintenance_setup_dialog.dart:758`) | `LocationService.currentPos` (`maintenance_setup_dialog.dart:64`) |
| Perangkat Scope Selector | `_isOnlyKasir` (`maintenance_setup_dialog.dart:870, 933`) | `false` default (`maintenance_setup_dialog.dart:38`) |
| Arsitektur Server Toggle | `_isServerKasirTerpisah` (`maintenance_setup_dialog.dart:1020, 1076`) | `true` (Terpisah) (`maintenance_setup_dialog.dart:40`) |
| OS Server Selector | `_serverOs` (`maintenance_setup_dialog.dart:1220, 1318`) | `'linux'` default (`maintenance_setup_dialog.dart:44`) |
| Jumlah PC Kasir Stepper | `_kasirCount` (`maintenance_setup_dialog.dart:1416-1455`) | `1` min (`maintenance_setup_dialog.dart:43, 1416`) |
| Unit Range Start Stepper | `_startUnit` (`maintenance_setup_dialog.dart:1780-1815`) | `1` min, `20` max (`maintenance_setup_dialog.dart:1782, 1807`) |
| Unit Range End Stepper | `_endUnit` (`maintenance_setup_dialog.dart:1820-1878`) | `1` min, `20` max (`maintenance_setup_dialog.dart:1826, 1871`) |
| SOP Manless Segmented Tile | `_manlessRole` (`maintenance_setup_dialog.dart:529, 544, 559`) | `'IN'` default (`maintenance_setup_dialog.dart:37`) |
| Pos Mode Segmented Tile | `_isBooth` (`maintenance_setup_dialog.dart:39, 456`) | `false` (Pos Kasir) (`maintenance_setup_dialog.dart:39`) |

### Actions
| Label (verbatim) | Control | Handler (file:line) | Result |
| Batal | TextButton | `Navigator.of(context).pop()` (`maintenance_setup_dialog.dart:2236`) | Closes dialog without changes |
| Mulai Checklist | ElevatedButton | `_generateAndOpenChecklist` (`maintenance_setup_dialog.dart:2251`) | Pushes `MaintenanceChecklistScreen` (`maintenance_setup_dialog.dart:284`) |
| Server & Kasir | InkWell | `setState(() => _isOnlyKasir = false)` (`maintenance_setup_dialog.dart:870`) | Selects server & kasir mode |
| Hanya Kasir | InkWell | `setState(() => _isOnlyKasir = true)` (`maintenance_setup_dialog.dart:933`) | Selects kasir-only mode |
| Terpisah | InkWell | `setState(() => _isServerKasirTerpisah = true)` (`maintenance_setup_dialog.dart:1020`) | Sets server/kasir separated |
| Gabung (1 PC) | InkWell | `setState(() => _isServerKasirTerpisah = false)` (`maintenance_setup_dialog.dart:1076`) | Sets server/kasir combined |
| Linux | InkWell | `setState(() => _serverOs = 'linux')` (`maintenance_setup_dialog.dart:1220`) | Selects Linux OS |
| Windows | InkWell | `setState(() => _serverOs = 'windows')` (`maintenance_setup_dialog.dart:1318`) | Selects Windows OS |
| IN | InkWell | `setState(() => _manlessRole = 'IN')` (`maintenance_setup_dialog.dart:532`) | Sets manless SOP to IN |
| OUT | InkWell | `setState(() => _manlessRole = 'OUT')` (`maintenance_setup_dialog.dart:547`) | Sets manless SOP to OUT |
| PEP | InkWell | `setState(() => _manlessRole = 'PEP')` (`maintenance_setup_dialog.dart:559`) | Sets manless SOP to PEP |

### States
- loading: none in code
- empty: none in code
- error: none in code
- disabled: Stepper `-` disabled at 1 (`maintenance_setup_dialog.dart:1416, 1782, 1826`), `+` disabled at 20 (`maintenance_setup_dialog.dart:1807, 1871`)
- success: none in code
- offline: none in code

### Conditional
- `widget.initialTemplate.jenis == TemplateCategory.maintServer`: shows server/kasir options (`maintenance_setup_dialog.dart:823`)
- `widget.initialTemplate.jenis == TemplateCategory.maintLengkap`: shows complete checklist area selectors (`maintenance_setup_dialog.dart:51, 694`)
- `BranchService.instance.currentBranch != AppBranch.manado`: shows OUT SOP tile for Manless (`maintenance_setup_dialog.dart:536`)
- `ThemeService.isDarkMode(context)` / `isDark`: adjusts dialog colors (`maintenance_setup_dialog.dart:624-644`)

### Copy
- 'Nama Teknisi / Support' (`maintenance_setup_dialog.dart:710`)
- 'Contoh: Farhan Lakoro' (`maintenance_setup_dialog.dart:715`)
- 'Lokasi Parkir' (`maintenance_setup_dialog.dart:767`)
- 'Pilih Perangkat' (`maintenance_setup_dialog.dart:852`)
- 'Pilih cek Server & Kasir atau khusus PC Kasir saja' (`maintenance_setup_dialog.dart:862`)
- 'Server & Kasir' (`maintenance_setup_dialog.dart:908`)
- 'Hanya Kasir' (`maintenance_setup_dialog.dart:970`)
- 'Jumlah PC Kasir' (`maintenance_setup_dialog.dart:1394`)
- 'PC Kasir 1, PC Kasir 2, dst (6 foto / unit)' (`maintenance_setup_dialog.dart:1402`)
- 'Pilih SOP Manless' (`maintenance_setup_dialog.dart:507`)
- 'IN = cek rutin • OUT = IN + 4 perangkat • PEP = fisik pulau' (`maintenance_setup_dialog.dart:517`)
- 'Ikut dicek: 1 PC Server (6 foto) — cakupan 4 area' (DASH) (`maintenance_setup_dialog.dart:2124`)
- 'Tidak dicek — cakupan 3 area (Gate + Manless + Pos)' (DASH) (`maintenance_setup_dialog.dart:2125`)
- 'Batal' (`maintenance_setup_dialog.dart:2244`)
- 'Mulai Checklist' (`maintenance_setup_dialog.dart:2264`)

## 2. Lihat Bukti: `lib/features/daily_tasks/widgets/completed_daily_task_modal.dart:13-753`
Opened from: `lib/features/daily_tasks/screens/teknisi_daily_tasks_screen.dart:678` (`TextButton.icon` 'Lihat Bukti'), `lib/features/daily_tasks/widgets/spv_task_card.dart:463` (`InkWell` 'Bukti')
Type: bottom sheet / dialog

### Fields
| UI element (top to bottom) | Source (field/variable + file:line) | Empty or edge value |
| Status Header Badge | `completedTime` (`completed_daily_task_modal.dart:179-181, 218`) | `'-'` when empty (`completed_daily_task_modal.dart:181`) |
| Read-Only Header Chip | static label (`completed_daily_task_modal.dart:241`) | always `'Read-Only'` (`completed_daily_task_modal.dart:241`) |
| Task Title | `task.judul` (`completed_daily_task_modal.dart:272`) | empty string if unset (`completed_daily_task_modal.dart:272`) |
| Info Row Lokasi | `task.posTag`, `task.posName` (`completed_daily_task_modal.dart:296`) | `task.posName` only when posTag empty (`completed_daily_task_modal.dart:296`) |
| Info Row Teknisi | `task.teknisiNama` (`completed_daily_task_modal.dart:303`) | empty string if unset (`completed_daily_task_modal.dart:303`) |
| Info Row Tanggal | `task.tanggal` (`completed_daily_task_modal.dart:310`) | empty string if unset (`completed_daily_task_modal.dart:310`) |
| Info Row Kategori | `task.isMaintenance` (`completed_daily_task_modal.dart:317`) | `'SOP Maintenance'` vs `'Tugas Khusus'` (`completed_daily_task_modal.dart:317`) |
| Deskripsi Container | `task.deskripsi` (`completed_daily_task_modal.dart:345`) | hidden if empty (`completed_daily_task_modal.dart:325`) |
| Catatan Teknisi Container | `task.catatanTeknisi` (`completed_daily_task_modal.dart:380`) | hidden if empty or `'-'` (`completed_daily_task_modal.dart:352-354`) |
| Foto Bukti Grid | `task.fotoBuktiUrls` (`completed_daily_task_modal.dart:460-621`) | shows empty state box if empty (`completed_daily_task_modal.dart:434-455`) |
| Video Bukti List | `videoList` from `task.fotoBuktiUrls` (`completed_daily_task_modal.dart:623-711`) | hidden if no `.mp4`/`.mov`/`.mkv` (`completed_daily_task_modal.dart:623`) |

### Actions
| Label (verbatim) | Control | Handler (file:line) | Result |
| Tutup | IconButton | `Navigator.of(context).pop()` (`completed_daily_task_modal.dart:255`) | Closes bottom sheet/dialog |
| Unduh Semua | OutlinedButton.icon | `_downloadAllPhotos` (`completed_daily_task_modal.dart:410`) | Saves all photos to gallery/downloads |
| Zoom | InkWell | `PhotoPreviewDialog.show` (`completed_daily_task_modal.dart:547`) | Opens full photo preview with AI reanalyze |
| Unduh | InkWell | `_downloadSinglePhoto` (`completed_daily_task_modal.dart:577`) | Saves single photo to gallery/downloads |
| Buka | ElevatedButton.icon | `_openVideo(videoUrl)` (`completed_daily_task_modal.dart:691`) | Launches video URL or local file externally |

### States
- loading: `'Mengunduh...'` (`completed_daily_task_modal.dart:419`), `'...'` (`completed_daily_task_modal.dart:601`), `CircularProgressIndicator` (`completed_daily_task_modal.dart:415, 592`)
- empty: `'Tidak ada lampiran foto bukti pada tugas ini.'` (`completed_daily_task_modal.dart:449`)
- error: `'Gagal mengunduh Foto #${index + 1}'` (`completed_daily_task_modal.dart:85`), `'Gagal membuka video.'` (`completed_daily_task_modal.dart:161`)
- disabled: `_isDownloadingAll ? null : _downloadAllPhotos` (`completed_daily_task_modal.dart:410`), `isDownloading ? null : () => _downloadSinglePhoto` (`completed_daily_task_modal.dart:577`)
- success: `'Foto #${index + 1} tersimpan di Galeri HP (Album: BSS Parking)'` (`completed_daily_task_modal.dart:84`), `'Berhasil mengunduh $successCount/${widget.task.fotoBuktiUrls.length} foto ke Galeri (Album: BSS Parking)'` (`completed_daily_task_modal.dart:119`)
- offline: none in code

### Conditional
- `MediaQuery.of(context).size.width > 600`: renders `Dialog` with maxWidth 620 instead of `ModalBottomSheet` (`completed_daily_task_modal.dart:24-42`)
- `kIsWeb`: shows `'Foto #${index + 1} diunduh ke Files/Downloads (bukan Galeri)'` (`completed_daily_task_modal.dart:82-84`)
- `task.fotoBuktiUrls.length > 1`: shows 'Unduh Semua' button (`completed_daily_task_modal.dart:408`)
- `Theme.of(context).brightness == Brightness.dark`: dark surface palette (`completed_daily_task_modal.dart:172-177`)

### Copy
- 'Selesai · $completedTime' (`completed_daily_task_modal.dart:218`)
- 'Read-Only' (`completed_daily_task_modal.dart:241`)
- 'Tutup' (`completed_daily_task_modal.dart:254`)
- 'Lokasi' (`completed_daily_task_modal.dart:295`)
- 'Teknisi' (`completed_daily_task_modal.dart:302`)
- 'Tanggal' (`completed_daily_task_modal.dart:309`)
- 'Kategori' (`completed_daily_task_modal.dart:316`)
- 'SOP Maintenance' (`completed_daily_task_modal.dart:317`)
- 'Tugas Khusus' (`completed_daily_task_modal.dart:317`)
- 'Deskripsi Tugas' (`completed_daily_task_modal.dart:328`)
- 'Catatan Teknisi Saat Penyelesaian' (`completed_daily_task_modal.dart:357`)
- 'Foto Bukti Pengerjaan (${task.fotoBuktiUrls.length})' (`completed_daily_task_modal.dart:401`)
- 'Unduh Semua' (`completed_daily_task_modal.dart:419`)
- 'Mengunduh...' (`completed_daily_task_modal.dart:419`)
- 'Tidak ada lampiran foto bukti pada tugas ini.' (`completed_daily_task_modal.dart:449`)
- 'Zoom' (`completed_daily_task_modal.dart:564`)
- 'Unduh' (`completed_daily_task_modal.dart:601`)
- 'Video Bukti Pengerjaan (${videoList.length})' (`completed_daily_task_modal.dart:634`)
- 'Video Bukti #${vIdx + 1}' (`completed_daily_task_modal.dart:672`)
- 'Buka' (`completed_daily_task_modal.dart:693`)

## 3. Serah terima tugas: `lib/features/daily_tasks/widgets/task_handover_dialog.dart:7-391`
Opened from: `lib/features/daily_tasks/screens/teknisi_daily_tasks_screen.dart:707` (`TextButton` 'Belum Selesai', handler `_serahkanTugas` at line 130), `lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart:1857` (`SpvTaskCard.onHandover`, handler `_alihkanTugas` at line 170)
Type: bottom sheet

### Fields
| UI element (top to bottom) | Source (field/variable + file:line) | Empty or edge value |
| Dialog Title | `widget.judulDialog` (`task_handover_dialog.dart:151`) | `'Belum Selesai & Serah Terima'` default (`task_handover_dialog.dart:26`), `'Alihkan Tugas'` for SPV (`spv_task_dispatcher_screen.dart:177`) |
| Task Title | `widget.judul` (`task_handover_dialog.dart:160`) | empty string if unset (`task_handover_dialog.dart:160`) |
| Task Location & Owner | `widget.lokasi`, `widget.pemilik` (`task_handover_dialog.dart:162-165`) | shows only `widget.lokasi` when pemilik is null/empty (`task_handover_dialog.dart:164`) |
| Section Header Target | `widget.tujuanLabel` (`task_handover_dialog.dart:171`) | `'Lanjut ke Teknisi'` default (`task_handover_dialog.dart:27`), `'Alihkan Ke'` for SPV (`spv_task_dispatcher_screen.dart:178`) |
| Radio Terbuka | `_penerus.isEmpty` (`task_handover_dialog.dart:176`) | `true` default (empty string) (`task_handover_dialog.dart:76`) |
| Radio Teknisi List | `widget.teknisiOptions` (`task_handover_dialog.dart:184-197`) | empty list if no technicians (`task_handover_dialog.dart:25`) |
| Alasan Cepat Chips | `TaskHandoverDialog.alasanCepat` (`task_handover_dialog.dart:32-39, 205`) | 6 predefined reasons (`task_handover_dialog.dart:32-39`) |
| Alasan Input Field | `_alasanCtrl.text` (`task_handover_dialog.dart:248-265`) | validation fails if empty (`task_handover_dialog.dart:89, 268`) |

### Actions
| Label (verbatim) | Control | Handler (file:line) | Result |
| Terbuka (siapa pun boleh ambil) | InkWell | `setState(() => _penerus = '')` (`task_handover_dialog.dart:177`) | Sets target to open task pool |
| <teknisi name> | InkWell | `setState(() => _penerus = t)` (`task_handover_dialog.dart:189`) | Selects specific successor technician |
| <alasan cepat chip> | InkWell | toggle text in `_alasanCtrl` (`task_handover_dialog.dart:207-210`) | Fills or unselects reason in text field |
| Serahkan Tugas / Alihkan Sekarang | FilledButton | `_submit` (`task_handover_dialog.dart:87, 290`) | Validates reason, executes handover, pops sheet |
| Batal | TextButton | `Navigator.pop(context)` (`task_handover_dialog.dart:319`) | Cancels handover and closes sheet |

### States
- loading: `'Menyimpan...'` (`task_handover_dialog.dart:305`), `CircularProgressIndicator` (`task_handover_dialog.dart:303`)
- empty: none in code
- error: `'Alasan wajib diisi'` (`task_handover_dialog.dart:268`), `'Gagal menyimpan, periksa sinyal lalu coba lagi.'` (`task_handover_dialog.dart:281`)
- disabled: `FilledButton(onPressed: _mengirim ? null : _submit)` (`task_handover_dialog.dart:290`), `TextButton(onPressed: _mengirim ? null : ...)` (`task_handover_dialog.dart:319`)
- success: SnackBar `'Tugas diserahkan ke $penerus.'` / `'Tugas dilepas ke daftar terbuka untuk shift berikutnya.'` (`teknisi_daily_tasks_screen.dart:148-149`), `'Tugas dialihkan ke $penerus.'` (`spv_task_dispatcher_screen.dart:193`)
- offline: none in code

### Conditional
- `widget.pemilik == null || widget.pemilik!.isEmpty`: omits `' · sekarang di ${widget.pemilik}'` (`task_handover_dialog.dart:162-165`)
- `error` (`_triedSubmit && _alasanCtrl.text.trim().isEmpty`): shows red underline and error text (`task_handover_dialog.dart:122, 245, 266-269`)
- `_gagal`: shows connection failure message (`task_handover_dialog.dart:279-284`)
- `ThemeService.isDarkMode(context)` / `isDark`: sets dark theme container colors (`task_handover_dialog.dart:115-121`)

### Copy
- 'Belum Selesai & Serah Terima' (`task_handover_dialog.dart:26`)
- 'Alihkan Tugas' (`spv_task_dispatcher_screen.dart:177`)
- 'Lanjut ke Teknisi' (`task_handover_dialog.dart:27`)
- 'Alihkan Ke' (`spv_task_dispatcher_screen.dart:178`)
- 'Terbuka (siapa pun boleh ambil)' (`task_handover_dialog.dart:174`)
- 'Masuk daftar Tugas Terbuka shift berikutnya' (`task_handover_dialog.dart:175`)
- 'Alasan Serah Terima' (`task_handover_dialog.dart:200`)
- 'Waktu habis (akhir shift)' (`task_handover_dialog.dart:33`)
- 'Material belum datang' (`task_handover_dialog.dart:34`)
- 'Hujan / kondisi gelap' (`task_handover_dialog.dart:35`)
- 'Alat kurang' (`task_handover_dialog.dart:36`)
- 'Butuh 2 orang' (`task_handover_dialog.dart:37`)
- 'Lokasi terkunci' (`task_handover_dialog.dart:38`)
- 'Tulis alasan singkat atau pilih salah satu di atas' (`task_handover_dialog.dart:261`)
- 'Alasan wajib diisi' (`task_handover_dialog.dart:268`)
- 'Gagal menyimpan, periksa sinyal lalu coba lagi.' (`task_handover_dialog.dart:281`)
- 'Menyimpan...' (`task_handover_dialog.dart:305`)
- 'Serahkan Tugas' (`task_handover_dialog.dart:28`)
- 'Alihkan Sekarang' (`spv_task_dispatcher_screen.dart:179`)
- 'Batal' (`task_handover_dialog.dart:320`)

## 4. Buat Tugas: `lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart:1284-1553`
Opened from: `lib/features/daily_tasks/screens/spv_task_dispatcher_screen.dart:987` (`FloatingActionButton.extended` 'Buat Tugas')
Type: bottom sheet

### Fields
| UI element (top to bottom) | Source (field/variable + file:line) | Empty or edge value |
| Header Title | static label (`spv_task_dispatcher_screen.dart:1380`) | `'Buat Tugas Baru'` (`spv_task_dispatcher_screen.dart:1380`) |
| Header Subtitle | static label (`spv_task_dispatcher_screen.dart:1389`) | `'Pilih kategori dan isi detail tugas'` (`spv_task_dispatcher_screen.dart:1389`) |
| Kategori Tabs | `_formTab` (`spv_task_dispatcher_screen.dart:1417, 1428, 1441`) | `'rutin'`, `'maintenance'`, `'khusus'` (`spv_task_dispatcher_screen.dart:1417-1444`) |
| Teknisi Dropdown | `_selectedTech` (`spv_task_dispatcher_screen.dart:1605`) | first technician in list (`spv_task_dispatcher_screen.dart:66`) |
| Template SOP Dropdown | `_selectedTemplateId` (`spv_task_dispatcher_screen.dart:1652`) | `_templates.first['id']` (`spv_task_dispatcher_screen.dart:1652`) |
| Dikerjakan Bersama Multi-select | `_pesertaTerpilih` (`spv_task_dispatcher_screen.dart:1673`) | `'Tidak ada teknisi tambahan'` when empty (`spv_task_dispatcher_screen.dart:1673`) |
| Lokasi Pekerjaan Input | `_lokasiCtrl.text` (`spv_task_dispatcher_screen.dart:1728`) | required, error SnackBar if empty (`spv_task_dispatcher_screen.dart:892`) |
| Detail Pekerjaan Input | `_pekerjaanCtrl.text` (`spv_task_dispatcher_screen.dart:1743`) | required, error SnackBar if empty (`spv_task_dispatcher_screen.dart:899`) |
| Tanggal Penugasan Selector | `_targetDispatchDate` (`spv_task_dispatcher_screen.dart:1761`) | `DateTime.now()` default (`spv_task_dispatcher_screen.dart:67`) |
| Catatan Input | `_catatanCtrl.text` (`spv_task_dispatcher_screen.dart:1777`) | optional, empty allowed (`spv_task_dispatcher_screen.dart:1770`) |

### Actions
| Label (verbatim) | Control | Handler (file:line) | Result |
| Tutup | IconButton | `handleClose` (`spv_task_dispatcher_screen.dart:1301, 1397`) | Warns if dirty, pops sheet |
| Rutin | InkWell | `_formTab = 'rutin'` (`spv_task_dispatcher_screen.dart:1420`) | Switches to Shift 1 routine tasks form |
| Maintenance | InkWell | `_formTab = 'maintenance'` (`spv_task_dispatcher_screen.dart:1431`) | Switches to SOP template task form |
| Tugas Khusus | InkWell | `_formTab = 'khusus'` (`spv_task_dispatcher_screen.dart:1444`) | Switches to custom task form |
| Simpan Tugas | FilledButton | `handleSubmit` -> `_submitTask` (`spv_task_dispatcher_screen.dart:1306, 1498`) | Validates fields and saves task |
| Tugaskan 2 Rutin Shift 1 | FilledButton | `handleSubmit` -> `_dispatchShift1ManadoRoutine` (`spv_task_dispatcher_screen.dart:1308, 1498`) | Shows confirm dialog, creates 2 routine tasks |

### States
- loading: `'Menyimpan...'` (`spv_task_dispatcher_screen.dart:1520`), `CircularProgressIndicator` (`spv_task_dispatcher_screen.dart:1515`)
- empty: `'Tidak ada teknisi tambahan'` (`spv_task_dispatcher_screen.dart:1673`)
- error: `'Lokasi harus diisi.'` (`spv_task_dispatcher_screen.dart:894`), `'Detail pekerjaan harus diisi.'` (`spv_task_dispatcher_screen.dart:901`), `'Gagal kirim tugas. Cek koneksi, coba lagi.'` (`spv_task_dispatcher_screen.dart:945`)
- disabled: `FilledButton(onPressed: _isLoading ? null : handleSubmit)` (`spv_task_dispatcher_screen.dart:1498`)
- success: SnackBar `'Tugas dibuat$suffix untuk $_selectedTech (${_formatDateDisplay(_targetDispatchDate)})'` (`spv_task_dispatcher_screen.dart:935`)
- offline: `' (Tersimpan di Perangkat / Mode Offline)'` suffix on local ID (`spv_task_dispatcher_screen.dart:932`)

### Conditional
- `BranchService.instance.currentBranch == AppBranch.manado`: displays 'Rutin' tab (`spv_task_dispatcher_screen.dart:1414`)
- `_formTab == 'rutin'`: switches button text to 'Tugaskan 2 Rutin Shift 1' and hides location/template fields (`spv_task_dispatcher_screen.dart:1531, 1618`)
- `_taskCategory == 'maintenance'`: shows 'Template SOP' dropdown (`spv_task_dispatcher_screen.dart:1647`)
- `_isFormDirty`: triggers discard draft confirmation on back/close (`spv_task_dispatcher_screen.dart:1302, 1322`)
- `ThemeService.isDarkMode(context)` / `isDark`: sets dark theme styling (`spv_task_dispatcher_screen.dart:1285-1288`)

### Copy
- 'Buat Tugas Baru' (`spv_task_dispatcher_screen.dart:1380`)
- 'Pilih kategori dan isi detail tugas' (`spv_task_dispatcher_screen.dart:1389`)
- 'Tutup' (`spv_task_dispatcher_screen.dart:1396`)
- 'Rutin' (`spv_task_dispatcher_screen.dart:1417`)
- 'Maintenance' (`spv_task_dispatcher_screen.dart:1428`)
- 'Tugas Khusus' (`spv_task_dispatcher_screen.dart:1441`)
- 'Pastikan data sudah sesuai sebelum menyimpan.' (`spv_task_dispatcher_screen.dart:1470`)
- 'Menyimpan...' (`spv_task_dispatcher_screen.dart:1520`)
- 'Simpan Tugas' (`spv_task_dispatcher_screen.dart:1531`)
- 'Tugaskan 2 Rutin Shift 1' (`spv_task_dispatcher_screen.dart:1531`)
- 'Teknisi (Pemilik Tugas)' (`spv_task_dispatcher_screen.dart:1601`)
- 'Teknisi Shift 1' (`spv_task_dispatcher_screen.dart:1601`)
- 'Template SOP' (`spv_task_dispatcher_screen.dart:1648`)
- 'Dikerjakan Bersama (Opsional)' (`spv_task_dispatcher_screen.dart:1665`)
- 'Lokasi Pekerjaan' (`spv_task_dispatcher_screen.dart:1722`)
- 'Contoh: PKM, PBM, TBM' (`spv_task_dispatcher_screen.dart:1731`)
- 'Detail Pekerjaan' (`spv_task_dispatcher_screen.dart:1736`)
- 'Contoh: Pemasangan lampu pos' (`spv_task_dispatcher_screen.dart:1747`)
- 'Tanggal Penugasan' (`spv_task_dispatcher_screen.dart:1753`)
- 'Catatan (Opsional)' (`spv_task_dispatcher_screen.dart:1770`)
- 'Contoh: Lampu cadangan di gudang pos' (`spv_task_dispatcher_screen.dart:1781`)
- 'Lokasi harus diisi.' (`spv_task_dispatcher_screen.dart:894`)
- 'Detail pekerjaan harus diisi.' (`spv_task_dispatcher_screen.dart:901`)

## 5. Tandai Sudah Diperbaiki: `lib/features/maintenance/widgets/temuan_fix_sheet.dart:22-612`
Opened from: `lib/features/maintenance/screens/maintenance_location_detail_screen.dart:824` (`ElevatedButton` 'Tandai Diperbaiki' at line 1258)
Type: bottom sheet

### Fields
| UI element (top to bottom) | Source (field/variable + file:line) | Empty or edge value |
| Header Title | static label (`temuan_fix_sheet.dart:377`) | `'Tandai Sudah Diperbaiki'` (`temuan_fix_sheet.dart:377`) |
| Header Subtitle | `widget.temuan.label`, `widget.log.posName` (`temuan_fix_sheet.dart:387`) | empty string if unset (`temuan_fix_sheet.dart:387`) |
| Section Title Foto | static label (`temuan_fix_sheet.dart:401`) | `'Foto bukti sesudah perbaikan (wajib, maks 3)'` (`temuan_fix_sheet.dart:401`) |
| Photo Thumbnails List | `_photoPaths` (`temuan_fix_sheet.dart:416`) | `[]` empty initial list (`temuan_fix_sheet.dart:74`) |
| Section Title Tindakan | static label (`temuan_fix_sheet.dart:464`) | `'Tindakan yang dilakukan'` (`temuan_fix_sheet.dart:464`) |
| Tindakan Input Field | `_catatanController.text` (`temuan_fix_sheet.dart:475`) | validation requires length >= 3 (`temuan_fix_sheet.dart:101`) |
| Error Message Box | `_errorMessage` (`temuan_fix_sheet.dart:522-545`) | hidden when null or empty (`temuan_fix_sheet.dart:522`) |

### Actions
| Label (verbatim) | Control | Handler (file:line) | Result |
| + Ambil Foto | InkWell | `_takePhoto` (`temuan_fix_sheet.dart:423`) | Launches camera (`ImageSource.camera`), captures 1-3 photos (`temuan_fix_sheet.dart:113`) |
| Hapus foto <index> | InkWell | `_removePhoto(index)` (`temuan_fix_sheet.dart:277`) | Removes photo from `_photoPaths` (`temuan_fix_sheet.dart:139`) |
| Simpan Perbaikan | ElevatedButton | `_submitFix` (`temuan_fix_sheet.dart:555`) | Submits fix to `MaintenanceFixService`, pops sheet (`temuan_fix_sheet.dart:203`) |
| Buang | TextButton in confirm dialog | `Navigator.of(ctx).pop(true)` (`temuan_fix_sheet.dart:169`) | Confirms discarding unsaved photos/notes (`temuan_fix_sheet.dart:149`) |
| Lanjut isi | TextButton in confirm dialog | `Navigator.of(ctx).pop(false)` (`temuan_fix_sheet.dart:165`) | Cancels discard dialog and stays in sheet (`temuan_fix_sheet.dart:165`) |
| Kirim WA | FilledButton in share dialog | `Navigator.of(ctx).pop(true)` (`maintenance_location_detail_screen.dart:887`) | Shares formatted report to WhatsApp via `ShareHelper` (`maintenance_location_detail_screen.dart:907`) |
| Nanti | TextButton in share dialog | `Navigator.of(ctx).pop(false)` (`maintenance_location_detail_screen.dart:883`) | Dismisses WhatsApp share prompt (`maintenance_location_detail_screen.dart:883`) |

### States
- loading: `'Menyimpan...'` (`temuan_fix_sheet.dart:584`), `CircularProgressIndicator` (`temuan_fix_sheet.dart:575`)
- empty: none in code
- error: `'Kamera tidak bisa dibuka'` (`temuan_fix_sheet.dart:130`), `'Data perbaikan tidak valid.'` (`temuan_fix_sheet.dart:216`), `'Gagal menyimpan perbaikan: $e'` (`temuan_fix_sheet.dart:231`)
- disabled: `ElevatedButton(onPressed: _canSubmit ? _submitFix : null)` (`temuan_fix_sheet.dart:555`)
- success: SnackBar `'Temuan ditandai sudah diperbaiki'` (`maintenance_location_detail_screen.dart:849`)
- offline: SnackBar `'Tersimpan. Dikirim otomatis saat ada sinyal'` (`maintenance_location_detail_screen.dart:854`)

### Conditional
- `_photoPaths.length < 3`: shows '+ Ambil Foto' button (`temuan_fix_sheet.dart:418`)
- `_errorMessage != null && _errorMessage!.isNotEmpty`: renders error message container (`temuan_fix_sheet.dart:522`)
- `_hasUnsavedInput`: prompts 'Buang perbaikan ini?' dialog on back dismiss (`temuan_fix_sheet.dart:95, 147`)
- `MaintenanceMapPalette.surfaceOf(context)` / light-dark mode: theme colors (`temuan_fix_sheet.dart:322-329`)

### Copy
- 'Tandai Sudah Diperbaiki' (`temuan_fix_sheet.dart:377`)
- 'Foto bukti sesudah perbaikan (wajib, maks 3)' (`temuan_fix_sheet.dart:401`)
- '+ Ambil Foto' (`temuan_fix_sheet.dart:446`)
- 'Tindakan yang dilakukan' (`temuan_fix_sheet.dart:464`)
- 'Contoh: Ganti roller, bersihkan jalur kertas' (`temuan_fix_sheet.dart:488`)
- 'Simpan Perbaikan' (`temuan_fix_sheet.dart:595`)
- 'Menyimpan...' (`temuan_fix_sheet.dart:584`)
- 'Buang perbaikan ini?' (`temuan_fix_sheet.dart:153`)
- 'Foto dan catatan yang sudah diisi akan hilang.' (`temuan_fix_sheet.dart:160`)
- 'Lanjut isi' (`temuan_fix_sheet.dart:166`)
- 'Buang' (`temuan_fix_sheet.dart:173`)
- 'Temuan ditandai sudah diperbaiki' (`maintenance_location_detail_screen.dart:849`)
- 'Tersimpan. Dikirim otomatis saat ada sinyal' (`maintenance_location_detail_screen.dart:854`)
- 'Kirim laporan ke WhatsApp?' (`maintenance_location_detail_screen.dart:874`)
- 'Nanti' (`maintenance_location_detail_screen.dart:884`)
- 'Kirim WA' (`maintenance_location_detail_screen.dart:892`)

## 6. Kendala Fisik: `lib/features/maintenance/screens/maintenance_checklist_screen.dart:2258-2495`
Opened from: `lib/features/maintenance/screens/maintenance_checklist_screen.dart:1905` (`_showDisposisiKendalaDialog`)
Type: dialog

### Fields
| UI element (top to bottom) | Source (field/variable + file:line) | Empty or edge value |
| Dialog Title Icon | `Icons.handyman_rounded` (`maintenance_checklist_screen.dart:2303`) | always `Icons.handyman_rounded` (`maintenance_checklist_screen.dart:2303`) |
| Dialog Title Text | static label (`maintenance_checklist_screen.dart:2310`) | `'Tandai Kendala Fisik'` (`maintenance_checklist_screen.dart:2310`) |
| Dialog Description | static label (`maintenance_checklist_screen.dart:2326`) | `'Pilih opsi ini jika alat rusak fisik atau perlu penggantian sparepart.'` (`maintenance_checklist_screen.dart:2326`) |
| Section Header | static label (`maintenance_checklist_screen.dart:2331`) | `'PILIH JENIS KENDALA:'` (`maintenance_checklist_screen.dart:2331`) |
| Reason Radio Options | `quickReasons` (`maintenance_checklist_screen.dart:2267-2274, 2339`) | 6 predefined reasons (`maintenance_checklist_screen.dart:2267-2274`) |
| Selected Reason State | `selectedReason` (`maintenance_checklist_screen.dart:2276, 2340`) | `quickReasons.first` default (`maintenance_checklist_screen.dart:2276`) |
| Custom Reason Input | `customCtrl.text` (`maintenance_checklist_screen.dart:2402`) | `'Kendala Fisik Belum Dirinci'` if submitted empty (`maintenance_checklist_screen.dart:2468`) |

### Actions
| Label (verbatim) | Control | Handler (file:line) | Result |
| <quick reason row> | InkWell | `setDlgState(() => selectedReason = reason)` (`maintenance_checklist_screen.dart:2342`) | Selects radio reason |
| Batal / Hapus Kendala | TextButton | `Navigator.pop(dlgCtx)` (`maintenance_checklist_screen.dart:2427`) | Clears kendala if exists, or cancels dialog |
| Simpan Kendala | ElevatedButton | save handler (`maintenance_checklist_screen.dart:2464`) | Updates point with `kendalaFisik`, saves, pops dialog |

### States
- loading: none in code
- empty: fallback `'Kendala Fisik Belum Dirinci'` (`maintenance_checklist_screen.dart:2468`)
- error: none in code
- disabled: none in code
- success: SnackBar `'Kendala fisik ditandai: $finalReason'` (`maintenance_checklist_screen.dart:2484`)
- offline: none in code

### Conditional
- `selectedReason == quickReasons.last`: displays custom reason `TextField` (`maintenance_checklist_screen.dart:2399`)
- `result.kendalaFisik != null && result.kendalaFisik!.isNotEmpty`: changes cancel button label to `'Hapus Kendala'` with danger color (`maintenance_checklist_screen.dart:2444-2452`)
- `ThemeService.isDarkMode(context)` / `isDark`: adjusts dialog surface and card borders (`maintenance_checklist_screen.dart:2262-2265`)

### Copy
- 'Tandai Kendala Fisik' (`maintenance_checklist_screen.dart:2310`)
- 'Pilih opsi ini jika alat rusak fisik atau perlu penggantian sparepart.' (`maintenance_checklist_screen.dart:2326`)
- 'PILIH JENIS KENDALA:' (`maintenance_checklist_screen.dart:2331`)
- 'Butuh Pengadaan Stiker / Akrilik Baru' (`maintenance_checklist_screen.dart:2268`)
- 'Kerusakan Fisik / Cor Pulau Retak (Butuh Sipil)' (`maintenance_checklist_screen.dart:2269`)
- 'Sparepart / Komponen Rusak (Butuh Part Kantor)' (`maintenance_checklist_screen.dart:2270`)
- 'Karat / Korosi Permanen (Butuh Cat / Semprot Karat)' (`maintenance_checklist_screen.dart:2271`)
- 'Kabel / Pipa Tertanam Rusak (Butuh Rekondisi)' (`maintenance_checklist_screen.dart:2272`)
- 'Lainnya (Tuliskan Keterangan Khusus)' (`maintenance_checklist_screen.dart:2273`)
- 'Tulis rincian kendala...' (`maintenance_checklist_screen.dart:2409`)
- 'Batal' (`maintenance_checklist_screen.dart:2446`)
- 'Hapus Kendala' (`maintenance_checklist_screen.dart:2445`)
- 'Simpan Kendala' (`maintenance_checklist_screen.dart:2490`)
- 'Kendala fisik ditandai: $finalReason' (`maintenance_checklist_screen.dart:2484`)

## 7. Riwayat Maintenance: `lib/features/maintenance/screens/maintenance_history_screen.dart:17-906`
Opened from: `lib/features/camera/widgets/camera_drawer.dart:340`, `lib/features/maintenance/screens/maintenance_checklist_screen.dart:738`
Type: screen

### Fields
| UI element (top to bottom) | Source (field/variable + file:line) | Empty or edge value |
| App Bar Title | static label (`maintenance_history_screen.dart:169`) | `'Riwayat Maintenance'` (`maintenance_history_screen.dart:169`) |
| Tab 1 Header Badge | `drafts.length` (`maintenance_history_screen.dart:214`) | hidden when drafts is empty (`maintenance_history_screen.dart:205`) |
| Tab 2 Header Badge | `completed.length` (`maintenance_history_screen.dart:244`) | hidden when completed is empty (`maintenance_history_screen.dart:235`) |
| Draft Card Location | `draft.location?.posName` (`maintenance_history_screen.dart:325`) | `'Lokasi tidak diketahui'` (`maintenance_history_screen.dart:325`) |
| Draft Card Template | `draft.templateName` (`maintenance_history_screen.dart:336`) | empty string if unset (`maintenance_history_screen.dart:336`) |
| Draft Card Progress Bar | `draft.doneCount`, `draft.totalPoints` (`maintenance_history_screen.dart:361`) | `0/0` if empty (`maintenance_history_screen.dart:361`) |
| Draft Card Timestamp | `draft.startedAt` (`maintenance_history_screen.dart:380`) | formatted time via `TimemarkFormatter` (`maintenance_history_screen.dart:380`) |
| Completed Card Location | `completed.location?.posName` (`maintenance_history_screen.dart:475`) | `'Lokasi tidak diketahui'` (`maintenance_history_screen.dart:475`) |
| Completed Card Status Badge | static label (`maintenance_history_screen.dart:495`) | `'100% Selesai'` (`maintenance_history_screen.dart:495`) |
| Completed Card Photo Count | `completed.points.length` (`maintenance_history_screen.dart:530`) | `0` if empty (`maintenance_history_screen.dart:530`) |

### Actions
| Label (verbatim) | Control | Handler (file:line) | Result |
| Lanjutkan Draft | ElevatedButton | `_resumeDraft(draft)` (`maintenance_history_screen.dart:398`) | Pushes `MaintenanceChecklistScreen` with existing draft (`maintenance_history_screen.dart:130`) |
| Hapus Draft | IconButton | `_deleteSubmission(draft.id)` (`maintenance_history_screen.dart:415`) | Shows confirm dialog, deletes submission from storage (`maintenance_history_screen.dart:65`) |
| Lihat Detail | ElevatedButton | `_openDetailSheet(submission)` (`maintenance_history_screen.dart:548`) | Opens `_MaintenanceDetailModal` bottom sheet (`maintenance_history_screen.dart:140`) |
| Hapus | ElevatedButton in dialog | `Navigator.of(ctx).pop(true)` (`maintenance_history_screen.dart:101`) | Confirms deletion of maintenance submission (`maintenance_history_screen.dart:108`) |
| Batal | TextButton in dialog | `Navigator.of(ctx).pop(false)` (`maintenance_history_screen.dart:87`) | Cancels deletion dialog (`maintenance_history_screen.dart:87`) |

### States
- loading: none in code
- empty: `'Tidak Ada Draft Berjalan'` (`maintenance_history_screen.dart:267`), `'Belum Ada Maintenance Selesai'` (`maintenance_history_screen.dart:280`)
- error: none in code
- disabled: none in code
- success: SnackBar `'Data maintenance dihapus.'` (`maintenance_history_screen.dart:113`)
- offline: none in code

### Conditional
- `drafts.isEmpty`: displays empty state with icon `Icons.assignment_outlined` (`maintenance_history_screen.dart:264`)
- `completed.isEmpty`: displays empty state with icon `Icons.task_alt_rounded` (`maintenance_history_screen.dart:277`)
- `drafts.isNotEmpty`: displays counter badge on Tab 1 (`maintenance_history_screen.dart:205`)
- `completed.isNotEmpty`: displays counter badge on Tab 2 (`maintenance_history_screen.dart:235`)
- `ThemeService.isDarkMode(context)` / `isDark`: adjusts scaffold and card dark palette (`maintenance_history_screen.dart:159-160`)

### Copy
- 'Riwayat Maintenance' (`maintenance_history_screen.dart:169`)
- 'Draft Berjalan' (`maintenance_history_screen.dart:204`)
- 'Selesai 100%' (`maintenance_history_screen.dart:234`)
- 'Tidak Ada Draft Berjalan' (`maintenance_history_screen.dart:267`)
- 'Semua pekerjaan maintenance yang tertunda akan muncul di sini.' (`maintenance_history_screen.dart:268`)
- 'Belum Ada Maintenance Selesai' (`maintenance_history_screen.dart:280`)
- 'Maintenance yang sudah selesai 100% tersimpan dan bisa dilihat lagi di sini.' (`maintenance_history_screen.dart:281`)
- 'Hapus Data Maintenance?' (`maintenance_history_screen.dart:71`)
- 'Data dan foto maintenance ini akan dihapus dari penyimpanan perangkat.' (`maintenance_history_screen.dart:79`)
- 'Batal' (`maintenance_history_screen.dart:89`)
- 'Hapus' (`maintenance_history_screen.dart:101`)
- 'Data maintenance dihapus.' (`maintenance_history_screen.dart:113`)
- 'Lanjutkan Draft' (`maintenance_history_screen.dart:404`)
- 'Lihat Detail' (`maintenance_history_screen.dart:554`)
- '100% Selesai' (`maintenance_history_screen.dart:495`)
