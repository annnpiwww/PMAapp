import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/services/whats_new_service.dart';
import '../../maintenance/widgets/ai_logo_mark.dart';

/// Lembar "Apa yang baru" yang muncul sekali setelah aplikasi ditimpa versi baru.
Future<void> showWhatsNewSheet(
  BuildContext context,
  WhatsNewRelease release,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => WhatsNewSheet(release: release),
  );
}

/// Pemasang layar pertama: menampilkan lembar sekali setelah layar tujuan siap.
class WhatsNewGate extends StatefulWidget {
  final WhatsNewRelease? release;
  final Widget child;

  const WhatsNewGate({super.key, required this.release, required this.child});

  @override
  State<WhatsNewGate> createState() => _WhatsNewGateState();
}

class _WhatsNewGateState extends State<WhatsNewGate> {
  @override
  void initState() {
    super.initState();
    final release = widget.release;
    if (release == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showWhatsNewSheet(context, release);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class WhatsNewSheet extends StatelessWidget {
  final WhatsNewRelease release;

  const WhatsNewSheet({super.key, required this.release});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? AppColors.darkSurface : AppColors.surface;
    final textPrimary =
        dark ? AppColors.textDarkPrimary : AppColors.textPrimary;
    final textMuted = dark ? AppColors.textDarkMuted : AppColors.textMuted;
    final border = dark ? AppColors.darkBorder : AppColors.cardBorder;
    final divider = dark ? AppColors.darkBorder : const Color(0xFFEDE7D9);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppColors.radiusBottomSheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AiLogoMark(size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Apa yang baru',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          height: 1.15,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Versi ${release.version} · ${release.date}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Container(height: 1, color: divider, margin: const EdgeInsets.symmetric(vertical: 14)),

            _SectionLabel('Fitur baru', textMuted),
            for (final feature in release.features)
              _Bullet(feature, textPrimary, textMuted),

            if (release.aiNote != null) ...[
              const SizedBox(height: 12),
              _SectionLabel('Analisa AI di preview', textMuted),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                decoration: _noteBoxDecoration(dark),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const AiLogoMark(size: 25),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        release.aiNote!,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                          color: dark ? AppColors.textDarkSecondary : const Color(0xFF2B4C8F),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (release.mapNote != null) ...[
              const SizedBox(height: 12),
              _SectionLabel('Map Maintenance baru', textMuted),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                decoration: _noteBoxDecoration(dark),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 25,
                      color: dark ? AppColors.primaryLight : AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        release.mapNote!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                          color: dark ? AppColors.textDarkSecondary : const Color(0xFF2B4C8F),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            _SectionLabel('Perbaikan', textMuted),
            const SizedBox(height: 7),
            Text(
              release.bugfix,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: textPrimary,
              ),
            ),

            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 12, color: textMuted),
                const SizedBox(width: 6),
                Text(
                  'Muncul sekali tiap ada versi baru',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: const Text(
                  'Mengerti',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _noteBoxDecoration(bool dark) {
    return BoxDecoration(
      color: dark ? AppColors.darkSurfaceContainer : const Color(0xFFF2F6FF),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(
        color: dark ? AppColors.darkBorderMuted : const Color(0xFFDCE6FA),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _SectionLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  final Color textColor;
  final Color dotColor;

  const _Bullet(this.text, this.textColor, this.dotColor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 7),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
