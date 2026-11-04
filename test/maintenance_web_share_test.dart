import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/services/whatsapp_report_service.dart';

/// iOS/Vercel: web tidak bisa menulisi file, jadi foto share harus memakai byte
/// ber-watermark dari kamera dan tetap urut sesuai SOP (Gate 1 -> Gate 2, point 1 -> 9).
void main() {
  MaintenanceSubmission submission(List<MaintenancePointResult> points) {
    final now = DateTime(2026, 10, 23, 9);
    return MaintenanceSubmission(
      id: 'sub_web',
      templateId: 'tpl_barrier',
      templateName: 'Maintenance Barrier',
      userId: 'u1',
      userName: 'Teknisi',
      userNpp: '1',
      posId: 'p1',
      posName: 'Pasar Bersehati',
      cabangName: 'Manado',
      points: points,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('foto share web memakai byte ber-watermark dan urut per unit + SOP', () async {
    final a = MaintenancePointResult(
      pointId: 'bar_2_02',
      label: 'Barrier Gate 2 - Palang',
      status: PointStatus.sesuai,
      imagePath: 'blob:https://app/2',
      shareImageBytes: Uint8List.fromList([2]),
    );
    final b = MaintenancePointResult(
      pointId: 'bar_1_01',
      label: 'Barrier Gate 1 - Sensor',
      status: PointStatus.sesuai,
      imagePath: 'blob:https://app/1',
      shareImageBytes: Uint8List.fromList([1]),
    );

    final files = await WhatsAppReportService.buildWebShareFiles(
      submission([a, b]),
    );

    expect(files.length, 2);
    expect(files.first.bytes, [1]);
    expect(files.first.name, '01_bar_1_01.jpg');
    expect(files.last.bytes, [2]);
  });

  test('poin tanpa byte terbaca dilewati, bukan bikin share kosong/gagal', () async {
    final tanpaFoto = const MaintenancePointResult(
      pointId: 'bar_1_02',
      label: 'Barrier Gate 1 - Palang',
      status: PointStatus.tidakTerpasang,
    );

    final files = await WhatsAppReportService.buildWebShareFiles(
      submission([tanpaFoto]),
    );

    expect(files, isEmpty);
  });

  test('byte watermark tidak ikut tersimpan ke local storage', () {
    final point = MaintenancePointResult(
      pointId: 'bar_1_01',
      label: 'Barrier Gate 1',
      shareImageBytes: Uint8List.fromList([1, 2, 3]),
    );

    expect(point.toJson().containsKey('shareImageBytes'), isFalse);
  });
}
