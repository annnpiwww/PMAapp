import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/core/constants/tiket_colors.dart';
import 'package:bssparking_timemark/data/models/user_model.dart';
import 'package:bssparking_timemark/data/repositories/auth_repository.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/auth/screens/login_screen.dart';
import 'package:bssparking_timemark/features/camera/widgets/camera_drawer.dart';

Future<void> _loadFonts() async {
  final fontLoader = FontLoader(AppTheme.fontFamily);
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
  });
}

Future<void> _pumpAndWarmImages(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final widget = element.widget as Image;
      await precacheImage(widget.image, element);
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
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

  group('Login & Drawer Logo Tests', () {
    const loginAsset = AssetImage('foto/splash_logo.png');
    const drawerAsset = AssetImage('foto/bssfotologo_transparent.png');

    for (final brightness in [Brightness.light, Brightness.dark]) {
      final isDark = brightness == Brightness.dark;
      final modeName = isDark ? 'dark' : 'light';
      final theme = isDark ? AppTheme.darkTheme : AppTheme.lightTheme;

      testWidgets('LoginScreen $modeName renders splash_logo image', (tester) async {
        final key = GlobalKey();
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme,
              home: const MediaQuery(
                data: MediaQueryData(
                  size: Size(360, 800),
                  padding: EdgeInsets.only(top: 24.0, bottom: 24.0),
                ),
                child: LoginScreen(),
              ),
            ),
          ),
        );

        await _pumpAndWarmImages(tester);

        expect(find.image(loginAsset), findsOneWidget);
        expect(tester.takeException(), isNull);

        if (!isDark) {
          const outPath = 'docs/screenshots/balance-sweep/fix-c/login-light-360.png';
          await _saveBoundaryAsPng(tester, key, outPath);
          expect(File(outPath).existsSync(), isTrue);
        }
      });

      testWidgets('CameraDrawer $modeName renders bssfotologo image', (tester) async {
        final key = GlobalKey();
        final scaffoldKey = GlobalKey<ScaffoldState>();
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final colors = isDark ? TiketColors.dark : TiketColors.light;

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
                body: const Center(child: Text('Content')),
              ),
            ),
          ),
        );

        scaffoldKey.currentState?.openDrawer();
        await _pumpAndWarmImages(tester);

        expect(find.image(drawerAsset), findsOneWidget);
        expect(tester.takeException(), isNull);

        if (!isDark) {
          const outPath = 'docs/screenshots/balance-sweep/fix-c/drawer-light-360.png';
          await _saveBoundaryAsPng(tester, key, outPath);
          expect(File(outPath).existsSync(), isTrue);
        }
      });
    }
  });
}
