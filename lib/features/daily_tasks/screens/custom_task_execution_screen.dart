import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/tiket_colors.dart';
import '../../../core/utils/share_helper.dart';
import '../../../core/widgets/app_file_image.dart';
import '../../../data/models/daily_task_model.dart';
import '../../../data/models/error_report.dart';
import '../../../data/services/daily_task_service.dart';
import '../../../data/services/error_ticket_service.dart';
import '../../../data/services/storage_service.dart';

class CustomTaskExecutionScreen extends StatefulWidget {
  final DailyTaskModel task;

  const CustomTaskExecutionScreen({
    super.key,
    required this.task,
  });

  @override
  State<CustomTaskExecutionScreen> createState() => _CustomTaskExecutionScreenState();

  @visibleForTesting
  static String buildCompleteCatatan({
    required bool isError,
    required String penyebab,
    required String solusi,
    required String catatan,
  }) {
    if (isError) {
      return errorCatatanTeknisi(
        penyebab: penyebab,
        solusiPerbaikan: solusi,
        catatan: catatan,
      );
    }
    return catatan.trim();
  }
}

class _CustomTaskExecutionScreenState extends State<CustomTaskExecutionScreen> {
  final List<String> _localPhotoPaths = [];
  final List<String> _localVideoPaths = [];
  final _catatanCtrl = TextEditingController();
  final _penyebabCtrl = TextEditingController();
  final _solusiCtrl = TextEditingController();
  final _picker = ImagePicker();

  late final bool _isError;
  late final ErrorReport _report;
  Timer? _infoTimer;

  bool _isSaving = false;
  String? _errorMessage;
  String? _solusiError;
  bool _isTaskCompleted = false;
  bool _isDraftRestored = false;

  String get _draftKey => 'daily_task_draft_${widget.task.id}';

  @override
  void initState() {
    super.initState();
    _isError = widget.task.kategori == ErrorTicketService.kategori;
    _report = ErrorReport.parse(widget.task.deskripsi);

    if (_isError) {
      _penyebabCtrl.text = _report.penyebab;
      _infoTimer = Timer.periodic(const Duration(seconds: 60), (_) {
        if (mounted) setState(() {});
      });
    }

    _restoreDraft();
    _catatanCtrl.addListener(_onFieldChanged);
    if (_isError) {
      _penyebabCtrl.addListener(_onFieldChanged);
      _solusiCtrl.addListener(_onFieldChanged);
    }
  }

  @override
  void dispose() {
    _infoTimer?.cancel();
    _catatanCtrl.removeListener(_onFieldChanged);
    _penyebabCtrl.removeListener(_onFieldChanged);
    _solusiCtrl.removeListener(_onFieldChanged);
    _catatanCtrl.dispose();
    _penyebabCtrl.dispose();
    _solusiCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    _saveDraft();
  }

