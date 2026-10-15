import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Bottom sheet modal to select camera countdown timer
class CameraTimerPickerModal extends StatelessWidget {
  final int currentSeconds;
  final ValueChanged<int> onTimerSelected;

  const CameraTimerPickerModal({
    super.key,
    required this.currentSeconds,
    required this.onTimerSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required int currentSeconds,
    required ValueChanged<int> onTimerSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CameraTimerPickerModal(
        currentSeconds: currentSeconds,
        onTimerSelected: onTimerSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const timerOptions = [
      (seconds: 0, label: 'Mati'),
      (seconds: 3, label: '3 Detik'),
      (seconds: 5, label: '5 Detik'),
    ];

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
              'Timer Kamera',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...timerOptions.map((opt) {
              final isSelected = currentSeconds == opt.seconds;
              return ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                tileColor: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppColors.accent.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.08),
                    border: Border.all(
                      color: isSelected ? AppColors.accent : Colors.white24,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: opt.seconds == 0
                        ? Icon(
                            Icons.timer_off_outlined,
                            color: isSelected
                                ? AppColors.accent
                                : Colors.white70,
                            size: 18,
                          )
                        : Text(
                            '${opt.seconds}s',
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.accent
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
                title: Text(
                  opt.label,
                  style: TextStyle(
                    color: isSelected ? AppColors.accent : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.accent,
                        size: 20,
                      )
                    : null,
                onTap: () {
                  onTimerSelected(opt.seconds);
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
