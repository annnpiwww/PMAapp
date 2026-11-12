import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/core/widgets/tiket/error_alarm_overlay.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/models/error_report.dart';
import 'package:bssparking_timemark/data/models/user_model.dart';
import 'package:bssparking_timemark/data/repositories/auth_repository.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/error_ticket_service.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/daily_tasks/screens/custom_task_execution_screen.dart';
import 'package:bssparking_timemark/features/daily_tasks/screens/teknisi_daily_tasks_screen.dart';

import 'visual_harness.dart';

class _MockHttpResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => 2;
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => false;
  @override
  String get reasonPhrase => 'OK';
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  HttpHeaders get headers => _MockHttpHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.value(utf8.encode('[]')).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation inv) => null;
}

class _MockHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation inv) => null;
}

class _MockHttpRequest implements HttpClientRequest {
  @override
  HttpHeaders get headers => _MockHttpHeaders();
  @override
  Future<dynamic> addStream(Stream<List<int>> stream) async {}
  @override
  void add(List<int> data) {}
  @override
  Future<HttpClientResponse> close() async => _MockHttpResponse();
  @override
  dynamic noSuchMethod(Invocation inv) => null;
}

class _MockHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _MockHttpRequest();
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpRequest();
  @override
  dynamic noSuchMethod(Invocation inv) => null;
}

class _MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _MockHttpClient();
}

const String _storyAdminText = '''Selamat pagi, izin melaporkan, telah terjadi kendala dengan kronologi sebagai berikut:

Tanggal : 12-11-2026
Waktu : 09.11

Lokasi : Mie Gacoan Nani Wartabone

Kendala : Monitor tidak menyala

Penyebab : -

Solusi sementara : -

Durasi Error : -

Berikut kami lampirkan dokumentasi kerusakan.

Terima kasih.''';

Future<void> _saveBoundaryAsPng(
  WidgetTester tester,
  GlobalKey key,
  String path, {
  double pixelRatio = 3.0,
  bool overwrite = true,
}) async {
  if (!overwrite && File(path).existsSync()) {
    debugPrint('Skipping existing screenshot: $path');
    return;
  }
  final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) throw Exception('RenderRepaintBoundary not found for $path');

  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Failed to get png byteData for $path');

    final file = File(path);
    file.parent.createSync(recursive: true);
    await file.writeAsBytes(byteData.buffer.asUint8List());
    debugPrint('Generated screenshot: $path (${image.width}x${image.height})');
  });
}

