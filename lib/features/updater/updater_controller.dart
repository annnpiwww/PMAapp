import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../data/services/app_update_service.dart';

enum UpdaterPhase {
  available,
  downloading,
  verifying,
  needsPermission,
  ready,
  error,
}

enum InstallStatus { idle, launching, notInstalled, failed }

class UpdaterState {
  final UpdaterPhase phase;
  final AppUpdateCheckResult checkResult;
  final DownloadProgress? progress;
  final String? verifiedFilePath;
  final AppUpdateErrorKind? errorKind;
  final int errorReceivedBytes;
  final int errorTotalBytes;
  final InstallStatus installStatus;
  final bool installFailureMissingFile;

  const UpdaterState({
    required this.phase,
    required this.checkResult,
    this.progress,
    this.verifiedFilePath,
    this.errorKind,
    this.errorReceivedBytes = 0,
    this.errorTotalBytes = 0,
    this.installStatus = InstallStatus.idle,
    this.installFailureMissingFile = false,
  });

  UpdaterState copyWith({
    UpdaterPhase? phase,
    AppUpdateCheckResult? checkResult,
    DownloadProgress? progress,
    String? verifiedFilePath,
    AppUpdateErrorKind? errorKind,
    int? errorReceivedBytes,
    int? errorTotalBytes,
    InstallStatus? installStatus,
    bool? installFailureMissingFile,
  }) {
    return UpdaterState(
      phase: phase ?? this.phase,
      checkResult: checkResult ?? this.checkResult,
      progress: progress ?? this.progress,
      verifiedFilePath: verifiedFilePath ?? this.verifiedFilePath,
      errorKind: errorKind ?? this.errorKind,
      errorReceivedBytes: errorReceivedBytes ?? this.errorReceivedBytes,
      errorTotalBytes: errorTotalBytes ?? this.errorTotalBytes,
      installStatus: installStatus ?? this.installStatus,
      installFailureMissingFile:
          installFailureMissingFile ?? this.installFailureMissingFile,
    );
  }
}

class UpdaterController extends ChangeNotifier with WidgetsBindingObserver {
  UpdaterController({
    required AppUpdateCheckResult checkResult,
    AppUpdateService? service,
    UpdaterPhase initialPhase = UpdaterPhase.available,
    DownloadProgress? initialProgress,
    AppUpdateErrorKind? initialErrorKind,
    String? initialVerifiedFilePath,
  }) : _service = service ?? AppUpdateService.instance,
       _state = UpdaterState(
         phase: initialPhase,
         checkResult: checkResult,
         progress: initialProgress,
         verifiedFilePath: initialVerifiedFilePath,
         errorKind: initialErrorKind,
         errorReceivedBytes: initialProgress?.received ?? 0,
         errorTotalBytes: checkResult.release.sizeBytes,
       ) {
    WidgetsBinding.instance.addObserver(this);
  }

  final AppUpdateService _service;
  UpdaterState _state;
  StreamSubscription<DownloadProgress>? _downloadSub;
  Timer? _installCooldownTimer;
  bool _installCoolingDown = false;
  bool _awaitingInstallerReturn = false;
  bool _sawBackground = false;
  bool _disposed = false;

  UpdaterState get state => _state;
  AppUpdateRelease get release => _state.checkResult.release;
  bool get isMandatory => _state.checkResult.mandatory;
  bool get installButtonCoolingDown => _installCoolingDown;

