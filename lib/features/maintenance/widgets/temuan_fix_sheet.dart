import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/tiket_colors.dart';
import '../../../core/widgets/tiket/tiket.dart';
import '../../../data/services/maintenance_fix_service.dart';
import '../../../data/services/maintenance_log_service.dart';

/// Hasil yang dikembalikan saat sheet selesai submit perbaikan.
class TemuanFixSheetResult {
  final FixSubmitResult submitResult;
  final List<String> photoPaths;

  const TemuanFixSheetResult({
    required this.submitResult,
    required this.photoPaths,
  });
}

/// Bottom sheet interaktif untuk teknisi mencatat bukti perbaikan temuan.
class TemuanFixSheet extends StatefulWidget {
  final MaintenanceLogEntry log;
  final MaintenanceTemuan temuan;
  final Future<String?> Function()? onPickPhoto;
  final Future<FixSubmitResult> Function({
    required MaintenanceLogEntry log,
    required MaintenanceTemuan temuan,
    required String catatan,
    required List<String> photoPaths,
  })? onSubmit;

  const TemuanFixSheet({
    super.key,
    required this.log,
    required this.temuan,
    this.onPickPhoto,
    this.onSubmit,
  });

  static Future<TemuanFixSheetResult?> show(
    BuildContext context, {
    required MaintenanceLogEntry log,
    required MaintenanceTemuan temuan,
    Future<String?> Function()? onPickPhoto,
    Future<FixSubmitResult> Function({
      required MaintenanceLogEntry log,
      required MaintenanceTemuan temuan,
      required String catatan,
      required List<String> photoPaths,
    })? onSubmit,
  }) {
    return showModalBottomSheet<TemuanFixSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) => TemuanFixSheet(
        log: log,
        temuan: temuan,
        onPickPhoto: onPickPhoto,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<TemuanFixSheet> createState() => _TemuanFixSheetState();
}

class _TemuanFixSheetState extends State<TemuanFixSheet> {
  final TextEditingController _catatanController = TextEditingController();
  final List<String> _photoPaths = [];
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _catatanController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _catatanController.removeListener(_onTextChanged);
    _catatanController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  bool get _hasUnsavedInput =>
      _photoPaths.isNotEmpty || _catatanController.text.trim().isNotEmpty;

  bool get _canSubmit =>
      !_isSubmitting &&
      _photoPaths.isNotEmpty &&
      _catatanController.text.trim().length >= 3;

  Future<void> _takePhoto() async {
    if (_photoPaths.length >= 3) return;

    try {
      String? pickedPath;
      if (widget.onPickPhoto != null) {
        pickedPath = await widget.onPickPhoto!();
      } else {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1600,
          maxHeight: 1600,
        );
        pickedPath = picked?.path;
      }

      if (pickedPath != null && pickedPath.isNotEmpty) {
        setState(() {
          _photoPaths.add(pickedPath!);
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kamera tidak bisa dibuka')),
        );
      }
    }
  }

  void _removePhoto(int index) {
    if (index >= 0 && index < _photoPaths.length) {
      setState(() {
        _photoPaths.removeAt(index);
        _errorMessage = null;
      });
    }
  }

  Future<bool> _handlePopRequest() async {
    if (_isSubmitting) return false;
    if (!_hasUnsavedInput) return true;

    final colors = TiketColors.of(context);
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.dialog,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.hairline),
        ),
        title: Text(
          'Buang perbaikan ini?',
          style: TextStyle(
            fontFamily: TiketType.fontFamily,
            fontWeight: FontWeight.w700,
            color: colors.ink,
          ),
        ),
        content: Text(
          'Foto dan catatan yang sudah diisi akan hilang.',
          style: TextStyle(
            fontFamily: TiketType.fontFamily,
            color: colors.body,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Lanjut isi',
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: colors.danger,
            ),
            child: Text(
              'Buang',
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                color: colors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    return shouldDiscard == true;
  }

  Future<void> _submitFix() async {
    if (!_canSubmit) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final trimmedCatatan = _catatanController.text.trim();
    final photoList = List<String>.from(_photoPaths);

    try {
      final FixSubmitResult result;
      if (widget.onSubmit != null) {
        result = await widget.onSubmit!(
          log: widget.log,
          temuan: widget.temuan,
          catatan: trimmedCatatan,
          photoPaths: photoList,
        );
      } else {
        result = await MaintenanceFixService.submitFix(
          log: widget.log,
          temuan: widget.temuan,
          catatan: trimmedCatatan,
          photoPaths: photoList,
        );
      }

      if (!mounted) return;

      if (result.status == FixSubmitStatus.invalid) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = result.message ?? 'Data perbaikan tidak valid.';
        });
        return;
      }

