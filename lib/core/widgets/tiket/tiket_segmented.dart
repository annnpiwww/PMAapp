import 'package:flutter/material.dart';
import '../../constants/tiket_colors.dart';

class TiketSegmented<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  const TiketSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  }) : assert(options.length <= 3, 'TiketSegmented supports at most 3 options');

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48.0),
      child: Center(
        child: Container(
          height: 44.0,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22.0),
            border: Border.all(
              color: colors.mute,
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.5),
            child: Row(
              children: [
                for (int i = 0; i < options.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 1.5,
                      height: 44.0,
                      color: colors.mute,
                    ),
                  Expanded(
                    child: _buildSegment(
                      context,
                      option: options[i],
                      colors: colors,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegment(
    BuildContext context, {
    required (T, String) option,
    required TiketColors colors,
  }) {
    final isSelected = option.$1 == selected;
    final label = option.$2;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Material(
        color: isSelected ? colors.primary : Colors.transparent,
        child: InkWell(
          splashColor: colors.primaryPressed,
          highlightColor: colors.primaryPressed.withValues(alpha: 0.3),
          onTap: () => onChanged(option.$1),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: TiketType.fontFamily,
                  fontSize: 14.0,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? colors.onPrimary : colors.ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
