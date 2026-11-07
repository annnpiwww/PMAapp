import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SecureTimeResult {
  final DateTime accurateTime;
  final bool isDeviceTimeManipulated;
  final bool isTimeSkewDetected;
  final bool isTampered;
  final int offsetSeconds;
  final String source; // 'NTP_HTTP', 'DEVICE_FALLBACK'
  final String? warningTag; // '[JAM DIUBAH MANUAL]' jika terdeteksi manipulasi
  final String? reason;

  SecureTimeResult({
    required this.accurateTime,
    required this.isDeviceTimeManipulated,
    this.isTimeSkewDetected = false,
    bool? isTampered,
    required this.offsetSeconds,
    required this.source,
    this.warningTag,
    this.reason,
  }) : isTampered = isTampered ?? (isDeviceTimeManipulated || isTimeSkewDetected);
}

class SecureTimeService {
  // Monotonic timer internal sejak app startup untuk deteksi lonjakan waktu (clock skew)
  static final Stopwatch _monotonicStopwatch = Stopwatch()..start();
  static DateTime _anchorWallTime = DateTime.now();
  static Duration _anchorStopwatchElapsed = Duration.zero;

  static DateTime? _lastSyncedNetworkTime;
  static int _cachedOffsetSeconds = 0;
  static bool _isManipulated = false;
  static bool _isTimeSkewDetected = false;
  static bool _isTampered = false;
  static String? _tamperedReason;

  @visibleForTesting
  static http.Client? clientOverride;

  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  static bool get isTimeSkewDetected => _isTimeSkewDetected;
  static bool get isTampered => _isTampered || _isManipulated || _isTimeSkewDetected;
  static String? get warningTag => isTampered ? '[JAM DIUBAH MANUAL]' : null;

