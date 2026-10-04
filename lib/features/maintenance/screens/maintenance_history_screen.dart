import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/utils/timemark_formatter.dart';
import '../../../data/models/maintenance_submission.dart';
import '../../../data/models/template_model.dart';
import '../../../data/repositories/template_repository.dart';
import '../../../data/services/storage_service.dart';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Data Maintenance?',
          style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Data dan foto maintenance ini akan dihapus dari penyimpanan perangkat.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
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
            content: Text('Data maintenance berhasil dihapus.'),
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
    final isDark = ThemeService.isDarkMode(context);
    final bgScaffold = isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgScaffold,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Riwayat Maintenance',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: Colors.white,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.white70,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Draft Berjalan'),
                  if (drafts.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${drafts.length}',
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Selesai 100%'),
                  if (completed.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${completed.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: DRAFT BERJALAN
          drafts.isEmpty
              ? _buildEmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'Tidak Ada Draft Berjalan',
                  subtitle: 'Semua pekerjaan maintenance yang tertunda akan muncul di sini.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: drafts.length,
                  itemBuilder: (ctx, i) => _buildDraftCard(drafts[i]),
                ),

          // TAB 2: SELESAI 100%
          completed.isEmpty
              ? _buildEmptyState(
                  icon: Icons.task_alt_rounded,
                  title: 'Belum Ada Maintenance Selesai',
                  subtitle: 'Pekerjaan maintenance yang telah selesai 100% akan tersimpan dan dapat direview di sini.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: completed.length,
                  itemBuilder: (ctx, i) => _buildCompletedCard(completed[i]),
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftCard(MaintenanceSubmission s) {
    final progress = s.totalPoints > 0 ? s.doneCount / s.totalPoints : 0.0;
    final isDark = ThemeService.isDarkMode(context);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : AppColors.cardBorder;
    final textTitle = isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary;
    final textSub = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _resumeDraft(s),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.templateName,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: textTitle,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${s.posName} • ${WhatsAppReportService.formatIndonesianDate(s.createdAt)}',
                            style: TextStyle(fontSize: 11, color: textSub),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${s.doneCount}/${s.totalPoints} Foto',
                        style: const TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.warning),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                      tooltip: 'Hapus Draft',
                      onPressed: () => _deleteSubmission(s.id),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text(
                        'Lanjutkan Pengerjaan',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      onPressed: () => _resumeDraft(s),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedCard(MaintenanceSubmission s) {
    final isDark = ThemeService.isDarkMode(context);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : AppColors.cardBorder;
    final textTitle = isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary;
    final textSub = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openDetailSheet(s),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.templateName,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: textTitle,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${s.posName} • ${s.userName}',
                            style: TextStyle(fontSize: 11, color: textSub),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 13, color: AppColors.success),
                          SizedBox(width: 4),
                          Text(
                            '100% Selesai',
                            style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w800,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: isDark ? const Color(0xFF64748B) : Colors.grey.shade500),
                    const SizedBox(width: 5),
                    Text(
                      '${WhatsAppReportService.formatIndonesianDate(s.createdAt)} • ${TimemarkFormatter.formatClockTime(s.createdAt)} WITA',
                      style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Text(
                      'Lihat Detail & Share ›',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF38BDF8) : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
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
    final category = _resolveCategory();
    final pointsWithImages = submission.points.where((p) => p.imagePath != null && p.imagePath!.isNotEmpty).length;
    final isDark = ThemeService.isDarkMode(context);
    final sheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textHead = isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary;
    final textSub = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;
    final itemBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final itemBorder = isDark ? const Color(0xFF334155) : AppColors.cardBorder;
    final dividerClr = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: BoxDecoration(
        color: sheetBg,
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
                color: isDark ? const Color(0xFF475569) : Colors.grey.shade300,
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
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: textHead,
                        ),
                      ),
                      Text(
                        '${submission.posName} • ${submission.userName}',
                        style: TextStyle(fontSize: 11.5, color: textSub),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  tooltip: 'Hapus Riwayat',
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: dividerClr),

          // List of Points & Photos
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: submission.points.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final p = submission.points[i];
                final hasImage = p.imagePath != null && File(p.imagePath!).existsSync();
                final isSesuai = p.status == PointStatus.sesuai;

                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: itemBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: itemBorder),
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
                                )
                            : null,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: hasImage
                                ? Image.file(
                                    File(p.imagePath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 24),
                                  )
                                : const Icon(Icons.camera_alt_outlined, color: Colors.grey, size: 24),
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
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                color: textHead,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              p.alasan.isNotEmpty ? p.alasan : (isSesuai ? 'Sesuai standar' : 'Perlu pemeriksaan'),
                              style: TextStyle(
                                fontSize: 11,
                                color: isSesuai ? AppColors.success : AppColors.warning,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: isSesuai
                              ? AppColors.success.withValues(alpha: 0.12)
                              : AppColors.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isSesuai ? '✓ Sesuai' : '⚠️ Cek',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isSesuai ? AppColors.success : AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Bottom Action: Re-share to WA & Telegram
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: sheetBg,
              border: Border(top: BorderSide(color: dividerClr, width: 0.8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
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
                          fontFamily: 'PlusJakartaSans',
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
                              content: Text('✓ $pointsWithImages foto dibuka di WhatsApp. Teks telah disalin ke clipboard!'),
                              backgroundColor: AppColors.success,
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
                          fontFamily: 'PlusJakartaSans',
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
                              content: Text('✓ $pointsWithImages foto dibuka di Telegram. Teks telah disalin ke clipboard!'),
                              backgroundColor: AppColors.success,
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
          ),
        ],
      ),
    );
  }
}
