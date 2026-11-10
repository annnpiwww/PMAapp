import 'package:flutter/material.dart';

class TiketColors extends ThemeExtension<TiketColors> {
  final Color canvas;
  final Color ink;
  final Color body;
  final Color mute;
  final Color soft;
  final Color hairline;
  final Color bar;
  final Color dialog;
  final Color band;
  final Color bandRaise;
  final Color bandLine;
  final Color bandCaption;
  final Color bandTrack;
  final Color primary;
  final Color onPrimary;
  final Color primaryPressed;
  final Color signal;
  final Color signalText;
  final Color ok;
  final Color okText;
  final Color danger;
  final Color dangerTint;

  const TiketColors({
    required this.canvas,
    required this.ink,
    required this.body,
    required this.mute,
    required this.soft,
    required this.hairline,
    required this.bar,
    required this.dialog,
    required this.band,
    required this.bandRaise,
    required this.bandLine,
    required this.bandCaption,
    required this.bandTrack,
    required this.primary,
    required this.onPrimary,
    required this.primaryPressed,
    required this.signal,
    required this.signalText,
    required this.ok,
    required this.okText,
    required this.danger,
    required this.dangerTint,
  });

  static const TiketColors light = TiketColors(
    canvas: Color(0xFFFFFFFF),
    ink: Color(0xFF000000),
    body: Color(0xFF5E5E5E),
    mute: Color(0xFF8A8A8A),
    soft: Color(0xFFEFEFEF),
    hairline: Color(0xFFE2E2E2),
    bar: Color(0xFFFFFFFF),
    dialog: Color(0xFFFFFFFF),
    band: Color(0xFF1A428A),
    bandRaise: Color(0xFF2A549C),
    bandLine: Color(0xFF8EA3D3),
    bandCaption: Color(0xFFD3DDF2),
    bandTrack: Color(0xFF40649F),
    primary: Color(0xFF1A428A),
    onPrimary: Color(0xFFFFFFFF),
    primaryPressed: Color(0xFF143672),
    signal: Color(0xFFFF6500),
    signalText: Color(0xFFB34700),
    ok: Color(0xFF0E8345),
    okText: Color(0xFF0E8345),
    danger: Color(0xFFC81E1E),
    dangerTint: Color(0xFFFBE9E9),
  );

  static const TiketColors dark = TiketColors(
    canvas: Color(0xFF141414),
    ink: Color(0xFFFFFFFF),
    body: Color(0xFFB3B3B3),
    mute: Color(0xFF8A8A8A),
    soft: Color(0xFF262626),
    hairline: Color(0xFF2E2E2E),
    bar: Color(0xFF1C1C1C),
    dialog: Color(0xFF1F1F1F),
    band: Color(0xFF000000),
    bandRaise: Color(0xFF1F1F1F),
    bandLine: Color(0xFF6A6A6A),
    bandCaption: Color(0xFFB3B3B3),
    bandTrack: Color(0xFF3A3A3A),
    primary: Color(0xFFFFFFFF),
    onPrimary: Color(0xFF000000),
    primaryPressed: Color(0xFFE2E2E2),
    signal: Color(0xFFFF6500),
    signalText: Color(0xFFFF8A3D),
    ok: Color(0xFF0E8345),
    okText: Color(0xFF2FB36A),
    danger: Color(0xFFFF9B9B),
    dangerTint: Color(0xFF3A1616),
  );

