import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/error_ticket_service.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/notification_service.dart';
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

  group('fetchOpen offline fallback filters kategori and status', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      DailyTaskService.clientOverride = null;
    });

    tearDown(() {
      DailyTaskService.clientOverride = null;
    });

    test('pure filterOpenTickets filters kategori == error and status != completed', () {
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
        ),
      ];

      await DailyTaskService.cacheTasksLocallyForTesting(cachedList);
      DailyTaskService.clientOverride = _FailingHttpClient();

      final result = await ErrorTicketService.fetchOpen();
      expect(result.length, equals(1));
      expect(result.first.id, equals('cached_err_1'));
      expect(result.first.judul, equals('Cached error pending'));
    });
  });

  group('Notification seeding and error ticket polling in DailyTaskService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      DailyTaskService.resetKnownPendingTaskIdsForTesting();
      DailyTaskService.resetKnownErrorTicketIdsForTesting();
      NotificationService.instance.clearSentErrorTicketNotificationsForTesting();
    });

    tearDown(() {
      DailyTaskService.clientOverride = null;
    });

    test('first poll no notification, second poll with new ticket by another user -> 1 notification, ticket by self -> 0', () async {
      final initialTicket = {
        'id': 'err_101',
        'tanggal': '2026-11-10',
        'teknisi_id': 'tek_farhan',
        'teknisi_nama': 'Farhan Lakoro',
        'pos_name': 'Pos Barat',
        'pos_tag': 'PB',
        'judul': 'Printer macet awal',
        'deskripsi': 'Detail error 1',
        'kategori': 'error',
        'status': 'pending',
      };

      // Poll 1: Initial ticket exists. Empty stored set -> seed silently, no notification.
      DailyTaskService.clientOverride = _SuccessHttpClient(jsonEncode([initialTicket]));

      await DailyTaskService.checkNewTasksForTesting('Ryan Lumasuge');

      expect(
        NotificationService.instance.sentErrorTicketNotificationsForTesting,
        isEmpty,
        reason: 'First poll must seed silently without sending notifications',
      );
      expect(
        StorageService.getKnownErrorTicketIds(),
        contains('err_101'),
        reason: 'Known error ticket IDs must be persisted to StorageService',
      );

      // Poll 2: New ticket from another user ('Farhan Lakoro' vs listener 'Ryan Lumasuge') -> 1 notification.
      final newTicketFromOther = {
        'id': 'err_102',
        'tanggal': '2026-11-10',
        'teknisi_id': 'tek_farhan',
        'teknisi_nama': 'Farhan Lakoro',
        'pos_name': 'Gate 2',
        'pos_tag': 'G2',
        'judul': 'Barrier gate patah',
        'deskripsi': 'Detail error 2',
        'kategori': 'error',
        'status': 'pending',
      };

      DailyTaskService.clientOverride = _SuccessHttpClient(
        jsonEncode([initialTicket, newTicketFromOther]),
      );

      await DailyTaskService.checkNewTasksForTesting('Ryan Lumasuge');

      final sentList = NotificationService.instance.sentErrorTicketNotificationsForTesting;
      expect(sentList.length, equals(1));
      expect(sentList.first['id'], equals('err_102'));
      expect(sentList.first['posName'], equals('Gate 2'));
      expect(sentList.first['judul'], equals('Barrier gate patah'));
      expect(StorageService.getKnownErrorTicketIds(), contains('err_102'));

      // Poll 3: New ticket from self ('Ryan Lumasuge' vs listener 'Ryan Lumasuge') -> 0 new notification.
      final newTicketFromSelf = {
        'id': 'err_103',
        'tanggal': '2026-11-10',
        'teknisi_id': 'tek_ryan',
        'teknisi_nama': 'Ryan Lumasuge',
        'pos_name': 'TBM',
        'pos_tag': 'TBM',
        'judul': 'Tiket buatan saya sendiri',
        'deskripsi': 'Detail error 3',
        'kategori': 'error',
        'status': 'pending',
      };

      DailyTaskService.clientOverride = _SuccessHttpClient(
        jsonEncode([initialTicket, newTicketFromOther, newTicketFromSelf]),
      );

      await DailyTaskService.checkNewTasksForTesting('Ryan Lumasuge');

      // Still 1 notification total
      expect(
        NotificationService.instance.sentErrorTicketNotificationsForTesting.length,
        equals(1),
        reason: 'Ticket created by self must not trigger local notification',
      );
      expect(StorageService.getKnownErrorTicketIds(), contains('err_103'));
    });
  });
}
