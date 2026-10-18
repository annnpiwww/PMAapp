import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/services/ai_vision_service.dart';

void main() {
  group('Prompt maintenance anti salin contoh', () {
    final prompt = AiVisionService.buildMaintenanceSystemPrompt(
      extraContext: 'Template: Maintenance Barrier Gate — Point: fisik palang tertutup lurus — Checkpoints: palang turun 0 derajat',
      criteriaListStr: '1. fisik palang tertutup lurus',
    );

    test('memuat aturan anti salin contoh sebelum daftar contoh kalimat', () {
      expect(prompt, contains('ATURAN WAJIB ANTI SALIN CONTOH (PRIORITAS TERTINGGI):'));
      expect(prompt, contains('DILARANG menyalin kalimat contoh apa adanya'));
      expect(prompt, contains('detail yang cuma ada di foto ini'));
      expect(prompt, contains('DILARANG memakai kalimat identik untuk dua temuan'));
      // Poin hijau dikecualikan: laporan menggabung poin aman jadi satu baris,
      // jadi kalimat spesifik justru salah kalau diklaim ke semua gate.
      expect(prompt, contains('KHUSUS poin sesuai (hijau)'));
      expect(prompt, contains('digabung jadi satu baris untuk beberapa gate'));
      expect(prompt, contains('KHUSUS TEMUAN'));
      // Aturan anti salin wajib muncul lebih dulu dari kalimat contoh,
      // biar contoh dibaca AI sebagai patokan gaya, bukan kalimat siap pakai.
      expect(
        prompt.indexOf('ANTI SALIN CONTOH'),
        lessThan(prompt.indexOf('Contoh alasan sesuai')),
      );
    });

    test('aturan fungsional lama tidak hilang', () {
      expect(prompt, contains('JALUR KABEL SENSOR LOOP DETECTOR'));
      expect(prompt, contains('DILARANG menolak atau memberi status tidak sesuai'));
      expect(prompt, contains('DILARANG memberi status "tidak_sesuai"'));
      expect(prompt, contains('ATURAN KHUSUS FISIK PALANG TERTUTUP vs TERBUKA'));
      expect(prompt, contains('WAJIB BEDA'));
      expect(prompt, contains('OUTPUT STRICT JSON ONLY'));
    });

    test('context dan kriteria point ikut tersisip', () {
      expect(prompt, contains('Point: fisik palang tertutup lurus'));
      expect(prompt, contains('1. fisik palang tertutup lurus'));
      expect(prompt, contains('Checkpoints: palang turun 0 derajat'));
    });
  });
}
