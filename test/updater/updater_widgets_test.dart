import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/data/services/app_release_admin_service.dart';
import 'package:bssparking_timemark/data/services/app_update_service.dart';
import 'package:bssparking_timemark/features/updater/screens/app_releases_screen.dart';
import 'package:bssparking_timemark/features/updater/screens/mandatory_update_screen.dart';
import 'package:bssparking_timemark/features/updater/screens/upload_release_screen.dart';
import 'package:bssparking_timemark/features/updater/updater_controller.dart';
import 'package:bssparking_timemark/features/updater/widgets/updater_sheet.dart';

bool _fontsLoaded = false;

Future<void> _loadFonts() async {
  if (_fontsLoaded) return;
  final fontLoader = FontLoader(AppTheme.fontFamily);
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final file = File('assets/fonts/Figtree-$weight.ttf');
    if (file.existsSync()) {
      final bytes = file.readAsBytesSync();
      fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
  }
  await fontLoader.load();

  const iconPaths = [
    '/home/annnpii/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ];
  for (final p in iconPaths) {
    final file = File(p);
    if (file.existsSync()) {
      final iconLoader = FontLoader('MaterialIcons');
      final bytes = file.readAsBytesSync();
      iconLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await iconLoader.load();
      break;
    }
  }
  _fontsLoaded = true;
}

AppUpdateCheckResult _sampleResult({
  bool mandatory = false,
  String changelog =
      'Perbaikan alarm darurat agar tetap berbunyi di latar belakang saat sinyal lemah.\nSinkronisasi ulang otomatis saat jaringan kembali stabil.',
}) {
  return AppUpdateCheckResult(
    release: AppUpdateRelease(
      id: 'rel-sample',
      versionName: '2.0.142',
      versionCode: 4155,
      sizeBytes: 24900000,
      sha256: 'a' * 64,
      changelog: changelog,
    ),
    mandatory: mandatory,
    downloadUrl: 'https://example.supabase.co/signed.apk',
    currentVersion: '2.0.141',
    currentCode: 4154,
  );
}

Future<void> _captureWidget(
  WidgetTester tester, {
  required String fileName,
  required Widget child,
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  await _loadFonts();
  tester.view.physicalSize = Size(size.width * 2.0, size.height * 2.0);
  tester.view.devicePixelRatio = 2.0;

  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          devicePixelRatio: 2.0,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: RepaintBoundary(key: key, child: child),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final boundary =
      key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  expect(boundary, isNotNull);

  await tester.runAsync(() async {
    final image = await boundary!.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    expect(byteData, isNotNull);
    final dir = Directory('docs/screenshots/updater');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final out = File('docs/screenshots/updater/$fileName');
    await out.writeAsBytes(byteData!.buffer.asUint8List());
  });

  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'U1 optional sheet renders clean copy without SHA/ABI/APK/versionCode & captures 390 screenshot',
    (tester) async {
      final controller = UpdaterController(checkResult: _sampleResult());
      addTearDown(controller.dispose);

      await _captureWidget(
        tester,
        fileName: 'u1-light-390.png',
        child: Scaffold(
          backgroundColor: Colors.black54,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: UpdaterSheet(controller: controller),
          ),
        ),
      );

      expect(find.text('Pembaruan aplikasi tersedia'), findsOneWidget);
      expect(find.text('v2.0.141'), findsOneWidget);
      expect(find.text('v2.0.142'), findsOneWidget);
      expect(find.text('24,9 MB'), findsOneWidget);
      expect(find.text('Perbarui sekarang'), findsOneWidget);
      expect(find.text('Nanti'), findsOneWidget);

      for (final forbidden in ['SHA', 'ABI', 'APK', 'versionCode', '4155']) {
        expect(find.textContaining(forbidden), findsNothing);
      }
    },
  );

  testWidgets(
    'U2 downloading sheet shows percent + MB text & captures 390 screenshot',
    (tester) async {
      final controller = UpdaterController(
        checkResult: _sampleResult(),
        initialPhase: UpdaterPhase.downloading,
        initialProgress: const DownloadProgress(
          received: 12000000,
          total: 24900000,
          bytesPerSec: 1200000,
          eta: Duration(seconds: 18),
        ),
      );
      addTearDown(controller.dispose);

      await _captureWidget(
        tester,
        fileName: 'u2-light-390.png',
        child: Scaffold(
          backgroundColor: Colors.black54,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: UpdaterSheet(controller: controller),
          ),
        ),
      );

      expect(find.text('Mengunduh pembaruan'), findsOneWidget);
      expect(find.text('48%'), findsOneWidget);
      expect(find.text('12,0 / 24,9 MB'), findsOneWidget);
      expect(find.text('1,2 MB/dtk'), findsOneWidget);
      expect(find.text('sekitar 18 dtk'), findsAtLeastNWidgets(1));
      expect(find.text('Batalkan'), findsOneWidget);
    },
  );

  testWidgets(
    'U4 mandatory screen has no Nanti, PopScope blocks back, no overflow at 360dp 1.3x, captures 390 screenshot',
    (tester) async {
      final controller = UpdaterController(
        checkResult: _sampleResult(mandatory: true),
        initialPhase: UpdaterPhase.downloading,
        initialProgress: const DownloadProgress(
          received: 15900000,
          total: 24900000,
          bytesPerSec: 1200000,
          eta: Duration(seconds: 8),
        ),
      );
      addTearDown(controller.dispose);

      await _captureWidget(
        tester,
        fileName: 'u4-light-390.png',
        child: MandatoryUpdateScreen(
          controller: controller,
          autoStartDownload: false,
        ),
      );

      expect(find.text('Pembaruan wajib diperlukan'), findsOneWidget);
      expect(
        find.text(
          'Versi ini sudah tidak didukung. Perbarui untuk lanjut bekerja.',
        ),
        findsOneWidget,
      );
      expect(find.text('Nanti'), findsNothing);
      expect(find.text('Batalkan'), findsNothing);
      expect(find.text('Mengunduh 64%...'), findsOneWidget);

      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);

      // Also verify 360dp @ 1.3x textScaler has zero overflow.
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.3),
              disableAnimations: true,
            ),
            child: MandatoryUpdateScreen(
              controller: controller,
              autoStartDownload: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A1 release list renders active + history & captures 390 screenshot',
    (tester) async {
      final releases = [
        AdminReleaseItem(
          id: 'id-1',
          app: 'pmapp',
          abi: 'arm64-v8a',
          versionCode: 4155,
          baseVersionCode: 2155,
          versionName: '2.0.142',
          sha256: 'a' * 64,
          sizeBytes: 24900000,
          changelog: 'Perbaikan alarm darurat saat sinyal lemah.',
          mandatory: true,
          minSupportedVersion: null,
          status: AdminReleaseStatus.published,
          createdBy: 'Farhan Lakoro',
          createdAt: DateTime(2026, 11, 22, 14, 30),
          publishedAt: DateTime(2026, 11, 22, 14, 30),
        ),
        AdminReleaseItem(
          id: 'id-2',
          app: 'pmapp',
          abi: 'armeabi-v7a',
          versionCode: 3155,
          baseVersionCode: 2155,
          versionName: '2.0.142',
          sha256: 'b' * 64,
          sizeBytes: 23100000,
          changelog: 'Perbaikan alarm darurat saat sinyal lemah.',
          mandatory: false,
          minSupportedVersion: null,
          status: AdminReleaseStatus.published,
          createdBy: 'Farhan Lakoro',
          createdAt: DateTime(2026, 11, 22, 14, 32),
          publishedAt: DateTime(2026, 11, 22, 14, 32),
        ),
        AdminReleaseItem(
          id: 'id-3',
          app: 'pmapp',
          abi: 'arm64-v8a',
          versionCode: 4156,
          baseVersionCode: 2156,
          versionName: '2.0.143',
          sha256: 'c' * 64,
          sizeBytes: 25100000,
          changelog: 'Uji coba sinkronisasi antrean foto offline.',
          mandatory: false,
          minSupportedVersion: null,
          status: AdminReleaseStatus.draft,
          createdBy: 'Farhan Lakoro',
          createdAt: DateTime(2026, 11, 22, 15, 0),
          publishedAt: null,
        ),
        AdminReleaseItem(
          id: 'id-4',
          app: 'pmapp',
          abi: 'arm64-v8a',
          versionCode: 4154,
          baseVersionCode: 2154,
          versionName: '2.0.141',
          sha256: 'd' * 64,
          sizeBytes: 24900000,
          changelog: 'Baseline rilis awal sistem pembaruan otomatis PMApp.',
          mandatory: false,
          minSupportedVersion: null,
          status: AdminReleaseStatus.archived,
          createdBy: 'Farhan Lakoro',
          createdAt: DateTime(2026, 11, 20, 9, 15),
          publishedAt: DateTime(2026, 11, 20, 9, 15),
        ),
      ];

      await _captureWidget(
        tester,
        fileName: 'a1-light-390.png',
        child: AppReleasesScreen(initialReleases: releases),
      );

      expect(find.text('Rilis aplikasi'), findsOneWidget);
      expect(find.text('2 ABI aktif di lapangan'), findsOneWidget);
      expect(find.text('Tarik rilis'), findsNWidgets(2));
      expect(find.text('Unggah APK'), findsOneWidget);
      expect(find.text('Terbitkan'), findsOneWidget);
    },
  );

  testWidgets('A1 shows 403 copy when forbidden', (tester) async {
    final service = AppReleaseAdminService(
      clientFactory: () => MockClient(
        (_) async => http.Response(jsonEncode({'error': 'forbidden'}), 403),
      ),
      baseUrlProvider: () => 'https://example.supabase.co',
      anonKeyProvider: () => 'anon',
      sessionTokenProvider: () => 'v1.tok.sig',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: AppReleasesScreen(service: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Akun ini belum punya akses rilis.'), findsOneWidget);
  });

  testWidgets('A2 shows 409 copy on version_code_must_increase', (
    tester,
  ) async {
    final service = AppReleaseAdminService(
      clientFactory: () => MockClient(
        (_) async => http.Response(
          jsonEncode({'error': 'version_code_must_increase'}),
          409,
        ),
      ),
      baseUrlProvider: () => 'https://example.supabase.co',
      anonKeyProvider: () => 'anon',
      sessionTokenProvider: () => 'v1.tok.sig',
    );

    const apk = LocalApkInfo(
      path: '/tmp/app-arm64.apk',
      fileName: 'app-arm64-v8a-release.apk',
      packageName: 'com.bssparking.timemark.bssparking_timemark',
      versionName: '2.0.141',
      versionCode: 4154,
      abi: 'arm64-v8a',
      baseVersionCode: 2154,
      sizeBytes: 24900000,
      sha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: UploadReleaseScreen(service: service, initialApk: apk),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Simpan sebagai draf'));
    await tester.tap(find.text('Simpan sebagai draf'));
    await tester.pumpAndSettle();

    expect(
      find.text('Nomor versi harus lebih tinggi dari rilis sebelumnya.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'U3 permission explainer & ready state copy has no SHA/ABI/APK/versionCode',
    (tester) async {
      final permCtrl = UpdaterController(
        checkResult: _sampleResult(),
        initialPhase: UpdaterPhase.needsPermission,
      );
      addTearDown(permCtrl.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: UpdaterSheet(controller: permCtrl)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Izinkan pasang pembaruan'), findsOneWidget);
      expect(find.text('Izinkan dari sumber ini'), findsOneWidget);
      expect(find.text('Buka pengaturan'), findsOneWidget);
      for (final forbidden in ['SHA', 'ABI', 'APK', 'versionCode']) {
        expect(find.textContaining(forbidden), findsNothing);
      }

      final readyCtrl = UpdaterController(
        checkResult: _sampleResult(),
        initialPhase: UpdaterPhase.ready,
      );
      addTearDown(readyCtrl.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: UpdaterSheet(controller: readyCtrl)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Siap dipasang'), findsOneWidget);
      expect(find.text('Keaslian file terverifikasi'), findsOneWidget);
      expect(find.text('Pasang sekarang'), findsOneWidget);
      for (final forbidden in ['SHA', 'ABI', 'APK', 'versionCode']) {
        expect(find.textContaining(forbidden), findsNothing);
      }
    },
  );

  testWidgets('U5 error states render exact recovery CTAs', (tester) async {
    for (final entry in {
      AppUpdateErrorKind.noInternet: (
        'Tidak ada koneksi internet',
        'Coba lagi',
      ),
      AppUpdateErrorKind.interrupted: ('Unduhan terputus', 'Lanjutkan unduhan'),
      AppUpdateErrorKind.corruptFile: ('File pembaruan rusak', 'Unduh ulang'),
      AppUpdateErrorKind.storageFull: ('Penyimpanan penuh', 'Coba lagi'),
    }.entries) {
      final ctrl = UpdaterController(
        checkResult: _sampleResult(),
        initialPhase: UpdaterPhase.error,
        initialErrorKind: entry.key,
        initialProgress: const DownloadProgress(
          received: 11400000,
          total: 24900000,
          bytesPerSec: 0,
          eta: null,
        ),
      );
      addTearDown(ctrl.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: UpdaterSheet(controller: ctrl)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(entry.value.$1), findsOneWidget);
      expect(find.text(entry.value.$2), findsOneWidget);
    }
  });
}
