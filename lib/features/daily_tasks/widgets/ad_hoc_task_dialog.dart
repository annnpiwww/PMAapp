import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/tiket_colors.dart';
import '../../../core/widgets/tiket/tiket_bottom_bar.dart';
import '../../../core/widgets/tiket/tiket_dropdown_field.dart';
import '../../../core/widgets/tiket/tiket_picker_dialog.dart';
import '../../../core/widgets/tiket/tiket_pill.dart';
import '../../../core/widgets/tiket/tiket_segmented.dart';
import '../../../data/models/error_report.dart';
import '../../../data/services/daily_task_service.dart';
import '../../../data/services/error_ticket_service.dart';
import '../../../data/services/location_service.dart';

/// Modal bottom sheet mencatat kerjaan dadakan atau laporan error dari Telegram.
class AdHocTaskDialog extends StatefulWidget {
  final String teknisiNama;
  final String tanggal;
  final List<PosLocation> lokasiOptions;
  final PosLocation? lokasiAwal;
  final bool startInErrorMode;

  const AdHocTaskDialog({
    super.key,
    required this.teknisiNama,
    required this.tanggal,
    required this.lokasiOptions,
    this.lokasiAwal,
    this.startInErrorMode = false,
  });

  /// Hasil `null` = cancelled, `true` = tugas tersimpan, `false` = gagal simpan.
  static Future<bool?> show(
    BuildContext context, {
    required String teknisiNama,
    required String tanggal,
    required List<PosLocation> lokasiOptions,
    PosLocation? lokasiAwal,
    bool startInErrorMode = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdHocTaskDialog(
        teknisiNama: teknisiNama,
        tanggal: tanggal,
        lokasiOptions: lokasiOptions,
        lokasiAwal: lokasiAwal,
        startInErrorMode: startInErrorMode,
      ),
    );
  }

  @override
  State<AdHocTaskDialog> createState() => _AdHocTaskDialogState();
}

class _AdHocTaskDialogState extends State<AdHocTaskDialog> {
  late String _mode = widget.startInErrorMode ? 'error' : 'kerjaan'; // 'kerjaan' | 'error'
  final _judulCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();
  String? _posId;
  bool _triedSubmit = false;
  bool _saving = false;

  // Laporan error state
  String? _pastedText;
  ErrorReport? _errorReport;
  String? _errorJudul;
  String? _inlineError;
  bool _isLokasiPreselected = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.startInErrorMode ? 'error' : 'kerjaan';
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

  String _formatReportedAt(DateTime? dt) {
    if (dt == null) return '-';
    const shortDays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const shortMonths = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final dayName = shortDays[(dt.weekday - 1).clamp(0, 6)];
    final dStr = dt.day.toString().padLeft(2, '0');
    final mStr = shortMonths[(dt.month - 1).clamp(0, 11)];
    final yStr = dt.year.toString().padLeft(4, '0');
    final hStr = dt.hour.toString().padLeft(2, '0');
    final minStr = dt.minute.toString().padLeft(2, '0');
    return '$dayName, $dStr $mStr $yStr · $hStr.$minStr';
  }

  Future<void> _pickLokasi() async {
    final options = widget.lokasiOptions
        .map(
          (p) => TiketOption<String>(
            value: p.posId,
            label: p.posName,
            trailingText: p.locationTag,
          ),
        )
        .toList();

    final selected = await showTiketPickerDialog<String>(
      context: context,
      title: 'Pilih Lokasi',
      options: options,
      selected: _posId,
    );

    if (selected != null) {
      setState(() {
        _posId = selected;
        _isLokasiPreselected = false;
      });
    }
  }

