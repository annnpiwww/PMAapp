import 'package:flutter/material.dart';

/// Logo AI (otak + kaca pembesar). Memakai aset `foto/ai_analisa.png` kalau
/// sudah ada; kalau belum, tampil tile biru + ikon otak sebagai cadangan.
class AiLogoMark extends StatelessWidget {
  final double size;
  final bool ring;

  const AiLogoMark({super.key, this.size = 32, this.ring = false});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.28);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ring ? 1.5 : 0),
      decoration: BoxDecoration(
        borderRadius: radius,
        color: ring ? Colors.white : Colors.transparent,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          'foto/ai_analisa.png',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E4FD8), Color(0xFF0B2A6F)],
              ),
            ),
            child: Center(
              child: Icon(
                Icons.psychology_rounded,
                color: Colors.white,
                size: size * 0.62,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
