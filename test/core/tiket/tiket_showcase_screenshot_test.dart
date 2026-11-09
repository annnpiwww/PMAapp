import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/core/constants/tiket_colors.dart';
import 'package:bssparking_timemark/core/widgets/tiket/tiket.dart';

Future<void> loadAppFonts() async {
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
}

class TiketShowcaseScreen extends StatelessWidget {
  const TiketShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final pad = TiketSpace.padOf(context);
    final type = TiketType.of(context);

    return Scaffold(
      backgroundColor: colors.canvas,
      body: Column(
        children: [
          TiketBand(
            leading: TiketIconButton(
              icon: Icons.arrow_back,
              semanticLabel: 'Kembali',
              onPressed: () {},
            ),
            actions: [
              TiketIconButton(
                icon: Icons.refresh,
                semanticLabel: 'Muat ulang',
                onPressed: () {},
              ),
            ],
            caption: 'KC Manado · 09 Nov 2026',
            hero: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '1/4',
                  style: type.hero(color: colors.onBand),
                ),
                const SizedBox(width: 8.0),
                Text(
                  'tugas selesai',
                  style: type.heroLabel(color: colors.onBand),
                ),
              ],
            ),
            footer: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  TiketPill(label: 'Semua', kind: TiketPillKind.bandSelected, onPressed: () {}),
                  const SizedBox(width: 8.0),
                  TiketPill(label: 'Pending', kind: TiketPillKind.band, badge: '3', onPressed: () {}),
                  const SizedBox(width: 8.0),
                  TiketPill(label: 'Selesai', kind: TiketPillKind.band, onPressed: () {}),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 16.0),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  child: TiketSegmented<String>(
                    options: const [
                      ('Tugas', 'Tugas'),
                      ('Temuan', 'Temuan'),
                      ('Riwayat', 'Riwayat'),
                    ],
                    selected: 'Tugas',
                    onChanged: (_) {},
                  ),
                ),
                const SizedBox(height: 12.0),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  child: TiketDropdownField(
                    label: 'Filter Teknisi',
                    value: 'Semua Teknisi (4)',
                    onTap: () {},
                  ),
                ),
                const SizedBox(height: 12.0),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  child: const Row(
                    children: [
                      StatusChip(label: 'Sesuai', kind: TiketChipKind.ok),
                      SizedBox(width: 6.0),
                      StatusChip(label: 'Perlu cek', kind: TiketChipKind.attention),
                      SizedBox(width: 6.0),
                      StatusChip(label: 'Belum', kind: TiketChipKind.neutral),
                      SizedBox(width: 6.0),
                      StatusChip(label: 'Urgent', kind: TiketChipKind.danger),
                    ],
                  ),
                ),
                const SizedBox(height: 12.0),
                TiketRow(
                  leading: const StatusMarker(status: TiketStatus.ok),
                  title: 'Pemeriksaan Pos Masuk Gate 1',
                  meta: const ['Gate 1', '08:30 WITA'],
                  status: ('Selesai', colors.okText),
                  trailing: TiketPill(label: 'Lihat', kind: TiketPillKind.secondary, onPressed: () {}),
                  onTap: () {},
                ),
                TiketRow(
                  leading: const StatusMarker(status: TiketStatus.attention),
                  title: 'Perbaikan Barrier Gate Keluar Motor',
                  meta: const ['Pos Keluar', '09:45 WITA'],
                  status: ('Perlu perhatian', colors.signalText),
                  trailing: TiketPill(label: 'Kerjakan', kind: TiketPillKind.primary, onPressed: () {}),
                  onTap: () {},
                ),
                TiketRow(
                  leading: const StatusMarker(status: TiketStatus.notStarted),
                  title: 'Pembersihan Sensor Loop Barrier',
                  meta: const ['Gate 2', '11:00 WITA'],
                  status: ('Belum', colors.body),
                  trailing: TiketPill(label: 'Mulai', kind: TiketPillKind.secondary, onPressed: () {}),
                  onTap: () {},
                ),
              ],
            ),
          ),
          TiketBottomBar(
            helper: '2 tugas belum diselesaikan',
            primary: TiketPill(
              label: 'Selesaikan Laporan',
              kind: TiketPillKind.primary,
              expand: true,
              onPressed: () {},
            ),
            secondary: TiketPill(
              label: 'Simpan Sementara',
              kind: TiketPillKind.secondary,
              expand: true,
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _captureShowcase({
  required WidgetTester tester,
  required Brightness brightness,
  required double width,
  required double height,
  required String outputPath,
}) async {
  final key = GlobalKey();
  final theme = brightness == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme;

  tester.view.physicalSize = Size(width, height);
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
            size: Size(width, height),
            padding: const EdgeInsets.only(top: 24.0, bottom: 24.0),
          ),
          child: const Scaffold(
            body: TiketShowcaseScreen(),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) throw Exception('RenderRepaintBoundary not found');

  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Failed to get png byteData');

    final file = File(outputPath);
    file.parent.createSync(recursive: true);
    await file.writeAsBytes(byteData.buffer.asUint8List());
    // ignore: avoid_print
    print('Generated screenshot: $outputPath (${file.lengthSync()} bytes)');
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
  });

  group('Tiket Showcase Screenshots', () {
    testWidgets('Capture light-360', (tester) async {
      await _captureShowcase(
        tester: tester,
        brightness: Brightness.light,
        width: 360.0,
        height: 800.0,
        outputPath: 'docs/screenshots/tiket-foundation/light-360.png',
      );
      expect(File('docs/screenshots/tiket-foundation/light-360.png').existsSync(), isTrue);
    });

    testWidgets('Capture light-390', (tester) async {
      await _captureShowcase(
        tester: tester,
        brightness: Brightness.light,
        width: 390.0,
        height: 844.0,
        outputPath: 'docs/screenshots/tiket-foundation/light-390.png',
      );
      expect(File('docs/screenshots/tiket-foundation/light-390.png').existsSync(), isTrue);
    });

    testWidgets('Capture dark-360', (tester) async {
      await _captureShowcase(
        tester: tester,
        brightness: Brightness.dark,
        width: 360.0,
        height: 800.0,
        outputPath: 'docs/screenshots/tiket-foundation/dark-360.png',
      );
      expect(File('docs/screenshots/tiket-foundation/dark-360.png').existsSync(), isTrue);
    });

    testWidgets('Capture dark-390', (tester) async {
      await _captureShowcase(
        tester: tester,
        brightness: Brightness.dark,
        width: 390.0,
        height: 844.0,
        outputPath: 'docs/screenshots/tiket-foundation/dark-390.png',
      );
      expect(File('docs/screenshots/tiket-foundation/dark-390.png').existsSync(), isTrue);
    });
  });
}
