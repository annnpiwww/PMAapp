import 'package:flutter/material.dart';
import '../../constants/tiket_colors.dart';
import 'status_marker.dart';
import 'tiket_pill.dart';

class TiketOption<T> {
  final T value;
  final String label;
  final String? trailingText;
  final TiketStatus? status;

  const TiketOption({
    required this.value,
    required this.label,
    this.trailingText,
    this.status,
  });
}

Future<T?> showTiketPickerDialog<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required List<TiketOption<T>> options,
  T? selected,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final colors = TiketColors.of(ctx);

      return Dialog(
        backgroundColor: colors.dialog,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400.0),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: TiketType.fontFamily,
                    fontSize: 18.0,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4.0),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: TiketType.fontFamily,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w500,
                      color: colors.body,
                    ),
                  ),
                ],
                const SizedBox(height: 16.0),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final option in options)
                          _buildOptionRow<T>(
                            ctx,
                            option: option,
                            isSelected: option.value == selected,
                            colors: colors,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                TiketPill(
                  label: 'Tutup',
                  kind: TiketPillKind.secondary,
                  expand: true,
                  onPressed: () => Navigator.of(ctx).pop(null),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildOptionRow<T>(
  BuildContext context, {
  required TiketOption<T> option,
  required bool isSelected,
  required TiketColors colors,
}) {
  return Semantics(
    button: true,
    selected: isSelected,
    label: option.label,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        splashColor: colors.primaryPressed.withValues(alpha: 0.12),
        highlightColor: colors.primaryPressed.withValues(alpha: 0.06),
        onTap: () => Navigator.of(context).pop(option.value),
        child: Container(
          height: 52.0,
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            children: [
              Container(
                width: 20.0,
                height: 20.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? colors.primary : colors.mute,
                    width: 2.0,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 10.0,
                          height: 10.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.primary,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Text(
                  option.label,
                  style: TextStyle(
                    fontFamily: TiketType.fontFamily,
                    fontSize: 14.0,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: colors.ink,
                  ),
                ),
              ),
              if (option.trailingText != null) ...[
                const SizedBox(width: 8.0),
                Text(
                  option.trailingText!,
                  style: TextStyle(
                    fontFamily: TiketType.fontFamily,
                    fontSize: 13.0,
                    fontWeight: FontWeight.w500,
                    color: colors.body,
                  ),
                ),
              ],
              if (option.status != null) ...[
                const SizedBox(width: 8.0),
                StatusMarker(status: option.status!),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
