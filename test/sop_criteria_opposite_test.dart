import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/models/submission_model.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/services/ai_vision_service.dart';

void main() {
  group('SopCriteriaHelper & AI Verification Positive/Negative Statement Tests', () {
    test('Positive criteria converts to clear negative opposite statement when failed', () {
      const pos1 = 'Seragam resmi BSS Parking bersih, rapi & terkancing';
      final neg1 = SopCriteriaHelper.toNegativeStatement(pos1);
      expect(neg1, contains('Tidak menggunakan seragam resmi'));

      const pos2 = 'ID Card / Name Tag terpasang jelas di saku kiri';
      final neg2 = SopCriteriaHelper.toNegativeStatement(pos2);
      expect(neg2, contains('tidak terpasang'));

      const pos3 = 'Rambut rapi / Jilbab rapi sesuai standar grooming BSS';
      final neg3 = SopCriteriaHelper.toNegativeStatement(pos3);
      expect(neg3, contains('tidak rapi'));

      const pos4 = 'Sepatu dinas pantofel / PDL hitam bersih';
      final neg4 = SopCriteriaHelper.toNegativeStatement(pos4);
      expect(neg4, contains('Tidak mengenakan sepatu'));

      const pos5 = 'Area pos / booth bersih, bebas dari tumpukan barang pribadi';
      final neg5 = SopCriteriaHelper.toNegativeStatement(pos5);
      expect(neg5, contains('kotor atau ada tumpukan barang'));
    });

    test('Verification with forced failure returns opposite statement in poinGagal', () async {
      final template = TemplateModel(
        id: 'test_tpl',
        nama: 'Test Template',
        deskripsi: 'Test Deskripsi',
        jenis: TemplateCategory.absensi,
        wajibLokasi: true,
        sopCriteria: [
          'Seragam resmi BSS Parking bersih, rapi & terkancing',
          'ID Card / Name Tag terpasang jelas di saku kiri',
        ],
        contohFotoDescriptions: [],
        createdBy: 'Tester',
        updatedAt: DateTime.now(),
      );

      final result = await AiVisionService.verifyPhoto(
        template: template,
        imageBase64: null,
        forceSimulateFailure: true,
      );

      expect(result.status, equals(VerificationStatus.tidakSesuai));
      expect(result.poinGagal.isNotEmpty, isTrue);
      // Poin gagal must NOT be positive statement
      expect(result.poinGagal.first, isNot(equals('Seragam resmi BSS Parking bersih, rapi & terkancing')));
      expect(result.poinGagal.first, contains('Tidak'));
    });

    test('Verification with forced success returns positive statements in poinLolos', () async {
      final template = TemplateModel(
        id: 'test_tpl',
        nama: 'Test Template',
        deskripsi: 'Test Deskripsi',
        jenis: TemplateCategory.absensi,
        wajibLokasi: true,
        sopCriteria: [
          'Seragam resmi BSS Parking bersih, rapi & terkancing',
        ],
        contohFotoDescriptions: [],
        createdBy: 'Tester',
        updatedAt: DateTime.now(),
      );

      final result = await AiVisionService.verifyPhoto(
        template: template,
        imageBase64: null,
        forceSimulateSuccess: true,
      );

      expect(result.status, equals(VerificationStatus.sesuai));
      expect(result.poinGagal.isEmpty, isTrue);
      expect(result.poinLolos, contains('Seragam resmi BSS Parking bersih, rapi & terkancing'));
    });
  });
}