  void _emit(UpdaterState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  void _clearInstallTracking() {
    _awaitingInstallerReturn = false;
    _sawBackground = false;
    _installCooldownTimer?.cancel();
    _installCooldownTimer = null;
    _installCoolingDown = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_awaitingInstallerReturn) {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden) {
        _sawBackground = true;
      } else if (state == AppLifecycleState.resumed && _sawBackground) {
        _clearInstallTracking();
        _emit(
          _state.copyWith(
            installStatus: InstallStatus.notInstalled,
            installFailureMissingFile: false,
          ),
        );
      }
    }
    if (state == AppLifecycleState.resumed &&
        _state.phase == UpdaterPhase.needsPermission) {
      unawaited(recheckPermission());
    }
  }

  Future<void> startDownload({bool resetPartial = false}) async {
    _clearInstallTracking();
    await _downloadSub?.cancel();
    _downloadSub = null;

    if (resetPartial) {
      try {
        final partFile = await _service.partFileFor(release.versionCode);
        if (partFile.existsSync()) await partFile.delete();
      } catch (_) {}
    }

    var existingBytes = 0;
    try {
      final partFile = await _service.partFileFor(release.versionCode);
      if (partFile.existsSync()) {
        existingBytes = await partFile.length();
      }
    } catch (_) {}

    _emit(
      UpdaterState(
        phase: UpdaterPhase.downloading,
        checkResult: _state.checkResult,
        progress: DownloadProgress(
          received: existingBytes,
          total: release.sizeBytes,
          bytesPerSec: 0,
          eta: null,
        ),
      ),
    );

    final stream = _service.download(
      release,
      _state.checkResult.downloadUrl,
      refreshLatest: () async {
        final fresh = await _service.checkLatest();
        if (fresh != null && !_disposed) {
          _state = _state.copyWith(checkResult: fresh);
        }
        return fresh;
      },
    );

    _downloadSub = stream.listen(
      (p) {
        if (_disposed) return;
        _emit(_state.copyWith(phase: UpdaterPhase.downloading, progress: p));
      },
      onError: (Object err) {
        if (_disposed) return;
        if (err is AppUpdateException) {
          _emit(
            UpdaterState(
              phase: UpdaterPhase.error,
              checkResult: _state.checkResult,
              progress: _state.progress,
              errorKind: err.kind,
              errorReceivedBytes:
                  err.receivedBytes ?? _state.progress?.received ?? 0,
              errorTotalBytes: err.totalBytes ?? release.sizeBytes,
            ),
          );
        } else {
          _emit(
            UpdaterState(
              phase: UpdaterPhase.error,
              checkResult: _state.checkResult,
              progress: _state.progress,
              errorKind: AppUpdateErrorKind.interrupted,
              errorReceivedBytes: _state.progress?.received ?? 0,
              errorTotalBytes: release.sizeBytes,
            ),
          );
        }
      },
      onDone: () {
        if (_disposed || _state.phase == UpdaterPhase.error) return;
        unawaited(_verifyAndAdvance());
      },
      cancelOnError: true,
    );
  }

  Future<void> _verifyAndAdvance() async {
    _emit(_state.copyWith(phase: UpdaterPhase.verifying));
    try {
      final verifiedFile = await _service.verifyAndFinalize(release);
      if (_disposed) return;
      final allowed = await _service.canInstallPackages();
      if (_disposed) return;
      _emit(
        UpdaterState(
          phase: allowed ? UpdaterPhase.ready : UpdaterPhase.needsPermission,
          checkResult: _state.checkResult,
          progress: DownloadProgress(
            received: release.sizeBytes,
            total: release.sizeBytes,
            bytesPerSec: 0,
            eta: Duration.zero,
          ),
          verifiedFilePath: verifiedFile.path,
        ),
      );
    } on AppUpdateException catch (e) {
      if (_disposed) return;
      _emit(
        UpdaterState(
          phase: UpdaterPhase.error,
          checkResult: _state.checkResult,
          errorKind: e.kind,
          errorReceivedBytes: 0,
          errorTotalBytes: release.sizeBytes,
        ),
      );
    } catch (_) {
      if (_disposed) return;
      _emit(
        UpdaterState(
          phase: UpdaterPhase.error,
          checkResult: _state.checkResult,
          errorKind: AppUpdateErrorKind.corruptFile,
          errorReceivedBytes: 0,
          errorTotalBytes: release.sizeBytes,
        ),
      );
    }
  }

  Future<void> cancelDownload() async {
    await _downloadSub?.cancel();
    _downloadSub = null;
  }

  Future<void> openPermissionSettings() =>
      _service.openInstallPermissionSettings();

  Future<void> recheckPermission() async {
    if (_state.phase != UpdaterPhase.needsPermission) return;
    final allowed = await _service.canInstallPackages();
    if (_disposed) return;
    if (allowed) {
      _emit(_state.copyWith(phase: UpdaterPhase.ready));
    }
  }

  Future<void> install() async {
    final path = _state.verifiedFilePath;
    if (path == null || path.isEmpty) return;
    final allowed = await _service.canInstallPackages();
    if (_disposed) return;
    if (!allowed) {
      _clearInstallTracking();
      _emit(_state.copyWith(phase: UpdaterPhase.needsPermission));
      return;
    }

    _awaitingInstallerReturn = false;
    _sawBackground = false;
    _installCooldownTimer?.cancel();
    _installCoolingDown = true;
    _installCooldownTimer = Timer(const Duration(seconds: 3), () {
      if (_disposed) return;
      _installCoolingDown = false;
      _installCooldownTimer = null;
      notifyListeners();
    });
    _emit(
      _state.copyWith(
        installStatus: InstallStatus.launching,
        installFailureMissingFile: false,
      ),
    );

    try {
      final ok = await _service.installApk(path);
      if (_disposed) return;
      if (ok) {
        _awaitingInstallerReturn = true;
      } else {
        _clearInstallTracking();
        _emit(
          _state.copyWith(
            installStatus: InstallStatus.failed,
            installFailureMissingFile: false,
          ),
        );
      }
    } on PlatformException catch (e) {
      if (_disposed) return;
      _clearInstallTracking();
      final missingFile = e.code == 'MISSING_FILE' || e.code == 'INVALID_PATH';
      _emit(
        _state.copyWith(
          installStatus: InstallStatus.failed,
          installFailureMissingFile: missingFile,
        ),
      );
    } catch (_) {
      if (_disposed) return;
      _clearInstallTracking();
      _emit(
        _state.copyWith(
          installStatus: InstallStatus.failed,
          installFailureMissingFile: false,
        ),
      );
    }
  }

  Future<void> redownload() {
    _clearInstallTracking();
    if (_state.installStatus != InstallStatus.idle ||
        _state.installFailureMissingFile) {
      _emit(
        _state.copyWith(
          installStatus: InstallStatus.idle,
          installFailureMissingFile: false,
        ),
      );
    }
    return startDownload(resetPartial: true);
  }

  Future<void> dismissLater() async {
    await cancelDownload();
    if (!isMandatory) {
      await _service.dismissFor12Hours(release.versionCode);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _clearInstallTracking();
    unawaited(_downloadSub?.cancel() ?? Future<void>.value());
    _downloadSub = null;
    super.dispose();
  }
}
