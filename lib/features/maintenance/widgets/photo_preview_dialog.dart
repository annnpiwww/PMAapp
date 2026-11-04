import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/utils/image_watermark_processor.dart';
import '../../../core/utils/share_helper.dart';
import '../../../core/utils/web_bytes/web_bytes.dart';
import '../../../core/widgets/app_file_image.dart';
import '../../../data/models/maintenance_submission.dart';
import '../../../data/models/submission_model.dart';
import '../../../data/services/ai_vision_service.dart';
import 'ai_analyzing_dialog.dart';
import 'ai_logo_mark.dart';
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
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
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
  late MaintenancePointResult? _pointResult = widget.pointResult;
  bool _analyzing = false;

  /// Ambil foto dari path apa pun jadi base64 ringan (512px) buat AI.
  Future<String?> _resolveBase64() async {
    // Paling andal: base64 yang masih tersimpan di memori hasil verifikasi.
    final stored = widget.pointResult?.imageBase64;
    if (stored != null && stored.isNotEmpty) return stored;

    final path = widget.imagePath;
    if (path.isEmpty) return null;
    Uint8List? bytes;
    if (path.startsWith('data:image')) {
      final comma = path.indexOf(',');
      if (comma < 0) return null;
      try {
        bytes = base64Decode(path.substring(comma + 1));
      } catch (_) {
        return null;
      }
    } else if (path.startsWith('http://') || path.startsWith('https://')) {
      try {
        final res = await http.get(Uri.parse(path));
        if (res.statusCode != 200) return null;
        bytes = res.bodyBytes;
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
    setState(() => _analyzing = true);
    try {
      final payload = await _resolveBase64();
      if (payload == null || payload.isEmpty) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Foto tidak bisa dibaca ulang dari perangkat ini.'),
          backgroundColor: Color(0xFFDC2626),
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
      messenger.showSnackBar(const SnackBar(
        content: Text('Analisa ulang gagal: koneksi AI terputus.'),
        backgroundColor: Color(0xFFDC2626),
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
                        widget.title,
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
                // Analisa ulang foto yang sedang dipreview, tepat di samping
                // tombol download. Selalu tampil di semua layar preview.
                InkWell(
                  key: const Key('analyze-photo-button'),
                  borderRadius: const BorderRadius.all(Radius.circular(9)),
                  onTap: _analyzing ? null : _analyze,
                  // Progres tampil di modal loading; tombol ini hanya
                  // mengunci diri supaya tidak ter-tap dua kali.
                  child: const Tooltip(
                    message: 'Analisa Ulang Foto Ini dengan AI',
                    child: SizedBox(
                      width: 34,
                      height: 34,
                      child: Center(child: AiLogoMark(size: 32, ring: true)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.download_rounded, color: Colors.white, size: 22),
                  tooltip: 'Download ke Galeri HP',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final success = await ShareHelper.savePhotoToGallery(widget.imagePath);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(success
                            ? (kIsWeb ? 'Foto diunduh ke Files/Downloads (bukan Galeri)' : 'Foto tersimpan di Galeri HP')
                            : (kIsWeb ? 'Gagal mengunduh foto' : 'Gagal menyimpan foto ke Galeri HP')),
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
                if (_pointResult != null && _pointResult!.alasan.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Catatan: ${_pointResult!.alasan}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Hanya tampilkan tombol Foto Ulang jika status BELUM SESUAI
                if (!isSesuai && widget.onRetake != null) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onRetake!();
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
