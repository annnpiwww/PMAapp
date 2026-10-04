import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/template_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/template_repository.dart';

class TemplateEditorScreen extends StatefulWidget {
  final TemplateModel? existingTemplate;

  const TemplateEditorScreen({super.key, this.existingTemplate});

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _namaController;
  late TextEditingController _deskripsiController;
  late TemplateCategory _selectedCategory;
  late bool _wajibLokasi;
  late List<String> _sopCriteria;
  final TextEditingController _newCriterionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final t = widget.existingTemplate;
    _namaController = TextEditingController(text: t?.nama ?? '');
    _deskripsiController = TextEditingController(text: t?.deskripsi ?? '');
    _selectedCategory = t?.jenis ?? TemplateCategory.absensi;
    _wajibLokasi = t?.wajibLokasi ?? true;
    _sopCriteria = t != null ? List.from(t.sopCriteria) : [];
  }

  @override
  void dispose() {
    _namaController.dispose();
    _deskripsiController.dispose();
    _newCriterionController.dispose();
    super.dispose();
  }

  void _addCriterion() {
    final text = _newCriterionController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _sopCriteria.add(text);
        _newCriterionController.clear();
      });
    }
  }

  void _removeCriterion(int index) {
    setState(() {
      _sopCriteria.removeAt(index);
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_sopCriteria.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tambahkan minimal 1 kriteria SOP.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final user = AuthRepository.instance.currentUser;
    final isEditing = widget.existingTemplate != null;

    final template = TemplateModel(
      id: isEditing
          ? widget.existingTemplate!.id
          : 'tpl_${const Uuid().v4().substring(0, 8)}',
      nama: _namaController.text.trim(),
      deskripsi: _deskripsiController.text.trim(),
      jenis: _selectedCategory,
      wajibLokasi: _wajibLokasi,
      sopCriteria: _sopCriteria,
      contohFotoDescriptions: widget.existingTemplate?.contohFotoDescriptions ??
          ['Foto panduan referensi'],
      createdBy: isEditing
          ? widget.existingTemplate!.createdBy
          : (user?.nama ?? 'Supervisor'),
      updatedAt: DateTime.now(),
    );

    if (isEditing) {
      await TemplateRepository.instance.updateTemplate(template);
    } else {
      await TemplateRepository.instance.addTemplate(template);
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Template "${template.nama}" berhasil disimpan!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingTemplate != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Template SOP' : 'Buat Template SOP'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Simpan Template',
            onPressed: _handleSave,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Template Name
                  TextFormField(
                    controller: _namaController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Template SOP *',
                      hintText: 'Contoh: Absensi Masuk Shift Siang',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Nama template wajib diisi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Category Selector
                  DropdownButtonFormField<TemplateCategory>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Kategori Template *',
                    ),
                    items: TemplateCategory.values.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(c.displayName),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Description
                  TextFormField(
                    controller: _deskripsiController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Petunjuk / Deskripsi Pengambilan Foto',
                      hintText: 'Tuliskan panduan pengambilan foto di lapangan...',
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Wajib Lokasi Switch
                  Card(
                    child: SwitchListTile(
                      title: const Text(
                        'Wajib Koordinat GPS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'Jika GPS tidak aktif, foto ditandai Perlu Cek Manual.',
                        style: TextStyle(fontSize: 11),
                      ),
                      value: _wajibLokasi,
                      activeThumbColor: AppColors.primary,
                      onChanged: (val) => setState(() => _wajibLokasi = val),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Dynamic SOP Criteria Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Daftar Kriteria SOP (Pengecekan AI)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${_sopCriteria.length} Kriteria',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Add New Criterion Input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newCriterionController,
                          decoration: const InputDecoration(
                            hintText: 'Tambah kriteria SOP baru...',
                            isDense: true,
                          ),
                          onSubmitted: (_) => _addCriterion(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Tambah Kriteria',
                        child: ElevatedButton(
                          onPressed: _addCriterion,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(60, 46),
                          ),
                          child: const Icon(Icons.add, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // List of criteria items
                  if (_sopCriteria.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: const Center(
                        child: Text(
                          'Belum ada kriteria SOP. Tambahkan kriteria di atas.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                      ),
                    )
                  else
                    ..._sopCriteria.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final criterion = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${idx + 1}.',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                criterion,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: AppColors.danger),
                              tooltip: 'Hapus Kriteria',
                              onPressed: () => _removeCriterion(idx),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 24),

                  // Save Button
                  ElevatedButton.icon(
                    onPressed: _handleSave,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Simpan Template SOP'),
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
