import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/features/splash/widgets/splash_concepts.dart';

import 'visual_harness.dart';

/// Mounts the splash concept inside [onPumped], advances to [targetMs],
/// then mutes [TickerMode] so [captureScreen]'s trailing 300ms pump
/// freezes the exact animation frame at [targetMs].
class _FrameStepper extends StatefulWidget {
  const _FrameStepper({
    required this.targetMs,
    required this.builder,
    required this.controller,
  });

  final int targetMs;
  final WidgetBuilder builder;
  final _FrameStepperController controller;

  @override
  State<_FrameStepper> createState() => _FrameStepperState();
}

class _FrameStepperController {
  _FrameStepperState? _state;

  Future<void> captureAtTarget(WidgetTester t) async {
    await _state!._runToTarget(t);
  }
}

class _FrameStepperState extends State<_FrameStepper> {
  bool _mounted = false;
  bool _tickerEnabled = true;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
  }

  Future<void> _runToTarget(WidgetTester t) async {
    await t.runAsync(() async {
      await precacheImage(const AssetImage('foto/splash_logo.png'), context);
    });

    setState(() {
      _mounted = true;
      _tickerEnabled = true;
    });
    await t.pump();

    final ms = widget.targetMs;
    if (ms > 0 && ms < 1200) {
      await t.pump(Duration(milliseconds: ms));
    } else if (ms == 1200) {
      await t.pump(const Duration(milliseconds: 1199));
    } else if (ms > 1200) {
      await t.pump(const Duration(milliseconds: 1200));
      await t.pump(const Duration(milliseconds: 16));
      await t.pump(const Duration(milliseconds: 16));
      await t.pump(Duration(milliseconds: ms - 1232));
    }

    setState(() {
      _tickerEnabled = false;
    });
    await t.pump();
  }

  @override
  Widget build(BuildContext context) {
    if (!_mounted) {
      return const SizedBox.shrink();
    }
    return TickerMode(
      enabled: _tickerEnabled,
      child: Builder(builder: widget.builder),
    );
  }
}

Future<void> _captureConceptFrame(
  WidgetTester t, {
  required String conceptKey,
  required WidgetBuilder builder,
  required int targetMs,
  Size size = const Size(390, 844),
  double textScale = 1.0,
  String? customFileName,
}) async {
  final stepperController = _FrameStepperController();
  final paddedMs = targetMs.toString().padLeft(4, '0');
  final fileName = customFileName ?? 'concept-$conceptKey-${paddedMs}ms.png';

  await captureScreen(
    t,
    name: 'concept-$conceptKey',
    folder: 'splash-concepts',
    size: size,
    mode: ThemeMode.light,
    textScale: textScale,
    customFileName: fileName,
    screen: _FrameStepper(
      targetMs: targetMs,
      controller: stepperController,
      builder: builder,
    ),
    onPumped: (tester) => stepperController.captureAtTarget(tester),
  );

  expect(t.takeException(), isNull);
}

void main() {
  const frameTimestamps = [0, 200, 450, 750, 1200, 2000];

  final concepts = <String, WidgetBuilder>{
    'a': (_) => const SplashConceptTickMark(),
    'b': (_) => const SplashConceptShutter(),
    'c': (_) => const SplashConceptAssembly(),
  };

  for (final entry in concepts.entries) {
    final key = entry.key;
    final builder = entry.value;

    for (final ms in frameTimestamps) {
      testWidgets('concept-$key frame ${ms}ms', (t) async {
        await _captureConceptFrame(
          t,
          conceptKey: key,
          builder: builder,
          targetMs: ms,
        );
        final paddedMs = ms.toString().padLeft(4, '0');
        expect(
          File('docs/screenshots/splash-concepts/concept-$key-${paddedMs}ms.png')
              .existsSync(),
          isTrue,
        );
      });
    }

    testWidgets('concept-$key overflow check at 360x780 textScale 1.3',
        (t) async {
      await _captureConceptFrame(
        t,
        conceptKey: key,
        builder: builder,
        targetMs: 2000,
        size: const Size(360, 780),
        textScale: 1.3,
        customFileName: 'concept-$key-360-scale13-2000ms.png',
      );
      expect(
        File('docs/screenshots/splash-concepts/concept-$key-360-scale13-2000ms.png')
            .existsSync(),
        isTrue,
      );
    });
  }

  testWidgets('reduced motion skips intro and leaves no pending animations',
      (t) async {
    for (final builder in concepts.values) {
      await t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
            child: Builder(builder: builder),
          ),
        ),
      );
      await t.pump();

      final logoOpacityFinder = find.ancestor(
        of: find.byType(ClipOval),
        matching: find.byType(Opacity),
      );
      expect(logoOpacityFinder, findsOneWidget);
      final opacityWidget = t.widget<Opacity>(logoOpacityFinder);
      expect(opacityWidget.opacity, equals(1.0));

      final settledFrames = await t.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 1),
      );
      expect(settledFrames, equals(1));
      expect(t.takeException(), isNull);
    }
  });
}
