import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/services/ai_vision_service.dart';

void main() {
  group('AI Vision Clean Technician Reason Sanitization Test', () {
    test('Membersihkan salam dan basa-basi pembuka LLM', () {
      const raw = 'Halo, selamat pagi. Berdasarkan analisis gambar, area dudukan mesin kotor dan berdebu. Terima kasih.';
      final cleaned = AiVisionService.cleanTechnicianReason(raw);
      expect(cleaned, isNot(contains('Halo')));
      expect(cleaned, isNot(contains('selamat pagi')));
      expect(cleaned, isNot(contains('Terima kasih')));
      expect(cleaned, equals('Area dudukan mesin kotor dan berdebu'));
    });

    test('Memangkas kalimat berbelit menjadi 1 kalimat tunggal fakta fisik', () {
      const raw = 'Baut dynabolt tampak berkarat dan kendor. Kondisi ini perlu segera diganti oleh teknisi. Pastikan dilakukan perawatan berkala.';
      final cleaned = AiVisionService.cleanTechnicianReason(raw);
      expect(cleaned, equals('Baut dynabolt tampak berkarat dan kendor'));
    });

    test('Mengubah kata kaku formal AI menjadi bahasa natural teknisi', () {
      const raw = 'Ditemukan adanya ketidaksesuaian pada plat besi yang mengalami degradasi fisik.';
      final cleaned = AiVisionService.cleanTechnicianReason(raw);
      expect(cleaned.toLowerCase(), contains('terdapat temuan plat besi yang mengalami kerusakan fisik'));
    });
  });
}
