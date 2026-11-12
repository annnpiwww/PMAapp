import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
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
import 'package:bssparking_timemark/data/services/maintenance_log_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/daily_tasks/screens/custom_task_execution_screen.dart';
import 'package:bssparking_timemark/features/daily_tasks/screens/teknisi_daily_tasks_screen.dart';
import 'package:bssparking_timemark/features/daily_tasks/widgets/ad_hoc_task_dialog.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_location_detail_screen.dart';
import 'package:bssparking_timemark/features/maintenance/screens/maintenance_map_screen.dart';

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

const String _storyAdminText = '''Selamat pagi
Izin melaporkan telah terjadi kendala operasional dengan kronologi sebagai berikut:

Tanggal : 11-Nov-2026
Waktu : 10.00
Lokasi : MGNW

Kendala : Kode tiket muncul alert seperti di gambar, bug ketika pindah ke menu scan muncul camout
Penyebab : -

Solusi sementara :

Durasi Error :

Berikut kami lampirkan
Mohon bantuan dari bapak2 teknisi untuk diperbaiki

Terima kasih''';

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

Widget _wrapSheet({
  required Widget child,
  required GlobalKey boundaryKey,
  required ThemeData theme,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(390, 844),
        padding: EdgeInsets.only(top: 24, bottom: 24),
        devicePixelRatio: 3.0,
      ),
      child: Scaffold(
        backgroundColor: Colors.black54,
        body: Align(
          alignment: Alignment.bottomCenter,
          child: RepaintBoundary(
            key: boundaryKey,
            child: child,
          ),
        ),
      ),
    ),
  );
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

  String? mockClipboardText;
  late File dummyPhotoFile;

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

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        if (mockClipboardText == null) return null;
        return <String, dynamic>{'text': mockClipboardText};
      }
      return null;
    });

    final tempDir = Directory.systemTemp.createTempSync('bss_video_test_');
    dummyPhotoFile = File('${tempDir.path}/evidence_photo.png');
    final realAssetPhoto = File('assets/foto absensi/absen1.png');
    if (realAssetPhoto.existsSync()) {
      dummyPhotoFile.writeAsBytesSync(realAssetPhoto.readAsBytesSync());
    } else {
      dummyPhotoFile.writeAsBytesSync(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAI0lEQVR4nGNMKelmIAUwkaSaYVQDcYCJSHVwMKqBGEByKAEAcI8Bg4SnJzQAAAAASUVORK5CYII=',
      ));
    }
  });

  const mgnwPosName = 'Mie Gacoan Nani Wartabone';
  const outBase = 'docs/screenshots/video-laporan-error';

  late PosLocation mgnwLoc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
    await BranchService.instance.setBranch(AppBranch.manado);

    mgnwLoc = LocationService.allLocations.firstWhere(
      (l) => l.locationTag == 'MGNW',
    );

    mockClipboardText = null;

    final ryan = UserModel(
      id: 'usr_ryan',
      nama: 'Ryan Lumasuge',
      npp: '10293',
      email: 'ryan@bssparking.com',
      role: UserRole.petugas,
      posId: 'POS-MGNW-01',
      posName: mgnwPosName,
      cabangName: 'KC BSG',
    );
    await AuthRepository.instance.login(ryan);

    final tasks = [
      DailyTaskModel(
        id: 't_01',
        tanggal: '2026-11-11',
        teknisiId: 'usr_ryan',
        teknisiNama: 'Ryan Lumasuge',
        posName: mgnwPosName,
        posTag: 'MGNW',
        judul: 'Maintenance Rutin Barrier Gate In',
        kategori: 'maintenance',
        templateId: 'tpl_maint_barrier',
        status: TaskStatus.inProgress,
      ),
      DailyTaskModel(
        id: 't_02',
        tanggal: '2026-11-11',
        teknisiId: 'usr_ryan',
        teknisiNama: 'Ryan Lumasuge',
        posName: mgnwPosName,
        posTag: 'MGNW',
        judul: 'Pembersihan Sensor & Dispenser Tiket',
        kategori: 'maintenance',
        templateId: 'tpl_maint_pos',
        status: TaskStatus.pending,
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

  group('Laporan Error Video Flow Screenshots', () {
    testWidgets('01 AdHocTaskDialog technician, tab Laporan error selected, before paste', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final key = GlobalKey();
      await tester.pumpWidget(
        _wrapSheet(
          child: AdHocTaskDialog(
            teknisiNama: 'Ryan Lumasuge',
            tanggal: '2026-11-11',
            lokasiOptions: LocationService.allLocations,
          ),
          boundaryKey: key,
          theme: AppTheme.lightTheme,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Laporan error'));
      await tester.pumpAndSettle();

      expect(find.text('Tempel dari Telegram'), findsOneWidget);

      await _saveBoundaryAsPng(tester, key, '$outBase/01-catat-kosong.png', overwrite: false);
      expect(File('$outBase/01-catat-kosong.png').existsSync(), isTrue);
    });

    testWidgets('02 same after paste (all fields filled, Lokasi = MGNW pos)', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      mockClipboardText = _storyAdminText;
      final key = GlobalKey();
      await tester.pumpWidget(
        _wrapSheet(
          child: AdHocTaskDialog(
            teknisiNama: 'Ryan Lumasuge',
            tanggal: '2026-11-11',
            lokasiOptions: LocationService.allLocations,
          ),
          boundaryKey: key,
          theme: AppTheme.lightTheme,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Laporan error'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tempel dari Telegram'));
      await tester.pumpAndSettle();

      expect(find.text('Rab, 11 Nov 2026 · 10.00'), findsOneWidget);
      expect(find.text(mgnwPosName), findsOneWidget);

      await _saveBoundaryAsPng(tester, key, '$outBase/02-catat-terisi.png', overwrite: false);
      expect(File('$outBase/02-catat-terisi.png').existsSync(), isTrue);
    });

    testWidgets('03 ErrorAlarmOverlay ringing over the technician Daily Task screen, one open ticket at MGNW pos', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final openError = DailyTaskModel(
        id: 't_err_mgnw',
        tanggal: '2026-11-11',
        teknisiId: 'usr_ryan',
        teknisiNama: 'Ryan Lumasuge',
        posName: mgnwPosName,
        posTag: 'MGNW',
        judul: 'Kode tiket muncul alert seperti di gambar, bug ketika pindah ke menu scan muncul camout',
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
      expect(find.textContaining('Kode tiket muncul alert'), findsOneWidget);

      await _saveBoundaryAsPng(tester, key, '$outBase/03-alarm-banner.png', overwrite: false);
      expect(File('$outBase/03-alarm-banner.png').existsSync(), isTrue);
    });

    testWidgets('04 MaintenanceMapScreen online state, radar on MGNW marker, chip 1 lokasi error, month Nov 2026', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mapController = MapController();
      final key = GlobalKey();
      await tester.pumpWidget(
        _wrapScreen(
          screen: MaintenanceMapScreen(
            showTileLayer: false,
            mapController: mapController,
            initialErrorPosNames: const {mgnwPosName},
          ),
          boundaryKey: key,
          theme: AppTheme.lightTheme,
        ),
      );
      await tester.pump();
      mapController.move(LatLng(mgnwLoc.lat, mgnwLoc.lng), 14.0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('1 lokasi error'), findsOneWidget);
      expect(find.text('$mgnwPosName · Error'), findsOneWidget);
      expect(find.textContaining('Offline'), findsNothing);

      await _saveBoundaryAsPng(tester, key, '$outBase/04-map-radar.png', overwrite: false);
      expect(File('$outBase/04-map-radar.png').existsSync(), isTrue);
    });

    testWidgets('04b MaintenanceLocationDetailScreen with open error ticket section', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mgnwTicket = DailyTaskModel(
        id: 't_err_mgnw_detail',
        tanggal: '2026-11-11',
        teknisiId: 'usr_ryan',
        teknisiNama: 'Ryan Lumasuge',
        posName: mgnwPosName,
        posTag: 'MGNW',
        judul: 'Kode tiket muncul alert seperti di gambar, bug ketika pindah ke menu scan muncul camout',
        deskripsi: _storyAdminText,
        kategori: 'error',
        status: TaskStatus.pending,
      );

      final mgnwStatus = PosMaintenanceStatus(
        location: mgnwLoc,
        wilayah: 'Gorontalo',
        logs: const [],
      );

      final key = GlobalKey();
      await tester.pumpWidget(
        _wrapScreen(
          screen: MaintenanceLocationDetailScreen(
            status: mgnwStatus,
            month: DateTime(2026, 11, 1),
            errorTicketsLoader: () async => [mgnwTicket],
          ),
          boundaryKey: key,
          theme: AppTheme.lightTheme,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LAPORAN ERROR'), findsOneWidget);
      expect(find.textContaining('Kode tiket muncul alert'), findsOneWidget);

      await _saveBoundaryAsPng(tester, key, '$outBase/04b-detail-error.png', overwrite: false);
      expect(File('$outBase/04b-detail-error.png').existsSync(), isTrue);
    });

    testWidgets('05 CustomTaskExecutionScreen error mode empty', (tester) async {
      tester.view.physicalSize = const Size(1170, 2700);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      customTaskNow = () => DateTime(2026, 11, 11, 10, 15);

      final report = ErrorReport.parse(_storyAdminText);
      final errorDeskripsi = report.toDeskripsi(_storyAdminText);

      final errorTask = DailyTaskModel(
        id: 't_err_exec',
        tanggal: '2026-11-11',
        teknisiId: 'usr_ryan',
        teknisiNama: 'Ryan Lumasuge',
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

      expect(find.text('Dilaporkan 10.00 · sudah 15 menit'), findsOneWidget);

      await _saveBoundaryAsPng(tester, key, '$outBase/05-selesaikan-kosong.png');
      expect(File('$outBase/05-selesaikan-kosong.png').existsSync(), isTrue);
    });

    testWidgets('06 same with Penyebab and Solusi perbaikan and photo thumbnail', (tester) async {
      tester.view.physicalSize = const Size(1170, 2700);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      customTaskNow = () => DateTime(2026, 11, 11, 10, 15);

      final report = ErrorReport.parse(_storyAdminText);
      final errorDeskripsi = report.toDeskripsi(_storyAdminText);

      final errorTask = DailyTaskModel(
        id: 't_err_exec_filled',
        tanggal: '2026-11-11',
        teknisiId: 'usr_ryan',
        teknisiNama: 'Ryan Lumasuge',
        posName: mgnwPosName,
        posTag: 'MGNW',
        judul: report.judul(_storyAdminText),
        deskripsi: errorDeskripsi,
        kategori: ErrorTicketService.kategori,
      );

      final draftKey = 'daily_task_draft_${errorTask.id}';
      final draftData = {
        'photos': [dummyPhotoFile.path],
        'videos': [],
        'catatan': '',
        'penyebab': 'app version tidak support',
        'solusi': 'Update version aplikasi oleh team PRD',
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
        final el = tester.element(find.byType(Image));
        final imgWidget = el.widget as Image;
        await precacheImage(imgWidget.image, el);
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Dilaporkan 10.00 · sudah 15 menit'), findsOneWidget);
      expect(find.text('app version tidak support'), findsOneWidget);
      expect(find.text('Update version aplikasi oleh team PRD'), findsOneWidget);

      final rawImg = tester.widget<RawImage>(find.byType(RawImage));
      debugPrint('Screen 06 RawImage image: ${rawImg.image}');

      final btnRect = tester.getRect(find.text('Simpan & Buat Laporan'));
      debugPrint('Screen 06 button rect: $btnRect');

      await _saveBoundaryAsPng(tester, key, '$outBase/06-selesaikan-terisi.png');
      expect(File('$outBase/06-selesaikan-terisi.png').existsSync(), isTrue);
    });

    testWidgets('07 Laporan siap dikirim dialog over 06, reply text visible', (tester) async {
      tester.view.physicalSize = const Size(1170, 2700);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      customTaskNow = () => DateTime(2026, 11, 11, 10, 15);

      final report = ErrorReport.parse(_storyAdminText);
      final errorDeskripsi = report.toDeskripsi(_storyAdminText);

      final errorTask = DailyTaskModel(
        id: 't_err_exec_dialog',
        tanggal: '2026-11-11',
        teknisiId: 'usr_ryan',
        teknisiNama: 'Ryan Lumasuge',
        posName: mgnwPosName,
        posTag: 'MGNW',
        judul: report.judul(_storyAdminText),
        deskripsi: errorDeskripsi,
        kategori: ErrorTicketService.kategori,
      );

      final draftKey = 'daily_task_draft_${errorTask.id}';
      final draftData = {
        'photos': [dummyPhotoFile.path],
        'videos': [],
        'catatan': '',
        'penyebab': 'app version tidak support',
        'solusi': 'Update version aplikasi oleh team PRD',
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
        final el = tester.element(find.byType(Image));
        final imgWidget = el.widget as Image;
        await precacheImage(imgWidget.image, el);
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final dynamic state = tester.state(find.byType(CustomTaskExecutionScreen));
      state.showPostSaveDialogForTesting();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Laporan siap dikirim'), findsOneWidget);
      expect(find.textContaining('Selamat pagi'), findsOneWidget);
      expect(find.textContaining('Rabu, 11 November 2026'), findsOneWidget);
      expect(find.textContaining('- Durasi Perbaikan : 15 menit'), findsOneWidget);

      await _saveBoundaryAsPng(tester, key, '$outBase/07-laporan-siap.png');
      expect(File('$outBase/07-laporan-siap.png').existsSync(), isTrue);
    });

    testWidgets('08 same map as 04 with no open ticket', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mapController = MapController();
      final key = GlobalKey();
      await tester.pumpWidget(
        _wrapScreen(
          screen: MaintenanceMapScreen(
            showTileLayer: false,
            mapController: mapController,
            initialErrorPosNames: const {},
          ),
          boundaryKey: key,
          theme: AppTheme.lightTheme,
        ),
      );
      await tester.pump();
      mapController.move(LatLng(mgnwLoc.lat, mgnwLoc.lng), 14.0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('1 lokasi error'), findsNothing);
      expect(find.textContaining('Offline'), findsNothing);

      await _saveBoundaryAsPng(tester, key, '$outBase/08-map-bersih.png', overwrite: false);
      expect(File('$outBase/08-map-bersih.png').existsSync(), isTrue);
    });

    testWidgets('09 technician Daily Task screen, no alarm', (tester) async {
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
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('LOKASI ERROR'), findsNothing);

      await _saveBoundaryAsPng(tester, key, '$outBase/09-daily-task.png', overwrite: false);
      expect(File('$outBase/09-daily-task.png').existsSync(), isTrue);
    });
  });
}