  void _restoreDraft() {
    try {
      final raw = StorageService.getString(_draftKey);
      if (raw == null || raw.isEmpty) return;

      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;

      final savedCatatan = decoded['catatan']?.toString() ?? '';
      if (savedCatatan.isNotEmpty) {
        _catatanCtrl.text = savedCatatan;
      }

      if (_isError) {
        final savedPenyebab = decoded['penyebab']?.toString();
        if (savedPenyebab != null && savedPenyebab.isNotEmpty) {
          _penyebabCtrl.text = savedPenyebab;
        }
        final savedSolusi = decoded['solusi']?.toString();
        if (savedSolusi != null && savedSolusi.isNotEmpty) {
          _solusiCtrl.text = savedSolusi;
        }
      }

      final rawPhotos = (decoded['photos'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final validPhotos = <String>[];
      for (final p in rawPhotos) {
        if (p.isNotEmpty && (kIsWeb || File(p).existsSync())) {
          validPhotos.add(p);
        }
      }

      final rawVideos = (decoded['videos'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final validVideos = <String>[];
      for (final v in rawVideos) {
        if (v.isNotEmpty && (kIsWeb || File(v).existsSync())) {
          validVideos.add(v);
        }
      }

      _localPhotoPaths.clear();
      _localPhotoPaths.addAll(validPhotos);

      _localVideoPaths.clear();
      _localVideoPaths.addAll(validVideos);

      if (validPhotos.isNotEmpty || validVideos.isNotEmpty || savedCatatan.isNotEmpty) {
        _isDraftRestored = true;
      }

      if (validPhotos.length != rawPhotos.length || validVideos.length != rawVideos.length) {
        _saveDraft();
      }
    } catch (e) {
      debugPrint('[CustomTaskExecution] Error restore draft: $e');
    }
  }

  Future<void> _saveDraft() async {
    if (_isTaskCompleted) return;
    try {
      final hasCatatan = _catatanCtrl.text.trim().isNotEmpty;
      final hasPenyebab = _isError && _penyebabCtrl.text.trim().isNotEmpty && _penyebabCtrl.text.trim() != _report.penyebab.trim();
      final hasSolusi = _isError && _solusiCtrl.text.trim().isNotEmpty;

      if (_localPhotoPaths.isEmpty && _localVideoPaths.isEmpty && !hasCatatan && !hasPenyebab && !hasSolusi) {
        await StorageService.remove(_draftKey);
        return;
      }
      final data = <String, dynamic>{
        'photos': _localPhotoPaths,
        'videos': _localVideoPaths,
        'catatan': _catatanCtrl.text,
        if (_isError) 'penyebab': _penyebabCtrl.text,
        if (_isError) 'solusi': _solusiCtrl.text,
      };
      await StorageService.setString(_draftKey, jsonEncode(data));
    } catch (e) {
      debugPrint('[CustomTaskExecution] Error save draft: $e');
    }
  }

  Future<void> _clearDraft() async {
    _isTaskCompleted = true;
    try {
      await StorageService.remove(_draftKey);
    } catch (e) {
      debugPrint('[CustomTaskExecution] Error clear draft: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (photo != null) {
        setState(() {
          _localPhotoPaths.add(photo.path);
          _errorMessage = null;
        });
        _saveDraft();
      }
    } catch (e) {
      debugPrint('[CustomTaskExecution] Error capture photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka kamera foto.')),
        );
      }
    }
  }

  Future<void> _recordVideo() async {
    try {
      final video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 30),
      );
      if (video != null) {
        setState(() {
          _localVideoPaths.add(video.path);
          _errorMessage = null;
        });
        _saveDraft();
      }
    } catch (e) {
      debugPrint('[CustomTaskExecution] Error record video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka kamera video.')),
        );
      }
    }
  }

  Future<void> _pickGalleryPhotos() async {
    try {
      final images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (images.isNotEmpty) {
        setState(() {
          for (final img in images) {
            _localPhotoPaths.add(img.path);
          }
          _errorMessage = null;
        });
        _saveDraft();
      }
    } catch (e) {
      debugPrint('[CustomTaskExecution] Error pick gallery photos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memilih gambar dari galeri.')),
        );
      }
    }
  }

  Future<void> _pickGalleryVideo() async {
    try {
      final video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        setState(() {
          _localVideoPaths.add(video.path);
          _errorMessage = null;
        });
        _saveDraft();
      }
    } catch (e) {
      debugPrint('[CustomTaskExecution] Error pick gallery video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memilih video dari galeri.')),
        );
      }
    }
  }

  void _showGalleryPicker(BuildContext context) {
    final colors = TiketColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.dialog,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.photo_library_outlined, color: colors.ink),
                  title: Text(
                    'Foto dari galeri',
                    style: TextStyle(fontFamily: 'Figtree', fontWeight: FontWeight.w600, color: colors.ink),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickGalleryPhotos();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.video_library_outlined, color: colors.ink),
                  title: Text(
                    'Video dari galeri',
                    style: TextStyle(fontFamily: 'Figtree', fontWeight: FontWeight.w600, color: colors.ink),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickGalleryVideo();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _removePhoto(int index) {
    if (index >= 0 && index < _localPhotoPaths.length) {
      setState(() {
        _localPhotoPaths.removeAt(index);
      });
      _saveDraft();
    }
  }

  void _removeVideo(int index) {
    if (index >= 0 && index < _localVideoPaths.length) {
      setState(() {
        _localVideoPaths.removeAt(index);
      });
      _saveDraft();
    }
  }

  String _currentFormattedTime() {
    final now = customTaskNow();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WITA';
  }

  String _buildInfoStripText() {
    final reportedAt = _report.reportedAt;
    if (reportedAt == null) {
      return 'Waktu lapor tidak ada di pesan';
    }
    final hh = reportedAt.hour.toString().padLeft(2, '0');
    final mm = reportedAt.minute.toString().padLeft(2, '0');
    final durasi = formatDurasi(customTaskNow().difference(reportedAt));
    return 'Dilaporkan $hh.$mm · sudah $durasi';
  }

  Future<void> _submitTask() async {
    if (_isSaving) return;

    setState(() {
      _errorMessage = null;
      _solusiError = null;
    });

    if (_localPhotoPaths.isEmpty && _localVideoPaths.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorMessage = 'Ambil atau upload minimal 1 foto/video bukti pekerjaan.';
      });
      return;
    }

    if (_isError) {
      if (_solusiCtrl.text.trim().isEmpty) {
        HapticFeedback.heavyImpact();
        setState(() {
          _solusiError = 'Solusi perbaikan wajib diisi.';
        });
        return;
      }
    } else {
      if (_catatanCtrl.text.trim().isEmpty) {
        HapticFeedback.heavyImpact();
        setState(() {
          _errorMessage = 'Catatan laporan harus diisi.';
        });
        return;
      }
    }

    setState(() => _isSaving = true);

    final jamSelesai = _currentFormattedTime();
    final catatan = CustomTaskExecutionScreen.buildCompleteCatatan(
      isError: _isError,
      penyebab: _penyebabCtrl.text,
      solusi: _solusiCtrl.text,
      catatan: _catatanCtrl.text,
    );

    final success = await DailyTaskService.completeTask(
      taskId: widget.task.id,
      jamSelesai: jamSelesai,
      catatan: catatan,
      localPhotoPaths: _localPhotoPaths,
      localVideoPaths: _localVideoPaths,
    );

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (success) {
      await _clearDraft();
      _showPostSaveDialog();
    } else {
      setState(() {
        _errorMessage = 'Gagal menyimpan laporan. Periksa koneksi lalu coba lagi.';
      });
    }
  }

  @visibleForTesting
  void showPostSaveDialogForTesting() {
    _showPostSaveDialog();
  }

  void _showPostSaveDialog() {
    final String reportText;
    if (_isError) {
      final kendala = _report.kendala.isNotEmpty ? _report.kendala : widget.task.judul;
      reportText = buildErrorReply(
        kendala: kendala,
        penyebab: _penyebabCtrl.text,
        solusiPerbaikan: _solusiCtrl.text,
        reportedAt: _report.reportedAt,
        selesai: customTaskNow(),
        catatan: _catatanCtrl.text,
      );
    } else {
      reportText = DailyTaskService.formatPerTaskReport(
        judul: widget.task.judul,
        notes: _catatanCtrl.text.trim(),
        partners: widget.task.pesertaList,
      );
    }

    final colors = TiketColors.of(context);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final media = [..._localPhotoPaths, ..._localVideoPaths];
        final pathsToSend = media.isNotEmpty ? media : null;

        return Dialog(
          backgroundColor: colors.dialog,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.hairline),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: colors.ok, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Laporan siap dikirim',
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Cek dulu, lalu bagikan ke grup',
                  style: TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 13,
                    color: colors.body,
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.soft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.hairline),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        reportText,
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 14,
                          height: 1.4,
                          color: colors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Foto dan video ikut terlampir. Teks laporan otomatis disalin, tempel di kolom keterangan Telegram kalau belum muncul.',
                  style: TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 12,
                    color: colors.mute,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      final rootNav = Navigator.of(context);
                      final dlgNav = Navigator.of(ctx);
                      await ShareHelper.shareToTelegram(
                        text: reportText,
                        imagePaths: pathsToSend,
                      );
                      dlgNav.pop();
                      rootNav.pop(true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Bagikan ke Grup',
                      style: TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: reportText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Teks laporan disalin.')),
                        );
                      },
                      child: Text(
                        'Salin teks',
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontWeight: FontWeight.w600,
                          color: colors.body,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).pop(true);
                      },
                      child: Text(
                        'Selesai',
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontWeight: FontWeight.w600,
                          color: colors.mute,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocIconButton({
    required IconData icon,
    required String semanticLabel,
    required VoidCallback onTap,
    required TiketColors colors,
  }) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.soft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 28, color: colors.ink),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.canvas, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.add, size: 14, color: colors.onPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final pad = TiketSpace.padOf(context);

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: colors.ink),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Selesaikan tugas',
              style: TextStyle(
                fontFamily: 'Figtree',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${widget.task.posName} · ${widget.task.judul}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Figtree',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.body,
              ),
            ),
            if (_isDraftRestored) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_edu_rounded, size: 12, color: colors.signalText),
                  const SizedBox(width: 4),
                  Text(
                    'Draft Tersimpan',
                    style: TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.signalText,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: pad, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info strip for Error Ticket
            if (_isError) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: colors.body),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _buildInfoStripText(),
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Field Penyebab
              Text(
                'Penyebab',
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _penyebabCtrl,
                style: TextStyle(fontFamily: 'Figtree', fontSize: 14, color: colors.ink),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colors.soft,
                  helperText: 'Isi awal dari admin. Ganti kalau sudah ketemu.',
                  helperStyle: TextStyle(fontFamily: 'Figtree', fontSize: 12, color: colors.body),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),

              // Field Solusi Perbaikan
              Text(
                'Solusi perbaikan',
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _solusiCtrl,
                style: TextStyle(fontFamily: 'Figtree', fontSize: 14, color: colors.ink),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colors.soft,
                  hintText: 'Tulis yang kamu perbaiki',
                  hintStyle: TextStyle(fontFamily: 'Figtree', fontSize: 14, color: colors.mute),
                  errorText: _solusiError,
                  errorStyle: TextStyle(fontFamily: 'Figtree', fontSize: 12, color: colors.danger),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),

              // Field Catatan (opsional)
              Text(
                'Catatan (opsional)',
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _catatanCtrl,
                maxLines: 3,
                style: TextStyle(fontFamily: 'Figtree', fontSize: 14, color: colors.ink),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colors.soft,
                  hintText: 'Hal lain yang perlu disampaikan',
                  hintStyle: TextStyle(fontFamily: 'Figtree', fontSize: 14, color: colors.mute),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
            ] else ...[
              // Non-error task: single Catatan field
              Text(
                'Catatan Laporan',
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _catatanCtrl,
                maxLines: 3,
                style: TextStyle(fontFamily: 'Figtree', fontSize: 14, color: colors.ink),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colors.soft,
                  hintText: 'Tulis catatan atau kendala pekerjaan...',
                  hintStyle: TextStyle(fontFamily: 'Figtree', fontSize: 14, color: colors.mute),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Dokumentasi section (both kinds)
            Text(
              'Dokumentasi (foto atau video)',
              style: TextStyle(
                fontFamily: 'Figtree',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                _buildDocIconButton(
                  icon: Icons.camera_alt_outlined,
                  semanticLabel: 'Ambil foto',
                  onTap: _takePhoto,
                  colors: colors,
                ),
                const SizedBox(width: 16),
                _buildDocIconButton(
                  icon: Icons.videocam_outlined,
                  semanticLabel: 'Rekam video',
                  onTap: _recordVideo,
                  colors: colors,
                ),
                const SizedBox(width: 16),
                _buildDocIconButton(
                  icon: Icons.photo_library_outlined,
                  semanticLabel: 'Pilih dari galeri',
                  onTap: () => _showGalleryPicker(context),
                  colors: colors,
                ),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              'Minimal 1 foto atau 1 video.',
              style: TextStyle(
                fontFamily: 'Figtree',
                fontSize: 12,
                color: colors.mute,
              ),
            ),
            const SizedBox(height: 14),

            // Thumbnail deck
            if (_localPhotoPaths.isNotEmpty || _localVideoPaths.isNotEmpty) ...[
              if (_localPhotoPaths.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Foto (${_localPhotoPaths.length}):',
                    style: TextStyle(fontFamily: 'Figtree', fontSize: 12, fontWeight: FontWeight.w600, color: colors.body),
                  ),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: _localPhotoPaths.length,
                  itemBuilder: (context, index) {
                    final path = _localPhotoPaths[index];
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: AppFileImage(path: path, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Semantics(
                            label: 'Hapus foto ${index + 1}',
                            button: true,
                            child: InkWell(
                              onTap: () => _removePhoto(index),
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                width: 48,
                                height: 48,
                                alignment: Alignment.topRight,
                                padding: const EdgeInsets.all(4),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: colors.danger,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(Icons.close, size: 14, color: colors.white),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],

              if (_localVideoPaths.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Video (${_localVideoPaths.length}):',
                    style: TextStyle(fontFamily: 'Figtree', fontSize: 12, fontWeight: FontWeight.w600, color: colors.body),
                  ),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.4,
                  ),
                  itemCount: _localVideoPaths.length,
                  itemBuilder: (context, index) {
                    final vPath = _localVideoPaths[index];
                    final fileName = vPath.split('/').last;
                    return Container(
                      decoration: BoxDecoration(
                        color: colors.soft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.hairline),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Icon(Icons.play_circle_fill_rounded, color: colors.body, size: 36),
                          ),
                          Positioned(
                            bottom: 6,
                            left: 8,
                            right: 8,
                            child: Text(
                              fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: 'Figtree', fontSize: 10, color: colors.body),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Semantics(
                              label: 'Hapus video ${index + 1}',
                              button: true,
                              child: InkWell(
                                onTap: () => _removeVideo(index),
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  alignment: Alignment.topRight,
                                  padding: const EdgeInsets.all(4),
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: colors.danger,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(Icons.close, size: 14, color: colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.dangerTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: colors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          color: colors.danger,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            if (_isError) ...[
              Text(
                'Laporan balasan dibuat otomatis setelah disimpan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 12,
                  color: colors.mute,
                ),
              ),
              const SizedBox(height: 8),
            ],

            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submitTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: _isSaving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onPrimary,
                        ),
                      )
                    : Text(
                        _isError ? 'Simpan & Buat Laporan' : 'Simpan',
                        style: const TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Jam yang dipakai layar ini; tes screenshot menggantinya supaya durasi tetap.
@visibleForTesting
DateTime Function() customTaskNow = DateTime.now;
