import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/utils/share_helper.dart';
import '../../../data/models/daily_task_model.dart';
import '../../../data/services/daily_task_service.dart';
import '../../../data/services/storage_service.dart';

class CustomTaskExecutionScreen extends StatefulWidget {
  final DailyTaskModel task;

  const CustomTaskExecutionScreen({
    super.key,
    required this.task,
  });

  @override
  State<CustomTaskExecutionScreen> createState() => _CustomTaskExecutionScreenState();
}

class _CustomTaskExecutionScreenState extends State<CustomTaskExecutionScreen> {
  final List<String> _localPhotoPaths = [];
  final List<String> _localVideoPaths = [];
  final _catatanCtrl = TextEditingController();
  final _picker = ImagePicker();
  bool _isSaving = false;
  String? _errorMessage;
  bool _isTaskCompleted = false;
  bool _isDraftRestored = false;

  String get _draftKey => 'daily_task_draft_${widget.task.id}';

  @override
  void initState() {
    super.initState();
    _restoreDraft();
    _catatanCtrl.addListener(_onCatatanChanged);
  }

  @override
  void dispose() {
    _catatanCtrl.removeListener(_onCatatanChanged);
    _catatanCtrl.dispose();
    super.dispose();
  }

  void _onCatatanChanged() {
    _saveDraft();
  }

