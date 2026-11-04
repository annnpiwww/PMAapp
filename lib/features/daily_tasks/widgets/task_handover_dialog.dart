import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/theme_service.dart';

/// Bottom sheet serah terima tugas yang belum selesai ke shift berikutnya.
/// Dipakai teknisi ("Belum Selesai & Serah Terima") maupun SPV ("Alihkan Tugas").
class TaskHandoverDialog extends StatefulWidget {
  final String judul;
  final String lokasi;
  final String? pemilik;
  final List<String> teknisiOptions;
  final String judulDialog;
  final String tujuanLabel;
  final String tombolLabel;

  /// Kalau diisi, proses pengalihan dikerjakan di dalam sheet supaya ada
  /// status loading dan tidak bisa dikirim dua kali.
  final Future<bool> Function(String alasan, String penerus)? onSubmit;

  const TaskHandoverDialog({
    super.key,
    required this.judul,
    required this.lokasi,
    this.pemilik,
    required this.teknisiOptions,
    this.judulDialog = 'Belum Selesai & Serah Terima',
    this.tujuanLabel = 'Lanjut ke Teknisi',
    this.tombolLabel = 'Serahkan Tugas',
    this.onSubmit,
  });

  static const List<String> alasanCepat = [
    'Waktu habis (akhir shift)',
    'Material belum datang',
    'Hujan / kondisi gelap',
    'Alat kurang',
    'Butuh 2 orang',
    'Lokasi terkunci',
  ];

