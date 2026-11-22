import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/data/services/app_update_service.dart';
import 'package:bssparking_timemark/features/updater/screens/mandatory_update_screen.dart';
import 'package:bssparking_timemark/features/updater/updater_controller.dart';
import 'package:bssparking_timemark/features/updater/widgets/updater_sheet.dart';
import 'package:bssparking_timemark/features/updater/widgets/updater_ticket_widgets.dart';

AppUpdateCheckResult _sampleCheckResult({bool mandatory = false}) {
  return AppUpdateCheckResult(
    release: const AppUpdateRelease(
      id: 'rel-1',
      versionName: '2.0.144',
      versionCode: 4157,
      sizeBytes: 24900000,
      sha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      changelog: 'Perbaikan stabilitas pemasangan pembaruan.',
    ),
    mandatory: mandatory,
    downloadUrl: 'https://example.supabase.co/signed.apk',
    currentVersion: '2.0.143',
    currentCode: 4156,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('pmapp_install_state_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('UpdaterController install states', () {
    test(
      'install success -> launching with 3s cooldown, then paused+resumed -> notInstalled',
      () async {
        final service = AppUpdateService(
          canInstallPackagesProvider: () async => true,
          installApkProvider: (_) async => true,
          cacheDirProvider: () async => tempDir,
        );
        final controller = UpdaterController(
          checkResult: _sampleCheckResult(),
          service: service,
          initialPhase: UpdaterPhase.ready,
          initialVerifiedFilePath: '${tempDir.path}/update.apk',
        );
        addTearDown(controller.dispose);

        await controller.install();
        expect(controller.state.phase, UpdaterPhase.ready);
        expect(controller.state.installStatus, InstallStatus.launching);
        expect(controller.installButtonCoolingDown, isTrue);

        controller.didChangeAppLifecycleState(AppLifecycleState.paused);
        controller.didChangeAppLifecycleState(AppLifecycleState.resumed);

        expect(controller.state.installStatus, InstallStatus.notInstalled);
        expect(controller.state.installFailureMissingFile, isFalse);
        expect(controller.installButtonCoolingDown, isFalse);
      },
    );

    test(
      'resumed without preceding paused or hidden stays launching',
      () async {
        final service = AppUpdateService(
          canInstallPackagesProvider: () async => true,
          installApkProvider: (_) async => true,
          cacheDirProvider: () async => tempDir,
        );
        final controller = UpdaterController(
          checkResult: _sampleCheckResult(),
          service: service,
          initialPhase: UpdaterPhase.ready,
          initialVerifiedFilePath: '${tempDir.path}/update.apk',
        );
        addTearDown(controller.dispose);

        await controller.install();
        expect(controller.state.installStatus, InstallStatus.launching);

        controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
        expect(controller.state.installStatus, InstallStatus.launching);
      },
    );

    test(
      'installApk throwing MISSING_FILE emits failed with missingFile=true and redownload resets',
      () async {
        final completer = Completer<List<int>>();
        final service = AppUpdateService(
          canInstallPackagesProvider: () async => true,
          installApkProvider: (_) async {
            throw PlatformException(code: 'MISSING_FILE', message: 'gone');
          },
          cacheDirProvider: () async => tempDir,
          clientFactory: () =>
              MockClient.streaming((request, bodyStream) async {
                return http.StreamedResponse(
                  Stream.fromFuture(completer.future),
                  200,
                  contentLength: 24900000,
                );
              }),
        );
        final controller = UpdaterController(
          checkResult: _sampleCheckResult(),
          service: service,
          initialPhase: UpdaterPhase.ready,
          initialVerifiedFilePath: '${tempDir.path}/update.apk',
        );
        addTearDown(() {
          if (!completer.isCompleted) completer.complete(const <int>[]);
          controller.dispose();
        });

        await controller.install();
        expect(controller.state.installStatus, InstallStatus.failed);
        expect(controller.state.installFailureMissingFile, isTrue);
        expect(controller.installButtonCoolingDown, isFalse);

        final partFile = await service.partFileFor(4157);
        await partFile.writeAsBytes([1, 2, 3, 4]);

        final downloadingReached = Completer<void>();
        void onControllerChanged() {
          if (controller.state.phase == UpdaterPhase.downloading &&
              !downloadingReached.isCompleted) {
            downloadingReached.complete();
          }
        }

        controller.addListener(onControllerChanged);
        final redownloadFuture = controller.redownload();
        await downloadingReached.future;
        controller.removeListener(onControllerChanged);

        expect(controller.state.phase, UpdaterPhase.downloading);
        expect(controller.state.installStatus, InstallStatus.idle);
        expect(controller.state.installFailureMissingFile, isFalse);
        expect(partFile.existsSync(), isFalse);

        await controller.cancelDownload();
        await redownloadFuture;
      },
    );

    test(
      'installApk returning false emits failed with missingFile=false',
      () async {
        final service = AppUpdateService(
          canInstallPackagesProvider: () async => true,
          installApkProvider: (_) async => false,
          cacheDirProvider: () async => tempDir,
        );
        final controller = UpdaterController(
          checkResult: _sampleCheckResult(),
          service: service,
          initialPhase: UpdaterPhase.ready,
          initialVerifiedFilePath: '${tempDir.path}/update.apk',
        );
        addTearDown(controller.dispose);

        await controller.install();
        expect(controller.state.installStatus, InstallStatus.failed);
        expect(controller.state.installFailureMissingFile, isFalse);
        expect(controller.installButtonCoolingDown, isFalse);
      },
    );
  });

  group('UpdaterSheet & MandatoryUpdateScreen install UI', () {
    testWidgets(
      'UpdaterSheet ready state shows disabled launching cooldown then Buka lagi then Pasang lagi after notInstalled',
      (tester) async {
        final service = AppUpdateService(
          canInstallPackagesProvider: () async => true,
          installApkProvider: (_) async => true,
          cacheDirProvider: () async => tempDir,
        );
        final controller = UpdaterController(
          checkResult: _sampleCheckResult(),
          service: service,
          initialPhase: UpdaterPhase.ready,
          initialVerifiedFilePath: '${tempDir.path}/update.apk',
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(body: UpdaterSheet(controller: controller)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pasang sekarang'), findsOneWidget);
        await tester.tap(find.text('Pasang sekarang'));
        await tester.pump();

        expect(find.text('Membuka pemasang Android...'), findsOneWidget);
        expect(
          find.text(
            'Ketuk Pasang atau Perbarui di layar Android, jangan ditutup sampai selesai.',
          ),
          findsOneWidget,
        );
        final disabledButton = tester.widget<UpdaterActionButton>(
          find.widgetWithText(
            UpdaterActionButton,
            'Membuka pemasang Android...',
          ),
        );
        expect(disabledButton.onPressed, isNull);

        await tester.pump(const Duration(seconds: 3));
        expect(find.text('Buka lagi'), findsOneWidget);
        final enabledButton = tester.widget<UpdaterActionButton>(
          find.widgetWithText(UpdaterActionButton, 'Buka lagi'),
        );
        expect(enabledButton.onPressed, isNotNull);

        controller.didChangeAppLifecycleState(AppLifecycleState.paused);
        controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await tester.pump();

        expect(find.text('Pemasangan belum selesai'), findsOneWidget);
        expect(
          find.text(
            'Versi baru belum terpasang. File sudah terunduh, tidak perlu unduh ulang.',
          ),
          findsOneWidget,
        );
        expect(find.text('Pasang lagi'), findsOneWidget);
        expect(
          find.text(
            'Ketuk Pasang atau Perbarui di layar Android, jangan ditutup sampai selesai.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'MandatoryUpdateScreen ready state shows launching, notInstalled, and failed missing-file copy',
      (tester) async {
        var shouldThrowMissing = false;
        final service = AppUpdateService(
          canInstallPackagesProvider: () async => true,
          installApkProvider: (_) async {
            if (shouldThrowMissing) {
              throw PlatformException(code: 'MISSING_FILE');
            }
            return true;
          },
          cacheDirProvider: () async => tempDir,
        );
        final controller = UpdaterController(
          checkResult: _sampleCheckResult(mandatory: true),
          service: service,
          initialPhase: UpdaterPhase.ready,
          initialVerifiedFilePath: '${tempDir.path}/update.apk',
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MandatoryUpdateScreen(
              controller: controller,
              autoStartDownload: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pasang sekarang'), findsOneWidget);
        await tester.tap(find.text('Pasang sekarang'));
        await tester.pump();

        expect(find.text('Membuka pemasang Android...'), findsOneWidget);
        expect(
          find.text(
            'Ketuk Pasang atau Perbarui di layar Android, jangan ditutup sampai selesai.',
          ),
          findsOneWidget,
        );

        controller.didChangeAppLifecycleState(AppLifecycleState.paused);
        controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await tester.pump();

        expect(find.text('Pemasangan belum selesai'), findsOneWidget);
        expect(find.text('Pasang lagi'), findsOneWidget);

        shouldThrowMissing = true;
        await tester.tap(find.text('Pasang lagi'));
        await tester.pump();

        expect(
          find.text(
            'File update tidak ditemukan. Unduh ulang untuk melanjutkan.',
          ),
          findsOneWidget,
        );
        expect(find.text('Unduh ulang'), findsOneWidget);
      },
    );
  });
}
