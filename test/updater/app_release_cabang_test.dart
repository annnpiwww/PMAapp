import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/data/services/app_release_admin_service.dart';
import 'package:bssparking_timemark/features/updater/screens/app_releases_screen.dart';
import 'package:bssparking_timemark/features/updater/screens/upload_release_screen.dart';

LocalApkInfo _fakeApk() {
  return LocalApkInfo(
    path: '/tmp/app.apk',
    fileName: 'app-arm64-v8a-release.apk',
    packageName: 'com.bssparking.timemark.bssparking_timemark',
    versionName: '2.0.142',
    versionCode: 4155,
    abi: 'arm64-v8a',
    baseVersionCode: 2155,
    sizeBytes: 24926834,
    sha256: 'a' * 64,
  );
}

Map<String, dynamic> _releaseJson({
  String id = 'rel-1',
  String versionName = '2.0.142',
  int versionCode = 4155,
  String status = 'published',
  dynamic targetCabang,
}) {
  return {
    'id': id,
    'app': 'pmapp',
    'abi': 'arm64-v8a',
    'version_code': versionCode,
    'base_version_code': versionCode - 2000,
    'version_name': versionName,
    'sha256': 'a' * 64,
    'size_bytes': 24926834,
    'changelog': 'Staged rollout test',
    'mandatory': false,
    'min_supported_version': null,
    'target_cabang': targetCabang,
    'status': status,
    'created_by': 'Farhan Lakoro',
    'created_at': '2026-11-22T09:00:00Z',
    'published_at': status == 'published' ? '2026-11-22T09:05:00Z' : null,
  };
}

