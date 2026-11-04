import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/services/location_service.dart';
import 'package:bssparking_timemark/data/services/maintenance_log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  group('MaintenanceLogService.wilayahOf', () {
    test('mengklasifikasikan seed lokasi KC Manado dan sekitarnya dengan tepat', () {
      final manadoLocations = LocationService.getLocationsByBranch(AppBranch.manado);

      PosLocation findLoc(String id) =>
          manadoLocations.firstWhere((p) => p.posId == id);

      // POS-MGMM-01: Airmadidi
      final airmadidi = findLoc('POS-MGMM-01');
      expect(MaintenanceLogService.wilayahOf(airmadidi), 'Airmadidi');

      // POS-MGTO-01: Tomohon
      final tomohon = findLoc('POS-MGTO-01');
      expect(MaintenanceLogService.wilayahOf(tomohon), 'Tomohon');

      // POS-MGKB-01: Kotamobagu
      final kotamobagu = findLoc('POS-MGKB-01');
      expect(MaintenanceLogService.wilayahOf(kotamobagu), 'Kotamobagu');

      // POS-MGLG-01: Gorontalo via Limboto
      final gorontalo = findLoc('POS-MGLG-01');
      expect(MaintenanceLogService.wilayahOf(gorontalo), 'Gorontalo');

      // POS-PBM-01: Manado
      final manado = findLoc('POS-PBM-01');
      expect(MaintenanceLogService.wilayahOf(manado), 'Manado');

      // POS-MGBP-01: Babe Palar masuk Bitung
      final mgbp = findLoc('POS-MGBP-01');
      expect(MaintenanceLogService.wilayahOf(mgbp), 'Bitung');

      // PosLocation buatan dengan fullAddress Bitung
      const bitungLoc = PosLocation(
        posId: 'POS-TEST-BITUNG',
        posName: 'Pelabuhan Bitung',
        cabangName: 'KC Manado',
        fullAddress: 'Jl. Sam Ratulangi No. 10, Bitung, Sulawesi Utara',
        locationTag: 'Bitung',
        tagColor: Colors.blue,
        lat: 1.4404,
        lng: 125.1217,
      );
      expect(MaintenanceLogService.wilayahOf(bitungLoc), 'Bitung');
    });
  });

  group('MaintenanceLogEntry.fromSubmission', () {
    test('hanya memasukkan tidakSesuai & perluCekManual ke temuan', () {
      final submission = MaintenanceSubmission(
        id: 'sub_test_01',
        templateId: 'tpl_maint_barrier',
        templateName: 'Maintenance: Barrier Gate',
        userId: 'usr_01',
        userName: 'Teknisi Alfa',
        userNpp: 'NPP-101',
        posId: 'POS-PBM-01',
        posName: 'RS Siloam Paal Dua',
        cabangName: 'KC Manado',
        points: [
          const MaintenancePointResult(
            pointId: 'p1',
            label: 'Kondisi Barrier Gate',
            status: PointStatus.sesuai,
            urgensi: TingkatUrgensi.normal,
            alasan: '',
          ),
          const MaintenancePointResult(
            pointId: 'p2',
            label: 'Palang Gate & Karet',
            status: PointStatus.tidakTerpasang,
            urgensi: TingkatUrgensi.normal,
            alasan: 'Tidak ada karet pelindung dari pabrik',
          ),
          const MaintenancePointResult(
            pointId: 'p3',
            label: 'Sensor Vehicle Loop Detector',
            status: PointStatus.tidakSesuai,
            urgensi: TingkatUrgensi.urgent,
            alasan: 'Loop detector mati total, kabel putus',
          ),
          const MaintenancePointResult(
            pointId: 'p4',
            label: 'Kunci Pengaman Manual Gear',
            status: PointStatus.perluCekManual,
            urgensi: TingkatUrgensi.sedang,
            alasan: 'Kunci sedikit macet tapi masih bisa diputar',
          ),
        ],
        createdAt: DateTime(2026, 11, 2, 9, 30),
        updatedAt: DateTime(2026, 11, 2, 10, 15),
      );

      final entry = MaintenanceLogEntry.fromSubmission(submission);

      expect(entry.id, 'sub_test_01');
      expect(entry.tanggal, '2026-11-02');
      expect(entry.jamSelesai, '10:15');
      expect(entry.posId, 'POS-PBM-01');
      expect(entry.posName, 'RS Siloam Paal Dua');
      expect(entry.teknisiNama, 'Teknisi Alfa');
      expect(entry.teknisiNpp, 'NPP-101');
      expect(entry.hasTemuan, isTrue);
      expect(entry.temuan.length, 2);

      // Temuan 1: tidak_sesuai & urgent
      final t1 = entry.temuan[0];
      expect(t1.label, 'Sensor Vehicle Loop Detector');
      expect(t1.status, 'tidak_sesuai');
      expect(t1.alasan, 'Loop detector mati total, kabel putus');
      expect(t1.urgent, isTrue);

      // Temuan 2: perlu_cek_manual & tidak urgent (sedang != urgent)
      final t2 = entry.temuan[1];
      expect(t2.label, 'Kunci Pengaman Manual Gear');
      expect(t2.status, 'perlu_cek_manual');
      expect(t2.alasan, 'Kunci sedikit macet tapi masih bisa diputar');
      expect(t2.urgent, isFalse);
    });
  });

  group('MaintenanceLogService.buildStatuses', () {
    const testLoc1 = PosLocation(
      posId: 'POS-1',
      posName: 'Pos Mega Mall 1',
      cabangName: 'KC Manado',
      fullAddress: 'Kawasan Megamas Manado',
      locationTag: 'Mega Mall',
      tagColor: Colors.blue,
      lat: 1.485,
      lng: 124.839,
    );

    const testLoc2 = PosLocation(
      posId: 'POS-2',
      posName: 'Pos IT Center',
      cabangName: 'KC Manado',
      fullAddress: 'Jl. Sam Ratulangi Manado',
      locationTag: 'IT Center',
      tagColor: Colors.blue,
      lat: 1.488,
      lng: 124.842,
    );

    test('lokasi tanpa log berstatus belum maintenance', () {
      final statuses = MaintenanceLogService.buildStatuses([testLoc1], []);
      expect(statuses.length, 1);
      final s = statuses.first;
      expect(s.sudah, isFalse);
      expect(s.adaTemuan, isFalse);
      expect(s.logs.isEmpty, isTrue);
    });

    test('log terbaru aman setelah log lama bertemuan menghasilkan sudah & tidak adaTemuan', () {
      const logLamaBertemuan = MaintenanceLogEntry(
        id: 'log_old',
        tanggal: '2026-11-01',
        jamSelesai: '08:00',
        posId: 'POS-1',
        posName: 'Pos Mega Mall 1',
        teknisiNama: 'Teknisi 1',
        temuan: [
          MaintenanceTemuan(
            label: 'Palang Patah',
            status: 'tidak_sesuai',
            alasan: 'Patah tertabrak',
            urgent: true,
          ),
        ],
      );

      const logBaruAman = MaintenanceLogEntry(
        id: 'log_new',
        tanggal: '2026-11-02',
        jamSelesai: '11:00',
        posId: 'POS-1',
        posName: 'Pos Mega Mall 1',
        teknisiNama: 'Teknisi 2',
        temuan: [], // Sudah diganti dan aman
      );

      // Kirim dalam urutan acak/campur
      final statuses = MaintenanceLogService.buildStatuses(
        [testLoc1],
        [logLamaBertemuan, logBaruAman],
      );

      expect(statuses.length, 1);
      final s = statuses.first;
      expect(s.sudah, isTrue);
      // Status warna mengikuti log TERBARU:
      expect(s.adaTemuan, isFalse);
      expect(s.logs.first.id, 'log_new');
    });

    test('mencocokkan log via posName fallback jika posId berbeda/kosong', () {
      const logFallback = MaintenanceLogEntry(
        id: 'log_fallback',
        tanggal: '2026-11-02',
        jamSelesai: '13:00',
        posId: 'POS-DIFFERENT-ID',
        posName: 'Pos IT Center', // Sesuai posName testLoc2
        teknisiNama: 'Teknisi Budi',
        temuan: [
          MaintenanceTemuan(
            label: 'Printer Thermal',
            status: 'perlu_cek_manual',
            alasan: 'Roll paper hampir habis',
            urgent: false,
          ),
        ],
      );

      final statuses = MaintenanceLogService.buildStatuses(
        [testLoc2],
        [logFallback],
      );

      expect(statuses.length, 1);
      final s = statuses.first;
      expect(s.sudah, isTrue);
      expect(s.adaTemuan, isTrue);
      expect(s.logs.first.id, 'log_fallback');
    });
  });

  group('MaintenanceLogEntry serialisasi toRow & fromJson roundtrip', () {
    test('mempertahankan data dan list temuan dengan presisi', () {
      const original = MaintenanceLogEntry(
        id: 'log_roundtrip_01',
        tanggal: '2026-11-02',
        jamSelesai: '14:20',
        posId: 'POS-PBM-01',
        posName: 'Siloam Hospital Manado',
        teknisiNama: 'Eko Prasetyo',
        teknisiNpp: 'BSS-MND-09',
        templateId: 'tpl_maint_pos',
        templateName: 'Maintenance: Pos Parkir & Booth',
        totalPoin: 15,
        sesuaiPoin: 13,
        temuan: [
          MaintenanceTemuan(
            label: 'Tombol Tiket',
            status: 'tidak_sesuai',
            alasan: 'Tombol aus dan agak macet',
            urgent: true,
          ),
          MaintenanceTemuan(
            label: 'Lampu Indikator',
            status: 'perlu_cek_manual',
            alasan: 'Kedip redup',
            urgent: false,
          ),
        ],
      );

      final row = original.toRow();
      final restored = MaintenanceLogEntry.fromJson(row);

      expect(restored.id, original.id);
      expect(restored.tanggal, original.tanggal);
      expect(restored.jamSelesai, original.jamSelesai);
      expect(restored.posId, original.posId);
      expect(restored.posName, original.posName);
      expect(restored.teknisiNama, original.teknisiNama);
      expect(restored.teknisiNpp, original.teknisiNpp);
      expect(restored.templateId, original.templateId);
      expect(restored.templateName, original.templateName);
      expect(restored.totalPoin, original.totalPoin);
      expect(restored.sesuaiPoin, original.sesuaiPoin);
      expect(restored.hasTemuan, isTrue);
      expect(restored.temuan.length, 2);

      expect(restored.temuan[0].label, 'Tombol Tiket');
      expect(restored.temuan[0].status, 'tidak_sesuai');
      expect(restored.temuan[0].alasan, 'Tombol aus dan agak macet');
      expect(restored.temuan[0].urgent, isTrue);

      expect(restored.temuan[1].label, 'Lampu Indikator');
      expect(restored.temuan[1].status, 'perlu_cek_manual');
      expect(restored.temuan[1].alasan, 'Kedip redup');
      expect(restored.temuan[1].urgent, isFalse);
    });
  });

  group('Jadwal Fase Bulanan (MaintenanceLogService & PosMaintenanceStatus)', () {
    test('phaseForDate mengembalikan fase batas dengan presisi', () {
      expect(MaintenanceLogService.phaseForDate(DateTime(2026, 11, 1)), 1);
      expect(MaintenanceLogService.phaseForDate(DateTime(2026, 11, 7)), 1);
      expect(MaintenanceLogService.phaseForDate(DateTime(2026, 11, 8)), 2);
      expect(MaintenanceLogService.phaseForDate(DateTime(2026, 11, 14)), 2);
      expect(MaintenanceLogService.phaseForDate(DateTime(2026, 11, 15)), 3);
      expect(MaintenanceLogService.phaseForDate(DateTime(2026, 11, 21)), 3);
      expect(MaintenanceLogService.phaseForDate(DateTime(2026, 11, 22)), 4);
      expect(MaintenanceLogService.phaseForDate(DateTime(2026, 11, 30)), 4);
      expect(MaintenanceLogService.phaseForDate(DateTime(2026, 10, 31)), 4);
    });

    test('phaseForTemplate mengidentifikasi fase template dan mengembalikan null untuk lengkap/lainnya', () {
      expect(MaintenanceLogService.phaseForTemplate('tpl_maint_manless'), 1);
      expect(MaintenanceLogService.phaseForTemplate('tpl_maint_pos'), 2);
      expect(MaintenanceLogService.phaseForTemplate('tpl_maint_barrier'), 3);
      expect(MaintenanceLogService.phaseForTemplate('tpl_maint_server'), 4);
      expect(MaintenanceLogService.phaseForTemplate('tpl_maint_lengkap'), isNull);
      expect(MaintenanceLogService.phaseForTemplate('tpl_absensi'), isNull);
      expect(MaintenanceLogService.phaseForTemplate(null), isNull);
    });

    test('isPhaseDone mendeteksi penyelesaian fase dari log manless PBM', () {
      const pbmLoc = PosLocation(
        posId: 'POS-PBM-01',
        posName: 'Pasar Bersehati Manado',
        cabangName: 'KC BSG',
        fullAddress: 'Jl. Nusantara No.17, Calaca, Wenang, Kota Manado, Sulawesi Utara',
        locationTag: 'PBM',
        tagColor: Colors.orange,
        lat: 1.4980709,
        lng: 124.8415709,
      );

      const logManlessPBM = MaintenanceLogEntry(
        id: 'log_pbm_manless_01',
        tanggal: '2026-11-03',
        jamSelesai: '09:30',
        posId: 'POS-PBM-01',
        posName: 'Pasar Bersehati Manado',
        teknisiNama: 'Teknisi Alfa',
        templateId: 'tpl_maint_manless',
        templateName: 'Maintenance: Manless & Pulau Gate',
        totalPoin: 8,
        sesuaiPoin: 8,
        temuan: [],
      );

      const status = PosMaintenanceStatus(
        location: pbmLoc,
        wilayah: 'Manado',
        logs: [logManlessPBM],
      );

      // Fase 1 (Manless) selesai, fase 2..4 belum
      expect(status.isPhaseDone(1), isTrue);
      expect(status.isPhaseDone(2), isFalse);
      expect(status.isPhaseDone(3), isFalse);
      expect(status.isPhaseDone(4), isFalse);
      expect(status.isAllPhasesDone, isFalse);
      expect(status.statusForPhase(1), 'selesai_aman');
      expect(status.statusForPhase(2), 'belum');
    });
  });

  group('MaintenanceLogService.entriesFromSubmission & isManadoSubmission', () {
    test(
      'lengkap submission memecah menjadi 4 entri dan menandai 4 fase di map',
      () {
        final submission = MaintenanceSubmission(
          id: 'sub_lengkap_01',
          templateId: 'tpl_maint_lengkap',
          templateName: 'Maintenance Lengkap',
          userId: 'usr_01',
          userName: 'Teknisi Alfa',
          userNpp: 'NPP-101',
          posId: 'POS-PBM-01',
          posName: 'Pasar Bersehati Manado',
          cabangName: 'KC Manado',
          points: [
            const MaintenancePointResult(
              pointId: 'bar_1_01',
              label: 'Barrier Gate 1 Fisik & Motor',
              status: PointStatus.sesuai,
              urgensi: TingkatUrgensi.normal,
              alasan: '',
            ),
            const MaintenancePointResult(
              pointId: 'man_1_01',
              label: 'Manless 1 Push Button',
              status: PointStatus.tidakSesuai,
              urgensi: TingkatUrgensi.urgent,
              alasan: 'Tombol tiket rusak',
            ),
            const MaintenancePointResult(
              pointId: 'pos_1_01',
              label: 'Pos 1 Kerapian Kabel',
              status: PointStatus.sesuai,
              urgensi: TingkatUrgensi.normal,
              alasan: '',
            ),
            const MaintenancePointResult(
              pointId: 'srv_1_01',
              label: 'Server 1 Storage C',
              status: PointStatus.sesuai,
              urgensi: TingkatUrgensi.normal,
              alasan: '',
            ),
          ],
          createdAt: DateTime(2026, 11, 2, 8, 30),
          updatedAt: DateTime(2026, 11, 2, 9, 15),
        );

        final entries = MaintenanceLogService.entriesFromSubmission(submission);

        expect(entries.length, 4);
        expect(entries.map((e) => e.templateId).toList(), [
          'tpl_maint_barrier',
          'tpl_maint_manless',
          'tpl_maint_pos',
          'tpl_maint_server',
        ]);

        final manlessEntry =
            entries.firstWhere((e) => e.templateId == 'tpl_maint_manless');
        expect(manlessEntry.id, 'sub_lengkap_01__tpl_maint_manless');
        expect(manlessEntry.temuan.length, 1);
        expect(manlessEntry.sesuaiPoin, 0);
        expect(manlessEntry.totalPoin, 1);
        expect(manlessEntry.hasTemuan, isTrue);

        final pbmLoc = LocationService.getLocationsByBranch(AppBranch.manado)
            .firstWhere((p) => p.posId == 'POS-PBM-01');

        final statuses = MaintenanceLogService.buildStatuses([pbmLoc], entries);
        expect(statuses.length, 1);
        final status = statuses.first;

        expect(status.isPhaseDone(1), isTrue);
        expect(status.isPhaseDone(2), isTrue);
        expect(status.isPhaseDone(3), isTrue);
        expect(status.isPhaseDone(4), isTrue);
        expect(status.hasPhaseTemuan(1), isTrue);
        expect(status.hasPhaseTemuan(2), isFalse);
        expect(status.hasPhaseTemuan(3), isFalse);
        expect(status.hasPhaseTemuan(4), isFalse);
      },
    );

    test('lengkap hanya bar_ dan pos_ menghasilkan 2 entri, fase 1 dan 4 belum', () {
      final submission = MaintenanceSubmission(
        id: 'sub_lengkap_02',
        templateId: 'tpl_maint_lengkap',
        templateName: 'Maintenance Lengkap',
        userId: 'usr_02',
        userName: 'Teknisi Beta',
        userNpp: 'NPP-102',
        posId: 'POS-PBM-01',
        posName: 'Pasar Bersehati Manado',
        cabangName: 'KC Manado',
        points: [
          const MaintenancePointResult(
            pointId: 'bar_1_01',
            label: 'Barrier Gate 1',
            status: PointStatus.sesuai,
            urgensi: TingkatUrgensi.normal,
            alasan: '',
          ),
          const MaintenancePointResult(
            pointId: 'pos_1_01',
            label: 'Pos 1',
            status: PointStatus.sesuai,
            urgensi: TingkatUrgensi.normal,
            alasan: '',
          ),
        ],
        createdAt: DateTime(2026, 11, 2, 10, 0),
        updatedAt: DateTime(2026, 11, 2, 10, 30),
      );

      final entries = MaintenanceLogService.entriesFromSubmission(submission);
      expect(entries.length, 2);
      expect(entries.map((e) => e.templateId).toList(), [
        'tpl_maint_barrier',
        'tpl_maint_pos',
      ]);

      final pbmLoc = LocationService.getLocationsByBranch(AppBranch.manado)
          .firstWhere((p) => p.posId == 'POS-PBM-01');

      final statuses = MaintenanceLogService.buildStatuses([pbmLoc], entries);
      final status = statuses.first;

      expect(status.isPhaseDone(1), isFalse);
      expect(status.isPhaseDone(2), isTrue);
      expect(status.isPhaseDone(3), isTrue);
      expect(status.isPhaseDone(4), isFalse);
    });

    test('non-lengkap submission mengembalikan tepat 1 entri dengan id sama', () {
      final submission = MaintenanceSubmission(
        id: 'sub_pos_single',
        templateId: 'tpl_maint_pos',
        templateName: 'Maintenance: Pos Parkir',
        userId: 'usr_03',
        userName: 'Teknisi Charlie',
        userNpp: 'NPP-103',
        posId: 'POS-PBM-01',
        posName: 'Pasar Bersehati Manado',
        cabangName: 'KC Manado',
        points: [
          const MaintenancePointResult(
            pointId: 'pos_1_01',
            label: 'Pos 1',
            status: PointStatus.sesuai,
            urgensi: TingkatUrgensi.normal,
            alasan: '',
          ),
        ],
        createdAt: DateTime(2026, 11, 2, 11, 0),
        updatedAt: DateTime(2026, 11, 2, 11, 20),
      );

      final entries = MaintenanceLogService.entriesFromSubmission(submission);
      expect(entries.length, 1);
      expect(entries.first.id, 'sub_pos_single');
      expect(entries.first.templateId, 'tpl_maint_pos');
    });

    test('isManadoSubmission memvalidasi posId Manado vs HO Makassar', () {
      final subHo = MaintenanceSubmission(
        id: 'sub_ho',
        templateId: 'tpl_maint_pos',
        templateName: 'Pos HO',
        userId: 'usr_ho',
        userName: 'Teknisi HO',
        userNpp: 'NPP-999',
        posId: 'POS-HO-MGAM-01',
        posName: 'HO Makassar',
        cabangName: 'HO',
        points: const [],
        createdAt: DateTime(2026, 11, 2, 12, 0),
        updatedAt: DateTime(2026, 11, 2, 12, 10),
      );

      final subManado = MaintenanceSubmission(
        id: 'sub_pbm',
        templateId: 'tpl_maint_pos',
        templateName: 'Pos Manado',
        userId: 'usr_mnd',
        userName: 'Teknisi Manado',
        userNpp: 'NPP-101',
        posId: 'POS-PBM-01',
        posName: 'Pasar Bersehati Manado',
        cabangName: 'KC Manado',
        points: const [],
        createdAt: DateTime(2026, 11, 2, 12, 0),
        updatedAt: DateTime(2026, 11, 2, 12, 10),
      );

      expect(MaintenanceLogService.isManadoSubmission(subHo), isFalse);
      expect(MaintenanceLogService.isManadoSubmission(subManado), isTrue);
    });
  });

  group('MaintenanceLogEntry.fromJson malformed temuan JSON robustness', () {
    test(
      'menangani temuan null, tipe bukan List, elemen rusak, dan field kosong tanpa crash',
      () {
        // 1. temuan null
        final entryNull =
            MaintenanceLogEntry.fromJson({'id': 'log_null', 'temuan': null});
        expect(entryNull.temuan, isEmpty);

        // 2. temuan tipe primitif (bukan List)
        final entryString = MaintenanceLogEntry.fromJson(
          {'id': 'log_str', 'temuan': 'corrupted'},
        );
        expect(entryString.temuan, isEmpty);

        // 3. temuan List berisi elemen rusak (null, string, int, list bersarang)
        final entryCorruptedItems = MaintenanceLogEntry.fromJson({
          'id': 'log_corrupted',
          'temuan': [
            null,
            'bukan_map',
            12345,
            ['nested_list'],
          ],
        });
        expect(entryCorruptedItems.temuan, isEmpty);

        // 4. temuan Map dengan field parsial / kosong dan dynamic map
        final entryPartial = MaintenanceLogEntry.fromJson({
          'id': 'log_partial',
          'temuan': [
            {'label': 'Cek CCTV'},
            <dynamic, dynamic>{
              'label': null,
              'status': null,
              'alasan': null,
              'urgent': null,
            },
          ],
        });
        expect(entryPartial.temuan.length, 2);
        expect(entryPartial.temuan[0].label, 'Cek CCTV');
        expect(entryPartial.temuan[0].status, 'tidak_sesuai');
        expect(entryPartial.temuan[0].alasan, '');
        expect(entryPartial.temuan[0].urgent, isFalse);

        expect(entryPartial.temuan[1].label, '');
        expect(entryPartial.temuan[1].status, 'tidak_sesuai');
        expect(entryPartial.temuan[1].alasan, '');
        expect(entryPartial.temuan[1].urgent, isFalse);
      },
    );
  });
}
