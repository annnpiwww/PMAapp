import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/tiket_colors.dart';
import '../../../core/widgets/tiket/tiket.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/utils/verification_code.dart';
import '../../../core/utils/image_watermark_processor.dart';
import '../../../core/widgets/verification_step_card.dart';
import '../../../data/models/watermark_config.dart';
import '../../../data/models/template_model.dart';
import '../../../data/models/maintenance_submission.dart';
import '../../../data/models/submission_model.dart';
import '../../../data/services/ai_vision_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/secure_time_service.dart';
import '../../camera/widgets/interactive_watermark.dart';

enum CameraRatioOption {
  full,
  ratio43,
  ratio11,
}

class PointCameraView extends StatefulWidget {
  final SopPoint point;
  final TemplateModel template;
  final PosLocation? location;
  final Widget? placeholderPreview;

  /// Preferensi global mode offline (saklar manual teknisi, ikut ke poin berikutnya)
  static bool globalOfflineMode = false;

  // Backoff otomatis saat server AI gagal: lewati beberapa poin, lalu coba AI lagi.
  // Tujuannya supaya 1 kegagalan jaringan tidak mematikan verifikasi AI sepanjang sesi.
  static const int _aiSkipMinPoints = 3;
  static const int _aiSkipMaxPoints = 24;
  static int _aiSkipRemaining = 0;
  static int _aiSkipStep = _aiSkipMinPoints;

  /// true = poin ini dilewati AI karena backoff kegagalan sebelumnya.
  @visibleForTesting
  static bool consumeAutoOffline() {
    if (_aiSkipRemaining <= 0) return false;
    _aiSkipRemaining--;
    return true;
  }

  /// Satu kegagalan AI: lewati beberapa poin berikutnya (3 -> 6 -> 12 -> 24), lalu coba lagi.
  @visibleForTesting
  static void noteAiFailure() {
    _aiSkipRemaining = _aiSkipStep;
    _aiSkipStep = (_aiSkipStep * 2).clamp(_aiSkipMinPoints, _aiSkipMaxPoints);
  }

  /// AI berhasil: kembalikan backoff ke kondisi normal.
  @visibleForTesting
  static void resetAutoOffline() {
    _aiSkipRemaining = 0;
    _aiSkipStep = _aiSkipMinPoints;
  }

  const PointCameraView({
    super.key,
    required this.point,
    required this.template,
    this.location,
    this.placeholderPreview,
  });

  @override
  State<PointCameraView> createState() => _PointCameraViewState();
}

class _PointCameraViewState extends State<PointCameraView> with WidgetsBindingObserver {
  static List<CameraDescription>? _cachedCameras;
  static ResolutionPreset? _cachedWebPreset;

  CameraController? _controller;
  bool _isInit = false;
  bool _hasInitError = false;
  bool _isCapturing = false;
  late bool _isOfflineFastMode;
  late WatermarkConfig _watermarkConfig;
  late PosLocation _activeLocation;
  LocationResult? _realLocation;
  FlashMode _flashMode = FlashMode.off;
  String _statusText = 'Arahkan kamera ke objek';
  int _currentStep = 0; // 0=idle,1=Memproses foto,2=Mengirim ke AI,3=Sedang diverifikasi,4=Verifikasi selesai
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  int _timerSeconds = 0;
  int _countdownValue = 0;
  bool _isCountingDown = false;
  Timer? _countdownTimer;

  // Aspect ratio state (Full, 3:4, 1:1) — default 3:4 untuk standard maintenance
  CameraRatioOption _selectedRatio = CameraRatioOption.ratio43;

  // Tap-to-Focus visual reticle state
  Offset? _focusPoint;
  bool _showFocusRing = false;
  Timer? _focusRingTimer;

