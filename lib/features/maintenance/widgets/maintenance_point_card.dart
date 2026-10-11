import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_file_image.dart';
import '../../../../data/models/maintenance_submission.dart';
import '../../../../data/models/template_model.dart';

/// Card item widget representing a single point checkpoint in the checklist
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
    final cardBorder = isDark ? const Color(0xFF334155) : AppColors.cardBorder;
    final textTitle = isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary;
    final textSub = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;

    final isDone = result.status != PointStatus.belumFoto;
    final IconData icon;
    final Color col;
    switch (result.status) {
      case PointStatus.sesuai:
        icon = Icons.check_circle_rounded;
        col = AppColors.success;
        break;
      case PointStatus.tidakSesuai:
        icon = Icons.cancel_rounded;
        col = AppColors.danger;
        break;
      case PointStatus.perluCekManual:
        icon = Icons.help_rounded;
        col = AppColors.warning;
        break;
      default:
        icon = Icons.radio_button_unchecked_rounded;
        col = AppColors.textMuted;
    }

    final cardItemBg = isDark
        ? (isDone ? const Color(0xFF162032) : const Color(0xFF1E293B))
        : (isDone ? const Color(0xFFFBFBFB) : Colors.white);

    return Opacity(
      opacity: isDone ? 0.82 : 1.0,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4.5),
        color: cardItemBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDone ? col.withValues(alpha: 0.4) : cardBorder,
            width: isDone ? 1.2 : 1.0,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          leading: (isDone && result.imagePath != null && File(result.imagePath!).existsSync())
              ? GestureDetector(
                  onTap: onPreviewPhoto,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AppFileImage(
                          path: result.imagePath!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: col.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: col, size: 24),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: col,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Icon(icon, color: Colors.white, size: 10),
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDone
                        ? col.withValues(alpha: 0.12)
                        : AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isDone ? icon : Icons.camera_alt_rounded,
                    color: isDone ? col : AppColors.primary,
                    size: 22,
                  ),
                ),
          title: Text(
            result.label,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDone ? textSub : textTitle,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.alasan.isNotEmpty) ...[
                Text(
                  result.alasan,
                  style: TextStyle(fontSize: 10, color: textSub),
                ),
              ],
              if (result.kendalaFisik != null && result.kendalaFisik!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.handyman_rounded, size: 10, color: Colors.orange),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Kendala: ${result.kendalaFisik}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: col.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      result.status.label,
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: col),
                    ),
                  ),
                  if (isDone) ...[
                    const SizedBox(width: 6),
                    const Text(
                      '• Terverifikasi AI',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDone && result.imagePath != null)
                IconButton(
                  icon: const Icon(Icons.zoom_in_rounded, size: 22, color: Colors.blueAccent),
                  tooltip: 'Cek Foto',
                  onPressed: onPreviewPhoto,
                ),
              IconButton(
                icon: Icon(
                  isDone ? Icons.refresh_rounded : Icons.camera_alt_rounded,
                  color: isDone ? AppColors.textSecondary : AppColors.primary,
                  size: 20,
                ),
                tooltip: isDone ? 'Foto Ulang' : 'Buka Kamera',
                onPressed: onRetakePhoto,
              ),
            ],
          ),
          onTap: onTapCard,
        ),
      ),
    );
  }
}
