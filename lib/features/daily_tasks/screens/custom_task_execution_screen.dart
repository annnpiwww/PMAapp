import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/utils/share_helper.dart';
import '../../../data/models/daily_task_model.dart';
import '../../../data/services/daily_task_service.dart';

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
  final _catatanCtrl = TextEditingController();
  final _picker = ImagePicker();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _catatanCtrl.dispose();
    super.dispose();
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
        });
      }
    } catch (e) {
      debugPrint('[CustomTaskExecution] Error take photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka kamera: $e')),
        );
      }
    }
  }

  void _removePhoto(int index) {
    if (index >= 0 && index < _localPhotoPaths.length) {
      setState(() {
        _localPhotoPaths.removeAt(index);
      });
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

    // Validasi Hard-Gate 1: Wajib foto dokumentasi
    if (_localPhotoPaths.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() {
        _isSaving = false;
        _errorMessage = 'Wajib mengambil minimal 1 foto dokumentasi pekerjaan!';
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
    );

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (success) {
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(); // Tutup dialog
                Navigator.of(context).pop(true); // Kembali ke list tugas & trigger reload
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
                await ShareHelper.shareToWhatsApp(
                  text: reportText,
                  imagePaths: _localPhotoPaths.isNotEmpty ? _localPhotoPaths : null,
                );
                dlgNav.pop();
                rootNav.pop(true);
              },
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Kirim Laporan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
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
                  Text(
                    widget.task.judul,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textHead,
                    ),
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

            // Foto Dokumentasi
            Text(
              'Foto Dokumentasi (Opsional)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textHead),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: _localPhotoPaths.length + 1,
              itemBuilder: (context, index) {
                if (index == _localPhotoPaths.length) {
                  // Tombol Tambah Foto
                  return InkWell(
                    onTap: _takePhoto,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: bgCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5), style: BorderStyle.solid),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, color: AppColors.accent, size: 24),
                          SizedBox(height: 4),
                          Text(
                            'Tambah Foto',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.accent),
                          ),
                        ],
                      ),
                    ),
                  );
                }

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
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(3),
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
                          padding: const EdgeInsets.all(2),
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
