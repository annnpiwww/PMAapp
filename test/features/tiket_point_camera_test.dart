import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/maintenance/screens/point_camera_view.dart';

Future<void> _loadAppFonts() async {
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
  });
}

const _samplePoint = SopPoint(
  id: 'p1',
  label: 'Palang Gate Masuk',
  deskripsi: 'Pastikan palang tidak lecet, motor arm normal, dan sensor loop aktif',
  checkpoints: ['Kondisi fisik', 'Kabel grounding'],
  panduanFoto: 'Ambil foto palang dalam kondisi tertutup',
  wajibFoto: true,
);

final _sampleTemplate = TemplateModel(
  id: 'tpl1',
  nama: 'Maintenance Gate Barrier',
  deskripsi: 'Pengecekan gate masuk & keluar',
  jenis: TemplateCategory.maintPos,
  wajibLokasi: true,
  sopCriteria: const ['Palang gate', 'Loop detector'],
  sopPoints: const [_samplePoint],
  requiredRole: TemplateRole.teknisi,
  aiMode: AiMode.singleFoto,
  contohFotoDescriptions: const ['Foto palang gate'],
  createdBy: 'system',
  updatedAt: DateTime(2026, 11, 9),
);

const _sampleLocation = PosLocation(
  posId: 'pos-1',
  posName: 'Pos Pasar Bersehati',
  cabangName: 'Manado',
  fullAddress: 'Jl. Nusantara No. 1, Calaca, Kec. Wenang, Kota Manado, Sulawesi Utara',
  locationTag: 'PBM',
  tagColor: Color(0xFF0284C7),
  lat: 1.4921,
  lng: 124.8415,
);

Widget _buildPlaceholderPreview() {
  return Container(
    color: const Color(0xFF3B3B3B),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await _loadAppFonts();
  });

  group('Tiket Point Camera View Redesign Tests & Screenshots', () {
    testWidgets('Capture 19 camera HUD light 390x844', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repaintKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: repaintKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                padding: EdgeInsets.only(top: 44, bottom: 34),
              ),
              child: PointCameraView(
                point: _samplePoint,
                template: _sampleTemplate,
                location: _sampleLocation,
                placeholderPreview: _buildPlaceholderPreview(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _saveBoundaryAsPng(
        tester,
        repaintKey,
        'docs/screenshots/tiket-point-camera/light-390-19.png',
      );
      await _saveBoundaryAsPng(
        tester,
        repaintKey,
        'docs/screenshots/tiket-point-camera/light-390-19-kamera-per-poin.png',
      );

      expect(find.text('Palang Gate Masuk'), findsOneWidget);
      expect(find.text('PBM'), findsNWidgets(2));
      expect(find.text('Maintenance'), findsOneWidget);
      expect(find.text('Barang tidak terpasang di lokasi?'), findsOneWidget);
      expect(find.byKey(const Key('point_camera_shutter_button')), findsOneWidget);
      expect(find.byKey(const Key('point_camera_back_button')), findsOneWidget);
      expect(find.byKey(const Key('point_camera_flash_button')), findsOneWidget);
    });

    testWidgets('Capture 19 camera HUD dark 390x844', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repaintKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: repaintKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                padding: EdgeInsets.only(top: 44, bottom: 34),
              ),
              child: PointCameraView(
                point: _samplePoint,
                template: _sampleTemplate,
                location: _sampleLocation,
                placeholderPreview: _buildPlaceholderPreview(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _saveBoundaryAsPng(
        tester,
        repaintKey,
        'docs/screenshots/tiket-point-camera/dark-390-19.png',
      );
      await _saveBoundaryAsPng(
        tester,
        repaintKey,
        'docs/screenshots/tiket-point-camera/dark-390-19-kamera-per-poin.png',
      );

      expect(find.text('Palang Gate Masuk'), findsOneWidget);
      expect(find.text('Barang tidak terpasang di lokasi?'), findsOneWidget);
    });

    testWidgets('360x780 textScaler 1.3 pump has no overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 780),
              padding: EdgeInsets.only(top: 36, bottom: 24),
              textScaler: TextScaler.linear(1.3),
            ),
            child: PointCameraView(
              point: _samplePoint,
              template: _sampleTemplate,
              location: _sampleLocation,
              placeholderPreview: _buildPlaceholderPreview(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Palang Gate Masuk'), findsOneWidget);
    });
  });
}
