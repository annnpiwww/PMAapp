import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/theme_service.dart';
import '../../../data/models/template_model.dart';
import '../../../data/repositories/template_repository.dart';
import '../../maintenance/widgets/maintenance_setup_dialog.dart';
import '../../maintenance/widgets/technician_pin_dialog.dart';
import '../widgets/absensi_kategori_dialog.dart';
import 'template_editor_screen.dart';

class TemplateListScreen extends StatefulWidget {
  final bool isAdmin;

  const TemplateListScreen({super.key, this.isAdmin = false});

  @override
  State<TemplateListScreen> createState() => _TemplateListScreenState();
}

class _TemplateListScreenState extends State<TemplateListScreen> {
  late bool _isAdmin;

  @override
  void initState() {
    super.initState();
    _isAdmin = widget.isAdmin;
    TemplateRepository.instance.addListener(_onRepoChange);
  }
  @override
  void dispose() {
    TemplateRepository.instance.removeListener(_onRepoChange);
    super.dispose();
  }

  void _onRepoChange() {
    if (mounted) setState(() {});
  }
  void _requestAdminUnlock() {
    showDialog(
      context: context,
      builder: (_) => TechnicianPinDialog(
        title: 'Buka Kunci Admin SOP',
        subtitle: 'Masukkan PIN untuk mengaktifkan mode edit template SOP.',
        onPinVerified: () {
          setState(() {
            _isAdmin = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Mode Admin aktif: Anda dapat mengedit & membuat template SOP.',
              ),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAbsensiKategoriModal(BuildContext context) {
    AbsensiKategoriDialog.show(context);
  }

  void _confirmDelete(TemplateModel template) {
    if (!_isAdmin) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Hapus Template SOP?',
          style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Hapus template "${template.nama}" dari daftar SOP?',
          style: TextStyle(fontFamily: 'PlusJakartaSans', ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal & Tutup'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              await TemplateRepository.instance.deleteTemplate(template.id);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.isDarkMode(context);
    final templates = TemplateRepository.instance.templates;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Template SOP'),
        actions: [
          if (_isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.restore_rounded),
              tooltip: 'Reset Template Bawaan',
              onPressed: () async {
                await TemplateRepository.instance.resetToDefaults();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Template bawaan berhasil di-reset!'),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.lock_open_rounded, color: AppColors.success),
              tooltip: 'Mode Admin Aktif (Kunci)',
              onPressed: () {
                setState(() => _isAdmin = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Mode Admin dinonaktifkan.'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.lock_outline_rounded),
              tooltip: 'Buka Kunci Admin (PIN)',
              onPressed: _requestAdminUnlock,
            ),
        ],
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TemplateEditorScreen()),
                );
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Buat Template'),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Header Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (_isAdmin ? AppColors.primary : (isDark ? const Color(0xFF64748B) : AppColors.textSecondary))
                        .withValues(alpha: isDark ? 0.15 : 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: (_isAdmin ? AppColors.primary : (isDark ? const Color(0xFF334155) : Colors.grey.shade300))
                          .withValues(alpha: isDark ? 0.35 : 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (_isAdmin ? AppColors.primary : (isDark ? const Color(0xFF64748B) : AppColors.textSecondary))
                              .withValues(alpha: isDark ? 0.25 : 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isAdmin
                              ? Icons.verified_user_rounded
                              : Icons.lock_outline_rounded,
                          color: _isAdmin
                              ? (isDark ? const Color(0xFF38BDF8) : AppColors.primary)
                              : (isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isAdmin
                                  ? 'Standarisasi SOP BSS Parking (Mode Admin)'
                                  : 'Standarisasi SOP BSS Parking',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _isAdmin
                                    ? (isDark ? const Color(0xFF38BDF8) : AppColors.primary)
                                    : (isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isAdmin
                                  ? 'Kelola aturan SOP, kriteria visual foto, edit atau hapus template.'
                                  : 'Template SOP resmi perusahaan terkunci aman untuk operasional.',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                if (templates.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        const Icon(
                          Icons.folder_open_rounded,
                          size: 48,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Belum ada template SOP.',
                          style: TextStyle(fontFamily: 'PlusJakartaSans', 
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            TemplateRepository.instance.resetToDefaults();
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Muat Template Bawaan'),
                        ),
                      ],
                    ),
                  )
                else
                  ...templates.map(_buildTemplateCard),

                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateCard(TemplateModel template) {
    final isDark = ThemeService.isDarkMode(context);
    final cardBorder = isDark ? const Color(0xFF334155) : AppColors.cardBorder;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textTitle = isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary;
    final textSub = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;
    final isMaint = template.jenis.isMaintenance;
    final pointCount = isMaint
        ? template.sopPoints.length
        : template.sopCriteria.length;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cardBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: isMaint
                  ? (isDark ? const Color(0xFF78350F).withValues(alpha: 0.35) : AppColors.warning.withValues(alpha: 0.12))
                  : (isDark ? const Color(0xFF0F172A) : AppColors.surfaceContainerLow),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              template.jenis == TemplateCategory.absensi
                  ? Icons.badge_outlined
                  : template.jenis == TemplateCategory.briefing
                  ? Icons.groups_outlined
                  : template.jenis == TemplateCategory.maintPos
                  ? Icons.home_repair_service_outlined
                  : template.jenis == TemplateCategory.maintBarrier
                  ? Icons.fence_outlined
                  : template.jenis == TemplateCategory.maintManless
                  ? Icons.point_of_sale_outlined
                  : template.jenis == TemplateCategory.maintServer
                  ? Icons.computer_outlined
                  : template.jenis == TemplateCategory.lokasi
                  ? Icons.local_parking_outlined
                  : Icons.checklist_rounded,
              color: isMaint
                  ? (isDark ? const Color(0xFFFDE68A) : AppColors.warning)
                  : (isDark ? const Color(0xFF38BDF8) : AppColors.primary),
              size: 22,
            ),
          ),
          title: Text(
            template.nama,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans', 
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: textTitle,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                template.deskripsi,
                style: TextStyle(
                  fontSize: 11,
                  color: textSub,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0284C7).withValues(alpha: 0.25)
                          : AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      template.jenis.displayName,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF38BDF8) : AppColors.primary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isMaint
                          ? "$pointCount Point • 1 foto/point"
                          : "$pointCount Kriteria SOP",
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: textSub,
                      ),
                    ),
                  ),
                  if (template.requiredRole == TemplateRole.teknisi)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF78350F).withValues(alpha: 0.35)
                            : AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "TEKNISI",
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFFDE68A) : AppColors.warning,
                        ),
                      ),
                    ),
                  if (template.aiMode == AiMode.countClassify)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF064E3B).withValues(alpha: 0.35)
                            : AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "COUNT <5 / ≥5",
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF6EE7B7) : AppColors.success,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 1, color: cardBorder),
                  const SizedBox(height: 10),
                  Text(
                    'Kriteria Pengecekan AI:',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans', 
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: textTitle,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (isMaint)
                    ...template.sopPoints.asMap().entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF78350F).withValues(alpha: 0.35)
                                    : AppColors.warning.withValues(
                                        alpha: 0.12,
                                      ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${e.key + 1}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFFDE68A) : AppColors.warning,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.value.label,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: textTitle,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (e.value.deskripsi.isNotEmpty)
                                    Text(
                                      e.value.deskripsi,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: textSub,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    })
                  else
                    ...template.sopCriteria.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.check_box_outlined,
                                size: 14,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: textSub,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 10),
                  // Absensi: tombol pilih kategori (modal) — hanya untuk absensi
                  if (template.jenis == TemplateCategory.absensi)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showAbsensiKategoriModal(context),
                        icon: const Icon(
                          Icons.badge_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        label: const Text('Pilih Kategori Absensi'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),

                  if (template.jenis == TemplateCategory.absensi)
                    const SizedBox(height: 8),

                  if (isMaint)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => TechnicianPinDialog(
                              onPinVerified: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => MaintenanceSetupDialog(
                                    initialTemplate: template,
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: Text(
                          'Mulai Maintenance (${template.sopPoints.length} Poin Standar)',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  if (isMaint) const SizedBox(height: 8),
                  if (_isAdmin)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TemplateEditorScreen(
                                  existingTemplate: template,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit_rounded, size: 14),
                          label: const Text('Edit'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(80, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _confirmDelete(template),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 14,
                            color: AppColors.danger,
                          ),
                          label: const Text(
                            'Hapus',
                            style: TextStyle(color: AppColors.danger),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.dangerBorder),
                            minimumSize: const Size(80, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Icon(Icons.lock_rounded, size: 12, color: AppColors.textSecondary),
                            SizedBox(width: 5),
                            Text(
                              'Template Terkunci (SOP Resmi)',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
