import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/tiket_colors.dart';
import '../../../core/widgets/tiket/tiket.dart';
import '../../../data/services/absensi_setup_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/models/daily_task_model.dart';
import '../../../data/services/daily_task_service.dart';
import '../../../data/services/whatsapp_report_service.dart';
import '../../../data/services/branch_service.dart';
import '../../../data/repositories/auth_repository.dart';

class DailyPulangBottomSheet extends StatefulWidget {
  const DailyPulangBottomSheet({super.key});

  /// Menampilkan bottom sheet. Mengembalikan `true` jika berhasil disimpan.
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DailyPulangBottomSheet(),
    );
  }

  @override
  State<DailyPulangBottomSheet> createState() => _DailyPulangBottomSheetState();
}

class _DailyPulangBottomSheetState extends State<DailyPulangBottomSheet> {
  final _selesaiCtrl = TextEditingController();
  final _belumCtrl = TextEditingController();

  String? _selectedNextShift;
  bool _adaPekerjaanBelum = false;
  String? _errorMessage;
  bool _isLoadingDailyTasks = false;
  int _syncedCompletedCount = 0;

  static const String _tanpaPengganti = 'Shift Terakhir / Tidak Ada Pengganti';

  // Rekan per cabang aktif: daftar statis dulu membocorkan nama teknisi Manado ke HO/Bali.
  late final List<String> _rekanItOptions = [
    ...BranchService.instance.getTechnicians(),
    _tanpaPengganti,
  ];

