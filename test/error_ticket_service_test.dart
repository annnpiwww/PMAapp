import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/error_ticket_service.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

class _FailingHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw http.ClientException('Server unavailable');
  }
}

class _SuccessHttpClient extends http.BaseClient {
  final String responseBody;

  _SuccessHttpClient(this.responseBody);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = utf8.encode(responseBody);
    final stream = Stream.value(bytes);
    return http.StreamedResponse(
      stream,
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const dummyColor = Color(0xFF000000);

  const posTBM = PosLocation(
    posId: 'pos_tbm',
    posName: 'Pos Booth Megamas',
    cabangName: 'KC Manado',
    fullAddress: 'Jl. Megamas',
    locationTag: 'TBM',
    tagColor: dummyColor,
    lat: 1.0,
    lng: 124.0,
  );

  const posGate1 = PosLocation(
    posId: 'pos_gate1',
    posName: 'Gate 1',
    cabangName: 'KC Manado',
    fullAddress: 'Jl. Megamas',
    locationTag: 'G1',
    tagColor: dummyColor,
    lat: 1.0,
    lng: 124.0,
  );

  const posGate2 = PosLocation(
    posId: 'pos_gate2',
    posName: 'Gate 2',
    cabangName: 'KC Manado',
    fullAddress: 'Jl. Megamas',
    locationTag: 'G2',
    tagColor: dummyColor,
    lat: 1.0,
    lng: 124.0,
  );

  const posBarat = PosLocation(
    posId: 'pos_barat',
    posName: 'Pos Barat',
    cabangName: 'KC Manado',
    fullAddress: 'Jl. Megamas',
    locationTag: 'PB',
    tagColor: dummyColor,
    lat: 1.0,
    lng: 124.0,
  );

  const posSingleCharTag = PosLocation(
    posId: 'pos_single_char',
    posName: 'Pos Satu',
    cabangName: 'KC Manado',
    fullAddress: 'Jl. Megamas',
    locationTag: 'A',
    tagColor: dummyColor,
    lat: 1.0,
    lng: 124.0,
  );

  group('guessPos rules', () {
    test('posName whole word hit', () {
      final match = ErrorTicketService.guessPos(
        'Tolong cek Pos Barat segera',
        [posBarat, posGate1],
      );
      expect(match, isNotNull);
      expect(match!.posId, equals('pos_barat'));
    });

    test("tag hit 'gate 2 TBM printer' -> TBM pos", () {
      final match = ErrorTicketService.guessPos(
        'gate 2 TBM printer',
        [posTBM],
      );
      expect(match, isNotNull);
      expect(match!.posId, equals('pos_tbm'));
    });

    test('substring inside another word not matched', () {
      final matchTag = ErrorTicketService.guessPos(
        'gate 2 atbmb printer',
        [posTBM],
      );
      expect(matchTag, isNull);

      final matchName = ErrorTicketService.guessPos(
        'PosBarat error',
        [posBarat],
      );
      expect(matchName, isNull);
    });

    test('longer posName beats tag', () {
      final match = ErrorTicketService.guessPos(
        'gate 2 TBM printer',
        [posGate2, posTBM],
      );
      expect(match, isNotNull);
      expect(match!.posId, equals('pos_gate2'));
    });

    test('tie -> null', () {
      final match = ErrorTicketService.guessPos(
        'gate 1 dan gate 2 error',
        [posGate1, posGate2],
      );
      expect(match, isNull);
    });

    test('empty text -> null', () {
      expect(ErrorTicketService.guessPos('', [posTBM]), isNull);
      expect(ErrorTicketService.guessPos('    ', [posTBM]), isNull);
    });

    test('tag of 1 char ignored', () {
      final match = ErrorTicketService.guessPos(
        'Kerusakan di Pos A',
        [posSingleCharTag],
      );
      expect(match, isNull);
    });
  });

  group('openPosNames normalisation', () {
    test('normalises, deduplicates and skips empty posName', () {
      final tasks = [
        DailyTaskModel(
          id: '1',
          tanggal: '2026-11-10',
          teknisiId: 'tek_1',
          teknisiNama: 'Budi',
          posName: '  Pos Barat  ',
          posTag: 'PB',
          judul: 'Error printer',
          kategori: 'error',
        ),
        DailyTaskModel(
          id: '2',
          tanggal: '2026-11-10',
          teknisiId: 'tek_2',
          teknisiNama: 'Andi',
          posName: 'POS BARAT',
          posTag: 'PB',
          judul: 'Gate macet',
          kategori: 'error',
        ),
        DailyTaskModel(
          id: '3',
          tanggal: '2026-11-10',
          teknisiId: 'tek_3',
          teknisiNama: 'Charlie',
          posName: 'Gate 1',
          posTag: 'G1',
          judul: 'Sensor rusak',
          kategori: 'error',
        ),
        DailyTaskModel(
          id: '4',
          tanggal: '2026-11-10',
          teknisiId: 'tek_4',
          teknisiNama: 'Dedi',
          posName: '',
          posTag: '',
          judul: 'Tanpa pos',
          kategori: 'error',
        ),
        DailyTaskModel(
          id: '5',
          tanggal: '2026-11-10',
          teknisiId: 'tek_5',
          teknisiNama: 'Eko',
          posName: '   ',
          posTag: '',
          judul: 'Spasi doang',
          kategori: 'error',
        ),
      ];

      final names = ErrorTicketService.openPosNames(tasks);
      expect(names, equals({'pos barat', 'gate 1'}));
    });
  });

  group('fetchOpen offline fallback filters kategori, status, and isOpenHandover', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      DailyTaskService.clientOverride = null;
      ErrorTicketService.resetLastServerResultForTesting();
    });