void main() {
  group('AdminReleaseItem.targetCabang & cabangLabel', () {
    test(
      'parses target_cabang null, list of strings, and non-list garbage',
      () {
        final nullItem = AdminReleaseItem.fromJson(
          _releaseJson(targetCabang: null),
        );
        expect(nullItem.targetCabang, isNull);
        expect(nullItem.isAllBranches, isTrue);

        final manadoItem = AdminReleaseItem.fromJson(
          _releaseJson(targetCabang: ['manado']),
        );
        expect(manadoItem.targetCabang, ['manado']);
        expect(manadoItem.isAllBranches, isFalse);

        final garbageItem = AdminReleaseItem.fromJson(
          _releaseJson(targetCabang: 5),
        );
        expect(garbageItem.targetCabang, isNull);
        expect(garbageItem.isAllBranches, isTrue);
      },
    );

    test('cabangLabel maps null/empty and branch codes cleanly', () {
      expect(cabangLabel(null), 'Semua cabang');
      expect(cabangLabel(const []), 'Semua cabang');
      expect(cabangLabel(const ['bali', 'manado']), 'Bali, Manado');
      expect(cabangLabel(const ['ho']), 'HO');
    });
  });

  group('AppReleaseAdminService target_cabang API', () {
    test(
      'createUpload sends target_cabang when given and null when omitted',
      () async {
        final capturedBodies = <Map<String, dynamic>>[];
        final service = AppReleaseAdminService(
          clientFactory: () => MockClient((req) async {
            capturedBodies.add(jsonDecode(req.body) as Map<String, dynamic>);
            return http.Response(
              jsonEncode({
                'id': 'rel-new',
                'upload': {
                  'path': 'prod/4155-arm64-v8a.apk',
                  'token': 'tok',
                  'signedUrl': 'https://example.supabase.co/upload',
                },
              }),
              201,
            );
          }),
          baseUrlProvider: () => 'https://example.supabase.co',
          anonKeyProvider: () => 'anon',
          sessionTokenProvider: () => 'v1.tok.sig',
        );

        await service.createUpload(
          apk: _fakeApk(),
          changelog: 'Cabang Manado dulu',
          mandatory: false,
          targetCabang: const ['manado'],
        );
        await service.createUpload(
          apk: _fakeApk(),
          changelog: 'Semua cabang',
          mandatory: false,
        );

        expect(capturedBodies[0]['target_cabang'], ['manado']);
        expect(capturedBodies[1].containsKey('target_cabang'), isTrue);
        expect(capturedBodies[1]['target_cabang'], isNull);
      },
    );

    test('setTargets posts action set_targets and parses release', () async {
      Map<String, dynamic>? capturedBody;
      final service = AppReleaseAdminService(
        clientFactory: () => MockClient((req) async {
          capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'release': _releaseJson(id: 'rel-1', targetCabang: null),
              'archived_count': 1,
            }),
            200,
          );
        }),
        baseUrlProvider: () => 'https://example.supabase.co',
        anonKeyProvider: () => 'anon',
        sessionTokenProvider: () => 'v1.tok.sig',
      );

      final updated = await service.setTargets('rel-1', null);
      expect(capturedBody, {
        'action': 'set_targets',
        'id': 'rel-1',
        'target_cabang': null,
      });
      expect(updated.id, 'rel-1');
      expect(updated.targetCabang, isNull);
      expect(updated.isAllBranches, isTrue);
    });

    test(
      '409 not_editable throws AppReleaseAdminException with exact copy',
      () async {
        final service = AppReleaseAdminService(
          clientFactory: () => MockClient(
            (_) async =>
                http.Response(jsonEncode({'error': 'not_editable'}), 409),
          ),
          baseUrlProvider: () => 'https://example.supabase.co',
          anonKeyProvider: () => 'anon',
          sessionTokenProvider: () => 'v1.tok.sig',
        );

        await expectLater(
          service.setTargets('rel-1', null),
          throwsA(
            isA<AppReleaseAdminException>()
                .having((e) => e.statusCode, 'statusCode', 409)
                .having((e) => e.errorCode, 'errorCode', 'not_editable')
                .having(
                  (e) => e.message,
                  'message',
                  'Rilis ini sudah tidak bisa diubah.',
                ),
          ),
        );
      },
    );
  });

  group('UploadReleaseScreen branch chips', () {
    testWidgets('enforces chip selection rules and updates helper text', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: UploadReleaseScreen(
            service: AppReleaseAdminService(
              baseUrlProvider: () => 'https://example.supabase.co',
              anonKeyProvider: () => 'anon',
              sessionTokenProvider: () => 'tok',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      FilterChip chipNamed(String label) =>
          tester.widget<FilterChip>(find.widgetWithText(FilterChip, label));

      expect(find.text('Cabang tujuan'), findsOneWidget);
      expect(chipNamed('Semua cabang').selected, isTrue);
      expect(chipNamed('Manado').selected, isFalse);
      expect(chipNamed('Bali').selected, isFalse);
      expect(chipNamed('HO').selected, isFalse);
      expect(find.text('Semua teknisi akan dapat update ini.'), findsOneWidget);
      expect(
        tester.getSize(find.widgetWithText(FilterChip, 'Manado')).height,
        greaterThanOrEqualTo(44.0),
      );

      // Select Manado -> Semua cabang turns off.
      await tester.ensureVisible(find.widgetWithText(FilterChip, 'Manado'));
      await tester.tap(find.widgetWithText(FilterChip, 'Manado'));
      await tester.pumpAndSettle();

      expect(chipNamed('Semua cabang').selected, isFalse);
      expect(chipNamed('Manado').selected, isTrue);
      expect(
        find.text(
          'Hanya teknisi cabang Manado yang dapat update. Cabang lain tetap di versi sekarang.',
        ),
        findsOneWidget,
      );

      // Tap Manado again -> deselecting last branch reselects Semua cabang.
      await tester.tap(find.widgetWithText(FilterChip, 'Manado'));
      await tester.pumpAndSettle();

      expect(chipNamed('Semua cabang').selected, isTrue);
      expect(chipNamed('Manado').selected, isFalse);
      expect(find.text('Semua teknisi akan dapat update ini.'), findsOneWidget);

      // Select Bali + Manado, then tap Semua cabang -> clears branches.
      await tester.tap(find.widgetWithText(FilterChip, 'Bali'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Manado'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Hanya teknisi cabang Bali, Manado yang dapat update. Cabang lain tetap di versi sekarang.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilterChip, 'Semua cabang'));
      await tester.pumpAndSettle();
      expect(chipNamed('Semua cabang').selected, isTrue);
      expect(chipNamed('Bali').selected, isFalse);
      expect(chipNamed('Manado').selected, isFalse);
    });
  });

  group('AppReleasesScreen target badge & widen-to-all action', () {
    testWidgets('shows target badges and confirms Rilis ke semua cabang', (
      tester,
    ) async {
      final calls = <Map<String, dynamic>>[];
      var widened = false;
      final service = AppReleaseAdminService(
        clientFactory: () => MockClient((req) async {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          calls.add(body);
          if (body['action'] == 'set_targets') {
            widened = true;
            return http.Response(
              jsonEncode({
                'release': _releaseJson(id: 'rel-manado', targetCabang: null),
                'archived_count': 1,
              }),
              200,
            );
          }
          if (body['action'] == 'list') {
            return http.Response(
              jsonEncode({
                'releases': [
                  _releaseJson(
                    id: 'rel-manado',
                    versionName: '2.0.142',
                    versionCode: 4155,
                    targetCabang: widened ? null : ['manado'],
                  ),
                  _releaseJson(
                    id: 'rel-all',
                    versionName: '2.0.141',
                    versionCode: 4154,
                    targetCabang: null,
                  ),
                ],
              }),
              200,
            );
          }
          return http.Response('{}', 200);
        }),
        baseUrlProvider: () => 'https://example.supabase.co',
        anonKeyProvider: () => 'anon',
        sessionTokenProvider: () => 'tok',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AppReleasesScreen(service: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Manado'), findsOneWidget);
      expect(find.text('Semua cabang'), findsOneWidget);
      expect(find.text('Rilis ke semua cabang'), findsOneWidget);
      expect(
        tester
            .getSize(find.widgetWithText(TextButton, 'Rilis ke semua cabang'))
            .height,
        greaterThanOrEqualTo(44.0),
      );

      await tester.tap(find.text('Rilis ke semua cabang'));
      await tester.pumpAndSettle();

      expect(find.text('Rilis ke semua cabang?'), findsOneWidget);
      expect(
        find.text(
          'Versi 2.0.142 akan tersedia untuk semua teknisi. Versi lama di server akan dihapus.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Rilis ke semua'));
      await tester.pumpAndSettle();

      expect(
        calls.any(
          (c) =>
              c['action'] == 'set_targets' &&
              c['id'] == 'rel-manado' &&
              c['target_cabang'] == null,
        ),
        isTrue,
      );
      expect(
        find.text('Versi 2.0.142 sekarang untuk semua cabang.'),
        findsOneWidget,
      );
      expect(find.text('Rilis ke semua cabang'), findsNothing);
    });
  });
}
