import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/constants/tiket_colors.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/widgets/tiket/tiket_band.dart';
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
import '../../maintenance/screens/maintenance_map_screen.dart';
import 'ios_pwa_install_modal.dart';

final Future<PackageInfo> _appPackageInfo = PackageInfo.fromPlatform();

class CameraDrawer extends StatelessWidget {
  final VoidCallback? onRefreshDailyTasksBadge;

  const CameraDrawer({
    super.key,
    this.onRefreshDailyTasksBadge,
  });

  void _confirmLogout(BuildContext context) {
    final colors = TiketColors.of(context);
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: colors.dialog,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: colors.ink, size: 24),
            const SizedBox(width: 8),
            Text(
              'Keluar Akun',
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.ink,
              ),
            ),
          ],
        ),
        content: Text(
          'Yakin ingin keluar akun?',
          style: TextStyle(
            fontFamily: TiketType.fontFamily,
            fontSize: 13,
            color: colors.body,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: Text(
              'Batal',
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                color: colors.body,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              Navigator.of(dCtx).pop();
              nav.pop();
              await AuthRepository.instance.logout();
              nav.pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.danger,
              foregroundColor: colors.white,
              elevation: 0,
              shape: const StadiumBorder(),
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
        final colors = TiketColors.of(context);

        return Drawer(
          width: 310,
          backgroundColor: colors.dialog,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      // Header Band with top-right radius 24 and perforation at bottom edge
                      Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
                            decoration: BoxDecoration(
                              color: colors.band,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(24),
                              ),
                            ),
                            child: Center(
                              child: Image.asset(
                                'foto/bssfotologo_transparent.png',
                                height: 48,
                                fit: BoxFit.contain,
                                errorBuilder: (ctx, err, stack) => const SizedBox(height: 48),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 10,
                            child: ExcludeSemantics(
                              child: CustomPaint(
                                painter: PerforationPainter(canvasColor: colors.dialog),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Menu Khusus SPV: Penugasan Teknisi
                      Builder(builder: (ctx) {
                        final user = AuthRepository.instance.currentUser;
                        final isSpv = user?.role == UserRole.supervisor;
                        if (!isSpv) return const SizedBox.shrink();

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                              title: Row(
                                children: [
                                  Text(
                                    'Penugasan Teknisi',
                                    style: TextStyle(
                                      fontFamily: TiketType.fontFamily,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: colors.ink,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colors.soft,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'SPV',
                                      style: TextStyle(
                                        fontFamily: TiketType.fontFamily,
                                        color: colors.body,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                'Buat tugas dan pantau progres kerja teknisi',
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 12,
                                  color: colors.body,
                                ),
                              ),
                              trailing: Icon(Icons.chevron_right_rounded, size: 20, color: colors.body),
                              onTap: () {
                                Navigator.of(context).pop();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SpvTaskDispatcherScreen(),
                                  ),
                                );
                              },
                            ),
                            Divider(height: 1, thickness: 1, color: colors.hairline, indent: 20, endIndent: 20),
                          ],
                        );
                      }),

                      // Menu Khusus Teknisi: Daily Task
                      Builder(builder: (ctx) {
                        final user = AuthRepository.instance.currentUser;
                        final isTeknisi = user?.role == UserRole.petugas;
                        if (!isTeknisi) return const SizedBox.shrink();

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                              title: Text(
                                'Daily Task',
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: colors.ink,
                                ),
                              ),
                              subtitle: Text(
                                'Daftar tugas harian yang harus dikerjakan',
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 12,
                                  color: colors.body,
                                ),
                              ),
                              trailing: ValueListenableBuilder<int>(
                                valueListenable: DailyTaskService.pendingCountNotifier,
                                builder: (context, pendingCount, _) {
                                  if (pendingCount > 0) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: colors.signal,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$pendingCount',
                                        style: TextStyle(
                                          fontFamily: TiketType.fontFamily,
                                          color: colors.black,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    );
                                  }
                                  return Icon(Icons.chevron_right_rounded, size: 20, color: colors.body);
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
                            ),
                            Divider(height: 1, thickness: 1, color: colors.hairline, indent: 20, endIndent: 20),
                          ],
                        );
                      }),

                      // Menu Khusus Teknisi: Riwayat Maintenance
                      Builder(builder: (ctx) {
                        final allSubmissions = StorageService.getMaintenanceSubmissions() ?? [];
                        final drafts = allSubmissions.where((s) => !s.isComplete).toList();
                        final completed = allSubmissions.where((s) => s.isComplete).toList();
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                              title: Text(
                                'Riwayat Maintenance',
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: colors.ink,
                                ),
                              ),
                              subtitle: Text(
                                drafts.isNotEmpty
                                    ? '${drafts.length} draft aktif • ${completed.length} selesai'
                                    : (completed.isNotEmpty ? '${completed.length} pekerjaan selesai' : 'Daftar checklist unit'),
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 12,
                                  color: colors.body,
                                ),
                              ),
                              trailing: drafts.isNotEmpty
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: colors.soft,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${drafts.length} Draft',
                                        style: TextStyle(
                                          fontFamily: TiketType.fontFamily,
                                          color: colors.body,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    )
                                  : Icon(Icons.chevron_right_rounded, size: 20, color: colors.body),
                              onTap: () {
                                Navigator.of(context).pop();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const MaintenanceHistoryScreen(),
                                  ),
                                );
                              },
                            ),
                            Divider(height: 1, thickness: 1, color: colors.hairline, indent: 20, endIndent: 20),
                          ],
                        );
                      }),

                      // Map Maintenance
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                        title: Text(
                          'Map Maintenance',
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: colors.ink,
                          ),
                        ),
                        subtitle: Text(
                          'Lokasi sudah & belum maintenance',
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 12,
                            color: colors.body,
                          ),
                        ),
                        trailing: Icon(Icons.chevron_right_rounded, size: 20, color: colors.body),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MaintenanceMapScreen(),
                            ),
                          );
                        },
                      ),
                      Divider(height: 1, thickness: 1, color: colors.hairline, indent: 20, endIndent: 20),

                      // Menu Arsip Kehadiran (30 Hari)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                        title: Text(
                          'Arsip Kehadiran',
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: colors.ink,
                          ),
                        ),
                        subtitle: Text(
                          'Catatan absen masuk & pulang 30 hari terakhir',
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 12,
                            color: colors.body,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: colors.soft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '30 Hari',
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colors.body,
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
                      Divider(height: 1, thickness: 1, color: colors.hairline, indent: 20, endIndent: 20),

                      // Pengaturan Tema (Mode Gelap / Terang)
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: ThemeService.themeModeNotifier,
                        builder: (ctx, currentMode, _) {
                          final isCurrentDark = ThemeService.isDarkMode(ctx);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                            title: Text(
                              isCurrentDark ? 'Mode Terang' : 'Mode Gelap',
                              style: TextStyle(
                                fontFamily: TiketType.fontFamily,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: colors.ink,
                              ),
                            ),
                            subtitle: Text(
                              isCurrentDark ? 'Ganti ke tema terang' : 'Ganti ke tema gelap',
                              style: TextStyle(
                                fontFamily: TiketType.fontFamily,
                                fontSize: 12,
                                color: colors.body,
                              ),
                            ),
                            trailing: Switch.adaptive(
                              value: isCurrentDark,
                              activeTrackColor: colors.primary,
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
                      Divider(height: 1, thickness: 1, color: colors.hairline, indent: 20, endIndent: 20),

                      // Panduan Instalasi Layar Utama iPhone (PWA)
                      if (kIsWeb) ...[
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                          title: Text(
                            'Pasang di iPhone (PWA)',
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: colors.ink,
                            ),
                          ),
                          subtitle: Text(
                            'Panduan pasang ke layar utama tanpa URL bar',
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 12,
                              color: colors.body,
                            ),
                          ),
                          trailing: Icon(Icons.chevron_right_rounded, size: 20, color: colors.body),
                          onTap: () {
                            Navigator.of(context).pop();
                            IosPwaInstallModal.show(context);
                          },
                        ),
                        Divider(height: 1, thickness: 1, color: colors.hairline, indent: 20, endIndent: 20),
                      ],

                      const SizedBox(height: 12),

                      // Informasi Akun & Keluar Akun
                      Builder(builder: (ctx) {
                        final user = AuthRepository.instance.currentUser;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: colors.soft,
                            child: Text(
                              (user?.nama.isNotEmpty ?? false) ? user!.nama[0].toUpperCase() : 'U',
                              style: TextStyle(
                                fontFamily: TiketType.fontFamily,
                                fontWeight: FontWeight.w700,
                                color: colors.ink,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          title: Text(
                            user?.nama ?? 'Belum Login',
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: colors.ink,
                            ),
                          ),
                          subtitle: Text(
                            'IT Support ${BranchService.instance.currentBranch.name}',
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 12,
                              color: colors.body,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: Tooltip(
                            message: 'Keluar Akun',
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Center(
                                child: Material(
                                  color: Colors.transparent,
                                  shape: CircleBorder(
                                    side: BorderSide(
                                      color: colors.hairline,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () => _confirmLogout(context),
                                    child: SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: Center(
                                        child: Icon(
                                          Icons.logout_rounded,
                                          size: 20,
                                          color: colors.ink,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          onTap: () => _confirmLogout(context),
                        );
                      }),
                    ],
                  ),
                ),

                // Footer Bottom-Pinned
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: colors.hairline, width: 1.0)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'PMAapp powered by annnpii',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 11.5,
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Project Maintenance Assembly',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 10,
                          color: colors.body,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder<PackageInfo>(
                        future: _appPackageInfo,
                        builder: (context, snap) => Text(
                          snap.hasData
                              ? 'Versi ${snap.data!.version} (${snap.data!.buildNumber})'
                              : 'Versi tidak terbaca',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 11,
                            color: colors.body,
                            fontWeight: FontWeight.w500,
                          ),
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
