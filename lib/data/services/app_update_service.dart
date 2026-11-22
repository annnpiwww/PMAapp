import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/auth_repository.dart';
import 'daily_task_service.dart';

class AppUpdateRelease {
  final String id;
  final String versionName;
  final int versionCode;
  final int sizeBytes;
  final String sha256;
  final String changelog;

  const AppUpdateRelease({
    required this.id,
    required this.versionName,
    required this.versionCode,
    required this.sizeBytes,
    required this.sha256,
    required this.changelog,
  });

  factory AppUpdateRelease.fromJson(Map<String, dynamic> json) {
    return AppUpdateRelease(
      id: (json['id'] as String?)?.trim() ?? '',
      versionName: (json['version_name'] as String?)?.trim() ?? '',
      versionCode: (json['version_code'] as num).toInt(),
      sizeBytes: (json['size_bytes'] as num).toInt(),
      sha256: ((json['sha256'] as String?) ?? '').trim().toLowerCase(),
      changelog: (json['changelog'] as String?) ?? '',
    );
  }
}

class AppUpdateCheckResult {
  final AppUpdateRelease release;
  final bool mandatory;
  final String downloadUrl;
  final String currentVersion;
  final int currentCode;

  const AppUpdateCheckResult({
    required this.release,
    required this.mandatory,
    required this.downloadUrl,
    required this.currentVersion,
    required this.currentCode,
  });
}

class DownloadProgress {
  final int received;
  final int total;
  final double bytesPerSec;
  final Duration? eta;

  const DownloadProgress({
    required this.received,
    required this.total,
    required this.bytesPerSec,
    required this.eta,
  });

  double get fraction => total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
  int get percent => (fraction * 100).round().clamp(0, 100);
}

enum AppUpdateErrorKind { noInternet, interrupted, corruptFile, storageFull }

class AppUpdateException implements Exception {
  final AppUpdateErrorKind kind;
  final String message;
  final int? receivedBytes;
  final int? totalBytes;

  const AppUpdateException(
    this.kind,
    this.message, {
    this.receivedBytes,
    this.totalBytes,
  });

  @override
  String toString() => 'AppUpdateException($kind): $message';
}

class _SpeedSample {
  final DateTime at;
  final int bytes;

  const _SpeedSample(this.at, this.bytes);
}

/// Computes lowercase hex SHA-256 of a file using chunked I/O.
String computeFileSha256Sync(String filePath) {
  final file = File(filePath);
  final raf = file.openSync();
  try {
    final output = _SingleDigestSink();
    final input = sha256.startChunkedConversion(output);
    const chunkSize = 64 * 1024;
    final buffer = Uint8List(chunkSize);
    while (true) {
      final read = raf.readIntoSync(buffer);
      if (read <= 0) break;
      input.add(
        read == chunkSize ? buffer : Uint8List.sublistView(buffer, 0, read),
      );
    }
    input.close();
    return output.value.toString().toLowerCase();
  } finally {
    raf.closeSync();
  }
}

class _SingleDigestSink implements Sink<Digest> {
  Digest? _value;
  Digest get value => _value!;

  @override
  void add(Digest data) {
    _value = data;
  }

  @override
  void close() {}
}

