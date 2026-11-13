import 'dart:async';
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
      unawaited(ErrorAlarmService.instance.tick());
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

      final confirmed = await _confirmKerjakan(target);
      if (confirmed != true) return;

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

      unawaited(ErrorAlarmService.instance.tick());
      AuthRepository.navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => CustomTaskExecutionScreen(task: claimed)),
      );
    } finally {
      _isOpening = false;
    }
  }

  static Future<bool?> _confirmKerjakan(DailyTaskModel task) {
    final ctx = AuthRepository.navigatorKey.currentContext;
    if (ctx == null) return Future<bool?>.value(false);
    final pos = task.posName.trim().isNotEmpty ? task.posName.trim() : task.posTag.trim();
    return showModalBottomSheet<bool>(
      context: ctx,
      isScrollControlled: false,
      showDragHandle: true,
      backgroundColor: TiketColors.of(ctx).dialog,
      builder: (sheetCtx) {
        final c = TiketColors.of(sheetCtx);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: c.danger),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Tiket error',
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.danger,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  pos.isNotEmpty ? pos : 'Lokasi',
                  style: TextStyle(
                    fontFamily: TiketType.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.judul,
                  style: TextStyle(
                    fontFamily: TiketType.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: c.body,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(sheetCtx).pop(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.ink,
                            side: BorderSide(color: c.hairline),
                          ),
                          child: const Text(
                            'Nanti',
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: () => Navigator.of(sheetCtx).pop(true),
                          style: FilledButton.styleFrom(
                            backgroundColor: c.primary,
                            foregroundColor: c.onPrimary,
                          ),
                          child: const Text(
                            'Kerjakan',
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