  Future<void> _tempelDariTelegram() async {
    setState(() => _inlineError = null);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();

    if (text == null || text.isEmpty) {
      setState(() {
        _inlineError = 'Clipboard kosong. Salin pesan admin dulu.';
      });
      return;
    }

    final report = ErrorReport.parse(text).withFallbackTime(DateTime.now());
    final judul = report.judul(text);

    if (judul.isEmpty) {
      setState(() {
        _inlineError = 'Pesan ini tidak berisi Kendala. Cek lagi pesan yang disalin.';
      });
      return;
    }

    final guessedPos = ErrorTicketService.guessPos(report.lokasi, widget.lokasiOptions) ??
        ErrorTicketService.guessPos(text, widget.lokasiOptions);

    setState(() {
      _pastedText = text;
      _errorReport = report;
      _errorJudul = judul;
      _inlineError = null;
      if (guessedPos != null) {
        _posId = guessedPos.posId;
        _isLokasiPreselected = true;
      } else {
        _isLokasiPreselected = false;
      }
    });
  }

  Future<void> _simpanKerjaan() async {
    if (_saving) return;
    final judul = _judulCtrl.text.trim();
    if (judul.isEmpty || _posId == null) {
      setState(() => _triedSubmit = true);
      return;
    }
    final lokasi = widget.lokasiOptions.firstWhere((p) => p.posId == _posId);
    setState(() => _saving = true);
    try {
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.pop(context, false);
    }
  }

