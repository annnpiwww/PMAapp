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
  final fontLoader = FontLoader('PlusJakartaSans');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final file = File('assets/fonts/PlusJakartaSans-$weight.ttf');
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
  return TemplateModel(
    id: 'tpl_maint_sample',
    nama: 'Maintenance Pos',
    deskripsi: 'Template maintenance pos parkir',
    jenis: TemplateCategory.maintPos,
    createdBy: 'admin',
    updatedAt: DateTime(2026, 11, 9),
    sopPoints: const [
      SopPoint(
        id: 'sop_1',
        label: '1. Lampu Indikator & LED Display Pos',
        deskripsi: 'Pemeriksaan nyala lampu indikator modul & LED display pos',
      ),
      SopPoint(
        id: 'sop_2',
        label: '2. Barrier Gate & Palang Parkir',
        deskripsi: 'Pemeriksaan kelancaran motor dan sensor loop',
      ),
    ],
  );
}

MaintenanceSubmission _createSampleSubmission(TemplateModel template) {
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
    points: [
      const MaintenancePointResult(
        pointId: 'sop_1',
        label: '1. Lampu Indikator & LED Display Pos',
        status: PointStatus.perluCekManual,
        alasan: 'sensor kotor, palang miring',
      ),
      const MaintenancePointResult(
        pointId: 'sop_2',
        label: '2. Barrier Gate & Palang Parkir',
        status: PointStatus.sesuai,
        alasan: '',
      ),
    ],
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

  group('Checklist Dialogs — Tiket Restyle (12, 26)', () {
    testWidgets('Light theme 390x844: Klarifikasi temuan AI (12) and Kendala Fisik (26)', (tester) async {
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

      // Open Frame 12 sheet: Klarifikasi temuan AI (sheet poin)
      final perluCekFinder = find.text('Perlu cek');
      expect(perluCekFinder, findsOneWidget);
      await tester.tap(perluCekFinder);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Kondisi Item'), findsOneWidget);
      expect(find.text('Kendala fisik'), findsOneWidget);
      expect(find.text('Foto Ulang'), findsOneWidget);
      expect(find.text('Tutup'), findsOneWidget);
      expect(find.text('Masih aman'), findsOneWidget);
      expect(find.text('Sudah mulai rusak'), findsOneWidget);
      expect(find.text('Harus diganti'), findsOneWidget);

      await _saveBoundaryAsPng(
        tester,
        key,
        'docs/screenshots/tiket-checklist-dialogs/light-390-12-klarifikasi-temuan-ai.png',
      );
      await _saveBoundaryAsPng(
        tester,
        key,
        'docs/screenshots/tiket-checklist-dialogs/light-390-klarifikasi.png',
      );

      // Open Frame 26 dialog: Tandai Kendala Fisik (dialog, dari Checklist)
      final kendalaFisikFinder = find.text('Kendala fisik');
      expect(kendalaFisikFinder, findsOneWidget);
      await tester.tap(kendalaFisikFinder);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Tandai Kendala Fisik'), findsOneWidget);
      expect(find.text('Pilih jenis kendala'), findsOneWidget);
      expect(find.text('Butuh Pengadaan Stiker / Akrilik Baru'), findsOneWidget);
      expect(find.text('Kerusakan Fisik / Cor Pulau Retak (Butuh Sipil)'), findsOneWidget);
      expect(find.text('Sparepart / Komponen Rusak (Butuh Part Kantor)'), findsOneWidget);
      expect(find.text('Karat / Korosi Permanen (Butuh Cat / Semprot Karat)'), findsOneWidget);
      expect(find.text('Kabel / Pipa Tertanam Rusak (Butuh Rekondisi)'), findsOneWidget);
      expect(find.text('Lainnya (Tuliskan Keterangan Khusus)'), findsOneWidget);
      expect(find.text('Simpan Kendala'), findsOneWidget);

      await _saveBoundaryAsPng(
        tester,
        key,
        'docs/screenshots/tiket-checklist-dialogs/light-390-26-kendala-fisik.png',
      );
      await _saveBoundaryAsPng(
        tester,
        key,
        'docs/screenshots/tiket-checklist-dialogs/light-390-kendala.png',
      );
    });

    testWidgets('Dark theme 390x844: Klarifikasi temuan AI (12) and Kendala Fisik (26)', (tester) async {
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

      // Open Frame 12 sheet: Klarifikasi temuan AI (sheet poin)
      final perluCekFinder = find.text('Perlu cek');
      expect(perluCekFinder, findsOneWidget);
      await tester.tap(perluCekFinder);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Kondisi Item'), findsOneWidget);
      expect(find.text('Kendala fisik'), findsOneWidget);
      expect(find.text('Foto Ulang'), findsOneWidget);
      expect(find.text('Tutup'), findsOneWidget);

      await _saveBoundaryAsPng(
        tester,
        key,
        'docs/screenshots/tiket-checklist-dialogs/dark-390-12-klarifikasi-temuan-ai.png',
      );
      await _saveBoundaryAsPng(
        tester,
        key,
        'docs/screenshots/tiket-checklist-dialogs/dark-390-klarifikasi.png',
      );

      // Open Frame 26 dialog: Tandai Kendala Fisik (dialog, dari Checklist)
      final kendalaFisikFinder = find.text('Kendala fisik');
      expect(kendalaFisikFinder, findsOneWidget);
      await tester.tap(kendalaFisikFinder);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Tandai Kendala Fisik'), findsOneWidget);
      expect(find.text('Pilih jenis kendala'), findsOneWidget);
      expect(find.text('Simpan Kendala'), findsOneWidget);

      await _saveBoundaryAsPng(
        tester,
        key,
        'docs/screenshots/tiket-checklist-dialogs/dark-390-26-kendala-fisik.png',
      );
      await _saveBoundaryAsPng(
        tester,
        key,
        'docs/screenshots/tiket-checklist-dialogs/dark-390-kendala.png',
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
        boundaryKey: key,
        textScale: 1.3,
        child: MaintenanceChecklistScreen(
          template: template,
          location: _sampleLocation,
          existingSubmission: submission,
        ),
      ));
      await tester.pumpAndSettle();

      // Open Frame 12 sheet at 360x780 textScaler 1.3
      final perluCekFinder = find.text('Perlu cek');
      await tester.tap(perluCekFinder);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Kondisi Item'), findsOneWidget);

      // Open Frame 26 dialog at 360x780 textScaler 1.3
      final kendalaFisikFinder = find.text('Kendala fisik');
      await tester.tap(kendalaFisikFinder);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Tandai Kendala Fisik'), findsOneWidget);
    });
  });
}
