import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/tiket_colors.dart';
import '../../../core/utils/image_watermark_processor.dart';
import '../../../core/utils/share_helper.dart';
import '../../../core/utils/web_bytes/web_bytes.dart';
import '../../../core/widgets/app_file_image.dart';
import '../../../core/widgets/tiket/tiket.dart';
import '../../../data/models/maintenance_submission.dart';
import '../../../data/models/submission_model.dart';
import '../../../data/services/ai_vision_service.dart';
import 'ai_analyzing_dialog.dart';
import 'ai_result_dialog.dart';

class PhotoPreviewDialog extends StatefulWidget {
  final String imagePath;
  final String title;
  final MaintenancePointResult? pointResult;
  final VoidCallback? onRetake;

  /// Kirim foto yang sedang dipreview ke AI untuk dianalisa ulang.
  /// Tombol otak AI hanya muncul kalau callback ini diisi.
  final Future<AiVerificationResult> Function(String imageBase64)? onAnalyze;

  const PhotoPreviewDialog({
    super.key,
    required this.imagePath,
    required this.title,
    this.pointResult,
    this.onRetake,
    this.onAnalyze,
  });

  static void show(
    BuildContext context, {
    required String imagePath,
    required String title,
    MaintenancePointResult? pointResult,
    VoidCallback? onRetake,
    Future<AiVerificationResult> Function(String imageBase64)? onAnalyze,
  }) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => PhotoPreviewDialog(
        imagePath: imagePath,
        title: title,
        pointResult: pointResult,
        onRetake: onRetake,
        onAnalyze: onAnalyze,
      ),
    );
  }

  @override
  State<PhotoPreviewDialog> createState() => _PhotoPreviewDialogState();
}

class _PhotoPreviewDialogState extends State<PhotoPreviewDialog> {
  bool _analyzing = false;
  late MaintenancePointResult? _pointResult;

  @override
  void initState() {
    super.initState();
    _pointResult = widget.pointResult;
  }

