import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/absensi_setup_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/daily_task_service.dart';

/// Modal Bottom Sheet 'Isi daily dulu ya!' sebelum absensi kepulangan.
/// Mengharuskan teknisi memilih IT Support pengganti dan mencatat tugas harian.
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
  final setup = AbsensiSetupService.instance;

  static const List<String> _rekanItOptions = [
    'Junifer Manua',
    'Ryan Lumasuge',
    'Alessandro Sulistyo',
    'Raldy Sangkop',
    'Shift Terakhir / Tidak Ada Pengganti',
  ];

  late String _selectedNextShift;
  late TextEditingController _selesaiCtrl;
  bool _adaPekerjaanBelum = false;
  late TextEditingController _belumCtrl;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final savedNext = setup.shiftSelanjutnya.trim();
    if (savedNext.isNotEmpty && savedNext != '-' && _rekanItOptions.contains(savedNext)) {
      _selectedNextShift = savedNext;
    } else if (savedNext.isNotEmpty && savedNext != '-') {
      _selectedNextShift = savedNext;
    } else {
      _selectedNextShift = _rekanItOptions.first;
    }

    final rawSelesai = setup.pekerjaanSelesai.trim();
    final rawBelum = setup.pekerjaanBelum.trim();
    var initialSelesai = rawSelesai.isNotEmpty && rawSelesai != '-' ? rawSelesai : '';
    var initialBelum = rawBelum.isNotEmpty && rawBelum != '-' ? rawBelum : '';

    // Auto-fill dari Daily Tasks & Maintenance hari ini jika belum ada input manual
    if (initialSelesai.isEmpty) {
      final cachedTasks = DailyTaskService.getCachedTasksLocally();
      final doneTasks = cachedTasks.where((t) => t.isCompleted).toList();
      final pendingTasks = cachedTasks.where((t) => !t.isCompleted).toList();

      final buffer = StringBuffer();
      int itemNum = 1;

      // 1. Ambil tugas daily selesai
      for (final t in doneTasks) {
        buffer.writeln('$itemNum. [✓] ${t.judul}');
        itemNum++;
      }

      // 2. Ambil tugas maintenance selesai hari ini
      final now = DateTime.now();
      final allMaint = StorageService.getMaintenanceSubmissions() ?? [];
      final todayMaint = allMaint.where((s) {
        return s.createdAt.year == now.year &&
            s.createdAt.month == now.month &&
            s.createdAt.day == now.day &&
            s.isComplete;
      }).toList();

      for (final m in todayMaint) {
        buffer.writeln('$itemNum. [✓] Maintenance: ${m.templateName} (${m.posName})');
        itemNum++;
      }

      if (buffer.isNotEmpty) {
        initialSelesai = buffer.toString().trim();
      }

      if (initialBelum.isEmpty && pendingTasks.isNotEmpty) {
        final pendingBuffer = StringBuffer();
        for (int i = 0; i < pendingTasks.length; i++) {
          pendingBuffer.writeln('- ${pendingTasks[i].judul} (Belum selesai)');
        }
        initialBelum = pendingBuffer.toString().trim();
        _adaPekerjaanBelum = true;
      }
    }

    _selesaiCtrl = TextEditingController(text: initialSelesai);
    _belumCtrl = TextEditingController(text: initialBelum);
    if (initialBelum.isNotEmpty) {
      _adaPekerjaanBelum = true;
    }
  }

  @override
  void dispose() {
    _selesaiCtrl.dispose();
    _belumCtrl.dispose();
    super.dispose();
  }

  void _handleSave() {
    final selesaiText = _selesaiCtrl.text.trim();
    final belumText = _belumCtrl.text.trim();

    // Validasi: Wajib ada isi pekerjaan selesai
    if (selesaiText.isEmpty || selesaiText == '-') {
      setState(() {
        _errorMessage = 'Mohon tuliskan pekerjaan yang telah diselesaikan hari ini.';
      });
      return;
    }

    // Validasi: Jika opsi pekerjaan pending diaktifkan, wajib diisi keterangannya
    if (_adaPekerjaanBelum && (belumText.isEmpty || belumText == '-')) {
      setState(() {
        _errorMessage = 'Mohon tuliskan rincian pekerjaan pending jika opsi ini diaktifkan.';
      });
      return;
    }

    final savedBelum = _adaPekerjaanBelum && belumText.isNotEmpty ? belumText : '-';

    // Simpan ke service & storage
    setup.updateNextShift(_selectedNextShift);
    setup.updatePekerjaanSelesai(selesaiText);
    setup.updatePekerjaanBelum(savedBelum);
    StorageService.markDailyReportCompletedToday();

    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.accent, width: 3.0),
        ),
        boxShadow: [
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
                    color: AppColors.cardBorder,
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Laporan Kerja Harian',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            fontFamily: 'PlusJakartaSans',
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Ringkasan pekerjaan sebelum absensi pulang',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
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
                        color: AppColors.surfaceContainerLow,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: const Center(
                        child: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 18),
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
              const Divider(color: AppColors.cardBorder, height: 1),
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
                    const TextSpan(
                      text: 'Teknisi Shift Selanjutnya ',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFamily: 'PlusJakartaSans',
                      ),
                      children: [
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
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder, width: 1.2),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedNextShift,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textPrimary,
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
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
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
                    const TextSpan(
                      text: 'Pekerjaan Selesai Hari Ini ',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFamily: 'PlusJakartaSans',
                      ),
                      children: [
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
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
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
                      maxLength: 500,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Tulis pekerjaan yang selesai hari ini...\nContoh: Pengecekan gate barrier, pembersihan printer pos, update sistem',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
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
                      '${_selesaiCtrl.text.length}/500',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textMuted,
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
                  color: AppColors.creamContainer,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _adaPekerjaanBelum
                        ? AppColors.accent.withValues(alpha: 0.6)
                        : AppColors.cardBorder,
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
                          color: _adaPekerjaanBelum ? AppColors.accent : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Ada pekerjaan belum selesai?',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              fontFamily: 'PlusJakartaSans',
                            ),
                          ),
                        ),
                        Switch(
                          value: _adaPekerjaanBelum,
                          activeThumbColor: AppColors.accent,
                          activeTrackColor: AppColors.accent.withValues(alpha: 0.35),
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: AppColors.cardBorder,
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.5), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
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
                              maxLength: 500,
                              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                fontFamily: 'PlusJakartaSans',
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: 'Tuliskan pekerjaan atau pendingan yang belum selesai...',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                  fontFamily: 'PlusJakartaSans',
                                  height: 1.4,
                                ),
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            Text(
                              '${_belumCtrl.text.length}/500',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textMuted,
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
