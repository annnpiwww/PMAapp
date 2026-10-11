import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/template_model.dart';
import '../../../data/repositories/template_repository.dart';
import '../../../data/services/absensi_setup_service.dart';
import '../../maintenance/widgets/maintenance_setup_dialog.dart';
import '../../templates/widgets/absensi_kategori_dialog.dart';

/// Bottom sheet modal to quickly pick SOP templates
class TemplateQuickPickerModal extends StatelessWidget {
  final TemplateModel? selectedTemplate;
  final ValueChanged<TemplateModel> onTemplateSelected;
  final VoidCallback? onLocationRefreshRequired;

  const TemplateQuickPickerModal({
    super.key,
    required this.selectedTemplate,
    required this.onTemplateSelected,
    this.onLocationRefreshRequired,
  });

  static Future<void> show(
    BuildContext context, {
    required TemplateModel? selectedTemplate,
    required ValueChanged<TemplateModel> onTemplateSelected,
    VoidCallback? onLocationRefreshRequired,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bCtx) => TemplateQuickPickerModal(
        selectedTemplate: selectedTemplate,
        onTemplateSelected: onTemplateSelected,
        onLocationRefreshRequired: onLocationRefreshRequired,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final templates = TemplateRepository.instance.templates;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle Bar Minimalis
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.checklist_rtl_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pilih Template SOP',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Pilih alur pemeriksaan atau absen',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Template List
              ...templates.map((t) {
                final isSelected = selectedTemplate?.id == t.id;
                final isTeknisi = t.isPerPoint || t.jenis.isMaintenance;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isTeknisi
                            ? const Color(0xFFFFFBEB)
                            : AppColors.primary.withValues(alpha: 0.05))
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? (isTeknisi
                              ? AppColors.warning
                              : AppColors.primary)
                          : AppColors.cardBorder,
                      width: isSelected ? 1.8 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: (isTeknisi
                                      ? AppColors.warning
                                      : AppColors.primary)
                                  .withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        Navigator.of(context).pop();
                        onTemplateSelected(t);

                        if (t.isPerPoint) {
                          await showDialog(
                            context: context,
                            builder: (_) =>
                                MaintenanceSetupDialog(initialTemplate: t),
                          );
                          onLocationRefreshRequired?.call();
                        } else if (t.jenis == TemplateCategory.absensi) {
                          AbsensiKategoriDialog.show(context, onSaved: () {
                            onLocationRefreshRequired?.call();
                          });
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon Box Indicator
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isTeknisi
                                    ? AppColors.warning.withValues(alpha: 0.15)
                                    : AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isTeknisi
                                      ? AppColors.warning.withValues(alpha: 0.3)
                                      : AppColors.primary.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  isTeknisi
                                      ? Icons.construction_rounded
                                      : Icons.badge_outlined,
                                  color: isTeknisi
                                      ? AppColors.warning
                                      : AppColors.primary,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Content Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isTeknisi
                                              ? AppColors.warning
                                              : AppColors.primary,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isTeknisi
                                              ? 'MAINTENANCE'
                                              : t.jenis.name.toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 9.5,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (isTeknisi)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            '${t.sopPoints.length} Titik Foto',
                                            style: const TextStyle(
                                              color: Color(0xFF92400E),
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    t.nama,
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 13.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w700,
                                      color: isSelected
                                          ? (isTeknisi
                                              ? const Color(0xFF92400E)
                                              : AppColors.primary)
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    t.deskripsi,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      height: 1.25,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (t.jenis == TemplateCategory.absensi) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.primary.withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.verified_user_outlined,
                                            size: 13,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Shift: ${AbsensiSetupService.instance.selectedKategori.displayName}',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Text(
                                            '• Ganti',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: AppColors.accent,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Checkmark selection circle
                            Padding(
                              padding: const EdgeInsets.only(top: 2, left: 8),
                              child: isSelected
                                  ? Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isTeknisi
                                            ? AppColors.warning
                                            : AppColors.primary,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}
