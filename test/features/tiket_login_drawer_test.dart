import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/core/constants/tiket_colors.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/data/models/user_model.dart';
import 'package:bssparking_timemark/data/repositories/auth_repository.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/features/auth/screens/login_screen.dart';
import 'package:bssparking_timemark/features/camera/widgets/camera_drawer.dart';

Future<void> loadAppFonts() async {
  final fontLoader = FontLoader('Figtree');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final file = File('assets/fonts/Figtree-$weight.ttf');
    if (file.existsSync()) {
      final bytes = file.readAsBytesSync();
      fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
  }
  await fontLoader.load();

  final iconFile = File(
    '/home/annnpii/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (iconFile.existsSync()) {
    final iconLoader = FontLoader('MaterialIcons');
    final iconBytes = iconFile.readAsBytesSync();
    iconLoader.addFont(Future.value(ByteData.view(iconBytes.buffer)));
    await iconLoader.load();
  }
}

Future<void> _saveBoundaryAsPng(
  WidgetTester tester,
  GlobalKey key,
  String path,
) async {
  final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) throw Exception('RenderRepaintBoundary not found for $path');

  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Failed to get png byteData for $path');

    final file = File(path);
    file.parent.createSync(recursive: true);
    await file.writeAsBytes(byteData.buffer.asUint8List());
    // ignore: avoid_print
    print('Generated screenshot: $path (${file.lengthSync()} bytes)');
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
    await AuthRepository.instance.login(
      UserModel(
        id: 'usr_test_spv',
        nama: 'Indra Yohana',
        npp: '78291',
        email: 'indra@bss.id',
        role: UserRole.supervisor,
        posId: 'pos_1',
        posName: 'Gate 1',
        cabangName: 'KC Manado',
      ),
    );
  });

  group('LoginScreen Tests', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final modeName = brightness == Brightness.light ? 'Light' : 'Dark';
      final theme = brightness == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme;

      for (final dimensions in [(360.0, 800.0), (390.0, 844.0)]) {
        final w = dimensions.$1;
        final h = dimensions.$2;

        testWidgets('LoginScreen $modeName ${w.toInt()}x${h.toInt()} renders without overflow', (tester) async {
          tester.view.physicalSize = Size(w, h);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme,
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(w, h),
                  padding: const EdgeInsets.only(top: 24.0, bottom: 24.0),
                ),
                child: const LoginScreen(),
              ),
            ),
          );

          await tester.pumpAndSettle();

          expect(find.text('PMApp'), findsOneWidget);
          expect(find.text('PMA App'), findsNothing);
          expect(find.text('Login'), findsOneWidget);
          expect(find.text('PMAapp powered by annnpii'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('LoginScreen handles 360 width with textScaler 1.3 without overflow', (tester) async {
      tester.view.physicalSize = const Size(360.0, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(360.0, 800.0),
              textScaler: TextScaler.linear(1.3),
              padding: EdgeInsets.only(top: 24.0, bottom: 24.0),
            ),
            child: LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('PMApp'), findsOneWidget);
    });
  });

  group('CameraDrawer Tests', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final modeName = brightness == Brightness.light ? 'Light' : 'Dark';
      final theme = brightness == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme;

      testWidgets('CameraDrawer $modeName renders logo asset and no BSS PARKING text', (tester) async {
        final scaffoldKey = GlobalKey<ScaffoldState>();

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: Scaffold(
              key: scaffoldKey,
              drawer: const CameraDrawer(),
              body: const Center(child: Text('Body')),
            ),
          ),
        );

        scaffoldKey.currentState?.openDrawer();
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'foto/bssfotologo_transparent.png',
          ),
          findsOneWidget,
        );
        expect(find.text('BSS PARKING'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Generate 8 Showcase Screenshots', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final mode = brightness == Brightness.light ? 'light' : 'dark';
      final theme = brightness == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme;

      for (final dim in [(360.0, 800.0), (390.0, 844.0)]) {
        final w = dim.$1;
        final h = dim.$2;
        final sizeTag = '${w.toInt()}';

        testWidgets('Capture $mode-$sizeTag-login', (tester) async {
          final key = GlobalKey();
          tester.view.physicalSize = Size(w, h);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(w, h),
                    padding: const EdgeInsets.only(top: 24.0, bottom: 24.0),
                  ),
                  child: const LoginScreen(),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();

          final path = 'docs/screenshots/tiket-login-drawer/$mode-$sizeTag-login.png';
          await _saveBoundaryAsPng(tester, key, path);
          expect(File(path).existsSync(), isTrue);
        });

        testWidgets('Capture $mode-$sizeTag-drawer', (tester) async {
          final key = GlobalKey();
          final scaffoldKey = GlobalKey<ScaffoldState>();
          tester.view.physicalSize = Size(w, h);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final colors = brightness == Brightness.dark ? TiketColors.dark : TiketColors.light;

          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                home: Scaffold(
                  key: scaffoldKey,
                  backgroundColor: colors.band,
                  drawer: const CameraDrawer(),
                  body: const Center(
                    child: Text('Main Screen Content'),
                  ),
                ),
              ),
            ),
          );

          scaffoldKey.currentState?.openDrawer();
          await tester.pumpAndSettle();

          final path = 'docs/screenshots/tiket-login-drawer/$mode-$sizeTag-drawer.png';
          await _saveBoundaryAsPng(tester, key, path);
          expect(File(path).existsSync(), isTrue);
        });
      }
    }
  });
}
