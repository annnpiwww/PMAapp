import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/tiket_colors.dart';
import '../../../core/utils/share_helper.dart';
import '../../../core/widgets/app_file_image.dart';
import '../../../core/widgets/tiket/tiket.dart';
import '../../../data/models/daily_task_model.dart';
import '../../maintenance/widgets/photo_preview_dialog.dart';

class CompletedDailyTaskModal extends StatefulWidget {
  final DailyTaskModel task;

  const CompletedDailyTaskModal({
    super.key,
    required this.task,
  });

  static Future<void> show(BuildContext context, DailyTaskModel task) {
    final colors = TiketColors.of(context);
    final isWide = MediaQuery.of(context).size.width > 600;

    if (isWide) {
      return showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: colors.dialog,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 750),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
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
          color: colors.dialog,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
    final colors = TiketColors.of(context);

    try {
      final success = await ShareHelper.savePhotoToGallery(url);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? (kIsWeb
                      ? 'Foto #${index + 1} diunduh ke Files/Downloads (bukan Galeri)'
                      : 'Foto #${index + 1} tersimpan di Galeri HP (Album: BSS Parking)')
                  : 'Gagal mengunduh Foto #${index + 1}',
            ),
            backgroundColor: success ? colors.ok : colors.danger,
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
    final colors = TiketColors.of(context);
    int successCount = 0;

    try {
      for (int i = 0; i < widget.task.fotoBuktiUrls.length; i++) {
        final url = widget.task.fotoBuktiUrls[i];
        try {
          final ok = await ShareHelper.savePhotoToGallery(url);
          if (ok) successCount++;
        } catch (_) {}
      }

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              successCount > 0
                  ? (kIsWeb
                      ? 'Berhasil mengunduh $successCount/${widget.task.fotoBuktiUrls.length} foto ke folder Downloads'
                      : 'Berhasil mengunduh $successCount/${widget.task.fotoBuktiUrls.length} foto ke Galeri (Album: BSS Parking)')
                  : 'Gagal mengunduh foto bukti. Periksa izin penyimpanan.',
            ),
            backgroundColor: successCount > 0 ? colors.ok : colors.danger,
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

  Future<void> _openVideo(String videoUrl) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final uri = Uri.parse(videoUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Gagal membuka video.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Gagal membuka video.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final task = widget.task;

    final completedTime = (task.jamSelesai != null && task.jamSelesai!.isNotEmpty)
        ? (task.jamSelesai!.contains('WITA') ? task.jamSelesai! : '${task.jamSelesai} WITA')
        : '-';

    final videoList = task.fotoBuktiUrls.where((url) {
      final lower = url.toLowerCase();
      return lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.mkv');
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.hairline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              StatusChip(
                label: 'Selesai · $completedTime',
                kind: TiketChipKind.ok,
              ),
              const SizedBox(width: 8),
              const StatusChip(
                label: 'Read-Only',
                kind: TiketChipKind.neutral,
              ),
              const Spacer(),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  icon: Icon(Icons.close_rounded, color: colors.ink, size: 22),
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: colors.hairline),

        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.judul,
                  style: TextStyle(
                    fontFamily: TiketType.fontFamily,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: colors.ink,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 16),

                _buildInfoRow(
                  label: 'Lokasi',
                  value: '${task.posTag.isNotEmpty ? '${task.posTag} • ' : ''}${task.posName}',
                  colors: colors,
                ),
                Divider(height: 24, thickness: 1, color: colors.hairline),
                _buildInfoRow(
                  label: 'Teknisi',
                  value: task.teknisiNama,
                  colors: colors,
                ),
                Divider(height: 24, thickness: 1, color: colors.hairline),
                _buildInfoRow(
                  label: 'Tanggal',
                  value: task.tanggal,
                  colors: colors,
                ),
                Divider(height: 24, thickness: 1, color: colors.hairline),
                _buildInfoRow(
                  label: 'Kategori',
                  value: task.isMaintenance ? 'SOP Maintenance' : 'Tugas Khusus',
                  colors: colors,
                ),
                Divider(height: 24, thickness: 1, color: colors.hairline),

                if (task.deskripsi.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Deskripsi Tugas',
                    style: TextStyle(
                      fontFamily: TiketType.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    task.deskripsi.trim(),
                    style: TextStyle(
                      fontFamily: TiketType.fontFamily,
                      fontSize: 13,
                      color: colors.body,
                      height: 1.4,
                    ),
                  ),
                  Divider(height: 24, thickness: 1, color: colors.hairline),
                ],

                if (task.catatanTeknisi != null &&
                    task.catatanTeknisi!.trim().isNotEmpty &&
                    task.catatanTeknisi != '-') ...[
                  const SizedBox(height: 16),
                  Text(
                    'Catatan Teknisi Saat Penyelesaian',
                    style: TextStyle(
                      fontFamily: TiketType.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    task.catatanTeknisi!.trim(),
                    style: TextStyle(
                      fontFamily: TiketType.fontFamily,
                      fontSize: 13,
                      color: colors.body,
                      height: 1.4,
                    ),
                  ),
                  Divider(height: 24, thickness: 1, color: colors.hairline),
                ],

                const SizedBox(height: 22),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Foto Bukti Pengerjaan (${task.fotoBuktiUrls.length})',
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                        ),
                      ),
                    ),
                    if (task.fotoBuktiUrls.length > 1) ...[
                      const SizedBox(width: 8),
                      TiketPill(
                        label: _isDownloadingAll ? 'Mengunduh...' : 'Unduh Semua',
                        kind: TiketPillKind.secondary,
                        height: 38,
                        icon: _isDownloadingAll ? null : Icons.download_rounded,
                        onPressed: _isDownloadingAll ? null : _downloadAllPhotos,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                if (task.fotoBuktiUrls.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                    decoration: BoxDecoration(
                      color: colors.soft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.hairline),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_outlined, size: 36, color: colors.mute),
                        const SizedBox(height: 10),
                        Text(
                          'Tidak ada lampiran foto bukti pada tugas ini.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 13,
                            color: colors.body,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: task.fotoBuktiUrls.length,
                    itemBuilder: (context, index) {
                      final url = task.fotoBuktiUrls[index];
                      final isDownloading = _downloadingPhotos.contains(url);

                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AppFileImage(
                              path: url,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      colors.black.withValues(alpha: 0.85),
                                      colors.black.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 44,
                                        child: ElevatedButton(
                                          onPressed: () => PhotoPreviewDialog.show(
                                            context,
                                            imagePath: url,
                                            title: 'Foto #${index + 1} - ${task.judul}',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: colors.white,
                                            foregroundColor: colors.black,
                                            elevation: 0,
                                            padding: EdgeInsets.zero,
                                            shape: const StadiumBorder(),
                                          ),
                                          child: const Text(
                                            'Zoom',
                                            style: TextStyle(
                                              fontFamily: TiketType.fontFamily,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SizedBox(
                                        height: 44,
                                        child: ElevatedButton(
                                          onPressed: isDownloading ? null : () => _downloadSinglePhoto(url, index),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: colors.white,
                                            foregroundColor: colors.black,
                                            elevation: 0,
                                            padding: EdgeInsets.zero,
                                            shape: const StadiumBorder(),
                                          ),
                                          child: isDownloading
                                              ? SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: colors.black,
                                                  ),
                                                )
                                              : const Text(
                                                  'Unduh',
                                                  style: TextStyle(
                                                    fontFamily: TiketType.fontFamily,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                if (videoList.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Video Bukti Pengerjaan (${videoList.length})',
                    style: TextStyle(
                      fontFamily: TiketType.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: videoList.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, vIdx) {
                      final videoUrl = videoList[vIdx];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: colors.soft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.hairline),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.video_library_rounded, color: colors.primary, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Video Bukti #${vIdx + 1}',
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colors.ink,
                                ),
                              ),
                            ),
                            TiketPill(
                              label: 'Buka',
                              kind: TiketPillKind.primary,
                              height: 44,
                              icon: Icons.play_arrow_rounded,
                              onPressed: () => _openVideo(videoUrl),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required TiketColors colors,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 13,
              color: colors.body,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.ink,
            ),
          ),
        ),
      ],
    );
  }
}
