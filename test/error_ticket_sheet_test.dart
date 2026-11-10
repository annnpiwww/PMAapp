import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/error_ticket_service.dart';
import 'package:bssparking_timemark/data/services/google_sheets_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

class _TrackingHttpClient extends http.BaseClient {
  final List<http.Request> recordedRequests = [];

  _TrackingHttpClient();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    recordedRequests.add(req);
    final response = http.Response(
      jsonEncode({'status': 'success'}),
      200,
      headers: {'content-type': 'application/json'},
    );
    final stream = Stream.value(utf8.encode(response.body));
    return http.StreamedResponse(stream, response.statusCode, headers: response.headers);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const adminSampleDeskripsi = '''
Selamat pagi, izin melaporkan, telah terjadi kendala dengan kronologi sebagai berikut:

Tanggal : 07-11-2026
Waktu : 05.35

Lokasi : PBM

Kendala : Pos 1 Palang Tidak bisa terangkat 

Penyebab : Tidak diketahui 

Solusi sementara : Pos 1 ditutup Smntra

Durasi Error : 

Berikut kami lampirkan dokumentasi kerusakan.

Terima kasih.
''';

  late _TrackingHttpClient mockClient;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
    mockClient = _TrackingHttpClient();
    GoogleSheetsService.clientOverride = mockClient;
  });

  tearDown(() {
    GoogleSheetsService.clientOverride = null;
    BranchService.instance.resetForTesting();
  });

  group('ErrorTicketService - Google Sheets Error log payload & sync', () {
    test('(a) buildSheetPayload open from contract admin sample', () {
      final task = DailyTaskModel(
        id: 'task_20261107_001',
        tanggal: '2026-11-07',
        teknisiId: 'tek_001',
        teknisiNama: 'Farhan Lakoro',
        posName: 'PBM',
        posTag: 'PBM',
        judul: 'Pos 1 Palang Tidak bisa terangkat',
        deskripsi: adminSampleDeskripsi,
        kategori: 'error',
      );

      final payload = ErrorTicketService.buildSheetPayload(task, stage: 'open');

      expect(payload['kind'], equals('error'));
      expect(payload['stage'], equals('open'));
      expect(payload['id'], equals('task_20261107_001'));
      expect(payload['tanggalLapor'], equals('07-11-2026'));
      expect(payload['waktuLapor'], equals('05.35'));
      expect(payload['lokasi'], equals('PBM'));
      expect(payload['kendala'], equals('Pos 1 Palang Tidak bisa terangkat'));
      expect(payload['penyebab'], equals('Tidak diketahui'));
      expect(payload['solusiSementara'], equals('Pos 1 ditutup Smntra'));
      expect(payload['pelapor'], equals('Farhan Lakoro'));
      expect(payload['teknisi'], equals('Farhan Lakoro'));
      expect(payload['solusiPerbaikan'], equals(''));
      expect(payload['selesai'], equals(''));
      expect(payload['durasiPerbaikan'], equals(''));
      expect(payload['catatan'], equals(''));
    });

    test('(b) done with parsed catatanTeknisi and formatDurasi (1 jam 12 menit for 05:35 -> 06:47)', () {
      final task = DailyTaskModel(
        id: 'task_20261107_001',
        tanggal: '2026-11-07',
        teknisiId: 'tek_001',
        teknisiNama: 'Farhan Lakoro',
        posName: 'PBM',
        posTag: 'PBM',
        judul: 'Pos 1 Palang Tidak bisa terangkat',
        deskripsi: adminSampleDeskripsi,
        kategori: 'error',
        catatanTeknisi: 'Penyebab : sensor kotor\nSolusi Perbaikan : dibersihkan sensor dan tes operasional\nCatatan : aman kembali',
        status: TaskStatus.completed,
        jamSelesai: '06.47',
      );

      final selesai = DateTime(2026, 11, 7, 6, 47);
      final payload = ErrorTicketService.buildSheetPayload(task, stage: 'done', selesai: selesai);

      expect(payload['kind'], equals('error'));
      expect(payload['stage'], equals('done'));
      expect(payload['id'], equals('task_20261107_001'));
      expect(payload['tanggalLapor'], equals('07-11-2026'));
      expect(payload['waktuLapor'], equals('05.35'));
      expect(payload['lokasi'], equals('PBM'));
      expect(payload['kendala'], equals('Pos 1 Palang Tidak bisa terangkat'));
      expect(payload['penyebab'], equals('sensor kotor'));
      expect(payload['solusiSementara'], equals('Pos 1 ditutup Smntra'));
      expect(payload['pelapor'], equals('Farhan Lakoro'));
      expect(payload['teknisi'], equals('Farhan Lakoro'));
      expect(payload['solusiPerbaikan'], equals('dibersihkan sensor dan tes operasional'));
      expect(payload['selesai'], equals('07-11-2026 06.47'));
      expect(payload['durasiPerbaikan'], equals('1 jam 12 menit'));
      expect(payload['catatan'], equals('aman kembali'));
    });

    test('(c) local_ id skipped on open', () async {
      final task = DailyTaskModel(
        id: 'local_1731234567890_1234',
        tanggal: '2026-11-07',
        teknisiId: 'tek_001',
        teknisiNama: 'Farhan Lakoro',
        posName: 'PBM',
        posTag: 'PBM',
        judul: 'Pos 1 Palang Tidak bisa terangkat',
        deskripsi: adminSampleDeskripsi,
        kategori: 'error',
      );

      await ErrorTicketService.syncSheetOpen(task);

      expect(mockClient.recordedRequests, isEmpty);
    });

    test('(d) non-error kategori skipped', () async {
      final task = DailyTaskModel(
        id: 'task_20261107_002',
        tanggal: '2026-11-07',
        teknisiId: 'tek_001',
        teknisiNama: 'Farhan Lakoro',
        posName: 'PBM',
        posTag: 'PBM',
        judul: 'Pengecekan Rutin',
        deskripsi: 'Deskripsi tugas biasa',
        kategori: 'khusus',
      );

      await ErrorTicketService.syncSheetOpen(task);
      expect(mockClient.recordedRequests, isEmpty);

      await ErrorTicketService.syncSheetDone(task, selesai: DateTime(2026, 11, 7, 7, 0));
      expect(mockClient.recordedRequests, isEmpty);
    });

    test('(e) branch not Manado skipped', () async {
      await BranchService.instance.setBranch(AppBranch.bali);
      expect(BranchService.instance.currentBranch, equals(AppBranch.bali));

      final task = DailyTaskModel(
        id: 'task_20261107_003',
        tanggal: '2026-11-07',
        teknisiId: 'tek_bali',
        teknisiNama: 'Indra Yohana',
        posName: 'PBKD',
        posTag: 'PBKD',
        judul: 'Pos 1 Error',
        deskripsi: adminSampleDeskripsi,
        kategori: 'error',
      );

      await ErrorTicketService.syncSheetOpen(task);
      expect(mockClient.recordedRequests, isEmpty);

      await ErrorTicketService.syncSheetDone(task, selesai: DateTime(2026, 11, 7, 7, 0));
      expect(mockClient.recordedRequests, isEmpty);
    });

    test('syncSheetOpen and syncSheetDone send payload when Manado and error kategori', () async {
      final taskOpen = DailyTaskModel(
        id: 'task_20261107_004',
        tanggal: '2026-11-07',
        teknisiId: 'tek_001',
        teknisiNama: 'Farhan Lakoro',
        posName: 'PBM',
        posTag: 'PBM',
        judul: 'Palang macet',
        deskripsi: adminSampleDeskripsi,
        kategori: 'error',
      );

      await ErrorTicketService.syncSheetOpen(taskOpen);
      expect(mockClient.recordedRequests.length, equals(1));
      final openBody = jsonDecode(mockClient.recordedRequests.first.body) as Map<String, dynamic>;
      expect(openBody['kind'], equals('error'));
      expect(openBody['stage'], equals('open'));
      expect(openBody['id'], equals('task_20261107_004'));

      final taskDone = taskOpen.copyWith(
        status: TaskStatus.completed,
        jamSelesai: '06.47',
        catatanTeknisi: 'Penyebab : kabel lepas\nSolusi Perbaikan : pasang kabel',
      );

      await ErrorTicketService.syncSheetDone(taskDone, selesai: DateTime(2026, 11, 7, 6, 47));
      expect(mockClient.recordedRequests.length, equals(2));
      final doneBody = jsonDecode(mockClient.recordedRequests.last.body) as Map<String, dynamic>;
      expect(doneBody['kind'], equals('error'));
      expect(doneBody['stage'], equals('done'));
      expect(doneBody['id'], equals('task_20261107_004'));
      expect(doneBody['penyebab'], equals('kabel lepas'));
      expect(doneBody['solusiPerbaikan'], equals('pasang kabel'));
    });
  });
}
