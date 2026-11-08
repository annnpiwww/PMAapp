import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/maintenance_log_service.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_location_detail_screen.dart';

void main() {
  group('MaintenanceLocationDetailScreen Widget Tests', () {
    testWidgets(
      'renders 3 / 5, Temuan (2), and Urgent badge before Perlu cek when one phase-1 log exists',
      (tester) async {
        tester.view.physicalSize = const Size(360, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const loc = PosLocation(
          posId: 'POS-01',
          posName: 'Pos Pasar Bersehati',
          cabangName: 'KC Manado',
          fullAddress: 'Jl. Nusantara Manado',
          locationTag: 'PBM',
          tagColor: Colors.blue,
          lat: 1.49,
          lng: 124.84,
        );

        const temuan1 = MaintenanceTemuan(
          label: 'Sensor gate kotor',
          status: 'tidak_sesuai',
          alasan: 'Perlu dibersihkan segera',
          urgent: true,
        );
        const temuan2 = MaintenanceTemuan(
          label: 'Kabel sensor kendur',
          status: 'perlu_cek_manual',
          alasan: 'Periksa koneksi kabel',
          urgent: false,
        );

        const log1 = MaintenanceLogEntry(
          id: 'log-01',
          tanggal: '2026-11-03',
          jamSelesai: '09:30',
          posId: 'POS-01',
          posName: 'Pos Pasar Bersehati',
          teknisiNama: 'Budi Santoso',
          templateId: 'tpl_maint_manless', // Phase 1
          totalPoin: 5,
          sesuaiPoin: 3,
          // Intentionally put non-urgent first to verify sorting urgent first
          temuan: [temuan2, temuan1],
        );

        const status = PosMaintenanceStatus(
          location: loc,
          wilayah: 'Manado',
          logs: [log1],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MaintenanceLocationDetailScreen(
              status: status,
              month: DateTime(2026, 11, 1),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Renders Progres Maintenance and '1 / 4 Fase'
        expect(find.text('Progres Maintenance'), findsOneWidget);
        expect(find.text('1 / 4 Fase'), findsOneWidget);
        expect(find.text('Hasil Maintenance'), findsNothing);

        // 2. Renders '3 / 5' in Fase 1
        expect(find.text('3 / 5'), findsOneWidget);

        // 3. Renders stat tiles: Total Item (5), Sesuai (3), Temuan (2)
        expect(find.text('Total Item'), findsOneWidget);
        expect(find.text('5'), findsOneWidget);
        expect(find.text('Sesuai'), findsWidgets);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('Temuan'), findsWidgets);

        // 4. Renders 'Temuan (2)'
        expect(find.text('Temuan (2)'), findsOneWidget);

        // 5. Renders 'Urgent' and 'Perlu Cek'
        expect(find.text('Urgent'), findsOneWidget);
        expect(find.text('Perlu Cek'), findsOneWidget);

        // 6. Asserts 'Urgent' badge is rendered before 'Perlu Cek'
        final urgentOffset = tester.getTopLeft(find.text('Urgent'));
        final perluCekOffset = tester.getTopLeft(find.text('Perlu Cek'));
        expect(urgentOffset.dy, lessThan(perluCekOffset.dy));

        // 7. 'Buka di Maps' is visible because lat != 0 && lng != 0
        expect(find.text('Buka di Maps'), findsOneWidget);
      },
    );

    testWidgets(
      'renders Belum ada laporan bulan ini and hides Buka di Maps when lat==0 with zero logs',
      (tester) async {
        tester.view.physicalSize = const Size(360, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const loc = PosLocation(
          posId: 'POS-ZERO',
          posName: 'Pos Tanpa Koordinat',
          cabangName: 'KC Manado',
          fullAddress: 'Jl. Sam Ratulangi',
          locationTag: 'PTK',
          tagColor: Colors.grey,
          lat: 0.0,
          lng: 0.0,
        );

        const status = PosMaintenanceStatus(
          location: loc,
          wilayah: 'Manado',
          logs: [],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MaintenanceLocationDetailScreen(
              status: status,
              month: DateTime(2026, 11, 1),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Renders 'Belum ada laporan bulan ini'
        expect(find.text('Belum ada laporan bulan ini'), findsWidgets);

        // 2. 'Buka di Maps' is hidden when lat == 0
        expect(find.text('Buka di Maps'), findsNothing);
      },
    );

    testWidgets(
      'renders without overflow exception when textScaler is 1.3 (A11y enlarged text scale)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const loc = PosLocation(
          posId: 'POS-01',
          posName:
              'Pos Pasar Bersehati Kawasan Megamas Kota Manado Sulawesi Utara',
          cabangName: 'KC Manado',
          fullAddress: 'Jl. Nusantara No. 123 Calaca Wenang Kota Manado',
          locationTag: 'PBM',
          tagColor: Colors.blue,
          lat: 1.49,
          lng: 124.84,
        );

        const temuan1 = MaintenanceTemuan(
          label:
              'Sensor gate kotor dan palang penghalang sedikit miring butuh kalibrasi',
          status: 'tidak_sesuai',
          alasan:
              'Perlu dibersihkan segera dengan cairan pembersih khusus elektronik',
          urgent: true,
        );

        const log1 = MaintenanceLogEntry(
          id: 'log-01',
          tanggal: '2026-11-03',
          jamSelesai: '09:30',
          posId: 'POS-01',
          posName: 'Pos Pasar Bersehati',
          teknisiNama: 'Budi Santoso Teknisi Senior Lapangan KC Manado',
          teknisiNpp: 'NPP-10123',
          templateId: 'tpl_maint_manless',
          totalPoin: 5,
          sesuaiPoin: 3,
          temuan: [temuan1],
        );

        const status = PosMaintenanceStatus(
          location: loc,
          wilayah: 'Manado',
          logs: [log1],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.3),
              ),
              child: MaintenanceLocationDetailScreen(
                status: status,
                month: DateTime(2026, 11, 1),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(MaintenanceLocationDetailScreen), findsOneWidget);
        expect(find.text('Progres Maintenance'), findsOneWidget);
        expect(find.text('Hasil Maintenance'), findsNothing);
      },
    );

    testWidgets(
      'renders without RenderFlex overflow at 360x640 logical with textScaler 1.0',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const loc = PosLocation(
          posId: 'POS-01',
          posName:
              'Pos Pasar Bersehati Kawasan Megamas Kota Manado Sulawesi Utara',
          cabangName: 'KC Manado',
          fullAddress: 'Jl. Nusantara No. 123 Calaca Wenang Kota Manado',
          locationTag: 'PBM',
          tagColor: Colors.blue,
          lat: 1.49,
          lng: 124.84,
        );

        const temuan1 = MaintenanceTemuan(
          label:
              'Sensor gate kotor dan palang penghalang sedikit miring butuh kalibrasi',
          status: 'tidak_sesuai',
          alasan:
              'Perlu dibersihkan segera dengan cairan pembersih khusus elektronik',
          urgent: true,
        );

        const log1 = MaintenanceLogEntry(
          id: 'log-01',
          tanggal: '2026-11-03',
          jamSelesai: '09:30',
          posId: 'POS-01',
          posName: 'Pos Pasar Bersehati',
          teknisiNama: 'Budi Santoso Teknisi Senior Lapangan KC Manado',
          teknisiNpp: 'NPP-10123',
          templateId: 'tpl_maint_manless',
          totalPoin: 5,
          sesuaiPoin: 3,
          temuan: [temuan1],
        );

        const status = PosMaintenanceStatus(
          location: loc,
          wilayah: 'Manado',
          logs: [log1],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.0),
              ),
              child: MaintenanceLocationDetailScreen(
                status: status,
                month: DateTime(2026, 11, 1),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(MaintenanceLocationDetailScreen), findsOneWidget);
      },
    );

    testWidgets(
      'renders without RenderFlex overflow at 360x640 logical with textScaler 1.3',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const loc = PosLocation(
          posId: 'POS-01',
          posName:
              'Pos Pasar Bersehati Kawasan Megamas Kota Manado Sulawesi Utara',
          cabangName: 'KC Manado',
          fullAddress: 'Jl. Nusantara No. 123 Calaca Wenang Kota Manado',
          locationTag: 'PBM',
          tagColor: Colors.blue,
          lat: 1.49,
          lng: 124.84,
        );

        const temuan1 = MaintenanceTemuan(
          label:
              'Sensor gate kotor dan palang penghalang sedikit miring butuh kalibrasi',
          status: 'tidak_sesuai',
          alasan:
              'Perlu dibersihkan segera dengan cairan pembersih khusus elektronik',
          urgent: true,
        );

        const log1 = MaintenanceLogEntry(
          id: 'log-01',
          tanggal: '2026-11-03',
          jamSelesai: '09:30',
          posId: 'POS-01',
          posName: 'Pos Pasar Bersehati',
          teknisiNama: 'Budi Santoso Teknisi Senior Lapangan KC Manado',
          teknisiNpp: 'NPP-10123',
          templateId: 'tpl_maint_manless',
          totalPoin: 5,
          sesuaiPoin: 3,
          temuan: [temuan1],
        );

        const status = PosMaintenanceStatus(
          location: loc,
          wilayah: 'Manado',
          logs: [log1],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.3),
              ),
              child: MaintenanceLocationDetailScreen(
                status: status,
                month: DateTime(2026, 11, 1),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(MaintenanceLocationDetailScreen), findsOneWidget);
      },
    );

    testWidgets(
      'at 360dp and textScale 1.0 phase status pills show full word without ellipsis',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const loc = PosLocation(
          posId: 'POS-01',
          posName: 'Pos Pasar Bersehati',
          cabangName: 'KC Manado',
          fullAddress: 'Jl. Nusantara Manado',
          locationTag: 'PBM',
          tagColor: Colors.blue,
          lat: 1.49,
          lng: 124.84,
        );

        const temuan1 = MaintenanceTemuan(
          label: 'Sensor gate kotor',
          status: 'tidak_sesuai',
          alasan: 'Perlu dibersihkan segera',
          urgent: true,
        );

        // Phase 1 has temuan -> status 'Temuan'
        const log1 = MaintenanceLogEntry(
          id: 'log-01',
          tanggal: '2026-11-03',
          jamSelesai: '09:30',
          posId: 'POS-01',
          posName: 'Pos Pasar Bersehati',
          teknisiNama: 'Budi Santoso',
          templateId: 'tpl_maint_manless',
          totalPoin: 24,
          sesuaiPoin: 23,
          temuan: [temuan1],
        );

        const status = PosMaintenanceStatus(
          location: loc,
          wilayah: 'Manado',
          logs: [log1],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'PlusJakartaSans'),
            home: MaintenanceLocationDetailScreen(
              status: status,
              month: DateTime(2026, 11, 1),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. All 4 status pills show full words:
        // Phase 1 shows 'Temuan', Phase 2, 3, 4 show 'Belum'
        expect(find.text('Temuan'), findsWidgets);
        expect(find.text('Belum'), findsNWidgets(3));

        // 2. Assert no Text in the phase row is ellipsized
        final phaseRowFinder = find.byKey(const Key('phase_cards_row'));
        expect(phaseRowFinder, findsOneWidget);

        final textWidgets = tester.widgetList<Text>(
          find.descendant(of: phaseRowFinder, matching: find.byType(Text)),
        );

        // Expect at least 12 text widgets: 4 labels ('Fase 1'..'Fase 4') + 4 numbers + 4 status texts
        expect(textWidgets.length, greaterThanOrEqualTo(12));
        for (final text in textWidgets) {
          final data = text.data ?? '';
          expect(data.contains('…'), isFalse, reason: 'Text "$data" must not contain …');
          expect(data.contains('...'), isFalse, reason: 'Text "$data" must not contain ...');
          expect(text.overflow, isNot(TextOverflow.ellipsis), reason: 'Phase text "$data" must not have overflow ellipsis');
        }
      },
    );

    testWidgets(
      'at textScale 1.3 phase status pills show icon only with Semantics label (never ellipsis)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const loc = PosLocation(
          posId: 'POS-01',
          posName: 'Pos Pasar Bersehati',
          cabangName: 'KC Manado',
          fullAddress: 'Jl. Nusantara Manado',
          locationTag: 'PBM',
          tagColor: Colors.blue,
          lat: 1.49,
          lng: 124.84,
        );

        const log1 = MaintenanceLogEntry(
          id: 'log-01',
          tanggal: '2026-11-03',
          jamSelesai: '09:30',
          posId: 'POS-01',
          posName: 'Pos Pasar Bersehati',
          teknisiNama: 'Budi Santoso',
          templateId: 'tpl_maint_manless',
          totalPoin: 24,
          sesuaiPoin: 24,
          temuan: [],
        );

        const status = PosMaintenanceStatus(
          location: loc,
          wilayah: 'Manado',
          logs: [log1],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'PlusJakartaSans'),
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.3),
              ),
              child: MaintenanceLocationDetailScreen(
                status: status,
                month: DateTime(2026, 11, 1),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final phaseRowFinder = find.byKey(const Key('phase_cards_row'));
        // In textScale 1.3, status pill texts ('Aman', 'Belum') are icon-only with Semantics label
        expect(
          find.descendant(
            of: phaseRowFinder,
            matching: find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.label == 'Aman',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: phaseRowFinder,
            matching: find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.label == 'Belum',
            ),
          ),
          findsNWidgets(3),
        );

        // At textScale 1.3, status Text is hidden (icon-only pill)
        expect(find.text('Aman'), findsNothing);
        expect(find.text('Belum'), findsNothing);

        // Assert no Text widget in the phase row has ellipsis
        final textWidgets = tester.widgetList<Text>(
          find.descendant(of: phaseRowFinder, matching: find.byType(Text)),
        );
        for (final text in textWidgets) {
          final data = text.data ?? '';
          expect(data.contains('…'), isFalse, reason: 'Text "$data" must not contain …');
          expect(data.contains('...'), isFalse, reason: 'Text "$data" must not contain ...');
        }
      },
    );
  });
}
