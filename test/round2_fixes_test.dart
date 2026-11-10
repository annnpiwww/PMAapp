import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/repositories/template_repository.dart';
import 'package:bssparking_timemark/data/services/absensi_setup_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/google_sheets_service.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/maintenance_log_service.dart';
import 'package:bssparking_timemark/data/services/photo_cleanup_service.dart';
import 'package:bssparking_timemark/data/services/secure_time_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/camera/screens/camera_capture_screen.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_map_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    SecureTimeService.reset();
    GoogleSheetsService.clientOverride = null;
    DailyTaskService.clientOverride = null;
    LocationService.testLocationOverride = null;
    LocationService.clearLocationCache();
  });

  tearDown(() {
    SecureTimeService.reset();
    GoogleSheetsService.clientOverride = null;
    DailyTaskService.clientOverride = null;
    LocationService.testLocationOverride = null;
    LocationService.clearLocationCache();
  });

  group('A. CODE-03: perlu_cek_manual is a reminder, NOT a temuan', () {
    test('MaintenanceLogEntry and PosMaintenanceStatus treat only tidak_sesuai as temuan', () {
      final subReminderOnly = MaintenanceSubmission(
        id: 'sub_reminder',
        templateId: 'tpl_maint_pos',
        templateName: 'Maintenance: Pos Parkir & Booth',
        userId: 'u1',
        userName: 'Budi',
        userNpp: '123',
        posId: 'POS-PBM-01',
        posName: 'Pasar Bersehati Manado',
        cabangName: 'KC BSG',
        createdAt: DateTime(2026, 11, 16, 10, 0),
        updatedAt: DateTime(2026, 11, 16, 10, 5),
        points: const [
          MaintenancePointResult(
            pointId: 'pos_1_01',
            label: 'Pos 1 - Printer Pos',
            status: PointStatus.sesuai,
            alasan: 'Printer bersih',
          ),
          MaintenancePointResult(
            pointId: 'pos_1_02',
            label: 'Pos 1 - Jalur Kabel',
            status: PointStatus.perluCekManual,
            alasan: 'Foto agak gelap, cek fisik di lokasi',
          ),
        ],
      );

      final entry = MaintenanceLogEntry.fromSubmission(subReminderOnly);
      // perlu_cek_manual tetap disimpan di JSON temuan agar halaman detail bisa menampilkan
      expect(entry.temuan.length, 1);
      expect(entry.temuan.first.status, 'perlu_cek_manual');
      // Tetapi hasTemuan harus false karena bukan tidak_sesuai
      expect(entry.hasTemuan, isFalse);

      const loc = PosLocation(
        posId: 'POS-PBM-01',
        posName: 'Pasar Bersehati Manado',
        cabangName: 'KC BSG',
        fullAddress: 'Jl. Nusantara',
        locationTag: 'PBM',
        tagColor: Colors.blue,
        lat: 1.48,
        lng: 124.84,
      );

      final status = PosMaintenanceStatus(
        location: loc,
        wilayah: 'Manado',
        logs: [entry],
      );

      expect(status.adaTemuan, isFalse);
      expect(status.hasPhaseTemuan(2), isFalse);
      expect(status.statusForPhase(2), 'selesai_aman');

      final extracted = MaintenanceMapScreen.extractTemuanItems(
        statuses: [status],
        isCurrentMonth: true,
        selectedMonth: DateTime(2026, 11, 1),
        now: DateTime(2026, 11, 16),
      );
      expect(extracted, isEmpty);
    });

    test('GoogleSheetsService poinMasalahCount excludes perlu_cek_manual', () async {
      await GoogleSheetsService.saveAppsScriptUrl('https://script.google.com/macros/s/test/exec');
      await GoogleSheetsService.saveSecretToken('sec-token');

      Map<String, dynamic>? sentPayload;
      GoogleSheetsService.clientOverride = MockClient((req) async {
        sentPayload = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response('OK', 200);
      });

      final sub = MaintenanceSubmission(
        id: 'sub_gs_code03',
        templateId: 'tpl_maint_pos',
        templateName: 'Maintenance: Pos Parkir & Booth',
        userId: 'u1',
        userName: 'Budi',
        userNpp: '123',
        posId: 'POS-PBM-01',
        posName: 'Pasar Bersehati Manado',
        cabangName: 'KC BSG',
        createdAt: DateTime(2026, 11, 7, 10, 0),
        updatedAt: DateTime(2026, 11, 7, 10, 5),
        points: const [
          MaintenancePointResult(
            pointId: 'pos_1_01',
            label: 'Pos 1 - Printer',
            status: PointStatus.sesuai,
          ),
          MaintenancePointResult(
            pointId: 'pos_1_02',
            label: 'Pos 1 - Kabel',
            status: PointStatus.perluCekManual,
            alasan: 'Cek manual',
          ),
          MaintenancePointResult(
            pointId: 'pos_1_03',
            label: 'Pos 1 - Kipas',
            status: PointStatus.tidakSesuai,
            alasan: 'Kipas mati',
          ),
        ],
      );

      final ok = await GoogleSheetsService.syncMaintenanceToGoogleSheet(
        submission: sub,
        category: TemplateCategory.maintPos,
      );
      expect(ok, isTrue);
      expect(sentPayload, isNotNull);
      expect(sentPayload!['poinMasalahCount'], 1);
    });
  });

  group('B. CODE-08: SOP criteria alignment (no thermal paste, no mandatory cable ties, no speedbump dynabolt)', () {
    test('TemplateRepository defaultTemplates have updated srv_04, srv_05, pos_02, and bar_09', () {
      final serverTpl = TemplateRepository.defaultTemplates.firstWhere(
        (t) => t.id == 'tpl_maint_server',
      );
      final srv04 = serverTpl.sopPoints.firstWhere((p) => p.id == 'srv_04');
      expect(
        srv04.checkpoints.any((c) => c.contains('Kipas dan heatsink bersih dari debu')),
        isTrue,
      );
      expect(
        srv04.checkpoints.join(' ').toLowerCase().contains('pasta'),
        isFalse,
      );

      final srv05 = serverTpl.sopPoints.firstWhere((p) => p.id == 'srv_05');
      expect(
        srv05.deskripsi.contains('tertata rapi, tidak semrawut'),
        isTrue,
      );
      expect(
        srv05.checkpoints.join(' ').toLowerCase().contains('cable tie'),
        isFalse,
      );

      final posTpl = TemplateRepository.defaultTemplates.firstWhere(
        (t) => t.id == 'tpl_maint_pos',
      );
      final pos02 = posTpl.sopPoints.firstWhere((p) => p.id == 'pos_02');
      expect(
        pos02.deskripsi.contains('tertata rapi, tidak semrawut'),
        isTrue,
      );
      expect(
        pos02.checkpoints.join(' ').toLowerCase().contains('kabel ties'),
        isFalse,
      );

      final barTpl = TemplateRepository.defaultTemplates.firstWhere(
        (t) => t.id == 'tpl_maint_barrier',
      );
      final bar09 = barTpl.sopPoints.firstWhere((p) => p.id == 'bar_09');
      expect(bar09.deskripsi.toLowerCase().contains('dinabolt'), isFalse);
      expect(bar09.deskripsi.toLowerCase().contains('dynabolt'), isFalse);
    });
  });

  group('C & D. CODE-13 & CODE-14: pulangAllowedFrom, isLateCheckIn, and verified hariKerja', () {
    test('pulangAllowedFrom unlocks at shift end even if late, handles cross-midnight, and unlocks immediately after shift end', () {
      // Late daytime check-in (10:45 on 10:00 - 18:00 shift) -> still unlocks at 18:00
      final gateLateDay = AbsensiSetupService.pulangAllowedFrom(
        shift: 'Shift 2 (10:00 - 18:00)',
        checkInTime: DateTime(2026, 11, 7, 10, 45),
      );
      expect(gateLateDay, DateTime(2026, 11, 7, 18, 0));

      // Checked in after shift end (18:15 on 10:00 - 18:00 shift) -> unlocks immediately
      final checkInAfterEnd = DateTime(2026, 11, 7, 18, 15);
      final gateImmediate = AbsensiSetupService.pulangAllowedFrom(
        shift: 'Shift 2 (10:00 - 18:00)',
        checkInTime: checkInAfterEnd,
      );
      expect(gateImmediate, checkInAfterEnd);

      // Cross-midnight Bali Shift 3 (22.00 - 06.00): check-in Nov 7 22:10 -> Nov 8 06:00
      final gateCrossMidnight = AbsensiSetupService.pulangAllowedFrom(
        shift: 'Shift 3 (22.00 - 06.00)',
        checkInTime: DateTime(2026, 11, 7, 22, 10),
      );
      expect(gateCrossMidnight, DateTime(2026, 11, 8, 6, 0));

      // Cross-midnight HO Shift 3 (24.00 - 08.00): check-in Nov 7 23:50 -> Nov 8 08:00
      final gateHoMidnight = AbsensiSetupService.pulangAllowedFrom(
        shift: 'Shift 3 (24.00 - 08.00)',
        checkInTime: DateTime(2026, 11, 7, 23, 50),
      );
      expect(gateHoMidnight, DateTime(2026, 11, 8, 8, 0));

      // Cross-midnight HO JP (17.00 - 01.00): check-in Nov 7 17:05 -> Nov 8 01:00
      final gateJp = AbsensiSetupService.pulangAllowedFrom(
        shift: 'JP (17.00 - 01.00)',
        checkInTime: DateTime(2026, 11, 7, 17, 5),
      );
      expect(gateJp, DateTime(2026, 11, 8, 1, 0));
    });

    test('isLateCheckIn handles 03:00, 22:00->06:00, 24:00->08:00, and 17:00->01:00', () {
      // 03:00 shift
      expect(
        AbsensiSetupService.isLateCheckIn('Shift 1 (03:00 - 11:00)', DateTime(2026, 11, 7, 23, 50)),
        isFalse,
      );
      expect(
        AbsensiSetupService.isLateCheckIn('Shift 1 (03:00 - 11:00)', DateTime(2026, 11, 7, 3, 0)),
        isFalse,
      );
      expect(
        AbsensiSetupService.isLateCheckIn('Shift 1 (03:00 - 11:00)', DateTime(2026, 11, 7, 3, 5)),
        isTrue,
      );

      // 22.00 - 06.00 shift
      expect(
        AbsensiSetupService.isLateCheckIn('Shift 3 (22.00 - 06.00)', DateTime(2026, 11, 7, 21, 55)),
        isFalse,
      );
      expect(
        AbsensiSetupService.isLateCheckIn('Shift 3 (22.00 - 06.00)', DateTime(2026, 11, 7, 22, 5)),
        isTrue,
      );
      expect(
        AbsensiSetupService.isLateCheckIn('Shift 3 (22.00 - 06.00)', DateTime(2026, 11, 8, 0, 15)),
        isTrue,
      );

      // 24.00 - 08.00 shift
      expect(
        AbsensiSetupService.isLateCheckIn('Shift 3 (24.00 - 08.00)', DateTime(2026, 11, 7, 23, 45)),
        isFalse,
      );
      expect(
        AbsensiSetupService.isLateCheckIn('Shift 3 (24.00 - 08.00)', DateTime(2026, 11, 8, 0, 0)),
        isFalse,
      );
      expect(
        AbsensiSetupService.isLateCheckIn('Shift 3 (24.00 - 08.00)', DateTime(2026, 11, 8, 0, 5)),
        isTrue,
      );

      // 17.00 - 01.00 shift
      expect(
        AbsensiSetupService.isLateCheckIn('JP (17.00 - 01.00)', DateTime(2026, 11, 7, 17, 0)),
        isFalse,
      );
      expect(
        AbsensiSetupService.isLateCheckIn('JP (17.00 - 01.00)', DateTime(2026, 11, 7, 17, 10)),
        isTrue,
      );
      expect(
        AbsensiSetupService.isLateCheckIn('JP (17.00 - 01.00)', DateTime(2026, 11, 8, 0, 20)),
        isTrue,
      );
    });

    test('CODE-14: hariKerja uses SecureTimeService verified time instead of raw DateTime.now()', () {
      // Simulate device clock at Monday 23:50, but server offset is +3600s (Tuesday 00:50)
      final fakeNow = DateTime(2026, 11, 2, 23, 50); // Monday
      SecureTimeService.clock = () => fakeNow;
      SecureTimeService.setMockOffset(3600);

      expect(AbsensiSetupService.instance.hariKerja, 'SELASA');
    });
  });

  group('E. CODE-02: SecureTimeService sleep wake & non-sticky reset', () {
    test('does not flag false [JAM DIUBAH MANUAL] on Android sleep wake and resets sticky flags on clean sync', () async {
      var deviceClock = DateTime.utc(2026, 11, 7, 8, 0, 0);
      var serverClock = DateTime.utc(2026, 11, 7, 8, 0, 0);

      SecureTimeService.clock = () => deviceClock;
      SecureTimeService.clientOverride = MockClient((req) async {
        return http.Response(
          '',
          204,
          headers: {'date': HttpDate.format(serverClock)},
        );
      });

      // 1. Initial clean sync
      await SecureTimeService.syncNetworkTime();
      expect(SecureTimeService.getVerifiedTime().isTampered, isFalse);
      expect(SecureTimeService.warningTag, isNull);

      // 2. Simulate Android deep sleep for 20 minutes: wall clock & server clock advance 20m,
      // while Stopwatch barely moves. Must NOT flag [JAM DIUBAH MANUAL].
      deviceClock = deviceClock.add(const Duration(minutes: 20));
      serverClock = serverClock.add(const Duration(minutes: 20));
      final afterSleep = SecureTimeService.getVerifiedTime();
      expect(afterSleep.isTampered, isFalse);
      expect(afterSleep.warningTag, isNull);

      // 3. Simulate real manual clock tampering (+10 minutes ahead of server)
      deviceClock = serverClock.add(const Duration(minutes: 10));
      await SecureTimeService.syncNetworkTime();
      final tampered = SecureTimeService.getVerifiedTime();
      expect(tampered.isTampered, isTrue);
      expect(tampered.warningTag, '[JAM DIUBAH MANUAL]');

      // 4. Technician restores automatic network time (offset 0s) and re-syncs -> flags reset!
      deviceClock = serverClock;
      await SecureTimeService.syncNetworkTime();
      final restored = SecureTimeService.getVerifiedTime();
      expect(restored.isTampered, isFalse);
      expect(restored.warningTag, isNull);
      expect(SecureTimeService.isTampered, isFalse);
    });
  });

  group('F. CODE-01: GoogleSheetsService HTTP 302 success and full 19-field offline payload', () {
    final sampleSub = MaintenanceSubmission(
      id: 'sub_gs_code01',
      templateId: 'tpl_maint_barrier',
      templateName: 'Maintenance: Barrier Gate',
      userId: 'u1',
      userName: 'Junifer',
      userNpp: '101',
      posId: 'POS-PBM-01',
      posName: 'Pasar Bersehati Manado',
      cabangName: 'KC BSG',
      createdAt: DateTime(2026, 11, 7, 9, 0),
      updatedAt: DateTime(2026, 11, 7, 9, 10),
      points: const [
        MaintenancePointResult(
          pointId: 'bar_1_01',
          label: 'Barrier 1 - Dudukan Mesin',
          status: PointStatus.sesuai,
        ),
        MaintenancePointResult(
          pointId: 'bar_1_02',
          label: 'Barrier 1 - Palang',
          status: PointStatus.tidakSesuai,
          alasan: 'Palang miring',
          urgensi: TingkatUrgensi.urgent,
        ),
      ],
    );

    test('treats HTTP 302 redirect from Google Apps Script as success without queuing duplicate', () async {
      await GoogleSheetsService.saveAppsScriptUrl('https://script.google.com/macros/s/test/exec');
      await GoogleSheetsService.saveSecretToken('token-123');

      GoogleSheetsService.clientOverride = MockClient((req) async {
        return http.Response('Moved Temporarily', 302);
      });

      final ok = await GoogleSheetsService.syncMaintenanceToGoogleSheet(
        submission: sampleSub,
        category: TemplateCategory.maintBarrier,
      );
      expect(ok, isTrue);

      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList('bss_pending_gsheet_queue_v1') ?? [];
      expect(queue, isEmpty);
    });

    test('enqueues full 19-field payload on network exception and flushes on HTTP 302', () async {
      await GoogleSheetsService.saveAppsScriptUrl('https://script.google.com/macros/s/test/exec');
      await GoogleSheetsService.saveSecretToken('token-123');

      GoogleSheetsService.clientOverride = MockClient((req) async {
        throw const SocketException('No internet');
      });

      final ok = await GoogleSheetsService.syncMaintenanceToGoogleSheet(
        submission: sampleSub,
        category: TemplateCategory.maintBarrier,
      );
      expect(ok, isFalse);

      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList('bss_pending_gsheet_queue_v1') ?? [];
      expect(queue.length, 1);

      final queuedMap = jsonDecode(queue.first) as Map<String, dynamic>;
      expect(queuedMap.length, 19);
      expect(queuedMap['perangkat'], 'Maintenance: Barrier Gate');
      expect(queuedMap['totalPoin'], 2);
      expect(queuedMap['poinLolosCount'], 1);
      expect(queuedMap['poinMasalahCount'], 1);
      expect(queuedMap['urgentCount'], 1);

      // Now online returning 302 -> flushPendingQueue succeeds
      GoogleSheetsService.clientOverride = MockClient((req) async {
        return http.Response('Redirect', 302);
      });
      final flushed = await GoogleSheetsService.flushPendingQueue();
      expect(flushed, 1);
      expect(prefs.getStringList('bss_pending_gsheet_queue_v1'), isEmpty);
    });
  });

  group('G. CODE-15: DailyTaskService exact technician match & atomic claimTask', () {
    test('isAssignedTo matches exact normalized full name and rejects partial token collisions', () {
      final task = DailyTaskModel(
        id: 't1',
        tanggal: '2026-11-07',
        teknisiId: '',
        teknisiNama: 'Andi Saputra',
        posName: 'Pos Simpang Lima',
        posTag: 'SL',
        judul: 'Cek Pos',
        deskripsi: 'Cek',
        peserta: 'Budi   Santoso,  Ari Wibowo',
        status: TaskStatus.pending,
      );

      expect(DailyTaskService.isAssignedTo(task, 'andi saputra'), isTrue);
      expect(DailyTaskService.isAssignedTo(task, '  Budi Santoso  '), isTrue);
      expect(DailyTaskService.isAssignedTo(task, 'ari wibowo'), isTrue);

      // Must NOT match partial names or 3-letter substring collisions
      expect(DailyTaskService.isAssignedTo(task, 'Andi'), isFalse);
      expect(DailyTaskService.isAssignedTo(task, 'Andika Saputra'), isFalse);
      expect(DailyTaskService.isAssignedTo(task, 'Bahari'), isFalse);
      expect(DailyTaskService.isAssignedTo(task, ''), isFalse);
    });

    test('claimTask sends status=eq.pending & teknisi_nama filter and returns false when 0 rows updated', () async {
      Uri? capturedUri;
      DailyTaskService.clientOverride = MockClient((req) async {
        if (req.url.path.contains('daily-tasks')) {
          return http.Response('{"error":"not_found"}', 404);
        }
        if (req.method == 'PATCH') {
          capturedUri = req.url;
        }
        return http.Response('[]', 200);
      });

      final openTask = DailyTaskModel(
        id: 'task_open_1',
        tanggal: '2026-11-07',
        teknisiId: '',
        teknisiNama: 'Teknisi Lama',
        posName: 'Pos Simpang Lima',
        posTag: 'SL',
        judul: 'Perbaikan Barrier',
        deskripsi: 'Gate 1',
        serahTerima: 'Teknisi Lama||Oper shift|08:00',
        status: TaskStatus.pending,
      );

      final claimed = await DailyTaskService.claimTask(
        task: openTask,
        olehSiapa: 'Teknisi Baru',
      );

      expect(claimed.success, isFalse);
      expect(capturedUri, isNotNull);
      expect(capturedUri!.queryParameters['id'], 'eq.task_open_1');
      expect(capturedUri!.queryParameters['status'], 'eq.pending');
      expect(capturedUri!.queryParameters['teknisi_nama'], 'eq.Teknisi Lama');
    });
  });

  group('H. SEC-06: Block absensi shutter when GPS has no fix or is mocked', () {
    test('LocationService.getCurrentLocation fallback never substitutes POS coordinates', () async {
      final res = await LocationService.getCurrentLocation(simulateGpsOff: true);
      expect(res.lat, 0.0);
      expect(res.lng, 0.0);
      expect(res.isGpsEnabled, isFalse);
      expect(res.isFallback, isTrue);
      expect(res.isDefaultFallback, isTrue);
    });

    testWidgets('CameraCaptureScreen blocks shutter with message and retry button when GPS has no fix', (tester) async {
      LocationService.testLocationOverride = () async => LocationResult(
            lat: 0.0,
            lng: 0.0,
            accuracyMeter: 0.0,
            isGpsEnabled: false,
            isMockLocation: false,
            isFallback: true,
            isDefaultFallback: true,
            posName: 'Pasar Bersehati Manado',
            cabangName: 'KC BSG',
            fullAddress: 'Manado',
            locationTag: 'PBM',
          );

      await tester.pumpWidget(
        const MaterialApp(
          home: CameraCaptureScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.text('GPS belum mengunci. Pindah ke area terbuka lalu coba lagi.'),
        findsOneWidget,
      );
      expect(find.text('Coba Lagi'), findsOneWidget);

      final shutterSemantics = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Ambil foto verifikasi',
      );
      expect(shutterSemantics, findsOneWidget);
      expect(
        tester.widget<Semantics>(shutterSemantics).properties.enabled,
        isFalse,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('CameraCaptureScreen blocks shutter with fake GPS message when position.isMocked is true', (tester) async {
      LocationService.testLocationOverride = () async => LocationResult(
            lat: 1.48,
            lng: 124.84,
            accuracyMeter: 5.0,
            isGpsEnabled: true,
            isMockLocation: true,
            isFallback: false,
            isDefaultFallback: false,
            posName: 'Pasar Bersehati Manado',
            cabangName: 'KC BSG',
            fullAddress: 'Manado',
            locationTag: 'PBM',
          );

      await tester.pumpWidget(
        const MaterialApp(
          home: CameraCaptureScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.text('Lokasi palsu terdeteksi. Matikan aplikasi lokasi palsu.'),
        findsOneWidget,
      );
      expect(find.text('Coba Lagi'), findsOneWidget);

      final shutterSemantics = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Ambil foto verifikasi',
      );
      expect(shutterSemantics, findsOneWidget);
      expect(
        tester.widget<Semantics>(shutterSemantics).properties.enabled,
        isFalse,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  group('I. SEC-10: No auto-save to public gallery & 7-day app-internal cleanup', () {
    test('camera_capture_screen.dart does not call ShareHelper.savePhotoToGallery', () {
      final src = File('lib/features/camera/screens/camera_capture_screen.dart')
          .readAsStringSync();
      expect(src.contains('ShareHelper.savePhotoToGallery('), isFalse);
    });

    test('PhotoCleanupService.cleanOldPhotos(maxDays: 7) deletes photos older than 7 days and keeps recent ones', () async {
      final tempDir = await Directory.systemTemp.createTemp('bss_sec10_test_');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final oldFile = File('${tempDir.path}/old_photo.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      await oldFile.setLastModified(
        DateTime.now().subtract(const Duration(days: 8)),
      );

      final recentFile = File('${tempDir.path}/recent_photo.jpg')
        ..writeAsBytesSync([4, 5, 6]);
      await recentFile.setLastModified(
        DateTime.now().subtract(const Duration(days: 2)),
      );

      final deleted = await PhotoCleanupService.cleanOldPhotos(
        maxDays: 7,
        targetDirs: [tempDir],
      );

      expect(deleted, 1);
      expect(oldFile.existsSync(), isFalse);
      expect(recentFile.existsSync(), isTrue);
    });
  });
}
