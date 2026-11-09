import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/tiket_colors.dart';
import '../../../core/widgets/app_file_image.dart';
import '../../../core/widgets/tiket/tiket.dart';
import '../../../core/utils/share_helper.dart';
import '../../../core/utils/timemark_formatter.dart';
import '../../../data/repositories/submission_repository.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/ai_vision_service.dart';
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
        if (p.imagePath != null &&
            (kIsWeb ||
                p.imagePath!.startsWith('data:image') ||
                File(p.imagePath!).existsSync())) {
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
        .where((s) =>
            s.imagePath != null &&
            (kIsWeb ||
                s.imagePath!.startsWith('data:image') ||
                File(s.imagePath!).existsSync()))
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
                ? (kIsWeb
                    ? '$savedCount foto diunduh ke Files/Downloads (bukan Galeri)'
                    : '$savedCount foto tersimpan di Galeri HP (Album BSS Parking)')
                : (kIsWeb
                    ? 'Gagal mengunduh foto'
                    : 'Gagal menyimpan foto ke Galeri HP'),
          ),
          backgroundColor: savedCount > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildBottomActionBar() {
    final colors = TiketColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.bar,
        border: Border(top: BorderSide(color: colors.hairline)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TiketPill(
                onPressed: _selectedImagePaths.isEmpty || _isDownloading
                    ? null
                    : _downloadSelectedPhotos,
                icon: _isDownloading ? null : Icons.download_rounded,
                label: _isDownloading
                    ? 'Menyimpan Foto...'
                    : 'Download (${_selectedImagePaths.length} Foto)',
                kind: (_selectedImagePaths.isEmpty || _isDownloading)
                    ? TiketPillKind.disabled
                    : TiketPillKind.primary,
                height: 48,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final type = TiketType.of(context);

    final albums = _buildAlbums();
    final allPhotos = albums.expand((a) => a.photos).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Jika sedang di dalam folder tertentu
    if (_selectedAlbum != null) {
      return _buildAlbumDetailView(_selectedAlbum!);
    }

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: _isMultiSelect
          ? AppBar(
              backgroundColor: colors.bar,
              elevation: 0,
              iconTheme: IconThemeData(color: colors.ink),
              title: Text(
                '${_selectedImagePaths.length} Terpilih',
                style: type.section(color: colors.ink),
              ),
              actions: [
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
                    style: TextStyle(
                      fontFamily: TiketType.fontFamily,
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isMultiSelect = false;
                      _selectedImagePaths.clear();
                    });
                  },
                  child: Text(
                    'Batal',
                    style: TextStyle(
                      fontFamily: TiketType.fontFamily,
                      color: colors.mute,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: SafeArea(
        top: !_isMultiSelect,
        bottom: false,
        child: Column(
          children: [
            if (!_isMultiSelect)
              TiketBand(
                leading: TiketIconButton(
                  icon: Icons.arrow_back,
                  semanticLabel: 'Kembali',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  TiketPill(
                    label: _showAllFlat ? 'Lihat Folder' : 'Semua Foto',
                    icon: _showAllFlat ? Icons.folder_copy_rounded : Icons.grid_view_rounded,
                    kind: _showAllFlat ? TiketPillKind.bandSelected : TiketPillKind.band,
                    height: 48,
                    onPressed: () {
                      setState(() => _showAllFlat = !_showAllFlat);
                    },
                  ),
                  if (allPhotos.isNotEmpty)
                    TiketPill(
                      label: 'Pilih',
                      kind: TiketPillKind.band,
                      height: 48,
                      onPressed: () {
                        setState(() {
                          _showAllFlat = true;
                          _isMultiSelect = true;
                          _selectedImagePaths.clear();
                        });
                      },
                    ),
                ],
                caption: _showAllFlat ? 'Semua Foto' : 'Folder Foto',
                hero: Row(
                  children: [
                    Text(
                      '${allPhotos.length}',
                      style: type.hero(color: colors.onBand),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _showAllFlat ? 'foto' : 'foto · ${albums.length} folder',
                      style: type.heroLabel(color: colors.onBand),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: allPhotos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 48,
                            color: colors.mute,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Belum Ada Foto Tersimpan',
                            style: type.section(color: colors.ink),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Foto absensi dan maintenance ber-watermark akan muncul di sini.',
                            textAlign: TextAlign.center,
                            style: type.meta(color: colors.body),
                          ),
                        ],
                      ),
                    )
                  : (_showAllFlat
                      ? _buildPhotoGrid(allPhotos)
                      : _buildAlbumFolderGrid(albums)),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _isMultiSelect ? _buildBottomActionBar() : null,
    );
  }

  /// Tampilan Daftar Folder / Album Sesi
  Widget _buildAlbumFolderGrid(List<_GalleryAlbum> albums) {
    final colors = TiketColors.of(context);
    final type = TiketType.of(context);

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: albums.length,
      separatorBuilder: (_, index) => Divider(
        height: 1,
        thickness: 1,
        color: colors.hairline,
      ),
      itemBuilder: (ctx, i) {
        final album = albums[i];
        final coverFile = File(album.coverImagePath);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedAlbum = album);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // 64x64 thumbnail radius 8 + count badge
                  Stack(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.0),
                          color: colors.soft,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: (kIsWeb || coverFile.existsSync())
                              ? AppFileImage(
                                  path: coverFile.path,
                                  fit: BoxFit.cover,
                                  cacheWidth: 300,
                                  errorBuilder: (_, _, _) => Icon(Icons.broken_image, color: colors.mute),
                                )
                              : Icon(Icons.folder_rounded, size: 32, color: colors.primary),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${album.photos.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  // Album details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          album.title,
                          style: type.rowTitle(color: colors.ink),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          album.subtitle,
                          style: type.meta(color: colors.body),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          TimemarkFormatter.formatIndonesianFullDate(album.date),
                          style: type.caption(color: colors.mute),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.mute,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Layar Drill-Down Masuk ke Dalam Folder Tertentu
  Widget _buildAlbumDetailView(_GalleryAlbum album) {
    final colors = TiketColors.of(context);
    final type = TiketType.of(context);

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            TiketBand(
              leading: TiketIconButton(
                icon: Icons.arrow_back,
                semanticLabel: 'Kembali',
                onPressed: () {
                  setState(() {
                    _selectedAlbum = null;
                    _isMultiSelect = false;
                    _selectedImagePaths.clear();
                  });
                },
              ),
              actions: [
                if (!_isMultiSelect)
                  TiketPill(
                    label: 'Pilih',
                    kind: TiketPillKind.band,
                    height: 48,
                    onPressed: () {
                      setState(() {
                        _isMultiSelect = true;
                        _selectedImagePaths.clear();
                      });
                    },
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
                      style: TextStyle(
                        fontFamily: TiketType.fontFamily,
                        color: colors.onBand,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isMultiSelect = false;
                        _selectedImagePaths.clear();
                      });
                    },
                    child: Text(
                      'Batal',
                      style: TextStyle(
                        fontFamily: TiketType.fontFamily,
                        color: colors.bandCaption,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
              caption: _isMultiSelect
                  ? '${_selectedImagePaths.length} Terpilih'
                  : album.title,
              hero: Row(
                children: [
                  Text(
                    '${album.photos.length}',
                    style: type.hero(color: colors.onBand),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'foto · ${album.subtitle}',
                      style: type.heroLabel(color: colors.onBand),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildPhotoGrid(album.photos),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _isMultiSelect ? _buildBottomActionBar() : null,
    );
  }

  /// Reusable Grid Foto
  Widget _buildPhotoGrid(List<_GalleryPhotoItem> photos) {
    final colors = TiketColors.of(context);
    final type = TiketType.of(context);

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, _isMultiSelect ? 90 : 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
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
                onAnalyze: (base64) => AiVisionService.reanalyzePhoto(
                  imageBase64: base64,
                  konteks: item.title,
                ),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: colors.canvas,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: isSelected ? colors.primary : colors.hairline,
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AppFileImage(
                          path: file.path,
                          fit: BoxFit.cover,
                          cacheWidth: 600,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: colors.soft,
                            child: Icon(Icons.broken_image_rounded, color: colors.mute),
                          ),
                        ),
                        // Multi-select Checkbox Indicator
                        if (_isMultiSelect)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isSelected ? colors.primary : Colors.black.withValues(alpha: 0.45),
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
                          style: type.meta(color: colors.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type.caption(color: colors.body),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${TimemarkFormatter.formatIndonesianFullDate(item.timestamp)} ${TimemarkFormatter.formatClockTime(item.timestamp)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type.caption(color: colors.mute),
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
