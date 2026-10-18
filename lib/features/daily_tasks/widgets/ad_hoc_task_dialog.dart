import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/theme_service.dart';
import '../../../data/services/daily_task_service.dart';
import '../../../data/services/location_service.dart';

/// Dialog mencatat kerjaan dadakan yang tidak diberikan SPV di pagi hari
/// (contoh: kabel putus di akhir shift). Tugas langsung masuk daftar hari itu,
/// jadi bisa dikerjakan, dilaporkan, dan diserahterimakan seperti tugas biasa.
class AdHocTaskDialog extends StatefulWidget {
  final String teknisiNama;
  final String tanggal;
  final List<PosLocation> lokasiOptions;
  final PosLocation? lokasiAwal;

  const AdHocTaskDialog({
    super.key,
    required this.teknisiNama,
    required this.tanggal,
    required this.lokasiOptions,
    this.lokasiAwal,
  });

  /// Hasil `true` = tugas tersimpan.
  static Future<bool?> show(
    BuildContext context, {
    required String teknisiNama,
    required String tanggal,
    required List<PosLocation> lokasiOptions,
    PosLocation? lokasiAwal,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdHocTaskDialog(
        teknisiNama: teknisiNama,
        tanggal: tanggal,
        lokasiOptions: lokasiOptions,
        lokasiAwal: lokasiAwal,
      ),
    );
  }

  @override
  State<AdHocTaskDialog> createState() => _AdHocTaskDialogState();
}

class _AdHocTaskDialogState extends State<AdHocTaskDialog> {
  final _judulCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();
  String? _posId;
  bool _triedSubmit = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final awal = widget.lokasiAwal;
    _posId = (awal != null && widget.lokasiOptions.any((p) => p.posId == awal.posId))
        ? awal.posId
        : (widget.lokasiOptions.isNotEmpty ? widget.lokasiOptions.first.posId : null);
  }

  @override
  void dispose() {
    _judulCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final judul = _judulCtrl.text.trim();
    if (judul.isEmpty || _posId == null) {
      setState(() => _triedSubmit = true);
      return;
    }
    final lokasi = widget.lokasiOptions.firstWhere((p) => p.posId == _posId);
    setState(() => _saving = true);
    final task = await DailyTaskService.createTask(
      tanggal: widget.tanggal,
      teknisiNama: widget.teknisiNama,
      posName: lokasi.posName,
      posTag: lokasi.locationTag,
      judul: judul,
      deskripsi: _catatanCtrl.text.trim(),
    );
    if (!mounted) return;
    Navigator.pop(context, task != null);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.isDarkMode(context);
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textHead = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC);
    final inputBorder = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final judulKosong = _judulCtrl.text.trim().isEmpty && _triedSubmit;
    final tanpaLokasi = widget.lokasiOptions.isEmpty;

    InputDecoration decoration({
      String? hint,
      String? error,
    }) {
      return InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: textSub, fontSize: 12),
        filled: true,
        fillColor: inputBg,
        errorText: error,
        errorStyle: const TextStyle(fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: error != null ? AppColors.danger : inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      );
    }

    return AlertDialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.add_task_rounded, size: 20, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Catat Kerjaan',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textHead),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Kerjaan dadakan yang bukan dari SPV. Setelah disimpan, masuk daftar hari ini dan bisa diserahterimakan.',
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
              'Kerjaan apa? *',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textHead),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _judulCtrl,
              autofocus: true,
              maxLines: 2,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: textHead, fontSize: 12.5),
              decoration: decoration(
                hint: 'Contoh: kabel sensor putus di Gate 1',
                error: judulKosong ? 'Kerjaan wajib diisi' : null,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Lokasi *',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textHead),
            ),
            const SizedBox(height: 8),
            if (tanpaLokasi)
              const Text(
                'Belum ada data lokasi. Sinkronkan dulu di menu Lokasi.',
                style: TextStyle(fontSize: 12, color: AppColors.danger),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: inputBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _posId,
                    isExpanded: true,
                    dropdownColor: inputBg,
                    style: TextStyle(color: textHead, fontSize: 12.5),
                    items: widget.lokasiOptions
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.posId,
                            child: Text(
                              '${p.posName} (${p.locationTag})',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: textHead, fontSize: 12.5),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _posId = val),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Text(
              'Catatan (opsional)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textHead),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _catatanCtrl,
              maxLines: 3,
              style: TextStyle(color: textHead, fontSize: 12.5),
              decoration: decoration(
                hint: 'Misal: kabel putus jam 21:10, sementara disambung dulu',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text('Batal', style: TextStyle(color: textSub)),
        ),
        ElevatedButton(
          onPressed: (_saving || tanpaLokasi) ? null : _simpan,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
