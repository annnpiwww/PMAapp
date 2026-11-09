import 'package:flutter/material.dart';
import '../../constants/tiket_colors.dart';

class TiketRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final List<String> meta;
  final (String, Color)? status;
  final Widget? trailing;
  final Widget? below;
  final VoidCallback? onTap;

  const TiketRow({
    super.key,
    this.leading,
    required this.title,
    this.meta = const [],
    this.status,
    this.trailing,
    this.below,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final pad = TiketSpace.padOf(context);
    final type = TiketType.of(context);

    const leadingSpacing = 12.0;
    const leadingWidth = 24.0;

    Widget content = Padding(
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            SizedBox(
              width: leadingWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: leading!,
              ),
            ),
            const SizedBox(width: leadingSpacing),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: type.rowTitle(color: colors.ink),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2.0),
                  Text(
                    meta.join(' · '),
                    style: type.meta(color: colors.body),
                  ),
                ],
                if (status != null) ...[
                  const SizedBox(height: 4.0),
                  Text(
                    status!.$1,
                    style: type.status(color: status!.$2),
                  ),
                ],
                if (below != null) ...[
                  const SizedBox(height: 8.0),
                  below!,
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12.0),
            trailing!,
          ],
        ],
      ),
    );

    final dividerInset = pad + (leading != null ? (leadingWidth + leadingSpacing) : 0.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onTap != null)
          Semantics(
            button: true,
            label: title,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48.0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  splashColor: colors.primaryPressed.withValues(alpha: 0.12),
                  highlightColor: colors.primaryPressed.withValues(alpha: 0.06),
                  onTap: onTap,
                  child: content,
                ),
              ),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48.0),
            child: content,
          ),
        Padding(
          padding: EdgeInsets.only(left: dividerInset, right: pad),
          child: Divider(
            height: 1.0,
            thickness: 1.0,
            color: colors.hairline,
          ),
        ),
      ],
    );
  }
}
