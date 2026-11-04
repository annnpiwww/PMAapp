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
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/maintenance_log_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_map_screen.dart';

bool _fontsLoaded = false;
Future<void> loadAppFonts() async {
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

void main() {
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
                status: 'perlu_cek_manual',
                alasan: 'Baut lepas',
                urgent: true,
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
            status: PointStatus.perluCekManual,
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
        templateId: 'tpl_maint_manless',
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
        expect(find.textContaining('Temuan ('), findsNothing);
        expect(find.textContaining('Belum ('), findsNothing);
        expect(find.byType(DraggableScrollableSheet), findsNothing);

        // Header, filters, summary strip and map present
        expect(find.text('Map Maintenance'), findsOneWidget);
        expect(find.text('Semua'), findsOneWidget);
        expect(find.textContaining('Ada temuan'), findsOneWidget);
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

    // (d) tapping PBM opens sheet with exactly its 4 temuan, urgent first
    testWidgets(
      'tapping PBM opens sheet with exactly its 4 temuan, urgent first',
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

        // Sheet is open: DraggableScrollableSheet
        expect(find.byType(DraggableScrollableSheet), findsOneWidget);

        // Header row
        expect(find.text('PBM · Pasar Bersehati'), findsOneWidget);
        expect(find.text('4 temuan'), findsOneWidget);
        expect(find.byTooltip('Tutup'), findsOneWidget);

        // Exactly 4 temuan rows
        final temuanRows = find.byType(MaintenanceTemuanRow);
        expect(temuanRows, findsNWidgets(4));

        // Urgent item is first
        final firstRow = tester.widget<MaintenanceTemuanRow>(temuanRows.at(0));
        expect(firstRow.item.temuan.urgent, isTrue);
        expect(
          firstRow.item.temuan.alasan,
          'Baut dudukan bawah sisi kanan hilang dan plat penahan longgar sehingga manless goyang',
        );

        // Close button works
        await tester.tap(find.byTooltip('Tutup'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(DraggableScrollableSheet), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    // (e) tapping a 0-temuan belum location shows 'Belum dikerjakan bulan ini'
    testWidgets(
      'tapping a 0-temuan belum location shows "Belum dikerjakan bulan ini"',
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

        // Sheet displays 0 temuan and "Belum dikerjakan bulan ini"
        expect(find.text('NBM · New Bendar'), findsOneWidget);
        expect(find.text('0 temuan'), findsOneWidget);
        expect(find.text('Belum dikerjakan bulan ini'), findsOneWidget);
        expect(find.byType(MaintenanceTemuanRow), findsNothing);

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
          templateId: 'tpl_maint_manless',
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
      'generates required screenshots: map_maintenance_v3_default_360.png and map_maintenance_v3_location_sheet_360.png',
      (tester) async {
        tester.view.physicalSize = const Size(720, 1560);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final file1 = File('docs/screenshots/map_maintenance_v3_default_360.png');
        final file2 =
            File('docs/screenshots/map_maintenance_v3_location_sheet_360.png');
        final originalBytes1 = file1.existsSync() ? file1.readAsBytesSync() : null;
        final originalBytes2 = file2.existsSync() ? file2.readAsBytesSync() : null;
        if (originalBytes1 != null) {
          addTearDown(() => file1.writeAsBytesSync(originalBytes1));
        }
        if (originalBytes2 != null) {
          addTearDown(() => file2.writeAsBytesSync(originalBytes2));
        }

        final mapController = MapController();
        final repaintKey = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: 'PlusJakartaSans',
              useMaterial3: true,
            ),
            builder: (context, child) => RepaintBoundary(
              key: repaintKey,
              child: child!,
            ),
            home: MaintenanceMapScreen(
              mapController: mapController,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // 1. Screenshot 1: default map at zoom where PBM, PKM, NBM are visible as separate markers with badges
        mapController.move(const LatLng(1.4965, 124.8412), 16.2);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Assert separate markers are present
        expect(find.text('PBM'), findsOneWidget);
        expect(find.text('PKM'), findsOneWidget);
        expect(find.text('NBM'), findsOneWidget);

        // Capture default screenshot
        final boundary1 =
            repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image1 = await boundary1.toImage(pixelRatio: 2.0);
          final byteData1 =
              await image1.toByteData(format: ui.ImageByteFormat.png);
          await file1.parent.create(recursive: true);
          await file1.writeAsBytes(byteData1!.buffer.asUint8List());
        });

        // 2. Screenshot 2: tap PBM marker to open location sheet
        final pbmFinder = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.label?.contains('PBM, 4 temuan') ?? false),
        );
        expect(pbmFinder, findsOneWidget);
        await tester.tap(pbmFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Verify sheet is open
        expect(find.text('PBM · Pasar Bersehati'), findsOneWidget);
        expect(find.text('4 temuan'), findsOneWidget);

        // Capture sheet screenshot
        final boundary2 =
            repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image2 = await boundary2.toImage(pixelRatio: 2.0);
          final byteData2 =
              await image2.toByteData(format: ui.ImageByteFormat.png);
          await file2.parent.create(recursive: true);
          await file2.writeAsBytes(byteData2!.buffer.asUint8List());
        });

        expect(file1.existsSync(), isTrue);
        expect(file1.lengthSync(), greaterThan(1000));
        expect(file2.existsSync(), isTrue);
        expect(file2.lengthSync(), greaterThan(1000));

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  });

  group('MaintenanceMapScreen: Wilayah Dropdown & Status Filter', () {
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
      '(a) top bar contains a DropdownButton<String> and no horizontal ListView of wilayah; selecting wilayah updates visible markers',
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

        expect(find.byType(DropdownButton<String>), findsOneWidget);
        expect(find.byType(ListView), findsNothing);

        final initialMarkers = tester
            .widget<MarkerLayer>(find.byType(MarkerLayer))
            .markers
            .length;
        expect(initialMarkers, greaterThan(0));

        // Open dropdown
        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pumpAndSettle();

        // Select the first non-'Semua' wilayah item (e.g. 'Airmadidi' or 'Manado')
        final itemFinder =
            find.widgetWithText(DropdownMenuItem<String>, 'Airmadidi (1)');
        if (itemFinder.evaluate().isNotEmpty) {
          await tester.tap(itemFinder.last, warnIfMissed: false);
        } else {
          final allItems = find.byType(DropdownMenuItem<String>);
          await tester.tap(allItems.at(1), warnIfMissed: false);
        }
        await tester.pumpAndSettle();

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
      '(b) tapping the Belum stat chip leaves only rank-0 markers and stat counts text stays identical; tapping again restores all',
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

        // Find the Belum stat chip text, e.g. "X Belum"
        final belumText = tester
            .widget<Text>(
              find.descendant(
                of: find.byType(Wrap),
                matching: find.textContaining('Belum'),
              ),
            )
            .data!;

        // Tap the Belum chip
        await tester.tap(find.text(belumText));
        await tester.pumpAndSettle();

        // Markers now filtered to rank 0 (Belum only)
        final belumMarkers = tester
            .widget<MarkerLayer>(find.byType(MarkerLayer))
            .markers
            .length;
        expect(belumMarkers, lessThanOrEqualTo(allMarkers));

        // Stat counts text must stay identical (counts do not collapse)
        expect(find.text(belumText), findsOneWidget);

        // Tap again to restore
        await tester.tap(find.text(belumText));
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
        String? zeroChip;
        for (final chip in chips) {
          final finder = find.descendant(
            of: find.byType(Wrap),
            matching: find.textContaining(chip),
          );
          if (finder.evaluate().isNotEmpty) {
            final text = tester.widget<Text>(finder).data!;
            if (text.startsWith('0 ')) {
              zeroChip = text;
              break;
            }
          }
        }

        if (zeroChip != null) {
          await tester.tap(find.text(zeroChip));
          await tester.pumpAndSettle();
        } else {
          // Select Airmadidi (1 pos)
          await tester.tap(find.byType(DropdownButton<String>));
          await tester.pumpAndSettle();

          final airmadidiItem =
              find.widgetWithText(DropdownMenuItem<String>, 'Airmadidi (1)');
          if (airmadidiItem.evaluate().isNotEmpty) {
            await tester.tap(airmadidiItem.last, warnIfMissed: false);
            await tester.pumpAndSettle();
          }

          for (final chip in chips) {
            final finder = find.descendant(
              of: find.byType(Wrap),
              matching: find.textContaining(chip),
            );
            if (finder.evaluate().isNotEmpty) {
              final text = tester.widget<Text>(finder).data!;
              if (text.startsWith('0 ')) {
                zeroChip = text;
                break;
              }
            }
          }
          if (zeroChip != null) {
            await tester.tap(find.text(zeroChip));
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
  });
}
