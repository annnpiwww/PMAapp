import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/models/submission_model.dart';

/// Cek perilaku status poin "Tidak Terpasang" (barang tidak ada di lokasi)
/// dan tingkat urgensi temuan per poin.
void main() {
  MaintenancePointResult point({
    String id = 'p1',
    PointStatus status = PointStatus.sesuai,
    TingkatUrgensi urgensi = TingkatUrgensi.normal,
  }) =>
      MaintenancePointResult(
        pointId: id,
        label: 'Poin $id',
        status: status,
        urgensi: urgensi,
        alasan: '',
      );

  MaintenanceSubmission submission(List<MaintenancePointResult> points) =>
      MaintenanceSubmission(
        id: 'sub_1',
        templateId: 'tpl_1',
        templateName: 'Maintenance: Barrier Gate',
        userId: 'usr_1',
        userName: 'Teknisi Uji',
        userNpp: 'BSS-001',
        posId: 'pos_1',
        posName: 'Pos Uji',
        cabangName: 'PBM',
        points: points,
        createdAt: DateTime(2026, 10, 17, 8),
        updatedAt: DateTime(2026, 10, 17, 8),
      );

  group('PointStatus tidak terpasang', () {
    test('parsing teks dari server/lama', () {
      expect(PointStatus.fromString('tidak terpasang'), PointStatus.tidakTerpasang);
      expect(PointStatus.fromString('Tidak Terpasang'), PointStatus.tidakTerpasang);
      expect(PointStatus.fromString('n/a'), PointStatus.tidakTerpasang);
      expect(PointStatus.fromString('tidak ada'), PointStatus.tidakTerpasang);
    });

    test('dianggap selesai tapi tidak butuh foto', () {
      final p = point(status: PointStatus.tidakTerpasang);
      expect(p.isDone, isTrue);
      expect(p.isTidakTerpasang, isTrue);
      expect(p.isSesuai, isFalse);
    });

    test('submission lengkap & tetap dianggap sesuai, dihitung netral', () {
      final sub = submission([
        point(id: 'p1', status: PointStatus.sesuai),
        point(id: 'p2', status: PointStatus.tidakTerpasang),
      ]);

      expect(sub.isComplete, isTrue);
      expect(sub.isAllSesuai, isTrue);
      expect(sub.overallStatus, VerificationStatus.sesuai);
      expect(sub.sesuaiCount, 1);
      expect(sub.tidakTerpasangCount, 1);
      expect(sub.doneCount, 2);
    });

    test('temuan tidak sesuai tetap membuat status bermasalah', () {
      final sub = submission([
        point(id: 'p1', status: PointStatus.tidakTerpasang),
        point(id: 'p2', status: PointStatus.tidakSesuai),
      ]);

      expect(sub.isAllSesuai, isFalse);
      expect(sub.overallStatus, VerificationStatus.tidakSesuai);
    });
  });

  group('Tingkat urgensi per poin', () {
    test('parsing teks', () {
      expect(TingkatUrgensi.fromString('urgent'), TingkatUrgensi.urgent);
      expect(TingkatUrgensi.fromString('URGENT'), TingkatUrgensi.urgent);
      expect(TingkatUrgensi.fromString('kritis'), TingkatUrgensi.urgent);
      expect(TingkatUrgensi.fromString('sedang'), TingkatUrgensi.sedang);
      expect(TingkatUrgensi.fromString('ringan'), TingkatUrgensi.ringan);
      expect(TingkatUrgensi.fromString(null), TingkatUrgensi.normal);
      expect(TingkatUrgensi.fromString('ngawur'), TingkatUrgensi.normal);
    });

    test('submission menghitung poin urgent', () {
      final sub = submission([
        point(id: 'p1', status: PointStatus.tidakSesuai, urgensi: TingkatUrgensi.urgent),
        point(id: 'p2', status: PointStatus.tidakSesuai, urgensi: TingkatUrgensi.sedang),
        point(id: 'p3', status: PointStatus.sesuai),
      ]);

      expect(sub.urgentCount, 1);
      expect(sub.hasUrgent, isTrue);
      expect(sub.bermasalahCount, 2);
    });

    test('tidak ada poin urgent', () {
      final sub = submission([point(id: 'p1', status: PointStatus.sesuai)]);
      expect(sub.urgentCount, 0);
      expect(sub.hasUrgent, isFalse);
    });
  });

  group('Simpan & baca ulang (SharedPreferences JSON)', () {
    test('status tidak terpasang + urgensi ikut tersimpan', () {
      final asli = point(
        id: 'speedbump',
        status: PointStatus.tidakTerpasang,
        urgensi: TingkatUrgensi.urgent,
      );

      final kembali = MaintenancePointResult.fromJson(asli.toJson());

      expect(kembali.status, PointStatus.tidakTerpasang);
      expect(kembali.urgensi, TingkatUrgensi.urgent);
      expect(kembali.label, asli.label);
    });

    test('data lama tanpa field urgensi tetap terbaca (normal)', () {
      final lama = point(id: 'p1', status: PointStatus.sesuai).toJson()..remove('urgensi');
      expect(MaintenancePointResult.fromJson(lama).urgensi, TingkatUrgensi.normal);
    });

    test('copyWith bisa mengubah urgensi & status saja', () {
      final asli = point(id: 'p1', status: PointStatus.sesuai);
      final diubah = asli.copyWith(status: PointStatus.tidakTerpasang, urgensi: TingkatUrgensi.ringan);

      expect(diubah.pointId, 'p1');
      expect(diubah.status, PointStatus.tidakTerpasang);
      expect(diubah.urgensi, TingkatUrgensi.ringan);
      expect(asli.status, PointStatus.sesuai, reason: 'objek asli tidak boleh berubah');
    });
  });

  group('Label tingkat keparahan (dipakai laporan & UI)', () {
    test('pakai bahasa yang langsung kebaca teknisi', () {
      expect(TingkatUrgensi.ringan.label, 'Masih aman');
      expect(TingkatUrgensi.sedang.label, 'Sudah mulai rusak');
      expect(TingkatUrgensi.urgent.label, 'Harus diganti');
    });

    test('label baru tetap bisa dibaca balik dari teks', () {
      expect(TingkatUrgensi.fromString('Masih aman'), TingkatUrgensi.ringan);
      expect(TingkatUrgensi.fromString('Sudah mulai rusak'), TingkatUrgensi.sedang);
      expect(TingkatUrgensi.fromString('Harus diganti'), TingkatUrgensi.urgent);
    });
  });
}
