import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/utils/share_helper.dart';
import '../../../data/models/maintenance_submission.dart';

class PhotoPreviewDialog extends StatelessWidget {
  final String imagePath;
  final String title;
  final MaintenancePointResult? pointResult;
  final VoidCallback? onRetake;

  const PhotoPreviewDialog({
    super.key,
    required this.imagePath,
    required this.title,
    this.pointResult,
    this.onRetake,
  });

  static void show(
    BuildContext context, {
    required String imagePath,
    required String title,
    MaintenancePointResult? pointResult,
    VoidCallback? onRetake,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (_) => PhotoPreviewDialog(
        imagePath: imagePath,
        title: title,
        pointResult: pointResult,
        onRetake: onRetake,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = File(imagePath);
    final exists = file.existsSync();

    final isSesuai = pointResult?.status == PointStatus.sesuai;
    final isTidakSesuai = pointResult?.status == PointStatus.tidakSesuai;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      // Solid Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSesuai
                              ? const Color(0xFF16A34A) // Solid green
                              : (isTidakSesuai ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isSesuai
                              ? '✓ SESUAI SOP'
                              : (isTidakSesuai ? '✕ TIDAK SESUAI' : '⚠ PERLU CEK MANUAL'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.download_rounded, color: Colors.white, size: 22),
                  tooltip: 'Download ke Galeri HP',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final success = await ShareHelper.savePhotoToGallery(imagePath);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(success ? 'Foto berhasil disimpan ke Galeri HP' : 'Gagal menyimpan foto ke Galeri HP'),
                        backgroundColor: success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Uncropped Full-View Image Viewport
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.60,
            ),
            decoration: const BoxDecoration(
              color: Colors.black,
              border: Border(
                left: BorderSide(color: Colors.white24),
                right: BorderSide(color: Colors.white24),
              ),
            ),
            child: exists
                ? ClipRect(
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 1.0,
                      maxScale: 4.5,
                      child: Center(
                        child: Image.file(
                          file,
                          cacheWidth: 1280,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  )
                : const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'File foto tidak ditemukan pada penyimpanan perangkat.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ),
          ),

          // Bottom Action Panel & Compact Note
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Compact Note
                if (pointResult != null && pointResult!.alasan.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Catatan: ${pointResult!.alasan}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Hanya tampilkan tombol Foto Ulang jika status BELUM SESUAI
                if (!isSesuai && onRetake != null) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onRetake!();
                      },
                      icon: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white70),
                      label: const Text(
                        'Foto Ulang',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