  void _restoreDraft() {
    try {
      final raw = StorageService.getString(_draftKey);
      if (raw == null || raw.isEmpty) return;

      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;

      final rawPhotos = (decoded['photos'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final validPhotos = <String>[];
      for (final p in rawPhotos) {
        if (p.isNotEmpty && File(p).existsSync()) {
          validPhotos.add(p);
        }
      }

      final rawVideos = (decoded['videos'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final validVideos = <String>[];
      for (final v in rawVideos) {
        if (v.isNotEmpty && File(v).existsSync()) {
          validVideos.add(v);
        }
      }

      final savedCatatan = decoded['catatan']?.toString() ?? '';

      _localPhotoPaths.clear();
      _localPhotoPaths.addAll(validPhotos);

      _localVideoPaths.clear();
      _localVideoPaths.addAll(validVideos);

      if (savedCatatan.isNotEmpty) {
        _catatanCtrl.text = savedCatatan;
      }

      if (validPhotos.isNotEmpty || validVideos.isNotEmpty || savedCatatan.isNotEmpty) {
        _isDraftRestored = true;
      }

      // Jika file fisik sudah dihapus di storage, update draft yang tersimpan
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
      if (_localPhotoPaths.isEmpty && _localVideoPaths.isEmpty && _catatanCtrl.text.trim().isEmpty) {
        await StorageService.remove(_draftKey);
        return;
      }
      final data = {
        'photos': _localPhotoPaths,
        'videos': _localVideoPaths,
        'catatan': _catatanCtrl.text,
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
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked != null) {
        setState(() {
          _localPhotoPaths.add(picked.path);
          _errorMessage = null;
        });
        _saveDraft();
      }
    } catch (e) {
      debugPrint('[CustomTaskExecution] Error take photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka kamera foto: $e')),
        );
      }
    }
  }

  Future<void> _recordVideo() async {
    try {
      final picked = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 30),
      );
      if (picked != null) {
        setState(() {
          _localVideoPaths.add(picked.path);
          _errorMessage = null;
        });
        _saveDraft();
      }
    } catch (e) {
      debugPrint('[CustomTaskExecution] Error record video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka kamera video: $e')),
        );
      }
    }
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
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WITA';
  }

  Future<void> _submitTask() async {
    if (_isSaving) return; // Anti-double submit

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final jamSelesai = _currentFormattedTime();
    final catatan = _catatanCtrl.text.trim();

    // Validasi Hard-Gate 1: Wajib foto ATAU video dokumentasi pekerjaan
    if (_localPhotoPaths.isEmpty && _localVideoPaths.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() {
        _isSaving = false;
        _errorMessage = 'Wajib mengambil minimal 1 foto atau video dokumentasi pekerjaan!';
      });
      return;
    }

    // Validasi Hard-Gate 2: Wajib catatan laporan teknisi
    if (catatan.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() {
        _isSaving = false;
        _errorMessage = 'Wajib mengisi catatan laporan pengerjaan!';
      });
      return;
    }

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
      _showPostSaveDialog(jamSelesai, catatan);
    } else {
      setState(() {
        _errorMessage = 'Gagal menyimpan laporan ke server. Periksa koneksi dan coba lagi.';
      });
    }
  }

  void _showPostSaveDialog(String jamSelesai, String catatan) {
    final reportText = DailyTaskService.formatPerTaskReport(
      judul: widget.task.judul,
      notes: catatan,
    );

    final isDark = ThemeService.isDarkMode(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          ),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
              const SizedBox(width: 8),
              Text(
                'Tugas Selesai',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tugas telah ditandai selesai dan dokumentasi tersimpan di database.',
                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  reportText,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                    height: 1.4,
                  ),
                ),
              ),
              if (_localPhotoPaths.isNotEmpty && _localVideoPaths.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF25D366), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'WhatsApp memisahkan pengiriman Foto dan Video. Kirim Foto terlebih dahulu, lalu kirim Video ke grup/chat yang sama.',
                          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            if (_localPhotoPaths.isNotEmpty && _localVideoPaths.isNotEmpty) ...[
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(true);
                },
                child: Text(
                  'Selesai',
                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  await ShareHelper.shareToWhatsApp(
                    text: reportText,
                    imagePaths: _localVideoPaths,
                  );
                },
                icon: const Icon(Icons.videocam_rounded, size: 15, color: Color(0xFF25D366)),
                label: Text(
                  'Kirim Video (${_localVideoPaths.length})',
                  style: const TextStyle(color: Color(0xFF25D366), fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF25D366)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  await ShareHelper.shareToWhatsApp(
                    text: reportText,
                    imagePaths: _localPhotoPaths,
                  );
                },
                icon: const Icon(Icons.photo_library_rounded, size: 15),
                label: Text(
                  'Kirim Foto (${_localPhotoPaths.length})',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ] else ...[
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(true);
                },
                child: Text(
                  'Selesai (Nanti Saja)',
                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  final rootNav = Navigator.of(context);
                  final dlgNav = Navigator.of(ctx);
                  final pathsToSend = _localPhotoPaths.isNotEmpty
                      ? _localPhotoPaths
                      : (_localVideoPaths.isNotEmpty ? _localVideoPaths : null);
                  await ShareHelper.shareToWhatsApp(
                    text: reportText,
                    imagePaths: pathsToSend,
                  );
                  dlgNav.pop();
                  rootNav.pop(true);
                },
                icon: Icon(
                  _localVideoPaths.isNotEmpty && _localPhotoPaths.isEmpty
                      ? Icons.videocam_rounded
                      : Icons.send_rounded,
                  size: 16,
                ),
                label: Text(
                  _localPhotoPaths.isNotEmpty
                      ? 'Kirim Foto (${_localPhotoPaths.length})'
                      : (_localVideoPaths.isNotEmpty ? 'Kirim Video (${_localVideoPaths.length})' : 'Kirim Laporan'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.isDarkMode(context);
    final bgScaffold = isDark ? const Color(0xFF0B1120) : const Color(0xFFFAF8F5);
    final bgAppBar = isDark ? const Color(0xFF111827) : AppColors.primary;
    final bgCard = isDark ? const Color(0xFF111827) : Colors.white;
    final borderCard = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textHead = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgScaffold,
      appBar: AppBar(
        backgroundColor: bgAppBar,
        elevation: 0,
        title: const Text(
          'Pengerjaan Tugas',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Detail Tugas Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderCard),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.task.judul,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textHead,
                          ),
                        ),
                      ),
                      if (_isDraftRestored) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.history_edu_rounded, size: 12, color: Colors.amber),
                              SizedBox(width: 4),
                              Text(
                                'Draft Tersimpan',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'Lokasi: ${widget.task.posName}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Teknisi: ${widget.task.teknisiNama}',
                        style: TextStyle(fontSize: 11, color: textSub),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Bukti Dokumentasi (Foto & Video Realtime)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bukti Dokumentasi Pekerjaan',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textHead),
                ),
                Text(
                  '${_localPhotoPaths.length} Foto • ${_localVideoPaths.length} Video',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Tombol Aksi Kamera & Video
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                    label: const Text('Ambil Foto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: BorderSide(color: AppColors.accent.withValues(alpha: 0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _recordVideo,
                    icon: const Icon(Icons.videocam_rounded, size: 18),
                    label: const Text('Rekam Video', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF991B1B) : const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 12, color: textSub),
                const SizedBox(width: 4),
                Text(
                  'Durasi video maksimal 30 detik langsung dari kamera',
                  style: TextStyle(fontSize: 10.5, color: textSub),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Preview Foto & Video
            if (_localPhotoPaths.isEmpty && _localVideoPaths.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: bgCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderCard),
                ),
                child: Column(
                  children: [
                    Icon(Icons.perm_media_outlined, size: 32, color: textSub.withValues(alpha: 0.6)),
                    const SizedBox(height: 8),
                    Text(
                      'Belum ada bukti yang diambil',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textHead),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Wajib mengambil minimal 1 foto atau rekaman video untuk menyelesaikan tugas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: textSub),
                    ),
                  ],
                ),
              )
            else ...[
              // Grid Foto
              if (_localPhotoPaths.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Foto Dokumentasi (${_localPhotoPaths.length}):',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textSub),
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
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(path),
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Foto ${index + 1}',
                              style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () => _removePhoto(index),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],

              // Grid / List Video
              if (_localVideoPaths.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Video Realtime (${_localVideoPaths.length}):',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textSub),
                  ),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: _localVideoPaths.length,
                  itemBuilder: (context, index) {
                    final vPath = _localVideoPaths[index];
                    final fileName = vPath.split('/').last;
                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 34),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'VIDEO ${index + 1} (MAKS 30s)',
                                    style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            left: 6,
                            right: 6,
                            child: Text(
                              fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 8, color: Colors.white70),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: InkWell(
                              onTap: () => _removeVideo(index),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: AppColors.danger,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
            const SizedBox(height: 18),

            // Catatan
            Text(
              'Catatan Laporan',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textHead),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _catatanCtrl,
              maxLines: 3,
              style: TextStyle(color: textHead, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Tuliskan catatan atau kendala pengerjaan...',
                hintStyle: TextStyle(color: textSub, fontSize: 13),
                filled: true,
                fillColor: bgCard,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderCard)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderCard)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accent)),
              ),
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.danger, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 10),

            // Tombol Utama Selesaikan Tugas (min height 48px)
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _submitTask,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: const Text('Selesaikan Tugas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
