import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/theme_service.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/branch_service.dart';
import '../../../data/services/daily_task_service.dart';
import '../../../data/services/storage_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../daily_tasks/screens/spv_task_dispatcher_screen.dart';
import '../../daily_tasks/screens/teknisi_daily_tasks_screen.dart';
import '../../history/screens/attendance_archive_screen.dart';
import '../../maintenance/screens/maintenance_history_screen.dart';
import 'ios_pwa_install_modal.dart';

/// Navigation Drawer for CameraCaptureScreen
class CameraDrawer extends StatelessWidget {
  final VoidCallback? onRefreshDailyTasksBadge;

  const CameraDrawer({
    super.key,
    this.onRefreshDailyTasksBadge,
  });

  void _confirmLogout(BuildContext context) {
    final isDark = ThemeService.isDarkMode(context);
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusCard)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: AppColors.danger, size: 24),
            const SizedBox(width: 8),
            Text(
              'Keluar Akun',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Yakin ingin keluar akun?',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              Navigator.of(dCtx).pop();
              nav.pop(); // Tutup drawer
              await AuthRepository.instance.logout();
              nav.pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, currentMode, _) {
        final isDark = ThemeService.isDarkMode(context);
        final drawerBg = isDark ? AppColors.darkSurface : Colors.white;
        final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textPrimary;
        final textSecondary = isDark ? AppColors.textDarkSecondary : AppColors.textSecondary;
        final dividerColor = isDark ? AppColors.darkBorder : AppColors.cardBorder;

        return Drawer(
          width: 310,
          backgroundColor: drawerBg,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      // Drawer Header with Pure Transparent Logo on Blue Background
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          border: Border(
                            bottom: BorderSide(color: AppColors.accent, width: 2.5),
                          ),
                        ),
                        child: Center(
                          child: Image.asset(
                            'foto/bssfotologo_transparent.png',
                            height: 48,
                            fit: BoxFit.contain,
                            errorBuilder: (ctx, err, stack) => const Text(
                              'BSS PARKING',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Menu Khusus SPV: Penugasan Teknisi
                      Builder(builder: (ctx) {
                        final user = AuthRepository.instance.currentUser;
                        final isSpv = user?.role == UserRole.supervisor;
                        if (!isSpv) return const SizedBox.shrink();

                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.assignment_ind_rounded, color: AppColors.accent, size: 22),
                          ),
                          title: Row(
                            children: [
                              Text(
                                'Penugasan Teknisi',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textPrimary),
                              ),
                              const SizedBox(width: 6),
                              const Chip(
                                label: Text('SPV', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                                backgroundColor: AppColors.accent,
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'Buat tugas dan pantau progres kerja teknisi',
                            style: TextStyle(fontSize: 11, color: textSecondary),
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SpvTaskDispatcherScreen(),
                              ),
                            );
                          },
                        );
                      }),

                      // Menu Khusus Teknisi: Daily Task
                      Builder(builder: (ctx) {
                        final user = AuthRepository.instance.currentUser;
                        final isTeknisi = user?.role == UserRole.petugas;
                        if (!isTeknisi) return const SizedBox.shrink();

                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.assignment_turned_in_rounded, color: AppColors.accent, size: 22),
                          ),
                          title: Text(
                            'Daily Task',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textPrimary),
                          ),
                          subtitle: Text(
                            'Daftar tugas harian yang harus dikerjakan',
                            style: TextStyle(fontSize: 11, color: textSecondary),
                          ),
                          trailing: ValueListenableBuilder<int>(
                            valueListenable: DailyTaskService.pendingCountNotifier,
                            builder: (context, pendingCount, _) {
                              if (pendingCount > 0) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$pendingCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                );
                              }
                              return const Icon(Icons.chevron_right_rounded, size: 20);
                            },
                          ),
                          onTap: () async {
                            Navigator.of(context).pop();
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const TeknisiDailyTasksScreen(),
                              ),
                            );
                            onRefreshDailyTasksBadge?.call();
                          },
                        );
                      }),

                      // Menu Khusus Teknisi: Riwayat Maintenance
                      Builder(builder: (ctx) {
                        final allSubmissions = StorageService.getMaintenanceSubmissions() ?? [];
                        final drafts = allSubmissions.where((s) => !s.isComplete).toList();
                        final completed = allSubmissions.where((s) => s.isComplete).toList();
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.handyman_rounded, color: AppColors.primary, size: 22),
                          ),
                          title: Text(
                            'Riwayat Maintenance',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textPrimary),
                          ),
                          subtitle: Text(
                            drafts.isNotEmpty
                                ? '${drafts.length} draft aktif • ${completed.length} selesai'
                                : (completed.isNotEmpty ? '${completed.length} pekerjaan selesai' : 'Daftar checklist unit'),
                            style: TextStyle(fontSize: 11, color: textSecondary),
                          ),
                          trailing: drafts.isNotEmpty
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${drafts.length} Draft',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                )
                              : Icon(Icons.chevron_right_rounded, size: 20, color: textSecondary),
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const MaintenanceHistoryScreen(),
                              ),
                            );
                          },
                        );
                      }),

                      // Menu Arsip Kehadiran (30 Hari)
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.25 : 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.folder_shared_rounded, color: Color(0xFF0284C7), size: 22),
                        ),
                        title: Text(
                          'Arsip Kehadiran',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textPrimary),
                        ),
                        subtitle: Text('Catatan absen masuk & pulang 30 hari terakhir', style: TextStyle(fontSize: 11, color: textSecondary)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF082F49) : const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? const Color(0xFF0284C7) : const Color(0xFFBAE6FD)),
                          ),
                          child: Text(
                            '30 Hari',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AttendanceArchiveScreen(),
                            ),
                          );
                        },
                      ),

                      // Pengaturan Tema (Mode Gelap / Terang)
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: ThemeService.themeModeNotifier,
                        builder: (ctx, currentMode, _) {
                          final isCurrentDark = ThemeService.isDarkMode(ctx);
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isCurrentDark ? const Color(0xFFF59E0B) : const Color(0xFF1E448D)).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isCurrentDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                color: isCurrentDark ? const Color(0xFFF59E0B) : const Color(0xFF1E448D),
                                size: 22,
                              ),
                            ),
                            title: Text(
                              isCurrentDark ? 'Mode Terang' : 'Mode Gelap',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textPrimary),
                            ),
                            subtitle: Text(
                              isCurrentDark ? 'Ganti ke tema terang' : 'Ganti ke tema gelap',
                              style: TextStyle(fontSize: 11, color: textSecondary),
                            ),
                            trailing: Switch.adaptive(
                              value: isCurrentDark,
                              activeTrackColor: AppColors.accent,
                              onChanged: (_) {
                                ThemeService.toggleTheme(context);
                              },
                            ),
                            onTap: () {
                              ThemeService.toggleTheme(context);
                            },
                          );
                        },
                      ),

                      // Panduan Instalasi Layar Utama iPhone (PWA)
                      if (kIsWeb)
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.25 : 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.apple_rounded, color: Color(0xFF3B82F6), size: 22),
                          ),
                          title: Text(
                            'Pasang di iPhone (PWA)',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textPrimary),
                          ),
                          subtitle: Text(
                            'Panduan pasang ke layar utama tanpa URL bar',
                            style: TextStyle(fontSize: 11, color: textSecondary),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                          onTap: () {
                            Navigator.of(context).pop();
                            IosPwaInstallModal.show(context);
                          },
                        ),

                      Divider(height: 24, color: dividerColor),

                      // Informasi Akun & Modal Konfirmasi Keluar Akun
                      Builder(builder: (ctx) {
                        final user = AuthRepository.instance.currentUser;
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                            child: Text(
                              (user?.nama.isNotEmpty ?? false) ? user!.nama[0].toUpperCase() : 'U',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent, fontSize: 16),
                            ),
                          ),
                          title: Text(
                            user?.nama ?? 'Belum Login',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textPrimary),
                          ),
                          subtitle: Text(
                            'IT Support ${BranchService.instance.currentBranch.name}',
                            style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.logout_rounded, size: 20, color: AppColors.danger),
                            tooltip: 'Keluar Akun',
                            onPressed: () => _confirmLogout(context),
                          ),
                          onTap: () => _confirmLogout(context),
                        );
                      }),
                    ],
                  ),
                ),

                // Footer Paling Bawah Center (Bottom-Pinned)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: dividerColor, width: 0.8)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'PMAapp powered by annnpii',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFF38BDF8) : AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Project Maintenance Assembly',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 10,
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
