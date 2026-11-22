import 'package:flutter/material.dart';

import '../../../core/constants/tiket_colors.dart';
import '../../../core/widgets/tiket/tiket_band.dart';
import '../../../data/services/app_update_service.dart';

const Curve kUpdaterEaseOut = Cubic(0.23, 1.0, 0.32, 1.0);

Duration updaterMotionDuration(BuildContext context, Duration normal) {
  return MediaQuery.disableAnimationsOf(context) ? Duration.zero : normal;
}

Color updaterSurfaceTint(BuildContext context, TiketColors colors) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark
      ? colors.dialog
      : Color.alphaBlend(colors.band.withValues(alpha: 0.04), colors.canvas);
}

class UpdaterBandContainer extends StatelessWidget {
  final Widget child;
  final bool showHandle;
  final EdgeInsetsGeometry? padding;

  const UpdaterBandContainer({
    super.key,
    required this.child,
    this.showHandle = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final horizontalPad = TiketSpace.padOf(context);

    return Stack(
      children: [
        Container(
          width: double.infinity,
          color: colors.band,
          padding:
              padding ??
              EdgeInsets.fromLTRB(
                horizontalPad,
                showHandle ? 10.0 : 16.0,
                horizontalPad,
                20.0,
              ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHandle) ...[
                Center(
                  child: ExcludeSemantics(
                    child: Container(
                      width: 38.0,
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: colors.bandLine,
                        borderRadius: BorderRadius.circular(999.0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14.0),
              ],
              child,
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 10.0,
          child: ExcludeSemantics(
            child: CustomPaint(
              painter: PerforationPainter(canvasColor: colors.canvas),
            ),
          ),
        ),
      ],
    );
  }
}

class UpdaterVersionFlow extends StatelessWidget {
  final String currentVersion;
  final String newVersion;
  final double newFontSize;

  const UpdaterVersionFlow({
    super.key,
    required this.currentVersion,
    required this.newVersion,
    this.newFontSize = 19.0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    return Semantics(
      label: 'Dari versi $currentVersion ke versi $newVersion',
      excludeSemantics: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 7.0,
        runSpacing: 4.0,
        children: [
          Text(
            'v$currentVersion',
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
              color: colors.bandCaption,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, size: 16.0, color: colors.onBand),
          Text(
            'v$newVersion',
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: newFontSize,
              fontWeight: FontWeight.w800,
              color: colors.onBand,
              letterSpacing: -0.2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class UpdaterVersionTicket extends StatelessWidget {
  final String currentVersion;
  final String newVersion;
  final Widget trailing;
  final double newFontSize;

  const UpdaterVersionTicket({
    super.key,
    required this.currentVersion,
    required this.newVersion,
    required this.trailing,
    this.newFontSize = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: colors.bandRaise,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: colors.bandLine, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: UpdaterVersionFlow(
              currentVersion: currentVersion,
              newVersion: newVersion,
              newFontSize: newFontSize,
            ),
          ),
          const SizedBox(width: 10.0),
          trailing,
        ],
      ),
    );
  }
}

class UpdaterTicketPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;

  const UpdaterTicketPill({
    super.key,
    required this.label,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final bg = backgroundColor ?? colors.onBand.withValues(alpha: 0.14);
    final fg = foregroundColor ?? colors.onBand;
    final border = borderColor ?? colors.bandLine;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999.0),
        border: Border.all(color: border, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12.0, color: fg),
            const SizedBox(width: 5.0),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 12.0,
              fontWeight: FontWeight.w700,
              color: fg,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class UpdaterProgressTicket extends StatelessWidget {
  final String currentVersion;
  final String newVersion;
  final int percent;
  final double fraction;
  final String leftMeta;
  final String rightMeta;
  final bool isInterrupted;

  const UpdaterProgressTicket({
    super.key,
    required this.currentVersion,
    required this.newVersion,
    required this.percent,
    required this.fraction,
    required this.leftMeta,
    required this.rightMeta,
    this.isInterrupted = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final compact = TiketType.of(context).isCompact;
    final clamped = fraction.clamp(0.0, 1.0);
    final dur = updaterMotionDuration(
      context,
      const Duration(milliseconds: 220),
    );

    return Semantics(
      label: 'Progres pembaruan $percent persen, $leftMeta, $rightMeta',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: colors.bandRaise,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: colors.bandLine, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: UpdaterVersionFlow(
                    currentVersion: currentVersion,
                    newVersion: newVersion,
                    newFontSize: 18.0,
                  ),
                ),
                const SizedBox(width: 8.0),
                Text(
                  '$percent%',
                  style: TextStyle(
                    fontFamily: TiketType.fontFamily,
                    fontSize: isInterrupted ? 20.0 : (compact ? 28.0 : 32.0),
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    color: colors.onBand,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            ClipRRect(
              borderRadius: BorderRadius.circular(999.0),
              child: Container(
                height: isInterrupted ? 7.0 : 8.0,
                width: double.infinity,
                color: colors.bandTrack,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: clamped),
                  duration: dur,
                  curve: kUpdaterEaseOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scaleX: value,
                      alignment: Alignment.centerLeft,
                      child: child,
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: isInterrupted ? colors.signal : colors.onBand,
                      borderRadius: BorderRadius.circular(999.0),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    leftMeta,
                    style: TextStyle(
                      fontFamily: TiketType.fontFamily,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: colors.bandCaption,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                Text(
                  rightMeta,
                  style: TextStyle(
                    fontFamily: TiketType.fontFamily,
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                    color: colors.bandCaption,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class UpdaterStatsRow extends StatelessWidget {
  final DownloadProgress? progress;

  const UpdaterStatsRow({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final speedText = progress != null && progress!.bytesPerSec > 0
        ? AppUpdateService.formatSpeed(progress!.bytesPerSec)
        : '0,0 MB/dtk';
    final etaText = AppUpdateService.formatEta(progress?.eta);

    return Row(
      children: [
        Expanded(
          child: _StatCell(label: 'Kecepatan unduh', value: speedText),
        ),
        const SizedBox(width: 10.0),
        Expanded(
          child: _StatCell(label: 'Estimasi sisa', value: etaText),
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;

  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: updaterSurfaceTint(context, colors),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
              color: colors.body,
            ),
          ),
          const SizedBox(height: 2.0),
          Text(
            value,
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 15.0,
              fontWeight: FontWeight.w700,
              color: colors.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

enum UpdaterStepStatus { waiting, active, done }

class UpdaterStepItem extends StatelessWidget {
  final int number;
  final String title;
  final String subtitle;
  final UpdaterStepStatus status;
  final bool showDivider;

  const UpdaterStepItem({
    super.key,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.status,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);

    Widget marker;
    switch (status) {
      case UpdaterStepStatus.done:
        marker = Container(
          width: 22.0,
          height: 22.0,
          decoration: BoxDecoration(color: colors.ok, shape: BoxShape.circle),
          child: Icon(Icons.check_rounded, size: 14.0, color: colors.white),
        );
      case UpdaterStepStatus.active:
        marker = Container(
          width: 22.0,
          height: 22.0,
          decoration: BoxDecoration(
            color: colors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: 12.0,
                fontWeight: FontWeight.w800,
                color: colors.onPrimary,
              ),
            ),
          ),
        );
      case UpdaterStepStatus.waiting:
        marker = Container(
          width: 22.0,
          height: 22.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.mute, width: 2.0),
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: 12.0,
                fontWeight: FontWeight.w800,
                color: colors.body,
              ),
            ),
          ),
        );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1.0),
                child: ExcludeSemantics(child: marker),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TiketType.rowTitleStyle(color: colors.ink),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      subtitle,
                      style: TiketType.metaStyle(color: colors.body),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1.0, color: colors.hairline),
      ],
    );
  }
}

enum UpdaterBandBadgeKind { signal, danger, ok, shield }

class UpdaterBandBadge extends StatelessWidget {
  final UpdaterBandBadgeKind kind;

  const UpdaterBandBadge({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);

    switch (kind) {
      case UpdaterBandBadgeKind.signal:
        return Container(
          width: 28.0,
          height: 28.0,
          margin: const EdgeInsets.only(top: 2.0),
          decoration: BoxDecoration(
            color: colors.signal,
            shape: BoxShape.circle,
            border: Border.all(color: colors.white, width: 2.0),
          ),
          child: Center(
            child: Text(
              '!',
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: 15.0,
                fontWeight: FontWeight.w800,
                color: colors.black,
                height: 1.0,
              ),
            ),
          ),
        );
      case UpdaterBandBadgeKind.danger:
        return Container(
          width: 28.0,
          height: 28.0,
          margin: const EdgeInsets.only(top: 2.0),
          decoration: BoxDecoration(
            color: colors.dangerTint,
            shape: BoxShape.circle,
            border: Border.all(color: colors.danger, width: 2.0),
          ),
          child: Center(
            child: Icon(Icons.close_rounded, size: 16.0, color: colors.danger),
          ),
        );
      case UpdaterBandBadgeKind.ok:
        final dur = updaterMotionDuration(
          context,
          const Duration(milliseconds: 220),
        );
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.94, end: 1.0),
          duration: dur,
          curve: kUpdaterEaseOut,
          builder: (context, scale, child) {
            final t = ((scale - 0.94) / 0.06).clamp(0.0, 1.0);
            return Opacity(
              opacity: 0.85 + 0.15 * t,
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child: Container(
            width: 34.0,
            height: 34.0,
            margin: const EdgeInsets.only(top: 2.0),
            decoration: BoxDecoration(
              color: colors.ok,
              shape: BoxShape.circle,
              border: Border.all(color: colors.white, width: 2.0),
            ),
            child: Icon(Icons.check_rounded, size: 18.0, color: colors.white),
          ),
        );
      case UpdaterBandBadgeKind.shield:
        return Container(
          width: 34.0,
          height: 34.0,
          margin: const EdgeInsets.only(top: 2.0),
          decoration: BoxDecoration(
            color: colors.bandRaise,
            shape: BoxShape.circle,
            border: Border.all(color: colors.bandLine, width: 1.5),
          ),
          child: Icon(
            Icons.verified_user_outlined,
            size: 18.0,
            color: colors.onBand,
          ),
        );
    }
  }
}

class UpdaterPermissionIllustration extends StatelessWidget {
  const UpdaterPermissionIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor = isDark ? colors.okText : colors.primary;

    return Semantics(
      image: true,
      label:
          'Ilustrasi pengaturan Android: aktifkan tombol Izinkan dari sumber ini untuk PMApp',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: updaterSurfaceTint(context, colors),
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(color: colors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings_outlined, size: 16.0, color: colors.body),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    'Pengaturan Android · Pasang aplikasi tidak dikenal',
                    style: TextStyle(
                      fontFamily: TiketType.fontFamily,
                      fontSize: 12.0,
                      fontWeight: FontWeight.w700,
                      color: colors.body,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10.0),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14.0,
                vertical: 12.0,
              ),
              decoration: BoxDecoration(
                color: colors.canvas,
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: colors.hairline),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Izinkan dari sumber ini',
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 14.0,
                            fontWeight: FontWeight.w700,
                            color: colors.ink,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          'PMApp',
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 12.0,
                            color: colors.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Container(
                    width: 48.0,
                    height: 28.0,
                    padding: const EdgeInsets.all(3.0),
                    decoration: BoxDecoration(
                      color: trackColor,
                      borderRadius: BorderRadius.circular(999.0),
                    ),
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 22.0,
                      height: 22.0,
                      decoration: BoxDecoration(
                        color: colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UpdaterActionButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isDanger;
  final IconData? icon;

  const UpdaterActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
    this.isDanger = false,
    this.icon,
  });

  @override
  State<UpdaterActionButton> createState() => _UpdaterActionButtonState();
}

class _UpdaterActionButtonState extends State<UpdaterActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final enabled = widget.onPressed != null;
    final dur = updaterMotionDuration(
      context,
      const Duration(milliseconds: 100),
    );

    final Color bg;
    final Color fg;
    final BorderSide? side;

    if (!enabled) {
      bg = colors.soft;
      fg = colors.body;
      side = null;
    } else if (widget.isDanger) {
      bg = colors.dangerTint;
      fg = colors.danger;
      side = BorderSide(color: colors.danger, width: 1.5);
    } else if (widget.isPrimary) {
      bg = _pressed ? colors.primaryPressed : colors.primary;
      fg = colors.onPrimary;
      side = null;
    } else {
      bg = Colors.transparent;
      fg = colors.primary;
      side = BorderSide(color: colors.primary, width: 1.5);
    }

    final minHeight = widget.isPrimary ? 52.0 : 48.0;

    return AnimatedScale(
      scale: (_pressed && enabled && !MediaQuery.disableAnimationsOf(context))
          ? 0.97
          : 1.0,
      duration: dur,
      curve: kUpdaterEaseOut,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight, minWidth: 48.0),
        child: Material(
          color: bg,
          shape: side != null
              ? StadiumBorder(side: side)
              : const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: widget.onPressed,
            onHighlightChanged: (v) {
              if (_pressed != v) setState(() => _pressed = v);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 18.0,
                vertical: 12.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 18.0, color: fg),
                    const SizedBox(width: 8.0),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: TiketType.fontFamily,
                        fontSize: widget.isPrimary ? 16.0 : 14.0,
                        fontWeight: widget.isPrimary
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: fg,
                      ),
                    ),
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
