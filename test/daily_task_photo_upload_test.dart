import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late List<String> photos;
  late String? patchBody;
  late int inFlight;
  late int maxInFlight;
  late int uploads;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
    tempDir = Directory.systemTemp.createTempSync('task_proof_');
    photos = List.generate(5, (i) {
      final f = File('${tempDir.path}/photo_$i.jpg')..writeAsBytesSync([i + 1, i + 2, i + 3]);
      return f.path;
    });
    patchBody = null;
    inFlight = 0;
    maxInFlight = 0;
    uploads = 0;
  });

  tearDown(() {
    DailyTaskService.clientOverride = null;
    BranchService.instance.resetForTesting();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  void installFake({bool failThirdUpload = false}) {
    DailyTaskService.clientOverride = MockClient((req) async {
      if (req.url.path.contains('/storage/v1/object/task-proofs/')) {
        uploads++;
        inFlight++;
        if (inFlight > maxInFlight) maxInFlight = inFlight;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        inFlight--;
        final failed = failThirdUpload && req.url.path.contains('_3_');
        return http.Response('', failed ? 500 : 200);
      }
      patchBody = req.body;
      return http.Response('[{"id":"task_perf_1"}]', 200, headers: {'content-type': 'application/json'});
    });
  }

  test('5 photos upload with at most 3 in flight and keep their order', () async {
    installFake();

    final ok = await DailyTaskService.completeTask(
      taskId: 'task_perf_1',
      jamSelesai: '16:20',
      localPhotoPaths: photos,
    );

    expect(ok, isTrue);
    expect(uploads, 5);
    expect(maxInFlight, lessThanOrEqualTo(3));
    expect(maxInFlight, greaterThan(1));

    final urls = (jsonDecode(patchBody!)['foto_bukti'] as List).cast<String>();
    expect(urls, hasLength(5));
    for (var i = 0; i < 5; i++) {
      expect(urls[i], contains('proof_task_perf_1_${i + 1}_'));
    }
  });

  test('a single failed upload is skipped like the sequential loop did', () async {
    installFake(failThirdUpload: true);

    final ok = await DailyTaskService.completeTask(
      taskId: 'task_perf_1',
      jamSelesai: '16:25',
      localPhotoPaths: photos,
    );

    expect(ok, isTrue);
    final urls = (jsonDecode(patchBody!)['foto_bukti'] as List).cast<String>();
    expect(urls, hasLength(4));
    expect(urls.any((u) => u.contains('_3_')), isFalse);
    expect(urls[2], contains('_4_'));
    expect(urls[3], contains('_5_'));
  });
}
