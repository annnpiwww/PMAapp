import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/data/services/app_release_admin_service.dart';
import 'package:bssparking_timemark/data/services/app_update_service.dart';

PackageInfo _fakePackageInfo({
  String version = '2.0.141',
  String buildNumber = '4154',
}) {
  return PackageInfo(
    appName: 'PMA App',
    packageName: 'com.bssparking.timemark.bssparking_timemark',
    version: version,
    buildNumber: buildNumber,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('pmapp_updater_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AppUpdateService.pickAbi', () {
    test('picks first supported ABI in device preference order', () {
      expect(
        AppUpdateService.pickAbi(['arm64-v8a', 'armeabi-v7a', 'armeabi']),
        'arm64-v8a',
      );
      expect(
        AppUpdateService.pickAbi(['armeabi-v7a', 'arm64-v8a']),
        'armeabi-v7a',
      );
      expect(AppUpdateService.pickAbi(['mips64', 'x86_64']), 'x86_64');
      expect(AppUpdateService.pickAbi(['mips', 'armeabi']), isNull);
    });
  });

  group('AppUpdateService.checkLatest', () {
    test('maps valid update=true response with exact payload', () async {
      Map<String, dynamic>? capturedBody;
      final mockClient = MockClient((req) async {
        capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'update': true,
            'mandatory': true,
            'release': {
              'id': 'rel-1',
              'version_name': '2.0.142',
              'version_code': 4155,
              'size_bytes': 24926834,
              'sha256': 'a' * 64,
              'changelog': 'Perbaikan sinkronisasi',
            },
            'download_url': 'https://example.supabase.co/storage/signed.apk',
          }),
          200,
        );
      });

      final service = AppUpdateService(
        clientFactory: () => mockClient,
        supportedAbisProvider: () async => ['arm64-v8a', 'armeabi-v7a'],
        packageInfoProvider: () async => _fakePackageInfo(),
        cacheDirProvider: () async => tempDir,
        baseUrlProvider: () => 'https://example.supabase.co',
        anonKeyProvider: () => 'anon-key',
      );

      final result = await service.checkLatest();
      expect(capturedBody, {
        'action': 'latest',
        'abi': 'arm64-v8a',
        'current_code': 4154,
        'current_version': '2.0.141',
      });
      expect(result, isNotNull);
      expect(result!.mandatory, isTrue);
      expect(result.release.versionName, '2.0.142');
      expect(result.release.versionCode, 4155);
      expect(result.release.sizeBytes, 24926834);
      expect(
        result.downloadUrl,
        'https://example.supabase.co/storage/signed.apk',
      );
      expect(result.currentVersion, '2.0.141');
    });

    test('returns null on 500, timeout, and invalid JSON', () async {
      final serverErrService = AppUpdateService(
        clientFactory: () => MockClient((_) async => http.Response('err', 500)),
        supportedAbisProvider: () async => ['arm64-v8a'],
        packageInfoProvider: () async => _fakePackageInfo(),
        cacheDirProvider: () async => tempDir,
        baseUrlProvider: () => 'https://example.supabase.co',
        anonKeyProvider: () => 'anon-key',
      );
      expect(await serverErrService.checkLatest(), isNull);

      final timeoutService = AppUpdateService(
        clientFactory: () => MockClient(
          (_) => Future<http.Response>.error(TimeoutException('timed out')),
        ),
        supportedAbisProvider: () async => ['arm64-v8a'],
        packageInfoProvider: () async => _fakePackageInfo(),
        cacheDirProvider: () async => tempDir,
        baseUrlProvider: () => 'https://example.supabase.co',
        anonKeyProvider: () => 'anon-key',
      );
      expect(await timeoutService.checkLatest(), isNull);

      final badJsonService = AppUpdateService(
        clientFactory: () =>
            MockClient((_) async => http.Response('{bad', 200)),
        supportedAbisProvider: () async => ['arm64-v8a'],
        packageInfoProvider: () async => _fakePackageInfo(),
        cacheDirProvider: () async => tempDir,
        baseUrlProvider: () => 'https://example.supabase.co',
        anonKeyProvider: () => 'anon-key',
      );
      expect(await badJsonService.checkLatest(), isNull);
    });
  });

  group('AppUpdateService.verify & download resume', () {
    test(
      'verify passes on exact size + sha256 and deletes file on mismatch',
      () async {
        final service = AppUpdateService(cacheDirProvider: () async => tempDir);
        final bytes = utf8.encode('pmapp-apk-payload-2.0.142');
        final digest = sha256.convert(bytes).toString();
        final release = AppUpdateRelease(
          id: 'rel-1',
          versionName: '2.0.142',
          versionCode: 4155,
          sizeBytes: bytes.length,
          sha256: digest,
          changelog: '',
        );

        final validFile = File('${tempDir.path}/valid.apk')
          ..writeAsBytesSync(bytes);
        expect(await service.verify(validFile, release), isTrue);
        expect(validFile.existsSync(), isTrue);

        final wrongShaFile = File('${tempDir.path}/badsha.apk')
          ..writeAsBytesSync(utf8.encode('pmapp-apk-payload-CORRUPT'));
        expect(await service.verify(wrongShaFile, release), isFalse);
        expect(wrongShaFile.existsSync(), isFalse);

        final wrongSizeFile = File('${tempDir.path}/badsize.apk')
          ..writeAsBytesSync(utf8.encode('short'));
        expect(await service.verify(wrongSizeFile, release), isFalse);
        expect(wrongSizeFile.existsSync(), isFalse);
      },
    );

    test(
      'download sends Range header from existing .part length and renames on verify',
      () async {
        final fullBytes = utf8.encode('0123456789ABCDEFGHIJ');
        final partBytes = fullBytes.sublist(0, 8);
        final remainingBytes = fullBytes.sublist(8);
        final digest = sha256.convert(fullBytes).toString();

        final release = AppUpdateRelease(
          id: 'rel-resume',
          versionName: '2.0.142',
          versionCode: 4155,
          sizeBytes: fullBytes.length,
          sha256: digest,
          changelog: '',
        );

        String? seenRange;
        final mockClient = MockClient.streaming((req, _) async {
          seenRange = req.headers['Range'];
          return http.StreamedResponse(
            Stream.value(remainingBytes),
            206,
            contentLength: remainingBytes.length,
          );
        });

        final service = AppUpdateService(
          clientFactory: () => mockClient,
          cacheDirProvider: () async => tempDir,
        );

        final partFile = await service.partFileFor(release.versionCode);
        await partFile.writeAsBytes(partBytes);

        final progressEvents = await service
            .download(release, 'https://example.supabase.co/signed.apk')
            .toList();

        expect(seenRange, 'bytes=8-');
        expect(progressEvents, isNotEmpty);
        expect(progressEvents.last.received, fullBytes.length);

        final finalFile = await service.verifyAndFinalize(release);
        expect(finalFile.existsSync(), isTrue);
        expect(finalFile.path.endsWith('pmapp-4155.apk'), isTrue);
        expect(finalFile.readAsBytesSync(), fullBytes);
        expect(partFile.existsSync(), isFalse);
      },
    );

    test('download refreshes signed URL on 403 and resumes', () async {
      final fullBytes = utf8.encode('HELLO_REFRESHED_APK');
      final digest = sha256.convert(fullBytes).toString();
      final release = AppUpdateRelease(
        id: 'rel-403',
        versionName: '2.0.142',
        versionCode: 4155,
        sizeBytes: fullBytes.length,
        sha256: digest,
        changelog: '',
      );

      final seenUrls = <String>[];
      final mockClient = MockClient.streaming((req, _) async {
        seenUrls.add(req.url.toString());
        if (req.url.toString().contains('expired')) {
          return http.StreamedResponse(const Stream.empty(), 403);
        }
        return http.StreamedResponse(
          Stream.value(fullBytes),
          200,
          contentLength: fullBytes.length,
        );
      });

      final service = AppUpdateService(
        clientFactory: () => mockClient,
        cacheDirProvider: () async => tempDir,
      );

      await service
          .download(
            release,
            'https://example.supabase.co/expired.apk',
            refreshLatest: () async => AppUpdateCheckResult(
              release: release,
              mandatory: false,
              downloadUrl: 'https://example.supabase.co/fresh.apk',
              currentVersion: '2.0.141',
              currentCode: 4154,
            ),
          )
          .drain<void>();

      expect(seenUrls, [
        'https://example.supabase.co/expired.apk',
        'https://example.supabase.co/fresh.apk',
      ]);
    });
  });

  group('12h Nanti suppression', () {
    test(
      'suppresses optional prompt for 12h and ignores dismissal when mandatory',
      () async {
        var now = DateTime(2026, 11, 22, 9, 0);
        final service = AppUpdateService(nowProvider: () => now);
        const release = AppUpdateRelease(
          id: 'rel-1',
          versionName: '2.0.142',
          versionCode: 4155,
          sizeBytes: 24926834,
          sha256:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          changelog: '',
        );

        const optionalResult = AppUpdateCheckResult(
          release: release,
          mandatory: false,
          downloadUrl: 'https://example.supabase.co/signed.apk',
          currentVersion: '2.0.141',
          currentCode: 4154,
        );
        const mandatoryResult = AppUpdateCheckResult(
          release: release,
          mandatory: true,
          downloadUrl: 'https://example.supabase.co/signed.apk',
          currentVersion: '2.0.141',
          currentCode: 4154,
        );

        expect(await service.shouldPrompt(optionalResult), isTrue);
        await service.dismissFor12Hours(4155);

        now = now.add(const Duration(hours: 11, minutes: 59));
        expect(await service.shouldPrompt(optionalResult), isFalse);
        expect(await service.shouldPrompt(mandatoryResult), isTrue);

        now = now.add(const Duration(minutes: 2));
        expect(await service.shouldPrompt(optionalResult), isTrue);
      },
    );
  });

  group('AppReleaseAdminService APK validation & error mapping', () {
    test('validates single-ABI APK and rejects universal APK', () {
      final valid = AppReleaseAdminService.validateParsedApk(
        raw: {
          'packageName': 'com.bssparking.timemark.bssparking_timemark',
          'versionName': '2.0.142',
          'versionCode': 4155,
          'abis': ['arm64-v8a'],
        },
        path: '/tmp/app.apk',
        fileName: 'app-arm64-v8a-release.apk',
        sizeBytes: 24926834,
        sha256: 'b' * 64,
      );
      expect(valid.abi, 'arm64-v8a');
      expect(valid.baseVersionCode, 2155);

      expect(
        () => AppReleaseAdminService.validateParsedApk(
          raw: {
            'packageName': 'com.bssparking.timemark.bssparking_timemark',
            'versionName': '2.0.142',
            'versionCode': 2155,
            'abis': ['arm64-v8a', 'armeabi-v7a'],
          },
          path: '/tmp/universal.apk',
          fileName: 'app-release.apk',
          sizeBytes: 24926834,
          sha256: 'b' * 64,
        ),
        throwsA(
          isA<AppReleaseAdminException>().having(
            (e) => e.message,
            'message',
            'Unggah APK per arsitektur, bukan universal.',
          ),
        ),
      );
    });

    test('maps 403 and 409 responses cleanly', () async {
      final forbiddenSvc = AppReleaseAdminService(
        clientFactory: () => MockClient(
          (_) async => http.Response(jsonEncode({'error': 'forbidden'}), 403),
        ),
        baseUrlProvider: () => 'https://example.supabase.co',
        anonKeyProvider: () => 'anon',
        sessionTokenProvider: () => 'v1.tok.sig',
      );
      await expectLater(
        forbiddenSvc.list(),
        throwsA(
          isA<AppReleaseAdminException>().having(
            (e) => e.message,
            'message',
            'Akun ini belum punya akses rilis.',
          ),
        ),
      );

      final conflictSvc = AppReleaseAdminService(
        clientFactory: () => MockClient(
          (_) async => http.Response(
            jsonEncode({'error': 'version_code_must_increase'}),
            409,
          ),
        ),
        baseUrlProvider: () => 'https://example.supabase.co',
        anonKeyProvider: () => 'anon',
        sessionTokenProvider: () => 'v1.tok.sig',
      );
      await expectLater(
        conflictSvc.createUpload(
          apk: LocalApkInfo(
            path: '/tmp/a.apk',
            fileName: 'a.apk',
            packageName: 'com.bssparking.timemark.bssparking_timemark',
            versionName: '2.0.141',
            versionCode: 4154,
            abi: 'arm64-v8a',
            baseVersionCode: 2154,
            sizeBytes: 1000,
            sha256: 'c' * 64,
          ),
          changelog: 'test',
          mandatory: false,
        ),
        throwsA(
          isA<AppReleaseAdminException>().having(
            (e) => e.message,
            'message',
            'Nomor versi harus lebih tinggi dari rilis sebelumnya.',
          ),
        ),
      );
    });
  });
}