  bool get _isFrontCamera =>
      _cameras.isNotEmpty &&
      _selectedCameraIndex < _cameras.length &&
      _cameras[_selectedCameraIndex].lensDirection == CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _activeLocation = widget.location ?? LocationService.currentPos;
    _isOfflineFastMode = PointCameraView.globalOfflineMode;
    _watermarkConfig = StorageService.getWatermarkConfig();
    // Di mode maintenance, badge tag kartu wm WAJIB mengikuti lokasi maintenance yang dipilih, bukan 'Absensi'
    if (_watermarkConfig.badgeTag.toLowerCase() == 'absensi' || _watermarkConfig.badgeTag.trim().isEmpty) {
      _watermarkConfig = _watermarkConfig.copyWith(
        badgeTag: _activeLocation.locationTag,
        badgeColor: _activeLocation.tagColor,
      );
    }
    _initCam();
    _refreshLocation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.paused) {
      controller.dispose();
      _controller = null;
      if (mounted) setState(() => _isInit = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCam();
      _refreshLocation();
    }
  }

  Future<void> _refreshLocation() async {
    try {
      final loc = await LocationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _realLocation = loc;
        });
      }
    } catch (_) {}
  }

  Future<void> _initCam() async {
    if (widget.placeholderPreview != null) {
      if (mounted) {
        setState(() {
          _isInit = true;
          _hasInitError = false;
        });
      }
      return;
    }
    try {
      if (mounted) {
        setState(() {
          _hasInitError = false;
          _statusText = 'Menyiapkan kamera...';
        });
      }
      if (_cachedCameras != null && _cachedCameras!.isNotEmpty) {
        _cameras = _cachedCameras!;
      } else {
        _cameras = await availableCameras();
        _cachedCameras = _cameras;
      }
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _hasInitError = true;
            _statusText = 'Tidak ada sensor kamera ditemukan';
          });
        }
        return;
      }
      _selectedCameraIndex = 0;
      await _initializeControllerWithFallback(_selectedCameraIndex);
    } catch (e) {
      LoggerService.error('Inisialisasi kamera error', error: e, tag: 'PointCameraView');
      if (mounted) {
        setState(() {
          _hasInitError = true;
          _statusText = 'Kamera gagal diinisialisasi. Pastikan izin kamera aktif lalu coba lagi.';
        });
      }
    }
  }

  Future<void> _initializeControllerWithFallback(int cameraIndex) async {
    // Pada platform Web PWA (Chrome/Safari), preset ultraHigh/max sering hang atau ditolak browser.
    // Gunakan preset yang sudah terbukti sukses atau fallback medium -> high -> low agar inisialisasi instan.
    final presets = kIsWeb
        ? [
            if (_cachedWebPreset != null && _cachedWebPreset != ResolutionPreset.medium)
              _cachedWebPreset!,
            ResolutionPreset.medium,
            ResolutionPreset.high,
            ResolutionPreset.low,
          ]
        : [
            ResolutionPreset.max,
            ResolutionPreset.ultraHigh,
            ResolutionPreset.veryHigh,
            ResolutionPreset.high,
            ResolutionPreset.medium,
          ];

    if (_controller != null) {
      try {
        await _controller!.dispose();
      } catch (_) {}
      _controller = null;
    }

    Object? lastErr;
    final timeoutDur = kIsWeb ? const Duration(seconds: 4) : const Duration(seconds: 7);
    for (final preset in presets) {
      try {
        final ctrl = CameraController(
          _cameras[cameraIndex],
          preset,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );
        await ctrl.initialize().timeout(timeoutDur);
        _controller = ctrl;
        if (kIsWeb) {
          _cachedWebPreset = preset;
        }
        try {
          await _controller!.setFocusMode(FocusMode.auto);
          await _controller!.setExposureMode(ExposureMode.auto);
        } catch (_) {}
        if (mounted) {
          setState(() {
            _isInit = true;
            _hasInitError = false;
            _statusText = 'Arahkan kamera ke objek';
          });
        }
        return;
      } catch (e) {
        lastErr = e;
        debugPrint('[PointCameraView] Preset $preset failed on camera $cameraIndex: $e');
        try {
          await _controller?.dispose();
        } catch (_) {}
        _controller = null;
      }
    }

    if (mounted) {
      setState(() {
        _isInit = false;
        _hasInitError = true;
        _statusText = 'Kamera gagal dimulai (${lastErr is CameraException ? (lastErr.description ?? lastErr.code) : 'Perangkat sibuk atau izin ditolak'})';
      });
    }
  }

  Future<void> _toggleCameraFlip() async {
    if (_cameras.length < 2 || _isCapturing || _isCountingDown) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    if (mounted) setState(() => _isInit = false);
    await _initializeControllerWithFallback(_selectedCameraIndex);
  }

  void _cycleTimer() {
    if (_isCountingDown || _isCapturing) return;
    setState(() {
      if (_timerSeconds == 0) {
        _timerSeconds = 3;
      } else if (_timerSeconds == 3) {
        _timerSeconds = 5;
      } else if (_timerSeconds == 5) {
        _timerSeconds = 10;
      } else {
        _timerSeconds = 0;
      }
    });
  }

  void _cycleRatio() {
    if (_isCapturing || _isCountingDown) return;
    setState(() {
      switch (_selectedRatio) {
        case CameraRatioOption.full:
          _selectedRatio = CameraRatioOption.ratio43;
          break;
        case CameraRatioOption.ratio43:
          _selectedRatio = CameraRatioOption.ratio11;
          break;
        case CameraRatioOption.ratio11:
          _selectedRatio = CameraRatioOption.full;
          break;
      }
    });
  }

  double _calculateTargetAspectRatio(Size media) {
    switch (_selectedRatio) {
      case CameraRatioOption.full:
        return media.width / media.height;
      case CameraRatioOption.ratio43:
        return 3.0 / 4.0;
      case CameraRatioOption.ratio11:
        return 1.0;
    }
  }

  void _handleTapToFocus(Offset localPos, double viewW, double viewH) {
    if (viewW <= 0 || viewH <= 0) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final dx = (localPos.dx / viewW).clamp(0.0, 1.0);
    final dy = (localPos.dy / viewH).clamp(0.0, 1.0);

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
      if (mounted) setState(() => _showFocusRing = false);
    });
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_isInit) return;
    // WebKit (semua browser di iPhone/iPad) tidak mendukung constraint
    // 'torch', jadi flash tidak bisa dinyalakan dari halaman web.
    if (kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      _showFlashUnsupportedMessage();
      return;
    }
    FlashMode next;
    switch (_flashMode) {
      case FlashMode.off:
        next = FlashMode.auto;
        break;
      case FlashMode.auto:
        next = FlashMode.always;
        break;
      case FlashMode.always:
        next = FlashMode.torch;
        break;
      case FlashMode.torch:
        next = FlashMode.off;
        break;
    }
    try {
      await _controller!.setFlashMode(next);
      setState(() => _flashMode = next);
    } catch (_) {
      _showFlashUnsupportedMessage();
    }
  }

  void _showFlashUnsupportedMessage() {
    if (!mounted) return;
    final bool isIosBrowser =
        kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Text(
            isIosBrowser
                ? 'iPhone tidak mengizinkan flash dinyalakan dari browser. '
                      'Nyalakan flash di aplikasi Kamera HP, atau pakai APK BSS di Android.'
                : 'Lampu kilat tidak bisa diaktifkan di perangkat ini.',
          ),
        ),
      );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _focusRingTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _toggleAiMode() {
    setState(() {
      _isOfflineFastMode = !_isOfflineFastMode;
      PointCameraView.globalOfflineMode = _isOfflineFastMode;
    });
    final colors = TiketColors.of(context);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: _isOfflineFastMode ? colors.signal : colors.ok,
        content: Row(
          children: [
            Icon(
              _isOfflineFastMode ? Icons.bolt_rounded : Icons.cloud_done_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _isOfflineFastMode
                    ? 'Mode Kilat aktif: foto langsung disimpan, tanpa AI Vision (hemat waktu & sinyal)'
                    : 'AI Cloud Aktif: Verifikasi SOP otomatis via Gemini Vision AI Online',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startTimedCapture() {
    if (_isCountingDown || _isCapturing) return;
    if (_timerSeconds <= 0) {
      _takePhotoAndVerify();
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
        _takePhotoAndVerify();
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

  /// Dialog blokir Fake GPS / Mock Location pada kamera maintenance. Return true = lanjut darurat (hasil ditandai).
  Future<bool?> _confirmMockLocationProceed() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final colors = TiketColors.of(ctx);
        return AlertDialog(
          backgroundColor: colors.dialog,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: colors.danger),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Fake GPS Terdeteksi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'Aplikasi mendeteksi Mock Location / Fake GPS aktif pada perangkat ini.\n\n'
            'Matikan Fake GPS untuk melanjutkan checklist maintenance sesuai lokasi fisik pos.\n\n'
            'Kalau kamu pilih Lanjut Darurat, foto ditandai [FAKE GPS DETECTED] dan otomatis jadi Cek Manual buat diaudit Supervisor.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal / Matikan Fake GPS'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Lanjut Darurat (Ditandai SPV)'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _takePhotoAndVerify() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;

    final media = MediaQuery.of(context).size;
    final targetAspect = _calculateTargetAspectRatio(media);

    setState(() {
      _isCapturing = true;
      _statusText = 'Memproses foto';
      _currentStep = 1;
    });

    try {
      final file = await _controller!.takePicture();
      final Uint8List bytes = await file.readAsBytes();

      final verifiedTime = SecureTimeService.getVerifiedTime();
      final now = verifiedTime.accurateTime;
      final user = StorageService.getUser();

      // Real-Time GPS Guard: Pastikan lokasi real-time terambil, jangan biarkan fallback default
      if (_realLocation == null || _realLocation!.isDefaultFallback) {
        try {
          final freshLoc = await LocationService.getCurrentLocation();
          if (!freshLoc.isDefaultFallback) {
            _realLocation = freshLoc;
          }
        } catch (_) {}
      }

      final loc = _realLocation ?? LocationService.lastLocationResult;

      // Security Check: Fake GPS / Mock Location diblokir by default.
      // Teknisi boleh lanjut darurat, tapi hasil dipaksa cek manual + ditandai untuk SPV.
      final isMock = (loc?.isMockLocation ?? false) || LocationService.isLastLocationMocked;
      bool mockOverride = false;
      if (isMock && mounted) {
        mockOverride = await _confirmMockLocationProceed() ?? false;
        if (!mockOverride) {
          if (mounted) {
            setState(() {
              _isCapturing = false;
              _statusText = '';
              _currentStep = 0;
            });
          }
          return;
        }
      }

      final pos = _activeLocation;
      final lat = loc?.lat ?? pos.lat;
      final lng = loc?.lng ?? pos.lng;
      final fullAddr = (loc != null && loc.fullAddress.isNotEmpty && !loc.isDefaultFallback)
          ? loc.fullAddress
          : pos.fullAddress;
      final activeTag = pos.locationTag;
      final activeTagColor = pos.tagColor;

      final code = VerificationCodeGenerator.generateCode(
        timestamp: now,
        lat: lat,
        lng: lng,
        userId: user?.id ?? 'tech',
      );

      // Mulai watermark di background (jalan paralel dengan AI verify).
      // Web tidak punya file lokal yang bisa ditulisi, jadi watermark dirender
      // ke byte di memori; tanpa ini foto share di iPhone/Vercel polos tanpa watermark.
      Future<String>? watermarkFuture;
      Future<Uint8List?>? webWatermarkFuture;
      try {
        final wmConfig = _watermarkConfig.copyWith(
          badgeTag: activeTag,
          badgeColor: activeTagColor,
        );
        if (kIsWeb) {
          webWatermarkFuture = ImageWatermarkProcessor.applyWatermarkToBytes(
            imageBytes: bytes,
            timestamp: now,
            lat: lat,
            lng: lng,
            fullAddress: fullAddr,
            kodeVerifikasi: code,
            config: wmConfig,
            activeLocationTag: activeTag,
            activeLocationColor: activeTagColor,
            pointLabel: widget.point.label,
            isFrontCamera: _isFrontCamera,
            targetAspectRatio: targetAspect,
            jpegQuality: 93,
          );
        } else {
          watermarkFuture = ImageWatermarkProcessor.applyWatermarkToFile(
            imagePath: file.path,
            timestamp: now,
            lat: lat,
            lng: lng,
            fullAddress: fullAddr,
            kodeVerifikasi: code,
            config: wmConfig,
            activeLocationTag: activeTag,
            activeLocationColor: activeTagColor,
            pointLabel: widget.point.label,
            isFrontCamera: _isFrontCamera,
            targetAspectRatio: targetAspect,
            jpegQuality: 93,
          );
        }
      } catch (err) {
        debugPrint('[PointCameraView] Error saat memicu watermark: $err');
      }

      Uint8List? shareBytes;
      Future<void> tungguWatermark() async {
        if (watermarkFuture != null) {
          try {
            await watermarkFuture.timeout(const Duration(seconds: 12));
          } catch (e) {
            debugPrint('[PointCameraView] Timeout/error watermark: $e');
          }
        }
        if (webWatermarkFuture != null) {
          try {
            final wm = await webWatermarkFuture.timeout(const Duration(seconds: 12));
            if (wm != null && wm.isNotEmpty) shareBytes = wm;
          } catch (e) {
            debugPrint('[PointCameraView] Timeout/error watermark web: $e');
          }
        }
      }

      // Mode Kilat manual, atau backoff otomatis setelah AI gagal: tunggu watermark selesai lalu simpan
      final autoOffline = PointCameraView.consumeAutoOffline();
      if (_isOfflineFastMode || autoOffline) {
        setState(() {
          _statusText = '⚡ Mode Kilat: Selesai';
        });
        if (watermarkFuture != null) {
          try {
            await watermarkFuture.timeout(const Duration(seconds: 12));
          } catch (e) {
            debugPrint('[PointCameraView] Timeout/error watermark offline: $e');
          }
        }
        if (webWatermarkFuture != null) {
          try {
            final wm = await webWatermarkFuture.timeout(const Duration(seconds: 12));
            if (wm != null && wm.isNotEmpty) shareBytes = wm;
          } catch (e) {
            debugPrint('[PointCameraView] Timeout/error watermark web offline: $e');
          }
        }
        setState(() {
          _statusText = '⚡ Mode Offline Cepat: Foto tersimpan!';
        });
        await Future.delayed(const Duration(milliseconds: 150));

        // Simpan base64 ringan di memori (tidak ikut ke local storage) supaya
        // tombol "Analisa Ulang" tetap bisa dipakai walau file/blob hilang.
        final offlineB64 = await ImageWatermarkProcessor.generateAiVisionBase64(
          file.path,
          bytes,
          _isFrontCamera,
          targetAspect,
        );

        final result = MaintenancePointResult(
          pointId: widget.point.id,
          label: widget.point.label,
          imagePath: file.path,
          shareImageBytes: shareBytes,
          imageBase64: offlineB64 ?? (bytes.isNotEmpty ? base64Encode(bytes) : null),
          timestamp: now,
          status: PointStatus.perluCekManual,
          alasan: mockOverride
              ? '[⚠️ FAKE GPS DETECTED] Mock Location aktif pada HP teknisi saat verifikasi checklist offline.'
              : autoOffline
                  ? 'Mode Offline otomatis (koneksi ke AI gagal). Foto tersimpan aman untuk cek manual.'
                  : 'Mode Offline Cepat: Foto tersimpan aman untuk laporan WhatsApp.',
          confidence: 1.0,
          providerName: mockOverride ? 'Mock GPS Guard' : 'Offline Fast Mode',
        );

        if (mounted) {
          Navigator.pop(context, result);
        }
        return;
      }

      // Generate compressed base64 untuk AI (ringan, 864px q72) — jalan paralel dengan watermark
      var base64Ai = await ImageWatermarkProcessor.generateAiVisionBase64(
        file.path,
        bytes,
        _isFrontCamera,
        targetAspect,
      );
      base64Ai ??= (bytes.isNotEmpty ? base64Encode(bytes) : null);
      setState(() {
        _statusText = 'Sedang diverifikasi';
        _currentStep = 3;
      });

      // Call Vision per-point with offline/timeout fallback
      AiVerificationResult aiResult;
      // Pause preview di web selama request AI: kamera aktif + request jaringan barengan
      // sering bikin Safari iOS membunuh tab (gejala "verifikasi AI terputus").
      if (kIsWeb) {
        try {
          await _controller?.pausePreview();
        } catch (_) {}
      }
      try {
        aiResult = await AiVisionService.verifyMaintenancePoint(
          point: widget.point,
          template: widget.template,
          imageBase64: base64Ai,
        );
        if (aiResult.isFallback) {
          // Server vision offline/timeout: lewati beberapa poin, lalu coba AI lagi otomatis
          PointCameraView.noteAiFailure();
        } else {
          PointCameraView.resetAutoOffline();
        }
      } catch (err) {
        debugPrint('[PointCameraView] Verifikasi AI gagal: $err');
        PointCameraView.noteAiFailure();
        aiResult = AiVerificationResult(
          status: VerificationStatus.perluCekManual,
          alasan: 'Mode Offline: Foto tersimpan aman di HP. Perlu cek manual.',
          poinGagal: [],
          poinLolos: [],
          confidenceScore: 0.5,
          providerName: 'Offline Fallback',
          isFallback: true,
        );
      } finally {
        if (kIsWeb) {
          try {
            await _controller?.resumePreview();
          } catch (_) {}
        }
      }

      setState(() {
        _statusText = 'Selesai';
        _currentStep = 4;
      });

      // Pastikan watermark HD selesai sebelum foto disimpan ke laporan
      await tungguWatermark();

      await Future.delayed(const Duration(milliseconds: 200));

      final pointStatus = mockOverride
          ? PointStatus.perluCekManual
          : (aiResult.status == VerificationStatus.sesuai
              ? PointStatus.sesuai
              : (aiResult.status == VerificationStatus.tidakSesuai
                  ? PointStatus.tidakSesuai
                  : PointStatus.perluCekManual));

      final result = MaintenancePointResult(
        pointId: widget.point.id,
        label: widget.point.label,
        imagePath: file.path,
        shareImageBytes: shareBytes,
        // Disimpan di memori saja (toJson tidak menyertakan field ini) supaya
        // analisa ulang tetap jalan; local storage tetap ringan.
        imageBase64: base64Ai,
        timestamp: now,
        status: pointStatus,
        alasan: mockOverride
            ? '[⚠️ FAKE GPS DETECTED] Mock Location terdeteksi aktif pada perangkat. ${aiResult.alasan}'
            : (aiResult.alasan.isNotEmpty
                ? aiResult.alasan
                : (pointStatus == PointStatus.sesuai
                    ? 'Sesuai SOP (${aiResult.confidenceScore > 0 ? "${(aiResult.confidenceScore * 100).toInt()}%" : "100%"})'
                    : 'Perlu verifikasi ulang')),
        confidence: aiResult.confidenceScore,
        providerName: mockOverride ? 'Mock GPS Guard' : aiResult.providerName,
      );

      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      LoggerService.error('Pengambilan atau pemrosesan foto maintenance gagal', error: e, tag: 'PointCameraView');
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _statusText = 'Gagal memproses foto. Silakan ambil ulang.';
        });
      }
    }
  }

  Widget _buildTopRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Back 44 circle (#000 alpha 0.6 surface via Colors.black.withValues, white icon)
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.6),
          ),
          child: IconButton(
            key: const Key('point_camera_back_button'),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            tooltip: 'Kembali',
            onPressed: () => Navigator.pop(context),
          ),
        ),
        const SizedBox(width: 8),

        // PBM soft pill (light grey fill, ink text)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: TiketColors.light.soft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _activeLocation.locationTag.isNotEmpty
                ? _activeLocation.locationTag
                : 'PBM',
            style: TextStyle(
              fontFamily: 'Figtree',
              color: TiketColors.light.ink,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Title Maintenance white
        const Text(
          'Maintenance',
          style: TextStyle(
            fontFamily: 'Figtree',
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),

        // AI Cloud pill right (black alpha surface, white text, no green/cloud chip)
        GestureDetector(
          onTap: _toggleAiMode,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _isOfflineFastMode ? 'Kilat' : 'AI Cloud',
              style: const TextStyle(
                fontFamily: 'Figtree',
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPointAndControlsRow() {
    final colors = TiketColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // (2) point card = dark rounded 16 surface (Colors.black alpha 0.7), title white 16 bold, SOP text white70 13 readable, no checkbox square
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.point.label,
                  style: const TextStyle(
                    fontFamily: 'Figtree',
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                  softWrap: true,
                ),
                if (widget.point.deskripsi.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.point.deskripsi,
                    style: const TextStyle(
                      fontFamily: 'Figtree',
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.3,
                    ),
                    softWrap: true,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),

        // (3) right column under it: Off, 3:4, flash as 44 dark circles stacked (move 3:4 out of the header)
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Timer circle
            GestureDetector(
              onTap: _cycleTimer,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.6),
                ),
                child: Center(
                  child: Text(
                    _timerSeconds == 0 ? 'Off' : '${_timerSeconds}s',
                    style: TextStyle(
                      fontFamily: 'Figtree',
                      color: _timerSeconds > 0 ? colors.signal : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Ratio circle
            GestureDetector(
              onTap: _cycleRatio,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.6),
                ),
                child: Center(
                  child: Text(
                    _selectedRatio == CameraRatioOption.full
                        ? 'Full'
                        : (_selectedRatio == CameraRatioOption.ratio43 ? '3:4' : '1:1'),
                    style: const TextStyle(
                      fontFamily: 'Figtree',
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Flash circle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.6),
              ),
              child: IconButton(
                key: const Key('point_camera_flash_button'),
                icon: Icon(
                  _flashMode == FlashMode.off
                      ? Icons.flash_off_rounded
                      : (_flashMode == FlashMode.auto
                          ? Icons.flash_auto_rounded
                          : (_flashMode == FlashMode.torch
                              ? Icons.flashlight_on_rounded
                              : Icons.flash_on_rounded)),
                  color: _flashMode == FlashMode.off
                      ? Colors.white70
                      : (_flashMode == FlashMode.torch
                          ? Colors.cyanAccent
                          : colors.signal),
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                tooltip: 'Flash',
                onPressed: _toggleFlash,
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildCameraViewport(Size media) {
    if (widget.placeholderPreview != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return SizedBox(
            width: w,
            height: h,
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                widget.placeholderPreview!,
                MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
                  child: InteractiveWatermark(
                    lat: _realLocation?.lat ?? _activeLocation.lat,
                    lng: _realLocation?.lng ?? _activeLocation.lng,
                    fullAddress: (_realLocation != null &&
                            _realLocation!.fullAddress.isNotEmpty &&
                            !_realLocation!.isDefaultFallback)
                        ? _realLocation!.fullAddress
                        : _activeLocation.fullAddress,
                    kodeVerifikasi: 'TIMEMARK',
                    template: widget.template,
                    config: _watermarkConfig.copyWith(
                      badgeTag: _activeLocation.locationTag,
                      badgeColor: _activeLocation.tagColor,
                    ),
                    activeLocationTag: _activeLocation.locationTag,
                    activeLocationColor: _activeLocation.tagColor,
                    onConfigChanged: (newConfig) {
                      setState(() => _watermarkConfig = newConfig);
                      StorageService.saveWatermarkConfig(newConfig);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
    if (!_isInit || _controller == null) {
      if (_hasInitError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.videocam_off_rounded, color: Colors.redAccent, size: 36),
                ),
                const SizedBox(height: 16),
                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pastikan izin kamera di browser/HP aktif atau tutup aplikasi lain yang sedang menggunakan kamera.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _initCam,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TiketColors.dark.primary,
                    foregroundColor: TiketColors.dark.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(
              _statusText.isNotEmpty ? _statusText : 'Menyiapkan kamera...',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final targetAspect = _calculateTargetAspectRatio(media);
    final colors = TiketColors.of(context);

    return Center(
      child: AspectRatio(
        aspectRatio: targetAspect,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final previewW = constraints.maxWidth;
            final previewH = constraints.maxHeight;

            return Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                // 1. Camera Viewfinder Preview with exact Touch-to-Focus
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    _handleTapToFocus(details.localPosition, previewW, previewH);
                  },
                  child: ClipRect(
                    child: kIsWeb
                        ? SizedBox.expand(
                            child: _controller!.buildPreview(),
                          )
                        : FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _controller!.value.previewSize?.height ?? previewW,
                              height: _controller!.value.previewSize?.width ?? previewH,
                              child: CameraPreview(_controller!),
                            ),
                          ),
                  ),
                ),

                // 2. Animated Focus Reticle Ring (muncul TEPAT di titik sentuhan user)
                if (_showFocusRing && _focusPoint != null)
                  Positioned(
                    left: (_focusPoint!.dx - 28).clamp(0.0, previewW - 56),
                    top: (_focusPoint!.dy - 28).clamp(0.0, previewH - 56),
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
                                  color: colors.signal,
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.signal.withValues(alpha: 0.45),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colors.signal,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const SizedBox(
                                    width: 6,
                                    height: 6,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // 3. Live Interactive Timemark Overlay (strictly bounded inside 3:4 preview frame)
                MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
                  child: InteractiveWatermark(
                    lat: _realLocation?.lat ?? _activeLocation.lat,
                    lng: _realLocation?.lng ?? _activeLocation.lng,
                    fullAddress: (_realLocation != null &&
                            _realLocation!.fullAddress.isNotEmpty &&
                            !_realLocation!.isDefaultFallback)
                        ? _realLocation!.fullAddress
                        : _activeLocation.fullAddress,
                    kodeVerifikasi: 'TIMEMARK',
                    template: widget.template,
                    config: _watermarkConfig.copyWith(
                      badgeTag: _activeLocation.locationTag,
                      badgeColor: _activeLocation.tagColor,
                    ),
                    activeLocationTag: _activeLocation.locationTag,
                    activeLocationColor: _activeLocation.tagColor,
                    onConfigChanged: (newConfig) {
                      setState(() => _watermarkConfig = newConfig);
                      StorageService.saveWatermarkConfig(newConfig);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Teknisi menandai poin ini memang tidak ada/tidak terpasang di lokasi.
  /// Tidak perlu foto, poin langsung dianggap selesai (hemat waktu).
  Future<void> _confirmTidakTerpasang() async {
    final colors = TiketColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.dialog,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Barang tidak terpasang?'),
        content: Text(
            '"${widget.point.label}" akan ditandai TIDAK TERPASANG / tidak ada di lokasi, tanpa perlu foto.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Tidak Terpasang'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    Navigator.pop(
      context,
      MaintenancePointResult(
        pointId: widget.point.id,
        label: widget.point.label,
        timestamp: DateTime.now(),
        status: PointStatus.tidakTerpasang,
        alasan: 'Ditandai teknisi: barang tidak terpasang di lokasi.',
        confidence: 1.0,
        providerName: 'Teknisi (Tanpa Foto)',
      ),
    );
  }

  Widget _buildBottomControls() {
    final colors = TiketColors.of(context);
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Perforation edge at the top (like camera_capture_screen G2)
          Transform.translate(
            offset: const Offset(0, -8),
            child: const ExcludeSemantics(
              child: CustomPaint(
                size: Size(double.infinity, 0),
                painter: PerforationPainter(canvasColor: Colors.black),
              ),
            ),
          ),

          // Floating Instruction Status Pill
          if (!_isCapturing) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24, width: 1.0),
              ),
              child: Text(
                _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left flip-camera 48 dark circle
              if (_cameras.length > 1)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                    border: Border.all(color: Colors.white24, width: 1.0),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    tooltip: 'Ganti Kamera Depan/Belakang',
                    onPressed: _isCapturing || _isCountingDown ? null : _toggleCameraFlip,
                  ),
                )
              else
                const SizedBox(width: 48, height: 48),

              // Shutter = white disc with 4px signal ring
              GestureDetector(
                key: const Key('point_camera_shutter_button'),
                onTap: _isCapturing
                    ? null
                    : (_isCountingDown ? _cancelTimer : _startTimedCapture),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.signal, width: 4.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(4.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _isCapturing ? Colors.grey : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: _isCapturing
                        ? const Center(
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2.5,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ),

              // Right close 48 dark circle (not blue)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(color: Colors.white24, width: 1.0),
                ),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  tooltip: 'Tutup Kamera',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Barang tidak terpasang pill dark outlined
          GestureDetector(
            onTap: _isCapturing || _isCountingDown ? null : _confirmTidakTerpasang,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white24, width: 1.0),
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.do_not_disturb_alt_rounded, color: Colors.white70, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Barang tidak terpasang di lokasi?',
                      style: TextStyle(
                        fontFamily: 'Figtree',
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Builder(
        builder: (context) {
          final media = MediaQuery.of(context).size;

          return Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              top: false,
              bottom: true,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Column: Viewport on top, Bottom Controls below
                  Column(
                    children: [
                      Expanded(
                        child: _buildCameraViewport(media),
                      ),
                      _buildBottomControls(),
                    ],
                  ),

                  // 2. Top HUD Overlay (on top of preview)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      top: true,
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTopRow(),
                            const SizedBox(height: 10),
                            _buildPointAndControlsRow(),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 3. Visual Shutter Overlay — Dynamic Floating Pill
                  if (_isCapturing)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 120,
                      child: Center(
                        child: VerificationStepCard(
                          currentStep: _currentStep,
                          statusText: _statusText,
                          templateName: widget.point.label,
                        ),
                      ),
                    ),

                  // 4. Countdown overlay
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
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: _cancelTimer,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.close, color: Colors.black, size: 16),
                                      SizedBox(width: 4),
                                      Text(
                                        'Batal',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
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
              ),
            ),
          );
        },
      ),
    );
  }
}