  /// Sinkronisasi waktu internet (World Time API / Google Date Header)
  static Future<void> syncNetworkTime() async {
    final bool ownsClient = clientOverride == null;
    final client = clientOverride ?? http.Client();
    try {
      final uri = Uri.parse('https://www.google.com/generate_204');
      final response = await client.head(uri).timeout(const Duration(seconds: 3));

      final dateHeader = response.headers['date'];
      if (dateHeader != null) {
        DateTime? serverTime;
        if (!kIsWeb) {
          try {
            serverTime = HttpDate.parse(dateHeader).toLocal();
          } catch (_) {}
        }
        serverTime ??= _tryParseHttpDate(dateHeader)?.toLocal();

        if (serverTime != null) {
          final deviceTime = clock();
          _cachedOffsetSeconds = serverTime.difference(deviceTime).inSeconds;
          // Toleransi perbedaan jam HP vs Server: 300 detik (5 menit)
          _isManipulated = _cachedOffsetSeconds.abs() > 300;
          _lastSyncedNetworkTime = serverTime;
          _anchorWallTime = deviceTime;
          _anchorStopwatchElapsed = _monotonicStopwatch.elapsed;

          if (_isManipulated) {
            _isTampered = true;
            _tamperedReason = 'Offset server berbeda ${_cachedOffsetSeconds}s (> 300s)';
          } else {
            _isTimeSkewDetected = false;
            _isTampered = false;
            _tamperedReason = null;
          }

          debugPrint('[BSS-Security] Time Synced. Offset: ${_cachedOffsetSeconds}s, Manipulated: $_isManipulated');
        }
      }
    } catch (e) {
      debugPrint('[BSS-Security] Sync network time failed: $e');
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }

  /// Mendapatkan waktu terverifikasi anti-fake time:
  /// Hanya menandai manipulasi jika selisih jam perangkat vs network time > 300s (5 menit).
  static SecureTimeResult getVerifiedTime() {
    final nowDevice = clock();
    final currentStopwatch = _monotonicStopwatch.elapsed;

    // Jika perangkat baru bangun dari deep sleep, re-anchor dan picu sync network time
    final elapsedMonotonicSinceAnchor = currentStopwatch - _anchorStopwatchElapsed;
    final expectedWallTime = _anchorWallTime.add(elapsedMonotonicSinceAnchor);
    final monotonicSkewSeconds = nowDevice.difference(expectedWallTime).inSeconds;
    if (monotonicSkewSeconds.abs() > 60 && !_isTimeSkewDetected) {
      _anchorWallTime = nowDevice;
      _anchorStopwatchElapsed = currentStopwatch;
      unawaited(syncNetworkTime());
    }

    final manipulated = _cachedOffsetSeconds.abs() > 300;
    _isManipulated = manipulated;
    final tampered = manipulated || _isTimeSkewDetected;
    _isTampered = tampered;
    if (!tampered) {
      _tamperedReason = null;
    }

    if (_lastSyncedNetworkTime != null) {
      final estimatedRealTime = nowDevice.add(Duration(seconds: _cachedOffsetSeconds)).toLocal();
      return SecureTimeResult(
        accurateTime: estimatedRealTime,
        isDeviceTimeManipulated: manipulated,
        isTimeSkewDetected: _isTimeSkewDetected,
        isTampered: tampered,
        offsetSeconds: -_cachedOffsetSeconds,
        source: 'NTP_HTTP',
        warningTag: tampered ? '[JAM DIUBAH MANUAL]' : null,
        reason: _tamperedReason,
      );
    }

    final estimatedRealTime = nowDevice.toLocal();
    return SecureTimeResult(
      accurateTime: estimatedRealTime,
      isDeviceTimeManipulated: manipulated,
      isTimeSkewDetected: _isTimeSkewDetected,
      isTampered: tampered,
      offsetSeconds: _cachedOffsetSeconds,
      source: 'DEVICE_FALLBACK',
      warningTag: tampered ? '[JAM DIUBAH MANUAL]' : null,
      reason: _tamperedReason,
    );
  }

  /// Helper untuk unit testing
  @visibleForTesting
  static void setMockOffset(int offsetSeconds) {
    final now = clock();
    _cachedOffsetSeconds = offsetSeconds;
    _isManipulated = offsetSeconds.abs() > 300;
    _isTampered = _isManipulated;
    _isTimeSkewDetected = false;
    _tamperedReason = _isManipulated ? 'Mock offset $offsetSeconds s' : null;
    _lastSyncedNetworkTime = now.add(Duration(seconds: offsetSeconds));
    _anchorWallTime = now;
    _anchorStopwatchElapsed = _monotonicStopwatch.elapsed;
  }

  /// Helper untuk simulasi clock skew di unit testing
  @visibleForTesting
  static void simulateClockSkew({required int skewSeconds}) {
    final now = clock();
    _anchorWallTime = now.subtract(Duration(seconds: skewSeconds));
    if (skewSeconds < -60 || skewSeconds > 300) {
      _isTimeSkewDetected = true;
      _isTampered = true;
      _tamperedReason = 'Simulated clock skew (${skewSeconds}s)';
    }
  }

  @visibleForTesting
  static void reset() {
    clientOverride = null;
    clock = DateTime.now;
    _lastSyncedNetworkTime = null;
    _cachedOffsetSeconds = 0;
    _isManipulated = false;
    _isTimeSkewDetected = false;
    _isTampered = false;
    _tamperedReason = null;
    _anchorWallTime = clock();
    _anchorStopwatchElapsed = _monotonicStopwatch.elapsed;
  }

  static DateTime? _tryParseHttpDate(String dateStr) {
    try {
      final parts = dateStr.trim().split(' ');
      if (parts.length >= 5) {
        final day = int.tryParse(parts[1]);
        const months = {
          'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
          'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
        };
        final month = months[parts[2]];
        final year = int.tryParse(parts[3]);
        final timeParts = parts[4].split(':');
        if (day != null && month != null && year != null && timeParts.length >= 3) {
          final hour = int.tryParse(timeParts[0]);
          final minute = int.tryParse(timeParts[1]);
          final second = int.tryParse(timeParts[2]);
          if (hour != null && minute != null && second != null) {
            return DateTime.utc(year, month, day, hour, minute, second);
          }
        }
      }
      return DateTime.tryParse(dateStr);
    } catch (_) {
      return null;
    }
  }
}
