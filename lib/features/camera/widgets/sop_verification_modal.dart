import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_file_image.dart';
import '../../../data/models/submission_model.dart';
import '../../../data/models/template_model.dart';
import '../../../data/services/ai_vision_service.dart';

class SopVerificationModal extends StatelessWidget {
  final TemplateModel template;
  final AiVerificationResult result;
  final String kodeVerifikasi;
  final String? imagePath;
  final VoidCallback onRetake;
  final VoidCallback onSave;
  final VoidCallback? onCancel;
  final VoidCallback? onShareTelegram;
  final VoidCallback? onShareWhatsApp;
  final bool isLoading;

  const SopVerificationModal({
    super.key,
    required this.template,
    required this.result,
    required this.kodeVerifikasi,
    this.imagePath,
    required this.onRetake,
    required this.onSave,
    this.onCancel,
    this.onShareTelegram,
    this.onShareWhatsApp,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isAIError = result.isFallback;
    final isSuccess = result.status == VerificationStatus.sesuai && !isAIError;
    final isFailure = result.status == VerificationStatus.tidakSesuai && !isAIError;

    final primaryColor = isSuccess
        ? AppColors.success
        : isFailure
            ? AppColors.danger
            : (isAIError ? const Color(0xFFD97706) : AppColors.warning);

    final bgColor = isSuccess
        ? AppColors.successLight
        : isFailure
            ? AppColors.dangerLight
            : (isAIError ? const Color(0xFFFFFBEB) : AppColors.warningLight);

    final borderColor = isSuccess
        ? AppColors.successBorder
        : isFailure
            ? AppColors.dangerBorder
            : (isAIError ? const Color(0xFFFDE68A) : AppColors.warningBorder);

    final confidencePercent = (result.confidenceScore * 100).toInt();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.accent, width: 2.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 24,
            spreadRadius: 2,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag indicator handle
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

            // Fallback Alert Banner (if Cloud AI failed)
            if (result.isFallback) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF3C7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.wifi_off_rounded, color: Color(0xFFD97706), size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SERVER AI OFFLINE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Koneksi ke server AI terputus. Foto dialihkan untuk Cek Manual oleh Supervisor.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF78350F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Hero Status Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 1.2),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          isSuccess
                              ? Icons.verified_rounded
                              : isFailure
                                  ? Icons.gpp_bad_rounded
                                  : Icons.shield_moon_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isSuccess
                                  ? 'SELESAI VERIFIKASI'
                                  : isFailure
                                      ? 'TIDAK SESUAI SOP'
                                      : (isAIError ? 'VERIFIKASI GAGAL' : 'PERLU CEK MANUAL'),
                              style: TextStyle(fontFamily: 'PlusJakartaSans', 
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isSuccess
                                  ? 'Verifikasi selesai, foto siap dikirim ke laporan & galeri'
                                  : isFailure
                                      ? 'Ditemukan ${result.poinGagal.isNotEmpty ? "${result.poinGagal.length} kriteria" : "hal"} yang belum memenuhi standar SOP'
                                      : (isAIError
                                          ? 'Koneksi AI terputus. Silakan foto ulang atau periksa manual'
                                          : 'Perlu konfirmasi dan pemeriksaan manual oleh Supervisor'),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: primaryColor.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (confidencePercent > 0) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: result.confidenceScore.clamp(0.0, 1.0),
                              backgroundColor: Colors.black.withValues(alpha: 0.08),
                              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                              minHeight: 5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Tingkat Keyakinan: $confidencePercent%',
                          style: TextStyle(fontFamily: 'PlusJakartaSans', 
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAIError ? Icons.error_outline_rounded : Icons.verified_user_rounded,
                              size: 13,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isAIError
                                  ? 'Verifikasi AI: Gagal / Terputus'
                                  : 'Verifikasi AI Aktif',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Meta Info Bar (Code & Template)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.qr_code_2_rounded, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        kodeVerifikasi,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      template.nama,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Preview Foto Hasil Capture (Anti-Blur Check with Tactical Frame)
            if (imagePath != null && imagePath!.isNotEmpty && File(imagePath!).existsSync()) ...[
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _showFullImagePreview(context, imagePath!),
                          child: SizedBox(
                            height: 190,
                            width: double.infinity,
                            child: AppFileImage(
                              path: imagePath!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Corner Tactical Accent (Top-Left)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24, width: 0.8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.photo_camera_rounded, color: AppColors.accent, size: 12),
                                SizedBox(width: 5),
                                Text(
                                  'Cek Kejernihan Foto',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Zoom Action Button (Top-Right)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => _showFullImagePreview(context, imagePath!),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accent.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Perbesar',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      color: const Color(0xFF1E293B),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: Color(0xFF94A3B8), size: 13),
                              SizedBox(width: 6),
                              Text(
                                'Pastikan foto tajam sebelum disimpan',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  color: Color(0xFFCBD5E1),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: onRetake,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.danger.withValues(alpha: 0.4),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.replay_rounded, size: 12, color: Color(0xFFFCA5A5)),
                                  SizedBox(width: 3),
                                  Text(
                                    'Foto Ulang',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 11,
                                      color: Color(0xFFFCA5A5),
                                      fontWeight: FontWeight.w800,
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
              const SizedBox(height: 14),
            ],

            // AI Explanation Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.infoBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.info,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result.alasan,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Failed Points (Negative Violations)
            if (result.poinGagal.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 16),
                  const SizedBox(width: 5),
                  Text(
                    'Kriteria Tidak Terpenuhi (${result.poinGagal.length}):',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...result.poinGagal.map((p) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.dangerBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.cancel_rounded, color: AppColors.danger, size: 15),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            p,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.danger,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 8),
            ],

            // Passed Points
            if (result.poinLolos.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 16),
                  const SizedBox(width: 5),
                  Text(
                    'Kriteria Terpenuhi (${result.poinLolos.length}):',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...result.poinLolos.map((p) => Container(
                    margin: const EdgeInsets.only(bottom: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.successBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.check_circle_rounded, color: AppColors.success, size: 14),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            p,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],

            const SizedBox(height: 18),

            // Action Buttons Dock
            if (isFailure) ...[
              ElevatedButton.icon(
                onPressed: onRetake,
                icon: const Icon(Icons.replay_rounded, size: 20),
                label: const Text('Foto Ulang'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Batal'),
              ),
            ] else ...[
              // Primary Submit Button
              ElevatedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.cloud_upload_rounded, size: 20),
                label: Text(
                  isSuccess ? 'Simpan & Kirim Laporan' : 'Simpan Laporan (Perlu Cek Manual)',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSuccess ? AppColors.success : AppColors.warning,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              // Card Bagikan Laporan: WhatsApp | Telegram
              if (onShareWhatsApp != null || onShareTelegram != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.share_rounded, size: 14, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            'Bagikan Laporan:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (onShareWhatsApp != null)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: onShareWhatsApp,
                                icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 16),
                                label: Text(
                                  'WhatsApp',
                                  style: TextStyle(fontFamily: 'PlusJakartaSans', 
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                    color: const Color(0xFF15803D),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDCFCE7),
                                  side: const BorderSide(color: Color(0xFF86EFAC), width: 1.2),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          if (onShareWhatsApp != null && onShareTelegram != null)
                            const SizedBox(width: 8),
                          if (onShareTelegram != null)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: onShareTelegram,
                                icon: const Icon(Icons.send_rounded, color: Color(0xFF229ED9), size: 16),
                                label: Text(
                                  'Telegram',
                                  style: TextStyle(fontFamily: 'PlusJakartaSans', 
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                    color: const Color(0xFF0369A1),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE0F2FE),
                                  side: const BorderSide(color: Color(0xFF7DD3FC), width: 1.2),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
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
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRetake,
                      icon: const Icon(
                        Icons.replay_rounded,
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                      label: const Text(
                        'Foto Ulang',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      label: const Text(
                        'Batal / Tutup',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }

  void _showFullImagePreview(BuildContext context, String path) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AppFileImage(
                  path: path,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.6),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close_rounded, size: 22),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
