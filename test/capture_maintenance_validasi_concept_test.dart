import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/repositories/template_repository.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_checklist_screen.dart';

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

  final iconFile = File('/home/annnpii/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (iconFile.existsSync()) {
    final iconLoader = FontLoader('MaterialIcons');
    final iconBytes = iconFile.readAsBytesSync();
    iconLoader.addFont(Future.value(ByteData.view(iconBytes.buffer)));
    await iconLoader.load();
  }
}

/// 1x1 PNG transparan, cukup buat thumbnail dummy di kartu poin.
String _tulisFotoDummy(String nama) {
  const pngSatuPiksel =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFAAH/q842iQAAAABJRU5ErkJggg==';
  final file = File('/tmp/opencode/$nama')..parent.createSync(recursive: true);
  file.writeAsBytesSync(base64Decode(pngSatuPiksel));
  return file.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Capture konsep terbaru modal validasi AI maintenance',
    skip: true, // redesign layout, TODO post-2.0.135
    (tester) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();

    // Ukuran layar HP (440 x 1000 logical @2x) biar mirip screenshot asli.
    tester.view.physicalSize = const Size(880, 2000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.runAsync(loadAppFonts);

    final template = TemplateRepository.defaultTemplates
        .firstWhere((t) => t.id == 'tpl_maint_server');
    final fotoA = _tulisFotoDummy('maint_foto_a.png');
    final fotoB = _tulisFotoDummy('maint_foto_b.png');

    final submission = MaintenanceSubmission(
      id: 'concept_sub',
      templateId: template.id,
      templateName: template.nama,
      userId: 'u1',
      userName: 'Teknisi Demo',
      userNpp: '1234',
      posId: 'POS1',
      posName: 'Pos Parkir',
      cabangName: 'Cabang Demo',
      points: [
        MaintenancePointResult(
          pointId: 'srv_1_01',
          label: 'PC Server & Kasir - Pembersihan Storage Linux (df -h & /tmp)',
          status: PointStatus.tidakSesuai,
          confidence: 0.95,
          alasan: 'Foto terlalu gelap, sudut pengambilan belum pas',
          imagePath: fotoA,
          timestamp: DateTime.now(),
        ),
        MaintenancePointResult(
          pointId: 'srv_1_02',
          label: 'PC Server & Kasir - Pengecekan Suhu & Fan',
          status: PointStatus.sesuai,
          confidence: 0.93,
          alasan: 'Suhu normal, kipas bersih',
          imagePath: fotoB,
          timestamp: DateTime.now(),
        ),
        const MaintenancePointResult(
          pointId: 'srv_1_03',
          label: 'PC Server & Kasir - Cek Kabel Power & Konektor',
          status: PointStatus.belumFoto,
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: MaintenanceChecklistScreen(
            template: template,
            existingSubmission: submission,
            serverOs: 'linux',
            isServerKasirGabung: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Buka modal validasi AI poin bermasalah, lalu pilih satu kondisi item.
    await tester.tap(find.textContaining('Pembersihan Storage Linux').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Harus diganti'));
    await tester.tap(find.text('Harus diganti'));
    await tester.pumpAndSettle();

    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary != null) {
      await tester.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: 2.0);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        if (bytes != null) {
          final file = File('docs/screenshots/maintenance_validasi_ai_terbaru.png');
          file.parent.createSync(recursive: true);
          await file.writeAsBytes(bytes.buffer.asUint8List());
          debugPrint('Saved konsep validasi maintenance: ${file.path}');
        }
      });
    }
  });
}
