import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/services/ai_vision_service.dart';
import 'ai_logo_mark.dart';

/// Modal loading analisa AI dengan progres bertahap + timer, supaya teknisi
/// tahu prosesnya jalan dan tidak terlihat macet.
///
/// Dialog ini yang menjalankan [task] lalu menutup diri sendiri:
/// - sukses  -> `Navigator.pop(result)`
/// - gagal   -> tetap terbuka dan menampilkan alasan + tombol "Coba Lagi"
/// - fallback/503 dari server diperlakukan sebagai gagal, bukan hasil analisa.
class AiAnalyzingDialog extends StatefulWidget {
  final Future<AiVerificationResult> Function() task;

  const AiAnalyzingDialog({super.key, required this.task});

  @override
  State<AiAnalyzingDialog> createState() => _AiAnalyzingDialogState();
}

class _AiAnalyzingDialogState extends State<AiAnalyzingDialog> {
  static const Color _bg = Color(0xFF0B192C);
  static const Color _card = Color(0xFF152C4E);
  static const Color _divider = Color(0xFF1E3A5F);
  static const Color _onDark = Color(0xFFF1F5F9);
  static const Color _muted = Color(0xFF9FB3CE);
  static const Color _green = Color(0xFF0E9F6E);
  static const Color _red = Color(0xFFE5484D);

  static const List<String> _steps = [
    'Foto disiapkan',
    'Mengirim foto ke server AI',
    'AI memeriksa kesesuaian dengan SOP',
  ];

  Timer? _timer;
  int _seconds = 0;
  bool _running = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
    });
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _error = null;
      _seconds = 0;
    });
    _startTimer();
    try {
      final result = await widget.task();
      _timer?.cancel();
      if (!mounted) return;
      if (result.isFallback) {
        setState(() {
          _running = false;
          _error = result.alasan;
        });
        return;
      }
      Navigator.of(context).pop(result);
    } catch (e) {
      _timer?.cancel();
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = 'Tidak bisa menghubungi server AI. Periksa koneksi internet.';
      });
    }
  }

  /// Indeks langkah yang sedang berjalan (0..2) berdasarkan durasi.
  int get _activeStep => _seconds < 1 ? 0 : (_seconds < 3 ? 1 : 2);

  Widget _buildStep(int index) {
    final bool failed = !_running && _error != null && index == _activeStep;
    final bool done = index < _activeStep;
    final bool active = _running && index == _activeStep;

    final Widget mark;
    if (failed) {
      mark = const Icon(Icons.error_rounded, color: _red, size: 18);
    } else if (done) {
      mark = const Icon(Icons.check_circle_rounded, color: _green, size: 18);
    } else if (active) {
      mark = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    } else {
      mark = const Icon(Icons.radio_button_unchecked,
          color: Color(0xFF4A6485), size: 16);
    }

    final Color color = failed
        ? _red
        : (done || active ? _onDark : _muted);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 20, child: Center(child: mark)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _steps[index],
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight:
                    active || failed ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Row(
                  children: [
                    const AiLogoMark(size: 30, ring: true),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Analisa AI',
                        style: TextStyle(
                          color: _onDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (_running)
                      Text(
                        '$_seconds dtk',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              Container(height: 1, color: _divider),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _running
                          ? 'Foto sedang diperiksa AI. Jangan tutup halaman ini.'
                          : 'Analisa belum berhasil.',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < _steps.length; i++) _buildStep(i),
                    if (_running) ...[
                      const SizedBox(height: 10),
                      Text(
                        _seconds >= 20
                            ? 'Server masih memproses, mohon tunggu sebentar lagi.'
                            : 'Biasanya selesai dalam 5-15 detik.',
                        style: const TextStyle(color: _muted, fontSize: 10.5),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _red.withValues(alpha: 0.45)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Koneksi ke server AI gagal',
                              style: TextStyle(
                                color: _red,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Periksa koneksi internet, lalu coba lagi. Kalau tetap gagal, server AI sedang gangguan.',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 10.5,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _onDark,
                                side: const BorderSide(color: Color(0xFF33507A)),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Tutup',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: _run,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: _bg,
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Coba Lagi',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
