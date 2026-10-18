import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/theme_service.dart';

/// Dialog serah terima tugas yang belum selesai ke shift berikutnya.
/// Dipakai teknisi ("Belum Selesai & Serah Terima") maupun SPV ("Alihkan Tugas").
class TaskHandoverDialog extends StatefulWidget {
  final String judul;
  final String lokasi;
  final List<String> teknisiOptions;
  final String judulDialog;

  const TaskHandoverDialog({
    super.key,
    required this.judul,
    required this.lokasi,
    required this.teknisiOptions,
    this.judulDialog = 'Belum Selesai & Serah Terima',
  });

  static const List<String> alasanCepat = [
    'Material belum datang',
    'Hujan / kondisi gelap',
    'Alat kurang',
    'Waktu habis (akhir shift)',
    'Lokasi terkunci',
    'Butuh 2 orang',
  ];

  /// Hasil dialog: alasan wajib, penerus kosong = dilepas ke daftar terbuka.
  static Future<({String alasan, String penerus})?> show(
    BuildContext context, {
    required String judul,
    required String lokasi,
    required List<String> teknisiOptions,
    String judulDialog = 'Belum Selesai & Serah Terima',
  }) {
    return showDialog<({String alasan, String penerus})>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TaskHandoverDialog(
        judul: judul,
        lokasi: lokasi,
        teknisiOptions: teknisiOptions,
        judulDialog: judulDialog,
      ),
    );
  }

  @override
  State<TaskHandoverDialog> createState() => _TaskHandoverDialogState();
}

class _TaskHandoverDialogState extends State<TaskHandoverDialog> {
  final _alasanCtrl = TextEditingController();
  String _penerus = '';

  @override
  void dispose() {
    _alasanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.isDarkMode(context);
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textHead = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC);
    final inputBorder = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final error =
        _alasanCtrl.text.trim().isEmpty && _triedSubmit;

    return AlertDialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_late_outlined, size: 20, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.judulDialog,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textHead),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.judul}\n${widget.lokasi}',
            style: TextStyle(fontSize: 11.5, color: textSub, height: 1.35),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Kenapa belum selesai? *',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textHead),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: TaskHandoverDialog.alasanCepat.map((a) {
                final selected = _alasanCtrl.text.trim() == a;
                return ChoiceChip(
                  label: Text(a, style: const TextStyle(fontSize: 11)),
                  selected: selected,
                  onSelected: (_) => setState(() => _alasanCtrl.text = a),
                  backgroundColor: inputBg,
                  selectedColor: AppColors.accent.withValues(alpha: 0.2),
                  side: BorderSide(color: selected ? AppColors.accent : inputBorder),
                  labelStyle: TextStyle(
                    color: selected ? AppColors.accent : textHead,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _alasanCtrl,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: textHead, fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'Tulis alasan singkat atau pilih salah satu di atas',
                hintStyle: TextStyle(color: textSub, fontSize: 12),
                filled: true,
                fillColor: inputBg,
                errorText: error ? 'Alasan wajib diisi' : null,
                errorStyle: const TextStyle(fontSize: 11),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: error ? AppColors.danger : inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Lanjut ke teknisi mana?',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textHead),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: inputBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _penerus,
                  isExpanded: true,
                  dropdownColor: inputBg,
                  style: TextStyle(color: textHead, fontSize: 12.5),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(
                        'Terbuka — siapa pun boleh ambil',
                        style: TextStyle(color: textSub, fontSize: 12.5),
                      ),
                    ),
                    ...widget.teknisiOptions.map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t, style: TextStyle(color: textHead, fontSize: 12.5)),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _penerus = val ?? ''),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Batal', style: TextStyle(color: textSub)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  bool _triedSubmit = false;

  void _submit() {
    final alasan = _alasanCtrl.text.trim();
    if (alasan.isEmpty) {
      setState(() => _triedSubmit = true);
      return;
    }
    Navigator.pop(context, (alasan: alasan, penerus: _penerus));
  }
}
