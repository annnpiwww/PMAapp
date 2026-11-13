import 'package:flutter/material.dart';
import '../../core/constants/tiket_colors.dart';
import '../../data/models/daily_task_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/daily_task_service.dart';
import '../../data/services/error_alarm_service.dart';
import '../../data/services/error_ticket_service.dart';
import '../maintenance/screens/maintenance_map_screen.dart';
import 'screens/custom_task_execution_screen.dart';
import 'screens/teknisi_daily_tasks_screen.dart';

class ErrorTicketLauncher {
  ErrorTicketLauncher._();

  /// Sentinel: `null` means nothing pending, `''` means open newest open ticket.
  static String? pendingTaskId;
  static bool _isOpening = false;

  static String? taskIdFromPayload(String? payload) {
    if (payload == null) return null;
    if (payload == 'error_alarm') return '';
    if (payload.startsWith('error_alarm:')) {
      return payload.substring('error_alarm:'.length).trim();
    }
    return null;
  }

  static Future<DailyTaskModel?> ensureClaimed(
    DailyTaskModel task,
    String userNama, {
    void Function(String pesan, bool sukses)? onMessage,
    bool onlyError = true,
  }) async {
    if ((onlyError && task.kategori != 'error') ||
        !task.isOpenHandover ||
        DailyTaskService.isAssignedTo(task, userNama)) {
      return task;
    }

    final res = await DailyTaskService.claimTask(
      task: task,
      olehSiapa: userNama,
    );
    if (res.success) {
      final cached = DailyTaskService.getCachedTasksLocally();
      for (final item in cached) {
        if (item.id == task.id) return item;
      }
      return task.copyWith(teknisiNama: userNama);
    }

    if (res.isTaken) {
      onMessage?.call(
        res.message ?? 'Tiket sudah diambil ${res.claimedBy ?? 'teknisi lain'}',
        false,
      );
      return null;
    }

    onMessage?.call(
      'Gagal mengambil tiket, cek sinyal lalu coba lagi.',
      false,
    );
    return null;
  }

  static Future<void> openById(String? taskId) async {
    final nav = AuthRepository.navigatorKey.currentState;
    final user = AuthRepository.instance.currentUser;
    final cleanId = taskId?.trim() ?? '';
    if (nav == null || user == null) {
      pendingTaskId = cleanId;
      return;
    }

    if (_isOpening) return;
    _isOpening = true;
    try {
      await ErrorAlarmService.instance.acknowledge();

      if (user.role != UserRole.petugas) {
        AuthRepository.navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const MaintenanceMapScreen()),
        );
        return;
      }

      final hasSpecificId = cleanId.isNotEmpty;
      final tickets = await ErrorTicketService.fetchOpen();
      DailyTaskModel? target;

      if (hasSpecificId) {
        for (final t in tickets) {
          if (t.id == cleanId) {
            target = t;
            break;
          }
        }
        if (target == null) {
          final cached = DailyTaskService.getCachedTasksLocally();
          for (final t in cached) {
            if (t.id == cleanId &&
                !t.isCompleted &&
                DailyTaskService.isAssignedTo(t, user.nama)) {
              target = t;
              break;
            }
          }
        }
      } else if (tickets.isNotEmpty) {
        target = tickets.first;
      }

      if (target == null) {
        AuthRepository.navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const TeknisiDailyTasksScreen()),
        );
        if (hasSpecificId) {
          _showSnack('Tiket sudah ditangani teknisi lain.', sukses: false);
        }
        return;
      }

      final claimed = await ensureClaimed(
        target,
        user.nama,
        onMessage: (pesan, sukses) => _showSnack(pesan, sukses: sukses),
      );
      if (claimed == null) {
        AuthRepository.navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const TeknisiDailyTasksScreen()),
        );
        return;
      }

      AuthRepository.navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => CustomTaskExecutionScreen(task: claimed)),
      );
    } finally {
      _isOpening = false;
    }
  }

  static Future<void> consumePending() async {
    final id = pendingTaskId;
    if (id == null) return;
    pendingTaskId = null;
    await openById(id);
  }

  static void _showSnack(String pesan, {bool sukses = false}) {
    final messenger = AuthRepository.scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    final ctx = AuthRepository.navigatorKey.currentContext;
    final bg = ctx != null
        ? (sukses ? TiketColors.of(ctx).ok : TiketColors.of(ctx).danger)
        : (sukses ? const Color(0xFF10B981) : const Color(0xFFEF4444));
    messenger.showSnackBar(
      SnackBar(
        content: Text(pesan),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
