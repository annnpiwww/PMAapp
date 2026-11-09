import 'package:flutter/material.dart';

import '../../../core/constants/tiket_colors.dart';
import '../../../core/widgets/tiket/tiket.dart';
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
    final colors = TiketColors.of(context);
    final type = TiketType.of(context);
    final horizontalPad = TiketSpace.padOf(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.canvas,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Ticket Band with Perforation
          Stack(
            children: [
              Container(
                color: colors.band,
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(horizontalPad, 10, horizontalPad, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.white.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Apa yang baru',
                      style: type.screenTitle(color: colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Versi ${release.version} · ${release.date}',
                      style: type.caption(color: colors.bandCaption),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: CustomPaint(
                  size: const Size(double.infinity, 10),
                  painter: PerforationPainter(canvasColor: colors.canvas),
                ),
              ),
            ],
          ),

          // 2. Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPad,
                16,
                horizontalPad,
                16 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel('Fitur baru', colors.ink),
                  const SizedBox(height: 4),
                  for (final feature in release.features)
                    _Bullet(feature, colors.ink, colors.primary),

                  if (release.aiNote != null) ...[
                    const SizedBox(height: 16),
                    _SectionLabel('Analisa AI di preview', colors.ink),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: colors.soft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.hairline, width: 1.0),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const AiLogoMark(size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              release.aiNote!,
                              style: TextStyle(
                                fontFamily: TiketType.fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.45,
                                color: colors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (release.mapNote != null) ...[
                    const SizedBox(height: 16),
                    _SectionLabel('Map Maintenance baru', colors.ink),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: colors.soft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.hairline, width: 1.0),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map_outlined,
                            size: 24,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              release.mapNote!,
                              style: TextStyle(
                                fontFamily: TiketType.fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.45,
                                color: colors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  _SectionLabel('Perbaikan', colors.ink),
                  const SizedBox(height: 6),
                  Text(
                    release.bugfix,
                    style: TextStyle(
                      fontFamily: TiketType.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      color: colors.ink,
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 14, color: colors.mute),
                      const SizedBox(width: 6),
                      Text(
                        'Muncul sekali tiap ada versi baru',
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colors.mute,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TiketPill(
                    label: 'Mengerti',
                    kind: TiketPillKind.primary,
                    height: 52,
                    expand: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    return Text(
      text,
      style: TiketType.sectionStyle(color: color),
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
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.45,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
