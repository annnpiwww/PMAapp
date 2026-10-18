import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/models/ai_vision_config.dart';
import 'package:bssparking_timemark/data/services/ai_vision_service.dart';

AiVerificationResult? _parse(Map<String, dynamic> payload) {
  return AiVisionService.parseAiJsonResponseForTest(
    jsonEncode(payload),
    const ['grooming'],
    const AiVisionConfig(),
  );
}

void main() {
  group('Hasil AI tidak boleh menampilkan temuan kembar', () {
    test('blur, miring, dan tidak fokus cuma jadi satu kalimat', () {
      final hasil = _parse({
        'status': 'tidak_sesuai',
        'confidenceScore': 92,
        'alasan': 'Foto blur dan tidak memperlihatkan seluruh badan',
        'poinLolos': ['Seragam resmi rapi'],
        'poinGagal': ['Foto blur', 'Foto miring', 'Tidak fokus', 'Foto blur'],
      });

      expect(hasil, isNotNull);
      expect(hasil!.poinGagal.length, 1);
      expect(hasil.poinGagal.first, contains('blur'));
    });

    test('temuan yang memang beda tetap muncul semua', () {
      final hasil = _parse({
        'status': 'tidak_sesuai',
        'confidenceScore': 88,
        'alasan': 'Ada beberapa pelanggaran SOP',
        'poinLolos': [],
        'poinGagal': ['Jaket dipakai', 'Foto blur', 'ID Card tidak terpasang'],
      });

      expect(hasil, isNotNull);
      expect(hasil!.poinGagal.length, 3);
      // 3 hal diperbaiki = 3 baris yang tampil, jadi hitungan header ikut benar.
      expect(hasil.poinGagal.toSet().length, hasil.poinGagal.length);
    });

    test('temuan kembar beda huruf besar-kecil tetap disaring', () {
      final hasil = _parse({
        'status': 'tidak_sesuai',
        'confidenceScore': 80,
        'alasan': 'Foto kurang fokus',
        'poinLolos': [],
        'poinGagal': ['memakai jaket', 'MEMAKAI JAKET'],
      });

      expect(hasil, isNotNull);
      expect(hasil!.poinGagal.length, 1);
    });
  });
}
