import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/data/models/maintenance_temuan_fix.dart';
import 'package:bssparking_timemark/data/services/maintenance_fix_service.dart';
import 'package:bssparking_timemark/data/services/maintenance_log_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/data/services/whatsapp_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    MaintenanceFixService.clientOverride = null;
  });

  tearDown(() {
    MaintenanceFixService.clientOverride = null;
  });

  group('MaintenanceTemuan and MaintenanceLogEntry Fix State', () {
    test('(a) fixed temuan makes hasTemuan false when it was the only tidak_sesuai', () {
      final fix = MaintenanceTemuanFix(
        id: 'fix-01',
        logId: 'log-01',
        temuanLabel: 'Temuan 1',
        posId: 'POS-01',
        posName: 'Pos Pasar Bersehati',
        branch: 'MDO',
        teknisiNama: 'Budi',
        catatan: 'Sudah diperbaiki dan diganti baut baru',
        photoUrls: const ['https://example.com/p1.jpg'],
        fixedAt: DateTime(2026, 11, 8, 10, 30),
      );

      final entry = MaintenanceLogEntry(
        id: 'log-01',
        tanggal: '2026-11-08',
        jamSelesai: '10:00',
        posId: 'POS-01',
        posName: 'Pos Pasar Bersehati',
        teknisiNama: 'Budi',
        totalPoin: 10,
        sesuaiPoin: 9,
        temuan: [
          MaintenanceTemuan(
            label: 'Temuan 1',
            status: 'tidak_sesuai',
            alasan: 'Baut kendor',
            urgent: false,
            fix: fix,
          ),
        ],
      );

      expect(entry.temuan.first.isFixed, isTrue);
      expect(entry.hasTemuan, isFalse);

      // Testing withFixes helper
      const unfixedEntry = MaintenanceLogEntry(
        id: 'log-01',
        tanggal: '2026-11-08',
        jamSelesai: '10:00',
        posId: 'POS-01',
        posName: 'Pos Pasar Bersehati',
        teknisiNama: 'Budi',
        totalPoin: 10,
        sesuaiPoin: 9,
        temuan: [
          MaintenanceTemuan(
            label: 'Temuan 1',
            status: 'tidak_sesuai',
            alasan: 'Baut kendor',
            urgent: false,
          ),
        ],
      );
      expect(unfixedEntry.hasTemuan, isTrue);

      final fixedMap = {'log-01|Temuan 1': fix};
      final updated = unfixedEntry.withFixes(fixedMap);
      expect(updated.hasTemuan, isFalse);
      expect(updated.temuan.first.isFixed, isTrue);
    });

    test('(b) one fixed + one unfixed keeps hasTemuan true', () {
      final fix = MaintenanceTemuanFix(
        id: 'fix-01',
        logId: 'log-01',
        temuanLabel: 'Temuan 1',
        posId: 'POS-01',
        posName: 'Pos Pasar Bersehati',
        branch: 'MDO',
        teknisiNama: 'Budi',
        catatan: 'Baut diperbaiki',
        photoUrls: const ['https://example.com/p1.jpg'],
        fixedAt: DateTime(2026, 11, 8, 10, 30),
      );

      final entry = MaintenanceLogEntry(
        id: 'log-01',
        tanggal: '2026-11-08',
        jamSelesai: '10:00',
        posId: 'POS-01',
        posName: 'Pos Pasar Bersehati',
        teknisiNama: 'Budi',
        totalPoin: 10,
        sesuaiPoin: 8,
        temuan: [
          MaintenanceTemuan(
            label: 'Temuan 1',
            status: 'tidak_sesuai',
            alasan: 'Baut kendor',
            urgent: false,
            fix: fix,
          ),
          const MaintenanceTemuan(
            label: 'Temuan 2',
            status: 'tidak_sesuai',
            alasan: 'Kabel terkelupas',
            urgent: true,
          ),
        ],
      );

      expect(entry.temuan[0].isFixed, isTrue);
      expect(entry.temuan[1].isFixed, isFalse);
      expect(entry.hasTemuan, isTrue);
    });
  });

  group('MaintenanceFixService Validation & Outbox', () {
    const sampleLog = MaintenanceLogEntry(
      id: 'log-test',
      tanggal: '2026-11-08',
      jamSelesai: '10:00',
      posId: 'POS-PBM-01',
      posName: 'Pasar Bersehati Manado',
      teknisiNama: 'Junifer Mamahit',
      totalPoin: 10,
      sesuaiPoin: 9,
      temuan: [],
    );

    const sampleTemuan = MaintenanceTemuan(
      label: 'Dudukan barrier gate kendor',
      status: 'tidak_sesuai',
      alasan: 'Baut dinabolt dol',
      urgent: true,
    );

    test('(c) submitFix rejects catatan < 3 chars and 0 photos with FixSubmitStatus.invalid', () async {
      // Short catatan
      final resultShort = await MaintenanceFixService.submitFix(
        log: sampleLog,
        temuan: sampleTemuan,
        catatan: 'ab',
        photoPaths: ['https://example.com/p1.jpg'],
      );
      expect(resultShort.status, equals(FixSubmitStatus.invalid));
      expect(resultShort.message, contains('3 sampai 500'));

      // Empty photos
      final resultNoPhotos = await MaintenanceFixService.submitFix(
        log: sampleLog,
        temuan: sampleTemuan,
        catatan: 'Sudah diganti dinabolt baru',
        photoPaths: [],
      );
      expect(resultNoPhotos.status, equals(FixSubmitStatus.invalid));
      expect(resultNoPhotos.message, contains('1 sampai 3 foto'));

      // More than 3 photos
      final resultTooManyPhotos = await MaintenanceFixService.submitFix(
        log: sampleLog,
        temuan: sampleTemuan,
        catatan: 'Sudah diganti dinabolt baru',
        photoPaths: ['p1', 'p2', 'p3', 'p4'],
      );
      expect(resultTooManyPhotos.status, equals(FixSubmitStatus.invalid));
      expect(resultTooManyPhotos.message, contains('1 sampai 3 foto'));
    });

    test('(d) network failure -> queued and present in pendingLocal()', () async {
      MaintenanceFixService.clientOverride = MockClient((request) async {
        throw http.ClientException('Network down');
      });

      final result = await MaintenanceFixService.submitFix(
        log: sampleLog,
        temuan: sampleTemuan,
        catatan: 'Sudah diganti dinabolt baru ukuran 12mm',
        photoPaths: ['https://example.com/photo_proof.jpg'],
      );

      expect(result.status, equals(FixSubmitStatus.queued));
      expect(result.fix, isNotNull);
      expect(result.fix!.pendingSync, isTrue);

      final pending = MaintenanceFixService.pendingLocal();
      expect(pending.length, equals(1));
      expect(pending.first.logId, equals('log-test'));
      expect(pending.first.temuanLabel, equals('Dudukan barrier gate kendor'));
      expect(pending.first.pendingSync, isTrue);
    });

    test('(e) fetchForLogs chunks 170 ids into 3 requests (80, 80, 10) with URL encoding', () async {
      final capturedUris = <Uri>[];

      MaintenanceFixService.clientOverride = MockClient((request) async {
        capturedUris.add(request.url);
        return http.Response('[]', 200, headers: {'content-type': 'application/json'});
      });

      final testIds = List.generate(170, (i) => 'log_id_$i with special & chars');
      await MaintenanceFixService.fetchForLogs(testIds);

      expect(capturedUris.length, equals(3));

      // 1st chunk: 80 IDs
      final query1 = capturedUris[0].query;
      expect(query1, contains('log_id=in.('));
      expect(query1, contains(Uri.encodeQueryComponent('log_id_0 with special & chars')));

      final chunk1Match = RegExp(r'log_id=in\.\((.*)\)&select=').firstMatch(query1);
      expect(chunk1Match, isNotNull);
      final chunk1Ids = chunk1Match!.group(1)!.split(',');
      expect(chunk1Ids.length, equals(80));

      // 2nd chunk: 80 IDs
      final chunk2Match = RegExp(r'log_id=in\.\((.*)\)&select=').firstMatch(capturedUris[1].query);
      expect(chunk2Match, isNotNull);
      final chunk2Ids = chunk2Match!.group(1)!.split(',');
      expect(chunk2Ids.length, equals(80));

      // 3rd chunk: 10 IDs
      final chunk3Match = RegExp(r'log_id=in\.\((.*)\)&select=').firstMatch(capturedUris[2].query);
      expect(chunk3Match, isNotNull);
      final chunk3Ids = chunk3Match!.group(1)!.split(',');
      expect(chunk3Ids.length, equals(10));
    });
  });

  group('WhatsAppReportService formatTemuanFixReport', () {
    test('(f) WhatsAppReportService.formatTemuanFixReport exact string formatting with WITA time', () {
      final fixedDate = DateTime(2026, 11, 8, 14, 25);

      final fix = MaintenanceTemuanFix(
        id: 'fix_12345',
        logId: 'log-pbm-01',
        temuanLabel: 'Dudukan/dinabolt mesin barrier gate',
        posId: 'POS-PBM-01',
        posName: 'Pasar Bersehati Manado',
        branch: 'MDO',
        teknisiNama: 'Junifer Mamahit',
        teknisiNpp: 'NPP-101',
        catatan: 'Sudah diganti dinabolt baru ukuran 12mm dan dicor ulang.',
        photoUrls: const ['https://example.com/p1.jpg'],
        fixedAt: fixedDate,
      );

      const log = MaintenanceLogEntry(
        id: 'log-pbm-01',
        tanggal: '2026-11-08',
        jamSelesai: '11:00',
        posId: 'POS-PBM-01',
        posName: 'Pasar Bersehati Manado',
        teknisiNama: 'Junifer Mamahit',
        totalPoin: 10,
        sesuaiPoin: 9,
        temuan: [],
      );

      final temuan = MaintenanceTemuan(
        label: 'Dudukan/dinabolt mesin barrier gate',
        status: 'tidak_sesuai',
        alasan: 'Dinabolt patah akibat getaran palang',
        urgent: true,
        fix: fix,
      );

      final report = WhatsAppReportService.formatTemuanFixReport(
        log: log,
        temuan: temuan,
        fix: fix,
      );

      final expected = '''*LAPORAN PERBAIKAN TEMUAN*

Pos : Pasar Bersehati Manado
Temuan : Dudukan/dinabolt mesin barrier gate
Kondisi Awal : Dinabolt patah akibat getaran palang
Tindakan : Sudah diganti dinabolt baru ukuran 12mm dan dicor ulang.
Diperbaiki Oleh : Junifer Mamahit
Waktu : 8 November 2026, 14:25 WITA

Terima Kasih''';

      expect(report, equals(expected));
    });
  });
}