Widget _wrapScreen({
  required Widget screen,
  required GlobalKey boundaryKey,
  required ThemeData theme,
  double height = 844,
}) {
  return RepaintBoundary(
    key: boundaryKey,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(390, height),
          padding: const EdgeInsets.only(top: 24, bottom: 24),
          devicePixelRatio: 3.0,
        ),
        child: SizedBox(
          width: 390,
          height: height,
          child: screen,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late File dummyPhotoFile;
  late File dummyPhotoFile2;

  setUpAll(() async {
    await loadAppFonts();
    HttpOverrides.global = _MockHttpOverrides();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (MethodCall methodCall) async {
        return true;
      },
    );

    final tempDir = Directory.systemTemp.createTempSync('bss_kelola_video_test_');
    dummyPhotoFile = File('${tempDir.path}/evidence_photo1.png');
    dummyPhotoFile2 = File('${tempDir.path}/evidence_photo2.png');
    final realAssetPhoto1 = File('assets/foto absensi/absen1.png');
    final realAssetPhoto2 = File('assets/foto absensi/absen2.png');

    if (realAssetPhoto1.existsSync()) {
      dummyPhotoFile.writeAsBytesSync(realAssetPhoto1.readAsBytesSync());
    } else {
      dummyPhotoFile.writeAsBytesSync(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAI0lEQVR4nGNMKelmIAUwkaSaYVQDcYCJSHVwMKqBGEByKAEAcI8Bg4SnJzQAAAAASUVORK5CYII=',
      ));
    }

    if (realAssetPhoto2.existsSync()) {
      dummyPhotoFile2.writeAsBytesSync(realAssetPhoto2.readAsBytesSync());
    } else {
      dummyPhotoFile2.writeAsBytesSync(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAI0lEQVR4nGNMKelmIAUwkaSaYVQDcYCJSHVwMKqBGEByKAEAcI8Bg4SnJzQAAAAASUVORK5CYII=',
      ));
    }
  });

  const mgnwPosName = 'Mie Gacoan Nani Wartabone';
  const outBase = 'docs/screenshots/video-kelola-laporan';

  late PosLocation mgnwLoc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
    await BranchService.instance.setBranch(AppBranch.manado);

    mgnwLoc = LocationService.allLocations.firstWhere(
      (l) => l.locationTag == 'MGNW',
    );

    final ryan = UserModel(
      id: 'usr_ryan',
      nama: 'Farhan Lakoro',
      npp: '10293',
      email: 'ryan@bssparking.com',
      role: UserRole.petugas,
      posId: 'POS-MGNW-01',
      posName: mgnwPosName,
      cabangName: 'KC BSG',
    );
    await AuthRepository.instance.login(ryan);

    final report = ErrorReport.parse(_storyAdminText);
    final errorDeskripsi = report.toDeskripsi(_storyAdminText);

    final tasks = [
      DailyTaskModel(
        id: 'local_t_01',
        tanggal: '2026-11-12',
        teknisiId: 'usr_ryan',
        teknisiNama: 'Farhan Lakoro',
        posName: mgnwPosName,
        posTag: 'MGNW',
        judul: 'Maintenance Rutin Barrier Gate In',
        kategori: 'maintenance',
        templateId: 'tpl_maint_barrier',
        status: TaskStatus.inProgress,
      ),
      DailyTaskModel(
        id: 'local_t_open_err',
        tanggal: '2026-11-12',
        teknisiId: 'usr_ryan',
        teknisiNama: 'Farhan Lakoro',
        posName: mgnwPosName,
        posTag: 'MGNW',
        judul: 'Monitor tidak menyala',
        deskripsi: errorDeskripsi,
        kategori: 'error',
        status: TaskStatus.pending,
        serahTerima: 'irma||Daftar terbuka|12 Nov 09:11',
      ),
    ];
    await StorageService.setString(
      DailyTaskService.localCacheKey,
      jsonEncode(tasks.map((e) => e.toJson()).toList()),
    );
  });

  tearDown(() {
    customTaskNow = DateTime.now;
  });

  group('Kelola Laporan Error Video Flow Screenshots', () {
    testWidgets('01 ErrorAlarmOverlay ringing over technician Daily Task', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final openError = DailyTaskModel(
        id: 't_err_mgnw',
        tanggal: '2026-11-12',
        teknisiId: 'usr_ryan',
        teknisiNama: 'Farhan Lakoro',
        posName: mgnwPosName,
        posTag: 'MGNW',
        judul: 'Monitor tidak menyala',
        kategori: 'error',
      );

      final openErrors = ValueNotifier<List<DailyTaskModel>>([openError]);
      final ringing = ValueNotifier<bool>(true);

      final key = GlobalKey();
      await tester.pumpWidget(
        _wrapScreen(
          screen: ErrorAlarmOverlay(
            openErrors: openErrors,
            ringing: ringing,
            onLihat: () {},
            child: const TeknisiDailyTasksScreen(),
          ),
          boundaryKey: key,
          theme: AppTheme.lightTheme,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('LOKASI ERROR'), findsOneWidget);
      expect(find.textContaining('Monitor tidak menyala'), findsWidgets);

      await _saveBoundaryAsPng(tester, key, '$outBase/01-alarm.png', overwrite: true);
      expect(File('$outBase/01-alarm.png').existsSync(), isTrue);
    });

    testWidgets('02 technician Daily Task screen without alarm showing error ticket', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final key = GlobalKey();
      await tester.pumpWidget(
        _wrapScreen(
          screen: const TeknisiDailyTasksScreen(),
          boundaryKey: key,
          theme: AppTheme.lightTheme,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('LOKASI ERROR'), findsNothing);

      await _saveBoundaryAsPng(tester, key, '$outBase/02-daily-task-tiket.png', overwrite: true);
      expect(File('$outBase/02-daily-task-tiket.png').existsSync(), isTrue);
    });

    testWidgets('03 CustomTaskExecutionScreen error mode empty', (tester) async {
      tester.view.physicalSize = const Size(1170, 2700);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      customTaskNow = () => DateTime(2026, 11, 12, 9, 26);

      final report = ErrorReport.parse(_storyAdminText);
      final errorDeskripsi = report.toDeskripsi(_storyAdminText);

      final errorTask = DailyTaskModel(
        id: 't_err_exec',
        tanggal: '2026-11-12',
        teknisiId: 'usr_ryan',
        teknisiNama: 'Farhan Lakoro',
        posName: mgnwPosName,
        posTag: 'MGNW',
        judul: report.judul(_storyAdminText),
        deskripsi: errorDeskripsi,
        kategori: ErrorTicketService.kategori,
      );

      final key = GlobalKey();
      await tester.pumpWidget(
        _wrapScreen(
          screen: CustomTaskExecutionScreen(task: errorTask),
          boundaryKey: key,
          theme: AppTheme.lightTheme,
          height: 900,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Dilaporkan 09.11 · sudah 15 menit'), findsOneWidget);
      expect(find.textContaining('Monitor tidak menyala'), findsWidgets);

      await _saveBoundaryAsPng(tester, key, '$outBase/03-selesaikan-kosong.png', overwrite: true);
      expect(File('$outBase/03-selesaikan-kosong.png').existsSync(), isTrue);
    });

    testWidgets('04 CustomTaskExecutionScreen filled with penyebab, solusi, and photos', (tester) async {
      tester.view.physicalSize = const Size(1170, 2700);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      customTaskNow = () => DateTime(2026, 11, 12, 9, 26);

      final report = ErrorReport.parse(_storyAdminText);
      final errorDeskripsi = report.toDeskripsi(_storyAdminText);

      final errorTask = DailyTaskModel(
        id: 't_err_exec_filled',
        tanggal: '2026-11-12',
        teknisiId: 'usr_ryan',
        teknisiNama: 'Farhan Lakoro',
        posName: mgnwPosName,
        posTag: 'MGNW',
        judul: report.judul(_storyAdminText),
        deskripsi: errorDeskripsi,
        kategori: ErrorTicketService.kategori,
      );

      final draftKey = 'daily_task_draft_${errorTask.id}';
      final draftData = {
        'photos': [dummyPhotoFile.path, dummyPhotoFile2.path],
        'videos': [],
        'catatan': '',
        'penyebab': 'Adaptor monitor rusak',
        'solusi': 'Ganti adaptor baru',
      };
      await StorageService.setString(draftKey, jsonEncode(draftData));

      final key = GlobalKey();
      await tester.runAsync(() async {
        await tester.pumpWidget(
          _wrapScreen(
            screen: CustomTaskExecutionScreen(task: errorTask),
            boundaryKey: key,
            theme: AppTheme.lightTheme,
            height: 900,
          ),
        );
        for (final el in find.byType(Image).evaluate()) {
          final imgWidget = el.widget as Image;
          await precacheImage(imgWidget.image, el);
        }
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Dilaporkan 09.11 · sudah 15 menit'), findsOneWidget);
      expect(find.text('Adaptor monitor rusak'), findsOneWidget);
      expect(find.text('Ganti adaptor baru'), findsOneWidget);

      await _saveBoundaryAsPng(tester, key, '$outBase/04-selesaikan-terisi.png', overwrite: true);
      expect(File('$outBase/04-selesaikan-terisi.png').existsSync(), isTrue);
    });

    testWidgets('05 Laporan siap dikirim dialog over 04', (tester) async {
      tester.view.physicalSize = const Size(1170, 2700);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      customTaskNow = () => DateTime(2026, 11, 12, 9, 26);

      final report = ErrorReport.parse(_storyAdminText);
      final errorDeskripsi = report.toDeskripsi(_storyAdminText);

      final errorTask = DailyTaskModel(
        id: 't_err_exec_dialog',
        tanggal: '2026-11-12',
        teknisiId: 'usr_ryan',
        teknisiNama: 'Farhan Lakoro',
        posName: mgnwPosName,
        posTag: 'MGNW',
        judul: report.judul(_storyAdminText),
        deskripsi: errorDeskripsi,
        kategori: ErrorTicketService.kategori,
      );

      final draftKey = 'daily_task_draft_${errorTask.id}';
      final draftData = {
        'photos': [dummyPhotoFile.path, dummyPhotoFile2.path],
        'videos': [],
        'catatan': '',
        'penyebab': 'Adaptor monitor rusak',
        'solusi': 'Ganti adaptor baru',
      };
      await StorageService.setString(draftKey, jsonEncode(draftData));

      final key = GlobalKey();
      await tester.runAsync(() async {
        await tester.pumpWidget(
          _wrapScreen(
            screen: CustomTaskExecutionScreen(task: errorTask),
            boundaryKey: key,
            theme: AppTheme.lightTheme,
            height: 900,
          ),
        );
        for (final el in find.byType(Image).evaluate()) {
          final imgWidget = el.widget as Image;
          await precacheImage(imgWidget.image, el);
        }
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final dynamic state = tester.state(find.byType(CustomTaskExecutionScreen));
      state.showPostSaveDialogForTesting();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Laporan siap dikirim'), findsOneWidget);
      expect(find.textContaining('Kamis, 12 November 2026'), findsOneWidget);
      expect(find.textContaining('- Kendala : Monitor tidak menyala'), findsOneWidget);
      expect(find.textContaining('- Durasi Perbaikan : 15 menit'), findsOneWidget);

      await _saveBoundaryAsPng(tester, key, '$outBase/05-laporan-siap.png', overwrite: true);
      expect(File('$outBase/05-laporan-siap.png').existsSync(), isTrue);
    });
  });
}
