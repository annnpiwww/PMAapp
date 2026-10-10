import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/theme_service.dart';
import '../../../data/services/storage_service.dart';

class IosPwaInstallModal extends StatelessWidget {
  const IosPwaInstallModal({super.key});

  static const String _storageKeyDismissed = 'ios_pwa_install_prompt_dismissed';

  /// Memeriksa apakah perangkat adalah iOS di browser Web, dan menampilkan modal jika belum di-dismiss
  static Future<void> checkAndShowPrompt(BuildContext context) async {
    if (!kIsWeb) return;

    // Deteksi platform iOS di Web (iPhone / iPad)
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    if (!isIos) return;

    final dismissed = StorageService.getBool(_storageKeyDismissed) ?? false;
    if (dismissed) return;

    // Berikan sedikit jeda agar halaman kamera/dashboard selesai render sempurna
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!context.mounted) return;

    await show(context);
  }

  /// Menampilkan modal panduan install PWA iPhone
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const IosPwaInstallModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.isDarkMode(context);
    final bgCard = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textTitle = isDark ? Colors.white : const Color(0xFF0F172A);
    final textDesc = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final stepBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final stepBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pill Handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header Banner
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.apple_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Pasang di Layar Utama iPhone',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: textTitle,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PWA iOS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Akses cepat satu ketukan tanpa bilah browser Safari',
                        style: TextStyle(
                          fontSize: 12,
                          color: textDesc,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Step 1
            _buildStepCard(
              stepNumber: '1',
              title: 'Ketuk Tombol Bagikan (Share)',
              description: 'Cari dan ketuk ikon kotak dengan panah ke atas di bilah menu bawah browser Safari iPhone Anda.',
              icon: Icons.ios_share_rounded,
              iconColor: const Color(0xFF3B82F6),
              stepBg: stepBg,
              stepBorder: stepBorder,
              textTitle: textTitle,
              textDesc: textDesc,
            ),
            const SizedBox(height: 10),

            // Step 2
            _buildStepCard(
              stepNumber: '2',
              title: 'Pilih "Tambahkan ke Layar Utama"',
              description: 'Gulir daftar menu ke bawah lalu pilih opsi "Add to Home Screen" (+).',
              icon: Icons.add_box_outlined,
              iconColor: const Color(0xFF10B981),
              stepBg: stepBg,
              stepBorder: stepBorder,
              textTitle: textTitle,
              textDesc: textDesc,
            ),
            const SizedBox(height: 10),

            // Step 3
            _buildStepCard(
              stepNumber: '3',
              title: 'Ketuk "Tambah" (Add)',
              description: 'Ketuk tombol Tambah di sudut kanan atas layar. Ikon aplikasi akan langsung muncul di beranda iPhone Anda.',
              icon: Icons.check_circle_outline_rounded,
              iconColor: AppColors.accent,
              stepBg: stepBg,
              stepBorder: stepBorder,
              textTitle: textTitle,
              textDesc: textDesc,
            ),
            const SizedBox(height: 20),

            // Tombol Aksi
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      StorageService.setBool(_storageKeyDismissed, true);
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Saya Mengerti',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
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
  }

  Widget _buildStepCard({
    required String stepNumber,
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required Color stepBg,
    required Color stepBorder,
    required Color textTitle,
    required Color textDesc,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: stepBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: stepBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(icon, color: iconColor, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$stepNumber. $title',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textTitle,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: textDesc,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
