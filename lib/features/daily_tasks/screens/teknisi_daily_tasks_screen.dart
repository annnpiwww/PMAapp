import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/theme_service.dart';
import '../../../data/models/daily_task_model.dart';
import '../../../data/models/maintenance_submission.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/template_repository.dart';
import '../../../data/services/daily_task_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/branch_service.dart';
import '../../maintenance/widgets/maintenance_setup_dialog.dart';
import '../../maintenance/screens/maintenance_checklist_screen.dart';
import '../widgets/completed_daily_task_modal.dart';
import '../widgets/ad_hoc_task_dialog.dart';
import '../widgets/task_handover_dialog.dart';
import 'custom_task_execution_screen.dart';

class TeknisiDailyTasksScreen extends StatefulWidget {
  const TeknisiDailyTasksScreen({super.key});

  @override
  State<TeknisiDailyTasksScreen> createState() => _TeknisiDailyTasksScreenState();
}

class _TeknisiDailyTasksScreenState extends State<TeknisiDailyTasksScreen> {
  List<DailyTaskModel> _tasks = [];
  List<DailyTaskModel> _openTasks = []; // tugas serah terima tanpa penerus
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _formatTaskDateBadge(String tanggal) {
    try {
      final parts = tanggal.split('-');
      if (parts.length == 3) {
        final taskDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        final now = DateTime.now();
        final tomorrow = now.add(const Duration(days: 1));
        if (taskDate.year == tomorrow.year && taskDate.month == tomorrow.month && taskDate.day == tomorrow.day) {
          return 'Besok';
        }
        return '${parts[2]}/${parts[1]}';
      }
    } catch (_) {}
    return tanggal;
  }

  Future<void> _loadTasks() async {
    final user = AuthRepository.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);

    final tasks = await DailyTaskService.getTasksForTeknisi(
      tanggal: _todayStr(),
      teknisiNama: user.nama,
    );

    final openTasks = await DailyTaskService.getOpenHandoverTasks(excludeTeknisi: user.nama);

    final pendingCount = tasks.where((t) => !t.isCompleted).length;
    DailyTaskService.updatePendingCount(pendingCount);
    NotificationService.instance.showDailyTasksNotification(tasks: tasks);

