import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/watermark_config.dart';

/// Bottom sheet modal mirroring the reference design:
/// - "Edit Templat" header with close button
/// - Live watermark preview at the top
/// - 8 toggle rows: Logo, Judul:Absensi, Styled Note, Tag, Waktu, Lokasi, Koordinat, Peta
/// - Trailing actions to edit text / pick logo
/// - "Selesai" primary button at the bottom
class WatermarkEditModal extends StatefulWidget {
  final WatermarkConfig initialConfig;
  final ValueChanged<WatermarkConfig> onConfigChanged;
  final Widget livePreview;

  const WatermarkEditModal({
    super.key,
    required this.initialConfig,
    required this.onConfigChanged,
    required this.livePreview,
  });

  @override
  State<WatermarkEditModal> createState() => _WatermarkEditModalState();
}

class _WatermarkEditModalState extends State<WatermarkEditModal> {
  late WatermarkConfig _config;
  late WatermarkElementToggles _toggles;
  String _customTitle = '';
  String _customNote = '';
  String _badgeTag = '';

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
    _toggles = widget.initialConfig.elements;
    _customTitle = widget.initialConfig.customTitle ?? '';
    _customNote = widget.initialConfig.customNote ?? '';
    _badgeTag = widget.initialConfig.badgeTag.isNotEmpty
        ? widget.initialConfig.badgeTag
        : 'Absensi';
  }

  void _applyChanges() {
    final updated = _config.copyWith(
      elements: _toggles,
      customTitle: _customTitle,
      customNote: _customNote,
      badgeTag: _badgeTag,
    );
    _config = updated;
    widget.onConfigChanged(updated);
  }

  Future<void> _pickLogoImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 300,
        imageQuality: 90,
      );
      if (picked != null) {
        final updated = _config.copyWith(
          logoImagePath: picked.path,
          elements: _toggles.copyWith(showLogo: true),
        );
        setState(() {
          _config = updated;
          _toggles = updated.elements;
        });
        widget.onConfigChanged(updated);
      }
    } catch (_) {}
  }

  void _editTitleDialog() {
    final controller = TextEditingController(text: _customTitle);
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('Ubah Judul Watermark', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Contoh: Absensi, Patroli, Briefing',
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                setState(() {
                  _customTitle = newTitle;
                });
                _applyChanges();
              }
              Navigator.of(dlgCtx).pop();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _editNoteDialog() {
    final controller = TextEditingController(text: _customNote);
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('Ubah Styled Note', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Catatan tambahan watermark',
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final newNote = controller.text.trim();
              setState(() {
                _customNote = newNote;
              });
              _applyChanges();
              Navigator.of(dlgCtx).pop();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _editBadgeTagDialog() {
    final controller = TextEditingController(text: _badgeTag);
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('Ubah Tag Singkatan', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'Contoh: Absensi, POS-01',
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final newTag = controller.text.trim().toUpperCase();
              if (newTag.isNotEmpty) {
                setState(() {
                  _badgeTag = newTag;
                });
                _applyChanges();
              }
              Navigator.of(dlgCtx).pop();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit Templat',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.8),

          // Scrollable content
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // 1. Live Preview Card (Dark background with live watermark rendered)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Center(
                    child: widget.livePreview,
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Text(
                    'ELEMEN WATERMARK',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),

                // 2. Toggles Section
                // Row 1: Logo
                _buildToggleRow(
                  label: 'Logo',
                  value: _toggles.showLogo,
                  onChanged: (v) {
                    setState(() => _toggles = _toggles.copyWith(showLogo: v));
                    _applyChanges();
                  },
                  trailingWidget: GestureDetector(
                    onTap: _pickLogoImage,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_config.logoImagePath != null &&
                              File(_config.logoImagePath!).existsSync())
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: Image.file(
                                File(_config.logoImagePath!),
                                width: 20,
                                height: 20,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: Container(
                                color: const Color(0xFF1E448D),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Image.asset(
                                  'foto/bssfotologo_transparent.png',
                                  width: 32,
                                  height: 18,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildDivider(),

                // Row 2: Judul:Absensi
                _buildToggleRow(
                  label: 'Judul: $_customTitle',
                  value: _toggles.showTitle,
                  onChanged: (v) {
                    setState(() => _toggles = _toggles.copyWith(showTitle: v));
                    _applyChanges();
                  },
                  trailingWidget: IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    onPressed: _editTitleDialog,
                  ),
                ),
                _buildDivider(),

                // Row 3: Styled Note
                _buildToggleRow(
                  label: 'Styled Note',
                  value: _toggles.showNote,
                  onChanged: (v) {
                    setState(() => _toggles = _toggles.copyWith(showNote: v));
                    _applyChanges();
                  },
                  trailingWidget: IconButton(
                    icon: const Icon(
                      Icons.edit_note_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    onPressed: _editNoteDialog,
                  ),
                ),
                _buildDivider(),

                // Row 4: Tag
                _buildToggleRow(
                  label: 'Tag',
                  value: _toggles.showBadgeTag,
                  onChanged: (v) {
                    setState(
                        () => _toggles = _toggles.copyWith(showBadgeTag: v));
                    _applyChanges();
                  },
                  trailingWidget: IconButton(
                    icon: const Icon(
                      Icons.label_outline_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    onPressed: _editBadgeTagDialog,
                  ),
                ),
                _buildDivider(),

                // Row 5: Waktu
                _buildToggleRow(
                  label: 'Waktu',
                  value: _toggles.showDateTime,
                  onChanged: (v) {
                    setState(
                        () => _toggles = _toggles.copyWith(showDateTime: v));
                    _applyChanges();
                  },
                  trailingWidget: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ),
                _buildDivider(),

                // Row 6: Lokasi
                _buildToggleRow(
                  label: 'Lokasi: $_badgeTag ...',
                  value: _toggles.showAddress,
                  onChanged: (v) {
                    setState(
                        () => _toggles = _toggles.copyWith(showAddress: v));
                    _applyChanges();
                  },
                  trailingWidget: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ),
                _buildDivider(),

                // Row 7: Koordinat
                _buildToggleRow(
                  label: 'Koordinat',
                  value: _toggles.showCoordinates,
                  onChanged: (v) {
                    setState(() =>
                        _toggles = _toggles.copyWith(showCoordinates: v));
                    _applyChanges();
                  },
                  trailingWidget: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ),
                _buildDivider(),

                // Row 8: Peta
                _buildToggleRow(
                  label: 'Peta',
                  value: _toggles.showMap,
                  onChanged: (v) {
                    setState(() => _toggles = _toggles.copyWith(showMap: v));
                    _applyChanges();
                  },
                  trailingWidget: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Bottom Selesai Button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Selesai',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    Widget? trailingWidget,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF10B981),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailingWidget,
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 0.6,
      indent: 20,
      endIndent: 20,
      color: Color(0xFFE2E8F0),
    );
  }
}
