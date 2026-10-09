import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/theme_service.dart';
import '../../../data/services/absensi_setup_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/daily_task_service.dart';
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

  // Daftar nama rekan IT Support
  static const List<String> _rekanItOptions = [
    'Ryan Lumasuge',
    'Raldy Sangkop',
    'Junifer Manua',
    'Alessandro Sulistyo',
    'Shift Terakhir / Tidak Ada Pengganti',
  ];

  @override
  void initState() {
    super.initState();
    final setup = AbsensiSetupService.instance;
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final isHandoverToday = setup.handoverDate == todayStr;

    // Prefill data yang sudah tersimpan jika hari ini
    if (setup.shiftSelanjutnya.isNotEmpty && setup.shiftSelanjutnya != '-') {
      _selectedNextShift = setup.shiftSelanjutnya;
    }
    if (isHandoverToday) {
      if (setup.pekerjaanSelesai.isNotEmpty && setup.pekerjaanSelesai != '-') {
        _selesaiCtrl.text = setup.pekerjaanSelesai;
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
        final bufferBelum = StringBuffer();
        for (int i = 0; i < pending.length; i++) {
          final t = pending[i];
          bufferBelum.writeln('${i + 1}. ${t.judul} (${t.posName})');
        }
        _belumCtrl.text = bufferBelum.toString().trim();
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
        final bufferBelum = StringBuffer();
        for (int i = 0; i < pending.length; i++) {
          final t = pending[i];
          bufferBelum.writeln('${i + 1}. ${t.judul} (${t.posName})');
        }
        _belumCtrl.text = bufferBelum.toString().trim();
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
        _errorMessage = 'Wajib memilih Teknisi Shift Selanjutnya!';
      });
      return;
    }

    // Validasi 2: Pekerjaan Selesai Wajib Diisi
    if (selesaiText.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorMessage = 'Wajib mencatat pekerjaan yang telah diselesaikan!';
      });
      return;
    }

    // Validasi 3: Jika toggle belum selesai aktif, teks tidak boleh kosong
    String savedBelum = '-';
    if (_adaPekerjaanBelum) {
      final belumText = _belumCtrl.text.trim();
      if (belumText.isEmpty) {
        HapticFeedback.heavyImpact();
        setState(() {
          _errorMessage = 'Tuliskan pekerjaan yang belum selesai atau matikan toggle jika tidak ada.';
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
    final isDark = ThemeService.isDarkMode(context);

    final sheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textTitle = isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary;
    final textSub = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;
    final cardBg = isDark ? const Color(0xFF1E293B) : AppColors.surfaceContainerLow;
    final cardBorder = isDark ? const Color(0xFF334155) : AppColors.cardBorder;
    final inputBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final inputBorder = isDark ? const Color(0xFF334155) : AppColors.cardBorder;
    final inputTextColor = isDark ? Colors.white : AppColors.textPrimary;
    final hintColor = isDark ? const Color(0xFF64748B) : AppColors.textMuted;
    final dividerColor = isDark ? const Color(0xFF334155) : AppColors.cardBorder;
    final handleColor = isDark ? const Color(0xFF475569) : AppColors.cardBorder;
    final toggleCardBg = isDark ? const Color(0xFF1E293B) : AppColors.creamContainer;
    final toggleInnerBg = isDark ? const Color(0xFF0B1120) : Colors.white;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: const Border(
          top: BorderSide(color: AppColors.accent, width: 3.0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 30,
            spreadRadius: 2,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle Bar
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header Title & Close Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(
                      Icons.assignment_turned_in_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Laporan Kerja Harian',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: textTitle,
                            fontFamily: 'PlusJakartaSans',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ringkasan pekerjaan sebelum absensi pulang',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: textSub,
                            fontFamily: 'PlusJakartaSans',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    icon: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : AppColors.surfaceContainerLow,
                        shape: BoxShape.circle,
                        border: Border.all(color: cardBorder),
                      ),
                      child: Center(
                        child: Icon(Icons.close_rounded, color: textSub, size: 18),
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop(false);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: dividerColor, height: 1),
              const SizedBox(height: 14),

              // Error banner jika validasi gagal
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.dangerBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.danger,
                            fontFamily: 'PlusJakartaSans',
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
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text.rich(
                    TextSpan(
                      text: 'Teknisi Shift Selanjutnya ',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: textTitle,
                        fontFamily: 'PlusJakartaSans',
                      ),
                      children: const [
                        TextSpan(
                          text: '*',
                          style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cardBorder, width: 1.2),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedNextShift,
                    isExpanded: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                    style: TextStyle(
                      fontSize: 13.5,
                      color: textTitle,
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w600,
                    ),
                    items: _rekanItOptions.map((name) {
                      final isNoOne = name.contains('Tidak Ada');
                      return DropdownMenuItem<String>(
                        value: name,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: isNoOne
                                  ? AppColors.textMuted
                                  : AppColors.primary,
                              child: Text(
                                isNoOne
                                    ? '-'
                                    : name.split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  color: textTitle,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
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
                  const Icon(Icons.assignment_outlined, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text.rich(
                    TextSpan(
                      text: 'Pekerjaan Selesai Hari Ini ',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: textTitle,
                        fontFamily: 'PlusJakartaSans',
                      ),
                      children: const [
                        TextSpan(
                          text: '*',
                          style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: _isLoadingDailyTasks ? null : () => _autoFillFromDailyTasks(force: true),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: isDark ? 0.4 : 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _isLoadingDailyTasks
                              ? const SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: AppColors.primary,
                                  ),
                                )
                              : const Icon(Icons.sync_rounded, size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            _syncedCompletedCount > 0
                                ? 'Sinkron ($_syncedCompletedCount Selesai)'
                                : 'Sinkron Daily Task',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: inputBorder, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextField(
                      controller: _selesaiCtrl,
                      maxLines: 4,
                      minLines: 3,
                      maxLength: 2000,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      style: TextStyle(
                        fontSize: 13,
                        color: inputTextColor,
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Tulis pekerjaan yang selesai hari ini...\nContoh: Pengecekan gate barrier, pembersihan printer pos, update sistem',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: hintColor,
                          fontFamily: 'PlusJakartaSans',
                          height: 1.4,
                        ),
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                      ),
                      onChanged: (_) {
                        setState(() {
                          if (_errorMessage != null) _errorMessage = null;
                        });
                      },
                    ),
                    Text(
                      '${_selesaiCtrl.text.length}/2000',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: hintColor,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. Pekerjaan Belum Selesai (Toggle)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: toggleCardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _adaPekerjaanBelum
                        ? AppColors.accent.withValues(alpha: 0.6)
                        : cardBorder,
                    width: 1.2,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.pending_actions_rounded,
                          size: 18,
                          color: _adaPekerjaanBelum ? AppColors.accent : textSub,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ada pekerjaan belum selesai?',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: textTitle,
                              fontFamily: 'PlusJakartaSans',
                            ),
                          ),
                        ),
                        Switch(
                          value: _adaPekerjaanBelum,
                          activeThumbColor: AppColors.accent,
                          activeTrackColor: AppColors.accent.withValues(alpha: 0.35),
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: cardBorder,
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
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                        decoration: BoxDecoration(
                          color: toggleInnerBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.5), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            TextField(
                              controller: _belumCtrl,
                              maxLines: 3,
                              minLines: 2,
                              maxLength: 2000,
                              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                              style: TextStyle(
                                fontSize: 13,
                                color: inputTextColor,
                                fontFamily: 'PlusJakartaSans',
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Tuliskan pekerjaan atau pendingan yang belum selesai...',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: hintColor,
                                  fontFamily: 'PlusJakartaSans',
                                  height: 1.4,
                                ),
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            Text(
                              '${_belumCtrl.text.length}/2000',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: hintColor,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tombol Simpan (Safety Orange Tactile Button)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                    shadowColor: AppColors.accent.withValues(alpha: 0.4),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Simpan Laporan Harian',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'PlusJakartaSans',
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
