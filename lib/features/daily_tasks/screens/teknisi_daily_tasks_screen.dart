import 'package:flutter/material.dart';
import '../../../core/constants/tiket_colors.dart';
import '../../../core/widgets/tiket/tiket.dart';
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
import '../widgets/daily_task_action_pill.dart';
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
  List<DailyTaskModel> _openTasks = [];
  bool _isLoading = true;
  bool _isOffline = false;
  String _lastUpdateTime = '08:15';

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

    try {
      final tasks = await DailyTaskService.getTasksForTeknisi(
        tanggal: _todayStr(),
        teknisiNama: user.nama,
      );

      final openTasks = await DailyTaskService.getOpenHandoverTasks(excludeTeknisi: user.nama);

      final pendingCount = tasks.where((t) => !t.isCompleted).length;
      DailyTaskService.updatePendingCount(pendingCount);
      NotificationService.instance.showDailyTasksNotification(tasks: tasks);

      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      if (mounted) {
        setState(() {
          _tasks = tasks;
          _openTasks = openTasks;
          _isLoading = false;
          _isOffline = false;
          _lastUpdateTime = timeStr;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOffline = true;
        });
      }
    }
  }

  void _snack(String pesan, {bool sukses = true}) {
    if (!mounted) return;
    final colors = TiketColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              sukses ? Icons.check_circle_rounded : Icons.error_rounded,
              color: colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(pesan)),
          ],
        ),
        backgroundColor: sukses ? colors.ok : colors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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

  Future<void> _serahkanTugas(DailyTaskModel task) async {
    final user = AuthRepository.instance.currentUser;
    await TaskHandoverDialog.show(
      context,
      judul: task.judul,
      lokasi: task.posName,
      pemilik: task.teknisiNama,
      teknisiOptions: BranchService.instance.getTechnicians().where((t) => !DailyTaskService.isAssignedTo(task, t)).toList(),
      onSubmit: (alasan, penerus) async {
        final ok = await DailyTaskService.transferTask(
          task: task,
          keTeknisi: penerus,
          alasan: alasan,
          olehSiapa: user?.nama ?? task.teknisiNama,
        );
        _snack(
          ok
              ? (penerus.isEmpty
                  ? 'Tugas dilepas ke daftar terbuka untuk shift berikutnya.'
                  : 'Tugas diserahkan ke $penerus.')
              : 'Gagal menyimpan serah terima, coba lagi saat sinyal stabil.',
          sukses: ok,
        );
        if (ok) await _loadTasks();
        return ok;
      },
    );
  }

  Future<void> _ambilTugas(DailyTaskModel task) async {
    final user = AuthRepository.instance.currentUser;
    if (user == null) return;
    final res = await DailyTaskService.claimTask(task: task, olehSiapa: user.nama);
    if (res.success) {
      _snack('Tugas diambil alih. Kerjakan sampai selesai ya.', sukses: true);
      await _loadTasks();
    } else if (res.isTaken) {
      _snack(
        res.message ?? 'Tiket sudah diambil ${res.claimedBy ?? 'teknisi lain'}',
        sukses: false,
      );
      await _loadTasks();
    } else {
      _snack('Gagal mengambil tugas, coba lagi.', sukses: false);
    }
  }

  void _startTask(DailyTaskModel task) async {
    final isKhusus = task.kategori == 'khusus' ||
        (task.templateId == null || task.templateId!.isEmpty);

    if (!isKhusus) {
      final templates = TemplateRepository.instance.templates;
      final foundTpl = templates.firstWhere(
        (t) => t.id == task.templateId,
        orElse: () => TemplateRepository.defaultTemplates.firstWhere(
          (t) => t.id == task.templateId,
          orElse: () => templates.first,
        ),
      );

      final MaintenanceSubmission? ongoing = DailyTaskService.getOngoingMaintenance(task);

      if (ongoing != null) {
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
          final colors = TiketColors.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.play_circle_fill_rounded, color: colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lanjut progres: ${ongoing.doneCount}/${ongoing.totalPoints} foto selesai',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: colors.primary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        if (!mounted) return;

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

      if (foundTpl.isPerPoint) {
        final matchedLoc = LocationService.resolveLocationFromTask(
          posTag: task.posTag,
          posName: task.posName,
          judul: task.judul,
        );

        if (matchedLoc != null) {
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
    final colors = TiketColors.of(context);
    final user = AuthRepository.instance.currentUser;
    final total = _tasks.length;
    final done = _tasks.where((t) => t.isCompleted).length;
    final semua = total > 0 && done == total;

    return Scaffold(
      backgroundColor: colors.canvas,
      bottomNavigationBar: TiketBottomBar(
        primary: TiketPill(
          label: 'Catat Kerjaan baru',
          icon: Icons.add_rounded,
          kind: TiketPillKind.primary,
          height: 48,
          expand: true,
          onPressed: _catatKerjaan,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTasks,
        color: colors.primary,
        child: CustomScrollView(
          slivers: [
            _TeknisiSliverBand(
              expandedHeight: 220.0,
              compactTitle: 'Daily Task · $done/$total selesai',
              leading: TiketIconButton(
                icon: Icons.arrow_back_rounded,
                semanticLabel: 'Kembali',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              actions: [
                TiketIconButton(
                  icon: Icons.refresh_rounded,
                  semanticLabel: 'Muat Ulang',
                  onPressed: _loadTasks,
                ),
              ],
              caption: 'Daily Task · ${user?.nama ?? 'IT Support'}',
              hero: (_tasks.isEmpty && !_isLoading)
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Belum ada tugas',
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: colors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tugas dari SPV muncul di sini',
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colors.bandCaption,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$done/$total',
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: colors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'tugas selesai',
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.white,
                          ),
                        ),
                      ],
                    ),
              footer: (_tasks.isEmpty && !_isLoading)
                  ? null
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: List.generate(
                            total == 0 ? 1 : total.clamp(1, 16),
                            (i) => Expanded(
                              child: Container(
                                height: 6,
                                margin: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
                                decoration: BoxDecoration(
                                  color: (total > 0 && i < done) ? colors.white : colors.bandTrack,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          semua
                              ? 'Semua selesai · otomatis masuk Laporan Pulang'
                              : 'Sisa ${(total - done).clamp(0, total)} · otomatis masuk Laporan Pulang',
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colors.bandCaption,
                          ),
                        ),
                      ],
                    ),
            ),
            if (_isLoading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: colors.primary),
                      const SizedBox(height: 16),
                      Text(
                        'Memuat tugas hari ini',
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tugas SPV dan shift sebelumnya lagi diambil',
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 13,
                          color: colors.body,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isOffline) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: colors.soft,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.hairline),
                          ),
                          child: Row(
                            children: [
                              const StatusMarker(status: TiketStatus.attention),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Offline. Ini data terakhir yang tersimpan di HP ($_lastUpdateTime).',
                                  style: TextStyle(
                                    fontFamily: TiketType.fontFamily,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: colors.ink,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _loadTasks,
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(48, 36),
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                                child: Text(
                                  'Coba Lagi',
                                  style: TextStyle(
                                    fontFamily: TiketType.fontFamily,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: colors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_tasks.isEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_outlined, size: 48, color: colors.mute),
                              const SizedBox(height: 14),
                              Text(
                                'Hari ini masih kosong',
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: colors.ink,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'SPV belum membagi tugas buat kamu. Kerjaan yang kamu kerjakan sendiri bisa dicatat lewat tombol di bawah.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 13,
                                  color: colors.body,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Text(
                                'Hari ini',
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: colors.ink,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$total tugas',
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: colors.body,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_tasks.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final task = _tasks[index];
                      final isDone = task.isCompleted ||
                          DailyTaskService.getCachedTasksLocally().any((ct) => ct.id == task.id && ct.isCompleted);
                      final isKhusus = task.kategori == 'khusus' || task.templateId == null || task.templateId!.isEmpty;
                      final ongoing = !isDone ? DailyTaskService.getOngoingMaintenance(task) : null;
                      final jamSelesai = (task.jamSelesai ?? '').trim();

                      final statusText = isDone
                          ? (jamSelesai.isNotEmpty ? 'Selesai $jamSelesai' : 'Selesai')
                          : (ongoing != null ? 'Proses ${ongoing.doneCount}/${ongoing.totalPoints} poin' : 'Belum dikerjakan');

                      final statusColor = isDone
                          ? colors.okText
                          : (ongoing != null ? colors.signalText : colors.body);

                      final metaList = [
                        task.posName,
                        isKhusus ? 'Tugas Khusus' : 'Maintenance',
                        if (task.tanggal != _todayStr()) _formatTaskDateBadge(task.tanggal),
                        if (task.isShared) 'Bersama ${task.pesertaList.join(', ')}',
                        if (task.isHandover) 'Lanjutan dari ${task.handoverDari ?? '-'}',
                      ].where((e) => e.trim().isNotEmpty).toList();

                      return TiketRow(
                        leading: StatusMarker(
                          status: isDone
                              ? TiketStatus.ok
                              : (ongoing != null ? TiketStatus.attention : TiketStatus.notStarted),
                        ),
                        title: task.judul,
                        meta: metaList,
                        status: (statusText, statusColor),
                        onTap: isDone ? () => CompletedDailyTaskModal.show(context, task) : () => _startTask(task),
                        trailing: null,
                        below: isDone
                            ? Row(
                                children: [
                                  const Spacer(),
                                  DailyTaskActionPill(
                                    label: 'Lihat bukti',
                                    isPrimary: false,
                                    onPressed: () => CompletedDailyTaskModal.show(context, task),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  DailyTaskActionPill(
                                    label: 'Belum selesai',
                                    isPrimary: false,
                                    onPressed: () => _serahkanTugas(task),
                                  ),
                                  const Spacer(),
                                  DailyTaskActionPill(
                                    label: ongoing != null ? 'Lanjutkan' : 'Kerjakan',
                                    isPrimary: true,
                                    onPressed: () => _startTask(task),
                                  ),
                                ],
                              ),
                      );
                    },
                    childCount: _tasks.length,
                  ),
                ),
              if (_openTasks.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Row(
                      children: [
                        Text(
                          'Shift sebelumnya',
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.ink,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_openTasks.length} belum',
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colors.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final task = _openTasks[index];
                      final lastLog = task.handoverList.isNotEmpty ? task.handoverList.last : null;
                      final asal = lastLog != null
                          ? 'Dilepas ${task.handoverDari ?? '-'}${lastLog.alasan.isNotEmpty ? ' · ${lastLog.alasan}' : ''}'
                          : 'Dari shift sebelumnya';

                      return TiketRow(
                        leading: const StatusMarker(status: TiketStatus.notStarted),
                        title: task.judul,
                        meta: [task.posName, asal],
                        status: ('Belum dikerjakan', colors.body),
                        onTap: () => _ambilTugas(task),
                        below: Row(
                          children: [
                            const Spacer(),
                            DailyTaskActionPill(
                              label: 'Kerjakan',
                              isPrimary: true,
                              onPressed: () => _ambilTugas(task),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: _openTasks.length,
                  ),
                ),
              ],
              const SliverToBoxAdapter(
                child: SizedBox(height: 84),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TeknisiSliverBand extends StatelessWidget {
  final Widget? leading;
  final List<Widget> actions;
  final String? caption;
  final Widget? hero;
  final Widget? footer;
  final String compactTitle;
  final double expandedHeight;

  const _TeknisiSliverBand({
    this.leading,
    this.actions = const [],
    this.caption,
    this.hero,
    this.footer,
    required this.compactTitle,
    this.expandedHeight = 220.0,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TeknisiSliverBandDelegate(
        leading: leading,
        actions: actions,
        caption: caption,
        hero: hero,
        footer: footer,
        compactTitle: compactTitle,
        expandedHeight: expandedHeight,
        topInset: topInset,
      ),
    );
  }
}

class _TeknisiSliverBandDelegate extends SliverPersistentHeaderDelegate {
  final Widget? leading;
  final List<Widget> actions;
  final String? caption;
  final Widget? hero;
  final Widget? footer;
  final String compactTitle;
  final double expandedHeight;
  final double topInset;

  _TeknisiSliverBandDelegate({
    this.leading,
    this.actions = const [],
    this.caption,
    this.hero,
    this.footer,
    required this.compactTitle,
    required this.expandedHeight,
    required this.topInset,
  });

  @override
  double get minExtent => topInset + 56.0;

  @override
  double get maxExtent => expandedHeight + topInset;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final colors = TiketColors.of(context);
    final type = TiketType.of(context);
    final horizontalPad = TiketSpace.padOf(context);

    final maxShrink = (maxExtent - minExtent).clamp(1.0, double.infinity);
    final progress = (shrinkOffset / maxShrink).clamp(0.0, 1.0);
    final isCollapsed = progress > 0.8;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: colors.band),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ExcludeSemantics(
            child: CustomPaint(
              size: const Size(double.infinity, 10),
              painter: PerforationPainter(canvasColor: colors.canvas),
            ),
          ),
        ),
        if (progress < 0.9)
          Positioned(
            top: topInset + 56.0,
            left: horizontalPad,
            right: horizontalPad,
            bottom: 16.0,
            child: Opacity(
              opacity: (1.0 - progress * 1.5).clamp(0.0, 1.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (caption != null) ...[
                    Text(
                      caption!,
                      style: type.caption(color: colors.bandCaption),
                    ),
                    const SizedBox(height: 4.0),
                  ],
                  if (hero != null) ...[
                    hero!,
                    const SizedBox(height: 12.0),
                  ],
                  ?footer,
                ],
              ),
            ),
          ),
        Positioned(
          top: topInset,
          left: 0,
          right: 0,
          height: 56.0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: NavigationToolbar(
              leading: leading,
              middle: Opacity(
                opacity: isCollapsed ? ((progress - 0.8) / 0.2).clamp(0.0, 1.0) : 0.0,
                child: Text(
                  compactTitle,
                  style: type.section(color: colors.onBand),
                ),
              ),
              trailing: actions.isNotEmpty
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8.0),
                          actions[i],
                        ],
                      ],
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _TeknisiSliverBandDelegate oldDelegate) {
    return oldDelegate.compactTitle != compactTitle ||
        oldDelegate.caption != caption ||
        oldDelegate.hero != hero ||
        oldDelegate.footer != footer ||
        oldDelegate.topInset != topInset ||
        oldDelegate.expandedHeight != expandedHeight;
  }
}