  Future<String?> _resolveBase64() async {
    final path = widget.imagePath;
    if (path.startsWith('data:image')) return path;
    Uint8List? bytes;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      try {
        final res = await http.get(Uri.parse(path)).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) bytes = res.bodyBytes;
      } catch (_) {
        return null;
      }
    } else if (path.startsWith('blob:')) {
      // Foto kamera web disimpan sebagai blob URL: ambil isinya lewat fetch.
      bytes = await fetchWebBytes(path);
      if (bytes == null) return null;
    }
    return ImageWatermarkProcessor.generateAiVisionBase64(path, bytes);
  }

  Future<void> _analyze() async {
    if (_analyzing) return;
    final messenger = ScaffoldMessenger.of(context);
    final dangerColor = TiketColors.of(context).danger;
    setState(() => _analyzing = true);
    try {
      final payload = await _resolveBase64();
      if (payload == null || payload.isEmpty) {
        messenger.showSnackBar(SnackBar(
          content: const Text('Foto tidak bisa dibaca ulang dari perangkat ini.'),
          backgroundColor: dangerColor,
        ));
        return;
      }
      // Kalau layar pemanggil tidak punya konteks SOP, tetap analisa dengan
      // kriteria umum supaya tombol ini tidak pernah mati.
      final analyze = widget.onAnalyze ??
          (String base64) => AiVisionService.reanalyzePhoto(
                imageBase64: base64,
                konteks: widget.title,
              );
      // Modal loading yang menjalankan request: progres bertahap + timer,
      // dan menampilkan tombol "Coba Lagi" kalau server gagal (503/timeout).
      if (!mounted) return;
      final result = await showDialog<AiVerificationResult>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.78),
        builder: (_) => AiAnalyzingDialog(task: () => analyze(payload)),
      );
      if (!mounted) return;
      setState(() => _analyzing = false);
      // null = user menutup modal setelah gagal; tidak ada hasil untuk ditampilkan.
      if (result == null) return;
      setState(() {
        final status = switch (result.status) {
          VerificationStatus.sesuai => PointStatus.sesuai,
          VerificationStatus.tidakSesuai => PointStatus.tidakSesuai,
          VerificationStatus.perluCekManual => PointStatus.perluCekManual,
        };
        _pointResult = (_pointResult ??
                MaintenancePointResult(
                  pointId: '',
                  label: widget.title,
                  imagePath: widget.imagePath,
                ))
            .copyWith(
          status: status,
          alasan: result.alasan,
          confidence: result.confidenceScore,
          providerName: result.providerName,
        );
      });
      // Tampilkan modal hasil analisa, sama seperti setelah foto baru diambil.
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.75),
        builder: (_) => AiResultDialog(result: result, title: widget.title),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(
        content: const Text('Analisa ulang gagal: koneksi AI terputus.'),
        backgroundColor: dangerColor,
      ));
    } finally {
      if (mounted && _analyzing) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRemoteOrData = widget.imagePath.startsWith('http://') ||
        widget.imagePath.startsWith('https://') ||
        widget.imagePath.startsWith('data:image') ||
        widget.imagePath.startsWith('blob:');
    final exists = kIsWeb ||
        isRemoteOrData ||
        (widget.imagePath.isNotEmpty && File(widget.imagePath).existsSync());

    final isSesuai = _pointResult?.status == PointStatus.sesuai;
    final isTidakSesuai = _pointResult?.status == PointStatus.tidakSesuai;

    return Theme(
      data: AppTheme.darkTheme,
      child: Builder(
        builder: (context) {
          final colors = TiketColors.of(context);
          return Dialog.fullscreen(
            backgroundColor: Colors.black,
            child: SafeArea(
              child: Column(
                children: [
                  // Top Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TiketIconButton(
                          icon: Icons.arrow_back_rounded,
                          semanticLabel: 'Kembali',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TiketPill(
                              key: const Key('analyze-photo-button'),
                              label: 'Analisa ulang',
                              icon: Icons.document_scanner_outlined,
                              kind: TiketPillKind.band,
                              height: 44,
                              onPressed: _analyzing ? null : _analyze,
                            ),
                            const SizedBox(width: 8),
                            TiketIconButton(
                              icon: Icons.download_rounded,
                              semanticLabel: 'Download ke Galeri HP',
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final success = await ShareHelper.savePhotoToGallery(widget.imagePath);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(success
                                        ? (kIsWeb ? 'Foto diunduh ke Files/Downloads (bukan Galeri)' : 'Foto tersimpan di Galeri HP')
                                        : (kIsWeb ? 'Gagal mengunduh foto' : 'Gagal menyimpan foto ke Galeri HP')),
                                    backgroundColor: success ? colors.ok : colors.danger,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Uncropped Full-View Image Viewport fills width
                  Expanded(
                    child: exists
                        ? ClipRect(
                            child: InteractiveViewer(
                              panEnabled: true,
                              minScale: 1.0,
                              maxScale: 4.5,
                              child: Center(
                                child: AppFileImage(
                                  path: widget.imagePath,
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

                  // Below photo: title (white 16 bold, wraps) + meta line (grey); status chip only when result exists; bottom center 'Foto Ulang'
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.title,
                                    style: const TextStyle(
                                      fontFamily: 'Figtree',
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Foto verifikasi maintenance',
                                    style: TextStyle(
                                      fontFamily: 'Figtree',
                                      color: colors.body,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_pointResult != null) ...[
                              const SizedBox(width: 12),
                              StatusChip(
                                label: isSesuai
                                    ? 'Sesuai'
                                    : (isTidakSesuai ? 'Tidak sesuai' : 'Perlu cek manual'),
                                kind: isSesuai
                                    ? TiketChipKind.ok
                                    : (isTidakSesuai ? TiketChipKind.attention : TiketChipKind.neutral),
                              ),
                            ],
                          ],
                        ),
                        if (_pointResult != null && _pointResult!.alasan.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Catatan: ${_pointResult!.alasan}',
                            style: TextStyle(
                              fontFamily: 'Figtree',
                              color: colors.body,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                        if (!isSesuai && widget.onRetake != null) ...[
                          const SizedBox(height: 20),
                          Center(
                            child: TiketPill(
                              label: 'Foto Ulang',
                              icon: Icons.camera_alt_rounded,
                              kind: TiketPillKind.secondary,
                              height: 48,
                              onPressed: () {
                                Navigator.of(context).pop();
                                widget.onRetake!();
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
