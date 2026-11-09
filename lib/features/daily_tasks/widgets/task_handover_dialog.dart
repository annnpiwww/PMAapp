import 'package:flutter/material.dart';
import '../../../core/constants/tiket_colors.dart';
import '../../../core/widgets/tiket/tiket.dart';

class TaskHandoverDialog extends StatefulWidget {
  final String judul;
  final String lokasi;
  final String? pemilik;
  final List<String> teknisiOptions;
  final String judulDialog;
  final String tujuanLabel;
  final String tombolLabel;

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
    final colors = TiketColors.of(context);
    final error = _triedSubmit && _alasanCtrl.text.trim().isEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: colors.dialog,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.hairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.judulDialog,
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: colors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.judul,
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.body,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.pemilik == null || widget.pemilik!.isEmpty
                              ? widget.lokasi
                              : '${widget.lokasi} · sekarang di ${widget.pemilik}',
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 12,
                            color: colors.body,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Divider(height: 1, thickness: 1, color: colors.hairline),
                        const SizedBox(height: 18),

                        _label(widget.tujuanLabel, colors.body),
                        const SizedBox(height: 6),
                        _opsi(
                          nama: 'Terbuka (siapa pun boleh ambil)',
                          ket: 'Masuk daftar Tugas Terbuka shift berikutnya',
                          selected: _penerus.isEmpty,
                          onTap: () => setState(() => _penerus = ''),
                          colors: colors,
                          height: 52,
                        ),
                        for (final t in widget.teknisiOptions) ...[
                          Divider(height: 1, thickness: 1, color: colors.hairline),
                          _opsi(
                            nama: t,
                            selected: _penerus == t,
                            onTap: () => setState(() => _penerus = t),
                            colors: colors,
                            height: 48,
                          ),
                        ],

                        const SizedBox(height: 24),
                        _label('Alasan Serah Terima', colors.body),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: TaskHandoverDialog.alasanCepat.map((a) {
                            final selected = _alasanCtrl.text.trim() == a;
                            return SizedBox(
                              height: 44,
                              child: InkWell(
                                onTap: () => setState(() {
                                  _alasanCtrl.text = selected ? '' : a;
                                }),
                                borderRadius: BorderRadius.circular(22),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: selected ? colors.primary : colors.canvas,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: selected ? colors.primary : colors.mute,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (selected) ...[
                                        Icon(Icons.check_rounded, size: 16, color: colors.white),
                                        const SizedBox(width: 6),
                                      ],
                                      Text(
                                        a,
                                        style: TextStyle(
                                          fontFamily: TiketType.fontFamily,
                                          fontSize: 12,
                                          color: selected ? colors.white : colors.ink,
                                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: colors.soft,
                            border: Border(
                              bottom: BorderSide(
                                color: error ? colors.danger : colors.body,
                                width: 2.0,
                              ),
                            ),
                          ),
                          child: TextField(
                            controller: _alasanCtrl,
                            maxLines: 3,
                            minLines: 1,
                            onChanged: (_) => setState(() {}),
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              color: colors.ink,
                              fontSize: 14,
                              height: 1.4,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              hintText: 'Tulis alasan singkat atau pilih salah satu di atas',
                              hintStyle: TextStyle(
                                fontFamily: TiketType.fontFamily,
                                color: colors.body,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        if (error) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Alasan wajib diisi',
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colors.danger,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    children: [
                      if (_gagal) ...[
                        Text(
                          'Gagal menyimpan, periksa sinyal lalu coba lagi.',
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.danger,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: _mengirim
                            ? Container(
                                height: 52,
                                decoration: ShapeDecoration(
                                  shape: const StadiumBorder(),
                                  color: colors.primary.withValues(alpha: 0.6),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colors.onPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Menyimpan...',
                                      style: TextStyle(
                                        fontFamily: TiketType.fontFamily,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: colors.onPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : TiketPill(
                                label: widget.tombolLabel,
                                kind: TiketPillKind.primary,
                                height: 52,
                                expand: true,
                                icon: Icons.swap_horiz_rounded,
                                onPressed: _submit,
                              ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: TiketPill(
                          label: 'Batal',
                          kind: TiketPillKind.secondary,
                          height: 48,
                          expand: true,
                          onPressed: _mengirim ? null : () => Navigator.pop(context),
                        ),
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
        text,
        style: TextStyle(
          fontFamily: TiketType.fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      );

  Widget _opsi({
    required String nama,
    String? ket,
    required bool selected,
    required VoidCallback onTap,
    required TiketColors colors,
    required double height,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? colors.primary.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? colors.primary : colors.mute,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nama,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: TiketType.fontFamily,
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: colors.ink,
                    ),
                  ),
                  if (ket != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      ket,
                      style: TextStyle(
                        fontFamily: TiketType.fontFamily,
                        fontSize: 10.5,
                        color: colors.body,
                      ),
                    ),
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