      Navigator.of(context).pop(
        TemuanFixSheetResult(
          submitResult: result,
          photoPaths: photoList,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Gagal menyimpan perbaikan: $e';
      });
    }
  }

  Widget _buildThumbnail(int index, String path, TiketColors colors) {
    Widget imageWidget;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      imageWidget = Image.network(
        path,
        fit: BoxFit.cover,
        width: 104,
        height: 104,
        errorBuilder: (context, error, stackTrace) => _buildThumbFallback(colors),
      );
    } else {
      final file = File(path);
      if (!kIsWeb && file.existsSync()) {
        imageWidget = Image.file(
          file,
          fit: BoxFit.cover,
          width: 104,
          height: 104,
        );
      } else {
        imageWidget = _buildThumbFallback(colors);
      }
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 104,
            height: 104,
            child: imageWidget,
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Semantics(
            label: 'Hapus foto ${index + 1}',
            button: true,
            child: InkWell(
              onTap: _isSubmitting ? null : () => _removePhoto(index),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.topRight,
                padding: const EdgeInsets.all(4),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: colors.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThumbFallback(TiketColors colors) {
    return Container(
      width: 104,
      height: 104,
      color: colors.soft,
      child: Center(
        child: Icon(
          Icons.image_rounded,
          size: 32,
          color: colors.mute,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final nav = Navigator.of(context);
    final pad = TiketSpace.padOf(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final ok = await _handlePopRequest();
        if (ok && mounted) {
          nav.pop();
        }
      },
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: colors.dialog,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 8),
                  decoration: BoxDecoration(
                    color: colors.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header: Title + subline + close button (48x48 hit area)
              Padding(
                padding: EdgeInsets.fromLTRB(pad, 4, pad, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tandai Sudah Diperbaiki',
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: colors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.temuan.label} · ${widget.log.posName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: colors.body,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Tutup',
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: InkWell(
                          onTap: _isSubmitting
                              ? null
                              : () async {
                                  final ok = await _handlePopRequest();
                                  if (ok && mounted) {
                                    nav.pop();
                                  }
                                },
                          borderRadius: BorderRadius.circular(24),
                          child: Center(
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: colors.soft,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: colors.body,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content scrollable
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(pad, 0, pad, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section: Foto Bukti
                      Text(
                        'Foto bukti sesudah perbaikan (wajib, maks 3)',
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 10),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (int i = 0; i < _photoPaths.length; i++)
                            _buildThumbnail(i, _photoPaths[i], colors),
                          if (_photoPaths.length < 3)
                            Semantics(
                              label: 'Ambil foto bukti',
                              button: true,
                              child: InkWell(
                                onTap: _isSubmitting ? null : _takePhoto,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 104,
                                  height: 104,
                                  decoration: BoxDecoration(
                                    color: colors.soft.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: colors.hairline,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_a_photo_outlined,
                                        size: 26,
                                        color: colors.primary,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '+ Ambil Foto',
                                        style: TextStyle(
                                          fontFamily: TiketType.fontFamily,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: colors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Section: Tindakan yang dilakukan
                      Text(
                        'Tindakan yang dilakukan',
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _catatanController,
                        enabled: !_isSubmitting,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 500,
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: colors.ink,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Contoh: Ganti roller, bersihkan jalur kertas',
                          hintStyle: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: colors.mute,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: colors.hairline,
                              width: 1.0,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: colors.hairline,
                              width: 1.0,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: colors.primary,
                              width: 1.5,
                            ),
                          ),
                          filled: true,
                          fillColor: colors.soft,
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),

                      // Error Text Area
                      if (_errorMessage != null &&
                          _errorMessage!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: colors.dangerTint,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colors.danger.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: colors.danger,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    fontFamily: TiketType.fontFamily,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: colors.danger,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom Bar
              TiketBottomBar(
                primary: SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _canSubmit && !_isSubmitting ? _submitFix : null,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: colors.primary,
                      disabledBackgroundColor: colors.soft,
                      foregroundColor: colors.onPrimary,
                      disabledForegroundColor: colors.body,
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontFamily: TiketType.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(
                      _isSubmitting ? 'Menyimpan...' : 'Simpan Perbaikan',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
