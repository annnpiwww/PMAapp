import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_file_image.dart';
import '../../../data/models/submission_model.dart';
import '../../../data/models/template_model.dart';
import '../../../data/services/ai_vision_service.dart';

/// Layar validasi AI Grooming.
/// Struktur mengikuti referensi desain: header, banner status, kartu foto beraksen
/// oranye, kartu alasan AI, daftar "Yang Perlu Diperbaiki", kartu tips, lalu CTA.
class _VerificationSheet extends StatelessWidget {
  final TemplateModel template;
  final AiVerificationResult result;
  final String kodeVerifikasi;
  final String? imagePath;
  final Uint8List? imageBytes;
  final VoidCallback onRetake;
  final VoidCallback onSave;
  final VoidCallback? onCancel;
  final VoidCallback? onShareTelegram;
  final VoidCallback? onShareWhatsApp;
  final bool isLoading;
  final Future<void> Function()? onRetryAi;
  final bool isRetrying;

  // Palet acuan desain validasi (dark navy tetap, di semua tema).
  static const Color _sheetBg = AppColors.primaryDark; // #0B192C
  static const Color _cardBlue = Color(0xFF1B3D73);
  static const Color _cardBlueDeep = Color(0xFF152C4E);
  static const Color _divider = Color(0xFF1E3A5F);
  static const Color _onDark = Color(0xFFF1F5F9);
  static const Color _onDarkMuted = Color(0xFF9FB3CE);
  static const Color _onDarkBody = Color(0xFFC7D6EC);
  static const Color _dangerBright = Color(0xFFE5484D);
  static const Color _dangerTint = Color(0xFFFDE8E8);
  static const Color _amberBright = Color(0xFFD97706);
  static const Color _amberTint = Color(0xFFFEF3C7);
  static const Color _successBright = Color(0xFF0E9F6E);
  static const Color _successTint = Color(0xFFE6F7F0);

