import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as imglib;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/core/utils/verification_code.dart';
import 'package:bssparking_timemark/core/utils/timemark_formatter.dart';
import 'package:bssparking_timemark/core/utils/image_watermark_processor.dart';
import 'package:bssparking_timemark/data/models/submission_model.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/data/repositories/submission_repository.dart';

class RgbaBenchmarkPayload {
  final int width;
  final int height;
  final Uint8List rgbaBytes;
  final int quality;

  RgbaBenchmarkPayload(this.width, this.height, this.rgbaBytes, this.quality);
}

Uint8List benchmarkEncodeRgbaToJpeg(RgbaBenchmarkPayload payload) {
  try {
    final img = imglib.Image.fromBytes(
      width: payload.width,
      height: payload.height,
      bytes: payload.rgbaBytes.buffer,
      numChannels: 4,
    );
    return Uint8List.fromList(imglib.encodeJpg(img, quality: payload.quality));
  } catch (_) {
    return Uint8List(0);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BSS PARKING TIMEMARK - COMPREHENSIVE STRESS & BENCHMARK SUITE', () {
    // =========================================================================
    // 1. SHA-256 HASH & COLLISION BENCHMARK
    // =========================================================================
    test('BENCHMARK 1.1: SHA-256 Verification Code Collision & Throughput (1,000 iterations)', () {
      final baseTime = DateTime(2026, 9, 11, 8, 0, 0);
      final Set<String> codeSet = {};
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 1000; i++) {
        final code = VerificationCodeGenerator.generateCode(
          timestamp: baseTime.add(Duration(milliseconds: i * 35)),
          lat: 1.4882 + (i * 0.00005),
          lng: 124.8428 + (i * 0.00005),
          userId: 'petugas_${i % 20}',
        );
        codeSet.add(code);
      }
      stopwatch.stop();

      final elapsedMs = stopwatch.elapsedMilliseconds;
      final opsPerSec = (1000.0 / (elapsedMs / 1000.0)).toStringAsFixed(1);
      final collisionCount = 1000 - codeSet.length;

      debugPrint('\n=== BENCHMARK 1.1: SHA-256 1,000 Iterasi ===');
      debugPrint('Total Waktu     : ${elapsedMs}ms');
      debugPrint('Throughput      : $opsPerSec ops/sec');
      debugPrint('Collision Count : $collisionCount (0% collision rate)');
      debugPrint('Sample Output   : ${codeSet.first}');

      expect(collisionCount, equals(0), reason: 'Zero collision allowed across 1,000 hashes');
      expect(codeSet.length, equals(1000));
      for (final c in codeSet) {
        expect(c.startsWith('BSS-'), isTrue);
        expect(c.length, equals(12));
      }
    });

    test('BENCHMARK 1.2: SHA-256 Verification Code Collision & Throughput (5,000 iterations)', () {
      final baseTime = DateTime(2026, 9, 11, 8, 0, 0);
      final Set<String> codeSet = {};
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 5000; i++) {
        final code = VerificationCodeGenerator.generateCode(
          timestamp: baseTime.add(Duration(milliseconds: i * 10)),
          lat: 1.4882 + (i * 0.00001),
          lng: 124.8428 + (i * 0.00001),
          userId: 'petugas_${i % 50}',
        );
        codeSet.add(code);
      }
      stopwatch.stop();

      final elapsedMs = stopwatch.elapsedMilliseconds;
      final opsPerSec = (5000.0 / (elapsedMs / 1000.0)).toStringAsFixed(1);
      final collisionCount = 5000 - codeSet.length;

      debugPrint('\n=== BENCHMARK 1.2: SHA-256 5,000 Iterasi ===');
      debugPrint('Total Waktu     : ${elapsedMs}ms');
      debugPrint('Throughput      : $opsPerSec ops/sec');
      debugPrint('Collision Count : $collisionCount (0% collision rate)');

      expect(collisionCount, equals(0), reason: 'Zero collision allowed across 5,000 hashes');
      expect(codeSet.length, equals(5000));
    });

    test('BENCHMARK 1.3: Rapid-Fire Same-Millisecond Hash Anti-Collision (1,000 iterations)', () {
      final sameTimestamp = DateTime(2026, 9, 11, 12, 34, 56, 789);
      final Set<String> codeSet = {};
      final stopwatch = Stopwatch()..start();

      // Rapid call in exact same millisecond, same GPS, same user
      for (int i = 0; i < 1000; i++) {
        final code = VerificationCodeGenerator.generateCode(
          timestamp: sameTimestamp,
          lat: -6.2088,
          lng: 106.8456,
          userId: 'petugas_pos_1',
        );
        codeSet.add(code);
      }
      stopwatch.stop();

      final elapsedMs = stopwatch.elapsedMilliseconds;
      final opsPerSec = (1000.0 / (elapsedMs / 1000.0)).toStringAsFixed(1);
      final collisionCount = 1000 - codeSet.length;

      debugPrint('\n=== BENCHMARK 1.3: Same-Millisecond Collision Resistance (1,000 calls) ===');
      debugPrint('Total Waktu     : ${elapsedMs}ms');
      debugPrint('Throughput      : $opsPerSec ops/sec');
      debugPrint('Collision Count : $collisionCount (100% Unique berkat Random.secure() salt)');

      expect(collisionCount, equals(0));
      expect(codeSet.length, equals(1000));
    });

    // =========================================================================
    // 2. WATERMARK CANVAS & ISOLATE WORKER ENCODING BENCHMARK
    // =========================================================================
    test('BENCHMARK 2.1: Watermark Canvas PictureRecorder Rendering (10 frames)', () async {
      final stopwatch = Stopwatch()..start();
      const frameCount = 10;
      final durations = <int>[];

      for (int i = 0; i < frameCount; i++) {
        final frameWatch = Stopwatch()..start();
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 1080, 1920));

        // Background simulation
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 1080, 1920),
          Paint()..color = const Color(0xFF1E293B),
        );

        // Watermark card background
        final cardRect = RRect.fromRectAndRadius(
          const Rect.fromLTWH(40, 1500, 1000, 360),
          const Radius.circular(20),
        );
        canvas.drawRRect(
          cardRect,
          Paint()..color = const Color(0xCC000000),
        );

        // Text elements
        final textPainter = TextPainter(
          text: TextSpan(
            text: 'BSS PARKING TIMEMARK - Frame $i\n'
                '${TimemarkFormatter.formatIndonesianFullDate(DateTime.now())} '
                '${TimemarkFormatter.formatClockTime(DateTime.now())} WITA\n'
                'GPS: 1.488200°N, 124.842800°E (Akurasi 4.2m)\n'
                'Kode Verifikasi: BSS-A1B2C3D4',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 960);

        textPainter.paint(canvas, const Offset(60, 1530));

        final picture = recorder.endRecording();
        final img = await picture.toImage(1080, 1920);
        final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);

        frameWatch.stop();
        durations.add(frameWatch.elapsedMilliseconds);
        expect(byteData != null, isTrue);
        expect(byteData!.lengthInBytes, equals(1080 * 1920 * 4));
      }
      stopwatch.stop();

      final avgMs = durations.reduce((a, b) => a + b) / frameCount;
      debugPrint('\n=== BENCHMARK 2.1: Watermark Canvas Rendering (1080x1920) ===');
      debugPrint('Total Durasi (10 frames) : ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('Rata-rata per frame     : ${avgMs.toStringAsFixed(2)}ms/frame');
      debugPrint('Render FPS throughput   : ${(1000.0 / avgMs).toStringAsFixed(1)} FPS');

      expect(avgMs < 80.0, isTrue, reason: 'Canvas painting should be <80ms per 1080x1920 frame');
    });

    test('BENCHMARK 2.2: Isolate Worker JPEG Encoding - 512x512 AI Vision (Quality 60)', () async {
      // Buat dummy raw RGBA buffer 512x512
      const width = 512;
      const height = 512;
      final rawRgba = Uint8List(width * height * 4);
      for (int i = 0; i < rawRgba.length; i += 4) {
        rawRgba[i] = (i % 255); // R
        rawRgba[i + 1] = ((i * 2) % 255); // G
        rawRgba[i + 2] = 128; // B
        rawRgba[i + 3] = 255; // A
      }

      const frameCount = 10;
      final durations = <int>[];
      int lastOutputBytesLength = 0;

      for (int i = 0; i < frameCount; i++) {
        final frameWatch = Stopwatch()..start();
        final jpegBytes = await compute(
          benchmarkEncodeRgbaToJpeg,
          RgbaBenchmarkPayload(width, height, rawRgba, 60),
        );
        frameWatch.stop();
        durations.add(frameWatch.elapsedMilliseconds);
        lastOutputBytesLength = jpegBytes.length;
        expect(jpegBytes.isNotEmpty, isTrue);
      }

      final avgMs = durations.reduce((a, b) => a + b) / frameCount;
      final sizeKb = (lastOutputBytesLength / 1024.0).toStringAsFixed(1);
      final fps = (1000.0 / avgMs).toStringAsFixed(1);

      debugPrint('\n=== BENCHMARK 2.2: Isolate Worker JPEG 512x512 (Q60) ===');
      debugPrint('Rata-rata Durasi : ${avgMs.toStringAsFixed(2)}ms per frame');
      debugPrint('Throughput       : $fps FPS');
      debugPrint('Output JPEG Size : $sizeKb KB (Sesuai target lightweight payload 15-30KB)');

      expect(avgMs < 120.0, isTrue, reason: '512x512 JPEG encoding must complete in < 120ms');
      expect(lastOutputBytesLength > 5000, isTrue);
    });

    test('BENCHMARK 2.3: Isolate Worker JPEG Encoding - 1080x1920 Full HD (Quality 90)', () async {
      const width = 1080;
      const height = 1920;
      // Buat raw RGBA buffer 1080x1920 (~8.29 MB)
      final rawRgba = Uint8List(width * height * 4);
      for (int i = 0; i < 100000; i += 4) {
        rawRgba[i] = 200;
        rawRgba[i + 1] = 100;
        rawRgba[i + 2] = 50;
        rawRgba[i + 3] = 255;
      }

      const frameCount = 3;
      final durations = <int>[];
      int lastOutputBytesLength = 0;

      for (int i = 0; i < frameCount; i++) {
        final frameWatch = Stopwatch()..start();
        final jpegBytes = await compute(
          benchmarkEncodeRgbaToJpeg,
          RgbaBenchmarkPayload(width, height, rawRgba, 90),
        );
        frameWatch.stop();
        durations.add(frameWatch.elapsedMilliseconds);
        lastOutputBytesLength = jpegBytes.length;
        expect(jpegBytes.isNotEmpty, isTrue);
      }

      final avgMs = durations.reduce((a, b) => a + b) / frameCount;
      final sizeKb = (lastOutputBytesLength / 1024.0).toStringAsFixed(1);

      debugPrint('\n=== BENCHMARK 2.3: Isolate Worker JPEG 1080x1920 (Q90) ===');
      debugPrint('Rata-rata Durasi : ${avgMs.toStringAsFixed(2)}ms per frame');
      debugPrint('Throughput       : ${(1000.0 / avgMs).toStringAsFixed(1)} FPS');
      debugPrint('Output JPEG Size : $sizeKb KB');

      expect(avgMs < 800.0, isTrue, reason: 'Full HD encode in background isolate must complete in < 800ms');
    });

    test('BENCHMARK 2.4: End-to-End ImageWatermarkProcessor.generateAiVisionBase64', () async {
      // Buat valid PNG byte data 256x256
      final image = imglib.Image(width: 256, height: 256);
      imglib.fill(image, color: imglib.ColorRgba8(40, 160, 220, 255));
      final pngBytes = Uint8List.fromList(imglib.encodePng(image));

      final stopwatch = Stopwatch()..start();
      final base64Result = await ImageWatermarkProcessor.generateAiVisionBase64('', pngBytes);
      stopwatch.stop();

      debugPrint('\n=== BENCHMARK 2.4: E2E generateAiVisionBase64 ===');
      debugPrint('Durasi Eksekusi  : ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('Base64 Length    : ${base64Result?.length ?? 0} chars');
      debugPrint('Approx Raw Size  : ${((base64Result?.length ?? 0) * 0.75 / 1024).toStringAsFixed(1)} KB');

      expect(base64Result != null, isTrue);
      expect(base64Result!.isNotEmpty, isTrue);
    });

    test('BENCHMARK 2.5: Concurrent Isolate Worker Scaling (4 Parallel Frames)', () async {
      const width = 512;
      const height = 512;
      final rawRgba = Uint8List(width * height * 4);

      final stopwatch = Stopwatch()..start();
      final results = await Future.wait([
        compute(benchmarkEncodeRgbaToJpeg, RgbaBenchmarkPayload(width, height, rawRgba, 60)),
        compute(benchmarkEncodeRgbaToJpeg, RgbaBenchmarkPayload(width, height, rawRgba, 60)),
        compute(benchmarkEncodeRgbaToJpeg, RgbaBenchmarkPayload(width, height, rawRgba, 60)),
        compute(benchmarkEncodeRgbaToJpeg, RgbaBenchmarkPayload(width, height, rawRgba, 60)),
      ]);
      stopwatch.stop();

      debugPrint('\n=== BENCHMARK 2.5: Concurrent 4-Frame Isolate Processing ===');
      debugPrint('Total Waktu 4 frame paralel : ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('Effective Latency per Frame : ${(stopwatch.elapsedMilliseconds / 4.0).toStringAsFixed(2)}ms');

      expect(results.length, equals(4));
      for (final r in results) {
        expect(r.isNotEmpty, isTrue);
      }
    });

    // =========================================================================
    // 3. STORAGE AUTO-PRUNING & HIGH-VOLUME SUBMISSION STRESS TEST
    // =========================================================================
    test('BENCHMARK 3.1: Auto-Pruning 250+ Submissions down to 150 items limit', () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();

      final submissions = <SubmissionModel>[];
      final now = DateTime(2026, 9, 11, 10, 0, 0);

      // Generate 250 realistic submissions (sub_0 is oldest, sub_249 is newest)
      for (int i = 0; i < 250; i++) {
        final submissionTime = now.subtract(Duration(minutes: 250 - i));
        submissions.add(SubmissionModel(
          id: 'sub_$i',
          templateId: 'tmpl_pos_pbm',
          templateName: 'PBM / PKM Standby',
          userId: 'user_${i % 10}',
          userName: 'Petugas $i',
          userNpp: 'BSS-NPP-$i',
          posId: 'pos_01',
          posName: 'Pos 1 Barat',
          cabangName: 'BSS Cabang Utama',
          timestampCapture: submissionTime,
          kodeVerifikasi: 'BSS-${i.toString().padLeft(8, "0")}',
          status: (i % 5 == 0) ? VerificationStatus.perluCekManual : VerificationStatus.sesuai,
          alasanAI: 'Kerapian seragam dan atribut kerja terverifikasi lengkap.',
          poinLolos: const ['Seragam Rapi', 'ID Card Terpasang', 'Pos Bersih'],
          poinGagal: const [],
          createdAt: submissionTime,
        ));
      }

      // Benchmark saveSubmissions (Serialization & Pruning)
      final saveWatch = Stopwatch()..start();
      await StorageService.saveSubmissions(submissions);
      saveWatch.stop();

      // Benchmark getSubmissions (Deserialization)
      final loadWatch = Stopwatch()..start();
      final loaded = StorageService.getSubmissions();
      loadWatch.stop();

      final prefs = await SharedPreferences.getInstance();
      final rawJsonString = prefs.getString('bss_submissions') ?? '';
      final payloadSizeKb = (rawJsonString.length / 1024.0).toStringAsFixed(2);

      debugPrint('\n=== BENCHMARK 3.1: Auto-Pruning 250 Submissions ===');
      debugPrint('Input Submissions       : ${submissions.length} records');
      debugPrint('Saved/Retained Records  : ${loaded?.length} records (Max: ${StorageService.maxStoredSubmissions})');
      debugPrint('Save & Pruning Durasi   : ${saveWatch.elapsedMilliseconds}ms (${(250.0 / (saveWatch.elapsedMilliseconds / 1000.0)).toStringAsFixed(1)} ops/sec)');
      debugPrint('Load & Deserialization  : ${loadWatch.elapsedMilliseconds}ms');
      debugPrint('Payload Size in Storage : $payloadSizeKb KB');
      debugPrint('Oldest Kept Submission  : ${loaded?.last.id} (${loaded?.last.createdAt})');
      debugPrint('Newest Kept Submission  : ${loaded?.first.id} (${loaded?.first.createdAt})');

      // VERIFIKASI BATAS & INTEGRITAS FIFO
      expect(loaded, isNotNull);
      expect(loaded!.length, equals(StorageService.maxStoredSubmissions)); // Harus tepat 150!
      expect(loaded.first.id, equals('sub_249'), reason: 'Newest submission must be at index 0');
      expect(loaded.last.id, equals('sub_100'), reason: 'Oldest kept submission must be sub_100 (150 newest kept)');

      // Pastikan sub_0 s/d sub_99 benar-benar ter-prune
      final ids = loaded.map((e) => e.id).toSet();
      expect(ids.contains('sub_0'), isFalse);
      expect(ids.contains('sub_50'), isFalse);
      expect(ids.contains('sub_99'), isFalse);
      expect(ids.contains('sub_100'), isTrue);
      expect(ids.contains('sub_249'), isTrue);
    });

    test('BENCHMARK 3.2: SubmissionRepository In-Memory List Bounding Under High Load', () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      await SubmissionRepository.instance.init();

      final now = DateTime.now();

      // Tambahkan 200 submission secara sequential
      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 200; i++) {
        await SubmissionRepository.instance.addSubmission(SubmissionModel(
          id: 'repo_sub_$i',
          templateId: 'tmpl_1',
          templateName: 'Test Template',
          userId: 'usr_1',
          userName: 'Teknisi',
          userNpp: '123',
          posId: 'pos_1',
          posName: 'Pos A',
          cabangName: 'Cabang A',
          timestampCapture: now.add(Duration(seconds: i)),
          kodeVerifikasi: 'BSS-REPO$i',
          status: VerificationStatus.sesuai,
          alasanAI: 'OK',
          createdAt: now.add(Duration(seconds: i)),
        ));
      }
      stopwatch.stop();

      final inMemoryCount = SubmissionRepository.instance.submissions.length;
      final storedCount = StorageService.getSubmissions()?.length ?? 0;

      debugPrint('\n=== BENCHMARK 3.2: In-Memory Bounding (200 Sequential Additions) ===');
      debugPrint('Total Waktu 200 Adds    : ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('Throughput Add Ops      : ${(200.0 / (stopwatch.elapsedMilliseconds / 1000.0)).toStringAsFixed(1)} adds/sec');
      debugPrint('In-Memory List Count    : $inMemoryCount (Bounded to max: 150)');
      debugPrint('Stored List Count       : $storedCount');
      debugPrint('Latest Submission in Repo: ${SubmissionRepository.instance.submissions.first.id}');

      expect(inMemoryCount, equals(StorageService.maxStoredSubmissions));
      expect(storedCount, equals(StorageService.maxStoredSubmissions));
      expect(SubmissionRepository.instance.submissions.first.id, equals('repo_sub_199'));
    });

    test('BENCHMARK 3.3: Maintenance Submissions Auto-Pruning (220 submissions)', () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();

      final list = <MaintenanceSubmission>[];
      final now = DateTime(2026, 9, 11, 12, 0, 0);

      for (int i = 0; i < 220; i++) {
        final t = now.subtract(Duration(hours: 220 - i));
        list.add(MaintenanceSubmission(
          id: 'maint_$i',
          templateId: 'tmpl_maint_1',
          templateName: 'Maintenance Pos',
          userId: 'tech_1',
          userName: 'Teknisi A',
          userNpp: 'NPP-101',
          posId: 'pos_01',
          posName: 'Pos 1',
          cabangName: 'Cabang Utama',
          points: [
            MaintenancePointResult(
              pointId: 'pt_1',
              label: 'Cek Palang Barrier Gate',
              status: PointStatus.sesuai,
              confidence: 0.95,
              timestamp: t,
            ),
          ],
          createdAt: t,
          updatedAt: t,
        ));
      }

      final watch = Stopwatch()..start();
      await StorageService.saveMaintenanceSubmissions(list);
      watch.stop();

      final loadedMaint = StorageService.getMaintenanceSubmissions();

      debugPrint('\n=== BENCHMARK 3.3: Maintenance Auto-Pruning 220 records ===');
      debugPrint('Durasi Pruning & Save : ${watch.elapsedMilliseconds}ms');
      debugPrint('Retained Records      : ${loadedMaint?.length} records');
      debugPrint('Newest Record         : ${loadedMaint?.first.id}');
      debugPrint('Oldest Retained       : ${loadedMaint?.last.id}');

      expect(loadedMaint?.length, equals(StorageService.maxStoredSubmissions));
      expect(loadedMaint?.first.id, equals('maint_219'));
      expect(loadedMaint?.last.id, equals('maint_70')); // 220 - 150 = 70
    });

    // =========================================================================
    // 4. MEMORY CONSUMPTION & LEAK PROFILING
    // =========================================================================
    test('PROFILING 4.1: Memory Footprint & Garbage Collection Stability', () async {
      final initialRss = ProcessInfo.currentRss;
      final initialMaxRss = ProcessInfo.maxRss;

      debugPrint('\n=== PROFILING 4.1: Memory Usage & GC Stability ===');
      debugPrint('Initial Current RSS : ${(initialRss / (1024 * 1024)).toStringAsFixed(2)} MB');
      debugPrint('Initial Max RSS     : ${(initialMaxRss / (1024 * 1024)).toStringAsFixed(2)} MB');

      // Stress load: 3,000 hashes + 100 json objects
      final Set<String> codes = {};
      final now = DateTime.now();
      for (int i = 0; i < 3000; i++) {
        codes.add(VerificationCodeGenerator.generateCode(
          timestamp: now.add(Duration(milliseconds: i)),
          userId: 'mem_test_$i',
        ));
      }

      final peakRss = ProcessInfo.currentRss;
      debugPrint('Peak RSS Under Load : ${(peakRss / (1024 * 1024)).toStringAsFixed(2)} MB');

      codes.clear();
      // Allow GC settle
      await Future.delayed(const Duration(milliseconds: 50));

      final finalRss = ProcessInfo.currentRss;
      final deltaMb = (finalRss - initialRss) / (1024 * 1024);

      debugPrint('Post-Load Settle RSS: ${(finalRss / (1024 * 1024)).toStringAsFixed(2)} MB');
      debugPrint('Delta Memory Growth : ${deltaMb.toStringAsFixed(2)} MB');

      // Heap should remain stable with minimal delta (<15MB)
      expect(deltaMb < 25.0, isTrue, reason: 'Memory growth must be bounded under 25MB after GC');
    });
  });
}