  /// Hasil sheet: alasan wajib, penerus kosong = dilepas ke daftar terbuka.
  static Future<({String alasan, String penerus})?> show(
    BuildContext context, {
    required String judul,
    required String lokasi,
    String? pemilik,
    required List<String> teknisiOptions,
    String judulDialog = 'Belum Selesai & Serah Terima',
    String tujuanLabel = 'Lanjut ke Teknisi',
    String tombolLabel = 'Serahkan Tugas',
    Future<bool> Function(String alasan, String penerus)? onSubmit,
  }) {
    return showModalBottomSheet<({String alasan, String penerus})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskHandoverDialog(
        judul: judul,
        lokasi: lokasi,
        pemilik: pemilik,
        teknisiOptions: teknisiOptions,
        judulDialog: judulDialog,
        tujuanLabel: tujuanLabel,
        tombolLabel: tombolLabel,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<TaskHandoverDialog> createState() => _TaskHandoverDialogState();
}

class _TaskHandoverDialogState extends State<TaskHandoverDialog> {
  final _alasanCtrl = TextEditingController();
  String _penerus = '';
  bool _triedSubmit = false;
  bool _mengirim = false;
  bool _gagal = false;

  @override
  void dispose() {
    _alasanCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final alasan = _alasanCtrl.text.trim();
    if (alasan.isEmpty) {
      setState(() => _triedSubmit = true);
      return;
    }
    if (widget.onSubmit == null) {
      Navigator.pop(context, (alasan: alasan, penerus: _penerus));
      return;
    }
    setState(() {
      _mengirim = true;
      _gagal = false;
    });
    final ok = await widget.onSubmit!(alasan, _penerus);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, (alasan: alasan, penerus: _penerus));
    } else {
      setState(() {
        _mengirim = false;
        _gagal = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.isDarkMode(context);
    final bg = isDark ? const Color(0xFF111827) : Colors.white;
    final line = isDark ? const Color(0xFF1E293B) : const Color(0xFFE5E1D8);
    final head = isDark ? Colors.white : const Color(0xFF111827);
    final sub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final pilihanBg = isDark ? AppColors.primary.withValues(alpha: 0.20) : const Color(0xFFF1F5FE);
    final radioOff = isDark ? const Color(0xFF475569) : const Color(0xFFCFCABF);
    final error = _triedSubmit && _alasanCtrl.text.trim().isEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : const Color(0xFFDDD8CD), borderRadius: BorderRadius.circular(2)),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.judulDialog,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: head,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(widget.judul, style: TextStyle(fontSize: 12, color: sub, height: 1.35)),
                        Text(
                          widget.pemilik == null || widget.pemilik!.isEmpty
                              ? widget.lokasi
                              : '${widget.lokasi} · sekarang di ${widget.pemilik}',
                          style: TextStyle(fontSize: 11, color: sub),
                        ),
                        const SizedBox(height: 16),
                        Divider(height: 1, thickness: 1, color: line),
                        const SizedBox(height: 18),

                        _label(widget.tujuanLabel, sub),
                        const SizedBox(height: 2),
                        _opsi(
                          nama: 'Terbuka (siapa pun boleh ambil)',
                          ket: 'Masuk daftar Tugas Terbuka shift berikutnya',
                          selected: _penerus.isEmpty,
                          onTap: () => setState(() => _penerus = ''),
                          line: line,
                          head: head,
                          sub: sub,
                          pilihanBg: pilihanBg,
                          radioOff: radioOff,
                        ),
                        for (final (i, t) in widget.teknisiOptions.indexed) ...[
                          if (i == 0) Divider(height: 1, thickness: 1, color: line),
                          _opsi(
                            nama: t,
                            selected: _penerus == t,
                            onTap: () => setState(() => _penerus = t),
                            line: line,
                            head: head,
                            sub: sub,
                            pilihanBg: pilihanBg,
                            radioOff: radioOff,
                          ),
                          if (i != widget.teknisiOptions.length - 1) Divider(height: 1, thickness: 1, color: line),
                        ],

                        const SizedBox(height: 24),
                        _label('Alasan Serah Terima', sub),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: TaskHandoverDialog.alasanCepat.map((a) {
                            final selected = _alasanCtrl.text.trim() == a;
                            return InkWell(
                              onTap: () => setState(() {
                                _alasanCtrl.text = selected ? '' : a;
                              }),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                decoration: BoxDecoration(
                                  color: selected ? AppColors.accent.withValues(alpha: 0.10) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: selected ? AppColors.accent : line),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (selected) ...[
                                      const Icon(Icons.check_rounded, size: 14, color: AppColors.accent),
                                      const SizedBox(width: 5),
                                    ],
                                    Text(
                                      a,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: selected ? AppColors.accent : head,
                                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.only(bottom: 9),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: error ? AppColors.danger : line, width: 1)),
                          ),
                          child: TextField(
                            controller: _alasanCtrl,
                            maxLines: 3,
                            minLines: 1,
                            onChanged: (_) => setState(() {}),
                            style: TextStyle(color: head, fontSize: 13.5, height: 1.4),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: false,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              hintText: 'Tulis alasan singkat atau pilih salah satu di atas',
                              hintStyle: TextStyle(color: sub, fontSize: 13),
                            ),
                          ),
                        ),
                        if (error) ...[
                          const SizedBox(height: 6),
                          const Text('Alasan wajib diisi', style: TextStyle(fontSize: 11, color: AppColors.danger)),
                        ],
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                  child: Column(
                    children: [
                      if (_gagal) ...[
                        const Text(
                          'Gagal menyimpan, periksa sinyal lalu coba lagi.',
                          style: TextStyle(fontSize: 11.5, color: AppColors.danger),
                        ),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _mengirim ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.55),
                            disabledForegroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _mengirim
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                    SizedBox(width: 10),
                                    Text('Menyimpan...', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.swap_horiz_rounded, size: 18),
                                    const SizedBox(width: 8),
                                    Text(widget.tombolLabel, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                        ),
                      ),
                      TextButton(
                        onPressed: _mengirim ? null : () => Navigator.pop(context),
                        child: Text('Batal', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: sub)),
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
  }

  Widget _label(String text, Color color) => Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 9.5, letterSpacing: 1.1, fontWeight: FontWeight.w600, color: color),
      );

  Widget _opsi({
    required String nama,
    String? ket,
    required bool selected,
    required VoidCallback onTap,
    required Color line,
    required Color head,
    required Color sub,
    required Color pilihanBg,
    required Color radioOff,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? pilihanBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? AppColors.primary : radioOff,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nama,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: head,
                    ),
                  ),
                  if (ket != null) ...[
                    const SizedBox(height: 1),
                    Text(ket, style: TextStyle(fontSize: 10.5, color: sub)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
