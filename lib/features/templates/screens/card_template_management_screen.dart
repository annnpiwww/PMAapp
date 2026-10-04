import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/watermark_config.dart';
import '../../../data/services/storage_service.dart';

class CardTemplateItem {
  final String id;
  final String title;
  final String badgeTag;
  final Color badgeColor;
  final String? logoImagePath;
  final bool isShiftTracker;
  final double? scale;
  final double? positionX;
  final double? positionY;

  const CardTemplateItem({
    required this.id,
    required this.title,
    required this.badgeTag,
    required this.badgeColor,
    this.logoImagePath,
    this.isShiftTracker = false,
    this.scale,
    this.positionX,
    this.positionY,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'badgeTag': badgeTag,
        'badgeColorValue': badgeColor.toARGB32(),
        'logoImagePath': logoImagePath,
        'isShiftTracker': isShiftTracker,
        if (scale != null) 'scale': scale,
        if (positionX != null) 'positionX': positionX,
        if (positionY != null) 'positionY': positionY,
      };

  factory CardTemplateItem.fromJson(Map<String, dynamic> json) =>
      CardTemplateItem(
        id: json['id'] as String,
        title: json['title'] as String,
        badgeTag: json['badgeTag'] as String? ?? 'Absensi',
        badgeColor: Color(json['badgeColorValue'] as int? ?? 0xFFF59E0B),
        logoImagePath: json['logoImagePath'] as String?,
        isShiftTracker: json['isShiftTracker'] as bool? ?? false,
        scale: (json['scale'] as num?)?.toDouble(),
        positionX: (json['positionX'] as num?)?.toDouble(),
        positionY: (json['positionY'] as num?)?.toDouble(),
      );
}

class CardTemplateManagementScreen extends StatefulWidget {
  final ValueChanged<WatermarkConfig>? onTemplateApplied;

  const CardTemplateManagementScreen({super.key, this.onTemplateApplied});

  @override
  State<CardTemplateManagementScreen> createState() =>
      _CardTemplateManagementScreenState();
}

class _CardTemplateManagementScreenState
    extends State<CardTemplateManagementScreen> {
  List<CardTemplateItem> _templates = [];
  final ImagePicker _picker = ImagePicker();

  static const List<Color> _palette = [
    Color(0xFFF59E0B), // Amber / Gold
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Emerald Green
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEF4444), // Red
    Color(0xFF0F172A), // Dark Slate
  ];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  void _loadTemplates() {
    final saved = StorageService.getCardTemplates();
    if (saved != null && saved.isNotEmpty) {
      _templates = saved.map((e) => CardTemplateItem.fromJson(e)).toList();
      bool needsSave = false;
      // Migrasikan template lama PBM/PKM ke Absensi dengan ukuran 50% di kiri bawah
      for (int i = 0; i < _templates.length; i++) {
        if (_templates[i].badgeTag == 'PBM/PKM' ||
            _templates[i].title.contains('PBM / PKM')) {
          _templates[i] = CardTemplateItem(
            id: _templates[i].id,
            title: 'Absensi',
            badgeTag: 'Absensi',
            badgeColor: _templates[i].badgeColor,
            logoImagePath: _templates[i].logoImagePath,
            isShiftTracker: _templates[i].isShiftTracker,
            scale: 0.5,
            positionX: 0.0,
            positionY: 1.0,
          );
          needsSave = true;
        }
      }
      // Pastikan template Shift Tracker selalu ada
      if (!_templates.any((t) => t.isShiftTracker)) {
        _templates.add(
          const CardTemplateItem(
            id: 'tpl_card_shift_tracker',
            title: 'BSS Shift Tracker (Masuk, Pulang & Durasi Kerja)',
            badgeTag: 'Time Out',
            badgeColor: Color(0xFFF59E0B),
            isShiftTracker: true,
          ),
        );
        needsSave = true;
      }
      if (needsSave) {
        _saveTemplates();
      }
    } else {
      _templates = [
        const CardTemplateItem(
          id: 'tpl_card_01',
          title: 'Absensi',
          badgeTag: 'Absensi',
          badgeColor: Color(0xFFF59E0B),
          scale: 0.5,
          positionX: 0.0,
          positionY: 1.0,
        ),
        const CardTemplateItem(
          id: 'tpl_card_shift_tracker',
          title: 'BSS Shift Tracker (Masuk, Pulang & Durasi Kerja)',
          badgeTag: 'Time Out',
          badgeColor: Color(0xFFF59E0B),
          isShiftTracker: true,
        ),
      ];
      _saveTemplates();
    }
  }