  Future<void> _simpanError() async {
    if (_saving) return;
    if (_errorReport == null || _pastedText == null || _posId == null) {
      return;
    }
    final lokasi = widget.lokasiOptions.where((p) => p.posId == _posId).firstOrNull;
    if (lokasi == null) return;

    setState(() => _saving = true);
    try {
      final task = await DailyTaskService.createTask(
        tanggal: widget.tanggal,
        teknisiNama: widget.teknisiNama,
        posName: lokasi.posName,
        posTag: lokasi.locationTag,
        judul: _errorJudul ?? _errorReport!.judul(_pastedText!),
        deskripsi: _errorReport!.toDeskripsi(_pastedText!),
        kategori: ErrorTicketService.kategori,
      );
      if (!mounted) return;
      Navigator.pop(context, task != null);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final pad = TiketSpace.padOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return PopScope(
      canPop: !_saving,
      child: Container(
        decoration: BoxDecoration(
          color: colors.dialog,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        ),
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              const SizedBox(height: 12.0),
              Center(
                child: Container(
                  width: 36.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: colors.hairline,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
              const SizedBox(height: 12.0),

              // Title, Subtitle & Close Button
              Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Catat Kerjaan',
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 17.0,
                              fontWeight: FontWeight.bold,
                              color: colors.ink,
                            ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            'Kerjaan dadakan atau laporan error dari grup',
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 13.0,
                              fontWeight: FontWeight.w500,
                              color: colors.body,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Tutup',
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 48.0, minHeight: 48.0),
                        child: IconButton(
                          icon: Icon(Icons.close, size: 22.0, color: colors.ink),
                          tooltip: 'Tutup',
                          onPressed: _saving ? null : () => Navigator.pop(context, null),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16.0),

              // Segmented control: 'Kerjaan' | 'Laporan error'
              Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: TiketSegmented<String>(
                  options: const [
                    ('kerjaan', 'Kerjaan'),
                    ('error', 'Laporan error'),
                  ],
                  selected: _mode,
                  onChanged: _saving
                      ? (_) {}
                      : (val) {
                          setState(() {
                            _mode = val;
                            _inlineError = null;
                            _triedSubmit = false;
                          });
                        },
                ),
              ),

              const SizedBox(height: 16.0),

              // Form body
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  child: _mode == 'kerjaan'
                      ? _buildKerjaanForm(colors)
                      : _buildErrorForm(colors),
                ),
              ),

              // Bottom bar
              _buildBottomBar(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKerjaanForm(TiketColors colors) {
    final judulKosong = _judulCtrl.text.trim().isEmpty && _triedSubmit;
    final tanpaLokasi = widget.lokasiOptions.isEmpty && _triedSubmit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextInput(
          colors: colors,
          label: 'Kerjaan apa *',
          controller: _judulCtrl,
          hint: 'Contoh: Ganti kabel LAN pos 2',
          errorText: judulKosong ? 'Wajib diisi' : null,
        ),
        const SizedBox(height: 16.0),
        _buildLokasiField(
          colors: colors,
          label: 'Lokasi *',
          errorText: tanpaLokasi ? 'Pilih salah satu lokasi' : null,
        ),
        const SizedBox(height: 16.0),
        _buildTextInput(
          colors: colors,
          label: 'Catatan opsional',
          controller: _catatanCtrl,
          hint: 'Deskripsi kendala atau tindakan...',
          maxLines: 3,
        ),
        const SizedBox(height: 16.0),
      ],
    );
  }

  Widget _buildErrorForm(TiketColors colors) {
    if (_errorReport == null) {
      // State A: nothing pasted yet
      final selectedPos = widget.lokasiOptions.where((p) => p.posId == _posId).firstOrNull;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pesan error',
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 12.0,
              fontWeight: FontWeight.w500,
              color: colors.body,
            ),
          ),
          const SizedBox(height: 6.0),
          TiketPill(
            label: 'Tempel dari Telegram',
            icon: Icons.content_paste_outlined,
            kind: TiketPillKind.secondary,
            height: 52.0,
            expand: true,
            onPressed: _saving ? null : _tempelDariTelegram,
          ),
          const SizedBox(height: 6.0),
          Text(
            'Salin pesan di grup Telegram dulu, lalu ketuk Tempel.',
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 12.0,
              fontWeight: FontWeight.w400,
              color: colors.body,
            ),
          ),
          if (_inlineError != null) ...[
            const SizedBox(height: 6.0),
            Text(
              _inlineError!,
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
                color: colors.danger,
              ),
            ),
          ],
          const SizedBox(height: 16.0),
          TiketDropdownField(
            label: 'Lokasi',
            value: selectedPos?.posName ?? 'Pilih lokasi',
            onTap: _saving ? () {} : _pickLokasi,
          ),
          if (selectedPos == null) ...[
            const SizedBox(height: 4.0),
            Text(
              'Pilih lokasi',
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: 12.0,
                fontWeight: FontWeight.w400,
                color: colors.body,
              ),
            ),
          ],
          const SizedBox(height: 16.0),
        ],
      );
    }

    // State B: pasted
    final selectedPos = widget.lokasiOptions.where((p) => p.posId == _posId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Isi laporan admin',
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: 13.0,
                fontWeight: FontWeight.w600,
                color: colors.body,
              ),
            ),
            Semantics(
              button: true,
              label: 'Tempel ulang',
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48.0, minHeight: 48.0),
                child: TextButton(
                  onPressed: _saving ? null : _tempelDariTelegram,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    minimumSize: const Size(48.0, 48.0),
                  ),
                  child: Text(
                    'Tempel ulang',
                    style: TextStyle(
                      fontFamily: TiketType.fontFamily,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4.0),

        // Read-only summary block
        Container(
          decoration: BoxDecoration(
            color: colors.soft,
            border: Border(
              bottom: BorderSide(
                color: colors.body,
                width: 2.0,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSummaryRow(
                colors,
                'Waktu lapor',
                _formatReportedAt(_errorReport?.reportedAt),
              ),
              const SizedBox(height: 10.0),
              _buildSummaryRow(
                colors,
                'Kendala',
                _errorReport?.kendala.trim().isNotEmpty == true
                    ? _errorReport!.kendala.trim()
                    : '-',
              ),
              const SizedBox(height: 10.0),
              _buildSummaryRow(
                colors,
                'Penyebab',
                _errorReport?.penyebab.trim().isNotEmpty == true
                    ? _errorReport!.penyebab.trim()
                    : '-',
              ),
              const SizedBox(height: 10.0),
              _buildSummaryRow(
                colors,
                'Solusi sementara',
                _errorReport?.solusiSementara.trim().isNotEmpty == true
                    ? _errorReport!.solusiSementara.trim()
                    : '-',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16.0),

        // Lokasi field
        TiketDropdownField(
          label: 'Lokasi',
          value: selectedPos?.posName ?? 'Pilih lokasi',
          onTap: _saving ? () {} : _pickLokasi,
        ),
        if (_isLokasiPreselected) ...[
          const SizedBox(height: 4.0),
          Text(
            'Dari kolom Lokasi di pesan. Ketuk kalau salah.',
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 12.0,
              fontWeight: FontWeight.w400,
              color: colors.body,
            ),
          ),
        ] else if (selectedPos == null) ...[
          const SizedBox(height: 4.0),
          Text(
            'Pilih lokasi',
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 12.0,
              fontWeight: FontWeight.w400,
              color: colors.body,
            ),
          ),
        ],
        const SizedBox(height: 16.0),
      ],
    );
  }

  Widget _buildSummaryRow(TiketColors colors, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: TiketType.fontFamily,
            fontSize: 12.0,
            fontWeight: FontWeight.w500,
            color: colors.body,
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          value,
          style: TextStyle(
            fontFamily: TiketType.fontFamily,
            fontSize: 15.0,
            fontWeight: FontWeight.w600,
            color: colors.ink,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildTextInput({
    required TiketColors colors,
    required String label,
    required TextEditingController controller,
    String? hint,
    String? errorText,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: TiketType.fontFamily,
            fontSize: 12.0,
            fontWeight: FontWeight.w500,
            color: colors.body,
          ),
        ),
        const SizedBox(height: 4.0),
        Container(
          decoration: BoxDecoration(
            color: colors.soft,
            border: Border(
              bottom: BorderSide(
                color: errorText != null ? colors.danger : colors.body,
                width: 2.0,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 15.0,
              fontWeight: FontWeight.w500,
              color: colors.ink,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: 14.0,
                color: colors.mute,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4.0),
          Text(
            errorText,
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 11.0,
              fontWeight: FontWeight.w500,
              color: colors.danger,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLokasiField({
    required TiketColors colors,
    required String label,
    String? errorText,
  }) {
    final selectedPos = widget.lokasiOptions.where((p) => p.posId == _posId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TiketDropdownField(
          label: label,
          value: selectedPos?.posName ?? 'Pilih lokasi',
          onTap: _saving ? () {} : _pickLokasi,
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4.0),
          Text(
            errorText,
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 11.0,
              fontWeight: FontWeight.w500,
              color: colors.danger,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomBar(TiketColors colors) {
    if (_mode == 'kerjaan') {
      return TiketBottomBar(
        primary: TiketPill(
          label: _saving ? 'Menyimpan...' : 'Simpan',
          kind: _saving ? TiketPillKind.disabled : TiketPillKind.primary,
          expand: true,
          height: 48.0,
          onPressed: _saving ? null : _simpanKerjaan,
        ),
      );
    }

    // Laporan error mode
    if (_errorReport == null) {
      // State A: nothing pasted yet
      return const TiketBottomBar(
        helper: 'Tempel pesan dan pilih lokasi dulu.',
        primary: TiketPill(
          label: 'Kirim Laporan Error',
          kind: TiketPillKind.disabled,
          expand: true,
          height: 48.0,
          onPressed: null,
        ),
      );
    }

    // State B: pasted
    final hasLokasi = _posId != null && widget.lokasiOptions.any((p) => p.posId == _posId);

    return TiketBottomBar(
      helper: hasLokasi
          ? 'Masuk Daily Task kamu. Tim cabang dapat notifikasi.'
          : 'Pilih lokasi dulu.',
      primary: TiketPill(
        label: _saving ? 'Menyimpan...' : 'Kirim Laporan Error',
        kind: (hasLokasi && !_saving) ? TiketPillKind.primary : TiketPillKind.disabled,
        expand: true,
        height: 48.0,
        onPressed: (hasLokasi && !_saving) ? _simpanError : null,
      ),
    );
  }
}
