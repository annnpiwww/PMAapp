import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/maintenance_submission.dart';
import '../../../../data/models/template_model.dart';
import '../../../../data/services/google_sheets_service.dart';
import '../../../../data/services/whatsapp_report_service.dart';

/// Card widget to share maintenance report via WhatsApp or Telegram
class MaintenanceShareReportCard extends StatelessWidget {
  final MaintenanceSubmission submission;
  final TemplateCategory category;
  final List<int> effectiveUnits;
  final Future<void> Function() onSave;

  const MaintenanceShareReportCard({
    super.key,
    required this.submission,
    required this.category,
    required this.effectiveUnits,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    if (!submission.isComplete) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.share_rounded, color: AppColors.primary, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                'Bagikan Laporan (${submission.doneCount} Foto Selesai)',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${submission.doneCount}/${submission.totalPoints} Foto Lengkap',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final rangeNote = effectiveUnits.length > 1
                        ? 'Pos ${effectiveUnits.first} - Pos ${effectiveUnits.last}'
                        : 'Pos ${effectiveUnits.first}';
                    await onSave();
                    // Sinkronisasi otomatis ke Google Sheet SPV di background
                    unawaited(GoogleSheetsService.syncMaintenanceToGoogleSheet(
                      submission: submission,
                      category: category,
                      unitCount: effectiveUnits.length,
                    ));
                    // Kirim laporan teks & foto ke WhatsApp
                    await WhatsAppReportService.shareToWhatsApp(
                      submission: submission,
                      category: category,
                      unitCount: effectiveUnits.length,
                      gateOutNotes: category == TemplateCategory.maintPos ? rangeNote : null,
                    );
                    if (context.mounted) {
                      final fotoCount = submission.points.where((p) => p.imagePath != null && p.imagePath!.isNotEmpty).length;
                      final msg = fotoCount > 1
                          ? '✓ $fotoCount foto dibuka di WhatsApp. Teks laporan telah disalin ke clipboard, silakan paste di chat!'
                          : '✓ Laporan dibuka di WhatsApp & disinkronkan ke Google Sheet SPV!';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 16),
                  label: const Text(
                    'WhatsApp',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                      color: Color(0xFF15803D),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFDCFCE7),
                    side: const BorderSide(color: Color(0xFF86EFAC), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final rangeNote = effectiveUnits.length > 1
                        ? 'Pos ${effectiveUnits.first} - Pos ${effectiveUnits.last}'
                        : 'Pos ${effectiveUnits.first}';
                    await onSave();
                    await WhatsAppReportService.shareToTelegram(
                      submission: submission,
                      category: category,
                      unitCount: effectiveUnits.length,
                      gateOutNotes: category == TemplateCategory.maintPos ? rangeNote : null,
                    );
                    if (context.mounted) {
                      final fotoCount = submission.points.where((p) => p.imagePath != null && p.imagePath!.isNotEmpty).length;
                      final msg = fotoCount > 1
                          ? '✓ $fotoCount foto dibuka di Telegram. Teks laporan telah disalin ke clipboard, silakan paste di chat!'
                          : '✓ Laporan dibuka di Telegram!';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF0088CC), size: 16),
                  label: const Text(
                    'Telegram',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                      color: Color(0xFF0E6BA8),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFE0F2FE),
                    side: const BorderSide(color: Color(0xFF7DD3FC), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
