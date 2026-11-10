import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/models/user_model.dart';
import 'package:bssparking_timemark/data/repositories/auth_repository.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_checklist_screen.dart';

bool _fontsLoaded = false;
Future<void> _loadAppFonts() async {
  if (_fontsLoaded) return;
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
  _fontsLoaded = true;
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

const PosLocation _sampleLocation = PosLocation(
  posId: 'POS-01',
  posName: 'Pos Pasar Bersehati',
  cabangName: 'KC Manado',
  fullAddress: 'Jl. Nusantara, Pasar Bersehati, Manado',
  locationTag: 'PBM',
  tagColor: Colors.blue,
  lat: 1.4931,
  lng: 124.8412,
);

UserModel _sampleUser() => UserModel(
      id: 'u-ryan',
      nama: 'Ryan Lumasuge',
      npp: 'BSS-042',
      email: 'ryan@bss.id',
      role: UserRole.petugas,
      posId: 'POS-01',
      posName: 'Pos Pasar Bersehati',
      cabangName: 'KC Manado',
    );

TemplateModel _createSampleTemplate() {
  final points = <SopPoint>[];
  for (int i = 1; i <= 24; i++) {
    points.add(
      SopPoint(
        id: 'sop_$i',
        label: '$i. Pemeriksaan Item $i',
        deskripsi: 'Deskripsi SOP untuk pemeriksaan item $i',
      ),
    );
  }
  return TemplateModel(
    id: 'tpl_maint_sample',
    nama: 'Maintenance Pos',
    deskripsi: 'Template maintenance pos parkir',
    jenis: TemplateCategory.maintPos,
    createdBy: 'admin',
    updatedAt: DateTime(2026, 11, 9),
    sopPoints: points,
  );
}

MaintenanceSubmission _createSampleSubmission(TemplateModel template) {
  final pointResults = <MaintenancePointResult>[];
  for (int i = 1; i <= 24; i++) {
    final sop = template.sopPoints[i - 1];
    PointStatus status;
    String alasan = '';
    if (i <= 17) {
      status = PointStatus.sesuai;
    } else if (i == 18) {
      status = PointStatus.perluCekManual;
      alasan = 'Perlu cek sudut kemiringan';
    } else {
      status = PointStatus.belumFoto;
    }
    pointResults.add(
      MaintenancePointResult(
        pointId: sop.id,
        label: sop.label,
        status: status,
        alasan: alasan,
      ),
    );
  }
  return MaintenanceSubmission(
    id: 'sub_test_01',
    templateId: template.id,
    templateName: template.nama,
    userId: 'u-ryan',
    userName: 'Ryan Lumasuge',
    userNpp: 'BSS-042',
    posId: _sampleLocation.posId,
    posName: _sampleLocation.posName,
    cabangName: _sampleLocation.cabangName,
    points: pointResults,
    createdAt: DateTime(2026, 11, 9, 8, 30),
    updatedAt: DateTime(2026, 11, 9, 8, 30),
  );
}

Widget _buildApp({
  required ThemeData theme,
  required double width,
  required double height,
  required GlobalKey boundaryKey,
  double textScale = 1.0,
  required Widget child,
}) {
  return RepaintBoundary(
    key: boundaryKey,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          padding: const EdgeInsets.only(top: 24, bottom: 24),
          textScaler: TextScaler.linear(textScale),
        ),
        child: SizedBox(
          width: width,
          height: height,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadAppFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
    await BranchService.instance.setBranch(AppBranch.manado);
    await AuthRepository.instance.login(_sampleUser());
  });

  group('Checklist Maintenance & Status Dialog — Tiket Restyle (06, 06b)', () {
    testWidgets('Light theme 390x844 checklist screen and status dialog', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final template = _createSampleTemplate();
      final submission = _createSampleSubmission(template);
      final key = GlobalKey();

      await tester.pumpWidget(_buildApp(
        theme: AppTheme.lightTheme,
        width: 390,
        height: 844,
        boundaryKey: key,
        child: MaintenanceChecklistScreen(
          template: template,
          location: _sampleLocation,
          existingSubmission: submission,
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Riwayat'), findsOneWidget);
      expect(find.text('18/24'), findsOneWidget);
      expect(find.text('foto masuk'), findsOneWidget);
      expect(find.textContaining('17 sesuai · 1 perlu cek · 6 belum difoto'), findsOneWidget);
      expect(find.text('Semua status'), findsOneWidget);
      expect(find.text('6 poin belum difoto'), findsOneWidget);
      expect(find.text('Simpan & Selesaikan Laporan'), findsOneWidget);

      await _saveBoundaryAsPng(
        tester,
        key,
        'docs/screenshots/tiket-checklist/light-390-06-checklist-maintenance.png',
      );
      await _saveBoundaryAsPng(
        tester,
        key,
        'docs/screenshots/tiket-checklist/light-390-checklist.png',
      );

      // Open status filter dialog (06b)
      await tester.tap(find.text('Semua status'));
      await tester.pumpAndSettle();

      expect(find.text('Status Poin'), findsOneWidget);
      expect(find.text('Semua status'), findsWidgets);
      expect(find.text('Sesuai'), findsWidgets);
      expect(find.text('Perlu cek'), findsWidgets);
      expect(find.text('Belum difoto'), findsOneWidget);

      await _saveBoundaryAsPng(
        tester,
        key,
        'docs/screenshots/tiket-checklist/light-390-06b-checklist-dialog-status.png',
      );
      await _saveBoundaryAsPng(
        tester,
        key,
        'docs/screenshots/tiket-checklist/light-390-dialog.png',
      );
    });

    testWidgets('Dark theme 390x844 checklist screen and status dialog', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final template = _createSampleTemplate();
      final submission = _createSampleSubmission(template);
      final key = GlobalKey();

      await tester.pumpWidget(_buildApp(
        theme: AppTheme.darkTheme,
        width: 390,
        height: 844,
        boundaryKey: key,
        child: MaintenanceChecklistScreen(
          template: template,
          location: _sampleLocation,
          existingSubmission: submission,
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Riwayat'), findsOneWidget);
      expect(find.text('18/24'), findsOneWidget);
      expect(find.text('foto masuk'), findsOneWidget);
      expect(find.textContaining('17 sesuai · 1 perlu cek · 6 belum difoto'), findsOneWidget);
      expect(find.text('Semua status'), findsOneWidget);
      expect(find.text('6 poin belum difoto'), findsOneWidget);
      expect(find.text('Simpan & Selesaikan Laporan'), findsOneWidget);

      await _saveBoundaryAsPng(
        tester,
        key,
        'docs/screenshots/tiket-checklist/dark-390-06-checklist-maintenance-dark.png',
      );
      await _saveBoundaryAsPng(
        tester,
        key,
        'docs/screenshots/tiket-checklist/dark-390-checklist.png',
      );

      // Open status filter dialog (06b dark)
      await tester.tap(find.text('Semua status'));
      await tester.pumpAndSettle();

      expect(find.text('Status Poin'), findsOneWidget);
      expect(find.text('Semua status'), findsWidgets);
      expect(find.text('Sesuai'), findsWidgets);
      expect(find.text('Perlu cek'), findsWidgets);
      expect(find.text('Belum difoto'), findsOneWidget);

      await _saveBoundaryAsPng(
        tester,
        key,
        'docs/screenshots/tiket-checklist/dark-390-06b-checklist-dialog-status.png',
      );
      await _saveBoundaryAsPng(
        tester,
        key,
        'docs/screenshots/tiket-checklist/dark-390-dialog.png',
      );
    });

    testWidgets('Responsive 360x780 textScaler 1.3 asserts no overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final template = _createSampleTemplate();
      final submission = _createSampleSubmission(template);
      final key = GlobalKey();

      await tester.pumpWidget(_buildApp(
        theme: AppTheme.lightTheme,
        width: 360,
        height: 780,
        textScale: 1.3,
        boundaryKey: key,
        child: MaintenanceChecklistScreen(
          template: template,
          location: _sampleLocation,
          existingSubmission: submission,
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
