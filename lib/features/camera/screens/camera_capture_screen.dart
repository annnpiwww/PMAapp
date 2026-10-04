import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/utils/verification_code.dart';
import '../../../core/utils/share_helper.dart';
import '../../../core/widgets/verification_step_card.dart';
import '../../../core/utils/timemark_formatter.dart';
import '../../../core/utils/image_watermark_processor.dart';
import '../../../data/models/submission_model.dart';
import '../../../data/models/template_model.dart';
import '../../../data/models/watermark_config.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/template_repository.dart';
import '../../../data/repositories/submission_repository.dart';
import '../../../data/services/ai_vision_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/whatsapp_report_service.dart';
import '../../../data/services/absensi_setup_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/secure_time_service.dart';
import '../../../data/services/notification_service.dart';
import '../widgets/interactive_watermark.dart';
import '../widgets/sop_verification_modal.dart';
import '../../history/screens/gallery_screen.dart';
import '../../maintenance/screens/maintenance_history_screen.dart';
import '../../locations/widgets/location_picker_modal.dart';
import '../../maintenance/widgets/maintenance_setup_dialog.dart';
import '../../../data/models/attendance_record.dart';
import '../../history/screens/attendance_archive_screen.dart';
import '../../templates/widgets/absensi_kategori_dialog.dart';
import '../widgets/daily_pulang_bottom_sheet.dart';
import '../../auth/screens/login_screen.dart';
import '../../daily_tasks/screens/spv_task_dispatcher_screen.dart';
import '../../daily_tasks/screens/teknisi_daily_tasks_screen.dart';
import '../../../data/models/user_model.dart';

/// Aspect ratio presets for camera viewfinder.
enum CameraAspectRatio {
  ratio1x1,
  ratio3x4,
  ratio9x16,
  ratioFull;

  /// Returns width / height ratio in portrait orientation.
  /// Null indicates full screen (matches container dimensions).
  double? get value {
    switch (this) {
      case CameraAspectRatio.ratio1x1:
        return 1.0;
      case CameraAspectRatio.ratio3x4:
        return 3 / 4; // 0.75
      case CameraAspectRatio.ratio9x16:
        return 9 / 16; // 0.5625
      case CameraAspectRatio.ratioFull:
        return null;
    }
  }

  String get label {
    switch (this) {
      case CameraAspectRatio.ratio1x1:
        return '1:1';
      case CameraAspectRatio.ratio3x4:
        return '3:4';
      case CameraAspectRatio.ratio9x16:
        return '9:16';
      case CameraAspectRatio.ratioFull:
        return 'Full';
    }
  }

  String get description {
    switch (this) {
      case CameraAspectRatio.ratio1x1:
        return 'Persegi Kotak (1:1)';
      case CameraAspectRatio.ratio3x4:
        return 'Standar Foto (3:4)';
      case CameraAspectRatio.ratio9x16:
        return 'Widescreen Vertikal (9:16)';
      case CameraAspectRatio.ratioFull:
        return 'Penuh Layar Transparan';
    }
  }