  Future<void> _saveTemplates() async {
    await StorageService.saveCardTemplates(
        _templates.map((e) => e.toJson()).toList());
  }

  void _showFormDialog({CardTemplateItem? existing}) {
    final isEditing = existing != null;
    final titleController =
        TextEditingController(text: existing?.title ?? '');
    final tagController =
        TextEditingController(text: existing?.badgeTag ?? 'Absensi');
    Color selectedColor = existing?.badgeColor ?? const Color(0xFFF59E0B);
    String? logoPath = existing?.logoImagePath;

    showDialog(
      context: context,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              title: Text(isEditing
                  ? 'Edit Template Card'
                  : 'Tambah Template Card Baru'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Template *',
                        hintText: 'Misal: Template Gate Barat',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: tagController,
                      decoration: const InputDecoration(
                        labelText: 'Teks Badge Tag *',
                        hintText: 'Absensi',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Pilih Warna Aksen & Badge:',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: _palette.map((c) {
                        final isSel = selectedColor.toARGB32() == c.toARGB32();
                        return GestureDetector(
                          onTap: () => setDlgState(() => selectedColor = c),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel ? Colors.black : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: isSel
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 15)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Gambar Logo (JPG / PNG):',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: logoPath != null &&
                                  File(logoPath!).existsSync()
                              ? Image.file(File(logoPath!), fit: BoxFit.contain)
                              : const Icon(Icons.image, size: 18, color: Colors.grey),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () async {
                            final file = await _picker.pickImage(
                                source: ImageSource.gallery);
                            if (file != null) {
                              setDlgState(() => logoPath = file.path);
                            }
                          },
                          icon: const Icon(Icons.photo_library, size: 15),
                          label: const Text('Pilih dari Galeri',
                              style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dlgCtx).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty ||
                        tagController.text.trim().isEmpty) {
                      return;
                    }

                    final item = CardTemplateItem(
                      id: isEditing
                          ? existing.id
                          : 'tpl_card_${const Uuid().v4().substring(0, 6)}',
                      title: titleController.text.trim(),
                      badgeTag: tagController.text.trim().toUpperCase(),
                      badgeColor: selectedColor,
                      logoImagePath: logoPath,
                    );

                    if (isEditing) {
                      final idx =
                          _templates.indexWhere((t) => t.id == existing.id);
                      if (idx != -1) _templates[idx] = item;
                    } else {
                      _templates.insert(0, item);
                    }

                    await _saveTemplates();
                    setState(() {});

                    if (dlgCtx.mounted) {
                      Navigator.of(dlgCtx).pop();
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Template Card "${item.title}" tersimpan!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(CardTemplateItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Template Card?'),
        content: Text('Hapus template "${item.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              _templates.removeWhere((t) => t.id == item.id);
              await _saveTemplates();
              setState(() {});
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Template Card'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Tambah Template Card',
            onPressed: () => _showFormDialog(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _templates.length,
          separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final t = _templates[index];

            return Card(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                leading: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: t.badgeColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    t.badgeTag,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                title: Text(
                  t.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Tag: ${t.badgeTag} • Logo: ${t.logoImagePath != null ? "Kustom" : "BSS Bawaan"}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _showFormDialog(existing: t),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: AppColors.danger),
                      onPressed: () => _confirmDelete(t),
                    ),
                  ],
                ),
                onTap: () {
                  final currentConfig = StorageService.getWatermarkConfig();
                  final config = currentConfig.copyWith(
                    badgeTag: t.badgeTag,
                    badgeColor: t.badgeColor,
                    logoImagePath: t.logoImagePath,
                    isShiftTracker: t.isShiftTracker,
                    scale: t.scale ?? currentConfig.scale,
                    positionX: t.positionX ?? currentConfig.positionX,
                    positionY: t.positionY ?? currentConfig.positionY,
                  );
                  StorageService.saveWatermarkConfig(config);
                  widget.onTemplateApplied?.call(config);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Template Card "${t.title}" diterapkan!'),
                      backgroundColor: AppColors.primary,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                  Navigator.of(context).pop();
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
