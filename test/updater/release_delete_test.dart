import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/data/services/app_release_admin_service.dart';
import 'package:bssparking_timemark/features/updater/screens/app_releases_screen.dart';

AdminReleaseItem _item({
  required String id,
  required AdminReleaseStatus status,
  String versionName = '2.0.141',
  int versionCode = 4154,
}) {
  return AdminReleaseItem(
    id: id,
    app: 'pmapp',
    abi: 'arm64-v8a',
    versionCode: versionCode,
    baseVersionCode: versionCode - 2000,
    versionName: versionName,
    sha256: 'a' * 64,
    sizeBytes: 24900000,
    changelog: 'Catatan rilis $versionName.',
    mandatory: false,
    minSupportedVersion: null,
    status: status,
    createdBy: 'Admin',
    createdAt: DateTime(2026, 11, 20, 9, 15),
    publishedAt: status == AdminReleaseStatus.draft
        ? null
        : DateTime(2026, 11, 20, 9, 30),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppReleaseAdminService.deleteRelease', () {
    test('posts action delete_release with id', () async {
      Map<String, dynamic>? sentBody;
      final service = AppReleaseAdminService(
        clientFactory: () => MockClient((req) async {
          sentBody = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'deleted': true,
              'id': 'rel-arch',
              'file_removed': true,
            }),
            200,
          );
        }),
        baseUrlProvider: () => 'https://example.supabase.co',
        anonKeyProvider: () => 'anon',
        sessionTokenProvider: () => 'v1.tok.sig',
      );

      await service.deleteRelease('rel-arch');
      expect(sentBody, {'action': 'delete_release', 'id': 'rel-arch'});
    });

    test('maps 409 release_is_active to Indonesian message', () async {
      final service = AppReleaseAdminService(
        clientFactory: () => MockClient(
          (_) async =>
              http.Response(jsonEncode({'error': 'release_is_active'}), 409),
        ),
        baseUrlProvider: () => 'https://example.supabase.co',
        anonKeyProvider: () => 'anon',
        sessionTokenProvider: () => 'v1.tok.sig',
      );

      expect(
        () => service.deleteRelease('rel-active'),
        throwsA(
          isA<AppReleaseAdminException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.errorCode, 'errorCode', 'release_is_active')
              .having(
                (e) => e.message,
                'message',
                'Rilis aktif tidak bisa dihapus. Tarik dulu atau terbitkan versi baru.',
              ),
        ),
      );
    });
  });

  group('AppReleasesScreen delete release', () {
    testWidgets(
      'archived & rolled_back show Hapus rilis, draft shows Hapus draf only, published shows helper line',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final releases = [
          _item(
            id: 'rel-pub',
            status: AdminReleaseStatus.published,
            versionName: '2.0.143',
            versionCode: 4156,
          ),
          _item(
            id: 'rel-draft',
            status: AdminReleaseStatus.draft,
            versionName: '2.0.144',
            versionCode: 4157,
          ),
          _item(
            id: 'rel-rb',
            status: AdminReleaseStatus.rolledBack,
            versionName: '2.0.142',
            versionCode: 4155,
          ),
          _item(
            id: 'rel-arch',
            status: AdminReleaseStatus.archived,
            versionName: '2.0.141',
            versionCode: 4154,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: AppReleasesScreen(initialReleases: releases),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Rilis aktif tidak bisa dihapus. Tarik dulu atau terbitkan versi baru.',
          ),
          findsOneWidget,
        );
        expect(find.text('Hapus draf'), findsOneWidget);
        expect(find.text('Terbitkan'), findsOneWidget);
        expect(find.text('Hapus rilis'), findsNWidgets(2));
      },
    );

    testWidgets(
      'confirm dialog Batal does not delete and Hapus calls delete_release and reloads',
      (tester) async {
        final actions = <Map<String, dynamic>>[];
        final releasesJson = [
          {
            'id': 'rel-arch',
            'app': 'pmapp',
            'abi': 'arm64-v8a',
            'version_code': 4154,
            'base_version_code': 2154,
            'version_name': '2.0.141',
            'sha256': 'a' * 64,
            'size_bytes': 24900000,
            'changelog': 'Arsip lama.',
            'mandatory': false,
            'min_supported_version': null,
            'status': 'archived',
            'created_by': 'Admin',
            'created_at': '2026-11-20T09:15:00Z',
            'published_at': '2026-11-20T09:30:00Z',
          },
        ];

        final service = AppReleaseAdminService(
          clientFactory: () => MockClient((req) async {
            final body = jsonDecode(req.body) as Map<String, dynamic>;
            actions.add(body);
            if (body['action'] == 'list') {
              return http.Response(jsonEncode({'releases': releasesJson}), 200);
            }
            if (body['action'] == 'delete_release') {
              releasesJson.clear();
              return http.Response(
                jsonEncode({
                  'deleted': true,
                  'id': body['id'],
                  'file_removed': true,
                }),
                200,
              );
            }
            return http.Response('{}', 400);
          }),
          baseUrlProvider: () => 'https://example.supabase.co',
          anonKeyProvider: () => 'anon',
          sessionTokenProvider: () => 'v1.tok.sig',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: AppReleasesScreen(service: service),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hapus rilis'), findsOneWidget);

        await tester.tap(find.text('Hapus rilis'));
        await tester.pumpAndSettle();
        expect(find.text('Hapus rilis v2.0.141 (Build 4154)?'), findsOneWidget);
        expect(
          find.text(
            'File APK dan riwayatnya dihapus permanen. Tidak bisa dibatalkan.',
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();
        expect(actions.where((a) => a['action'] == 'delete_release'), isEmpty);

        await tester.tap(find.text('Hapus rilis'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hapus'));
        await tester.pumpAndSettle();

        expect(actions.where((a) => a['action'] == 'delete_release').toList(), [
          {'action': 'delete_release', 'id': 'rel-arch'},
        ]);
        expect(actions.where((a) => a['action'] == 'list').length, 2);
        expect(find.text('Rilis v2.0.141 dihapus.'), findsOneWidget);
        expect(find.text('Hapus rilis'), findsNothing);
      },
    );
  });
}
