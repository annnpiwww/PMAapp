import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/core/constants/app_colors.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/features/daily_tasks/widgets/spv_task_card.dart';

bool _fontsLoaded = false;

Future<void> loadAppFonts(WidgetTester tester) async {
  if (_fontsLoaded) return;
  await tester.runAsync(() async {
    // 1. Figtree (App Font)
    final pjsLoader = FontLoader('Figtree');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      final file = File('assets/fonts/Figtree-$weight.ttf');
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        pjsLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
      }
    }
    await pjsLoader.load();

    // 2. Roboto (Flutter SDK fallback)
    const robotoDir = '/home/annnpii/flutter/bin/cache/artifacts/material_fonts';
    final robotoLoader = FontLoader('Roboto');
    for (final name in ['Regular', 'Medium', 'Bold']) {
      final file = File('$robotoDir/Roboto-$name.ttf');
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        robotoLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
      }
    }
    await robotoLoader.load();

    // 3. MaterialIcons
    final iconFile = File('$robotoDir/MaterialIcons-Regular.otf');
    if (iconFile.existsSync()) {
      final iconLoader = FontLoader('MaterialIcons');
      final iconBytes = iconFile.readAsBytesSync();
      iconLoader.addFont(Future.value(ByteData.view(iconBytes.buffer)));
      await iconLoader.load();
    }
    _fontsLoaded = true;
  });
}

