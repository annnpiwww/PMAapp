import 'package:flutter/material.dart';
import '../../../data/models/submission_model.dart';
import '../../../data/services/ai_vision_service.dart';
import 'ai_logo_mark.dart';

/// Modal hasil analisa ulang foto, tampilannya mengikuti sheet verifikasi AI
/// saat foto baru diambil (banner status, alasan, daftar temuan).
class AiResultDialog extends StatelessWidget {
  final AiVerificationResult result;
  final String? title;

  const AiResultDialog({super.key, required this.result, this.title});

  static const Color _bg = Color(0xFF0B192C);
  static const Color _card = Color(0xFF152C4E);
  static const Color _onDark = Color(0xFFF1F5F9);
  static const Color _onDarkMuted = Color(0xFF9FB3CE);
  static const Color _divider = Color(0xFF1E3A5F);

  Color get _statusColor => switch (result.status) {
        VerificationStatus.sesuai => const Color(0xFF0E9F6E),
        VerificationStatus.tidakSesuai => const Color(0xFFE5484D),
        VerificationStatus.perluCekManual => const Color(0xFFD97706),
      };

  IconData get _statusIcon => switch (result.status) {
        VerificationStatus.sesuai => Icons.check_circle_rounded,
        VerificationStatus.tidakSesuai => Icons.cancel_rounded,
        VerificationStatus.perluCekManual => Icons.help_rounded,
      };

  String get _statusLabel => switch (result.status) {
        VerificationStatus.sesuai => 'SESUAI SOP',
        VerificationStatus.tidakSesuai => 'TIDAK SESUAI',
        VerificationStatus.perluCekManual => 'PERLU CEK MANUAL',
      };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
                child: Row(
                  children: [
                    const AiLogoMark(size: 24),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Hasil Analisa AI',
                        style: TextStyle(
                          color: _onDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: _divider),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Banner status
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: _statusColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _statusColor.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Icon(_statusIcon, color: _statusColor, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _statusLabel,
                                style: TextStyle(
                                  color: _statusColor,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            Text(
                              '${(result.confidenceScore * 100).round()}%',
                              style: const TextStyle(
                                color: _onDarkMuted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (title != null && title!.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          title!,
                          style: const TextStyle(
                            color: _onDark,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],

                      // Alasan
                      if (result.alasan.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            result.alasan,
                            style: const TextStyle(
                              color: _onDark,
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],

                      if (result.poinGagal.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Yang Perlu Diperbaiki',
                          style: TextStyle(
                            color: Color(0xFFE5484D),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final poin in result.poinGagal)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('•  ',
                                    style: TextStyle(
                                        color: Color(0xFFE5484D),
                                        fontSize: 12)),
                                Expanded(
                                  child: Text(
                                    poin,
                                    style: const TextStyle(
                                      color: _onDarkMuted,
                                      fontSize: 11.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],

                      if (result.poinLolos.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Yang Sudah Sesuai',
                          style: TextStyle(
                            color: Color(0xFF0E9F6E),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final poin in result.poinLolos)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('✓  ',
                                    style: TextStyle(
                                        color: Color(0xFF0E9F6E),
                                        fontSize: 12)),
                                Expanded(
                                  child: Text(
                                    poin,
                                    style: const TextStyle(
                                      color: _onDarkMuted,
                                      fontSize: 11.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],

                      if (result.providerName.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Dianalisa oleh ${result.providerName}',
                          style: const TextStyle(
                            color: _onDarkMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // CTA
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _bg,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Tutup',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
