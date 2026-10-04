import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/watermark_config.dart';

class WatermarkCustomizerModal extends StatefulWidget {
  final WatermarkConfig initialConfig;
  final ValueChanged<WatermarkConfig> onConfigChanged;

  const WatermarkCustomizerModal({
    super.key,
    required this.initialConfig,
    required this.onConfigChanged,
  });

  @override
  State<WatermarkCustomizerModal> createState() =>
      _WatermarkCustomizerModalState();
}

class _WatermarkCustomizerModalState extends State<WatermarkCustomizerModal> {
  late TextEditingController _badgeTagController;
  late Color _selectedColor;
  String? _logoImagePath;
  late bool _showLocationOnCamera;
  late bool _showLocationOnResult;

  final ImagePicker _picker = ImagePicker();

  static const List<Color> _palette = [
    Color(0xFF1E489C), // BSS Blue
    Color(0xFFF59E0B), // Amber / Gold
    Color(0xFF3B82F6), // Sky Blue
    Color(0xFF10B981), // Emerald Green
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEF4444), // Red
    Color(0xFF0F172A), // Dark Slate
  ];

  @override
  void initState() {
    super.initState();
    _badgeTagController =
        TextEditingController(text: widget.initialConfig.badgeTag);
    _selectedColor = widget.initialConfig.badgeColor;
    _logoImagePath = widget.initialConfig.logoImagePath;
    _showLocationOnCamera = widget.initialConfig.showLocationOnCamera;
    _showLocationOnResult = widget.initialConfig.showLocationOnResult;
  }

  @override
  void dispose() {
    _badgeTagController.dispose();
    super.dispose();
  }

  Future<void> _pickLogoFromGallery() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 300,
        imageQuality: 90,
      );
      if (file != null) {
        setState(() {
          _logoImagePath = file.path;
        });
        _applyChanges();
      }
    } catch (_) {}
  }

  void _applyChanges() {
    final newConfig = widget.initialConfig.copyWith(
      badgeTag: _badgeTagController.text.trim().isEmpty
          ? 'Absensi'
          : _badgeTagController.text.trim(),
      badgeColor: _selectedColor,
      logoImagePath: _logoImagePath,
      showLocationOnCamera: _showLocationOnCamera,
      showLocationOnResult: _showLocationOnResult,
    );
    widget.onConfigChanged(newConfig);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag indicator handle
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Modal Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.style_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Kustomisasi Watermark',
                      style: TextStyle(fontFamily: 'PlusJakartaSans', 
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _badgeTagController.text = 'Absensi';
                      _selectedColor = const Color(0xFFF59E0B);
                      _logoImagePath = null;
                      _showLocationOnCamera = true;
                      _showLocationOnResult = true;
                    });
                    _applyChanges();
                  },
                  child: const Text('Reset Watermark'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // LIVE CARD PREVIEW
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _selectedColor.withValues(alpha: 0.6), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: _logoImagePath != null &&
                                    File(_logoImagePath!).existsSync()
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.file(
                                      File(_logoImagePath!),
                                      fit: BoxFit.contain,
                                    ),
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.asset(
                                      'foto/bssfotologo.jpg',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '14:20:08',
                            style: TextStyle(fontFamily: 'PlusJakartaSans', 
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _selectedColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _badgeTagController.text.trim().isEmpty
                              ? 'Absensi'
                              : _badgeTagController.text.trim(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_showLocationOnCamera) ...[
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 12, color: _selectedColor),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            'Lokasi Operasional BSS Parking',
                            style: TextStyle(fontSize: 10, color: Colors.white70),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // --- 1. LOGO PERUSAHAAN ---
            const Text(
              'Logo Perusahaan (Galeri):',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _logoImagePath != null &&
                            File(_logoImagePath!).existsSync()
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.file(
                              File(_logoImagePath!),
                              fit: BoxFit.contain,
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.asset(
                              'foto/bssfotologo.jpg',
                              fit: BoxFit.contain,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _logoImagePath != null
                              ? 'Logo Kustom Terpasang'
                              : 'Logo Standar (BSS PARKING)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Pilih file JPG/PNG untuk mengganti logo',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _pickLogoFromGallery,
                    icon: const Icon(Icons.photo_library_rounded, size: 14),
                    label: const Text('Galeri', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(70, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // --- 2. TAG BADGE CARD ---
            TextField(
              controller: _badgeTagController,
              decoration: const InputDecoration(
                labelText: 'Teks Tag / Badge Watermark',
                hintText: 'Contoh: Absensi, MEGAMAS, GATE 1',
                isDense: true,
              ),
              onChanged: (_) {
                setState(() {});
                _applyChanges();
              },
            ),
            const SizedBox(height: 14),

            // --- 3. COLOR PALETTE SELECTOR ---
            const Text(
              'Warna Aksen Badge:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: _palette.map((color) {
                final isSelected = _selectedColor.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedColor = color);
                    _applyChanges();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // --- 4. TOGGLE TAMPILKAN LOKASI ---
            const Text(
              'Pengaturan Lokasi:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Tampilkan Lokasi di Kamera',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Alamat & GPS pada watermark viewfinder',
                      style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                    ),
                    value: _showLocationOnCamera,
                    onChanged: (val) {
                      setState(() => _showLocationOnCamera = val);
                      _applyChanges();
                    },
                    dense: true,
                  ),
                  const Divider(height: 1, color: AppColors.cardBorder),
                  SwitchListTile(
                    title: const Text(
                      'Tampilkan Lokasi di Hasil Foto',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Alamat & koordinat GPS pada foto yang tersimpan',
                      style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                    ),
                    value: _showLocationOnResult,
                    onChanged: (val) {
                      setState(() => _showLocationOnResult = val);
                      _applyChanges();
                    },
                    dense: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Simpan & Tutup'),
            ),
          ],
        ),
      ),
    );
  }
}
