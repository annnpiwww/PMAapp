import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/services/maintenance_fix_service.dart';
import '../../../data/services/maintenance_log_service.dart';
import '../screens/maintenance_map_screen.dart';

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

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Buang perbaikan ini?',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Foto dan catatan yang sudah diisi akan hilang.',
          style: TextStyle(fontFamily: 'PlusJakartaSans'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Lanjut isi'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: MaintenanceMapPalette.urgentTextOf(context),
            ),
            child: const Text('Buang'),
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

  Widget _buildThumbnail(int index, String path) {
    Widget imageWidget;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      imageWidget = Image.network(
        path,
        fit: BoxFit.cover,
        width: 88,
        height: 88,
        errorBuilder: (context, error, stackTrace) => _buildThumbFallback(),
      );
    } else {
      final file = File(path);
      if (!kIsWeb && file.existsSync()) {
        imageWidget = Image.file(
          file,
          fit: BoxFit.cover,
          width: 88,
          height: 88,
        );
      } else {
        imageWidget = _buildThumbFallback();
      }
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 88,
            height: 88,
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
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThumbFallback() {
    return Container(
      width: 88,
      height: 88,
      color: MaintenanceMapPalette.surfaceRaisedOf(context),
      child: const Center(
        child: Icon(
          Icons.image_rounded,
          size: 28,
          color: Colors.grey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = MaintenanceMapPalette.surfaceOf(context);
    final surfaceRaisedColor = MaintenanceMapPalette.surfaceRaisedOf(context);
    final dividerColor = MaintenanceMapPalette.dividerOf(context);
    final textPrimaryColor = MaintenanceMapPalette.textPrimaryOf(context);
    final textSecondaryColor = MaintenanceMapPalette.textSecondaryOf(context);
    final primaryColor = MaintenanceMapPalette.primaryOf(context);
    final urgentColor = MaintenanceMapPalette.urgentTextOf(context);

    final viewInsets = MediaQuery.of(context).viewInsets;

    final nav = Navigator.of(context);

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
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Header Titles
                  Text(
                    'Tandai Sudah Diperbaiki',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.temuan.label} · ${widget.log.posName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section: Foto Bukti
                  Text(
                    'Foto bukti sesudah perbaikan (wajib, maks 3)',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (int i = 0; i < _photoPaths.length; i++)
                        _buildThumbnail(i, _photoPaths[i]),
                      if (_photoPaths.length < 3)
                        Semantics(
                          label: 'Ambil foto bukti',
                          button: true,
                          child: InkWell(
                            onTap: _isSubmitting ? null : _takePhoto,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                color: surfaceRaisedColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: dividerColor,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    size: 24,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '+ Ambil Foto',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Section: Tindakan yang dilakukan
                  Text(
                    'Tindakan yang dilakukan',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textPrimaryColor,
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
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: textPrimaryColor,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Contoh: Ganti roller, bersihkan jalur kertas',
                      hintStyle: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: textSecondaryColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: dividerColor,
                          width: 0.8,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: dividerColor,
                          width: 0.8,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: primaryColor,
                          width: 1.5,
                        ),
                      ),
                      filled: true,
                      fillColor: surfaceRaisedColor,
                    ),
                  ),

                  // Error Text Area
                  if (_errorMessage != null && _errorMessage!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 16,
                          color: urgentColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: urgentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _canSubmit ? _submitFix : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            dividerColor.withValues(alpha: 0.5),
                        disabledForegroundColor:
                            textSecondaryColor.withValues(alpha: 0.7),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isSubmitting
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Menyimpan...',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              'Simpan Perbaikan',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
