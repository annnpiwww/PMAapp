import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/share_helper.dart';
import '../../../core/utils/timemark_formatter.dart';
import '../../../data/repositories/submission_repository.dart';
import '../../../data/services/storage_service.dart';
import '../../maintenance/widgets/photo_preview_dialog.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  _GalleryAlbum? _selectedAlbum;
  bool _showAllFlat = false;
  bool _isMultiSelect = false;
  final Set<String> _selectedImagePaths = {};
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    SubmissionRepository.instance.addListener(_onUpdate);
  }

  @override
  void dispose() {
    SubmissionRepository.instance.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  List<_GalleryAlbum> _buildAlbums() {
    final albums = <_GalleryAlbum>[];

    // 1. Kelompokkan foto dari Maintenance Submissions (per sesi maintenance)
    final maintList = StorageService.getMaintenanceSubmissions() ?? [];
    for (final ms in maintList) {
      final validPhotos = <_GalleryPhotoItem>[];
      for (final p in ms.points) {
        if (p.imagePath != null && File(p.imagePath!).existsSync()) {
          validPhotos.add(
            _GalleryPhotoItem(
              imagePath: p.imagePath!,
              title: p.label,
              subtitle: '${ms.posName} • ${ms.templateName}',
              timestamp: p.timestamp ?? ms.createdAt,
            ),
          );
        }
      }
      if (validPhotos.isNotEmpty) {
        // Urutkan foto dalam album
        validPhotos.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        albums.add(
          _GalleryAlbum(
            id: ms.id,
            title: ms.templateName,
            subtitle: ms.posName,
            date: ms.createdAt,
            icon: Icons.handyman_rounded,
            badgeColor: const Color(0xFF0284C7),
            photos: validPhotos,
          ),
        );
      }
    }

    // 2. Kelompokkan foto dari Absensi Submissions (per hari & kategori)
    final submissions = SubmissionRepository.instance.submissions
        .where((s) => s.imagePath != null && File(s.imagePath!).existsSync())
        .toList();

    final absensiGroupMap = <String, List<_GalleryPhotoItem>>{};
    final absensiMetaMap = <String, ({String title, String subtitle, DateTime date})>{};

    for (final s in submissions) {
      final dayKey = '${s.timestampCapture.year}-${s.timestampCapture.month}-${s.timestampCapture.day}_${s.templateName}';
      final item = _GalleryPhotoItem(
        imagePath: s.imagePath!,
        title: s.templateName,
        subtitle: '${s.posName} • ${s.userName}',
        timestamp: s.timestampCapture,
      );
      absensiGroupMap.putIfAbsent(dayKey, () => []).add(item);
      absensiMetaMap.putIfAbsent(
        dayKey,
        () => (
          title: s.templateName,
          subtitle: '${TimemarkFormatter.formatIndonesianFullDate(s.timestampCapture)} • ${s.posName}',
          date: s.timestampCapture,
        ),
      );
    }

    absensiGroupMap.forEach((key, photos) {
      final meta = absensiMetaMap[key]!;
      photos.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      albums.add(
        _GalleryAlbum(
          id: key,
          title: meta.title,
          subtitle: meta.subtitle,
          date: meta.date,
          icon: Icons.badge_rounded,
          badgeColor: const Color(0xFF16A34A),
          photos: photos,
        ),
      );
    });

    // Urutkan album dari yang terbaru
    albums.sort((a, b) => b.date.compareTo(a.date));
    return albums;
  }

  Future<void> _downloadSelectedPhotos() async {
    if (_selectedImagePaths.isEmpty) return;
    setState(() => _isDownloading = true);
    int savedCount = 0;
    for (final path in _selectedImagePaths) {
      final ok = await ShareHelper.savePhotoToGallery(path);
      if (ok) savedCount++;
    }
    if (mounted) {
      setState(() {
        _isDownloading = false;
        _isMultiSelect = false;
        _selectedImagePaths.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedCount > 0
                ? '$savedCount foto berhasil disimpan ke Galeri HP (Album BSS Parking)'
                : 'Gagal menyimpan foto ke Galeri HP',
          ),
          backgroundColor: savedCount > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _selectedImagePaths.isEmpty || _isDownloading
                    ? null
                    : _downloadSelectedPhotos,
                icon: _isDownloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download_rounded, size: 20),
                label: Text(
                  _isDownloading
                      ? 'Menyimpan Foto...'
                      : 'Download (${_selectedImagePaths.length} Foto)',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: AppColors.accent.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final albums = _buildAlbums();
    final allPhotos = albums.expand((a) => a.photos).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Jika sedang di dalam folder tertentu
    if (_selectedAlbum != null) {
      return _buildAlbumDetailView(_selectedAlbum!);
    }

    return Scaffold(
      appBar: AppBar(
        title: _isMultiSelect
            ? Text(
                '${_selectedImagePaths.length} Terpilih',
                style: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700, fontSize: 16),
              )
            : Text(
                _showAllFlat ? 'Semua Foto' : 'Folder Foto',
                style: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700, fontSize: 16),
              ),
        actions: [
          if (!_isMultiSelect) ...[
            if (allPhotos.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showAllFlat = true;
                    _isMultiSelect = true;
                    _selectedImagePaths.clear();
                  });
                },
                icon: const Icon(Icons.checklist_rounded, size: 18, color: AppColors.primary),
                label: const Text(
                  'Pilih',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            // Toggle View Mode (Folder vs Flat Grid)
            IconButton(
              tooltip: _showAllFlat ? 'Lihat Folder' : 'Lihat Semua Foto',
              icon: Icon(
                _showAllFlat ? Icons.folder_copy_rounded : Icons.grid_view_rounded,
                color: AppColors.primary,
              ),
              onPressed: () {
                setState(() => _showAllFlat = !_showAllFlat);
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _showAllFlat ? '${allPhotos.length} Foto' : '${albums.length} Folder',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            TextButton(
              onPressed: () {
                setState(() {
                  final allPaths = allPhotos.map((p) => p.imagePath).toSet();
                  if (_selectedImagePaths.containsAll(allPaths)) {
                    _selectedImagePaths.clear();
                  } else {
                    _selectedImagePaths.addAll(allPaths);
                  }
                });
              },
              child: Text(
                _selectedImagePaths.containsAll(allPhotos.map((p) => p.imagePath).toSet())
                    ? 'Batal Semua'
                    : 'Pilih Semua',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isMultiSelect = false;
                  _selectedImagePaths.clear();
                });
              },
              child: const Text(
                'Batal',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: _isMultiSelect ? _buildBottomActionBar() : null,
      body: allPhotos.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_outlined, size: 42, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Belum Ada Foto Tersimpan',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Foto absensi dan maintenance ber-watermark akan muncul di sini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : (_showAllFlat
              ? _buildPhotoGrid(allPhotos)
              : _buildAlbumFolderGrid(albums)),
    );
  }

  /// Tampilan Daftar Folder / Album Sesi
  Widget _buildAlbumFolderGrid(List<_GalleryAlbum> albums) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: albums.length,
      itemBuilder: (ctx, i) {
        final album = albums[i];
        final coverFile = File(album.coverImagePath);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedAlbum = album);
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Cover Thumbnail with Stack Overlay
                    Stack(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey.shade200,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: coverFile.existsSync()
                                ? Image.file(
                                    coverFile,
                                    fit: BoxFit.cover,
                                    cacheWidth: 300,
                                    errorBuilder: (_, _, _) => const Icon(Icons.broken_image, color: Colors.grey),
                                  )
                                : const Icon(Icons.folder_rounded, size: 32, color: AppColors.primary),
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${album.photos.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),

                    // Album Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3.5),
                                decoration: BoxDecoration(
                                  color: album.badgeColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(album.icon, size: 13, color: album.badgeColor),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  album.title,
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            album.subtitle,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 11, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                TimemarkFormatter.formatIndonesianFullDate(album.date),
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${album.photos.length} Foto ❯',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Layar Drill-Down Masuk ke Dalam Folder Tertentu
  Widget _buildAlbumDetailView(_GalleryAlbum album) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Kembali',
          onPressed: () {
            setState(() {
              _selectedAlbum = null;
              _isMultiSelect = false;
              _selectedImagePaths.clear();
            });
          },
        ),
        title: _isMultiSelect
            ? Text(
                '${_selectedImagePaths.length} Terpilih',
                style: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700, fontSize: 16),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.title,
                    style: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700, fontSize: 14.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${album.photos.length} Foto • ${album.subtitle}',
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
        actions: [
          if (!_isMultiSelect)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _isMultiSelect = true;
                  _selectedImagePaths.clear();
                });
              },
              icon: const Icon(Icons.checklist_rounded, size: 18, color: AppColors.primary),
              label: const Text(
                'Pilih',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            )
          else ...[
            TextButton(
              onPressed: () {
                setState(() {
                  final allAlbumPaths = album.photos.map((p) => p.imagePath).toSet();
                  if (_selectedImagePaths.containsAll(allAlbumPaths)) {
                    _selectedImagePaths.clear();
                  } else {
                    _selectedImagePaths.addAll(allAlbumPaths);
                  }
                });
              },
              child: Text(
                _selectedImagePaths.containsAll(album.photos.map((p) => p.imagePath).toSet())
                    ? 'Batal Semua'
                    : 'Pilih Semua',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isMultiSelect = false;
                  _selectedImagePaths.clear();
                });
              },
              child: const Text(
                'Batal',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: _isMultiSelect ? _buildBottomActionBar() : null,
      body: _buildPhotoGrid(album.photos),
    );
  }

  /// Reusable Grid Foto
  Widget _buildPhotoGrid(List<_GalleryPhotoItem> photos) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(12, 12, 12, _isMultiSelect ? 90 : 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: photos.length,
      itemBuilder: (ctx, i) {
        final item = photos[i];
        final file = File(item.imagePath);
        final isSelected = _selectedImagePaths.contains(item.imagePath);

        return GestureDetector(
          onLongPress: () {
            if (!_isMultiSelect) {
              setState(() {
                _isMultiSelect = true;
                _selectedImagePaths.add(item.imagePath);
              });
            }
          },
          onTap: () {
            if (_isMultiSelect) {
              setState(() {
                if (isSelected) {
                  _selectedImagePaths.remove(item.imagePath);
                } else {
                  _selectedImagePaths.add(item.imagePath);
                }
              });
            } else {
              PhotoPreviewDialog.show(
                context,
                imagePath: item.imagePath,
                title: item.title,
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.cardBorder,
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          file,
                          fit: BoxFit.cover,
                          cacheWidth: 600,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                          ),
                        ),
                        // Multi-select Checkbox Indicator
                        if (_isMultiSelect)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : Colors.black.withValues(alpha: 0.45),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 15, color: Colors.white)
                                  : null,
                            ),
                          ),
                        // Zoom Indicator
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${TimemarkFormatter.formatIndonesianFullDate(item.timestamp)} ${TimemarkFormatter.formatClockTime(item.timestamp)}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GalleryPhotoItem {
  final String imagePath;
  final String title;
  final String subtitle;
  final DateTime timestamp;

  _GalleryPhotoItem({
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.timestamp,
  });
}

class _GalleryAlbum {
  final String id;
  final String title;
  final String subtitle;
  final DateTime date;
  final IconData icon;
  final Color badgeColor;
  final List<_GalleryPhotoItem> photos;

  _GalleryAlbum({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.icon,
    required this.badgeColor,
    required this.photos,
  });

  String get coverImagePath => photos.isNotEmpty ? photos.first.imagePath : '';
}