    if (mounted) {
      setState(() {
        _tasks = tasks;
        _openTasks = openTasks;
        _isLoading = false;
      });
    }
  }

  void _snack(String pesan, {bool sukses = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              sukses ? Icons.check_circle_rounded : Icons.error_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(pesan)),
          ],
        ),
        backgroundColor: sukses ? AppColors.success : AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Teknisi mencatat kerjaan dadakan (bukan tugas SPV) supaya masuk daftar hari itu.
  Future<void> _catatKerjaan() async {
    final user = AuthRepository.instance.currentUser;
    if (user == null) return;
    final tersimpan = await AdHocTaskDialog.show(
      context,
      teknisiNama: user.nama,
      tanggal: _todayStr(),
      lokasiOptions: LocationService.availablePosList,
      lokasiAwal: LocationService.currentPos,
    );
    if (tersimpan == null) return;
    _snack(
      tersimpan
          ? 'Kerjaan dicatat. Kerjakan seperti tugas biasa ya.'
          : 'Gagal mencatat kerjaan, coba lagi saat sinyal stabil.',
      sukses: tersimpan,
    );
    if (tersimpan) await _loadTasks();
  }

  /// Teknisi menyerahkan tugas yang belum selesai ke shift berikutnya.
  Future<void> _serahkanTugas(DailyTaskModel task) async {
    final user = AuthRepository.instance.currentUser;
    final hasil = await TaskHandoverDialog.show(
      context,
      judul: task.judul,
      lokasi: task.posName,
      teknisiOptions: BranchService.instance
          .getTechnicians()
          .where((t) => !DailyTaskService.isAssignedTo(task, t))
          .toList(),
    );
    if (hasil == null) return;

    final ok = await DailyTaskService.transferTask(
      task: task,
      keTeknisi: hasil.penerus,
      alasan: hasil.alasan,
      olehSiapa: user?.nama ?? task.teknisiNama,
    );
    _snack(
      ok
          ? (hasil.penerus.isEmpty
              ? 'Tugas dilepas ke daftar terbuka untuk shift berikutnya.'
              : 'Tugas diserahkan ke ${hasil.penerus}.')
          : 'Gagal menyimpan serah terima, coba lagi saat sinyal stabil.',
      sukses: ok,
    );
    if (ok) await _loadTasks();
  }

  /// Teknisi shift berikutnya mengambil tugas dari daftar terbuka.
  Future<void> _ambilTugas(DailyTaskModel task) async {
    final user = AuthRepository.instance.currentUser;
    if (user == null) return;
    final ok = await DailyTaskService.claimTask(task: task, olehSiapa: user.nama);
    _snack(
      ok ? 'Tugas diambil alih. Kerjakan sampai selesai ya.' : 'Gagal mengambil tugas, coba lagi.',
      sukses: ok,
    );
    if (ok) await _loadTasks();
  }

  void _startTask(DailyTaskModel task) async {
    final isKhusus = task.kategori == 'khusus' ||
        (task.templateId == null || task.templateId!.isEmpty);

    if (!isKhusus) {
      // Tugas Maintenance SOP (Checklist Point Pos)
      final templates = TemplateRepository.instance.templates;
      final foundTpl = templates.firstWhere(
        (t) => t.id == task.templateId,
        orElse: () => TemplateRepository.defaultTemplates.firstWhere(
          (t) => t.id == task.templateId,
          orElse: () => templates.first,
        ),
      );

      // 1. CARI APAKAH ADA PROGRESS DRAFT BERJALAN UNTUK TUGAS INI
      final MaintenanceSubmission? ongoing = DailyTaskService.getOngoingMaintenance(task);

      if (ongoing != null) {
        // Hubungkan taskId jika belum tercatat di submission
        if (ongoing.taskId != task.id) {
          final updated = ongoing.copyWith(taskId: task.id);
          final list = StorageService.getMaintenanceSubmissions() ?? [];
          final idx = list.indexWhere((e) => e.id == ongoing.id);
          if (idx >= 0) {
            list[idx] = updated;
            await StorageService.saveMaintenanceSubmissions(list);
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lanjut progres: ${ongoing.doneCount}/${ongoing.totalPoints} foto selesai',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.accent,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        if (!mounted) return;

        // Langsung lanjutkan pengerjaan tanpa reset progress!
        final refreshed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => MaintenanceChecklistScreen(
              template: foundTpl,
              existingSubmission: ongoing,
              dailyTaskId: task.id,
            ),
          ),
        );

        if (refreshed == true || mounted) {
          _loadTasks();
        }
        return;
      }

      // 2. JIKA BELUM ADA PROGRESS: BUKA SETUP DIALOG
      if (foundTpl.isPerPoint) {
        // Cari rekomendasi lokasi cerdas dari kata kunci SPV (posTag, posName, judul)
        final matchedLoc = LocationService.resolveLocationFromTask(
          posTag: task.posTag,
          posName: task.posName,
          judul: task.judul,
        );

        if (matchedLoc != null) {
          // Sinkronkan langsung ke LocationService agar watermark & GPS sinkron
          LocationService.setCurrentPos(matchedLoc);
          LocationService.clearLocationCache();
        }

        await showDialog(
          context: context,
          builder: (_) => MaintenanceSetupDialog(
            initialTemplate: foundTpl,
            dailyTaskId: task.id,
            initialLocation: matchedLoc,
            onChecklistFinished: _loadTasks,
          ),
        );
        _loadTasks();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mulai tugas: ${task.judul}')),
        );
      }
    } else {
      // Tugas Khusus (Non-SOP Checklist): Buka layar pengerjaan mandiri
      final refreshed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CustomTaskExecutionScreen(task: task),
        ),
      );
      if (refreshed == true) {
        _loadTasks();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthRepository.instance.currentUser;
    final total = _tasks.length;
    final done = _tasks.where((t) => t.isCompleted).length;
    final isDark = ThemeService.isDarkMode(context);

    final bg = isDark ? const Color(0xFF0B1120) : const Color(0xFFFAF8F5);
    final line = isDark ? const Color(0xFF1E293B) : const Color(0xFFE5E1D8);
    final textHead = isDark ? Colors.white : const Color(0xFF111827);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111827) : AppColors.primary,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Task',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              user?.nama ?? 'IT Support KC BSG',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11.5,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Muat Ulang',
            onPressed: _loadTasks,
          ),
        ],
      ),
      bottomNavigationBar: _isLoading
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                decoration: BoxDecoration(
                  color: bg,
                  border: Border(top: BorderSide(color: line)),
                ),
                child: SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: _catatKerjaan,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'Catat Kerjaan',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : RefreshIndicator(
              onRefresh: _loadTasks,
              color: AppColors.accent,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  _progressBlock(done: done, total: total, textHead: textHead, textSub: textSub, line: line),
                  _infoLaporanPulang(textSub: textSub, line: line),
                  _sectionHeader(
                    'Tugas Hari Ini',
                    _tasks.isEmpty ? null : '$total tugas',
                    textHead: textHead,
                    textSub: textSub,
                  ),
                  if (_tasks.isEmpty)
                    _emptyToday(textSub)
                  else
                    ..._tasks.map(
                      (task) => _taskRow(
                        task,
                        isDark: isDark,
                        line: line,
                        textHead: textHead,
                        textSub: textSub,
                      ),
                    ),
                  if (_openTasks.isNotEmpty) ...[
                    _sectionHeader(
                      'Tugas Shift Sebelumnya',
                      '${_openTasks.length} belum selesai',
                      textHead: textHead,
                      textSub: textSub,
                    ),
                    ..._openTasks.map(
                      (task) => _openTaskRow(
                        task,
                        line: line,
                        textHead: textHead,
                        textSub: textSub,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _progressBlock({
    required int done,
    required int total,
    required Color textHead,
    required Color textSub,
    required Color line,
  }) {
    final semua = total > 0 && done == total;
    final value = total == 0 ? 0.0 : done / total;
    final accent = semua ? AppColors.success : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STATUS PENGERJAAN',
                      style: TextStyle(
                        fontSize: 9.5,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w600,
                        color: textSub,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$done dari $total selesai',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        color: textHead,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    semua ? Icons.check_circle_rounded : Icons.schedule_rounded,
                    size: 15,
                    color: accent,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    semua ? 'Semua selesai' : 'Sisa ${(total - done).clamp(0, total)}',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: accent),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: line,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoLaporanPulang({required Color textSub, required Color line}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tugas yang selesai otomatis masuk ke Laporan Pulang saat absen pulang.',
                  style: TextStyle(fontSize: 11.5, height: 1.35, color: textSub),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: line),
      ],
    );
  }

  Widget _sectionHeader(String title, String? trailing, {required Color textHead, required Color textSub}) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 2),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
              color: textHead,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(trailing, style: TextStyle(fontSize: 11, color: textSub)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyToday(Color textSub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Belum ada tugas dari SPV hari ini.',
              style: TextStyle(fontSize: 12, color: textSub),
            ),
          ),
          TextButton(
            onPressed: _loadTasks,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Cek Ulang', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _taskRow(
    DailyTaskModel task, {
    required bool isDark,
    required Color line,
    required Color textHead,
    required Color textSub,
  }) {
    final isDone = task.isCompleted ||
        DailyTaskService.getCachedTasksLocally().any((ct) => ct.id == task.id && ct.isCompleted);
    final isKhusus = task.kategori == 'khusus' || task.templateId == null || task.templateId!.isEmpty;
    final ongoing = !isDone ? DailyTaskService.getOngoingMaintenance(task) : null;
    final statusColor = isDone ? AppColors.success : (ongoing != null ? AppColors.accent : textSub);
    final statusText = isDone
        ? 'Selesai'
        : (ongoing != null ? 'Proses ${ongoing.doneCount}/${ongoing.totalPoints}' : 'Belum dikerjakan');
    final jamSelesai = (task.jamSelesai ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: isDone ? () => CompletedDailyTaskModal.show(context, task) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        task.judul,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14.5,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          color: isDone ? textSub : textHead,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          decorationColor: textSub,
                          decorationThickness: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDone
                              ? Icons.check_circle_rounded
                              : (ongoing != null ? Icons.autorenew_rounded : Icons.circle_outlined),
                          size: 13,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: statusColor),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  [
                    task.posName,
                    isKhusus ? 'Tugas Khusus' : 'Maintenance',
                    if (task.tanggal != _todayStr()) _formatTaskDateBadge(task.tanggal),
                  ].where((e) => e.trim().isNotEmpty).join(' · '),
                  style: TextStyle(fontSize: 11.5, color: textSub),
                ),
                if (task.isShared || task.isHandover) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (task.isShared) 'Bersama ${task.pesertaList.join(', ')}',
                      if (task.isHandover) 'Lanjutan dari ${task.handoverDari ?? '-'}',
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1),
                    ),
                  ),
                ],
                if (task.deskripsi.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    task.deskripsi,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, height: 1.4, color: textSub),
                  ),
                ],
                if (ongoing != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: ongoing.progress,
                      minHeight: 3,
                      backgroundColor: line,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                if (isDone)
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => CompletedDailyTaskModal.show(context, task),
                        icon: const Icon(Icons.photo_library_outlined, size: 15, color: AppColors.success),
                        label: Text(
                          jamSelesai.isNotEmpty ? 'Lihat Bukti ($jamSelesai)' : 'Lihat Bukti',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const Spacer(),
                      if (jamSelesai.isNotEmpty) ...[
                        Icon(Icons.schedule_rounded, size: 13, color: textSub),
                        const SizedBox(width: 4),
                        Text(jamSelesai, style: TextStyle(fontSize: 11, color: textSub)),
                      ],
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _serahkanTugas(task),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 40),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Belum Selesai',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 4),
                      FilledButton.icon(
                        onPressed: () => _startTask(task),
                        icon: Icon(
                          ongoing != null ? Icons.play_arrow_rounded : Icons.camera_alt_outlined,
                          size: 16,
                        ),
                        label: Text(
                          ongoing != null ? 'Lanjutkan' : 'Kerjakan',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: line),
      ],
    );
  }

  Widget _openTaskRow(
    DailyTaskModel task, {
    required Color line,
    required Color textHead,
    required Color textSub,
  }) {
    final lastLog = task.handoverList.isNotEmpty ? task.handoverList.last : null;
    final asal = lastLog != null
        ? 'Dilepas ${task.handoverDari ?? '-'}${lastLog.alasan.isNotEmpty ? ' · ${lastLog.alasan}' : ''}'
        : 'Dari shift sebelumnya';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.judul,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13.5,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: textHead,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${task.posName} · $asal',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, height: 1.35, color: textSub),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text(
                    'Belum selesai',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.danger),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _ambilTugas(task),
                    icon: const Icon(Icons.pan_tool_alt_outlined, size: 15),
                    label: const Text(
                      'Ambil & Kerjakan',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: line),
      ],
    );
  }
}
