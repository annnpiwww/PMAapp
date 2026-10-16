import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/share_helper.dart';
import '../../../core/widgets/app_file_image.dart';
import '../../../data/models/daily_task_model.dart';
import '../../maintenance/widgets/photo_preview_dialog.dart';

/// Modal dialog/bottom sheet read-only untuk melihat detail tugas harian yang sudah selesai,
/// melihat foto bukti pengerjaan, dan mengunduh foto bukti ke galeri HP.
class CompletedDailyTaskModal extends StatefulWidget {
  final DailyTaskModel task;

  const CompletedDailyTaskModal({
    super.key,
    required this.task,
  });

  /// Menampilkan modal tugas selesai secara responsif
  static Future<void> show(BuildContext context, DailyTaskModel task) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 600;

    if (isWide) {
      return showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 750),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CompletedDailyTaskModal(task: task),
            ),
          ),
        ),
      );
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: CompletedDailyTaskModal(task: task),
      ),
    );
  }

  @override
  State<CompletedDailyTaskModal> createState() => _CompletedDailyTaskModalState();
}

class _CompletedDailyTaskModalState extends State<CompletedDailyTaskModal> {
  bool _isDownloadingAll = false;
  final Set<String> _downloadingPhotos = {};

  Future<void> _downloadSinglePhoto(String url, int index) async {
    if (_downloadingPhotos.contains(url)) return;

    setState(() => _downloadingPhotos.add(url));
    final messenger = ScaffoldMessenger.of(context);

    try {
      final success = await ShareHelper.savePhotoToGallery(url);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Foto #${index + 1} berhasil disimpan ke Galeri HP (Album: BSS Parking)'
                  : 'Gagal mengunduh Foto #${index + 1}',
            ),
            backgroundColor: success ? AppColors.success : Colors.redAccent,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _downloadingPhotos.remove(url));
      }
    }
  }

  Future<void> _downloadAllPhotos() async {
    if (_isDownloadingAll || widget.task.fotoBuktiUrls.isEmpty) return;

    setState(() => _isDownloadingAll = true);
    final messenger = ScaffoldMessenger.of(context);
    int successCount = 0;

    try {
      for (final url in widget.task.fotoBuktiUrls) {
        final ok = await ShareHelper.savePhotoToGallery(url);
        if (ok) successCount++;
      }

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Berhasil mengunduh $successCount/${widget.task.fotoBuktiUrls.length} foto ke Galeri (Album: BSS Parking)',
            ),
            backgroundColor: successCount > 0 ? AppColors.success : Colors.redAccent,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingAll = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgCard = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderCard = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textHead = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final completedTime = (task.jamSelesai != null && task.jamSelesai!.isNotEmpty)
        ? (task.jamSelesai!.contains('WITA') ? task.jamSelesai! : '${task.jamSelesai} WITA')
        : '-';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle bar untuk drag bottom sheet
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Header Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(
                      'Selesai · $completedTime',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 12, color: textSub),
                    const SizedBox(width: 4),
                    Text(
                      'Read-Only',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: textSub,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close_rounded, color: textSub, size: 22),
                tooltip: 'Tutup',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Scrollable Content
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Judul Tugas
                Text(
                  task.judul,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textHead,
                  ),
                ),
                const SizedBox(height: 12),

                // Card Info Metadata
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderCard),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        icon: Icons.location_on_outlined,
                        label: 'Lokasi',
                        value: '${task.posTag.isNotEmpty ? '${task.posTag} • ' : ''}${task.posName}',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Teknisi',
                        value: task.teknisiNama,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Tanggal',
                        value: task.tanggal,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        icon: Icons.category_outlined,
                        label: 'Kategori',
                        value: task.isMaintenance ? 'SOP Maintenance' : 'Tugas Khusus',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),

                // Deskripsi Tugas (bila ada)
                if (task.deskripsi.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Deskripsi Tugas',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textHead,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: bgCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderCard),
                    ),
                    child: Text(
                      task.deskripsi.trim(),
                      style: TextStyle(fontSize: 12, color: textSub, height: 1.4),
                    ),
                  ),
                ],

                // Catatan Teknisi (bila ada)
                if (task.catatanTeknisi != null &&
                    task.catatanTeknisi!.trim().isNotEmpty &&
                    task.catatanTeknisi != '-') ...[
                  const SizedBox(height: 16),
                  Text(
                    'Catatan Teknisi Saat Penyelesaian',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textHead,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.notes_rounded, size: 16, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            task.catatanTeknisi!.trim(),
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Foto Bukti Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Foto Bukti Pengerjaan (${task.fotoBuktiUrls.length})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textHead,
                      ),
                    ),
                    if (task.fotoBuktiUrls.length > 1)
                      OutlinedButton.icon(
                        onPressed: _isDownloadingAll ? null : _downloadAllPhotos,
                        icon: _isDownloadingAll
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.download_for_offline_rounded, size: 15),
                        label: Text(
                          _isDownloadingAll ? 'Mengunduh...' : 'Unduh Semua',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          side: const BorderSide(color: AppColors.accent),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                if (task.fotoBuktiUrls.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                    decoration: BoxDecoration(
                      color: bgCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderCard),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_outlined, size: 36, color: textSub.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        Text(
                          'Tidak ada lampiran foto bukti pada tugas ini.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: textSub),
                        ),
                      ],
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: task.fotoBuktiUrls.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemBuilder: (ctx, idx) {
                      final photoUrl = task.fotoBuktiUrls[idx];
                      final isDownloading = _downloadingPhotos.contains(photoUrl);

                      return Container(
                        decoration: BoxDecoration(
                          color: bgCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderCard),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Gambar Thumbnail (Bisa di-tap untuk zoom penuh)
                              GestureDetector(
                                onTap: () {
                                  PhotoPreviewDialog.show(
                                    context,
                                    imagePath: photoUrl,
                                    title: '${task.judul} · Foto #${idx + 1}',
                                  );
                                },
                                child: AppFileImage(
                                  path: photoUrl,
                                  fit: BoxFit.cover,
                                  cacheWidth: 600,
                                ),
                              ),

                              // Header Tag di sudut kiri atas
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '#${idx + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),

                              // Bottom action bar overlay (Preview & Download Button)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.85),
                                        Colors.black.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Tombol Buka Preview
                                      InkWell(
                                        onTap: () {
                                          PhotoPreviewDialog.show(
                                            context,
                                            imagePath: photoUrl,
                                            title: '${task.judul} · Foto #${idx + 1}',
                                          );
                                        },
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                                            SizedBox(width: 3),
                                            Text(
                                              'Zoom',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Tombol Download ke Galeri
                                      InkWell(
                                        onTap: isDownloading ? null : () => _downloadSinglePhoto(photoUrl, idx),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.accent,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isDownloading)
                                                const SizedBox(
                                                  width: 10,
                                                  height: 10,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 1.5,
                                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                  ),
                                                )
                                              else
                                                const Icon(Icons.download_rounded, size: 12, color: Colors.white),
                                              const SizedBox(width: 3),
                                              Text(
                                                isDownloading ? '...' : 'Unduh',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final textHead = isDark ? Colors.white : const Color(0xFF0F172A);

    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.accent),
        const SizedBox(width: 8),
        SizedBox(
          width: 65,
          child: Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textSub),
          ),
        ),
        Text(' :  ', style: TextStyle(fontSize: 11, color: textSub)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textHead),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