void main() {
  DailyTaskModel createBaseTask({
    String id = 'task-1',
    String posTag = 'PKM',
    String posName = 'Parkir Kawasan Megamas',
    String judul = 'Pemasangan lampu pos',
    String deskripsi = 'Ganti 2 lampu LED depan booth',
    String teknisiNama = 'Ryan Lumasuge',
    String peserta = '',
    String kategori = 'khusus',
    TaskStatus status = TaskStatus.pending,
    String? jamSelesai,
    List<String> fotoBuktiUrls = const [],
    String? catatanTeknisi,
    String serahTerima = '',
  }) {
    return DailyTaskModel(
      id: id,
      tanggal: '2026-11-04',
      teknisiId: 'u-1',
      teknisiNama: teknisiNama,
      posName: posName,
      posTag: posTag,
      judul: judul,
      deskripsi: deskripsi,
      kategori: kategori,
      status: status,
      jamSelesai: jamSelesai,
      fotoBuktiUrls: fotoBuktiUrls,
      catatanTeknisi: catatanTeknisi,
      peserta: peserta,
      serahTerima: serahTerima,
    );
  }

  Widget buildTestCard({
    required DailyTaskModel task,
    bool isDark = false,
    bool isExpanded = false,
    VoidCallback? onToggleExpand,
    VoidCallback? onHandover,
    VoidCallback? onDelete,
    double textScaleFactor = 1.0,
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: isDark
          ? ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.primaryLight,
                surface: AppColors.darkSurface,
              ),
            )
          : ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primary,
                surface: AppColors.surface,
              ),
            ),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 800),
          textScaler: TextScaler.linear(textScaleFactor),
        ),
        child: Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Align(
              alignment: Alignment.topCenter,
              child: SpvTaskCard(
                task: task,
                isDark: isDark,
                isExpanded: isExpanded,
                onToggleExpand: onToggleExpand ?? () {},
                onHandover: onHandover,
                onDelete: onDelete,
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('SpvTaskCard Specification Tests', () {
    testWidgets('(a) posName renders in meta line and semantics', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final task = createBaseTask(posTag: 'PKM', posName: 'Kawasan Megamas');
        await tester.pumpWidget(buildTestCard(task: task));
        await tester.pumpAndSettle();

        expect(find.textContaining('Kawasan Megamas'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(r'lokasi Kawasan Megamas')), findsOneWidget);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('(b) posTag empty + posName Kawasan Megamas renders Kawasan Megamas', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final task = createBaseTask(posTag: '', posName: 'Kawasan Megamas');
        await tester.pumpWidget(buildTestCard(task: task));
        await tester.pumpAndSettle();

        expect(find.textContaining('Kawasan Megamas'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(r'lokasi Kawasan Megamas')), findsOneWidget);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('(c) both empty -> no Semantics Lokasi', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final task = createBaseTask(posTag: '   ', posName: '   ');
        await tester.pumpWidget(buildTestCard(task: task));
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel(RegExp(r'lokasi')), findsNothing);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('(d) pending + onHandover -> Alihkan present, status Belum mulai', (tester) async {
      final task = createBaseTask(status: TaskStatus.pending);
      await tester.pumpWidget(
        buildTestCard(
          task: task,
          onHandover: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alihkan'), findsOneWidget);
      expect(find.text('Belum mulai'), findsOneWidget);
    });

    testWidgets('(e) done with 2 photos + jamSelesai 09:49 -> Bukti (2) and Selesai', (tester) async {
      final task = createBaseTask(
        status: TaskStatus.completed,
        jamSelesai: '09:49',
        fotoBuktiUrls: ['https://example.com/p1.jpg', 'https://example.com/p2.jpg'],
      );
      await tester.pumpWidget(buildTestCard(task: task));
      await tester.pumpAndSettle();

      expect(find.text('Bukti (2)'), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);
    });

    testWidgets('(f) every Text inside the card has effective fontSize >= 12', (tester) async {
      final task = createBaseTask(
        status: TaskStatus.completed,
        jamSelesai: '09:49',
        kategori: 'maintenance',
        serahTerima: 'Raldy|Ryan|Ganti shift|08:00',
        catatanTeknisi: 'Kabel sensor gate 3 diperbaiki.',
        fotoBuktiUrls: ['url1', 'url2'],
      );
      await tester.pumpWidget(
        buildTestCard(
          task: task,
          isExpanded: true,
          onDelete: () {},
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.byType(SpvTaskCard);
      final textWidgets = tester.widgetList<Text>(
        find.descendant(of: cardFinder, matching: find.byType(Text)),
      );

      expect(textWidgets.isNotEmpty, isTrue);
      for (final text in textWidgets) {
        final fontSize = text.style?.fontSize ?? 14.0;
        expect(
          fontSize >= 12.0,
          isTrue,
          reason: 'Text "${text.data}" has fontSize $fontSize which is less than 12sp',
        );
      }
    });

    testWidgets('(g) textScaler 1.3 with a 60-char judul and all tags -> no overflow exception', (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final taskLong = createBaseTask(
        posTag: 'PKM',
        posName: 'Parkir Kawasan Megamas',
        judul: 'Pemasangan barrier gate baru di pos barat daya Megamas Manado', // 61 chars
        deskripsi: 'Pengecekan rutin kabel optik dan power supply unit 1 sampai 6',
        kategori: 'maintenance',
        serahTerima: 'Raldy|Ryan|Lanjutan shift|08:00',
        catatanTeknisi: 'Perlu penggantian sekring cadangan di box utama.',
        status: TaskStatus.pending,
      );

      await tester.pumpWidget(
        buildTestCard(
          task: taskLong,
          isExpanded: true,
          textScaleFactor: 1.3,
          onHandover: () {},
          onDelete: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('(h) kebab menu hit area >= 44x44', (tester) async {
      final task = createBaseTask();
      await tester.pumpWidget(
        buildTestCard(
          task: task,
          onDelete: () {},
        ),
      );
      await tester.pumpAndSettle();

      final kebabFinder = find.byTooltip('Pilihan menu tugas');
      expect(kebabFinder, findsOneWidget);

      final size = tester.getSize(kebabFinder);
      expect(size.width >= 44.0, isTrue, reason: 'Kebab width was ${size.width}');
      expect(size.height >= 44.0, isTrue, reason: 'Kebab height was ${size.height}');
    });

    testWidgets('pending card with onHandover renders status pill and Alihkan in the same row with compact width and right edge alignment', (tester) async {
      final task = createBaseTask(status: TaskStatus.pending);
      await tester.pumpWidget(
        buildTestCard(
          task: task,
          onHandover: () {},
          onDelete: () {},
        ),
      );
      await tester.pumpAndSettle();

      final statusCenter = tester.getCenter(find.text('Belum mulai'));
      final alihkanCenter = tester.getCenter(find.text('Alihkan'));
      expect((statusCenter.dy - alihkanCenter.dy).abs() <= 4.0, isTrue);

      final cardWidth = tester.getSize(find.byType(SpvTaskCard)).width;
      final alihkanTarget = find.ancestor(of: find.text('Alihkan'), matching: find.byType(ConstrainedBox)).first;
      final alihkanWidth = tester.getSize(alihkanTarget).width;
      expect(alihkanWidth < cardWidth * 0.5, isTrue);

      // Alihkan visual height <= 36
      final alihkanMaterial = find.ancestor(of: find.text('Alihkan'), matching: find.byType(Material)).first;
      final visualHeight = tester.getSize(alihkanMaterial).height;
      expect(visualHeight <= 36.0, isTrue, reason: 'Alihkan visual height was $visualHeight');

      // Alihkan hit target >= 48
      final hitHeight = tester.getSize(alihkanTarget).height;
      expect(hitHeight >= 48.0, isTrue, reason: 'Alihkan hit height was $hitHeight');

      // Alihkan right edge matches kebab menu right edge
      final kebabRight = tester.getTopRight(find.byTooltip('Pilihan menu tugas')).dx;
      final alihkanRight = tester.getTopRight(alihkanTarget).dx;
      expect((kebabRight - alihkanRight).abs() <= 1.0, isTrue, reason: 'Kebab right $kebabRight vs Alihkan right $alihkanRight');
    });

    testWidgets('posName PPM renders in meta line with kategori', (tester) async {
      final task = createBaseTask(posTag: 'PPM', posName: 'PPM', teknisiNama: 'Alessandro');
      await tester.pumpWidget(buildTestCard(task: task));
      await tester.pumpAndSettle();

      expect(find.textContaining('PPM · khusus'), findsOneWidget);
    });

    testWidgets('Alihkan and Bukti tap target height >= 44', (tester) async {
      final pendingTask = createBaseTask(status: TaskStatus.pending);
      await tester.pumpWidget(
        buildTestCard(
          task: pendingTask,
          onHandover: () {},
        ),
      );
      await tester.pumpAndSettle();

      final alihkanTarget = tester.getSize(
        find.ancestor(of: find.text('Alihkan'), matching: find.byType(ConstrainedBox)).first,
      );
      expect(alihkanTarget.height >= 48.0, isTrue);

      final doneTask = createBaseTask(
        status: TaskStatus.completed,
        jamSelesai: '10:00',
        fotoBuktiUrls: ['url1'],
      );
      await tester.pumpWidget(buildTestCard(task: doneTask));
      await tester.pumpAndSettle();

      final buktiTarget = tester.getSize(
        find.ancestor(of: find.text('Bukti (1)'), matching: find.byType(ConstrainedBox)).first,
      );
      expect(buktiTarget.height >= 48.0, isTrue);

      final buktiMaterial = tester.getSize(
        find.ancestor(of: find.text('Bukti (1)'), matching: find.byType(Material)).first,
      );
      expect(buktiMaterial.height <= 36.0, isTrue);
    });

    testWidgets('pending card with 1-line title and no deskripsi has height <= 160dp', (tester) async {
      final task = createBaseTask(
        judul: 'Pemasangan lampu pos',
        deskripsi: '',
        status: TaskStatus.pending,
      );
      await tester.pumpWidget(
        buildTestCard(
          task: task,
          onHandover: () {},
        ),
      );
      await tester.pumpAndSettle();

      final cardSize = tester.getSize(find.byType(SpvTaskCard));
      expect(cardSize.height <= 160.0, isTrue, reason: 'Card height was ${cardSize.height}');
    });
  });
}
