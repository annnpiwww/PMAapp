import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/auth_repository.dart';
import '../../features/daily_tasks/error_ticket_launcher.dart';
import 'daily_task_service.dart';
import 'error_alarm_service.dart';
import 'notification_service.dart';

/// Top-level background message handler invoked by FirebaseMessaging in background isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) return;
  try {
    if (message.data['type'] == 'error_alarm') {
      final posName = message.data['pos_name']?.toString().trim() ?? '';
      final judul = message.data['judul']?.toString().trim() ?? '';
      final title = posName.isEmpty ? 'Lokasi error' : 'Lokasi error: $posName';
      final body = judul.isEmpty ? 'Tiket error baru' : judul;
      final taskId = message.data['task_id']?.toString().trim() ?? '';

      await NotificationService.instance.showDirectErrorAlarmNotification(
        title: title,
        body: body,
        taskId: taskId,
      );
    }
  } catch (e) {
    debugPrint('[PushService] Background message handler error: $e');
  }
}

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const String prefsKeyLastToken = 'bss_push_last_registered_token_v1';
  static const String prefsKeyLastName = 'bss_push_last_registered_name_v1';

  bool _isInitialized = false;
  String? _currentToken;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;

  @visibleForTesting
  http.Client? httpClient;

  @visibleForTesting
  Future<void> Function()? firebaseInitOverride;

  @visibleForTesting
  Future<String?> Function()? tokenFetcherOverride;

  @visibleForTesting
  void Function(RemoteMessage)? foregroundMessageHandlerOverride;

  @visibleForTesting
  String? get currentToken => _currentToken;

  @visibleForTesting
  void setTokenForTesting(String? token) {
    _currentToken = token;
  }

  @visibleForTesting
  void resetForTesting() {
    _isInitialized = false;
    _currentToken = null;
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _onMessageSub?.cancel();
    _onMessageSub = null;
    _onMessageOpenedAppSub?.cancel();
    _onMessageOpenedAppSub = null;
    httpClient = null;
    firebaseInitOverride = null;
    tokenFetcherOverride = null;
    foregroundMessageHandlerOverride = null;
  }

  /// Initialize Firebase app & messaging listeners.
  /// Guarded with kIsWeb and try-catch so it never blocks startup.
  static Future<void> init() => instance.initialize();

  Future<void> initialize() async {
    if (kIsWeb) return;
    if (_isInitialized) return;

    try {
      if (firebaseInitOverride != null) {
        await firebaseInitOverride!();
      } else {
        await Firebase.initializeApp();
      }

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      _onMessageSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (foregroundMessageHandlerOverride != null) {
          foregroundMessageHandlerOverride!(message);
          return;
        }
        if (message.data['type'] == 'error_alarm') {
          unawaited(ErrorAlarmService.instance.tick());
        }
      });

      _onMessageOpenedAppSub =
          FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleOpenedMessage(initialMessage);
      }

      _tokenRefreshSub = messaging.onTokenRefresh.listen((String newToken) {
        _currentToken = newToken;
        unawaited(_handleTokenRefresh(newToken));
      });

      _isInitialized = true;
      debugPrint('[PushService] Initialized successfully.');
    } catch (e) {
      debugPrint('[PushService] Initialization failed (non-blocking): $e');
    }
  }

  void _handleOpenedMessage(RemoteMessage message) {
    if (message.data['type'] == 'error_alarm') {
      final taskId = message.data['task_id']?.toString().trim() ?? '';
      unawaited(ErrorTicketLauncher.openById(taskId));
    }
  }

  Future<String?> _getToken() async {
    if (tokenFetcherOverride != null) {
      return await tokenFetcherOverride!();
    }
    if (kIsWeb) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('[PushService] Error fetching FCM token: $e');
      return null;
    }
  }

  Future<void> _handleTokenRefresh(String newToken) async {
    final user = AuthRepository.instance.currentUser;
    if (user != null) {
      await ensureRegistered(
        name: user.nama,
        cabang: user.cabangName,
        role: user.role.name,
      );
    }
  }

  /// Register current FCM token with backend idempotently per token and user name.
  static Future<void> ensureRegistered({
    required String name,
    required String cabang,
    required String role,
  }) =>
      instance.ensureRegisteredInternal(
        name: name,
        cabang: cabang,
        role: role,
      );

  Future<void> ensureRegisteredInternal({
    required String name,
    required String cabang,
    required String role,
  }) async {
    if (kIsWeb) return;
    try {
      final token = _currentToken ?? await _getToken();
      if (token == null || token.trim().isEmpty) return;
      _currentToken = token;

      final prefs = await SharedPreferences.getInstance();
      final lastToken = prefs.getString(prefsKeyLastToken);
      final lastName = prefs.getString(prefsKeyLastName);

      if (token == lastToken && name.trim() == lastName) {
        // Idempotent: already registered for this device & user
        return;
      }

      final success = await _callRegisterEndpoint(
        token: token.trim(),
        platform: 'android',
      );

      if (success) {
        await prefs.setString(prefsKeyLastToken, token);
        await prefs.setString(prefsKeyLastName, name.trim());
        debugPrint('[PushService] Successfully registered push token for $name ($cabang)');
      }
    } catch (e) {
      debugPrint('[PushService] ensureRegistered error: $e');
    }
  }

  /// Unregister current token from backend on logout.
  static Future<void> unregister() => instance.unregisterInternal();

  Future<void> unregisterInternal() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = _currentToken ?? prefs.getString(prefsKeyLastToken) ?? await _getToken();
      if (token != null && token.trim().isNotEmpty) {
        await _callUnregisterEndpoint(token: token.trim());
      }
      await prefs.remove(prefsKeyLastToken);
      await prefs.remove(prefsKeyLastName);
      debugPrint('[PushService] Push token unregistered.');
    } catch (e) {
      debugPrint('[PushService] unregister error: $e');
    }
  }

  Map<String, String> _buildHeaders() {
    final sessionToken = AuthRepository.instance.sessionToken;
    return {
      'Content-Type': 'application/json',
      'apikey': DailyTaskService.anonKey,
      'Authorization': 'Bearer ${DailyTaskService.anonKey}',
      if (sessionToken != null && sessionToken.isNotEmpty) 'x-app-session': sessionToken,
    };
  }

  Future<bool> _callRegisterEndpoint({
    required String token,
    required String platform,
  }) async {
    final client = httpClient ?? http.Client();
    final url = Uri.parse('${DailyTaskService.baseUrl}/functions/v1/push-register');
    try {
      final res = await client.post(
        url,
        headers: _buildHeaders(),
        body: jsonEncode({
          'token': token,
          'platform': platform,
        }),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('[PushService] _callRegisterEndpoint error: $e');
      return false;
    } finally {
      if (httpClient == null) {
        client.close();
      }
    }
  }

  Future<bool> _callUnregisterEndpoint({
    required String token,
  }) async {
    final client = httpClient ?? http.Client();
    final url = Uri.parse('${DailyTaskService.baseUrl}/functions/v1/push-register');
    try {
      final res = await client.delete(
        url,
        headers: _buildHeaders(),
        body: jsonEncode({
          'token': token,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[PushService] _callUnregisterEndpoint error: $e');
      return false;
    } finally {
      if (httpClient == null) {
        client.close();
      }
    }
  }
}
