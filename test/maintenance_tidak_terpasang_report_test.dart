import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/data/services/whatsapp_report_service.dart';

/// Memastikan poin "Tidak Terpasang" TIDAK pernah dilaporkan sebagai
/// "sesuai/terpasang" di teks laporan WhatsApp/Telegram.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  final now = DateTime(2026, 10, 17, 9, 30);

  MaintenancePointResult p(
    String id,
    String label,
    PointStatus status, {
    TingkatUrgensi urgensi = TingkatUrgensi.normal,
    String alasan = '',
  }) =>
      MaintenancePointResult(
        pointId: id,
        label: label,
        status: status,
        urgensi: urgensi,
        alasan: alasan,
      );

  MaintenanceSubmission sub(List<MaintenancePointResult> points) => MaintenanceSubmission(
        id: 'sub_report_1',
        templateId: 'tpl_maint_barrier',
        templateName: 'Maintenance: Barrier Gate',
        userId: 'usr_1',
        userName: 'Teknisi Uji',
        userNpp: 'BSS-001',
        posId: 'pos_1',
        posName: 'Pos Uji',
        cabangName: 'PBM',
        points: points,
        createdAt: now,
        updatedAt: now,
      );

  List<MaintenancePointResult> gate1({PointStatus speedbump = PointStatus.sesuai}) => [
        p('bar_1_01', 'Gate 1 - Dudukan Mesin & Baut Dynabolt', PointStatus.sesuai),
        p('bar_1_02', 'Gate 1 - Fisik Palang Tertutup Lurus', PointStatus.sesuai),
        p('bar_1_03', 'Gate 1 - Fisik Palang Terbuka', PointStatus.sesuai),
        p('bar_1_04', 'Gate 1 - Pelumas (Spring/Bearing)', PointStatus.sesuai),
        p('bar_1_05', 'Gate 1 - Sensor Loop Detector', PointStatus.sesuai),
        p('bar_1_06', 'Gate 1 - Jalur Kabel Sensor', PointStatus.sesuai),
        p('bar_1_07', 'Gate 1 - Stiker Receiver Barrier Gate', PointStatus.sesuai),
        p('bar_1_08', 'Gate 1 - Tiang CCTV & Housing', PointStatus.sesuai),
        p('bar_1_09', 'Gate 1 - Speedbump Gate', speedbump),
      ];

  /// Isi blok tema tertentu (baris di bawah judul tema sampai judul berikutnya).
  String blokTema(String report, String kataKunci) {
    final baris = report.split('\n').map((l) => l.trim()).toList();
    final start = baris.indexWhere((l) => l.toLowerCase().contains(kataKunci));
    if (start < 0) return '';
    final out = <String>[];
    for (final l in baris.skip(start + 1)) {
      if (RegExp(r'^\d+\.\s').hasMatch(l)) break;
      out.add(l);
    }
    return out.join('\n');
  }

  /// Blok tema speedbump tidak boleh mengklaim barangnya terpasang (✅).
  void expectSpeedbumpTidakDiklaimTerpasang(String report) {
    final blok = blokTema(report, 'speedbump');
    expect(blok.trim(), isNotEmpty, reason: 'blok tema speedbump harus tetap dilaporkan');
    expect(blok.contains('✅'), isFalse, reason: 'tidak boleh diklaim terpasang:\n$blok');
  }

  test('Speedbump tidak terpasang tetap muncul sebagai ⛔ di laporan', () {
    final report = WhatsAppReportService.generateReportText(
      submission: sub(gate1(speedbump: PointStatus.tidakTerpasang)),
      category: TemplateCategory.maintBarrier,
      unitCount: 1,
    );

    expect(report, contains('⛔ Tidak Terpasang: 1'));
    expect(report, contains('⛔ Tidak terpasang'));
    expectSpeedbumpTidakDiklaimTerpasang(report);
    // Poin lain yang memang sesuai tetap dilaporkan aman
    expect(report, contains('✅'));
  });

  test('Kalau SEMUA poin tidak terpasang, tidak ada klaim ✅ sama sekali', () {
    final points = gate1()
        .map((e) => e.copyWith(status: PointStatus.tidakTerpasang))
        .toList();

    final report = WhatsAppReportService.generateReportText(
      submission: sub(points),
      category: TemplateCategory.maintBarrier,
      unitCount: 1,
    );

    expect(report, contains('⛔ Tidak Terpasang: 9'));
    expect(report, isNot(contains('✅')));
    expect(report, isNot(contains('semua aman')));
    expectSpeedbumpTidakDiklaimTerpasang(report);
  });

  test('Urgensi ikut terkirim dan tidak terpasang tampil per gate (multi gate)', () {
    final points = [
      ...gate1(),
      p('bar_2_01', 'Gate 2 - Dudukan Mesin & Baut Dynabolt', PointStatus.sesuai),
      p('bar_2_03', 'Gate 2 - Fisik Palang Terbuka', PointStatus.tidakSesuai,
          urgensi: TingkatUrgensi.urgent, alasan: 'palang tidak mengunci'),
      p('bar_2_09', 'Gate 2 - Speedbump Gate', PointStatus.tidakTerpasang),
    ];

    final report = WhatsAppReportService.generateReportText(
      submission: sub(points),
      category: TemplateCategory.maintBarrier,
      unitCount: 2,
    );

    expect(report, contains('⛔ Tidak Terpasang: 1'));
    expect(report, contains('🚨 Harus diganti: 1 poin'));
    expect(report, contains('*(harus diganti)*'));
    expect(report, contains('⚠️ Gate 2: palang tidak mengunci'));
    // Speedbump Gate 2 tidak terpasang: ditulis singkat, tapi tetap jelas gate-nya
    expect(report, contains('⛔ Gate 2: Tidak terpasang'));
    expect(report, isNot(contains('⛔ Gate 1')));
  });

  test('Poin tidak terpasang tidak dihitung sebagai temuan/perlu perbaikan', () {
    final report = WhatsAppReportService.generateReportText(
      submission: sub(gate1(speedbump: PointStatus.tidakTerpasang)),
      category: TemplateCategory.maintBarrier,
      unitCount: 1,
    );

    expect(report, isNot(contains('⚠️ Tidak Sesuai')));
    expect(report, isNot(contains('⚠️ Perlu Dicek')));
    expect(report, contains('HASIL MAINTENANCE'));
  });

  test('Baris tidak terpasang langsung bilang tidak terpasang tanpa dobel nama', () {
    final points = [
      p('pos_1_01', 'Pos 1 - Pembersihan printer pos kasir', PointStatus.tidakTerpasang),
      p('pos_1_02', 'Pos 1 - Kerapian kabel dan stopkontak pos', PointStatus.tidakTerpasang),
      p('pos_1_06', 'Pos 1 - Stiker BSS Parking & Parkways - Sisi Kanan', PointStatus.tidakTerpasang),
    ];

    final report = WhatsAppReportService.generateReportText(
      submission: sub(points),
      category: TemplateCategory.maintPos,
      unitCount: 1,
    );

    // Judul tema sudah menyebut nama barang: cukup "Tidak terpasang".
    final baris = report.split('\n').map((l) => l.trim()).toList();
    final iJudul = baris.indexWhere((l) => l.contains('Kerapian jalur kabel'));
    expect(iJudul, greaterThanOrEqualTo(0));
    expect(baris[iJudul + 1], '⛔ Tidak terpasang');
    expect(report, isNot(contains('Kerapian kabel dan stopkontak pos')));

    // Yang sisanya memang beda (stiker sisi kanan) tetap disebut singkat.
    expect(report, contains('⛔ Sisi Kanan tidak terpasang'));
    expect(report, isNot(contains('Stiker BSS Parking & Parkways - Sisi Kanan tidak')));
  });

  group('Ringkasan HASIL MAINTENANCE tidak monoton', () {
    String ringkas(String report) => report
        .split('\n')
        .skipWhile((l) => !l.startsWith('HASIL MAINTENANCE'))
        .takeWhile((l) => !l.startsWith('Total Point') && l.trim().isNotEmpty)
        .join('\n');

    test('semua aman (ada + tidak urgent) -> cuma Sesuai & Total Point', () {
      final report = WhatsAppReportService.generateReportText(
        submission: sub(gate1()),
        category: TemplateCategory.maintBarrier,
        unitCount: 1,
      );

      expect(report, contains('✅ Sesuai: 9'));
      expect(report, contains('Total Point: 9'));
      // Baris tambahan tidak boleh muncul kalau memang tidak ada kejadian
      expect(report, isNot(contains('⛔')));
      expect(report, isNot(contains('🚨')));
      expect(report, isNot(contains('Tidak Terpasang')));
      expect(report, isNot(contains('URGENT')));
      expect(ringkas(report), 'HASIL MAINTENANCE :\n✅ Sesuai: 9');
    });

    test('ada tidak terpasang -> baris ⛔ baru ditulis', () {
      final report = WhatsAppReportService.generateReportText(
        submission: sub(gate1(speedbump: PointStatus.tidakTerpasang)),
        category: TemplateCategory.maintBarrier,
        unitCount: 1,
      );

      expect(report, contains('✅ Sesuai: 8'));
      expect(report, contains('⛔ Tidak Terpasang: 1'));
      expect(report, isNot(contains('🚨')), reason: 'tidak ada yang urgent, jangan tulis');
    });

    test('ada urgent -> baris 🚨 baru ditulis', () {
      final points = gate1()
          .map((e) => e.pointId == 'bar_1_02'
              ? e.copyWith(
                  status: PointStatus.tidakSesuai,
                  urgensi: TingkatUrgensi.urgent,
                  alasan: 'palang miring',
                )
              : e)
          .toList();

      final report = WhatsAppReportService.generateReportText(
        submission: sub(points),
        category: TemplateCategory.maintBarrier,
        unitCount: 1,
      );

      expect(report, contains('✅ Sesuai: 8'));
      expect(report, contains('⚠️ Ada Masalah: 1'));
      expect(report, contains('🚨 Harus diganti: 1 poin'));
      expect(report, isNot(contains('⛔')), reason: 'tidak ada yang tidak terpasang, jangan tulis');
    });

    test('tidak ada yang sesuai -> baris Sesuai juga tidak dipaksa tampil', () {
      final points = [
        p('bar_1_02', 'Gate 1 - Fisik Palang Tertutup Lurus', PointStatus.tidakSesuai, alasan: 'miring'),
      ];

      final report = WhatsAppReportService.generateReportText(
        submission: sub(points),
        category: TemplateCategory.maintBarrier,
        unitCount: 1,
      );

      expect(report, isNot(contains('✅ Sesuai')));
      expect(report, contains('⚠️ Ada Masalah: 1'));
    });
  });
}