  IconData get icon {
    switch (this) {
      case CameraAspectRatio.ratio1x1:
        return Icons.crop_square_rounded;
      case CameraAspectRatio.ratio3x4:
        return Icons.crop_portrait_rounded;
      case CameraAspectRatio.ratio9x16:
        return Icons.crop_16_9_rounded;
      case CameraAspectRatio.ratioFull:
        return Icons.fullscreen_rounded;
    }
  }
}

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  late TemplateModel _selectedTemplate;

  // Real Camera Controller
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  int _selectedCameraIndex = 0;

  LocationResult? _location;
  bool _isProcessingAI = false;
  int _captureStep = 0; // 1=Memproses foto,2=Mengirim ke AI,3=Sedang diverifikasi,4=Verifikasi selesai
  Completer<AiVerificationResult>? _aiBypassCompleter;

  // Watermark Customization State (Persisted)
  WatermarkConfig _watermarkConfig = const WatermarkConfig();

  // Active Location Tags
  PosLocation _activePos = LocationService.currentPos;

  // NOTE: Data absensi (kategori, standby, shift, tipe, pulang) dikelola di
  // AbsensiSetupService (diisi di halaman SOP). Tidak ada state lokal lagi
  // agar tidak ada 2 sumber kebenaran.

  // Camera Settings State
  FlashMode _flashMode = FlashMode.off;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 5.0;

  // Aspect Ratio Selector (Default: 3:4 portrait standard)
  CameraAspectRatio _aspectRatio = CameraAspectRatio.ratio3x4;
  int _timerSeconds = 0;
  int _countdownValue = 0;
  bool _isCountingDown = false;
  Timer? _countdownTimer;
  Timer? _liveAttendanceTimer;

  // Tap-to-Focus visual feedback state
  Offset? _focusPoint;
  bool _showFocusRing = false;
  Timer? _focusRingTimer;

  // Cached frame dimensions for aspect ratio matching
  double _lastFrameW = 0.0;
  double _lastFrameH = 0.0;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final templates = TemplateRepository.instance.templates;
    _selectedTemplate = templates.isNotEmpty
        ? templates.first
        : TemplateRepository.defaultTemplates.first;

    _activePos = LocationService.currentPos;
    _timerSeconds = StorageService.getCameraTimerSeconds();

    // Load persisted watermark configuration
    final savedConfig = StorageService.getWatermarkConfig();
    _watermarkConfig = savedConfig;

    // Minta izin kamera & lokasi langsung di frame pertama UI muncul,
    // lalu init kamera & lokasi setelah izin diberikan (tidak perlu pancing
    // tombol switch kamera lagi).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestInitialPermissionsAndInit();
    });

    TemplateRepository.instance.addListener(_onTemplateRepoChange);
    SubmissionRepository.instance.addListener(_onSubmissionRepoChange);
    AbsensiSetupService.instance.addListener(_onAbsensiSetupChange);

    _liveAttendanceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    TemplateRepository.instance.removeListener(_onTemplateRepoChange);
    SubmissionRepository.instance.removeListener(_onSubmissionRepoChange);
    AbsensiSetupService.instance.removeListener(_onAbsensiSetupChange);
    _countdownTimer?.cancel();
    _liveAttendanceTimer?.cancel();
    _focusRingTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  void _handleTapToFocus(Offset localPos, double frameW, double frameH) {
    if (frameW <= 0 || frameH <= 0) return;
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    final dx = (localPos.dx / frameW).clamp(0.0, 1.0);
    final dy = (localPos.dy / frameH).clamp(0.0, 1.0);

    try {
      controller.setFocusMode(FocusMode.auto);
      controller.setFocusPoint(Offset(dx, dy));
      controller.setExposurePoint(Offset(dx, dy));
    } catch (_) {}

    setState(() {
      _focusPoint = localPos;
      _showFocusRing = true;
    });

    _focusRingTimer?.cancel();
    _focusRingTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() => _showFocusRing = false);
      }
    });
  }

  void _startTimedCapture() {
    if (_isCountingDown || _isProcessingAI) return;
    if (_timerSeconds <= 0) {
      _handleCapturePhoto();
      return;
    }
    setState(() {
      _isCountingDown = true;
      _countdownValue = _timerSeconds;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownValue <= 1) {
        timer.cancel();
        setState(() {
          _isCountingDown = false;
          _countdownValue = 0;
        });
        _handleCapturePhoto();
      } else {
        setState(() => _countdownValue -= 1);
      }
    });
  }

  void _cancelTimer() {
    _countdownTimer?.cancel();
    if (mounted && _isCountingDown) {
      setState(() {
        _isCountingDown = false;
        _countdownValue = 0;
      });
    }
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }
    // Hanya dispose kamera saat aplikasi benar-benar di background (paused),
    // bukan saat sekadar ada dialog/modal muncul (inactive).
    if (state == AppLifecycleState.paused) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
      _checkGpsServiceAndPrompt();
      _fetchLocation();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      if (_cameraController != null) {
        try {
          await _cameraController!.dispose();
        } catch (_) {}
        _cameraController = null;
      }

      final presets = [
        ResolutionPreset.max,
        ResolutionPreset.ultraHigh,
        ResolutionPreset.veryHigh,
        ResolutionPreset.high,
        ResolutionPreset.medium,
      ];

      CameraController? initializedController;
      for (final preset in presets) {
        try {
          final controller = CameraController(
            _cameras[_selectedCameraIndex],
            preset,
            enableAudio: false,
            imageFormatGroup: ImageFormatGroup.jpeg,
          );
          await controller.initialize();
          initializedController = controller;
          break;
        } catch (err) {
          debugPrint('[CameraCaptureScreen] Failed preset $preset: $err');
        }
      }

      if (initializedController == null) {
        debugPrint('[CameraCaptureScreen] All camera presets failed');
        return;
      }

      final controller = initializedController;
      _cameraController = controller;
      await controller.setFlashMode(_flashMode);

      // Enable continuous Auto-Focus (AF) and Auto-Exposure (AE) so the
      // viewfinder stays sharp and well-exposed like a stock camera app.
      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}
      try {
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {}

      // Lock the AF/AE regions to the screen center initially so the
      // subject is in focus the instant the preview appears.
      try {
        final previewSize =
            controller.value.previewSize ?? const Size(720, 1280);
        await controller.setFocusPoint(Offset(0.5, 0.5));
        await controller.setExposurePoint(Offset(0.5, 0.5));
        // silence unused previewSize warning
        assert(previewSize.width > 0);
      } catch (_) {}

      try {
        _minZoom = await controller.getMinZoomLevel();
        _maxZoom = await controller.getMaxZoomLevel();
      } catch (_) {
        _minZoom = 1.0;
        _maxZoom = 5.0;
      }

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    }
  }

  Future<void> _toggleCameraFlip() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _cameraController?.dispose();
    _isCameraInitialized = false;
    setState(() {});
    await _initCamera();
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_isCameraInitialized) return;
    FlashMode nextMode;
    switch (_flashMode) {
      case FlashMode.off:
        nextMode = FlashMode.auto;
        break;
      case FlashMode.auto:
        nextMode = FlashMode.always;
        break;
      case FlashMode.always:
        nextMode = FlashMode.torch;
        break;
      case FlashMode.torch:
        nextMode = FlashMode.off;
        break;
    }

    try {
      await _cameraController!.setFlashMode(nextMode);
      setState(() {
        _flashMode = nextMode;
      });
    } catch (_) {}
  }

  Future<void> _setZoom(double zoom) async {
    if (_cameraController == null || !_isCameraInitialized) return;
    try {
      final target = zoom.clamp(_minZoom, _maxZoom);
      await _cameraController!.setZoomLevel(target);
      setState(() {
        _currentZoom = target;
      });
    } catch (_) {}
  }

  void _onTemplateRepoChange() {
    if (!mounted) return;
    final templates = TemplateRepository.instance.templates;
    if (templates.isNotEmpty &&
        !templates.any((t) => t.id == _selectedTemplate.id)) {
      setState(() {
        _selectedTemplate = templates.first;
      });
    } else {
      setState(() {});
    }
  }

  void _onSubmissionRepoChange() {
    if (mounted) setState(() {});
  }

  void _onAbsensiSetupChange() {
    if (mounted) setState(() {});
  }

  Future<void> _fetchLocation() async {
    final loc = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _location = loc;
      });
    }
  }

  bool _isGpsDialogShowing = false;

  Future<bool> _checkGpsServiceAndPrompt({bool forceShow = false}) async {
    if (kIsWeb) return true;
    try {
      final isEnabled = await LocationService.isGpsServiceEnabled();
      if (!isEnabled) {
        if (!_isGpsDialogShowing && mounted) {
          _showGpsMandatoryDialog();
        }
        return false;
      } else {
        if (_isGpsDialogShowing && mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          _isGpsDialogShowing = false;
        }
        return true;
      }
    } catch (_) {
      return true;
    }
  }

  void _showGpsMandatoryDialog() {
    if (_isGpsDialogShowing || !mounted) return;
    _isGpsDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: const Color(0xFF0F2C59),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_off_rounded, color: Colors.redAccent, size: 24),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Layanan Lokasi (GPS) Wajib Aktif',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Layanan lokasi (GPS) pada perangkat Anda saat ini nonaktif atau belum menyala.',
                style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
              ),
              SizedBox(height: 10),
              Text(
                'Sistem PMA App mewajibkan GPS aktif untuk verifikasi presensi yang sah dan pencegahan fraud. Silakan aktifkan GPS perangkat Anda.',
                style: TextStyle(fontSize: 12, color: Colors.amberAccent, height: 1.4),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white30),
              ),
              onPressed: () async {
                final active = await LocationService.isGpsServiceEnabled();
                if (active) {
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  _isGpsDialogShowing = false;
                  _fetchLocation();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Layanan GPS berhasil aktif!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('GPS masih nonaktif. Mohon nyalakan lokasi di pengaturan.'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              child: const Text('Cek Ulang'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF071731),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.settings_rounded, size: 18),
              onPressed: () async {
                await LocationService.openLocationSettings();
              },
              label: const Text(
                'Aktifkan GPS',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      _isGpsDialogShowing = false;
    });
  }

  Future<void> _requestInitialPermissionsAndInit() async {
    // Minta izin secara batch agar Android OS menampilkan dialog izin berurutan (carousel)
    // tanpa race condition atau memaksa user force-close antar dialog permission.
    try {
      await [
        Permission.camera,
        Permission.location,
        Permission.notification,
      ].request();
    } catch (_) {}

    // Periksa apakah izin penting sudah di-acc
    try {
      final cameraGranted = await Permission.camera.isGranted;
      final locationGranted = await Permission.location.isGranted;

      if ((!cameraGranted || !locationGranted) && mounted) {
        _showPermissionRequiredDialog();
      }
    } catch (_) {}

    // Periksa apakah GPS aktif
    if (mounted) {
      await _checkGpsServiceAndPrompt();
    }

    // Inisialisasi lokasi di background
    _loadLocationInBackground();

    // Langsung init kamera agar viewfinder menyala instan
    await _initCamera();
  }

  void _showPermissionRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: AppColors.primary, size: 24),
            SizedBox(width: 8),
            Text('Izin Diperlukan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Untuk mematuhi SOP BSS Parking, aplikasi memerlukan izin Kamera, Lokasi (GPS), dan Notifikasi.\n\n'
          'Mohon setujui semua izin (acc) agar aplikasi dapat digunakan.',
          style: TextStyle(fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _requestInitialPermissionsAndInit();
            },
            child: const Text('Coba Lagi'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await openAppSettings();
            },
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }


  /// Cold start optimization: get last known position immediately
  void _loadLocationInBackground() {
    if (kIsWeb) {
      _fetchLocation();
      return;
    }
    Geolocator.getLastKnownPosition()
        .then((last) {
          if (!mounted || last == null) return;
          final pos = LocationService.currentPos;
          setState(() {
            _location = LocationResult(
              lat: last.latitude,
              lng: last.longitude,
              accuracyMeter: last.accuracy,
              isGpsEnabled: true,
              posName: pos.posName,
              cabangName: pos.cabangName,
              fullAddress: pos.fullAddress,
              locationTag: pos.locationTag,
              tagColor: pos.tagColor,
            );
          });
        })
        .catchError((_) {});

    _fetchLocation();
  }

  void _showRatioPickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Pilih Aspek Rasio Kamera',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            ...CameraAspectRatio.values.map((ratio) {
              final isSelected = _aspectRatio == ratio;
              return ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                tileColor: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                leading: Icon(
                  ratio.icon,
                  color: isSelected ? AppColors.accent : Colors.white70,
                  size: 22,
                ),
                title: Text(
                  ratio.label,
                  style: TextStyle(
                    color: isSelected ? AppColors.accent : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  ratio.description,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                trailing: isSelected
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.accent,
                        size: 20,
                      )
                    : null,
                onTap: () {
                  setState(() => _aspectRatio = ratio);
                  Navigator.of(ctx).pop();
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showTimerPickerModal() {
    final timerOptions = [
      (
        seconds: 0,
        label: 'Tanpa Timer (Mati)',
        desc: 'Foto langsung diambil saat tombol ditekan',
      ),
      (
        seconds: 3,
        label: '3 Detik',
        desc: 'Hitung mundur cepat untuk foto lebih stabil',
      ),
      (
        seconds: 5,
        label: '5 Detik',
        desc: 'Waktu ideal untuk bersiap sebelum jepretan',
      ),
      (
        seconds: 10,
        label: '10 Detik',
        desc: 'Waktu cukup untuk foto bersama / jarak jauh',
      ),
      (
        seconds: 15,
        label: '15 Detik',
        desc: 'Waktu ekstra untuk posisi teknisi di lapangan',
      ),
      (
        seconds: 20,
        label: '20 Detik',
        desc: 'Durasi maksimal untuk inspeksi & persiapan area',
      ),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Timer Kamera',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...timerOptions.map((opt) {
                final isSelected = _timerSeconds == opt.seconds;
                return ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  tileColor: isSelected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppColors.accent.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.08),
                      border: Border.all(
                        color: isSelected ? AppColors.accent : Colors.white24,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: opt.seconds == 0
                          ? Icon(
                              Icons.timer_off_outlined,
                              color: isSelected
                                  ? AppColors.accent
                                  : Colors.white70,
                              size: 18,
                            )
                          : Text(
                              '${opt.seconds}s',
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.accent
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                    ),
                  ),
                  title: Text(
                    opt.label,
                    style: TextStyle(
                      color: isSelected ? AppColors.accent : Colors.white,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    opt.desc,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.accent,
                          size: 20,
                        )
                      : null,
                  onTap: () {
                    setState(() => _timerSeconds = opt.seconds);
                    StorageService.saveCameraTimerSeconds(opt.seconds);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showRealtimeLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LocationPickerModal(
        activePos: _activePos,
        onLocationSelected: (newPos) {
          LocationService.setCurrentPos(newPos);
          final updatedConfig = _watermarkConfig.copyWith(
            badgeTag: newPos.locationTag,
            badgeColor: newPos.tagColor,
          );
          setState(() {
            _activePos = newPos;
            _watermarkConfig = updatedConfig;
          });
          StorageService.saveWatermarkConfig(updatedConfig);
          _fetchLocation();
        },
      ),
    );
  }

  void _showTemplateQuickPicker() {
    final templates = TemplateRepository.instance.templates;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bCtx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle Bar Minimalis
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.checklist_rtl_rounded,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pilih Template SOP',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 1),
                              Text(
                                'Tentukan alur kerja pemeriksaan atau absensi',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () => Navigator.of(bCtx).pop(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: AppColors.cardBorder, height: 1),
                  const SizedBox(height: 12),

                  // List Template Cards (Tactical Modern Bento Cards)
                  ...templates.map((t) {
                    final isSelected = t.id == _selectedTemplate.id;
                    final isTeknisi = t.isPerPoint;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isTeknisi
                                ? const Color(0xFFFFFBEB)
                                : const Color(0xFFEFF6FF))
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? (isTeknisi ? AppColors.warning : AppColors.primary)
                              : AppColors.cardBorder,
                          width: isSelected ? 1.8 : 1.1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? (isTeknisi
                                    ? AppColors.warning.withValues(alpha: 0.15)
                                    : AppColors.primary.withValues(alpha: 0.12))
                                : Colors.black.withValues(alpha: 0.03),
                            blurRadius: isSelected ? 10 : 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            Navigator.of(bCtx).pop();
                            if (t.isPerPoint) {
                              await showDialog(
                                context: context,
                                builder: (_) =>
                                    MaintenanceSetupDialog(initialTemplate: t),
                              );
                              if (mounted) {
                                setState(() {
                                  _activePos = LocationService.currentPos;
                                });
                              }
                            } else if (t.jenis == TemplateCategory.absensi) {
                              setState(() => _selectedTemplate = t);
                              AbsensiKategoriDialog.show(context, onSaved: () {
                                if (mounted) {
                                  setState(() {
                                    _activePos = LocationService.currentPos;
                                  });
                                }
                              });
                            } else {
                              setState(() => _selectedTemplate = t);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon Box Indicator
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isTeknisi
                                        ? AppColors.warning.withValues(alpha: 0.15)
                                        : AppColors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isTeknisi
                                          ? AppColors.warning.withValues(alpha: 0.3)
                                          : AppColors.primary.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isTeknisi
                                          ? Icons.construction_rounded
                                          : Icons.badge_outlined,
                                      color: isTeknisi
                                          ? AppColors.warning
                                          : AppColors.primary,
                                      size: 22,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Content Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isTeknisi
                                                  ? AppColors.warning
                                                  : AppColors.primary,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isTeknisi
                                                  ? 'MAINTENANCE'
                                                  : t.jenis.name.toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 9.5,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          if (isTeknisi)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                '${t.sopPoints.length} Titik Foto',
                                                style: const TextStyle(
                                                  color: Color(0xFF92400E),
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        t.nama,
                                        style: TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 13.5,
                                          fontWeight: isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w700,
                                          color: isSelected
                                              ? (isTeknisi
                                                  ? const Color(0xFF92400E)
                                                  : AppColors.primary)
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        t.deskripsi,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                          height: 1.25,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (t.jenis == TemplateCategory.absensi) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: AppColors.primary.withValues(alpha: 0.2),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.verified_user_outlined,
                                                size: 13,
                                                color: AppColors.primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Shift: ${AbsensiSetupService.instance.selectedKategori.displayName}',
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Text(
                                                '• Ganti',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.accent,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Checkmark selection circle
                                Padding(
                                  padding: const EdgeInsets.only(top: 2, left: 8),
                                  child: isSelected
                                      ? Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isTeknisi
                                                ? AppColors.warning
                                                : AppColors.primary,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Fast bypass AI Cloud saat sinyal seluler lemah/dead-zone di pos parkir
  void _triggerFastBypass() {
    if (_aiBypassCompleter != null && !_aiBypassCompleter!.isCompleted) {
      _aiBypassCompleter!.complete(
        AiVerificationResult(
          status: VerificationStatus.perluCekManual,
          alasan: 'Mode Sinyal Lemah: Teknisi memilih simpan cepat tanpa menunggu cloud AI.',
          poinGagal: [],
          poinLolos: [],
          confidenceScore: 0.5,
          providerName: 'Fast Signal Bypass',
          isFallback: true,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚡ Mode Sinyal Lemah: Foto dialihkan ke Cek Manual SPV.'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF1E293B),
          ),
        );
      }
    }
  }

  /// Dialog blokir Fake GPS. Return true = lanjut darurat (hasil ditandai).
  Future<bool?> _confirmMockLocationProceed() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Lokasi Tidak Valid (Fake GPS Terdeteksi)', style: TextStyle(fontSize: 15)),
          ],
        ),
        content: const Text(
          'Mock Location aktif di HP ini. Matikan Fake GPS lalu jepret ulang.\n\nLanjut darurat hanya untuk kondisi khusus — hasil OTOMATIS jadi cek manual dan ditandai untuk SPV.',
          style: TextStyle(fontSize: 12.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Lanjut & Tandai'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCapturePhoto() async {
    if (_isProcessingAI) return;
    _isProcessingAI = true;

    // Absensi: pastikan data standby & shift teknisi memiliki default jika belum terisi
    if (_selectedTemplate.jenis == TemplateCategory.absensi) {
      final setup = AbsensiSetupService.instance;
      if (setup.lokasiStandby.trim().isEmpty) {
        setup.updateLokasi('PBM');
      }
      if (setup.jadwalShift.trim().isEmpty) {
        setup.updateShift('S2 (10:00 - 14:00)');
      }

      // SHUTTER INTERCEPT GUARD (DURASI KERJA MINIMAL & ISI DAILY DULU YA)
      final isPulangMode = setup.tipeLaporan == 'Pulang';
      if (isPulangMode) {
        final lastCheckIn = StorageService.getLastCheckInTime();
        if (lastCheckIn == null) {
          _isProcessingAI = false;
          _captureStep = 0;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
                  SizedBox(width: 8),
                  Text('Belum Ada Absen Masuk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: const Text(
                'Anda belum memiliki catatan absensi Masuk aktif hari ini.\n\n'
                'Silakan ambil foto absensi Masuk terlebih dahulu sebelum absensi Pulang.',
                style: TextStyle(fontSize: 13, height: 1.45),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
          return;
        }

        final isEligible = AbsensiSetupService.isEligibleForAutoPulang(
          shift: setup.effectiveJadwalShift,
          checkInTime: lastCheckIn,
        );

        // 1. Cek Kelayakan Pulang (Shift Berakhir ATAU Durasi Kerja Terpenuhi)
        if (!isEligible) {
          _isProcessingAI = false;
          _captureStep = 0;
          final jamPulangStr = AbsensiSetupService.autoDetectJamPulang(
            shift: setup.effectiveJadwalShift,
            time: lastCheckIn,
          );
          final worked = DateTime.now().difference(lastCheckIn);
          final remaining = AbsensiSetupService.getRemainingWorkTime(
            shift: setup.effectiveJadwalShift,
            checkInTime: lastCheckIn,
          );
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
                  SizedBox(width: 8),
                  Text('Belum Bisa Absensi Pulang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                'Absensi kepulangan belum diizinkan karena shift belum berakhir.\n\n'
                '• Jadwal Akhir Shift: Jam $jamPulangStr\n'
                '• Durasi Berjalan: ${worked.inHours}j ${worked.inMinutes.remainder(60)}m\n'
                '${remaining != null && remaining > Duration.zero ? '• Sisa Durasi Normal: ${remaining.inHours}j ${remaining.inMinutes.remainder(60)}m lagi\n\n' : '\n'}'
                'Absensi pulang dapat dilakukan setelah jam $jamPulangStr atau setelah durasi shift terpenuhi.',
                style: const TextStyle(fontSize: 13, height: 1.45),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
          return;
        }

        // 2. Wajib Isi Daily Report Sebelum Jepret Foto Pulang
        if (!setup.isDailyHandoverComplete()) {
          _isProcessingAI = false;
          _captureStep = 0;
          final saved = await DailyPulangBottomSheet.show(context);
          if (saved == true && mounted) {
            _handleCapturePhoto();
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Isi daily dulu ya sebelum absensi pulang!'),
                backgroundColor: Color(0xFFF59E0B),
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }
      } else {
        // MODE MASUK: PROTEKSI ABSENSI MASUK GANDA (DOUBLE CHECK-IN GUARD)
        final lastCheckIn = StorageService.getLastCheckInTime();
        if (lastCheckIn != null) {
          final isEligible = AbsensiSetupService.isEligibleForAutoPulang(
            shift: setup.effectiveJadwalShift,
            checkInTime: lastCheckIn,
          );
          if (isEligible) {
            // Jam shift sudah selesai -> otomatis alihkan ke mode Pulang
            setup.updateTipe('Pulang');
            if (mounted) setState(() {});
            if (!setup.isDailyHandoverComplete()) {
              _isProcessingAI = false;
              _captureStep = 0;
              final saved = await DailyPulangBottomSheet.show(context);
              if (saved == true && mounted) {
                _handleCapturePhoto();
              }
              return;
            }
          } else {
            // Masih dalam durasi shift aktif -> BLOKIR JEPET MASUK AGAR TIDAK DUPLIKAT!
            _isProcessingAI = false;
            _captureStep = 0;
            final worked = DateTime.now().difference(lastCheckIn);
            final remaining = AbsensiSetupService.getRemainingWorkTime(
              shift: setup.effectiveJadwalShift,
              checkInTime: lastCheckIn,
            );
            if (mounted) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B), size: 24),
                      SizedBox(width: 8),
                      Text('Sedang Shift Aktif', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  content: Text(
                    'Anda sudah melakukan absensi masuk sebelumnya.\n\n'
                    '• Shift: ${setup.effectiveJadwalShift}\n'
                    '• Durasi Berjalan: ${worked.inHours}j ${worked.inMinutes.remainder(60)}m\n'
                    '• Sisa Waktu Shift: ${remaining != null ? "${remaining.inHours}j ${remaining.inMinutes.remainder(60)}m lagi" : "-"}\n\n'
                    'Tidak perlu foto absensi masuk lagi agar data tidak terduplikasi di arsip. Tombol absensi pulang akan otomatis aktif setelah jam shift selesai.',
                    style: const TextStyle(fontSize: 13, height: 1.45),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }
            return;
          }
        }
      }
    }

    // Jika template yang dipilih adalah Maintenance (Pos/Barrier/Manless/Server),
    // teknisi langsung buka Setup Wizard Unit tanpa PIN.
    if (_selectedTemplate.isPerPoint) {
      _isProcessingAI = false;
      await showDialog(
        context: context,
        builder: (_) =>
            MaintenanceSetupDialog(initialTemplate: _selectedTemplate),
      );
      if (mounted) {
        setState(() {
          _activePos = LocationService.currentPos;
        });
      }
      return;
    }

    // Validasi Wajib GPS Aktif sebelum jepret foto
    final isGpsActive = await _checkGpsServiceAndPrompt(forceShow: true);
    if (!isGpsActive) {
      if (mounted) setState(() => _isProcessingAI = false);
      return;
    }

    // Real-Time GPS Guard: Pastikan koordinat real-time didapatkan sebelum watermark dibakar
    if (_location == null || _location!.isDefaultFallback) {
      final freshLoc = await LocationService.getCurrentLocation();
      if (mounted && !freshLoc.isDefaultFallback) {
        setState(() {
          _location = freshLoc;
        });
      }
    }

    setState(() {
      _captureStep = 1;
    });
    await Future.delayed(const Duration(milliseconds: 50));

    final user =
        AuthRepository.instance.currentUser ?? AuthRepository.demoUsers[0];

    // Anti-Fraud: Gunakan Secure Verified Time untuk mencegah manipulasi jam HP manual
    final verifiedTime = SecureTimeService.getVerifiedTime();
    final capturedTimestamp = verifiedTime.accurateTime.toLocal();
    final lat = _location?.lat ?? _activePos.lat;
    final lng = _location?.lng ?? _activePos.lng;
    final accuracy = _location?.accuracyMeter ?? 3.0;
    final currentAddress = _location?.fullAddress ?? _activePos.fullAddress;

    // Security Check: Fake GPS / Mock Location diblokir by default.
    // Teknisi boleh lanjut darurat, tapi hasil dipaksa cek manual + ditandai.
    final isMock = _location?.isMockLocation ?? false;
    bool mockOverride = false;
    if (isMock && mounted) {
      mockOverride = await _confirmMockLocationProceed() ?? false;
      if (!mockOverride) {
        if (mounted) setState(() => _isProcessingAI = false);
        return;
      }
    }

    final kodeVerifikasi = VerificationCodeGenerator.generateCode(
      timestamp: capturedTimestamp,
      lat: lat,
      lng: lng,
      userId: user.id,
    );

    String? capturedPath;
    String? imageBase64;
    Future<String>? watermarkFuture;
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final isFrontCamera = _cameras.isNotEmpty &&
            _selectedCameraIndex < _cameras.length &&
            _cameras[_selectedCameraIndex].lensDirection == CameraLensDirection.front;

        final xfile = await _cameraController!.takePicture();
        capturedPath = xfile.path;

        // Beri jeda 30ms ke UI loop agar animasi shutter camera merender mulus
        await Future.delayed(const Duration(milliseconds: 30));

        // Hitung aspek rasio target frame viewfinder (mendukung mode Full ratio, 3:4, 1:1, 9:16)
        final targetAspect = (_lastFrameW > 0 && _lastFrameH > 0)
            ? (_lastFrameW / _lastFrameH)
            : (_aspectRatio.value ?? (3 / 4));

        // Generate thumbnail cepat di background isolate dengan crop yang konsisten
        final rawBytes = await xfile.readAsBytes();
        imageBase64 = await ImageWatermarkProcessor.generateAiVisionBase64(
          capturedPath,
          rawBytes,
          isFrontCamera,
          targetAspect,
        );

        // Apply permanent watermark to saved file in background with precise aspect ratio & HD quality
        if (mounted) setState(() => _captureStep = 2);
        await Future.delayed(const Duration(milliseconds: 30));

        watermarkFuture = ImageWatermarkProcessor.applyWatermarkToFile(
          imagePath: capturedPath,
          timestamp: capturedTimestamp,
          lat: lat,
          lng: lng,
          fullAddress: currentAddress,
          kodeVerifikasi: kodeVerifikasi,
          config: _watermarkConfig,
          activeLocationTag: _activePos.locationTag,
          activeLocationColor: _activePos.tagColor,
          isAbsensi: _selectedTemplate.jenis == TemplateCategory.absensi,
          isFrontCamera: isFrontCamera,
          targetAspectRatio: targetAspect,
          jpegQuality: 93,
        );
      } catch (_) {}
    }

    // Perform Vision Scan against LLM
    if (mounted) setState(() => _captureStep = 3);
    await Future.delayed(const Duration(milliseconds: 30));
    final absensiSetup = AbsensiSetupService.instance;
    final isAbsensi = _selectedTemplate.jenis == TemplateCategory.absensi;
    _aiBypassCompleter = Completer<AiVerificationResult>();

    AiVerificationResult aiResult;
    try {
      final aiFuture = AiVisionService.verifyPhoto(
        template: _selectedTemplate,
        imageBase64: imageBase64,
        absensiKategori: isAbsensi ? absensiSetup.selectedKategori : null,
        hariKerja: isAbsensi && absensiSetup.selectedKategori == AbsensiKategori.teknisi ? absensiSetup.hariKerja : null,
        tipeLaporan: isAbsensi ? absensiSetup.tipeLaporan : null,
      );
      aiResult = await Future.any([aiFuture, _aiBypassCompleter!.future]);
    } catch (e) {
      aiResult = AiVerificationResult(
        status: VerificationStatus.perluCekManual,
        alasan: 'Gagal terhubung ke AI Vision. Foto tersimpan aman untuk verifikasi manual.',
        poinGagal: [],
        poinLolos: [],
        confidenceScore: 0.5,
        providerName: 'Offline Fallback',
        isFallback: true,
      );
    }

    // Override darurat mock: hasil dipaksa cek manual + ditandai jelas.
    if (mockOverride) {
      aiResult = AiVerificationResult(
        status: VerificationStatus.perluCekManual,
        alasan:
            '${aiResult.alasan} (GPS mock terdeteksi — perlu cek manual SPV).',
        poinGagal: aiResult.poinGagal,
        poinLolos: aiResult.poinLolos,
        confidenceScore: 0.4,
        providerName: aiResult.providerName,
        isFallback: true,
      );
    }

    if (!mounted) return;
    setState(() {
      _captureStep = 4;
      _isProcessingAI = false;
    });

    // Pre-burn watermark di background agar saat user konfirmasi / share, file sudah siap
    if (capturedPath != null && watermarkFuture != null) {
      unawaited(() async {
        try {
          final burned = await watermarkFuture;
          if (burned != null && burned.isNotEmpty && File(burned).existsSync()) {
            capturedPath = burned;
          }
        } catch (_) {}
      }());
    }

    // Build share text — teknisi has special Masuk/Pulang format (data dari SOP page)
    final absensiSetup2 = AbsensiSetupService.instance;
    final isTeknisi = _selectedTemplate.jenis == TemplateCategory.absensi && absensiSetup2.selectedKategori == AbsensiKategori.teknisi;
    final lastTechName = StorageService.getLastTechnicianName().trim();
    final effectiveUserName = lastTechName.isNotEmpty ? lastTechName : user.nama;
    final currentTipeLaporan = absensiSetup2.tipeLaporan;
    final String shareText;
    if (isTeknisi) {
      if (currentTipeLaporan == 'Pulang') {
        final jamPulangText = absensiSetup2.jamPulang.trim().isNotEmpty
            ? absensiSetup2.jamPulang.trim()
            : absensiSetup2.effectiveJamPulang;
        // Salam pulang disesuaikan jam kepulangan (misal 18:00/22:00 -> Selamat Malam, 11:00 -> Selamat Siang)
        final greetingPulang = WhatsAppReportService.getGreetingFromTimeString(jamPulangText);
        final rawSelesai = absensiSetup2.pekerjaanSelesai.trim();
        final selesaiText = rawSelesai.isNotEmpty && rawSelesai != '-'
            ? WhatsAppReportService.formatAutoNumberedList(rawSelesai)
            : '-';
        final belumText = absensiSetup2.pekerjaanBelum.trim().isNotEmpty ? absensiSetup2.pekerjaanBelum.trim() : '-';
        final nextShift = absensiSetup2.shiftSelanjutnya.trim().isNotEmpty ? absensiSetup2.shiftSelanjutnya.trim() : '-';
        shareText = '''$greetingPulang

Izin Update Laporan Jadwal Pulang Technical Support Staff

IT Support : $effectiveUserName
Lokasi Standby : ${absensiSetup2.lokasiStandby}
Jam Pulang : $jamPulangText
IT Support Shift Selanjutnya : $nextShift

List Pekerjaan yang Selesai :
$selesaiText

List Pekerjaan yang Belum Selesai :
$belumText

Terima Kasih''';
      } else {
        final greetingMasuk = WhatsAppReportService.getGreeting(capturedTimestamp);
        // Gunakan jadwal shift yang sudah dipilih (efektif) atau deteksi jam foto
        final shiftText = absensiSetup2.jadwalShift.trim().isNotEmpty
            ? absensiSetup2.jadwalShift.trim()
            : AbsensiSetupService.autoDetectShift(capturedTimestamp);
        shareText = '''$greetingMasuk

Izin Update Laporan Jadwal Masuk Technical Support Staff

IT Support : $effectiveUserName
Lokasi Standby : ${absensiSetup2.lokasiStandby}
Jadwal Shift : $shiftText

Terima Kasih''';
      }
    } else {
      shareText = '''[BSS PARKING TIMEMARK]
Kode: $kodeVerifikasi
Waktu: ${TimemarkFormatter.formatIndonesianFullDate(capturedTimestamp)} ${TimemarkFormatter.formatClockTime(capturedTimestamp)}
Lokasi: ${_activePos.posName} (${_activePos.cabangName})
Petugas: $effectiveUserName (${user.npp})
SOP: ${_selectedTemplate.nama} (${AbsensiSetupService.instance.selectedKategori.displayName})
Status: ${aiResult.isSesuai ? "LOLOS SOP (ACC)" : "TIDAK ACC"}
''';
    }

    // Catatan jujur jika koordinat dari fallback titik pos (GPS HP tidak aktif)
    final String fullShareText;
    if ((_location?.isFallback ?? false) || mockOverride) {
      final flags = [
        if (_location?.isFallback ?? false) 'titik pos (GPS HP tidak aktif)',
        if (mockOverride) 'GPS mock terdeteksi',
      ].join(', ');
      fullShareText = '$shareText\nCatatan GPS: $flags.';
    } else {
      fullShareText = shareText;
    }

    // Helper: Simpan data absensi & submission HANYA saat user konfirmasi (Simpan / Share WA / Share TG)
    bool alreadyCommitted = false;
    Future<void> commitRecord() async {
      if (alreadyCommitted) return;
      alreadyCommitted = true;

      // JAMINAN MUTLAK: Tunggu watermark selesai dibakar sebelum file disimpan ke record/galeri
      if (watermarkFuture != null) {
        try {
          final burned = await watermarkFuture.timeout(const Duration(seconds: 10));
          if (burned.isNotEmpty && File(burned).existsSync()) {
            capturedPath = burned;
          }
        } catch (e) {
          debugPrint('[Capture] Error awaiting watermark in commitRecord: $e');
        }
      }

      // JAMINAN MUTLAK: Simpan foto yang sudah ber-watermark ke galeri HP
      if (capturedPath != null && File(capturedPath!).existsSync()) {
        try {
          await ShareHelper.savePhotoToGallery(capturedPath);
        } catch (_) {}
      }

      final absSetup = AbsensiSetupService.instance;
      final isAbsensiSave = _selectedTemplate.jenis == TemplateCategory.absensi;
      final isTeknisiSave = isAbsensiSave && absSetup.selectedKategori == AbsensiKategori.teknisi;

      final submission = SubmissionModel(
        id: 'SUB-${DateTime.now().millisecondsSinceEpoch}',
        templateId: _selectedTemplate.id,
        templateName: _selectedTemplate.nama,
        userId: user.id,
        userName: effectiveUserName,
        userNpp: user.npp,
        posId: _activePos.posId,
        posName: _activePos.posName,
        cabangName: _activePos.cabangName,
        imagePath: capturedPath,
        imageBase64: imageBase64,
        timestampCapture: capturedTimestamp,
        lat: lat,
        lng: lng,
        akurasiMeter: accuracy,
        kodeVerifikasi: kodeVerifikasi,
        status: aiResult.status,
        alasanAI: aiResult.alasan,
        poinGagal: aiResult.poinGagal,
        poinLolos: aiResult.poinLolos,
        createdAt: DateTime.now(),
        absensiKategori: isAbsensiSave ? absSetup.selectedKategori : null,
        hariKerja: isTeknisiSave ? absSetup.hariKerja : null,
        lokasiStandby: isTeknisiSave ? absSetup.lokasiStandby : null,
        jadwalShift: isTeknisiSave ? absSetup.jadwalShift : null,
        tipeLaporan: isTeknisiSave ? currentTipeLaporan : null,
        jamPulang: isTeknisiSave && currentTipeLaporan == 'Pulang' ? absSetup.jamPulang : null,
        shiftSelanjutnya: isTeknisiSave && currentTipeLaporan == 'Pulang' ? absSetup.shiftSelanjutnya : null,
        pekerjaanSelesai: isTeknisiSave && currentTipeLaporan == 'Pulang' ? absSetup.pekerjaanSelesai : null,
        pekerjaanBelum: isTeknisiSave && currentTipeLaporan == 'Pulang' ? absSetup.pekerjaanBelum : null,
      );

      if (isAbsensiSave) {
        final attType = currentTipeLaporan == 'Pulang'
            ? AttendanceType.pulang
            : AttendanceType.masuk;
        String? duration;
        if (attType == AttendanceType.pulang) {
          DateTime? checkIn = StorageService.getLastCheckInTime();
          if (checkIn == null) {
            final shift = absSetup.effectiveJadwalShift;
            final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(shift);
            if (match != null) {
              final startH = int.tryParse(match.group(1) ?? '') ?? 10;
              final startM = int.tryParse(match.group(2) ?? '') ?? 0;
              final scheduledStart = DateTime(
                capturedTimestamp.year,
                capturedTimestamp.month,
                capturedTimestamp.day,
                startH,
                startM,
              );
              if (capturedTimestamp.isAfter(scheduledStart) &&
                  capturedTimestamp.difference(scheduledStart).inHours < 24) {
                checkIn = scheduledStart;
              }
            }
          }
          if (checkIn != null) {
            final diff = capturedTimestamp.difference(checkIn);
            final h = diff.inHours;
            final m = diff.inMinutes.remainder(60);
            duration = '${h}j ${m}m';
          }
        }

        final attRecord = AttendanceRecord(
          id: 'att_${capturedTimestamp.millisecondsSinceEpoch}',
          timestamp: capturedTimestamp,
          type: attType,
          shiftName: absSetup.effectiveJadwalShift,
          technicianName: StorageService.getLastTechnicianName().isNotEmpty
              ? StorageService.getLastTechnicianName()
              : effectiveUserName,
          posName: _activePos.posName,
          lat: lat,
          lng: lng,
          fullAddress: currentAddress,
          photoPath: capturedPath,
          workDuration: duration,
          isAiVerified: aiResult.isSesuai,
          aiStatusText: aiResult.statusDisplay,
        );
        await StorageService.saveAttendanceRecord(attRecord);

        if (attType == AttendanceType.masuk) {
          if (aiResult.isSesuai) {
            await StorageService.saveLastCheckInTime(capturedTimestamp);

            unawaited(NotificationService.instance.showInstantAbsenMasukNotification(
              shift: absSetup.effectiveJadwalShift,
            ));
            unawaited(NotificationService.instance.scheduleAbsenPulangNotification(
              shift: absSetup.effectiveJadwalShift,
              checkInTime: capturedTimestamp,
            ));

            final isEligible = AbsensiSetupService.isEligibleForAutoPulang(
              shift: absSetup.effectiveJadwalShift,
              checkInTime: capturedTimestamp,
              currentTime: capturedTimestamp,
            );
            if (isEligible) {
              absSetup.updateTipe('Pulang');
            }
          }
        } else {
          await StorageService.clearLastCheckInTime();
          unawaited(NotificationService.instance.showInstantAbsenPulangNotification(
            shift: absSetup.effectiveJadwalShift,
            durationText: duration,
          ));
          absSetup.updateTipe('Masuk');
        }
      }

      await SubmissionRepository.instance.addSubmission(submission);
      if (mounted) setState(() {});
    }

    // Show Verification Result Modal
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return SopVerificationModal(
          template: _selectedTemplate.jenis == TemplateCategory.absensi
              ? _selectedTemplate.copyWith(nama: AbsensiSetupService.instance.selectedKategori.displayName)
              : _selectedTemplate,
          result: aiResult,
          kodeVerifikasi: kodeVerifikasi,
          imagePath: capturedPath,
          onRetake: () {
            Navigator.of(modalCtx).pop();
            if (mounted) {
              setState(() {
                _captureStep = 0;
                _isProcessingAI = false;
              });
            }
          },
          onCancel: () {
            Navigator.of(modalCtx).pop();
            if (mounted) {
              setState(() {
                _captureStep = 0;
                _isProcessingAI = false;
              });
            }
          },
          onShareWhatsApp: () async {
            await commitRecord();
            ShareHelper.shareToWhatsApp(
              text: fullShareText,
              imagePath: capturedPath ?? '',
            );
          },
          onShareTelegram: () async {
            await commitRecord();
            ShareHelper.shareToTelegram(
              text: fullShareText,
              imagePath: capturedPath ?? '',
            );
          },
          onSave: () async {
            await commitRecord();
            if (modalCtx.mounted) Navigator.of(modalCtx).pop();
            if (mounted) {
              setState(() {
                _captureStep = 0;
                _isProcessingAI = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Foto timemark tersimpan (${aiResult.statusDisplay})',
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        );
      },
    );
    if (mounted) {
      setState(() {
        _captureStep = 0;
        _isProcessingAI = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastSubmission = SubmissionRepository.instance.submissions.isNotEmpty
        ? SubmissionRepository.instance.submissions.first
        : null;

    final currentAddress = _location?.fullAddress ?? _activePos.fullAddress;
    final isDark = ThemeService.isDarkMode(context);
    final scaffoldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFFAF8F5);
    final barBg = isDark ? const Color(0xFF0F172A) : Colors.white;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildAppDrawer(),
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalW = constraints.maxWidth;
            final totalH = constraints.maxHeight;

            // Reserve fixed slot for top bar (~64) and bottom bar (~150 incl. timer row).
            const topBarH = 64.0;
            const bottomBarH = 150.0;
            final midH = totalH - topBarH - bottomBarH;

            final isFull = _aspectRatio == CameraAspectRatio.ratioFull;

            // Target frame size for the chosen aspect ratio.
            double frameW, frameH;
            if (isFull) {
              frameW = totalW;
              frameH = midH;
            } else {
              frameW = totalW;
              final r = _aspectRatio.value ?? (3 / 4);
              final desiredH = frameW / r;
              if (desiredH > midH) {
                frameH = midH;
                frameW = midH * r;
              } else {
                frameH = desiredH;
              }
            }

            // Simpan dimensi frame viewfinder untuk kalkulasi crop aspect ratio foto
            _lastFrameW = frameW;
            _lastFrameH = frameH;

            return Stack(
              children: [
                // 1. Adaptive background fill (White di Light Mode, Navy di Dark Mode)
                Container(color: isFull ? const Color(0xFF0F172A) : scaffoldBg),

                // 2. Viewfinder (vertically centered between top & bottom bars)
                Positioned(
                  left: (totalW - frameW) / 2,
                  top: topBarH + (midH - frameH) / 2,
                  width: frameW,
                  height: frameH,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      _handleTapToFocus(details.localPosition, frameW, frameH);
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Camera Preview
                        if (_isCameraInitialized && _cameraController != null)
                          ClipRect(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width:
                                    _cameraController!
                                        .value
                                        .previewSize
                                        ?.height ??
                                    frameW,
                                height:
                                    _cameraController!
                                        .value
                                        .previewSize
                                        ?.width ??
                                    frameH,
                                child: CameraPreview(_cameraController!),
                              ),
                            ),
                          )
                        else
                          Container(
                            color: const Color(0xFF0F172A),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'Loading',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Tactical Optical Crop & Corner Brackets Frame Guide
                        const IgnorePointer(
                          child: SizedBox.expand(
                            child: CustomPaint(
                              painter: _TacticalOpticalFramePainter(),
                            ),
                          ),
                        ),

                        // Animated Focus Reticle Ring (Tap-to-focus visual feedback)
                        if (_showFocusRing && _focusPoint != null)
                          Positioned(
                            left: (_focusPoint!.dx - 28).clamp(0.0, (frameW - 56).clamp(0.0, frameW)),
                            top: (_focusPoint!.dy - 28).clamp(0.0, (frameH - 56).clamp(0.0, frameH)),
                            child: IgnorePointer(
                              child: TweenAnimationBuilder<double>(
                                key: ValueKey(_focusPoint),
                                tween: Tween(begin: 1.35, end: 1.0),
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutBack,
                                builder: (context, scale, child) {
                                  return Transform.scale(
                                    scale: scale,
                                    child: Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFFFACC15),
                                          width: 1.8,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFFACC15).withValues(alpha: 0.35),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Color(0xFFFACC15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: SizedBox(
                                            width: 5,
                                            height: 5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                        // Interactive Live Watermark bounded within viewfinder (hanya tampil jika kamera sudah siap)
                        if (_isCameraInitialized && _cameraController != null)
                          Positioned.fill(
                            child: InteractiveWatermark(
                              lat: _location?.lat ?? _activePos.lat,
                              lng: _location?.lng ?? _activePos.lng,
                              fullAddress: currentAddress,
                              kodeVerifikasi: 'VERIFYING...',
                              template: _selectedTemplate,
                              config: _watermarkConfig,
                              activeLocationTag: _activePos.locationTag,
                              activeLocationColor: _activePos.tagColor,
                              onConfigChanged: (newConfig) {
                                setState(() => _watermarkConfig = newConfig);
                                StorageService.saveWatermarkConfig(newConfig);
                              },
                            ),
                          ),

                        // Floating Shortcut Location Button (Bottom-Right of Viewfinder: Icon only, compact 15px)
                        if (_isCameraInitialized && _cameraController != null)
                          Positioned(
                            right: 14,
                            bottom: 14,
                            child: GestureDetector(
                              onTap: _showRealtimeLocationPicker,
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.accent.withValues(
                                      alpha: 0.85,
                                    ),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.my_location_rounded,
                                    color: AppColors.accent,
                                    size: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // 3. Top Floating Overlay Bar (Hamburger, Quick Ratio Pill, Flash, Flip)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: topBarH,
                  child: Container(
                    color: isFull
                        ? Colors.transparent
                        : barBg,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Hamburger Menu / Sidebar Drawer Icon
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black.withValues(alpha: 0.45) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                            border: Border.all(color: isDark ? Colors.white24 : AppColors.cardBorder, width: 0.8),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.menu_rounded,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                              size: 20,
                            ),
                            onPressed: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Quick Ratio Selector Pill
                        GestureDetector(
                          onTap: _showRatioPickerModal,
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                            ),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black.withValues(alpha: 0.45) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDark ? Colors.white24 : AppColors.cardBorder,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _aspectRatio.icon,
                                  color: AppColors.accent,
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _aspectRatio.label,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'PlusJakartaSans',
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Quick Timer Selector Pill
                        GestureDetector(
                          onTap: _isCountingDown ? null : _showTimerPickerModal,
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                            ),
                            decoration: BoxDecoration(
                              color: _timerSeconds > 0
                                  ? AppColors.accent.withValues(alpha: 0.22)
                                  : (isDark ? Colors.black.withValues(alpha: 0.45) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: _timerSeconds > 0
                                    ? AppColors.accent
                                    : (isDark ? Colors.white24 : AppColors.cardBorder),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _timerSeconds > 0
                                      ? Icons.timer_rounded
                                      : Icons.timer_outlined,
                                  color: _timerSeconds > 0
                                      ? AppColors.accent
                                      : (isDark ? Colors.white70 : AppColors.textSecondary),
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _timerSeconds > 0
                                      ? '${_timerSeconds}s'
                                      : 'Timer',
                                  style: TextStyle(
                                    color: _timerSeconds > 0
                                        ? AppColors.accent
                                        : (isDark ? Colors.white : AppColors.textPrimary),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'PlusJakartaSans',
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color: _timerSeconds > 0
                                      ? AppColors.accent
                                      : (isDark ? Colors.white70 : AppColors.textSecondary),
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Flash Toggle Button (Off -> Auto -> On -> Torch Senter)
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black.withValues(alpha: 0.45) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                            border: Border.all(color: isDark ? Colors.white24 : AppColors.cardBorder, width: 0.8),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              _flashMode == FlashMode.off
                                  ? Icons.flash_off_rounded
                                  : (_flashMode == FlashMode.auto
                                        ? Icons.flash_auto_rounded
                                        : (_flashMode == FlashMode.torch
                                              ? Icons.flashlight_on_rounded
                                              : Icons.flash_on_rounded)),
                              color: _flashMode == FlashMode.off
                                  ? (isDark ? Colors.white70 : AppColors.textSecondary)
                                  : (_flashMode == FlashMode.torch
                                        ? Colors.cyanAccent
                                        : Colors.amber),
                              size: 18,
                            ),
                            onPressed: _toggleFlash,
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Camera Flip Switch
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black.withValues(alpha: 0.45) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                            border: Border.all(color: isDark ? Colors.white24 : AppColors.cardBorder, width: 0.8),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.flip_camera_ios_rounded,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                              size: 18,
                            ),
                            onPressed: _toggleCameraFlip,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 4. Right-side Zoom Controls (Compact 34x34 round buttons with proper right padding)
                Positioned(
                  right: 16,
                  top: topBarH + (midH - 24 - 120) / 2,
                  child: Column(
                    children: [1.0, 2.0, 5.0].map((zoomVal) {
                      final isSelected = (_currentZoom - zoomVal).abs() < 0.2;
                      return GestureDetector(
                        onTap: () => _setZoom(zoomVal),
                        child: Container(
                          width: 34,
                          height: 34,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.25),
                              width: 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '${zoomVal.toInt()}x',
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(0xFF0F2C59)
                                    : Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // 5. Bottom Controls Bar (fixed at bottom)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: bottomBarH,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isFull
                          ? Colors.transparent
                          : barBg,
                      gradient: isFull
                          ? LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.55),
                                Colors.black.withValues(alpha: 0.85),
                              ],
                            )
                          : null,
                    ),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: isFull ? 12 : 8,
                        ),
                        child: _buildControlsRow(
                          lastSubmission: lastSubmission,
                          isTransparent: isFull,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ),
                ),

                // 6. Processing AI Loading Overlay — Dynamic Floating Pill (Non-intrusive di atas kontrol bawah)
                if (_isProcessingAI)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 120,
                    child: Center(
                      child: VerificationStepCard(
                        currentStep: _captureStep,
                        statusText: _captureStep == 1
                            ? 'Memproses foto'
                            : _captureStep == 2
                                ? 'Mengirim ke AI'
                                : _captureStep == 3
                                    ? 'Sedang diverifikasi'
                                    : 'Selesai',
                        templateName: _selectedTemplate.jenis == TemplateCategory.absensi
                            ? AbsensiSetupService.instance.selectedKategori.displayName
                            : _selectedTemplate.nama,
                        onFastBypass: _triggerFastBypass,
                      ),
                    ),
                  ),
                // Countdown overlay
                if (_isCountingDown)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.7),
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                              child: Center(
                                child: Text(
                                  '$_countdownValue',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 56,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Foto dalam $_countdownValue detik',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: _cancelTimer,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.close,
                                        color: Colors.black, size: 16),
                                    SizedBox(width: 4),
                                    Text('Batal',
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAttendanceShiftShortcutPill(bool isTransparent, {bool isDark = true}) {
    final absSetup = AbsensiSetupService.instance;
    final isCheckedInActive = StorageService.hasCheckedInTodayWithoutCheckOut();
    final lastCheckIn = StorageService.getLastCheckInTime();
    final now = DateTime.now();
    final shift = absSetup.effectiveJadwalShift;
    final shiftShort = shift.split('(').first.trim();

    String label;
    Color accentColor;

    if (isCheckedInActive && lastCheckIn != null && now.isAfter(lastCheckIn)) {
      final diff = now.difference(lastCheckIn);
      final hours = diff.inHours;
      final minutes = diff.inMinutes.remainder(60);

      // Cek apakah waktu kerja minimal sudah terpenuhi (8 jam / 4 jam Shift 2.2)
      final isEligible = AbsensiSetupService.isEligibleForAutoPulang(
        shift: shift,
        checkInTime: lastCheckIn,
        currentTime: now,
      );

      if (isEligible) {
        if (absSetup.tipeLaporan != 'Pulang') {
          absSetup.updateTipe('Pulang');
        }
        final hasDaily = absSetup.isDailyHandoverComplete();
        label = hasDaily
            ? 'Pulang (Kerja: $shiftShort)'
            : 'Pulang (Kerja: $shiftShort) • Isi daily dulu ya!';
        accentColor = hasDaily
            ? const Color(0xFF38BDF8) // Sky blue
            : const Color(0xFFF59E0B); // Amber peringatan
      } else {
        if (absSetup.tipeLaporan != 'Masuk') {
          absSetup.updateTipe('Masuk');
        }
        label = 'Kerja : $shiftShort (${hours}j ${minutes}m)';
        accentColor = const Color(0xFFF59E0B); // Amber hangat (sedang dinas aktif)
      }
    } else {
      // Tidak sedang berdinas / sudah absen pulang
      if (absSetup.tipeLaporan != 'Masuk') {
        absSetup.updateTipe('Masuk');
      }
      label = 'Masuk : $shiftShort';
      accentColor = const Color(0xFF4ADE80); // Emerald green
    }

    final isModePulangTap = absSetup.tipeLaporan == 'Pulang' &&
        (isCheckedInActive && lastCheckIn != null &&
         AbsensiSetupService.isEligibleForAutoPulang(
           shift: shift,
           checkInTime: lastCheckIn,
           currentTime: now,
         ));

    return GestureDetector(
      onTap: () {
        if (isModePulangTap) {
          DailyPulangBottomSheet.show(context).then((saved) {
            if (mounted && saved == true) {
              setState(() {});
            }
          });
        } else {
          AbsensiKategoriDialog.show(
            context,
            onSaved: () {
              if (mounted) setState(() {});
            },
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5.5),
        decoration: BoxDecoration(
          color: isTransparent
              ? Colors.black.withValues(alpha: 0.75)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.8),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor,
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.8),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.arrow_drop_down_rounded,
              color: Colors.white70,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsRow({
    required SubmissionModel? lastSubmission,
    required bool isTransparent,
    required bool isDark,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Left: Last Photo Thumbnail / Galeri Foto
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GalleryScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isTransparent
                        ? Colors.black.withValues(alpha: 0.45)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isTransparent
                          ? Colors.white38
                          : (isDark ? const Color(0xFF334155) : AppColors.cardBorder),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isTransparent ? 0.3 : 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: (lastSubmission != null &&
                          lastSubmission.imagePath != null &&
                          lastSubmission.imagePath!.isNotEmpty)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(lastSubmission.imagePath!),
                            cacheWidth: 800,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Icon(
                              Icons.photo_library_outlined,
                              color: isTransparent
                                  ? Colors.white
                                  : (isDark ? Colors.white : AppColors.primary),
                              size: 22,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.photo_library_outlined,
                          color: isTransparent
                              ? Colors.white70
                              : (isDark ? Colors.white70 : AppColors.textSecondary),
                          size: 22,
                        ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Galeri',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'PlusJakartaSans',
                    color: isTransparent
                        ? Colors.white70
                        : (isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Center: Floating Attendance Shift Shortcut Pill + Pro Dual-Ring Shutter Button
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAttendanceShiftShortcutPill(isTransparent, isDark: isDark),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                if (_isProcessingAI) return;
                HapticFeedback.mediumImpact();
                if (_isCountingDown) {
                  _cancelTimer();
                } else {
                  _startTimedCapture();
                }
              },
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  border: Border.all(
                    color: _isProcessingAI
                        ? (isDark ? Colors.white24 : Colors.black26)
                        : AppColors.accent,
                    width: 3.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isProcessingAI
                              ? Colors.black
                              : AppColors.accent)
                          .withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 1.0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4.5),
                child: Container(
                  decoration: BoxDecoration(
                    color: _isProcessingAI
                        ? Colors.grey.shade600
                        : (isTransparent
                            ? Colors.white
                            : (isDark ? AppColors.primary : const Color(0xFF1E448D))),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: _isProcessingAI
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            Icons.camera_alt_rounded,
                            color: isTransparent
                                ? const Color(0xFF0F2C59)
                                : Colors.white,
                            size: 30,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),

        // Right: Template Icon "SOP" Shortcut Button
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _showTemplateQuickPicker();
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isTransparent
                        ? Colors.black.withValues(alpha: 0.45)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isTransparent
                          ? Colors.white38
                          : (isDark ? const Color(0xFF334155) : AppColors.cardBorder),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isTransparent ? 0.3 : 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.assignment_outlined,
                    color: isTransparent
                        ? Colors.white
                        : (isDark ? Colors.white : AppColors.primary),
                    size: 24,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'SOP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'PlusJakartaSans',
                    color: isTransparent
                        ? Colors.white70
                        : (isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppDrawer() {
    final isDark = ThemeService.isDarkMode(context);
    final drawerBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Drawer(
      width: 310,
      backgroundColor: drawerBg,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Drawer Header with Pure Transparent Logo on Blue Background (Tanpa Tombol Close & Tanpa Kotak Dalam)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 52, 20, 28),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      border: Border(
                        bottom: BorderSide(color: AppColors.accent, width: 2.5),
                      ),
                    ),
                    child: Center(
                      child: Image.asset(
                        'foto/bssfotologo_transparent.png',
                        height: 48,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, stack) => const Text(
                          'BSS PARKING',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Menu Khusus SPV: Penugasan Teknisi (Hanya Muncul untuk SPV)
                  Builder(builder: (ctx) {
                    final user = AuthRepository.instance.currentUser;
                    final isSpv = user?.role == UserRole.supervisor;
                    if (!isSpv) return const SizedBox.shrink();

                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.assignment_ind_rounded, color: AppColors.accent, size: 22),
                      ),
                      title: Row(
                        children: [
                          Text(
                            'Penugasan Teknisi',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textPrimary),
                          ),
                          const SizedBox(width: 6),
                          const Chip(
                            label: Text('SPV', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                            backgroundColor: AppColors.accent,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      subtitle: Text(
                        'Buat tugas dan pantau progres kerja teknisi',
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SpvTaskDispatcherScreen(),
                          ),
                        );
                      },
                    );
                  }),

                  // Menu Khusus Teknisi: Daily Task
                  Builder(builder: (ctx) {
                    final user = AuthRepository.instance.currentUser;
                    final isTeknisi = user?.role == UserRole.petugas;
                    if (!isTeknisi) return const SizedBox.shrink();

                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.assignment_turned_in_rounded, color: AppColors.accent, size: 22),
                      ),
                      title: Text(
                        'Daily Task',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textPrimary),
                      ),
                      subtitle: Text(
                        'List daily yang harus dikerjakan',
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TeknisiDailyTasksScreen(),
                          ),
                        );
                      },
                    );
                  }),

                  // Menu Khusus Teknisi: Riwayat Maintenance (Dilindungi PIN)
                  Builder(builder: (ctx) {
                    final allSubmissions = StorageService.getMaintenanceSubmissions() ?? [];
                    final drafts = allSubmissions.where((s) => !s.isComplete).toList();
                    final completed = allSubmissions.where((s) => s.isComplete).toList();
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.handyman_rounded, color: AppColors.primary, size: 22),
                      ),
                      title: Text(
                        'Riwayat Maintenance',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textPrimary),
                      ),
                      subtitle: Text(
                        drafts.isNotEmpty
                            ? '${drafts.length} draft aktif • ${completed.length} selesai'
                            : (completed.isNotEmpty ? '${completed.length} pekerjaan selesai' : 'Daftar checklist unit'),
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                      trailing: drafts.isNotEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.warning,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${drafts.length} Draft',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            )
                          : Icon(Icons.chevron_right_rounded, size: 20, color: textSecondary),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MaintenanceHistoryScreen(),
                          ),
                        );
                      },
                    );
                  }),

                  // Menu Arsip Lembar Kerja Kehadiran (30 Hari)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.25 : 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.folder_shared_rounded, color: Color(0xFF0284C7), size: 22),
                    ),
                    title: Text(
                      'Arsip Kehadiran',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textPrimary),
                    ),
                    subtitle: Text('Catatan absensi masuk & pulang 30 hari terakhir', style: TextStyle(fontSize: 11, color: textSecondary)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF082F49) : const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF0284C7) : const Color(0xFFBAE6FD)),
                      ),
                      child: Text(
                        '30 Hari',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AttendanceArchiveScreen(),
                        ),
                      );
                    },
                  ),

                  // Pengaturan Tema (Mode Gelap / Terang)
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: ThemeService.themeModeNotifier,
                    builder: (ctx, currentMode, _) {
                      final isCurrentDark = ThemeService.isDarkMode(ctx);
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isCurrentDark ? const Color(0xFFF59E0B) : const Color(0xFF1E448D)).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isCurrentDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                            color: isCurrentDark ? const Color(0xFFF59E0B) : const Color(0xFF1E448D),
                            size: 22,
                          ),
                        ),
                        title: Text(
                          isCurrentDark ? 'Mode Terang' : 'Mode Gelap',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textPrimary),
                        ),
                        subtitle: Text(
                          isCurrentDark ? 'Beralih ke tampilan putih bersih' : 'Beralih ke tampilan gelap malam',
                          style: TextStyle(fontSize: 11, color: textSecondary),
                        ),
                        trailing: Switch.adaptive(
                          value: isCurrentDark,
                          activeTrackColor: AppColors.accent,
                          onChanged: (_) {
                            ThemeService.toggleTheme(context);
                          },
                        ),
                        onTap: () {
                          ThemeService.toggleTheme(context);
                        },
                      );
                    },
                  ),

                  Divider(height: 24, color: dividerColor),

                  // Informasi Akun & Modal Konfirmasi Keluar Akun
                  Builder(builder: (ctx) {
                    final user = AuthRepository.instance.currentUser;
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                        child: Text(
                          (user?.nama.isNotEmpty ?? false) ? user!.nama[0].toUpperCase() : 'U',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent, fontSize: 16),
                        ),
                      ),
                      title: Text(
                        user?.nama ?? 'Belum Login',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textPrimary),
                      ),
                      subtitle: Text(
                        'IT Support KC BSG',
                        style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.logout_rounded, size: 20, color: AppColors.danger),
                        tooltip: 'Keluar Akun',
                        onPressed: () => _confirmLogout(context),
                      ),
                      onTap: () => _confirmLogout(context),
                    );
                  }),

                ],
              ),
            ),

            // Footer Paling Bawah Center (Bottom-Pinned)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: dividerColor, width: 0.8)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'PMA App ❤️ Made by annnpii',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11.5,
                      color: isDark ? const Color(0xFF38BDF8) : AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Project Maintenance Assembly',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 10,
                      color: textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.danger, size: 24),
            SizedBox(width: 8),
            Text(
              'Keluar Akun',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun ini?',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              Navigator.of(dCtx).pop();
              nav.pop(); // Tutup drawer
              await AuthRepository.instance.logout();
              if (mounted) {
                nav.pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// Optical Viewfinder Frame Painter (Pro Optical Corner Brackets & Crosshair)
class _TacticalOpticalFramePainter extends CustomPainter {
  const _TacticalOpticalFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bracketPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.65)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Outer subtle border
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), borderPaint);

    const cornerLen = 18.0;
    const padding = 10.0;

    // Top-Left
    canvas.drawLine(
      const Offset(padding, padding),
      const Offset(padding + cornerLen, padding),
      bracketPaint,
    );
    canvas.drawLine(
      const Offset(padding, padding),
      const Offset(padding, padding + cornerLen),
      bracketPaint,
    );

    // Top-Right
    canvas.drawLine(
      Offset(size.width - padding, padding),
      Offset(size.width - padding - cornerLen, padding),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(size.width - padding, padding),
      Offset(size.width - padding, padding + cornerLen),
      bracketPaint,
    );

    // Bottom-Left
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(padding + cornerLen, size.height - padding),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(padding, size.height - padding - cornerLen),
      bracketPaint,
    );

    // Bottom-Right
    canvas.drawLine(
      Offset(size.width - padding, size.height - padding),
      Offset(size.width - padding - cornerLen, size.height - padding),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(size.width - padding, size.height - padding),
      Offset(size.width - padding, size.height - padding - cornerLen),
      bracketPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

