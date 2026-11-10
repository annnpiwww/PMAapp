import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/models/error_report.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/error_ticket_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
    DailyTaskService.resetKnownPendingTaskIdsForTesting();
    ErrorTicketService.resetLastServerResultForTesting();
  });

  tearDown(() {
    DailyTaskService.clientOverride = null;
    BranchService.instance.resetForTesting();
  });

  group('SPV Error Assign Modes & Technician Scope Tests', () {
    test('1. createErrorTicketForMode builds correct state for all 3 modes', () async {
      // 1a. semuaTeknisi: released to open list
      const textSemua = '''
Tanggal : 10-11-2026
Waktu : 08.30
Lokasi : PBM
Kendala : Tiket dispenser gate in mati
Penyebab : Power supply drop
Solusi sementara : Buka gate manual
''';
      final taskSemua = await ErrorTicketService.createErrorTicketForMode(
        mode: ErrorAssignMode.semuaTeknisi,
        report: ErrorReport.parse(textSemua),
        original: textSemua,
        pelapor: 'Farhan Lakoro',
        posName: 'Pasar Bersehati',
        posTag: 'PBM',
      );
      expect(taskSemua, isNotNull);
      expect(taskSemua!.kategori, equals('error'));
      expect(taskSemua.createdBy, equals('Farhan Lakoro'));
      expect(taskSemua.isOpenHandover, isTrue);
      expect(taskSemua.peserta, isEmpty);

      // 1b. tunjuk: assigned to penanggungJawab and pendamping
      const textTunjuk = '''
Tanggal : 10-11-2026
Waktu : 09.00
Lokasi : PBM
Kendala : Barrier gate pos 2 macet
Penyebab : Motor terbakar
Solusi sementara : Diganjal terbuka
''';
      final taskTunjuk = await ErrorTicketService.createErrorTicketForMode(
        mode: ErrorAssignMode.tunjuk,
        report: ErrorReport.parse(textTunjuk),
        original: textTunjuk,
        pelapor: 'Farhan Lakoro',
        posName: 'Pasar Bersehati',
        posTag: 'PBM',
        penanggungJawab: 'Ryan Lumasuge',
        pendamping: ['Junifer Manua', 'Raldy Sangkop'],
      );
      expect(taskTunjuk, isNotNull);
      expect(taskTunjuk!.kategori, equals('error'));
      expect(taskTunjuk.teknisiNama, equals('Ryan Lumasuge'));
      expect(taskTunjuk.peserta, equals('Junifer Manua, Raldy Sangkop'));
      expect(taskTunjuk.isOpenHandover, isFalse);
      expect(taskTunjuk.createdBy, equals('Farhan Lakoro'));

      // 1c. sayaTangani: assigned to SPV pelapor
      const textSaya = '''
Tanggal : 10-11-2026
Waktu : 09.30
Lokasi : PBM
Kendala : Switch hub server restart sendiri
Penyebab : Adaptor panas
Solusi sementara : Pasang kipas darurat
''';
      final taskSaya = await ErrorTicketService.createErrorTicketForMode(
        mode: ErrorAssignMode.sayaTangani,
        report: ErrorReport.parse(textSaya),
        original: textSaya,
        pelapor: 'Farhan Lakoro',
        posName: 'Pasar Bersehati',
        posTag: 'PBM',
      );
      expect(taskSaya, isNotNull);
      expect(taskSaya!.kategori, equals('error'));
      expect(taskSaya.teknisiNama, equals('Farhan Lakoro'));
      expect(taskSaya.peserta, isEmpty);
      expect(taskSaya.isOpenHandover, isFalse);
      expect(taskSaya.createdBy, equals('Farhan Lakoro'));
    });

    test('2. technician task list includes assigned and open-list, but excludes other tech or SPV sayaTangani', () async {
      const today = '2026-11-10';
      final rows = [
        // a. Open-list error ticket (semuaTeknisi) -> MUST be included for Ryan
        {
          'id': 'task_err_open',
          'tanggal': today,
          'teknisi_nama': 'Farhan Lakoro',
          'peserta': '',
          'pos_name': 'Pasar Bersehati',
          'pos_tag': 'PBM',
          'judul': 'Tiket gate in rusak',
          'deskripsi': 'Pelapor : Farhan Lakoro\nKendala : Tiket gate in rusak',
          'kategori': 'error',
          'status': 'pending',
          'serah_terima': 'Farhan Lakoro||Daftar terbuka|10 Nov 08:30',
        },
        // b. Tunjuk teknisi Ryan Lumasuge -> MUST be included
        {
          'id': 'task_err_ryan',
          'tanggal': today,
          'teknisi_nama': 'Ryan Lumasuge',
          'peserta': '',
          'pos_name': 'Pasar Bersehati',
          'pos_tag': 'PBM',
          'judul': 'Barrier gate error',
          'deskripsi': 'Pelapor : Farhan Lakoro\nKendala : Barrier gate error',
          'kategori': 'error',
          'status': 'pending',
          'serah_terima': '',
        },
        // c. Tunjuk teknisi Budi Santoso -> MUST BE EXCLUDED for Ryan
        {
          'id': 'task_err_budi',
          'tanggal': today,
          'teknisi_nama': 'Budi Santoso',
          'peserta': '',
          'pos_name': 'Pasar Bersehati',
          'pos_tag': 'PBM',
          'judul': 'Kamera LPR error',
          'deskripsi': 'Pelapor : Farhan Lakoro\nKendala : Kamera LPR error',
          'kategori': 'error',
          'status': 'pending',
          'serah_terima': '',
        },
        // d. SPV Saya Tangani -> MUST BE EXCLUDED for Ryan
        {
          'id': 'task_err_spv_saya',
          'tanggal': today,
          'teknisi_nama': 'Farhan Lakoro',
          'peserta': '',
          'pos_name': 'Pasar Bersehati',
          'pos_tag': 'PBM',
          'judul': 'Server database down',
          'deskripsi': 'Pelapor : Farhan Lakoro\nKendala : Server database down',
          'kategori': 'error',
          'status': 'pending',
          'serah_terima': '',
        },
        // e. Regular task assigned to Ryan -> included
        {
          'id': 'task_reg_ryan',
          'tanggal': today,
          'teknisi_nama': 'Ryan Lumasuge',
          'peserta': '',
          'pos_name': 'Pasar Bersehati',
          'pos_tag': 'PBM',
          'judul': 'Checklist pos 1',
          'deskripsi': '',
          'kategori': 'khusus',
          'status': 'pending',
          'serah_terima': '',
        },
      ];

      DailyTaskService.clientOverride = MockClient((req) async {
        return http.Response(jsonEncode(rows), 200, headers: {'content-type': 'application/json'});
      });

      final result = await DailyTaskService.getTasksForTeknisi(tanggal: today, teknisiNama: 'Ryan Lumasuge');
      final resultIds = result.map((t) => t.id).toSet();

      expect(resultIds, contains('task_err_open'));
      expect(resultIds, contains('task_err_ryan'));
      expect(resultIds, contains('task_reg_ryan'));
      expect(resultIds, isNot(contains('task_err_budi')));
      expect(resultIds, isNot(contains('task_err_spv_saya')));
    });

    test('3. claimTask on already-claimed ticket returns taken result with owner name', () async {
      final task = DailyTaskModel(
        id: 'task_err_race_1',
        tanggal: '2026-11-10',
        teknisiId: '',
        teknisiNama: 'Farhan Lakoro',
        posName: 'PBM',
        posTag: 'PBM',
        judul: 'Barrier macet',
        kategori: 'error',
        status: TaskStatus.pending,
        serahTerima: 'Farhan Lakoro||Daftar terbuka|10 Nov 08:30',
      );

      // Mock server returns 0 updated rows on PATCH (already claimed), and subsequent check query returns Budi Santoso as new owner
      DailyTaskService.clientOverride = MockClient((req) async {
        if (req.method == 'POST' && req.url.path.contains('/functions/v1/daily-tasks')) {
          // Edge function returns 409 already claimed
          return http.Response(
            jsonEncode({'error': 'already claimed', 'claimed_by': 'Budi Santoso'}),
            409,
            headers: {'content-type': 'application/json'},
          );
        }
        if (req.method == 'PATCH') {
          return http.Response(jsonEncode([]), 200, headers: {'content-type': 'application/json'});
        }
        if (req.method == 'GET' && req.url.queryParameters['select'] == 'teknisi_nama') {
          return http.Response(
            jsonEncode([
              {'teknisi_nama': 'Budi Santoso'}
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('[]', 200);
      });

      final res = await DailyTaskService.claimTask(task: task, olehSiapa: 'Ryan Lumasuge');
      expect(res.success, isFalse);
      expect(res.isTaken, isTrue);
      expect(res.claimedBy, equals('Budi Santoso'));
      expect(res.message, equals('Tiket sudah diambil Budi Santoso'));
    });
  });
}
