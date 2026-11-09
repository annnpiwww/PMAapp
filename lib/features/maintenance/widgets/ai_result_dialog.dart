import 'package:flutter/material.dart';
import '../../../core/constants/tiket_colors.dart';
import '../../../core/widgets/tiket/tiket.dart';
import '../../../data/models/submission_model.dart';
import '../../../data/services/ai_vision_service.dart';

/// Modal hasil analisa ulang foto berdasar mockup 13b PMA Tiket.
class AiResultDialog extends StatelessWidget {
  final AiVerificationResult result;
  final String? title;

  const AiResultDialog({super.key, required this.result, this.title});

  TiketChipKind get _chipKind => switch (result.status) {
        VerificationStatus.sesuai => TiketChipKind.ok,
        VerificationStatus.tidakSesuai => TiketChipKind.attention,
        VerificationStatus.perluCekManual => TiketChipKind.neutral,
      };

  String get _statusLabel => switch (result.status) {
        VerificationStatus.sesuai => 'Sesuai',
        VerificationStatus.tidakSesuai => 'Tidak sesuai',
        VerificationStatus.perluCekManual => 'Perlu cek manual',
      };

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.dialog,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title 'Hasil Analisa AI' screenTitle
              Text(
                'Hasil Analisa AI',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 12),

              // StatusChip sentence case ('Tidak sesuai' attention, 'Sesuai' ok, 'Perlu cek manual' neutral)
              StatusChip(label: _statusLabel, kind: _chipKind),

              if (title != null && title!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  title!,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: colors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],

              // Description as plain body text, no grey box
              if (result.alasan.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  result.alasan,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: colors.body,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],

              // Section 'Yang perlu diperbaiki'
              if (result.poinGagal.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Yang perlu diperbaiki',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: colors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final poin in result.poinGagal)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const StatusMarker(
                          status: TiketStatus.attention,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            poin,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              color: colors.ink,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],

              // Section 'Yang sudah sesuai'
              if (result.poinLolos.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Yang sudah sesuai',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: colors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final poin in result.poinLolos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const StatusMarker(
                          status: TiketStatus.ok,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            poin,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              color: colors.ink,
                              fontSize: 13,
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
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: colors.mute,
                    fontSize: 11,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // 'Tutup' = TiketPill secondary content-width aligned right
              Align(
                alignment: Alignment.centerRight,
                child: TiketPill(
                  label: 'Tutup',
                  kind: TiketPillKind.secondary,
                  height: 44,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
