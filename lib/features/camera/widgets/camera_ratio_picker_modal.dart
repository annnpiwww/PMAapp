import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/camera_aspect_ratio.dart';

/// Bottom sheet modal to select camera aspect ratio
class CameraRatioPickerModal extends StatelessWidget {
  final CameraAspectRatio currentRatio;
  final ValueChanged<CameraAspectRatio> onRatioSelected;

  const CameraRatioPickerModal({
    super.key,
    required this.currentRatio,
    required this.onRatioSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required CameraAspectRatio currentRatio,
    required ValueChanged<CameraAspectRatio> onRatioSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CameraRatioPickerModal(
        currentRatio: currentRatio,
        onRatioSelected: onRatioSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppColors.radiusBottomSheet)),
        border: Border(top: BorderSide(color: AppColors.darkBorderMuted, width: 1.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Pilih Aspek Rasio Kamera',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            ...CameraAspectRatio.values.map((ratio) {
              final isSelected = currentRatio == ratio;
              return ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                tileColor: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                leading: Icon(
                  ratio.icon,
                  color: isSelected ? AppColors.accent : Colors.white70,
                  size: 22,
                ),
                title: Text(
                  ratio.label,
                  style: TextStyle(
                    color: isSelected ? AppColors.accent : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  ratio.description,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                trailing: isSelected
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.accent,
                        size: 20,
                      )
                    : null,
                onTap: () {
                  onRatioSelected(ratio);
                  Navigator.of(context).pop();
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
