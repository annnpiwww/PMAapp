import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../../core/constants/app_colors.dart';
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
import '../../../data/repositories/auth_repository.dart';
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

  /// Preferensi global mode offline agar jika 1 poin terdeteksi offline, poin berikutnya otomatis cepat
  static bool globalOfflineMode = false;

  const PointCameraView({
    super.key,
    required this.point,
    required this.template,
    this.location,
  });

  @override
  State<PointCameraView> createState() => _PointCameraViewState();
}

class _PointCameraViewState extends State<PointCameraView> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInit = false;
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
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      _selectedCameraIndex = 0;
      await _initializeControllerWithFallback(_selectedCameraIndex);
    } catch (e) {
      if (mounted) setState(() => _statusText = 'Kamera error: $e');
    }
  }

  Future<void> _initializeControllerWithFallback(int cameraIndex) async {
    final presets = [
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

    CameraException? lastErr;
    for (final preset in presets) {
      try {
        final ctrl = CameraController(
          _cameras[cameraIndex],
          preset,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );
        await ctrl.initialize();
        _controller = ctrl;
        try {
          await _controller!.setFocusMode(FocusMode.auto);
          await _controller!.setExposureMode(ExposureMode.auto);
        } catch (_) {}
        if (mounted) {
          setState(() {
            _isInit = true;
            _statusText = 'Arahkan kamera ke objek';
          });
        }
        return;
      } on CameraException catch (e) {
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
        _statusText = 'Kamera gagal dimulai (${lastErr?.description ?? lastErr?.code ?? 'Perangkat sibuk'})';
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
    } catch (_) {}
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
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: _isOfflineFastMode ? const Color(0xFFB45309) : const Color(0xFF047857),
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
                    ? 'Mode Kilat Aktif: Foto langsung disimpan tanpa AI Vision (hemat waktu & sinyal)'
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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Expanded(
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
          'Jika Anda memilih Lanjut Darurat, foto akan ditandai [FAKE GPS DETECTED] dan otomatis berstatus Cek Manual untuk diaudit oleh Supervisor.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal / Matikan Fake GPS'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lanjut Darurat (Ditandai SPV)'),
          ),
        ],
      ),
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
      final bytes = await File(file.path).readAsBytes();

      final verifiedTime = SecureTimeService.getVerifiedTime();
      final now = verifiedTime.accurateTime;
      final user = AuthRepository.instance.currentUser;

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

      // Mulai watermark di background (jalan paralel dengan AI verify)
      Future<String>? watermarkFuture;
      try {
        watermarkFuture = ImageWatermarkProcessor.applyWatermarkToFile(
          imagePath: file.path,
          timestamp: now,
          lat: lat,
          lng: lng,
          fullAddress: fullAddr,
          kodeVerifikasi: code,
          config: _watermarkConfig.copyWith(
            badgeTag: activeTag,
            badgeColor: activeTagColor,
          ),
          activeLocationTag: activeTag,
          activeLocationColor: activeTagColor,
          pointLabel: widget.point.label,
          isFrontCamera: _isFrontCamera,
          targetAspectRatio: targetAspect,
          jpegQuality: 93,
        );
      } catch (err) {
        debugPrint('[PointCameraView] Error saat memicu watermark: $err');
      }

      // Jika Mode Offline Cepat aktif: tunggu watermark selesai lalu simpan
      if (_isOfflineFastMode) {
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
        setState(() {
          _statusText = '⚡ Mode Offline Cepat: Foto tersimpan!';
        });
        await Future.delayed(const Duration(milliseconds: 150));

        final result = MaintenancePointResult(
          pointId: widget.point.id,
          label: widget.point.label,
          imagePath: file.path,
          imageBase64: null,
          timestamp: now,
          status: PointStatus.perluCekManual,
          alasan: mockOverride
              ? '[⚠️ FAKE GPS DETECTED] Mock Location aktif pada HP teknisi saat verifikasi checklist offline.'
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
      try {
        aiResult = await AiVisionService.verifyMaintenancePoint(
          point: widget.point,
          template: widget.template,
          imageBase64: base64Ai,
        );
        if (aiResult.isFallback) {
          // Jika server vision offline atau timeout, aktifkan auto-offline untuk poin berikutnya
          PointCameraView.globalOfflineMode = true;
        }
      } catch (err) {
        PointCameraView.globalOfflineMode = true;
        aiResult = AiVerificationResult(
          status: VerificationStatus.perluCekManual,
          alasan: 'Offline: Foto tersimpan aman di HP. Perlu cek manual ($err)',
          poinGagal: [],
          poinLolos: [],
          confidenceScore: 0.5,
          providerName: 'Offline Fallback',
          isFallback: true,
        );
      }

      setState(() {
        _statusText = 'Selesai';
        _currentStep = 4;
      });

      // Pastikan watermark HD selesai sebelum foto disimpan ke laporan
      if (watermarkFuture != null) {
        try {
          await watermarkFuture.timeout(const Duration(seconds: 12));
        } catch (e) {
          debugPrint('[PointCameraView] Timeout/error watermark online: $e');
        }
      }

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
        imageBase64: null, // Jangan simpan base64 ke local storage
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
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _statusText = 'Gagal: $e';
        });
      }
    }
  }

  Widget _buildTopHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Back/Close, Location Tag, Title, AI status, Timer, Ratio, Flash
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                tooltip: 'Kembali',
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: _activeLocation.tagColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _activeLocation.tagColor.withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
                child: Text(
                  _activeLocation.locationTag.isNotEmpty
                      ? _activeLocation.locationTag
                      : 'BSS',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: _activeLocation.tagColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Flexible(
                child: Text(
                  'Maintenance',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),

              // Shortcut AI Status (Online / Offline Mode Kilat)
              GestureDetector(
                onTap: _toggleAiMode,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: _isOfflineFastMode
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.25)
                        : const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isOfflineFastMode
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF10B981),
                      width: 1.1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isOfflineFastMode ? Icons.bolt_rounded : Icons.cloud_done_rounded,
                        size: 12,
                        color: _isOfflineFastMode ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _isOfflineFastMode ? 'Kilat' : 'AI Cloud',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: _isOfflineFastMode ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Timer Pill
              GestureDetector(
                onTap: _cycleTimer,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: _timerSeconds > 0
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _timerSeconds > 0
                          ? const Color(0xFFF59E0B)
                          : Colors.white30,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_rounded,
                        size: 12,
                        color: _timerSeconds > 0 ? const Color(0xFFF59E0B) : Colors.white70,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _timerSeconds == 0 ? 'Off' : '${_timerSeconds}s',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: _timerSeconds > 0 ? const Color(0xFFF59E0B) : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Ratio Pill (3:4 / Full / 1:1)
              GestureDetector(
                onTap: _cycleRatio,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Text(
                    _selectedRatio == CameraRatioOption.full
                        ? 'Full'
                        : (_selectedRatio == CameraRatioOption.ratio43 ? '3:4' : '1:1'),
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),

              // Flash Toggle
              IconButton(
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
                          : Colors.amber),
                  size: 18,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _toggleFlash,
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Row 2: Point Info Compact Card (Terlihat jelas, multi-line, anti-terpotong)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.assignment_turned_in_rounded, size: 15, color: Color(0xFF38BDF8)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.point.label,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.point.deskripsi.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.point.deskripsi,
                          maxLines: 3,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 10,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCameraViewport(Size media) {
    if (!_isInit || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final targetAspect = _calculateTargetAspectRatio(media);

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
                                  color: const Color(0xFFFACC15),
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFACC15).withValues(alpha: 0.45),
                                    blurRadius: 10,
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
                InteractiveWatermark(
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
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Floating Instruction Status Pill
          if (!_isCapturing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Switch Camera Button (Rotate)
              if (_cameras.length > 1)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 22),
                    tooltip: 'Ganti Kamera Depan/Belakang',
                    onPressed: _isCapturing || _isCountingDown ? null : _toggleCameraFlip,
                  ),
                )
              else
                const SizedBox(width: 48, height: 48),

              // Pro Dual-Ring Shutter button
              GestureDetector(
                onTap: _isCapturing
                    ? null
                    : (_isCountingDown ? _cancelTimer : _startTimedCapture),
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(4.5),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _isCapturing ? Colors.grey : AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: _isCapturing
                          ? const SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),

              // Close Button (Tutup Kamera)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(color: Colors.white24),
                ),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                  tooltip: 'Tutup Kamera',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Non-overlapping 3-part layout: Top Header, Center 3:4 Viewport, Bottom Controls
            Column(
              children: [
                _buildTopHeader(),
                Expanded(
                  child: _buildCameraViewport(media),
                ),
                _buildBottomControls(),
              ],
            ),

            // Visual Shutter Overlay — Dynamic Floating Pill (Non-intrusive di atas kontrol bawah)
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
  }
}