    tearDown(() {
      DailyTaskService.clientOverride = null;
      ErrorTicketService.resetLastServerResultForTesting();
    });

    test('pure filterOpenTickets filters kategori == error, !isCompleted, and isOpenHandover', () {
      final list = [
        DailyTaskModel(
          id: 't_error_open',
          tanggal: '2026-11-10',
          teknisiId: 'tek_1',
          teknisiNama: 'Teknisi 1',
          posName: 'Pos 1',
          posTag: 'P1',
          judul: 'Error open',
          kategori: 'error',
          status: TaskStatus.pending,
          serahTerima: 'a||Daftar terbuka|13 Nov 05:52',
        ),
        DailyTaskModel(
          id: 't_error_claimed',
          tanggal: '2026-11-10',
          teknisiId: 'tek_1',
          teknisiNama: 'Budi',
          posName: 'Pos 1',
          posTag: 'P1',
          judul: 'Error claimed',
          kategori: 'error',
          status: TaskStatus.pending,
          serahTerima: 'a||Daftar terbuka|13 Nov 05:52\na|Budi|Ambil tugas terbuka|13 Nov 06:00',
        ),
        DailyTaskModel(
          id: 't_error_completed',
          tanggal: '2026-11-10',
          teknisiId: 'tek_1',
          teknisiNama: 'Teknisi 1',
          posName: 'Pos 1',
          posTag: 'P1',
          judul: 'Error completed',
          kategori: 'error',
          status: TaskStatus.completed,
          serahTerima: 'a||Daftar terbuka|13 Nov 05:52',
        ),
        DailyTaskModel(
          id: 't_khusus_pending',
          tanggal: '2026-11-10',
          teknisiId: 'tek_1',
          teknisiNama: 'Teknisi 1',
          posName: 'Pos 1',
          posTag: 'P1',
          judul: 'Khusus pending',
          kategori: 'khusus',
          status: TaskStatus.pending,
          serahTerima: 'a||Daftar terbuka|13 Nov 05:52',
        ),
        DailyTaskModel(
          id: 't_maintenance_pending',
          tanggal: '2026-11-10',
          teknisiId: 'tek_1',
          teknisiNama: 'Teknisi 1',
          posName: 'Pos 1',
          posTag: 'P1',
          judul: 'Maintenance pending',
          kategori: 'maintenance',
          status: TaskStatus.pending,
        ),
      ];

      final filtered = ErrorTicketService.filterOpenTickets(list);
      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals('t_error_open'));
    });

    test('filterOpenTickets includes unclaimed open handover and excludes claimed or assigned tickets', () {
      final unclaimed = DailyTaskModel(
        id: 't_unclaimed',
        tanggal: '2026-11-13',
        teknisiId: '',
        teknisiNama: 'a',
        posName: 'Pos 1',
        posTag: 'P1',
        judul: 'Unclaimed',
        kategori: 'error',
        status: TaskStatus.pending,
        serahTerima: 'a||Daftar terbuka|13 Nov 05:52',
      );
      final claimed = DailyTaskModel(
        id: 't_claimed',
        tanggal: '2026-11-13',
        teknisiId: '',
        teknisiNama: 'Budi',
        posName: 'Pos 1',
        posTag: 'P1',
        judul: 'Claimed',
        kategori: 'error',
        status: TaskStatus.pending,
        serahTerima: 'a||Daftar terbuka|13 Nov 05:52\na|Budi|Ambil tugas terbuka|13 Nov 06:00',
      );
      final assigned = DailyTaskModel(
        id: 't_assigned',
        tanggal: '2026-11-13',
        teknisiId: '',
        teknisiNama: 'Budi',
        posName: 'Pos 1',
        posTag: 'P1',
        judul: 'Direct tunjuk',
        kategori: 'error',
        status: TaskStatus.pending,
      );

      final filtered = ErrorTicketService.filterOpenTickets([claimed, assigned, unclaimed]);
      expect(filtered.map((t) => t.id).toList(), equals(['t_unclaimed']));
    });

    test('fetchOpen falls back to local cached tasks when client fails', () async {
      final cachedList = [
        DailyTaskModel(
          id: 'cached_err_1',
          tanggal: '2026-11-10',
          teknisiId: 'tek_1',
          teknisiNama: 'Teknisi 1',
          posName: 'Pos 1',
          posTag: 'P1',
          judul: 'Cached error pending',
          kategori: 'error',
          status: TaskStatus.pending,
          serahTerima: 'a||Daftar terbuka|13 Nov 05:52',
        ),
        DailyTaskModel(
          id: 'cached_err_2',
          tanggal: '2026-11-10',
          teknisiId: 'tek_1',
          teknisiNama: 'Teknisi 1',
          posName: 'Pos 1',
          posTag: 'P1',
          judul: 'Cached error done',
          kategori: 'error',
          status: TaskStatus.completed,
          serahTerima: 'a||Daftar terbuka|13 Nov 05:52',
        ),
        DailyTaskModel(
          id: 'cached_khusus',
          tanggal: '2026-11-10',
          teknisiId: 'tek_1',
          teknisiNama: 'Teknisi 1',
          posName: 'Pos 1',
          posTag: 'P1',
          judul: 'Cached khusus pending',
          kategori: 'khusus',
          status: TaskStatus.pending,
          serahTerima: 'a||Daftar terbuka|13 Nov 05:52',
        ),
      ];

      await DailyTaskService.cacheTasksLocallyForTesting(cachedList);
      DailyTaskService.clientOverride = _FailingHttpClient();

      final result = await ErrorTicketService.fetchOpen();
      expect(result.length, equals(1));
      expect(result.first.id, equals('cached_err_1'));
      expect(result.first.judul, equals('Cached error pending'));
    });

    test('fetchOpen prefers last successful server result in memory over local cache on offline fallback', () async {
      final serverTicket = {
        'id': 'server_spv_err_1',
        'tanggal': '2026-11-10',
        'teknisi_id': 'spv_1',
        'teknisi_nama': 'Farhan Lakoro (SPV)',
        'pos_name': 'Pos Barat',
        'pos_tag': 'PB',
        'judul': 'Server error from SPV',
        'deskripsi': 'Detail server error',
        'kategori': 'error',
        'status': 'pending',
        'serah_terima': 'Farhan Lakoro (SPV)||Daftar terbuka|13 Nov 05:52',
      };

      // 1. Initial successful server fetch: populates _lastServerResult
      DailyTaskService.clientOverride = _SuccessHttpClient(jsonEncode([serverTicket]));
      final onlineResult = await ErrorTicketService.fetchOpen();
      expect(onlineResult.length, equals(1));
      expect(onlineResult.first.id, equals('server_spv_err_1'));

      // 2. Local cache only has the technician's own cached tasks
      final technicianOwnCache = [
        DailyTaskModel(
          id: 'local_tech_only_1',
          tanggal: '2026-11-10',
          teknisiId: 'tek_ryan',
          teknisiNama: 'Ryan Lumasuge',
          posName: 'Pos 1',
          posTag: 'P1',
          judul: 'Local tech task',
          kategori: 'error',
          status: TaskStatus.pending,
          serahTerima: 'Ryan Lumasuge||Daftar terbuka|13 Nov 05:52',
        ),
      ];
      await DailyTaskService.cacheTasksLocallyForTesting(technicianOwnCache);

      // 3. Network fails -> fallback prefers in-memory _lastServerResult over local technician cache
      DailyTaskService.clientOverride = _FailingHttpClient();
      final fallbackResult = await ErrorTicketService.fetchOpen();
      expect(fallbackResult.length, equals(1));
      expect(fallbackResult.first.id, equals('server_spv_err_1'));
      expect(fallbackResult.first.teknisiNama, equals('Farhan Lakoro (SPV)'));
    });

    test('fetchOpen excludes claimed server tickets once serah_terima has a claimer', () async {
      final unclaimed = {
        'id': 'err_unclaimed',
        'tanggal': '2026-11-13',
        'teknisi_id': '',
        'teknisi_nama': 'fatma',
        'pos_name': 'Pos Barat',
        'pos_tag': 'PB',
        'judul': 'Gate macet',
        'deskripsi': 'Gate macet',
        'kategori': 'error',
        'status': 'pending',
        'serah_terima': 'fatma||Daftar terbuka|13 Nov 05:52',
      };
      final claimed = {
        'id': 'err_claimed',
        'tanggal': '2026-11-13',
        'teknisi_id': '',
        'teknisi_nama': 'Budi',
        'pos_name': 'Pos Timur',
        'pos_tag': 'PT',
        'judul': 'Printer rusak',
        'deskripsi': 'Printer rusak',
        'kategori': 'error',
        'status': 'pending',
        'serah_terima': 'a||Daftar terbuka|13 Nov 05:52\na|Budi|Ambil tugas terbuka|13 Nov 06:00',
      };

      DailyTaskService.clientOverride = _SuccessHttpClient(jsonEncode([claimed, unclaimed]));
      final result = await ErrorTicketService.fetchOpen();
      expect(result.map((t) => t.id).toList(), equals(['err_unclaimed']));
    });
  });
}