  static bool _doesFileExist(String? path) {
    if (path == null || path.trim().isEmpty) return false;
    if (kIsWeb) return true;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  bool get _hasValidImage {
    if (imageBytes != null && imageBytes!.isNotEmpty) return true;
    return _doesFileExist(imagePath);
  }

  const _VerificationSheet({
    required this.template,
    required this.result,
    required this.kodeVerifikasi,
    this.imagePath,
    this.imageBytes,
    required this.onRetake,
    required this.onSave,
    this.onCancel,
    this.onShareTelegram,
    this.onShareWhatsApp,
    this.isLoading = false,
    this.onRetryAi,
    this.isRetrying = false,
  });

  @override
  Widget build(BuildContext context) {
    final isAIError = result.isFallback;
    final isSuccess = result.status == VerificationStatus.sesuai && !isAIError;
    final isFailure =
        result.status == VerificationStatus.tidakSesuai && !isAIError;

    final bannerColor =
        isSuccess ? _successBright : (isFailure ? _dangerBright : _amberBright);
    final bannerTint =
        isSuccess ? _successTint : (isFailure ? _dangerTint : _amberTint);
    final bannerIcon = isSuccess
        ? Icons.check_rounded
        : (isFailure ? Icons.priority_high_rounded : Icons.wifi_off_rounded);
    final bannerTitle = isSuccess
        ? 'Foto lolos validasi'
        : (isFailure ? 'Foto belum lolos validasi' : 'Verifikasi AI terputus');
    final bannerSubtitle = isSuccess
        ? 'Verifikasi selesai, foto siap dikirim ke laporan'
        : isFailure
            ? '${result.poinGagal.isNotEmpty ? result.poinGagal.length : 1} hal perlu diperbaiki'
            : 'Foto dialihkan untuk cek manual oleh Supervisor';
    final aiTitle = isSuccess
        ? 'Hasil verifikasi AI'
        : (isFailure ? 'Alasan AI menolak foto' : 'Catatan sistem');

    // Tips diambil dari panduan template yang sebenarnya (bukan teks karangan).
    final tips = <String>[
      ...template.contohFotoDescriptions.map((e) => e.trim()),
      ...template.sopPoints.map((p) => p.panduanFoto.trim()),
    ].where((e) => e.isNotEmpty).toList();

    final screenH = MediaQuery.of(context).size.height;
    final maxHeight = screenH > 0 ? screenH * 0.90 : 650.0;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: const BoxDecoration(
            color: _sheetBg,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppColors.radiusBottomSheet),
            ),
            border: Border(
              top: BorderSide(color: AppColors.accent, width: 3.0),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 24,
                spreadRadius: 2,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),

                const SizedBox(height: 12),
                _statusBanner(
                  color: bannerColor,
                  tint: bannerTint,
                  icon: bannerIcon,
                  title: bannerTitle,
                  subtitle: bannerSubtitle,
                ),

                // Koneksi AI gagal / AI tidak bisa memastikan: teknisi bisa
                // analisa ulang foto yang sama tanpa memotret dari awal.
                if (!isSuccess && !isFailure && onRetryAi != null) ...[
                  const SizedBox(height: 10),
                  _retryAiButton(),
                ],

                // Foto hasil unggahan: kartu besar, sudut membulat, border oranye.
                if (_hasValidImage) ...[
                  const SizedBox(height: 10),
                  _photoCard(context),
                ],

                const SizedBox(height: 10),
                _aiCard(aiTitle),

                // Satu checkpoint ringkas berisi seluruh temuan AI apa adanya.
                if (result.poinGagal.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _sectionLabel('YANG PERLU DIPERBAIKI'),
                  const SizedBox(height: 8),
                  _NeedsFixCard(
                    title: template.jenis == TemplateCategory.absensi
                        ? 'Grooming teknisi belum memenuhi SOP'
                        : '${result.poinGagal.length} kriteria belum memenuhi standar SOP',
                    points: result.poinGagal,
                  ),
                ],

                if (tips.isNotEmpty && !isSuccess) ...[
                  const SizedBox(height: 14),
                  _tipsCard(tips),
                ],

                const SizedBox(height: 16),

                if (isFailure) ...[
                  ElevatedButton.icon(
                    onPressed: onRetake,
                    icon: const Icon(Icons.photo_camera_rounded, size: 20),
                    label: const Text(
                      'Foto Ulang',
                      style: TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.cloud_upload_rounded, size: 20),
                    label: Text(
                      isSuccess
                          ? 'Simpan & Kirim Laporan'
                          : 'Simpan Laporan (Perlu Cek Manual)',
                      style: const TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isSuccess ? _successBright : _amberBright,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  if (kIsWeb) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Di Safari/iPhone: simpan foto ke Galeri lewat menu Bagikan → Simpan Gambar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 10.5,
                        color: _onDarkMuted,
                      ),
                    ),
                  ],
                  if (onShareWhatsApp != null || onShareTelegram != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _cardBlueDeep,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.share_rounded,
                                size: 14,
                                color: _onDarkMuted,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Bagikan Laporan:',
                                style: TextStyle(
                                  fontFamily: 'Figtree',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _onDarkMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (onShareWhatsApp != null)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: onShareWhatsApp,
                                    icon: const Icon(
                                      Icons.chat_rounded,
                                      color: Color(0xFF25D366),
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'WhatsApp',
                                      style: TextStyle(
                                        fontFamily: 'Figtree',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11.5,
                                        color: Color(0xFF15803D),
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: const Color(0xFFDCFCE7),
                                      side: const BorderSide(
                                        color: Color(0xFF86EFAC),
                                        width: 1.2,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              if (onShareWhatsApp != null &&
                                  onShareTelegram != null)
                                const SizedBox(width: 8),
                              if (onShareTelegram != null)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: onShareTelegram,
                                    icon: const Icon(
                                      Icons.send_rounded,
                                      color: Color(0xFF229ED9),
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Telegram',
                                      style: TextStyle(
                                        fontFamily: 'Figtree',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11.5,
                                        color: Color(0xFF0369A1),
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE0F2FE),
                                      side: const BorderSide(
                                        color: Color(0xFF7DD3FC),
                                        width: 1.2,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onRetake,
                          icon: const Icon(
                            Icons.replay_rounded,
                            size: 18,
                            color: _onDark,
                          ),
                          label: const Text(
                            'Foto Ulang',
                            style: TextStyle(
                              fontFamily: 'Figtree',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _onDark,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            side: const BorderSide(
                              color: _divider,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onCancel,
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: _onDarkMuted,
                          ),
                          label: const Text(
                            'Batal / Tutup',
                            style: TextStyle(
                              fontFamily: 'Figtree',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _onDarkMuted,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            side: const BorderSide(
                              color: _divider,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        if (onCancel != null)
          GestureDetector(
            onTap: onCancel,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.only(right: 10, top: 4, bottom: 4),
              child: Icon(Icons.arrow_back_rounded, color: _onDark, size: 22),
            ),
          ),
        const Text.rich(
          TextSpan(
            style: TextStyle(
              fontFamily: 'Figtree',
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _onDark,
            ),
            children: [
              TextSpan(text: 'PMA'),
              TextSpan(text: 'app', style: TextStyle(color: AppColors.accent)),
            ],
          ),
        ),
        Container(
          width: 1.2,
          height: 18,
          color: _divider,
          margin: const EdgeInsets.symmetric(horizontal: 10),
        ),
        Expanded(
          child: Text(
            template.jenis == TemplateCategory.absensi
                ? 'Validasi Grooming'
                : 'Validasi ${template.nama}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Figtree',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _onDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusBanner({
    required Color color,
    required Color tint,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 13,
                    color: Color(0xFF52525B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tombol analisa ulang: pakai foto yang sudah ada, tanpa memotret lagi.
  Widget _retryAiButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isRetrying ? null : onRetryAi,
        icon: isRetrying
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _amberBright,
                ),
              )
            : const Icon(Icons.psychology_rounded, size: 20),
        label: Text(
          isRetrying
              ? 'Menganalisa ulang foto...'
              : 'Analisa Ulang Foto Ini dengan AI',
          style: const TextStyle(
            fontFamily: 'Figtree',
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _amberBright,
          backgroundColor: Colors.white,
          disabledForegroundColor: _amberBright,
          side: const BorderSide(color: _amberBright, width: 1.4),
          minimumSize: const Size(double.infinity, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _photoCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent, width: 1.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => _showFullImagePreview(
              context,
              path: imagePath,
              bytes: imageBytes,
            ),
            child: SizedBox(
              height: 190,
              width: double.infinity,
              child: AppFileImage(
                path: imagePath,
                bytes: imageBytes,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xE60B1220),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.photo_camera_rounded,
                    color: AppColors.accent,
                    size: 13,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Foto saat ini',
                    style: TextStyle(
                      fontFamily: 'Figtree',
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiCard(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBlue,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF1D4ED8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: _onDark,
                  ),
                ),
                if (result.alasan.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    result.alasan,
                    style: const TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFFD8E3F5),
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

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'Figtree',
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: _onDarkMuted,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Divider(color: _divider, height: 1, thickness: 1),
        ),
      ],
    );
  }

  Widget _tipsCard(List<String> tips) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBlueDeep,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF1D4ED8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tips agar lolos',
                  style: TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _onDark,
                  ),
                ),
                const SizedBox(height: 6),
                ...tips.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      t,
                      style: const TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 12.5,
                        height: 1.45,
                        color: _onDarkBody,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullImagePreview(
    BuildContext context, {
    String? path,
    Uint8List? bytes,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AppFileImage(path: path, bytes: bytes, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.6),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close_rounded, size: 22),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal validasi AI.
///
/// Menyimpan hasil verifikasi di dalam state supaya teknisi bisa menganalisa
/// ulang foto yang sama saat koneksi AI gagal, tanpa memotret ulang.
class SopVerificationModal extends StatefulWidget {
  final TemplateModel template;
  final AiVerificationResult result;
  final String kodeVerifikasi;
  final String? imagePath;
  final Uint8List? imageBytes;
  final VoidCallback onRetake;
  final VoidCallback onSave;
  final VoidCallback? onCancel;
  final VoidCallback? onShareTelegram;
  final VoidCallback? onShareWhatsApp;
  final bool isLoading;

  /// Dijalankan saat teknisi menekan "Analisa Ulang". Null = tombol disembunyikan.
  final Future<AiVerificationResult> Function()? onRetryAi;

  const SopVerificationModal({
    super.key,
    required this.template,
    required this.result,
    required this.kodeVerifikasi,
    this.imagePath,
    this.imageBytes,
    required this.onRetake,
    required this.onSave,
    this.onCancel,
    this.onShareTelegram,
    this.onShareWhatsApp,
    this.isLoading = false,
    this.onRetryAi,
  });

  @override
  State<SopVerificationModal> createState() => _SopVerificationModalState();
}

class _SopVerificationModalState extends State<SopVerificationModal> {
  late AiVerificationResult _result = widget.result;
  bool _isRetrying = false;

  Future<void> _retryAi() async {
    final retry = widget.onRetryAi;
    if (retry == null || _isRetrying) return;
    setState(() => _isRetrying = true);

    AiVerificationResult? updated;
    try {
      updated = await retry();
    } catch (_) {
      updated = null;
    }

    if (!mounted) return;
    setState(() {
      if (updated != null) _result = updated;
      _isRetrying = false;
    });

    if (updated == null || updated.isFallback) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'AI masih belum terhubung. Foto tetap aman — coba lagi atau simpan untuk cek manual.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _VerificationSheet(
      template: widget.template,
      result: _result,
      kodeVerifikasi: widget.kodeVerifikasi,
      imagePath: widget.imagePath,
      imageBytes: widget.imageBytes,
      onRetake: widget.onRetake,
      onSave: widget.onSave,
      onCancel: widget.onCancel,
      onShareTelegram: widget.onShareTelegram,
      onShareWhatsApp: widget.onShareWhatsApp,
      isLoading: widget.isLoading,
      onRetryAi: widget.onRetryAi == null ? null : _retryAi,
      isRetrying: _isRetrying,
    );
  }
}

/// Satu kartu ringkas berisi seluruh temuan AI apa adanya (verbatim),
/// bukan kartu merah terpisah per pelanggaran.
class _NeedsFixCard extends StatelessWidget {
  final String title;
  final List<String> points;

  const _NeedsFixCard({required this.title, required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _VerificationSheet._cardBlueDeep,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: _VerificationSheet._dangerBright,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _VerificationSheet._onDark,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...points.map(
            (p) => Padding(
              padding: const EdgeInsets.only(left: 32, bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(
                      Icons.circle,
                      size: 5,
                      color: _VerificationSheet._onDarkMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p,
                      style: const TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 12.5,
                        height: 1.45,
                        color: _VerificationSheet._onDarkBody,
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
  }
}
