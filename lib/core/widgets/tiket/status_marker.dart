import 'package:flutter/material.dart';
import '../../constants/tiket_colors.dart';

enum TiketStatus {
  ok,
  attention,
  notStarted,
  danger,
}

class StatusMarker extends StatelessWidget {
  final TiketStatus status;
  final double size;
  final bool onBand;

  const StatusMarker({
    super.key,
    required this.status,
    this.size = 16.0,
    this.onBand = false,
  });

  String get _semanticsLabel {
    switch (status) {
      case TiketStatus.ok:
        return 'Selesai';
      case TiketStatus.attention:
        return 'Perlu perhatian';
      case TiketStatus.notStarted:
        return 'Belum';
      case TiketStatus.danger:
        return 'Harus diganti';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);

    Widget marker;
    switch (status) {
      case TiketStatus.ok:
        marker = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.ok,
            border: onBand
                ? Border.all(
                    color: colors.white,
                    width: 1.5,
                  )
                : null,
          ),
          child: Center(
            child: Icon(
              Icons.check,
              size: size * 0.75,
              color: colors.white,
            ),
          ),
        );
        break;

      case TiketStatus.attention:
        marker = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.signal,
            border: Border.all(
              color: colors.ink,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              '!',
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: size * 0.75,
                fontWeight: FontWeight.w900,
                color: colors.ink,
                height: 1.0,
              ),
            ),
          ),
        );
        break;

      case TiketStatus.notStarted:
        marker = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
            border: Border.all(
              color: onBand ? colors.bandCaption : colors.mute,
              width: 2.0,
            ),
          ),
        );
        break;

      case TiketStatus.danger:
        marker = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.danger,
          ),
          child: Center(
            child: Text(
              '!',
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: size * 0.75,
                fontWeight: FontWeight.w900,
                color: colors.white,
                height: 1.0,
              ),
            ),
          ),
        );
        break;
    }

    return Semantics(
      label: _semanticsLabel,
      excludeSemantics: true,
      child: marker,
    );
  }
}
