import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/services/app_update_service.dart';
import 'screens/mandatory_update_screen.dart';
import 'updater_controller.dart';
import 'widgets/updater_sheet.dart';

/// Coordinates non-blocking startup and throttled resume update checks.
class AppUpdateCoordinator with WidgetsBindingObserver {
  AppUpdateCoordinator({
    AppUpdateService? service,
    DateTime Function()? nowProvider,
  }) : _service = service ?? AppUpdateService.instance,
       _nowProvider = nowProvider ?? DateTime.now;

  static final AppUpdateCoordinator instance = AppUpdateCoordinator();
  static const Duration resumeThrottle = Duration(minutes: 30);

  final AppUpdateService _service;
  final DateTime Function() _nowProvider;

  bool _observerAttached = false;
  bool _checking = false;
  bool _promptShowing = false;
  bool _mandatoryRouteActive = false;
  bool _pendingStartupAfterPopup = false;
  DateTime? _lastCheckedAt;
  int _activePushedCaptureDepth = 0;
  int _activePopupDepth = 0;

  late final NavigatorObserver routeObserver = _UpdaterRouteObserver(this);

  void attachLifecycleObserver() {
    if (_observerAttached || kIsWeb) return;
    _observerAttached = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void detachLifecycleObserver() {
    if (!_observerAttached) return;
    _observerAttached = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(checkOnResume());
  }

  void scheduleStartupCheck({required bool waitForPopupClose}) {
    if (waitForPopupClose) {
      _pendingStartupAfterPopup = true;
      return;
    }
    unawaited(checkOnStartup());
  }

  Future<void> checkOnStartup() => _checkAndPrompt(force: true);

  Future<void> checkOnResume() async {
    final last = _lastCheckedAt;
    if (last != null && _nowProvider().difference(last) < resumeThrottle) {
      return;
    }
    await _checkAndPrompt(force: false);
  }

  Future<void> _checkAndPrompt({required bool force}) async {
    if (kIsWeb || _checking || _promptShowing || _mandatoryRouteActive) return;
    if (!force && (_activePushedCaptureDepth > 0 || _activePopupDepth > 0)) {
      return;
    }

    _checking = true;
    try {
      final result = await _service.checkLatest();
      _lastCheckedAt = _nowProvider();
      if (result == null) return;

      final shouldShow = await _service.shouldPrompt(result);
      if (!shouldShow) return;

      final navState = AuthRepository.navigatorKey.currentState;
      final navContext = AuthRepository.navigatorKey.currentContext;
      if (navState == null || navContext == null || !navContext.mounted) return;

      if (result.mandatory) {
        _mandatoryRouteActive = true;
        final controller = UpdaterController(
          checkResult: result,
          service: _service,
        );
        try {
          await navState.pushAndRemoveUntil<void>(
            MaterialPageRoute(
              settings: const RouteSettings(name: '/updater/mandatory'),
              builder: (_) => MandatoryUpdateScreen(
                controller: controller,
                ownsController: true,
              ),
            ),
            (_) => false,
          );
        } finally {
          _mandatoryRouteActive = false;
        }
        return;
      }

      if (_activePushedCaptureDepth > 0 || _activePopupDepth > 0) return;
      _promptShowing = true;
      final controller = UpdaterController(
        checkResult: result,
        service: _service,
      );
      try {
        await showUpdaterSheet(navContext, controller: controller);
      } finally {
        controller.dispose();
        _promptShowing = false;
      }
    } catch (_) {
      // Never block app flow on update check errors.
    } finally {
      _checking = false;
    }
  }

  void _onRouteChanged(Route<dynamic>? route, bool pushed) {
    if (route is PopupRoute) {
      _activePopupDepth = pushed
          ? _activePopupDepth + 1
          : (_activePopupDepth - 1).clamp(0, 99);
      if (!pushed && _activePopupDepth == 0 && _pendingStartupAfterPopup) {
        _pendingStartupAfterPopup = false;
        unawaited(checkOnStartup());
      }
    }
    final name = route?.settings.name ?? '';
    if (name.contains('capture') || name.contains('sop_camera')) {
      _activePushedCaptureDepth = pushed
          ? _activePushedCaptureDepth + 1
          : (_activePushedCaptureDepth - 1).clamp(0, 99);
    }
  }
}

class _UpdaterRouteObserver extends NavigatorObserver {
  final AppUpdateCoordinator _coordinator;

  _UpdaterRouteObserver(this._coordinator);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _coordinator._onRouteChanged(route, true);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _coordinator._onRouteChanged(route, false);
  }
}
