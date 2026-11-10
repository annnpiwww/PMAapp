import 'package:flutter/material.dart';
import '../../../core/constants/tiket_colors.dart';
import '../../../core/widgets/tiket/tiket.dart';
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
    final colors = TiketColors.of(context);
    final templates = TemplateRepository.instance.templates;

    return Container(
      decoration: BoxDecoration(
        color: colors.dialog,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: colors.bandLine, width: 1.0),
        ),
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
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilih Template SOP',
                          style: TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: colors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pilih alur pemeriksaan atau absen',
                          style: TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 13,
                            color: colors.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      color: colors.mute,
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Template List (flat rows with hairline dividers)
              for (int i = 0; i < templates.length; i++) ...[
                Builder(
                  builder: (context) {
                    final t = templates[i];
                    final isSelected = selectedTemplate?.id == t.id;
                    final isTeknisi = t.isPerPoint || t.jenis.isMaintenance;

                    return InkWell(
                      onTap: () async {
                        Navigator.of(context).pop();
                        onTemplateSelected(t);

                        if (t.isPerPoint) {
                          await showDialog(
                            context: context,
                            builder: (_) =>
                                MaintenanceSetupDialog(initialTemplate: t),
                          );
                          final templates = TemplateRepository.instance.templates;
                          final defaultAbsensi = templates.firstWhere(
                            (tpl) => tpl.jenis == TemplateCategory.absensi,
                            orElse: () => TemplateRepository.defaultTemplates.first,
                          );
                          onTemplateSelected(defaultAbsensi);
                          onLocationRefreshRequired?.call();
                        } else if (t.jenis == TemplateCategory.absensi) {
                          AbsensiKategoriDialog.show(context, onSaved: () {
                            onLocationRefreshRequired?.call();
                          });
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Content Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.nama,
                                    style: TextStyle(
                                      fontFamily: 'Figtree',
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w700,
                                      color: colors.ink,
                                    ),
                                    softWrap: true,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    isTeknisi
                                        ? 'Maintenance · ${t.sopPoints.length} titik foto'
                                        : t.deskripsi,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.body,
                                      fontFamily: 'Figtree',
                                      height: 1.3,
                                    ),
                                    softWrap: true,
                                  ),
                                  if (t.jenis == TemplateCategory.absensi) ...[
                                    const SizedBox(height: 8),
                                    TiketPill(
                                      kind: TiketPillKind.secondary,
                                      label: 'Shift: ${AbsensiSetupService.instance.selectedKategori.displayName} • Ganti',
                                      onPressed: () {
                                        AbsensiKategoriDialog.show(context, onSaved: () {
                                          onLocationRefreshRequired?.call();
                                        });
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Selection radio/check trailing in primary
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: isSelected
                                  ? Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: colors.primary,
                                      ),
                                      child: Icon(
                                        Icons.check,
                                        size: 14,
                                        color: colors.onPrimary,
                                      ),
                                    )
                                  : Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: colors.mute,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (i < templates.length - 1)
                  Divider(color: colors.hairline, height: 1),
              ],
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}
