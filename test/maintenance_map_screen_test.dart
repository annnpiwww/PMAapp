import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/models/maintenance_temuan_fix.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/maintenance_log_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_location_detail_screen.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_map_screen.dart';

bool _fontsLoaded = false;
Future<void> loadAppFonts() async {
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BranchService.instance.resetForTesting();
  });

  group('MaintenanceMapScreen.shortName', () {
    test('strips trailing Manado case-insensitively', () {
      const loc1 = PosLocation(
        posId: '1',
        posName: 'Pasar Bersehati Manado',
        cabangName: 'KC Manado',
        fullAddress: 'Jl. Nusantara',
        locationTag: 'PBM',
        tagColor: Colors.blue,
        lat: 1.49,
        lng: 124.84,
      );
      expect(MaintenanceMapScreen.shortName(loc1), equals('Pasar Bersehati'));

      const locLower = PosLocation(
        posId: '1b',
        posName: 'pasar bersehati manado',
        cabangName: 'KC Manado',
        fullAddress: '',
        locationTag: 'PBM',
        tagColor: Colors.blue,
        lat: 0,
        lng: 0,
      );
      expect(MaintenanceMapScreen.shortName(locLower), equals('pasar bersehati'));
    });

    test('replaces leading Mie Gacoan with Gacoan', () {
      const loc2 = PosLocation(
        posId: '2',
        posName: 'Mie Gacoan AirMadidi',
        cabangName: 'KC Manado',
        fullAddress: 'Jl. Raya Airmadidi',
        locationTag: 'GCO',
        tagColor: Colors.orange,
        lat: 1.42,
        lng: 124.98,
      );
      expect(MaintenanceMapScreen.shortName(loc2), equals('Gacoan AirMadidi'));

      const locGacoanManado = PosLocation(
        posId: '2b',
        posName: 'Mie Gacoan Manado',
        cabangName: 'KC Manado',
        fullAddress: '',
        locationTag: 'GCO',
        tagColor: Colors.orange,
        lat: 0,
        lng: 0,
      );
      expect(MaintenanceMapScreen.shortName(locGacoanManado), equals('Gacoan'));
    });

    test('leaves names without target patterns unchanged', () {
      const loc3 = PosLocation(
        posId: '3',
        posName: 'Mall Pelayanan Publik',
        cabangName: 'KC Manado',
        fullAddress: 'Kawasan Megamas',
        locationTag: 'MPP',
        tagColor: Colors.purple,
        lat: 1.48,
        lng: 124.83,
      );
      expect(
        MaintenanceMapScreen.shortName(loc3),
        equals('Mall Pelayanan Publik'),
      );
    });
  });

  group('MaintenanceMapScreen.formatTanggalShort', () {
    test('formats ISO dates correctly into d MMM', () {
      expect(MaintenanceMapScreen.formatTanggalShort('2026-11-03'), equals('3 Nov'));
      expect(MaintenanceMapScreen.formatTanggalShort('2026-04-15'), equals('15 Apr'));
      expect(MaintenanceMapScreen.formatTanggalShort('invalid'), equals('invalid'));
    });
  });

  group('MaintenanceLocationRow Overflow at 320dp', () {
    testWidgets(
      'renders without RenderFlex overflow exception at 320dp width with 60-char posName and 40-char tech',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final longPosName = 'A' * 60; // 60 characters
        final longTechName = 'B' * 40; // 40 characters

        final location = PosLocation(
          posId: 'POS-TEST-LONG-01',
          posName: longPosName,
          cabangName: 'KC Manado',
          fullAddress: 'Jl. Sam Ratulangi No. 123 Manado',
          locationTag: 'LONGTAG',
          tagColor: Colors.blue,
          lat: 1.47,
          lng: 124.84,
        );

        final currentPhase = MaintenanceLogService.phaseForDate(DateTime.now());
        final templateForCurrent =
            MaintenanceLogService.phaseTemplates[currentPhase] ??
                'tpl_maint_manless';

        final log = MaintenanceLogEntry(
          id: 'log-test-long',
          tanggal: '2026-11-03',
          jamSelesai: '13:45',
          posId: 'POS-TEST-LONG-01',
          posName: longPosName,
          teknisiNama: longTechName,
          templateId: templateForCurrent,
          totalPoin: 12,
          sesuaiPoin: 10,
          temuan: const [
            MaintenanceTemuan(
              label: 'Sensor palang barrier kotor dan kabel kendur',
              status: 'tidak_sesuai',
              alasan: 'Perlu dibersihkan segera',
              urgent: true,
            ),
          ],
        );

        final status = PosMaintenanceStatus(
          location: location,
          wilayah: 'Manado',
          logs: [log],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: MaintenanceLocationRow(
                  status: status,
                  isCurrentMonth: true,
                  selectedMonth: DateTime(2026, 11, 1),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(MaintenanceLocationRow), findsOneWidget);
        expect(find.text('LONGTAG'), findsOneWidget);
        expect(find.text('1 Temuan'), findsOneWidget);
      },
    );

    testWidgets(
      'renders without overflow when phase is not done (Belum dikerjakan) at 320dp',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final longPosName = 'Lokasi Tanpa Log Sangat Panjang Sekali Enam Puluh Karakter!!';
        final location = PosLocation(
          posId: 'POS-TEST-EMPTY',
          posName: longPosName,
          cabangName: 'KC Manado',
          fullAddress: 'Jl. Hasanuddin No. 99 Manado',
          locationTag: 'EMPTY',
          tagColor: Colors.grey,
          lat: 1.48,
          lng: 124.83,
        );

        final status = PosMaintenanceStatus(
          location: location,
          wilayah: 'Airmadidi',
          logs: const [],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: MaintenanceLocationRow(
                  status: status,
                  isCurrentMonth: true,
                  selectedMonth: DateTime(2026, 11, 1),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Belum'), findsOneWidget);
        expect(find.text('EMPTY'), findsOneWidget);
      },
    );
  });

  group('MaintenanceMapScreen Widget Tests', () {
    testWidgets(
      'pumps screen and asserts FlutterMap is present while loading (map not replaced by spinner)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: MaintenanceMapScreen(),
          ),
        );

        // While _isLoading is true on first build frame:
        // 1. FlutterMap must stay mounted
        expect(find.byType(FlutterMap), findsOneWidget);
        // 2. Loading overlay on map must be present (indeterminate progress indicator)
        expect(
          find.byWidgetPredicate(
            (w) => w is LinearProgressIndicator && w.value == null,
          ),
          findsOneWidget,
        );
        // 3. Map should not be replaced by CircularProgressIndicator
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'completes load cycle with zero logs and renders UI gracefully without throwing',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: MaintenanceMapScreen(),
          ),
        );

        // Advance frames and async operations in _initData / _loadMonthData
        FlutterError.onError = (FlutterErrorDetails details) {
          debugPrint('DETAILS_SUMMARY: ${details.summary}');
          if (details.informationCollector != null) {
            for (final node in details.informationCollector!()) {
              debugPrint('NODE: ${node.toString()}');
            }
          }
        };

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final err = tester.takeException();
        if (err is FlutterError) {
          debugPrint('ERR_DEEP:\n${err.toStringDeep()}');
        }
        expect(err, isNull);
        expect(find.byType(FlutterMap), findsOneWidget);
      },
    );

    testWidgets(
      'asserts TileLayer uses OpenStreetMap URL template without API key and no cartocdn',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: MaintenanceMapScreen(),
          ),
        );

        final tileLayerFinder = find.byType(TileLayer);
        expect(tileLayerFinder, findsOneWidget);
        final tileLayer = tester.widget<TileLayer>(tileLayerFinder);
        expect(
          tileLayer.urlTemplate,
          equals('https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
        );
        expect(tileLayer.urlTemplate!.contains('cartocdn'), isFalse);
      },
    );

    testWidgets(
      'asserts floating summary card no longer exists, phase strip shows Fase text, TileLayer has no tileBuilder, and map fills screen',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: MaintenanceMapScreen(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 1. Phase strip shows 'Fase' text
        expect(find.textContaining('Fase'), findsWidgets);

        // 2. TileLayer has no tileBuilder
        final tileLayerFinder = find.byType(TileLayer);
        expect(tileLayerFinder, findsOneWidget);
        final tileLayer = tester.widget<TileLayer>(tileLayerFinder);
        expect(tileLayer.tileBuilder, isNull);

        // 3. No docked sheet on default view
        expect(find.byType(DraggableScrollableSheet), findsNothing);

        // 4. Inside the Expanded containing the Stack, children are:
        // FlutterMap and Positioned (controls).
        final expandedFinder = find.byWidgetPredicate(
          (w) => w is Expanded && w.child is Stack,
        );
        expect(expandedFinder, findsOneWidget);
        final expanded = tester.widget<Expanded>(expandedFinder);
        final stack = expanded.child as Stack;
        expect(stack.children.length, equals(2));
        expect(stack.children[0], isA<FlutterMap>());
        expect(stack.children[1], isA<Positioned>());
      },
    );
  });

  group('Pure Logic: extractBelumList & extractTemuanItems', () {
    const loc1 = PosLocation(
      posId: 'POS-01',
      posName: 'Pos Pasar Bersehati',
      cabangName: 'KC Manado',
      fullAddress: 'Jl. Nusantara 1',
      locationTag: 'PBM',
      tagColor: Colors.blue,
      lat: 1.48,
      lng: 124.84,
    );

    const loc2 = PosLocation(
      posId: 'POS-02',
      posName: 'Pos Toko Bintang',
      cabangName: 'KC Manado',
      fullAddress: 'Jl. Sam Ratulangi 2',
      locationTag: 'TBM',
      tagColor: Colors.orange,
      lat: 1.47,
      lng: 124.83,
    );

    final fixedNow = DateTime(2026, 11, 3); // Phase 1 (tgl 1-7)

    test('extractBelumList excludes POS done in current phase and includes unfinished POS', () {
      const logP1 = MaintenanceLogEntry(
        id: 'log-01',
        tanggal: '2026-11-02',
        jamSelesai: '10:00',
        posId: 'POS-01',
        posName: 'Pos Pasar Bersehati',
        teknisiNama: 'Budi',
        templateId: 'tpl_maint_manless',
        totalPoin: 10,
        sesuaiPoin: 10,
        temuan: [],
      );

      const statusDone = PosMaintenanceStatus(
        location: loc1,
        wilayah: 'Manado',
        logs: [logP1],
      );

      const statusNotDone = PosMaintenanceStatus(
        location: loc2,
        wilayah: 'Manado',
        logs: [],
      );

      final belumList = MaintenanceMapScreen.extractBelumList(
        statuses: [statusDone, statusNotDone],
        isCurrentMonth: true,
        now: fixedNow,
      );

      expect(belumList.length, equals(1));
      expect(belumList.first.location.posId, equals('POS-02'));
    });

    test('extractTemuanItems extracts findings and sorts urgent first, then status, then date', () {
      const status1 = PosMaintenanceStatus(
        location: loc1,
        wilayah: 'Manado',
        logs: [
          MaintenanceLogEntry(
            id: 'log-01',
            tanggal: '2026-11-01',
            jamSelesai: '09:00',
            posId: 'POS-01',
            posName: 'Pos Pasar Bersehati',
            teknisiNama: 'Budi',
            templateId: 'tpl_maint_manless',
            totalPoin: 10,
            sesuaiPoin: 8,
            temuan: [
              MaintenanceTemuan(
                label: 'Temuan Biasa Tanggal 1',
                status: 'tidak_sesuai',
                alasan: 'Kotor',
                urgent: false,
              ),
              MaintenanceTemuan(
                label: 'Temuan Urgent Tanggal 1',
                status: 'tidak_sesuai',
                alasan: 'Baut lepas',
                urgent: true,
              ),
              MaintenanceTemuan(
                label: 'Cek Manual Pengingat',
                status: 'perlu_cek_manual',
                alasan: 'Foto agak gelap',
                urgent: false,
              ),
            ],
          ),
        ],
      );

      const status2 = PosMaintenanceStatus(
        location: loc2,
        wilayah: 'Manado',
        logs: [
          MaintenanceLogEntry(
            id: 'log-02',
            tanggal: '2026-11-03',
            jamSelesai: '11:00',
            posId: 'POS-02',
            posName: 'Pos Toko Bintang',
            teknisiNama: 'Andi',
            templateId: 'tpl_maint_manless',
            totalPoin: 10,
            sesuaiPoin: 8,
            temuan: [
              MaintenanceTemuan(
                label: 'Temuan Biasa Tanggal 3',
                status: 'tidak_sesuai',
                alasan: 'Lampu mati',
                urgent: false,
              ),
            ],
          ),
        ],
      );

      final items = MaintenanceMapScreen.extractTemuanItems(
        statuses: [status1, status2],
        isCurrentMonth: true,
        selectedMonth: DateTime(2026, 11, 1),
        now: fixedNow,
      );

      expect(items.length, equals(3));
      // 1st: Urgent item
      expect(items[0].temuan.urgent, isTrue);
      expect(items[0].temuan.label, equals('Temuan Urgent Tanggal 1'));
      // 2nd: tidak_sesuai newer date (Nov 3 before Nov 1)
      expect(items[1].temuan.urgent, isFalse);
      expect(items[1].temuan.label, equals('Temuan Biasa Tanggal 3'));
      // 3rd: tidak_sesuai older date (Nov 1)
      expect(items[2].temuan.urgent, isFalse);
      expect(items[2].temuan.label, equals('Temuan Biasa Tanggal 1'));
    });

    test('pos whose only temuan is fixed is not counted as temuan marker and has isFixed: true', () {
      final fix = MaintenanceTemuanFix(
        id: 'fix-1',
        logId: 'log-01',
        temuanLabel: 'Temuan Sudah Dibereskan',
        posId: 'POS-01',
        posName: 'Pos Pasar Bersehati',
        branch: 'MDO',
        teknisiNama: 'Budi',
        catatan: 'Sudah diganti baut baru',
        photoUrls: ['https://example.com/p1.jpg'],
        fixedAt: DateTime(2026, 11, 2),
      );

      final log = MaintenanceLogEntry(
        id: 'log-01',
        tanggal: '2026-11-01',
        jamSelesai: '09:00',
        posId: 'POS-01',
        posName: 'Pos Pasar Bersehati',
        teknisiNama: 'Budi',
        templateId: 'tpl_maint_manless',
        totalPoin: 10,
        sesuaiPoin: 9,
        temuan: [
          MaintenanceTemuan(
            label: 'Temuan Sudah Dibereskan',
            status: 'tidak_sesuai',
            alasan: 'Baut kendor',
            urgent: false,
            fix: fix,
          ),
        ],
      );

      final status = PosMaintenanceStatus(
        location: loc1,
        wilayah: 'Manado',
        logs: [log],
      );

      // Log hasTemuan is false because the only temuan is fixed
      expect(log.hasTemuan, isFalse);
      expect(status.hasPhaseTemuan(1), isFalse);
      expect(status.statusForPhase(1), equals('selesai_aman'));

      final items = MaintenanceMapScreen.extractTemuanItems(
        statuses: [status],
        isCurrentMonth: true,
        selectedMonth: DateTime(2026, 11, 1),
        now: fixedNow,
      );

      expect(items.length, equals(1));
      expect(items.first.isFixed, isTrue);
      expect(items.first.temuan.isFixed, isTrue);
    });

    test('compareTemuanItems sorts unfixed findings before fixed findings', () {
      final fix = MaintenanceTemuanFix(
        id: 'fix-1',
        logId: 'log-01',
        temuanLabel: 'Temuan Fixed Urgent',
        posId: 'POS-01',
        posName: 'Pos Pasar Bersehati',
        branch: 'MDO',
        teknisiNama: 'Budi',
        catatan: 'Fixed',
        photoUrls: ['https://example.com/p.jpg'],
        fixedAt: DateTime(2026, 11, 2),
      );

      const unfixedLog = MaintenanceLogEntry(
        id: 'log-01',
        tanggal: '2026-11-01',
        jamSelesai: '09:00',
        posId: 'POS-01',
        posName: 'Pos Pasar Bersehati',
        teknisiNama: 'Budi',
        totalPoin: 10,
        sesuaiPoin: 9,
        temuan: [],
      );

      const unfixedItem = MaintenanceTemuanItem(
        status: PosMaintenanceStatus(location: loc1, wilayah: 'Manado'),
        log: unfixedLog,
        temuan: MaintenanceTemuan(
          label: 'Temuan Normal Unfixed',
          status: 'tidak_sesuai',
          alasan: 'Normal',
          urgent: false,
        ),
        phase: 1,
        isFixed: false,
      );

      final fixedItem = MaintenanceTemuanItem(
        status: const PosMaintenanceStatus(location: loc1, wilayah: 'Manado'),
        log: unfixedLog,
        temuan: MaintenanceTemuan(
          label: 'Temuan Fixed Urgent',
          status: 'tidak_sesuai',
          alasan: 'Urgent but fixed',
          urgent: true,
          fix: fix,
        ),
        phase: 1,
        isFixed: true,
      );

      // Unfixed must come before fixed
      expect(MaintenanceMapScreen.compareTemuanItems(unfixedItem, fixedItem), isNegative);
      expect(MaintenanceMapScreen.compareTemuanItems(fixedItem, unfixedItem), isPositive);
    });
  });

  group('MaintenanceBelumRow and MaintenanceTemuanRow at 320dp', () {
    testWidgets('renders MaintenanceBelumRow at 320dp without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const loc = PosLocation(
        posId: 'POS-BELUM',
        posName: 'Nama Lokasi Panjang Sekali Enam Puluh Karakter Manado Banget',
        cabangName: 'KC Manado',
        fullAddress: 'Jl. Hasanuddin No. 99 Calaca Wenang Manado Utara',
        locationTag: 'NLPS',
        tagColor: Colors.blue,
        lat: 1.48,
        lng: 124.83,
      );

      const status = PosMaintenanceStatus(
        location: loc,
        wilayah: 'Manado',
        logs: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: MaintenanceBelumRow(
                status: status,
                isCurrentMonth: true,
                selectedMonth: DateTime(2026, 11, 1),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(MaintenanceBelumRow), findsOneWidget);
      expect(find.text('NLPS'), findsOneWidget);
    });

    testWidgets('renders MaintenanceTemuanRow at 320dp without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const loc = PosLocation(
        posId: 'POS-TEMUAN',
        posName: 'Mie Gacoan Manado Megamas',
        cabangName: 'KC Manado',
        fullAddress: 'Kawasan Megamas Blok A Manado',
        locationTag: 'GMM',
        tagColor: Colors.orange,
        lat: 1.48,
        lng: 124.83,
      );

      const log = MaintenanceLogEntry(
        id: 'log-t-01',
        tanggal: '2026-11-03',
        jamSelesai: '14:20',
        posId: 'POS-TEMUAN',
        posName: 'Mie Gacoan Manado Megamas',
        teknisiNama: 'Teknisi Sangat Panjang Namanya Sekali',
        templateId: 'tpl_maint_manless',
        totalPoin: 12,
        sesuaiPoin: 10,
        temuan: [
          MaintenanceTemuan(
            label: 'Dudukan Bawah Manless ke Pulau Patah dan Berkarat Berat',
            status: 'tidak_sesuai',
            alasan: 'Perlu diganti plat besi dan dibaut ulang segera',
            urgent: true,
          ),
        ],
      );

      const status = PosMaintenanceStatus(
        location: loc,
        wilayah: 'Manado',
        logs: [log],
      );

      final item = MaintenanceTemuanItem(
        status: status,
        log: log,
        temuan: log.temuan.first,
        phase: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: MaintenanceTemuanRow(
                item: item,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(MaintenanceTemuanRow), findsOneWidget);
      expect(find.text('Urgent'), findsOneWidget);
      expect(find.text(item.temuan.label), findsOneWidget);
    });
  });

  group('MaintenanceMapScreen 360x780 Sheet Visibility & A11y Tests', () {
    testWidgets(
      'month switcher does not overflow at 360dp width with textScaler 1.3',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(360, 780),
                textScaler: TextScaler.linear(1.3),
              ),
              child: MaintenanceMapScreen(),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.calendar_today_rounded), findsOneWidget);
        expect(find.byIcon(Icons.chevron_left), findsOneWidget);
        expect(find.bySemanticsLabel('Bulan berikutnya'), findsOneWidget);
      },
    );

    testWidgets(
      'MaintenanceBelumRow and MaintenanceTemuanRow do not overflow at textScaler 1.3 on 360dp width',
      (tester) async {
        const loc = PosLocation(
          posId: 'POS-TEST',
          posName: 'Gedung Keuangan Negara (GKN) Manado',
          cabangName: 'KC Manado',
          fullAddress: 'Jl. Sam Ratulangi No. 1 Manado',
          locationTag: 'GKN',
          tagColor: Colors.blue,
          lat: 1.4880,
          lng: 124.8420,
        );

        const log = MaintenanceLogEntry(
          id: 'log-1',
          tanggal: '2026-11-02',
          jamSelesai: '10:00',
          posId: 'POS-TEST',
          posName: 'Gedung Keuangan Negara (GKN) Manado',
          teknisiNama: 'Petugas 1',
          templateId: 'tpl_maint_pos',
          totalPoin: 10,
          sesuaiPoin: 8,
          temuan: [
            MaintenanceTemuan(
              label: 'Motor penggerak palang pintu berbunyi kasar',
              status: 'tidak_sesuai',
              alasan: 'Perlu diganti plat besi dan dibaut ulang',
              urgent: true,
            ),
          ],
        );

        const status = PosMaintenanceStatus(
          location: loc,
          wilayah: 'Manado',
          logs: [],
        );

        final temuanItem = MaintenanceTemuanItem(
          status: const PosMaintenanceStatus(
            location: loc,
            wilayah: 'Manado',
            logs: [log],
          ),
          log: log,
          temuan: log.temuan.first,
          phase: 1,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.3),
              ),
              child: Scaffold(
                body: SizedBox(
                  width: 360,
                  child: Column(
                    children: [
                      MaintenanceBelumRow(
                        status: status,
                        isCurrentMonth: true,
                        selectedMonth: DateTime(2026, 11, 1),
                      ),
                      MaintenanceTemuanRow(
                        item: temuanItem,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(MaintenanceBelumRow), findsOneWidget);
        expect(find.byType(MaintenanceTemuanRow), findsOneWidget);
      },
    );

    testWidgets(
      'renders full MaintenanceMapScreen at 360x640 with textScaler 1.0 without RenderFlex overflow',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(360, 640),
                textScaler: TextScaler.linear(1.0),
              ),
              child: MaintenanceMapScreen(),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.byType(MaintenanceMapScreen), findsOneWidget);
        expect(find.byType(FlutterMap), findsOneWidget);
      },
    );

    testWidgets(
      'renders full MaintenanceMapScreen at 360x640 with textScaler 1.3 without RenderFlex overflow',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(360, 640),
                textScaler: TextScaler.linear(1.3),
              ),
              child: MaintenanceMapScreen(),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.byType(MaintenanceMapScreen), findsOneWidget);
        expect(find.byType(FlutterMap), findsOneWidget);
      },
    );

    testWidgets(
      'asserts semantics labels exist on month switcher and markers',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: MaintenanceMapScreen(),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Month switcher 'Bulan berikutnya' semantics
        final nextMonthSemantics = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Bulan berikutnya',
        );
        expect(nextMonthSemantics, findsOneWidget);

        // Marker semantics exists
        final markerSemantics = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              ((w.properties.label?.contains('lokasi') ?? false) ||
               (w.properties.label?.contains('temuan') ?? false) ||
               (w.properties.label?.contains('belum') ?? false)),
        );
        expect(markerSemantics, findsWidgets);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  });

  group('Map Maintenance UX V3: Badges, Location Sheet & Screenshots', () {
    final now = DateTime.now();
    final currentTemplate =
        MaintenanceLogService.phaseTemplates[MaintenanceLogService.phaseForDate(now)] ??
            'tpl_maint_manless';

    final testSubmissions = [
      MaintenanceSubmission(
        id: 'sub-aan-pbm-01',
        posId: 'POS-PBM-01',
        posName: 'Pasar Bersehati Manado',
        cabangName: 'KC BSG',
        userId: 'tech-01',
        userName: 'Junifer Mamahit',
        userNpp: 'NPP-101',
        templateId: currentTemplate,
        templateName: 'Manless Gate',
        createdAt: now,
        updatedAt: now,
        points: const [
          MaintenancePointResult(
            pointId: 'manless_dudukan',
            label: 'Manless 3 - Dudukan Bawah Manless kanan',
            status: PointStatus.tidakSesuai,
            alasan:
                'Baut dudukan bawah sisi kanan hilang dan plat penahan longgar sehingga manless goyang',
            urgensi: TingkatUrgensi.urgent,
          ),
          MaintenancePointResult(
            pointId: 'manless_kabel',
            label: 'Manless 1 (PEP) - Kebersihan & Kerapian Kabel',
            status: PointStatus.tidakSesuai,
            alasan:
                'Kabel di dalam manless belum tertata rapi dan sebagian terlepas dari klem',
            urgensi: TingkatUrgensi.normal,
          ),
          MaintenancePointResult(
            pointId: 'manless_sensor',
            label: 'Manless 2 - Sensor Loop',
            status: PointStatus.tidakSesuai,
            alasan: 'Deteksi loop kendaraan tidak stabil',
            urgensi: TingkatUrgensi.normal,
          ),
          MaintenancePointResult(
            pointId: 'manless_printer',
            label: 'Printer Tiket',
            status: PointStatus.tidakSesuai,
            alasan: 'Kertas agak macet saat cetak',
            urgensi: TingkatUrgensi.normal,
          ),
        ],
      ),
      MaintenanceSubmission(
        id: 'sub-aan-pkm-01',
        posId: 'POS-PKM-01',
        posName: 'Pelabuhan Kalimas Manado',
        cabangName: 'KC BSG',
        userId: 'tech-01',
        userName: 'Junifer Mamahit',
        userNpp: 'NPP-101',
        templateId: currentTemplate,
        templateName: 'Manless Gate',
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
        points: const [
          MaintenancePointResult(
            pointId: 'barrier_palang',
            label: 'Palang Pintu Masuk',
            status: PointStatus.tidakSesuai,
            alasan: 'Karet pelindung robek',
            urgensi: TingkatUrgensi.normal,
          ),
        ],
      ),
    ];

    setUp(() async {
      await loadAppFonts();
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (methodCall) async => '.',
          );
      await StorageService.init();
      await StorageService.saveMaintenanceSubmissions(testSubmissions);
    });

    // (a) default render has no Temuan/Belum tab
    testWidgets(
      'default render has no Temuan/Belum tab and fills with map',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: MaintenanceMapScreen(),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // No docked sheet or tabs
        expect(find.byType(Tab), findsNothing);
        expect(find.textContaining('Belum ('), findsNothing);
        expect(find.byType(DraggableScrollableSheet), findsNothing);

        // Header, filters, summary strip and map present
        expect(find.text('Map Maintenance'), findsOneWidget);
        expect(find.text('Semua'), findsOneWidget);
        expect(find.text('Temuan'), findsOneWidget);
        expect(find.byType(FlutterMap), findsOneWidget);

        // Map controls present
        expect(find.byTooltip('Pusatkan Peta'), findsOneWidget);
        expect(find.byTooltip('Perbesar'), findsOneWidget);
        expect(find.byTooltip('Perkecil'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    // (b) PBM marker shows badge '4' red when one urgent
    testWidgets(
      'PBM marker shows badge "4" red when one urgent',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mapController = MapController();
        await tester.pumpWidget(
          MaterialApp(
            home: MaintenanceMapScreen(mapController: mapController),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Zoom to separate PBM
        mapController.move(const LatLng(1.49807, 124.84157), 16.5);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Semantics on marker includes urgent indicator
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                (w.properties.label?.contains('PBM, 4 temuan, ada urgent') ??
                    false),
          ),
          findsOneWidget,
        );

        // Find badge displaying '4'
        final badgeText = find.text('4');
        expect(badgeText, findsOneWidget);

        final containerFinder = find.ancestor(
          of: badgeText,
          matching: find.byType(Container),
        );
        final container = tester.widget<Container>(containerFinder.first);
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, const Color(0xFFDC2626));

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    // (c) cluster badge equals sum
    testWidgets(
      'cluster badge equals sum of child locations (4 + 1 = 5) and is red if any urgent',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mapController = MapController();
        await tester.pumpWidget(
          MaterialApp(
            home: MaintenanceMapScreen(mapController: mapController),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Zoom out so PBM (4), PKM (1), and NBM (0) cluster into one
        mapController.move(const LatLng(1.496, 124.841), 13.0);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Location count bubble shows '3'
        expect(find.text('3'), findsOneWidget);

        // Cluster notification badge shows '5'
        final clusterBadge = find.text('5');
        expect(clusterBadge, findsOneWidget);

        final badgeContainerFinder = find.ancestor(
          of: clusterBadge,
          matching: find.byType(Container),
        );
        final badgeContainer =
            tester.widget<Container>(badgeContainerFinder.first);
        final decoration = badgeContainer.decoration as BoxDecoration;
        expect(decoration.color, const Color(0xFFDC2626));

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    // (d) tapping a location marker pushes MaintenanceLocationDetailScreen directly
    testWidgets(
      'tapping a location marker pushes MaintenanceLocationDetailScreen directly without bottom sheet',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mapController = MapController();
        await tester.pumpWidget(
          MaterialApp(
            home: MaintenanceMapScreen(mapController: mapController),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        mapController.move(const LatLng(1.49807, 124.84157), 16.5);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Tap PBM marker
        final pbmFinder = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.label?.contains('PBM, 4 temuan') ?? false),
        );
        expect(pbmFinder, findsOneWidget);
        await tester.tap(pbmFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // No BottomSheet shown
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(DraggableScrollableSheet), findsNothing);

        // Pushed MaintenanceLocationDetailScreen directly
        expect(find.byType(MaintenanceLocationDetailScreen), findsOneWidget);

        // Pop back to map
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();

        // Back on map screen, detail screen popped
        expect(find.byType(MaintenanceLocationDetailScreen), findsNothing);
        expect(find.byType(MaintenanceMapScreen), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    // (e) tapping a 0-temuan belum location pushes MaintenanceLocationDetailScreen directly
    testWidgets(
      'tapping a 0-temuan belum location pushes MaintenanceLocationDetailScreen directly',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mapController = MapController();
        await tester.pumpWidget(
          MaterialApp(
            home: MaintenanceMapScreen(mapController: mapController),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Zoom in to NBM
        mapController.move(const LatLng(1.49344, 124.84161), 16.5);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Tap NBM marker
        final nbmFinder = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.label?.contains('NBM, belum dikerjakan') ?? false),
        );
        expect(nbmFinder, findsOneWidget);
        await tester.tap(nbmFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(DraggableScrollableSheet), findsNothing);
        expect(find.byType(MaintenanceLocationDetailScreen), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    // (f) '9+' cap
    testWidgets(
      'badge caps count at "9+" when count > 9',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Seed NBM with 10 temuan
        final points10 = List.generate(
          10,
          (i) => MaintenancePointResult(
            pointId: 'point_$i',
            label: 'Manless item $i',
            status: PointStatus.tidakSesuai,
            alasan: 'Alasan pemeriksaan $i',
            urgensi: TingkatUrgensi.normal,
          ),
        );

        final submission10 = MaintenanceSubmission(
          id: 'sub-nbm-10',
          posId: 'POS-NBM-01',
          posName: 'New Bendar Manado',
          cabangName: 'KC BSG',
          userId: 'tech-01',
          userName: 'Junifer Mamahit',
          userNpp: 'NPP-101',
          templateId: currentTemplate,
          templateName: 'Manless Gate',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          points: points10,
        );

        await StorageService.saveMaintenanceSubmissions([
          ...testSubmissions,
          submission10,
        ]);

        final mapController = MapController();
        await tester.pumpWidget(
          MaterialApp(
            home: MaintenanceMapScreen(mapController: mapController),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        mapController.move(const LatLng(1.49344, 124.84161), 16.5);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Badge shows '9+'
        expect(find.text('9+'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    // Map controls test
    testWidgets(
      'Map controls: zoom pill and recenter button function correctly',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mapController = MapController();
        await tester.pumpWidget(
          MaterialApp(
            home: MaintenanceMapScreen(mapController: mapController),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Controls exist
        expect(find.byTooltip('Pusatkan Peta'), findsOneWidget);
        expect(find.byTooltip('Perbesar'), findsOneWidget);
        expect(find.byTooltip('Perkecil'), findsOneWidget);

        final initialZoom = mapController.camera.zoom;
        await tester.tap(find.byTooltip('Perbesar'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(mapController.camera.zoom, greaterThan(initialZoom));

        await tester.tap(find.byTooltip('Perkecil'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    // Screenshots generation test
    testWidgets(
      'generates required screenshots: maintenance_map_stats.png and maintenance_map_wilayah_dialog.png (both default and _ts13)',
      (tester) async {
        tester.view.physicalSize = const Size(720, 1560);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fileStats = File('docs/screenshots/maintenance_map_stats.png');
        final fileStatsTs13 =
            File('docs/screenshots/maintenance_map_stats_ts13.png');
        final fileDialog =
            File('docs/screenshots/maintenance_map_wilayah_dialog.png');
        final fileDialogTs13 =
            File('docs/screenshots/maintenance_map_wilayah_dialog_ts13.png');

        final origStats = fileStats.existsSync() ? fileStats.readAsBytesSync() : null;
        final origStatsTs13 = fileStatsTs13.existsSync() ? fileStatsTs13.readAsBytesSync() : null;
        final origDialog = fileDialog.existsSync() ? fileDialog.readAsBytesSync() : null;
        final origDialogTs13 = fileDialogTs13.existsSync() ? fileDialogTs13.readAsBytesSync() : null;

        addTearDown(() {
          if (origStats != null) {
            fileStats.writeAsBytesSync(origStats);
          } else if (fileStats.existsSync()) {
            fileStats.deleteSync();
          }
          if (origStatsTs13 != null) {
            fileStatsTs13.writeAsBytesSync(origStatsTs13);
          } else if (fileStatsTs13.existsSync()) {
            fileStatsTs13.deleteSync();
          }
          if (origDialog != null) {
            fileDialog.writeAsBytesSync(origDialog);
          } else if (fileDialog.existsSync()) {
            fileDialog.deleteSync();
          }
          if (origDialogTs13 != null) {
            fileDialogTs13.writeAsBytesSync(origDialogTs13);
          } else if (fileDialogTs13.existsSync()) {
            fileDialogTs13.deleteSync();
          }
        });

        fileStats.parent.createSync(recursive: true);

        // --- 1. Default scale (1.0) ---
        final repaintKey1 = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: 'Figtree',
              useMaterial3: true,
            ),
            builder: (context, child) => RepaintBoundary(
              key: repaintKey1,
              child: child!,
            ),
            home: const MaintenanceMapScreen(),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Select 'Temuan' stat tile
        await tester.tap(find.text('Temuan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Capture stats screenshot
        final boundaryStats =
            repaintKey1.currentContext!.findRenderObject() as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundaryStats.toImage(pixelRatio: 2.0);
          final byteData =
              await image.toByteData(format: ui.ImageByteFormat.png);
          fileStats.writeAsBytesSync(byteData!.buffer.asUint8List());
        });

        // Tap wilayah pill to open dialog
        final wilayahPill1 = find.bySemanticsLabel(RegExp(r'Filter wilayah'));
        await tester.tap(wilayahPill1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(Dialog), findsOneWidget);

        // Capture dialog screenshot
        final boundaryDialog =
            repaintKey1.currentContext!.findRenderObject() as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundaryDialog.toImage(pixelRatio: 2.0);
          final byteData =
              await image.toByteData(format: ui.ImageByteFormat.png);
          fileDialog.writeAsBytesSync(byteData!.buffer.asUint8List());
        });

        // Close dialog and clean up tree
        await tester.tap(find.byTooltip('Tutup'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpWidget(const SizedBox());
        await tester.pump();

        // --- 2. TextScaler 1.3 ---
        final repaintKey2 = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: 'Figtree',
              useMaterial3: true,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.3),
              ),
              child: RepaintBoundary(
                key: repaintKey2,
                child: child!,
              ),
            ),
            home: const MaintenanceMapScreen(),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Select 'Temuan' stat tile
        await tester.tap(find.text('Temuan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final boundaryStatsTs13 =
            repaintKey2.currentContext!.findRenderObject() as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundaryStatsTs13.toImage(pixelRatio: 2.0);
          final byteData =
              await image.toByteData(format: ui.ImageByteFormat.png);
          fileStatsTs13.writeAsBytesSync(byteData!.buffer.asUint8List());
        });

        // Tap wilayah pill to open dialog
        final wilayahPill2 = find.bySemanticsLabel(RegExp(r'Filter wilayah'));
        await tester.tap(wilayahPill2);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(Dialog), findsOneWidget);

        final boundaryDialogTs13 =
            repaintKey2.currentContext!.findRenderObject() as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundaryDialogTs13.toImage(pixelRatio: 2.0);
          final byteData =
              await image.toByteData(format: ui.ImageByteFormat.png);
          fileDialogTs13.writeAsBytesSync(byteData!.buffer.asUint8List());
        });

        await tester.tap(find.byTooltip('Tutup'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpWidget(const SizedBox());
        await tester.pump();

        expect(fileStats.existsSync(), isTrue);
        expect(fileStats.lengthSync(), greaterThan(1000));
        expect(fileStatsTs13.existsSync(), isTrue);
        expect(fileStatsTs13.lengthSync(), greaterThan(1000));
        expect(fileDialog.existsSync(), isTrue);
        expect(fileDialog.lengthSync(), greaterThan(1000));
        expect(fileDialogTs13.existsSync(), isTrue);
        expect(fileDialogTs13.lengthSync(), greaterThan(1000));

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  });

  group('MaintenanceMapScreen: Wilayah Modal & Status Filter', () {
    final now = DateTime.now();

    final testSubmissions = [
      MaintenanceSubmission(
        id: 'sub-aan-pbm-01',
        posId: 'POS-PBM-01',
        posName: 'Pasar Bersehati Manado',
        cabangName: 'KC BSG',
        userId: 'tech-01',
        userName: 'Junifer Mamahit',
        userNpp: 'NPP-101',
        templateId: 'tpl_maint_manless',
        templateName: 'Manless Gate',
        createdAt: now,
        updatedAt: now,
        points: const [
          MaintenancePointResult(
            pointId: 'manless_dudukan',
            label: 'Manless 3 - Dudukan Bawah Manless kanan',
            status: PointStatus.tidakSesuai,
            alasan: 'Baut dudukan lepas',
            urgensi: TingkatUrgensi.urgent,
          ),
        ],
      ),
    ];

    setUp(() async {
      await loadAppFonts();
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (methodCall) async => '.',
          );
      await StorageService.init();
      await StorageService.saveMaintenanceSubmissions(testSubmissions);
    });

    testWidgets(
      '(a) top bar contains a wilayah pill trigger and no DropdownButton; tapping opens modal dialog and selecting wilayah updates visible markers',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: MaintenanceMapScreen(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // No DropdownButton exists anywhere in the widget tree
        expect(find.byType(DropdownButton<String>), findsNothing);
        expect(find.byType(ListView), findsNothing);

        final initialMarkers = tester
            .widget<MarkerLayer>(find.byType(MarkerLayer))
            .markers
            .length;
        expect(initialMarkers, greaterThan(0));

        // Tap wilayah pill to open dialog
        final wilayahPill = find.bySemanticsLabel(RegExp(r'Filter wilayah'));
        expect(wilayahPill, findsOneWidget);
        await tester.tap(wilayahPill);
        await tester.pumpAndSettle();

        // Dialog is open with title 'Pilih wilayah'
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.text('Pilih wilayah'), findsOneWidget);

        // Select the first non-'Semua' wilayah item (e.g. 'Airmadidi')
        final itemFinder = find.text('Airmadidi');
        if (itemFinder.evaluate().isNotEmpty) {
          await tester.tap(itemFinder.first);
        } else {
          final dialogRows = find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(InkWell),
          );
          await tester.tap(dialogRows.at(1));
        }
        await tester.pumpAndSettle();

        // Dialog is closed
        expect(find.byType(Dialog), findsNothing);

        final filteredMarkers = tester
            .widget<MarkerLayer>(find.byType(MarkerLayer))
            .markers
            .length;
        expect(filteredMarkers, lessThan(initialMarkers));

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets(
      '(b) tapping the Belum stat tile leaves only rank-0 markers and stat counts text stays identical; tapping again restores all',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: MaintenanceMapScreen(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final allMarkers = tester
            .widget<MarkerLayer>(find.byType(MarkerLayer))
            .markers
            .length;

        // Find the Belum stat tile
        final belumLabel = find.text('Belum');
        expect(belumLabel, findsOneWidget);

        final belumSemanticsFinder = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.label?.contains('Belum saja') ?? false),
        );
        expect(belumSemanticsFinder, findsOneWidget);
        final initialLabel =
            tester.widget<Semantics>(belumSemanticsFinder).properties.label;

        // Tap the Belum tile
        await tester.tap(belumLabel);
        await tester.pumpAndSettle();

        // Markers now filtered to rank 0 (Belum only)
        final belumMarkers = tester
            .widget<MarkerLayer>(find.byType(MarkerLayer))
            .markers
            .length;
        expect(belumMarkers, lessThanOrEqualTo(allMarkers));

        // Stat counts text must stay identical (counts do not collapse)
        final afterFilterLabel =
            tester.widget<Semantics>(belumSemanticsFinder).properties.label;
        expect(afterFilterLabel, equals(initialLabel));

        // Tap again to restore
        await tester.tap(belumLabel);
        await tester.pumpAndSettle();

        final restoredMarkers = tester
            .widget<MarkerLayer>(find.byType(MarkerLayer))
            .markers
            .length;
        expect(restoredMarkers, equals(allMarkers));

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets(
      '(c) empty state text and Tampilkan semua appears when the selected status has 0 matches',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: MaintenanceMapScreen(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final chips = ['Belum', 'Ada temuan', 'Aman'];
        String? zeroTile;
        for (final chip in chips) {
          final semanticsFinder = find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                (w.properties.label?.contains('$chip saja') ?? false),
          );
          if (semanticsFinder.evaluate().isNotEmpty) {
            final sem = tester.widget<Semantics>(semanticsFinder);
            if (sem.properties.label?.contains('lokasi 0 ') ?? false) {
              zeroTile = chip;
              break;
            }
          }
        }

        if (zeroTile != null) {
          await tester.tap(find.text(zeroTile));
          await tester.pumpAndSettle();
        } else {
          // Open wilayah dialog to select Airmadidi (1 pos)
          final wilayahPill = find.bySemanticsLabel(RegExp(r'Filter wilayah'));
          await tester.tap(wilayahPill);
          await tester.pumpAndSettle();

          final airmadidiItem = find.text('Airmadidi');
          if (airmadidiItem.evaluate().isNotEmpty) {
            await tester.tap(airmadidiItem.first);
            await tester.pumpAndSettle();
          }

          for (final chip in chips) {
            final semanticsFinder = find.byWidgetPredicate(
              (w) =>
                  w is Semantics &&
                  (w.properties.label?.contains('$chip saja') ?? false),
            );
            if (semanticsFinder.evaluate().isNotEmpty) {
              final sem = tester.widget<Semantics>(semanticsFinder);
              if (sem.properties.label?.contains('lokasi 0 ') ?? false) {
                zeroTile = chip;
                break;
              }
            }
          }
          if (zeroTile != null) {
            await tester.tap(find.text(zeroTile));
            await tester.pumpAndSettle();
          }
        }

        expect(find.textContaining('Tidak ada lokasi'), findsOneWidget);
        expect(find.text('Tampilkan semua'), findsOneWidget);

        // Tap 'Tampilkan semua' clears status filter
        await tester.tap(find.text('Tampilkan semua'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Tidak ada lokasi'), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets(
      'branch bali with 0 locations renders without exception and shows 0/0 lokasi',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await BranchService.instance.setBranch(AppBranch.bali);
        addTearDown(() => BranchService.instance.resetForTesting());

        final manadoOnly = LocationService.getLocationsByBranch(AppBranch.manado);
        await StorageService.saveLocations(manadoOnly);
        await StorageService.setLocationSyncedRemote(true);
        LocationService.resetForTesting();
        addTearDown(() => LocationService.resetForTesting());

        await tester.pumpWidget(
          const MaterialApp(
            home: MaintenanceMapScreen(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('0/0 lokasi'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  });
}
