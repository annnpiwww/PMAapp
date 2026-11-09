import 'package:flutter/material.dart';
import '../../constants/tiket_colors.dart';
import 'tiket_band.dart';

class TiketSliverBand extends StatelessWidget {
  final Widget? leading;
  final List<Widget> actions;
  final String? caption;
  final Widget? hero;
  final Widget? footer;
  final String compactTitle;
  final double? expandedHeight;

  const TiketSliverBand({
    super.key,
    this.leading,
    this.actions = const [],
    this.caption,
    this.hero,
    this.footer,
    required this.compactTitle,
    this.expandedHeight,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final type = TiketType.of(context);

    final double effectiveExpandedHeight = expandedHeight ?? 180.0;

    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: colors.band,
      foregroundColor: colors.onBand,
      toolbarHeight: 56.0,
      expandedHeight: effectiveExpandedHeight,
      leading: leading,
      actions: actions.isNotEmpty
          ? [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8.0),
                      actions[i],
                    ],
                  ],
                ),
              ),
            ]
          : null,
      title: Text(
        compactTitle,
        style: type.section(color: colors.onBand),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            TiketBand(
              leading: null,
              actions: const [],
              caption: caption,
              hero: hero,
              footer: footer,
              padding: EdgeInsets.only(
                top: topInset + 56.0,
                left: TiketSpace.padOf(context),
                right: TiketSpace.padOf(context),
                bottom: 16.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
