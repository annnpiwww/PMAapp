import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/daily_task_model.dart';
import '../repositories/auth_repository.dart';
import 'error_ticket_service.dart';
import 'notification_service.dart';
import 'push_service.dart';
import 'storage_service.dart';

class ErrorAlarmService {
  ErrorAlarmService._();
  static final ErrorAlarmService instance = ErrorAlarmService._();

  static const Duration realarmInterval = Duration(minutes: 2);

  final ValueNotifier<List<DailyTaskModel>> _openErrors =
      ValueNotifier<List<DailyTaskModel>>(<DailyTaskModel>[]);
  final ValueNotifier<bool> _ringing = ValueNotifier<bool>(false);

  ValueListenable<List<DailyTaskModel>> get openErrors => _openErrors;
  ValueListenable<bool> get ringing => _ringing;

  Timer? _timer;
  bool _isTicking = false;

  final Set<String> _notifiedIds = <String>{};
  DateTime? _lastAlarmAt;
  bool _pushRegisteredForUser = false;
  bool _hasUnregisteredLoggedOut = false;

  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  @visibleForTesting
  Future<List<DailyTaskModel>> Function()? fetchOpenOverride;

  @visibleForTesting
  void resetForTesting() {
    _timer?.cancel();
    _timer = null;
    _openErrors.value = <DailyTaskModel>[];
    _ringing.value = false;
    _notifiedIds.clear();
    _lastAlarmAt = null;
    clock = DateTime.now;
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

  /// Periodic or event-driven tick checking unclaimed error tickets and re-alarming every 2 minutes.
  Future<void> tick() async {
    if (_isTicking) return;
    _isTicking = true;
    try {
      final user = AuthRepository.instance.currentUser ?? StorageService.getUser();
      if (user == null) {
        _openErrors.value = <DailyTaskModel>[];
        _ringing.value = false;
        _notifiedIds.clear();
        _lastAlarmAt = null;
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
      _ringing.value = tickets.isNotEmpty;

      if (tickets.isEmpty) {
        _notifiedIds.clear();
        _lastAlarmAt = null;
        await NotificationService.instance.cancelErrorAlarmNotification();
        return;
      }

      final now = clock();
      final currentIds = tickets.map((t) => t.id).toSet();
      final hasNewId = currentIds.any((id) => !_notifiedIds.contains(id));
      final shouldNotify = hasNewId ||
          _lastAlarmAt == null ||
          now.difference(_lastAlarmAt!) >= realarmInterval;

      if (shouldNotify) {
        _notifiedIds.addAll(currentIds);
        await NotificationService.instance.showErrorAlarmNotification(
          openTickets: tickets,
        );
        _lastAlarmAt = now;
      }
    } catch (e) {
      debugPrint('[ErrorAlarmService] tick error: $e');
    } finally {
      _isTicking = false;
    }
  }
}
