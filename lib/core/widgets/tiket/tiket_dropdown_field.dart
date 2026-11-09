import 'package:flutter/material.dart';
import '../../constants/tiket_colors.dart';

class TiketDropdownField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const TiketDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);

    return Semantics(
      button: true,
      label: '$label: $value',
      child: Material(
        color: colors.soft,
        child: InkWell(
          splashColor: colors.primaryPressed.withValues(alpha: 0.12),
          highlightColor: colors.primaryPressed.withValues(alpha: 0.06),
          onTap: onTap,
          child: Container(
            height: 52.0,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colors.body,
                  width: 2.0,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 11.0,
                          fontWeight: FontWeight.w500,
                          color: colors.body,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        value,
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 14.0,
                          fontWeight: FontWeight.w600,
                          color: colors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 20.0,
                  color: colors.body,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
