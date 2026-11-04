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

        // 1. Renders '3 / 5'
        expect(find.text('3 / 5'), findsOneWidget);

        // 2. Renders 'Temuan (2)'
        expect(find.text('Temuan (2)'), findsOneWidget);

        // 3. Renders 'Urgent' and 'Perlu cek'
        expect(find.text('Urgent'), findsOneWidget);
        expect(find.text('Perlu cek'), findsOneWidget);

        // 4. Asserts 'Urgent' badge is rendered before 'Perlu cek'
        final urgentOffset = tester.getTopLeft(find.text('Urgent'));
        final perluCekOffset = tester.getTopLeft(find.text('Perlu cek'));
        expect(urgentOffset.dy, lessThan(perluCekOffset.dy));

        // 5. 'Buka di Maps' is visible because lat != 0 && lng != 0
        expect(find.text('Buka di Maps'), findsOneWidget);
      },
    );

    testWidgets(
      'renders Belum ada laporan bulan ini and hides Buka di Maps when lat==0 with zero logs',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
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
        tester.view.physicalSize = const Size(360, 800);
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
        expect(find.text('Hasil Inspeksi'), findsOneWidget);
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
  });
}
