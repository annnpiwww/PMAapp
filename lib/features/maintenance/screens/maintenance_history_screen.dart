import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/tiket_colors.dart';
import '../../../core/widgets/app_file_image.dart';
import '../../../core/widgets/tiket/tiket.dart';
import '../../../core/utils/timemark_formatter.dart';
import '../../../data/models/maintenance_submission.dart';
import '../../../data/models/template_model.dart';
import '../../../data/repositories/template_repository.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/ai_vision_service.dart';
import '../../../data/services/whatsapp_report_service.dart';
import '../widgets/photo_preview_dialog.dart';
import 'maintenance_checklist_screen.dart';

class MaintenanceHistoryScreen extends StatefulWidget {
  final int initialTabIndex;

  const MaintenanceHistoryScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<MaintenanceHistoryScreen> createState() => _MaintenanceHistoryScreenState();
}

class _MaintenanceHistoryScreenState extends State<MaintenanceHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<MaintenanceSubmission> _submissions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
    _loadSubmissions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadSubmissions() {
    setState(() {
      _submissions = StorageService.getMaintenanceSubmissions() ?? [];
    });
  }

  List<MaintenanceSubmission> get _draftSubmissions =>
      _submissions.where((s) => !s.isComplete).toList();

  List<MaintenanceSubmission> get _completedSubmissions =>
      _submissions.where((s) => s.isComplete).toList();

  Future<void> _deleteSubmission(String id) async {
    final colors = TiketColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.dialog,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus Data Maintenance?',
          style: TextStyle(
            fontFamily: TiketType.fontFamily,
            fontWeight: FontWeight.w700,
            color: colors.ink,
          ),
        ),
        content: Text(
          'Data dan foto maintenance ini akan dihapus dari penyimpanan perangkat.',
          style: TextStyle(
            fontSize: 13,
            color: colors.body,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Batal',
              style: TextStyle(
                color: colors.body,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await StorageService.deleteMaintenanceSubmission(id);
      _loadSubmissions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data maintenance dihapus.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _resumeDraft(MaintenanceSubmission draft) {
    final template = TemplateRepository.instance.templates.firstWhere(
      (t) => t.id == draft.templateId,
      orElse: () => TemplateRepository.defaultTemplates.firstWhere(
        (t) => t.id == draft.templateId,
        orElse: () => TemplateRepository.defaultTemplates.first,
      ),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MaintenanceChecklistScreen(
          template: template,
          existingSubmission: draft,
        ),
      ),
    ).then((_) => _loadSubmissions());
  }

  void _openDetailSheet(MaintenanceSubmission submission) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MaintenanceDetailModal(
        submission: submission,
        onDelete: () async {
          Navigator.of(ctx).pop();
          await _deleteSubmission(submission.id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final drafts = _draftSubmissions;
    final completed = _completedSubmissions;
    final colors = TiketColors.of(context);
    final pad = TiketSpace.padOf(context);
    final type = TiketType.of(context);

    return Scaffold(
      backgroundColor: colors.canvas,
      body: Column(
        children: [
          TiketBand(
            leading: TiketIconButton(
              icon: Icons.arrow_back,
              semanticLabel: 'Kembali',
              onPressed: () => Navigator.pop(context),
            ),
            caption: 'Riwayat Maintenance',
            hero: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${drafts.length}',
                  style: type.hero(color: colors.onBand),
                ),
                const SizedBox(width: 8.0),
                Text(
                  'draft berjalan',
                  style: type.heroLabel(color: colors.onBand),
                ),
              ],
            ),
            footer: Text(
              '${completed.length} maintenance selesai 100%',
              style: type.caption(color: colors.bandCaption),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(pad, 12.0, pad, 8.0),
            child: TiketSegmented<int>(
              options: [
                (0, 'Draft Berjalan · ${drafts.length}'),
                (1, 'Selesai 100% · ${completed.length}'),
              ],
              selected: _tabController.index,
              onChanged: (index) {
                setState(() {
                  _tabController.animateTo(index);
                });
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: DRAFT BERJALAN
                drafts.isEmpty
                    ? _buildEmptyState(
                        icon: Icons.assignment_outlined,
                        title: 'Tidak Ada Draft Berjalan',
                        subtitle:
                            'Semua pekerjaan maintenance yang tertunda akan muncul di sini.',
                        colors: colors,
                        type: type,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        itemCount: drafts.length,
                        itemBuilder: (ctx, i) => _buildDraftRow(
                          drafts[i],
                          colors: colors,
                          type: type,
                          pad: pad,
                        ),
                      ),

                // TAB 2: SELESAI 100%
                completed.isEmpty
                    ? _buildEmptyState(
                        icon: Icons.task_alt_rounded,
                        title: 'Belum Ada Maintenance Selesai',
                        subtitle:
                            'Maintenance yang sudah selesai 100% tersimpan dan bisa dilihat lagi di sini.',
                        colors: colors,
                        type: type,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        itemCount: completed.length,
                        itemBuilder: (ctx, i) => _buildCompletedRow(
                          completed[i],
                          colors: colors,
                          type: type,
                          pad: pad,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required TiketColors colors,
    required TiketType type,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18.0),
              decoration: BoxDecoration(
                color: colors.soft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40.0, color: colors.mute),
            ),
            const SizedBox(height: 16.0),
            Text(
              title,
              style: type.section(color: colors.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6.0),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: type.meta(color: colors.body),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftRow(
    MaintenanceSubmission s, {
    required TiketColors colors,
    required TiketType type,
    required double pad,
  }) {
    final posTitle = s.posName.isNotEmpty ? s.posName : 'Lokasi tidak diketahui';
    final timeStr = TimemarkFormatter.formatClockTime(s.createdAt);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2.0),
                child: StatusMarker(
                  status: TiketStatus.attention,
                  size: 16.0,
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      posTitle,
                      style: type.rowTitle(color: colors.ink),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      s.templateName,
                      style: type.meta(color: colors.body),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      'Proses ${s.doneCount}/${s.totalPoints} poin · mulai $timeStr',
                      style: type.status(color: colors.signalText),
                    ),
                    const SizedBox(height: 10.0),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        TiketPill(
                          label: 'Lanjutkan Draft',
                          kind: TiketPillKind.primary,
                          onPressed: () => _resumeDraft(s),
                        ),
                        _DangerOutlinePill(
                          label: 'Hapus Draft',
                          onPressed: () => _deleteSubmission(s.id),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: pad + 16.0 + 12.0),
          child: Divider(
            height: 1.0,
            thickness: 1.0,
            color: colors.hairline,
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedRow(
    MaintenanceSubmission s, {
    required TiketColors colors,
    required TiketType type,
    required double pad,
  }) {
    final posTitle = s.posName.isNotEmpty ? s.posName : 'Lokasi tidak diketahui';
    final dateStr = WhatsAppReportService.formatIndonesianDate(s.createdAt);
    final timeStr = TimemarkFormatter.formatClockTime(s.createdAt);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const StatusMarker(
                status: TiketStatus.ok,
                size: 16.0,
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      posTitle,
                      style: type.rowTitle(color: colors.ink),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      '${s.templateName} · ${s.points.length} foto',
                      style: type.meta(color: colors.body),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      '$dateStr · $timeStr WITA',
                      style: type.caption(color: colors.body),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              TiketPill(
                label: 'Lihat Detail',
                kind: TiketPillKind.secondary,
                onPressed: () => _openDetailSheet(s),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: pad + 16.0 + 12.0),
          child: Divider(
            height: 1.0,
            thickness: 1.0,
            color: colors.hairline,
          ),
        ),
      ],
    );
  }
}

class _DangerOutlinePill extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _DangerOutlinePill({
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48.0, minWidth: 48.0),
      child: Center(
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: colors.danger, width: 1.5),
            foregroundColor: colors.danger,
            shape: const StadiumBorder(),
            minimumSize: const Size(0, 44.0),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
              color: colors.danger,
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal Bottom Sheet Detail & Re-share Maintenance Selesai
class _MaintenanceDetailModal extends StatelessWidget {
  final MaintenanceSubmission submission;
  final VoidCallback onDelete;

  const _MaintenanceDetailModal({
    required this.submission,
    required this.onDelete,
  });

  TemplateCategory _resolveCategory() {
    final tpl = TemplateRepository.defaultTemplates.firstWhere(
      (t) => t.id == submission.templateId,
      orElse: () => TemplateRepository.defaultTemplates.first,
    );
    return tpl.jenis;
  }

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final type = TiketType.of(context);
    final category = _resolveCategory();
    final pointsWithImages = submission.points.where((p) => p.imagePath != null && p.imagePath!.isNotEmpty).length;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: BoxDecoration(
        color: colors.dialog,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: colors.mute.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        submission.templateName,
                        style: type.rowTitle(color: colors.ink),
                      ),
                      Text(
                        '${submission.posName} • ${submission.userName}',
                        style: type.meta(color: colors.body),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: colors.danger),
                  tooltip: 'Hapus Riwayat',
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.hairline),

          // List of Points & Photos
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: submission.points.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final p = submission.points[i];
                final hasImage = p.imagePath != null && (kIsWeb || File(p.imagePath!).existsSync());
                final isSesuai = p.status == PointStatus.sesuai;
                final isTidakTerpasang = p.isTidakTerpasang;
                final isOk = isSesuai || isTidakTerpasang;
                final statusClr = isSesuai
                    ? colors.ok
                    : (isTidakTerpasang ? colors.body : colors.danger);

                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.soft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.hairline),
                  ),
                  child: Row(
                    children: [
                      // Thumbnail
                      GestureDetector(
                        onTap: hasImage
                            ? () => PhotoPreviewDialog.show(
                                  context,
                                  imagePath: p.imagePath!,
                                  title: p.label,
                                  pointResult: p,
                                  onAnalyze: (base64) =>
                                      AiVisionService.reanalyzePhoto(
                                    imageBase64: base64,
                                    konteks: p.label,
                                  ),
                                )
                            : null,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: colors.canvas,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: hasImage
                                ? AppFileImage(
                                    path: p.imagePath!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, size: 24, color: colors.mute),
                                  )
                                : Icon(Icons.camera_alt_outlined, color: colors.mute, size: 24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Point Label & Reason
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.label,
                              style: type.rowTitle(color: colors.ink),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              p.alasan.isNotEmpty
                                  ? p.alasan
                                  : (isSesuai
                                      ? 'Sesuai standar'
                                      : (isTidakTerpasang ? 'Barang tidak terpasang' : 'Perlu pemeriksaan')),
                              style: TextStyle(
                                fontFamily: TiketType.fontFamily,
                                fontSize: 11,
                                color: isOk ? statusClr : colors.signalText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (p.urgensi != TingkatUrgensi.normal) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Tingkat: ${p.urgensi.label}',
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: p.urgensi == TingkatUrgensi.urgent
                                      ? colors.danger
                                      : colors.signalText,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: statusClr.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isSesuai
                              ? '✓ Sesuai'
                              : (isTidakTerpasang ? '⛔ Tidak Ada' : '⚠️ Cek'),
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isOk ? statusClr : colors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Bottom Action: Re-share to WA & Telegram (Hanya jika laporan telah lengkap)
          if (submission.isComplete)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.dialog,
                border: Border(top: BorderSide(color: colors.hairline, width: 0.8)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFDCFCE7),
                          side: const BorderSide(color: Color(0xFF86EFAC), width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 16),
                        label: const Text(
                          'Share WhatsApp',
                          style: TextStyle(
                            fontFamily: 'Figtree',
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                            color: Color(0xFF15803D),
                          ),
                        ),
                        onPressed: () async {
                          await WhatsAppReportService.shareToWhatsApp(
                            submission: submission,
                            category: category,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✓ $pointsWithImages foto dibuka di WhatsApp. Teks tersalin, tinggal paste di chat.'),
                                backgroundColor: colors.ok,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFE0F2FE),
                          side: const BorderSide(color: Color(0xFF7DD3FC), width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.send_rounded, color: Color(0xFF0088CC), size: 16),
                        label: const Text(
                          'Share Telegram',
                          style: TextStyle(
                            fontFamily: 'Figtree',
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                            color: Color(0xFF0E6BA8),
                          ),
                        ),
                        onPressed: () async {
                          await WhatsAppReportService.shareToTelegram(
                            submission: submission,
                            category: category,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✓ $pointsWithImages foto dibuka di Telegram. Teks sudah disalin, tinggal paste di chat.'),
                                backgroundColor: colors.ok,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.dialog,
                border: Border(top: BorderSide(color: colors.hairline, width: 0.8)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: colors.signal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Laporan belum lengkap (${submission.doneCount}/${submission.totalPoints} foto). Lengkapi seluruh checkpoint untuk membagikan laporan.',
                        style: type.meta(color: colors.body),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