class AppUpdateService {
  AppUpdateService({
    http.Client Function()? clientFactory,
    Future<List<String>> Function()? supportedAbisProvider,
    Future<PackageInfo> Function()? packageInfoProvider,
    Future<Directory> Function()? cacheDirProvider,
    Future<bool> Function()? canInstallPackagesProvider,
    Future<bool> Function()? openInstallPermissionSettingsProvider,
    Future<bool> Function(String path)? installApkProvider,
    String Function()? baseUrlProvider,
    String Function()? anonKeyProvider,
    String? Function()? sessionTokenProvider,
    Future<SharedPreferences> Function()? prefsProvider,
    DateTime Function()? nowProvider,
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _supportedAbisProvider = supportedAbisProvider ?? _defaultSupportedAbis,
       _packageInfoProvider = packageInfoProvider ?? PackageInfo.fromPlatform,
       _cacheDirProvider = cacheDirProvider ?? getTemporaryDirectory,
       _canInstallPackagesProvider =
           canInstallPackagesProvider ?? _defaultCanInstallPackages,
       _openInstallPermissionSettingsProvider =
           openInstallPermissionSettingsProvider ??
           _defaultOpenInstallPermissionSettings,
       _installApkProvider = installApkProvider ?? _defaultInstallApk,
       _baseUrlProvider = baseUrlProvider ?? (() => DailyTaskService.baseUrl),
       _anonKeyProvider = anonKeyProvider ?? (() => DailyTaskService.anonKey),
       _sessionTokenProvider =
           sessionTokenProvider ?? (() => AuthRepository.instance.sessionToken),
       _prefsProvider = prefsProvider ?? SharedPreferences.getInstance,
       _nowProvider = nowProvider ?? DateTime.now;

  static final AppUpdateService instance = AppUpdateService();

  static const MethodChannel channel = MethodChannel(
    'com.bssparking.timemark/app_updater',
  );

  static const List<String> supportedAbiTargets = [
    'arm64-v8a',
    'armeabi-v7a',
    'x86_64',
  ];

  static const Duration checkTimeout = Duration(seconds: 8);
  static const Duration dismissalDuration = Duration(hours: 12);
  static const int _isolateVerifyThresholdBytes = 5 * 1024 * 1024;
  static const String _dismissKeyPrefix = 'bss_updater_dismissed_';

  final http.Client Function() _clientFactory;
  final Future<List<String>> Function() _supportedAbisProvider;
  final Future<PackageInfo> Function() _packageInfoProvider;
  final Future<Directory> Function() _cacheDirProvider;
  final Future<bool> Function() _canInstallPackagesProvider;
  final Future<bool> Function() _openInstallPermissionSettingsProvider;
  final Future<bool> Function(String path) _installApkProvider;
  final String Function() _baseUrlProvider;
  final String Function() _anonKeyProvider;
  final String? Function() _sessionTokenProvider;
  final Future<SharedPreferences> Function() _prefsProvider;
  final DateTime Function() _nowProvider;

  static Future<List<String>> _defaultSupportedAbis() async {
    if (kIsWeb || !Platform.isAndroid) return const [];
    final raw = await channel.invokeListMethod<String>('getSupportedAbis');
    return raw ?? const [];
  }

  static Future<bool> _defaultCanInstallPackages() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    final res = await channel.invokeMethod<bool>('canInstallPackages');
    return res ?? true;
  }

  static Future<bool> _defaultOpenInstallPermissionSettings() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    final res = await channel.invokeMethod<bool>(
      'openInstallPermissionSettings',
    );
    return res ?? false;
  }

