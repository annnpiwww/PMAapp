import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_task_model.dart';
import '../repositories/auth_repository.dart';
import 'error_ticket_service.dart';
import 'notification_service.dart';
import 'push_service.dart';
import 'storage_service.dart';

class ErrorAlarmService {
  ErrorAlarmService._();
  static final ErrorAlarmService instance = ErrorAlarmService._();

  static const String prefsKeyAcknowledged = 'bss_error_alarm_ack_v1';

  final ValueNotifier<List<DailyTaskModel>> _openErrors =
      ValueNotifier<List<DailyTaskModel>>(<DailyTaskModel>[]);
  final ValueNotifier<bool> _ringing = ValueNotifier<bool>(false);

  ValueListenable<List<DailyTaskModel>> get openErrors => _openErrors;
  ValueListenable<bool> get ringing => _ringing;

  Timer? _timer;
  bool _isTicking = false;

  final Set<String> _notifiedUnacknowledgedIds = <String>{};
  bool _pushRegisteredForUser = false;
  bool _hasUnregisteredLoggedOut = false;

  @visibleForTesting
  Future<List<DailyTaskModel>> Function()? fetchOpenOverride;

  @visibleForTesting
  void resetForTesting() {
    _timer?.cancel();
    _timer = null;
    _openErrors.value = <DailyTaskModel>[];
    _ringing.value = false;
    _notifiedUnacknowledgedIds.clear();
    _pushRegisteredForUser = false;
    _hasUnregisteredLoggedOut = false;
    _isTicking = false;
    fetchOpenOverride = null;
  }

  /// Start the periodic error alarm poller (idempotent: Timer.periodic 25s + immediate tick).
  void start() {
    if (_timer != null) return;
    unawaited(tick());
    _timer = Timer.periodic(const Duration(seconds: 25), (_) {
      unawaited(tick());
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Stops sound: cancels alarm notification, adds current open ticket IDs to the acknowledged set, ringing=false.
  Future<void> acknowledge() async {
    _ringing.value = false;
    await NotificationService.instance.cancelErrorAlarmNotification();

    final currentIds = _openErrors.value.map((t) => t.id).toSet();
    final prefs = await SharedPreferences.getInstance();
    final existingAck = (prefs.getStringList(prefsKeyAcknowledged) ?? []).toSet();
    existingAck.addAll(currentIds);
    await prefs.setStringList(prefsKeyAcknowledged, existingAck.toList());
  }

  /// Periodic or event-driven tick checking open error tickets and ringing alarm if unacknowledged.
  Future<void> tick() async {
    if (_isTicking) return;
    _isTicking = true;
    try {
      final user = AuthRepository.instance.currentUser ?? StorageService.getUser();
      if (user == null) {
        _openErrors.value = <DailyTaskModel>[];
        _ringing.value = false;
        _notifiedUnacknowledgedIds.clear();
        await NotificationService.instance.cancelErrorAlarmNotification();
        if (_pushRegisteredForUser || !_hasUnregisteredLoggedOut) {
          _pushRegisteredForUser = false;
          _hasUnregisteredLoggedOut = true;
          await PushService.unregister();
        }
        return;
      }

      _hasUnregisteredLoggedOut = false;
      _pushRegisteredForUser = true;
      await PushService.ensureRegistered(
        name: user.nama,
        cabang: user.cabangName,
        role: user.role.name,
      );

      final tickets = fetchOpenOverride != null
          ? await fetchOpenOverride!()
          : await ErrorTicketService.fetchOpen();

      _openErrors.value = tickets;

      if (tickets.isEmpty) {
        _ringing.value = false;
        _notifiedUnacknowledgedIds.clear();
        await NotificationService.instance.cancelErrorAlarmNotification();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(prefsKeyAcknowledged, <String>[]);
        return;
      }

      final currentOpenIds = tickets.map((t) => t.id).toSet();
      final prefs = await SharedPreferences.getInstance();
      final storedAck = (prefs.getStringList(prefsKeyAcknowledged) ?? []).toSet();

      // Prune IDs no longer open each tick
      final prunedAck = storedAck.intersection(currentOpenIds);
      if (prunedAck.length != storedAck.length) {
        await prefs.setStringList(prefsKeyAcknowledged, prunedAck.toList());
      }

      // ringing = any open id not acknowledged
      final unacknowledgedIds = currentOpenIds.difference(prunedAck);

      if (unacknowledgedIds.isEmpty) {
        _ringing.value = false;
        _notifiedUnacknowledgedIds.clear();
        await NotificationService.instance.cancelErrorAlarmNotification();
      } else {
        _ringing.value = true;
        // Notify only on transition to a NEW unacknowledged id
        final hasNewUnacknowledged =
            unacknowledgedIds.any((id) => !_notifiedUnacknowledgedIds.contains(id));
        if (hasNewUnacknowledged) {
          _notifiedUnacknowledgedIds.addAll(unacknowledgedIds);
          await NotificationService.instance.showErrorAlarmNotification(
            openTickets: tickets,
          );
        }
      }
    } catch (e) {
      debugPrint('[ErrorAlarmService] tick error: $e');
    } finally {
      _isTicking = false;
    }
  }
}
