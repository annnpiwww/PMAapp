import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
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
                    color: (_isAdmin ? AppColors.primary : AppColors.textSecondary)
                        .withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: (_isAdmin ? AppColors.primary : Colors.grey.shade300)
                          .withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (_isAdmin ? AppColors.primary : AppColors.textSecondary)
                              .withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isAdmin
                              ? Icons.verified_user_rounded
                              : Icons.lock_outline_rounded,
                          color: _isAdmin ? AppColors.primary : AppColors.textSecondary,
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
                                color: _isAdmin ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isAdmin
                                  ? 'Kelola aturan SOP, kriteria visual foto, edit atau hapus template.'
                                  : 'Template SOP resmi perusahaan terkunci aman untuk operasional.',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
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
    final isMaint = template.jenis.isMaintenance;
    final pointCount = isMaint
        ? template.sopPoints.length
        : template.sopCriteria.length;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.cardBorder),
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
                  ? AppColors.warning.withValues(alpha: 0.12)
                  : AppColors.surfaceContainerLow,
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
              color: isMaint ? AppColors.warning : AppColors.primary,
              size: 22,
            ),
          ),
          title: Text(
            template.nama,
            style: TextStyle(fontFamily: 'PlusJakartaSans', 
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                template.deskripsi,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
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
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      template.jenis.displayName,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isMaint
                          ? "$pointCount Point • 1 foto/point"
                          : "$pointCount Kriteria SOP",
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
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
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "TEKNISI",
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
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
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "COUNT <5 / ≥5",
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
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
                  const Divider(height: 1, color: AppColors.cardBorder),
                  const SizedBox(height: 10),
                  Text(
                    'Kriteria Pengecekan AI:',
                    style: TextStyle(fontFamily: 'PlusJakartaSans', 
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
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
                                color: AppColors.warning.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${e.key + 1}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.warning,
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
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (e.value.deskripsi.isNotEmpty)
                                    Text(
                                      e.value.deskripsi,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
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
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
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