  @override
  void initState() {
    super.initState();
    final setup = AbsensiSetupService.instance;
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final isHandoverToday = setup.handoverDate == todayStr;

    // Prefill data yang sudah tersimpan jika hari ini
    // Nilai tersimpan dari cabang lain tidak boleh jadi value dropdown (bukan item = assert error).
    if (setup.shiftSelanjutnya.isNotEmpty &&
        setup.shiftSelanjutnya != '-' &&
        _rekanItOptions.contains(setup.shiftSelanjutnya)) {
      _selectedNextShift = setup.shiftSelanjutnya;
    }
    if (isHandoverToday) {
      if (setup.pekerjaanSelesai.isNotEmpty && setup.pekerjaanSelesai != '-') {
        _selesaiCtrl.text = setup.pekerjaanSelesai;
        _syncedCompletedCount = 2;
      }
      if (setup.pekerjaanBelum.isNotEmpty && setup.pekerjaanBelum != '-') {
        _adaPekerjaanBelum = true;
        _belumCtrl.text = setup.pekerjaanBelum;
      }
    }

    // Auto-fill dari Daily Task hari ini
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoFillFromDailyTasks(force: !isHandoverToday);
    });
  }

  static String _formatUnfinishedTaskPrefill(List<DailyTaskModel> tasks) {
    final buffer = StringBuffer();
    for (int i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      final reason = DailyTaskService.unfinishedReason(t) ?? '';
      buffer.writeln('${i + 1}. ${t.judul} (${t.posName})');
      buffer.writeln('Alasan: $reason');
    }
    return buffer.toString().trim();
  }

  Future<void> _autoFillFromDailyTasks({bool force = false}) async {
    final user = AuthRepository.instance.currentUser;
    if (user == null) return;

    if (!force && _selesaiCtrl.text.trim().isNotEmpty && _selesaiCtrl.text.trim() != '-') {
      return;
    }

    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    setState(() => _isLoadingDailyTasks = true);

    try {
      final tasks = await DailyTaskService.getTasksForTeknisi(
        tanggal: todayStr,
        teknisiNama: user.nama,
      );

      final completed = tasks.where((t) => t.isCompleted).toList();
      final pending = tasks.where((t) => !t.isCompleted).toList();

      if (completed.isNotEmpty) {
        final buffer = StringBuffer();
        for (int i = 0; i < completed.length; i++) {
          final t = completed[i];
          final timeStr = (t.jamSelesai != null && t.jamSelesai!.isNotEmpty) ? ' (Selesai ${t.jamSelesai})' : '';
          buffer.writeln('${i + 1}. ${t.judul}$timeStr');
        }
        _selesaiCtrl.text = buffer.toString().trim();
      }

      if (pending.isNotEmpty) {
        _adaPekerjaanBelum = true;
        _belumCtrl.text = _formatUnfinishedTaskPrefill(pending);
      }

      _syncedCompletedCount = completed.length;
    } catch (_) {
      // Fallback local cache jika offline di basement
      final cached = DailyTaskService.getCachedTasksLocally();
      final completed = cached.where((t) => t.isCompleted).toList();
      final pending = cached.where((t) => !t.isCompleted).toList();
      if (completed.isNotEmpty) {
        final buffer = StringBuffer();
        for (int i = 0; i < completed.length; i++) {
          final t = completed[i];
          final timeStr = (t.jamSelesai != null && t.jamSelesai!.isNotEmpty) ? ' (Selesai ${t.jamSelesai})' : '';
          buffer.writeln('${i + 1}. ${t.judul}$timeStr');
        }
        _selesaiCtrl.text = buffer.toString().trim();
      }
      if (pending.isNotEmpty) {
        _adaPekerjaanBelum = true;
        _belumCtrl.text = _formatUnfinishedTaskPrefill(pending);
      }
      _syncedCompletedCount = completed.length;
    } finally {
      if (mounted) {
        setState(() => _isLoadingDailyTasks = false);
      }
    }
  }

  @override
  void dispose() {
    _selesaiCtrl.dispose();
    _belumCtrl.dispose();
    super.dispose();
  }

  void _handleSave() {
    final setup = AbsensiSetupService.instance;
    final selesaiText = _selesaiCtrl.text.trim();

    // Validasi 1: Teknisi Shift Selanjutnya Wajib Dipilih
    if (_selectedNextShift == null || _selectedNextShift!.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorMessage = 'Pilih teknisi shift berikutnya.';
      });
      return;
    }

    // Validasi 2: Pekerjaan Selesai Wajib Diisi
    if (selesaiText.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorMessage = 'Tulis pekerjaan yang sudah selesai.';
      });
      return;
    }

    // Validasi 3: Jika toggle belum selesai aktif, teks tidak boleh kosong dan wajib ada alasan
    String savedBelum = '-';
    if (_adaPekerjaanBelum) {
      final belumText = _belumCtrl.text.trim();
      if (belumText.isEmpty) {
        HapticFeedback.heavyImpact();
        setState(() {
          _errorMessage = 'Tulis pekerjaan yang belum selesai, atau matikan opsi jika tidak ada.';
        });
        return;
      }
      final missingReasons = WhatsAppReportService.unfinishedJobsMissingReason(belumText);
      if (missingReasons.isNotEmpty) {
        HapticFeedback.heavyImpact();
        setState(() {
          _errorMessage = 'Tulis alasan kenapa belum selesai untuk: ${missingReasons.first}';
        });
        return;
      }
      savedBelum = belumText;
    }

    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Simpan ke service & storage dengan tanggal hari ini
    setup.updateDailyHandover(
      nextShift: _selectedNextShift!,
      selesai: selesaiText,
      belum: savedBelum,
      date: todayStr,
    );
    StorageService.markDailyReportCompletedToday();

    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final colors = TiketColors.of(context);

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: colors.dialog,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle Bar
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header Title & Close Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Handover & Laporan Pulang',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: colors.ink,
                            fontFamily: 'Figtree',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ringkasan tugas & serah terima shift',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.body,
                            fontFamily: 'Figtree',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: Icon(Icons.close_rounded, color: colors.mute, size: 22),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop(false);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: colors.hairline, height: 1),
              const SizedBox(height: 14),

              // Error banner jika validasi gagal
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.soft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.danger, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: colors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.danger,
                            fontFamily: 'Figtree',
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // 1. Teknisi Shift Selanjutnya
              Text.rich(
                TextSpan(
                  text: 'Teknisi shift selanjutnya ',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                    fontFamily: 'Figtree',
                  ),
                  children: [
                    TextSpan(
                      text: '*',
                      style: TextStyle(color: colors.danger, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.soft,
                  border: Border(
                    bottom: BorderSide(color: colors.body, width: 2.0),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedNextShift,
                    isExpanded: true,
                    dropdownColor: colors.dialog,
                    hint: Text(
                      'Pilih teknisi',
                      style: TextStyle(
                        color: colors.body,
                        fontSize: 13.5,
                        fontFamily: 'Figtree',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: colors.ink),
                    style: TextStyle(
                      fontSize: 13.5,
                      color: colors.ink,
                      fontFamily: 'Figtree',
                      fontWeight: FontWeight.w600,
                    ),
                    items: _rekanItOptions.map((name) {
                      return DropdownMenuItem<String>(
                        value: name,
                        child: Text(
                          name,
                          style: TextStyle(
                            color: colors.ink,
                            fontSize: 13.5,
                            fontFamily: 'Figtree',
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedNextShift = val;
                          _errorMessage = null;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 2. Pekerjaan yang Selesai
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'Pekerjaan selesai hari ini ',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                          fontFamily: 'Figtree',
                        ),
                        children: [
                          TextSpan(
                            text: '*',
                            style: TextStyle(color: colors.danger, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TiketPill(
                    kind: TiketPillKind.secondary,
                    icon: Icons.refresh_rounded,
                    label: _syncedCompletedCount > 0
                        ? 'Sinkron ($_syncedCompletedCount Selesai)'
                        : 'Sinkron',
                    onPressed: _isLoadingDailyTasks ? null : () => _autoFillFromDailyTasks(force: true),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _selesaiCtrl,
                maxLines: 4,
                minLines: 3,
                maxLength: 2000,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.ink,
                  fontFamily: 'Figtree',
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colors.soft,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  hintText: 'Tulis pekerjaan yang selesai hari ini...\nContoh: Pengecekan gate barrier, pembersihan printer pos, update sistem',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: colors.mute,
                    fontFamily: 'Figtree',
                    height: 1.4,
                  ),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: colors.body, width: 2.0),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: colors.body, width: 2.0),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: colors.primary, width: 2.0),
                  ),
                ),
                onChanged: (_) {
                  setState(() {
                    if (_errorMessage != null) _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_selesaiCtrl.text.length}/2000',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: colors.mute,
                    fontFamily: 'Figtree',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 3. Pekerjaan Belum Selesai (Toggle)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ada pekerjaan belum selesai?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                        fontFamily: 'Figtree',
                      ),
                    ),
                  ),
                  Switch(
                    value: _adaPekerjaanBelum,
                    activeThumbColor: colors.white,
                    activeTrackColor: colors.primary,
                    inactiveThumbColor: colors.mute,
                    inactiveTrackColor: colors.soft,
                    trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _adaPekerjaanBelum = val;
                        if (!val) {
                          _belumCtrl.clear();
                        }
                      });
                    },
                  ),
                ],
              ),
              if (_adaPekerjaanBelum) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _belumCtrl,
                  maxLines: 3,
                  minLines: 2,
                  maxLength: 2000,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.ink,
                    fontFamily: 'Figtree',
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colors.soft,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    hintText:
                        '1. Nama pekerjaan (Pos)\nAlasan: kenapa belum selesai',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: colors.mute,
                      fontFamily: 'Figtree',
                      height: 1.4,
                    ),
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(color: colors.body, width: 2.0),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: colors.body, width: 2.0),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: colors.primary, width: 2.0),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_belumCtrl.text.length}/2000',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: colors.mute,
                      fontFamily: 'Figtree',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Tombol Simpan
              TiketPill(
                kind: TiketPillKind.primary,
                expand: true,
                icon: Icons.check_circle_rounded,
                label: 'Simpan & Lanjut Foto Pulang',
                onPressed: _handleSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