  static Future<bool> _defaultInstallApk(String path) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    final res = await channel.invokeMethod<bool>('installApk', {'path': path});
    return res ?? false;
  }

  /// Picks the first device ABI present in [supportedAbiTargets].
  static String? pickAbi(List<String> supportedAbis) {
    for (final abi in supportedAbis) {
      if (supportedAbiTargets.contains(abi)) return abi;
    }
    return null;
  }

  static String formatMbNumber(int bytes) {
    final mb = bytes / 1000000.0;
    return mb.toStringAsFixed(1).replaceAll('.', ',');
  }

  static String formatMb(int bytes) {
    return '${formatMbNumber(bytes)} MB';
  }

  static String formatMbProgress(int received, int total) {
    return '${formatMbNumber(received)} / ${formatMbNumber(total)} MB';
  }

  static String formatSpeed(double bytesPerSec) {
    final mbPerSec = bytesPerSec / 1000000.0;
    return '${mbPerSec.toStringAsFixed(1).replaceAll('.', ',')} MB/dtk';
  }

  static String formatEta(Duration? eta) {
    if (eta == null || eta.inSeconds <= 0) return 'menghitung...';
    final secs = eta.inSeconds;
    if (secs >= 60) {
      final mins = (secs / 60).ceil();
      return 'sekitar $mins mnt';
    }
    return 'sekitar $secs dtk';
  }

  Future<Directory> updatesDirectory() async {
    final cacheDir = await _cacheDirProvider();
    final dir = Directory('${cacheDir.path}${Platform.pathSeparator}updates');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> partFileFor(int versionCode) async {
    final dir = await updatesDirectory();
    return File(
      '${dir.path}${Platform.pathSeparator}pmapp-$versionCode.apk.part',
    );
  }

  Future<File> apkFileFor(int versionCode) async {
    final dir = await updatesDirectory();
    return File('${dir.path}${Platform.pathSeparator}pmapp-$versionCode.apk');
  }

  /// Deletes cached update APKs/partials at or below [currentCode] to reclaim space.
  Future<void> cleanupStaleApks({required int currentCode}) async {
    try {
      final dir = await updatesDirectory();
      if (!dir.existsSync()) return;
      final re = RegExp(r'^pmapp-(\d+)\.apk(\.part)?$');
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (name.startsWith('picked-') && name.endsWith('.apk')) {
          try {
            await entity.delete();
          } catch (_) {}
          continue;
        }
        final m = re.firstMatch(name);
        if (m == null) continue;
        final code = int.tryParse(m.group(1) ?? '');
        if (code != null && code <= currentCode) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Checks the `app-releases` Edge Function (`action: 'latest'`).
  /// Returns `null` when no update is available or on any network/parse failure.
  Future<AppUpdateCheckResult?> checkLatest() async {
    http.Client? client;
    try {
      if (kIsWeb) return null;
      final info = await _packageInfoProvider();
      final currentCode = int.tryParse(info.buildNumber);
      if (currentCode == null || currentCode <= 0) return null;

      unawaited(cleanupStaleApks(currentCode: currentCode));

      final abis = await _supportedAbisProvider();
      final abi = pickAbi(abis);
      if (abi == null) return null;

      final baseUrl = _baseUrlProvider();
      final anonKey = _anonKeyProvider();
      final token = _sessionTokenProvider();
      final uri = Uri.parse('$baseUrl/functions/v1/app-releases');

      client = _clientFactory();
      final response = await client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'apikey': anonKey,
              'Authorization': 'Bearer $anonKey',
              if (token != null && token.isNotEmpty) 'x-app-session': token,
            },
            body: jsonEncode({
              'action': 'latest',
              'abi': abi,
              'current_code': currentCode,
              'current_version': info.version,
            }),
          )
          .timeout(checkTimeout);

      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['update'] != true) return null;

      final releaseJson = decoded['release'];
      final downloadUrl = decoded['download_url'];
      if (releaseJson is! Map<String, dynamic> ||
          downloadUrl is! String ||
          downloadUrl.trim().isEmpty) {
        return null;
      }

      final release = AppUpdateRelease.fromJson(releaseJson);
      if (release.id.isEmpty ||
          release.versionName.isEmpty ||
          release.versionCode <= 0 ||
          release.sizeBytes <= 0 ||
          release.sha256.length != 64) {
        return null;
      }

      return AppUpdateCheckResult(
        release: release,
        mandatory: decoded['mandatory'] == true,
        downloadUrl: downloadUrl.trim(),
        currentVersion: info.version,
        currentCode: currentCode,
      );
    } catch (_) {
      return null;
    } finally {
      client?.close();
    }
  }

  Future<bool> isDismissedFor12Hours(int versionCode) async {
    final prefs = await _prefsProvider();
    final savedMs = prefs.getInt('$_dismissKeyPrefix$versionCode');
    if (savedMs == null) return false;
    final dismissedAt = DateTime.fromMillisecondsSinceEpoch(savedMs);
    return _nowProvider().difference(dismissedAt) < dismissalDuration;
  }

  Future<void> dismissFor12Hours(int versionCode) async {
    final prefs = await _prefsProvider();
    await prefs.setInt(
      '$_dismissKeyPrefix$versionCode',
      _nowProvider().millisecondsSinceEpoch,
    );
  }

  Future<bool> shouldPrompt(AppUpdateCheckResult result) async {
    if (result.mandatory) return true;
    return !(await isDismissedFor12Hours(result.release.versionCode));
  }

  /// Streams download bytes into `<cache>/updates/pmapp-<versionCode>.apk.part`
  /// with HTTP Range resume, 3s rolling speed, and signed-URL refresh on 400/403.
  Stream<DownloadProgress> download(
    AppUpdateRelease release,
    String url, {
    Future<AppUpdateCheckResult?> Function()? refreshLatest,
  }) {
    final controller = StreamController<DownloadProgress>();
    var cancelled = false;
    http.Client? activeClient;
    IOSink? activeSink;

    controller.onCancel = () {
      cancelled = true;
      try {
        activeClient?.close();
      } catch (_) {}
      activeClient = null;
      final sink = activeSink;
      activeSink = null;
      if (sink != null) {
        unawaited(sink.close().catchError((_) {}));
      }
    };

    () async {
      try {
        final finalFile = await apkFileFor(release.versionCode);
        if (finalFile.existsSync()) {
          if (await verify(finalFile, release)) {
            if (!cancelled && !controller.isClosed) {
              controller.add(
                DownloadProgress(
                  received: release.sizeBytes,
                  total: release.sizeBytes,
                  bytesPerSec: 0,
                  eta: Duration.zero,
                ),
              );
              await controller.close();
            }
            return;
          }
        }

        final partFile = await partFileFor(release.versionCode);
        var currentUrl = url;
        var refreshedUrl = false;
        var resetPart = false;

        while (!cancelled) {
          var existingLength = 0;
          if (!resetPart && partFile.existsSync()) {
            existingLength = await partFile.length();
            if (existingLength > release.sizeBytes) {
              await partFile.delete();
              existingLength = 0;
            }
          }
          resetPart = false;

          if (existingLength == release.sizeBytes && release.sizeBytes > 0) {
            if (!cancelled && !controller.isClosed) {
              controller.add(
                DownloadProgress(
                  received: existingLength,
                  total: release.sizeBytes,
                  bytesPerSec: 0,
                  eta: Duration.zero,
                ),
              );
              await controller.close();
            }
            return;
          }

          activeClient?.close();
          activeClient = _clientFactory();

          final request = http.Request('GET', Uri.parse(currentUrl));
          if (existingLength > 0) {
            request.headers['Range'] = 'bytes=$existingLength-';
          }

          final http.StreamedResponse response;
          try {
            response = await activeClient!
                .send(request)
                .timeout(const Duration(seconds: 25));
          } on SocketException {
            throw AppUpdateException(
              existingLength > 0
                  ? AppUpdateErrorKind.interrupted
                  : AppUpdateErrorKind.noInternet,
              existingLength > 0
                  ? 'Unduhan terputus'
                  : 'Tidak ada koneksi internet',
              receivedBytes: existingLength,
              totalBytes: release.sizeBytes,
            );
          } on TimeoutException {
            throw AppUpdateException(
              existingLength > 0
                  ? AppUpdateErrorKind.interrupted
                  : AppUpdateErrorKind.noInternet,
              existingLength > 0
                  ? 'Unduhan terputus'
                  : 'Tidak ada koneksi internet',
              receivedBytes: existingLength,
              totalBytes: release.sizeBytes,
            );
          } on http.ClientException {
            if (cancelled) return;
            throw AppUpdateException(
              existingLength > 0
                  ? AppUpdateErrorKind.interrupted
                  : AppUpdateErrorKind.noInternet,
              existingLength > 0
                  ? 'Unduhan terputus'
                  : 'Tidak ada koneksi internet',
              receivedBytes: existingLength,
              totalBytes: release.sizeBytes,
            );
          }

          // Signed URL may expire after 900s: refresh via checkLatest once.
          if ((response.statusCode == 400 || response.statusCode == 403) &&
              !refreshedUrl &&
              refreshLatest != null) {
            refreshedUrl = true;
            await response.stream.drain<void>().catchError((_) {});
            final fresh = await refreshLatest();
            if (fresh != null && fresh.downloadUrl.isNotEmpty) {
              currentUrl = fresh.downloadUrl;
              continue;
            }
          }

          if (response.statusCode == 416) {
            await response.stream.drain<void>().catchError((_) {});
            if (existingLength >= release.sizeBytes) {
              if (!cancelled && !controller.isClosed) {
                controller.add(
                  DownloadProgress(
                    received: existingLength,
                    total: release.sizeBytes,
                    bytesPerSec: 0,
                    eta: Duration.zero,
                  ),
                );
                await controller.close();
              }
              return;
            }
            if (partFile.existsSync()) await partFile.delete();
            resetPart = true;
            continue;
          }

          if (response.statusCode != 200 && response.statusCode != 206) {
            await response.stream.drain<void>().catchError((_) {});
            throw AppUpdateException(
              AppUpdateErrorKind.interrupted,
              'Unduhan terputus',
              receivedBytes: existingLength,
              totalBytes: release.sizeBytes,
            );
          }

          final isAppend = response.statusCode == 206 && existingLength > 0;
          var received = isAppend ? existingLength : 0;
          final total = release.sizeBytes > 0
              ? release.sizeBytes
              : ((response.contentLength ?? 0) +
                    (isAppend ? existingLength : 0));

          final sink = partFile.openWrite(
            mode: isAppend ? FileMode.append : FileMode.write,
          );
          activeSink = sink;

          final samples = ListQueue<_SpeedSample>();
          var lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

          try {
            await for (final chunk in response.stream) {
              if (cancelled) break;
              try {
                sink.add(chunk);
              } on FileSystemException catch (e) {
                throw _mapFsError(e, received, total);
              }
              received += chunk.length;

              final now = _nowProvider();
              samples.add(_SpeedSample(now, chunk.length));
              final cutoff = now.subtract(const Duration(seconds: 3));
              while (samples.isNotEmpty && samples.first.at.isBefore(cutoff)) {
                samples.removeFirst();
              }

              if (now.difference(lastEmit).inMilliseconds >= 80 ||
                  (total > 0 && received >= total)) {
                lastEmit = now;
                final speed = _computeSpeed(samples, now);
                final eta = _computeEta(received, total, speed);
                if (!cancelled && !controller.isClosed) {
                  controller.add(
                    DownloadProgress(
                      received: received,
                      total: total,
                      bytesPerSec: speed,
                      eta: eta,
                    ),
                  );
                }
              }
            }
            await sink.flush();
            await sink.close();
            activeSink = null;
          } on FileSystemException catch (e) {
            await sink.close().catchError((_) {});
            activeSink = null;
            throw _mapFsError(e, received, total);
          } on SocketException {
            await sink.close().catchError((_) {});
            activeSink = null;
            throw AppUpdateException(
              received > 0
                  ? AppUpdateErrorKind.interrupted
                  : AppUpdateErrorKind.noInternet,
              received > 0 ? 'Unduhan terputus' : 'Tidak ada koneksi internet',
              receivedBytes: received,
              totalBytes: total,
            );
          } on http.ClientException {
            await sink.close().catchError((_) {});
            activeSink = null;
            if (cancelled) return;
            throw AppUpdateException(
              received > 0
                  ? AppUpdateErrorKind.interrupted
                  : AppUpdateErrorKind.noInternet,
              received > 0 ? 'Unduhan terputus' : 'Tidak ada koneksi internet',
              receivedBytes: received,
              totalBytes: total,
            );
          }

          if (!cancelled && !controller.isClosed) {
            controller.add(
              DownloadProgress(
                received: received,
                total: total,
                bytesPerSec: 0,
                eta: Duration.zero,
              ),
            );
            await controller.close();
          }
          return;
        }
      } on AppUpdateException catch (e) {
        if (!cancelled && !controller.isClosed) {
          controller.addError(e);
          await controller.close();
        }
      } on FileSystemException catch (e) {
        if (!cancelled && !controller.isClosed) {
          controller.addError(_mapFsError(e, 0, release.sizeBytes));
          await controller.close();
        }
      } catch (e) {
        if (!cancelled && !controller.isClosed) {
          controller.addError(
            AppUpdateException(
              AppUpdateErrorKind.interrupted,
              'Unduhan terputus',
              totalBytes: release.sizeBytes,
            ),
          );
          await controller.close();
        }
      } finally {
        try {
          activeClient?.close();
        } catch (_) {}
        activeClient = null;
      }
    }();

    return controller.stream;
  }

  static double _computeSpeed(ListQueue<_SpeedSample> samples, DateTime now) {
    if (samples.isEmpty) return 0.0;
    var totalBytes = 0;
    for (final s in samples) {
      totalBytes += s.bytes;
    }
    final elapsedMs = now.difference(samples.first.at).inMilliseconds;
    final seconds = elapsedMs < 250 ? 0.25 : elapsedMs / 1000.0;
    return totalBytes / seconds;
  }

  static Duration? _computeEta(int received, int total, double speed) {
    if (total <= 0 || received >= total || speed <= 1024) return null;
    final remaining = total - received;
    return Duration(seconds: (remaining / speed).ceil());
  }

  static AppUpdateException _mapFsError(
    FileSystemException e,
    int received,
    int total,
  ) {
    final code = e.osError?.errorCode;
    final msg = '${e.message} ${e.osError?.message ?? ''}'.toLowerCase();
    if (code == 28 || msg.contains('no space') || msg.contains('enospc')) {
      return AppUpdateException(
        AppUpdateErrorKind.storageFull,
        'Penyimpanan penuh',
        receivedBytes: received,
        totalBytes: total,
      );
    }
    return AppUpdateException(
      AppUpdateErrorKind.interrupted,
      'Gagal menyimpan file pembaruan',
      receivedBytes: received,
      totalBytes: total,
    );
  }

  /// Verifies [file] byte size and SHA-256 against [release].
  /// Deletes [file] if verification fails.
  Future<bool> verify(File file, AppUpdateRelease release) async {
    if (!file.existsSync()) return false;
    final length = await file.length();
    if (length != release.sizeBytes) {
      await file.delete().catchError((_) => file);
      return false;
    }

    final actualSha = length > _isolateVerifyThresholdBytes
        ? await Isolate.run(() => computeFileSha256Sync(file.path))
        : computeFileSha256Sync(file.path);

    if (actualSha != release.sha256.toLowerCase()) {
      await file.delete().catchError((_) => file);
      return false;
    }
    return true;
  }

  /// Verifies the downloaded `.part` file and atomically renames it to `.apk`.
  /// Throws [AppUpdateException] with [AppUpdateErrorKind.corruptFile] on mismatch.
  Future<File> verifyAndFinalize(AppUpdateRelease release) async {
    final finalFile = await apkFileFor(release.versionCode);
    if (finalFile.existsSync()) {
      if (await verify(finalFile, release)) {
        return finalFile;
      }
    }

    final partFile = await partFileFor(release.versionCode);
    final ok = await verify(partFile, release);
    if (!ok) {
      throw const AppUpdateException(
        AppUpdateErrorKind.corruptFile,
        'File pembaruan rusak',
      );
    }
    if (finalFile.existsSync()) {
      await finalFile.delete();
    }
    return partFile.rename(finalFile.path);
  }

  Future<bool> canInstallPackages() => _canInstallPackagesProvider();
  Future<bool> openInstallPermissionSettings() =>
      _openInstallPermissionSettingsProvider();
  Future<bool> installApk(String path) => _installApkProvider(path);
}
