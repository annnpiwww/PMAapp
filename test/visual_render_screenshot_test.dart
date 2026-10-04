import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/templates/widgets/absensi_kategori_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'bss_last_technician_name_v1': 'Junifer Manua',
      'absensi_lokasi_standby_v1': 'PBM',
      'absensi_jadwal_shift_v1': 'Shift 1 (03:00 - 11:00)',
      'absensi_tipe_laporan_v1': 'Masuk',
    });
    await StorageService.init();
    await StorageService.saveLastTechnicianName('Junifer Manua');
  });

  testWidgets('Capture visual screenshot of Atur Shift modal redesign', (tester) async {
    final boundaryKey = GlobalKey();

    // Standard modern smartphone viewport: 390 x 844 pt (iPhone 14 / modern Android)
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'PlusJakartaSans',
        ),
        home: Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: RepaintBoundary(
            key: boundaryKey,
            child: const Center(
              child: AbsensiKategoriDialog(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Render boundary to image inside tester.runAsync
    final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary != null) {
      await tester.runAsync(() async {
        final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final buffer = byteData.buffer.asUint8List();
          final dir = Directory('test_artifacts');
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }
          final file = File('test_artifacts/atur_shift_modal_redesign.png');
          await file.writeAsBytes(buffer);
          // ignore: avoid_print
          print('Captured visual screenshot: ${file.absolute.path} (${buffer.length} bytes)');
        }
      });
    }

    expect(tester.takeException(), isNull);
  });
}
