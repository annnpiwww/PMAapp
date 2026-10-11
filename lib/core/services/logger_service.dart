import 'package:flutter/foundation.dart';

/// Centralized logging service for BssparkingTimeMark
/// Replaces arbitrary print() statements and provides controlled logging in production
class LoggerService {
  LoggerService._();

  static void info(String message, {String? tag, Object? error}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag] ' : '';
      debugPrint('ℹ️ INFO: $prefix$message');
      if (error != null) {
        debugPrint('   Details: $error');
      }
    }
  }

  static void warning(String message, {String? tag, Object? error}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag] ' : '';
      debugPrint('⚠️ WARN: $prefix$message');
      if (error != null) {
        debugPrint('   Details: $error');
      }
    }
  }

  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // In production, errors could be piped to Crashlytics/Sentry if configured
    final prefix = tag != null ? '[$tag] ' : '';
    debugPrint('🚨 ERROR: $prefix$message');
    if (error != null) {
      debugPrint('   Error: $error');
    }
    if (stackTrace != null && kDebugMode) {
      debugPrint('   StackTrace:\n$stackTrace');
    }
  }

  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag] ' : '';
      debugPrint('🐛 DEBUG: $prefix$message');
    }
  }
}