  static TiketColors of(BuildContext context) {
    final ext = Theme.of(context).extension<TiketColors>();
    if (ext != null) return ext;
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  Color get white => const Color(0xFFFFFFFF);
  Color get black => const Color(0xFF000000);
  Color get onBand => const Color(0xFFFFFFFF);

  @override
  TiketColors copyWith({
    Color? canvas,
    Color? ink,
    Color? body,
    Color? mute,
    Color? soft,
    Color? hairline,
    Color? bar,
    Color? dialog,
    Color? band,
    Color? bandRaise,
    Color? bandLine,
    Color? bandCaption,
    Color? bandTrack,
    Color? primary,
    Color? onPrimary,
    Color? primaryPressed,
    Color? signal,
    Color? signalText,
    Color? ok,
    Color? okText,
    Color? danger,
    Color? dangerTint,
  }) {
    return TiketColors(
      canvas: canvas ?? this.canvas,
      ink: ink ?? this.ink,
      body: body ?? this.body,
      mute: mute ?? this.mute,
      soft: soft ?? this.soft,
      hairline: hairline ?? this.hairline,
      bar: bar ?? this.bar,
      dialog: dialog ?? this.dialog,
      band: band ?? this.band,
      bandRaise: bandRaise ?? this.bandRaise,
      bandLine: bandLine ?? this.bandLine,
      bandCaption: bandCaption ?? this.bandCaption,
      bandTrack: bandTrack ?? this.bandTrack,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryPressed: primaryPressed ?? this.primaryPressed,
      signal: signal ?? this.signal,
      signalText: signalText ?? this.signalText,
      ok: ok ?? this.ok,
      okText: okText ?? this.okText,
      danger: danger ?? this.danger,
      dangerTint: dangerTint ?? this.dangerTint,
    );
  }

  @override
  TiketColors lerp(ThemeExtension<TiketColors>? other, double t) {
    if (other is! TiketColors) return this;
    return TiketColors(
      canvas: Color.lerp(canvas, other.canvas, t) ?? canvas,
      ink: Color.lerp(ink, other.ink, t) ?? ink,
      body: Color.lerp(body, other.body, t) ?? body,
      mute: Color.lerp(mute, other.mute, t) ?? mute,
      soft: Color.lerp(soft, other.soft, t) ?? soft,
      hairline: Color.lerp(hairline, other.hairline, t) ?? hairline,
      bar: Color.lerp(bar, other.bar, t) ?? bar,
      dialog: Color.lerp(dialog, other.dialog, t) ?? dialog,
      band: Color.lerp(band, other.band, t) ?? band,
      bandRaise: Color.lerp(bandRaise, other.bandRaise, t) ?? bandRaise,
      bandLine: Color.lerp(bandLine, other.bandLine, t) ?? bandLine,
      bandCaption: Color.lerp(bandCaption, other.bandCaption, t) ?? bandCaption,
      bandTrack: Color.lerp(bandTrack, other.bandTrack, t) ?? bandTrack,
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t) ?? onPrimary,
      primaryPressed: Color.lerp(primaryPressed, other.primaryPressed, t) ?? primaryPressed,
      signal: Color.lerp(signal, other.signal, t) ?? signal,
      signalText: Color.lerp(signalText, other.signalText, t) ?? signalText,
      ok: Color.lerp(ok, other.ok, t) ?? ok,
      okText: Color.lerp(okText, other.okText, t) ?? okText,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      dangerTint: Color.lerp(dangerTint, other.dangerTint, t) ?? dangerTint,
    );
  }
}

class TiketType {
  final double width;
  static const String fontFamily = 'Figtree';

  const TiketType(this.width);

  static TiketType of(BuildContext context) {
    return TiketType(MediaQuery.of(context).size.width);
  }

  bool get isCompact => width < 375.0;

  static bool isWidthCompact(double width) => width < 375.0;

  TextStyle hero({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: isCompact ? 32.0 : 36.0,
    fontWeight: FontWeight.w800,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle heroStyle(double width, {Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: isWidthCompact(width) ? 32.0 : 36.0,
    fontWeight: FontWeight.w800,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  TextStyle heroLabel({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: isCompact ? 15.0 : 16.0,
    fontWeight: FontWeight.w700,
    color: color,
  );

  static TextStyle heroLabelStyle(double width, {Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: isWidthCompact(width) ? 15.0 : 16.0,
    fontWeight: FontWeight.w700,
    color: color,
  );

  TextStyle screenTitle({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: isCompact ? 20.0 : 22.0,
    fontWeight: FontWeight.w800,
    color: color,
  );

  static TextStyle screenTitleStyle(double width, {Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: isWidthCompact(width) ? 20.0 : 22.0,
    fontWeight: FontWeight.w800,
    color: color,
  );

  TextStyle section({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 16.0,
    fontWeight: FontWeight.w700,
    color: color,
  );

  static TextStyle sectionStyle({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 16.0,
    fontWeight: FontWeight.w700,
    color: color,
  );

  TextStyle rowTitle({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 15.0,
    height: 20.0 / 15.0,
    fontWeight: FontWeight.w600,
    color: color,
  );

  static TextStyle rowTitleStyle({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 15.0,
    height: 20.0 / 15.0,
    fontWeight: FontWeight.w600,
    color: color,
  );

  TextStyle meta({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 13.0,
    height: 18.0 / 13.0,
    fontWeight: FontWeight.w500,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle metaStyle({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 13.0,
    height: 18.0 / 13.0,
    fontWeight: FontWeight.w500,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  TextStyle status({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 13.0,
    fontWeight: FontWeight.w700,
    color: color,
  );

  static TextStyle statusStyle({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 13.0,
    fontWeight: FontWeight.w700,
    color: color,
  );

  TextStyle button({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.0,
    fontWeight: FontWeight.w600,
    color: color,
  );

  static TextStyle buttonStyle({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.0,
    fontWeight: FontWeight.w600,
    color: color,
  );

  TextStyle cta({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 16.0,
    fontWeight: FontWeight.w700,
    color: color,
  );

  static TextStyle ctaStyle({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 16.0,
    fontWeight: FontWeight.w700,
    color: color,
  );

  TextStyle caption({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.0,
    fontWeight: FontWeight.w500,
    color: color,
  );

  static TextStyle captionStyle({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.0,
    fontWeight: FontWeight.w500,
    color: color,
  );
}

class TiketSpace {
  static double pad(double width) => width < 375.0 ? 16.0 : 20.0;
  static double padOf(BuildContext context) => pad(MediaQuery.of(context).size.width);
}
