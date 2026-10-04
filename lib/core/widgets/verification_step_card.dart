import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Dynamic Floating Pill — Konsep 3
/// Tampilan modern, mengambang ringkas tanpa menutupi layar bidik kamera.
/// Tanpa kata-kata basa-basi/fluff. Fokus pada status, step progress, dan template.
class VerificationStepCard extends StatelessWidget {
  final int currentStep; // 1..4
  final String statusText; // e.g. "Sedang diverifikasi"
  final String? templateName; // optional: "Absensi Teknisi"
  final double spinnerSize;
  final double spinnerStroke;
  final VoidCallback? onFastBypass;

  const VerificationStepCard({
    super.key,
    required this.currentStep,
    required this.statusText,
    this.templateName,
    this.spinnerSize = 22,
    this.spinnerStroke = 2.5,
    this.onFastBypass,
  });

  @override
  Widget build(BuildContext context) {
    final stepNum = currentStep.clamp(1, 4);
    final progressValue = stepNum / 4.0;
    final isDone = stepNum >= 4;

    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone ? AppColors.success : AppColors.accent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row Utama: Pulse Status Icon + Teks Status + Step Counter
          Row(
            children: [
              // Animated Pulse / Status Indicator
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: (isDone ? AppColors.success : AppColors.accent).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: isDone
                    ? const Icon(Icons.check_rounded, color: AppColors.success, size: 18)
                    : SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.accent,
                        ),
                      ),
              ),
              const SizedBox(width: 12),

              // Status Teks Ringkas
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (templateName != null && templateName!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        templateName!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Step Counter Badge: e.g. "3/4"
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Text(
                  '$stepNum/4',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDone ? AppColors.success : AppColors.accent,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Micro Linear Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 4,
              backgroundColor: const Color(0xFF1E293B),
              valueColor: AlwaysStoppedAnimation<Color>(
                isDone ? AppColors.success : AppColors.accent,
              ),
            ),
          ),

          if (onFastBypass != null && !isDone && stepNum >= 2) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onFastBypass,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.bolt_rounded, size: 14, color: AppColors.accent),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Sinyal Lemah? Lewati & Simpan Cepat',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFCBD5E1),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
