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
  static DateTime? _lastCheckedWallTime;

  static DateTime? _lastSyncedNetworkTime;
  static Duration? _lastSyncedStopwatchElapsed;
  static int _cachedOffsetSeconds = 0;
  static bool _isManipulated = false;
  static bool _isTimeSkewDetected = false;
  static bool _isTampered = false;
  static String? _tamperedReason;

  static bool get isTimeSkewDetected => _isTimeSkewDetected;
  static bool get isTampered => _isTampered || _isManipulated || _isTimeSkewDetected;
  static String? get warningTag => isTampered ? '[JAM DIUBAH MANUAL]' : null;
  static String? get tamperedReason => _tamperedReason;

  /// Sinkronisasi waktu internet (World Time API / Google Date Header)
  static Future<void> syncNetworkTime() async {
    try {
      final client = http.Client();
      final uri = Uri.parse('https://www.google.com/generate_204');
      final response = await client.head(uri).timeout(const Duration(seconds: 3));
      client.close();

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
          final deviceTime = DateTime.now();
          _cachedOffsetSeconds = serverTime.difference(deviceTime).inSeconds;
          // Toleransi perbedaan jam HP vs Server: 300 detik (5 menit)
          _isManipulated = _cachedOffsetSeconds.abs() > 300;
          _lastSyncedNetworkTime = serverTime;
          _lastSyncedStopwatchElapsed = _monotonicStopwatch.elapsed;
          _anchorWallTime = deviceTime;
          _anchorStopwatchElapsed = _monotonicStopwatch.elapsed;
          _lastCheckedWallTime = deviceTime;

          if (_isManipulated) {
            _isTampered = true;
            _tamperedReason = 'Offset server berbeda ${_cachedOffsetSeconds}s (> 300s)';
          }

          debugPrint('[BSS-Security] Time Synced. Offset: ${_cachedOffsetSeconds}s, Manipulated: $_isManipulated');
        }
      }
    } catch (e) {
      debugPrint('[BSS-Security] Sync network time failed: $e');
    }
  }

  /// Mendapatkan waktu terverifikasi anti-fake time & deteksi lonjakan jam (clock skew)
  static SecureTimeResult getVerifiedTime() {
    final nowDevice = DateTime.now();
    final currentStopwatch = _monotonicStopwatch.elapsed;

    // Deteksi Clock Skew via Monotonic Timer:
    // 1. Cek backward jump dibanding pengecekan terakhir (> 60 detik)
    bool backwardJumpDetected = false;
    if (_lastCheckedWallTime != null) {
      final backwardDiff = _lastCheckedWallTime!.difference(nowDevice).inSeconds;
      if (backwardDiff > 60) {
        backwardJumpDetected = true;
      }
    }

    // 2. Cek drift dibanding elapsed monotonic stopwatch sejak anchor
    final elapsedMonotonicSinceAnchor = currentStopwatch - _anchorStopwatchElapsed;
    final expectedWallTime = _anchorWallTime.add(elapsedMonotonicSinceAnchor);
    final monotonicSkewSeconds = nowDevice.difference(expectedWallTime).inSeconds;

    // Melompat mundur (> 60 detik) ATAU melompat maju ekstrem (> 300 detik)
    final bool isBackwardSkew = monotonicSkewSeconds < -60 || backwardJumpDetected;
    final bool isExtremeForwardSkew = monotonicSkewSeconds > 300;

    if (isBackwardSkew || isExtremeForwardSkew) {
      _isTimeSkewDetected = true;
      _isTampered = true;
      _tamperedReason = isBackwardSkew
          ? 'Jam melompat mundur (${monotonicSkewSeconds.abs()}s)'
          : 'Jam melompat maju ekstrem (${monotonicSkewSeconds}s)';
      debugPrint('[BSS-Security] CLOCK SKEW DETECTED! Reason: $_tamperedReason');
    }

    _lastCheckedWallTime = nowDevice;

    // Jika sudah pernah sync dengan server:
    if (_lastSyncedNetworkTime != null && _lastSyncedStopwatchElapsed != null) {
      final elapsedSinceSync = currentStopwatch - _lastSyncedStopwatchElapsed!;
      final estimatedRealTime = _lastSyncedNetworkTime!.add(elapsedSinceSync).toLocal();
      final currentOffset = nowDevice.difference(estimatedRealTime).inSeconds;
      final manipulated = currentOffset.abs() > 300 || _isTimeSkewDetected;

      if (manipulated) {
        _isManipulated = true;
        _isTampered = true;
      }

      final tampered = manipulated || _isTimeSkewDetected;

      return SecureTimeResult(
        accurateTime: estimatedRealTime,
        isDeviceTimeManipulated: manipulated,
        isTimeSkewDetected: _isTimeSkewDetected,
        isTampered: tampered,
        offsetSeconds: currentOffset,
        source: 'NTP_HTTP',
        warningTag: tampered ? '[JAM DIUBAH MANUAL]' : null,
        reason: _tamperedReason,
      );
    }

    // Fallback tanpa network sync:
    // Gunakan anchor wall time + monotonic stopwatch untuk accurateTime
    final estimatedRealTime = _anchorWallTime.add(elapsedMonotonicSinceAnchor).toLocal();
    final manipulated = _isManipulated || _isTimeSkewDetected;

    return SecureTimeResult(
      accurateTime: estimatedRealTime,
      isDeviceTimeManipulated: manipulated,
      isTimeSkewDetected: _isTimeSkewDetected,
      isTampered: manipulated,
      offsetSeconds: monotonicSkewSeconds,
      source: 'DEVICE_FALLBACK',
      warningTag: manipulated ? '[JAM DIUBAH MANUAL]' : null,
      reason: _tamperedReason,
    );
  }

  /// Helper untuk unit testing
  @visibleForTesting
  static void setMockOffset(int offsetSeconds) {
    _cachedOffsetSeconds = offsetSeconds;
    _isManipulated = offsetSeconds.abs() > 300;
    _isTampered = _isManipulated;
    _isTimeSkewDetected = false;
    _tamperedReason = _isManipulated ? 'Mock offset $offsetSeconds s' : null;
    _lastSyncedNetworkTime = DateTime.now().add(Duration(seconds: offsetSeconds));
    _lastSyncedStopwatchElapsed = _monotonicStopwatch.elapsed;
    _anchorWallTime = DateTime.now();
    _anchorStopwatchElapsed = _monotonicStopwatch.elapsed;
    _lastCheckedWallTime = DateTime.now();
  }

  /// Helper untuk simulasi clock skew di unit testing
  @visibleForTesting
  static void simulateClockSkew({required int skewSeconds}) {
    _anchorWallTime = DateTime.now().subtract(Duration(seconds: skewSeconds));
    _lastCheckedWallTime = DateTime.now().subtract(Duration(seconds: skewSeconds));
  }

  @visibleForTesting
  static void reset() {
    _lastSyncedNetworkTime = null;
    _lastSyncedStopwatchElapsed = null;
    _cachedOffsetSeconds = 0;
    _isManipulated = false;
    _isTimeSkewDetected = false;
    _isTampered = false;
    _tamperedReason = null;
    _anchorWallTime = DateTime.now();
    _anchorStopwatchElapsed = _monotonicStopwatch.elapsed;
    _lastCheckedWallTime = _anchorWallTime;
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
