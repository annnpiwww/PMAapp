import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_file_image.dart';
import '../../../../data/models/maintenance_submission.dart';
import '../../../../data/models/template_model.dart';

/// Premium tactile card for a single checkpoint in maintenance checklist.
/// Tactical-operational language, r14 card, 44×44 thumb, high-contrast badges.
class MaintenancePointCard extends StatelessWidget {
  final MaintenancePointResult result;
  final SopPoint point;
  final bool isDark;
  final VoidCallback onRetakePhoto;
  final VoidCallback onPreviewPhoto;
  final VoidCallback onTapCard;

  const MaintenancePointCard({
    super.key,
    required this.result,
    required this.point,
    required this.isDark,
    required this.onRetakePhoto,
    required this.onPreviewPhoto,
    required this.onTapCard,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = result.status != PointStatus.belumFoto;

    // Badge palette — AppColors tokens high contrast
    late final Color badgeColor;
    late final Color badgeBg;
    late final Color badgeBorder;
    late final IconData badgeIcon;
    late final String badgeLabel;

    switch (result.status) {
      case PointStatus.sesuai:
        badgeColor = AppColors.success;
        badgeBg = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : AppColors.successLight;
        badgeBorder = isDark ? const Color(0xFF10B981).withValues(alpha: 0.5) : AppColors.successBorder;
        badgeIcon = Icons.verified_rounded;
        badgeLabel = 'SESUAI';
        break;
      case PointStatus.tidakSesuai:
        badgeColor = AppColors.danger;
        badgeBg = isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.35) : AppColors.dangerLight;
        badgeBorder = isDark ? const Color(0xFFEF4444).withValues(alpha: 0.5) : AppColors.dangerBorder;
        badgeIcon = Icons.error_rounded;
        badgeLabel = 'TIDAK SESUAI';
        break;
      case PointStatus.perluCekManual:
        badgeColor = AppColors.warning;
        badgeBg = isDark ? const Color(0xFF78350F).withValues(alpha: 0.35) : AppColors.warningLight;
        badgeBorder = isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.5) : AppColors.warningBorder;
        badgeIcon = Icons.flag_rounded;
        badgeLabel = 'PERLU CEK';
        break;
      case PointStatus.belumFoto:
        badgeColor = AppColors.warning;
        badgeBg = isDark ? const Color(0xFF422006).withValues(alpha: 0.45) : const Color(0xFFFFF7ED);
        badgeBorder = isDark ? const Color(0xFFEA580C).withValues(alpha: 0.45) : const Color(0xFFFFEDD5);
        badgeIcon = Icons.camera_alt_rounded;
        badgeLabel = 'BELUM FOTO';
        break;
    }

    final cardBorder = isDark ? AppColors.darkBorderMuted : AppColors.cardBorder;
    final textTitle = isDark ? AppColors.textDarkPrimary : AppColors.textPrimary;
    final textSub = isDark ? AppColors.textDarkSecondary : AppColors.textSecondary;
    final textMeta = isDark ? AppColors.textDarkMuted : AppColors.textMuted;

    final cardBg = isDark
        ? (isDone ? AppColors.darkSurface : AppColors.darkSurfaceContainer)
        : (isDone ? AppColors.creamSurface : Colors.white);
    final hasThumb = isDone &&
        result.imagePath != null &&
        result.imagePath!.isNotEmpty &&
        (kIsWeb || File(result.imagePath!).existsSync());

    return Semantics(
      button: true,
      label: result.label,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDone ? badgeColor.withValues(alpha: 0.35) : cardBorder,
            width: isDone ? 1.2 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTapCard();
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 44×44 thumbnail — tap to zoom
                  GestureDetector(
                    onTap: hasThumb
                        ? () {
                            HapticFeedback.lightImpact();
                            onPreviewPhoto();
                          }
                        : null,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: hasThumb
                                ? Colors.black12
                                : badgeColor.withValues(alpha: isDark ? 0.22 : 0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: hasThumb ? Colors.black12 : badgeColor.withValues(alpha: 0.18),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: hasThumb
                              ? AppFileImage(
                                  path: result.imagePath!,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Icon(badgeIcon, color: badgeColor, size: 22),
                                )
                              : Icon(
                                  Icons.camera_alt_rounded,
                                  color: result.status == PointStatus.belumFoto
                                      ? AppColors.primary
                                      : badgeColor,
                                  size: 20,
                                ),
                        ),
                        if (hasThumb)
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                color: badgeColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Icon(badgeIcon, color: Colors.white, size: 10),
                            ),
                          ),
                        if (hasThumb)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.black.withValues(alpha: 0.0),
                              ),
                              child: const Center(
                                child: Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Middle: title + meta + badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.label,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            color: isDone ? textSub : textTitle,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (point.deskripsi.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            point.deskripsi,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 10.5,
                              height: 1.3,
                              color: textMeta,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (result.alasan.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            result.alasan,
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.25,
                              color: isDone ? textSub : textMeta,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (result.kendalaFisik != null && result.kendalaFisik!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.handyman_rounded, size: 11, color: Color(0xFFD97706)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Kendala: ${result.kendalaFisik}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: badgeBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(badgeIcon, size: 11, color: badgeColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    badgeLabel,
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                      color: badgeColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isDone && result.confidence > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: cardBorder),
                                ),
                                child: Text(
                                  '${(result.confidence * 100).toInt()}%',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: textMeta,
                                  ),
                                ),
                              ),
                            if (isDone)
                              Text(
                                '• Tap untuk detail',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: textMeta,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Trailing 48dp touch targets
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          icon: Icon(
                            isDone ? Icons.refresh_rounded : Icons.camera_alt_rounded,
                            color: isDone ? textMeta : AppColors.primary,
                            size: 20,
                          ),
                          tooltip: isDone ? 'Foto Ulang (48dp)' : 'Buka Kamera (48dp)',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            onRetakePhoto();
                          },
                        ),
                      ),
                      if (hasThumb)
                        SizedBox(
                          width: 48,
                          height: 32,
                          child: IconButton(
                            icon: const Icon(Icons.zoom_in_rounded, size: 18, color: AppColors.primary),
                            tooltip: 'Perbesar Foto',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              onPreviewPhoto();
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
