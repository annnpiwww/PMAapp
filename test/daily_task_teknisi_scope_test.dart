import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

const _tanggal = '2026-11-05';
const _nama = 'Ryan Lumasuge';

Map<String, dynamic> _row({
  required String id,
  required String owner,
  String peserta = '',
  String status = 'pending',
  String tanggal = _tanggal,
}) =>
    {
      'id': id,
      'tanggal': tanggal,
      'teknisi_nama': owner,
      'peserta': peserta,
      'pos_name': 'PBM',
      'pos_tag': 'PBM',
      'judul': 'Tugas $id',
      'status': status,
      'foto_bukti': <String>[],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final rows = [
    _row(id: 'a', owner: _nama),
    _row(id: 'b', owner: 'Raldy Sangkop', peserta: 'Ryan Lumasuge, Junifer Manua'),
    _row(id: 'c', owner: 'Junifer Manua'),
    _row(id: 'd', owner: 'Alessandro Sulistyo', peserta: 'Raldy Sangkop'),
  ];

  late List<http.Request> requests;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
    requests = [];
    DailyTaskService.clientOverride = MockClient((req) async {
      requests.add(req);
      return http.Response(jsonEncode(rows), 200, headers: {'content-type': 'application/json'});
    });
  });

  tearDown(() {
    DailyTaskService.clientOverride = null;
    BranchService.instance.resetForTesting();
  });

  test('request is scoped by technician server-side and keeps status/tanggal scoping', () async {
    await DailyTaskService.getTasksForTeknisi(tanggal: _tanggal, teknisiNama: _nama);

    expect(requests, hasLength(1));
    final params = requests.single.url.queryParameters;
    final filter = params['and'];
    expect(filter, isNotNull);
    expect(filter, contains('or(status.eq.pending,tanggal.eq.$_tanggal)'));
    expect(filter, contains('teknisi_nama.ilike.*Ryan*'));
    expect(filter, contains('teknisi_nama.ilike.*Lumasuge*'));
    expect(filter, contains('peserta.ilike.*Ryan*'));
    expect(params['limit'], '100');
    expect(params['order'], 'created_at.desc');
  });

  test('reserved PostgREST characters in the name are stripped from the filter', () async {
    await DailyTaskService.getTasksForTeknisi(tanggal: _tanggal, teknisiNama: 'Ryan (Lumasuge), *Jr.*');

    final filter = requests.single.url.queryParameters['and']!;
    final group = filter.substring(filter.lastIndexOf('or(') + 3, filter.length - 2);
    for (final part in group.split(',')) {
      if (part.startsWith('and(kategori.') || part.startsWith('status.eq.')) continue;
      expect(
        part,
        matches(RegExp(r'^(teknisi_nama|peserta)\.ilike\.\*[^,()*:.]+\*$')),
        reason: 'un-sanitized filter segment: $part',
      );
    }
    expect(filter, contains('and(kategori.eq.error,status.eq.pending)'));
    expect(filter, contains('teknisi_nama.ilike.*Jr*'));
  });

  test('result equals the old client-side isAssignedTo filter', () async {
    final result = await DailyTaskService.getTasksForTeknisi(tanggal: _tanggal, teknisiNama: _nama);

    final expected = rows
        .map((r) => DailyTaskModel.fromJson(r))
        .where((t) => DailyTaskService.isAssignedTo(t, _nama))
        .map((t) => t.id)
        .toSet();
    expect(result.map((t) => t.id).toSet(), expected);
    expect(expected, {'a', 'b'});
  });

  test('empty technician name skips the server and uses the offline cache', () async {
    final result = await DailyTaskService.getTasksForTeknisi(tanggal: _tanggal, teknisiNama: '   ');
    expect(requests, isEmpty);
    expect(result, isEmpty);
  });

  test('unreachable server keeps the offline fallback path', () async {
    DailyTaskService.clientOverride = MockClient((req) async => throw http.ClientException('offline'));

    final created = await DailyTaskService.createTask(
      tanggal: _tanggal,
      teknisiNama: _nama,
      posName: 'PBM',
      posTag: 'PBM',
      judul: 'Tugas offline',
    );
    expect(created!.id, startsWith('local_'));

    final result = await DailyTaskService.getTasksForTeknisi(tanggal: _tanggal, teknisiNama: _nama);
    expect(result.map((t) => t.id), contains(created.id));
  });
}
