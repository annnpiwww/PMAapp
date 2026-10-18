import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/services/absensi_setup_service.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

/// Tugas bareng (1 tugas banyak pelaksana) + serah terima antar shift:
/// satu bukti, satu laporan, dan pekerjaan yang belum selesai tetap terlacak.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
  });

  DailyTaskModel taskContoh({
    String id = 't1',
    String tanggal = '2026-10-18',
    String teknisiNama = 'Andi',
    String judul = 'Pengecoran kabel sensor',
    String peserta = '',
    String serahTerima = '',
    TaskStatus status = TaskStatus.pending,
    String? jamSelesai,
  }) {
    return DailyTaskModel(
      id: id,
      tanggal: tanggal,
      teknisiId: '',
      teknisiNama: teknisiNama,
      posName: 'Pos Simpang Lima',
      posTag: 'SL',
      judul: judul,
      peserta: peserta,
      serahTerima: serahTerima,
      status: status,
      jamSelesai: jamSelesai,
    );
  }

  group('Tugas bareng (peserta)', () {
    test('model membaca daftar peserta dan label pelaksana', () {
      final task = taskContoh(peserta: 'Budi, Candra');
      expect(task.isShared, isTrue);
      expect(task.pesertaList, equals(['Budi', 'Candra']));
      expect(task.labelPelaksana, equals('Andi + Budi + Candra'));
      expect(taskContoh().isShared, isFalse);
    });

    test('tugas ikut tampil untuk pelaksana tambahan, bukan orang lain', () {
      final task = taskContoh(peserta: 'Budi');
      expect(DailyTaskService.isAssignedTo(task, 'Andi'), isTrue);
      expect(DailyTaskService.isAssignedTo(task, 'Budi'), isTrue);
      expect(DailyTaskService.isAssignedTo(task, 'Candra'), isFalse);
    });

    test('createTask menyimpan peserta tanpa menggandakan tugas', () async {
      final first = await DailyTaskService.createTask(
        tanggal: '2026-10-18',
        teknisiNama: 'Andi',
        posName: 'Pos Simpang Lima',
        posTag: 'SL',
        judul: 'Pengecoran kabel sensor',
        peserta: 'Budi',
      );
      final second = await DailyTaskService.createTask(
        tanggal: '2026-10-18',
        teknisiNama: 'Andi',
        posName: 'Pos Simpang Lima',
        posTag: 'SL',
        judul: 'Pengecoran kabel sensor',
        peserta: 'Budi',
      );

      expect(first, isNotNull);
      expect(second!.id, equals(first!.id));

      final cached = DailyTaskService.getCachedTasksLocally()
          .singleWhere((t) => t.id == first.id);
      expect(cached.peserta, equals('Budi'));
      expect(cached.isShared, isTrue);
    });

    test('laporan per tugas menambahkan baris dikerjakan bersama', () {
      final res = DailyTaskService.formatPerTaskReport(
        judul: 'Pengecoran kabel sensor',
        notes: 'Kabel sudah dicor rapi',
        partners: ['Budi'],
      );
      expect(res, equals('Kabel sudah dicor rapi\nDikerjakan bersama Budi'));

      final tanpaPartner = DailyTaskService.formatPerTaskReport(
        judul: 'Pengecoran kabel sensor',
        notes: 'Kabel sudah dicor rapi',
      );
      expect(tanpaPartner, equals('Kabel sudah dicor rapi'));
    });

    test('briefing pagi menandai tugas bareng dan tugas lanjutan', () {
      final result = DailyTaskService.formatMorningDispatchReport(
        tasks: [
          taskContoh(peserta: 'Budi'),
          taskContoh(
            id: 't2',
            teknisiNama: 'Budi',
            judul: 'Perbaikan loop detector',
            serahTerima: 'Andi|Budi|Waktu habis (akhir shift)|18 Okt 21:10',
          ),
        ],
        techShiftMap: {
          'Andi': 'Shift 1 (03:00 - 11:00)',
          'Budi': 'Shift 2 (10:00 - 14:00)',
        },
        branch: AppBranch.manado,
      );

      expect(result, contains('1. Pengecoran kabel sensor (bersama Budi)'));
      expect(result, contains('(lanjutan dari Andi)'));
    });
  });

  group('Serah terima antar shift', () {
    test('model membaca log serah terima terbuka', () {
      final task = taskContoh(serahTerima: 'Andi||Material belum datang|18 Okt 21:10');
      expect(task.isHandover, isTrue);
      expect(task.handoverDari, equals('Andi'));
      expect(task.isOpenHandover, isTrue);
      expect(task.handoverList.last.alasan, equals('Material belum datang'));
    });

    test('transferTask ke penerus: pemilik pindah, log & pelaksana lama tercatat', () async {
      final dibuat = await DailyTaskService.createTask(
        tanggal: '2026-10-18',
        teknisiNama: 'Andi',
        posName: 'Pos Simpang Lima',
        posTag: 'SL',
        judul: 'Pengecoran kabel sensor',
        peserta: 'Candra',
      );
      // Paksa id lokal supaya transfer tidak menulis ke server saat pengujian.
      final lokal = dibuat!.copyWith(id: 'local_serah_terima_1');

      final ok = await DailyTaskService.transferTask(
        task: lokal,
        keTeknisi: 'Budi',
        alasan: 'Waktu habis (akhir shift)',
        olehSiapa: 'Andi',
      );

      expect(ok, isTrue);
      final updated = DailyTaskService.getCachedTasksLocally()
          .firstWhere((t) => t.id == lokal.id);
      expect(updated.teknisiNama, equals('Budi'));
      expect(updated.peserta, isEmpty);
      expect(updated.handoverList.last.ke, equals('Budi'));
      expect(updated.handoverList.last.dari, equals('Andi'));
      expect(updated.handoverList.last.alasan, equals('Waktu habis (akhir shift)'));
      expect(updated.isOpenHandover, isFalse);
      expect(DailyTaskService.isAssignedTo(updated, 'Budi'), isTrue);
    });

    test('transferTask tanpa penerus: pemilik tetap, masuk daftar terbuka', () async {
      final dibuat = await DailyTaskService.createTask(
        tanggal: '2026-10-18',
        teknisiNama: 'Andi',
        posName: 'Pos PBM',
        posTag: 'PBM',
        judul: 'Ganti bearing barrier',
      );
      final lokal = dibuat!.copyWith(id: 'local_serah_terima_2');

      final ok = await DailyTaskService.transferTask(
        task: lokal,
        keTeknisi: '',
        alasan: 'Hujan / kondisi gelap',
        olehSiapa: 'Andi',
      );

      expect(ok, isTrue);
      final updated = DailyTaskService.getCachedTasksLocally()
          .firstWhere((t) => t.id == lokal.id);
      expect(updated.teknisiNama, equals('Andi'));
      expect(updated.isOpenHandover, isTrue);
      expect(DailyTaskService.isAssignedTo(updated, 'Budi'), isFalse);
    });

    test('claimTask memindahkan tugas terbuka ke pengklaim', () async {
      final dibuat = await DailyTaskService.createTask(
        tanggal: '2026-10-18',
        teknisiNama: 'Andi',
        posName: 'Pos MPP',
        posTag: 'MPP',
        judul: 'Pembersihan pos parkir',
      );
      final lokal = dibuat!.copyWith(id: 'local_serah_terima_3');

      await DailyTaskService.transferTask(
        task: lokal,
        keTeknisi: '',
        alasan: 'Alat kurang',
        olehSiapa: 'Andi',
      );
      final terbuka = DailyTaskService.getCachedTasksLocally()
          .firstWhere((t) => t.id == lokal.id);
      expect(terbuka.isOpenHandover, isTrue);

      final ok = await DailyTaskService.claimTask(task: terbuka, olehSiapa: 'Budi');

      expect(ok, isTrue);
      final diambil = DailyTaskService.getCachedTasksLocally()
          .firstWhere((t) => t.id == lokal.id);
      expect(diambil.teknisiNama, equals('Budi'));
      expect(diambil.isOpenHandover, isFalse);
      expect(diambil.handoverList.last.alasan, equals('Ambil tugas terbuka'));
    });

    test('rekap SPV: tugas bareng satu baris, progres per tanggal, serah terima tampil', () {
      final recap = DailyTaskService.formatSpvTeamRecap(
        tanggal: '2026-10-18',
        spvName: 'Farhan',
        branch: AppBranch.manado,
        tasks: [
          taskContoh(
            id: 'selesai',
            peserta: 'Budi',
            status: TaskStatus.completed,
            jamSelesai: '14:20',
          ),
          taskContoh(
            id: 'serah',
            teknisiNama: 'Budi',
            judul: 'Perbaikan loop detector',
            serahTerima: 'Andi|Budi|Material belum datang|18 Okt 21:10',
          ),
          taskContoh(
            id: 'terbuka',
            tanggal: '2026-10-17',
            teknisiNama: 'Candra',
            judul: 'Perbaikan palang',
            serahTerima: 'Candra||Butuh 2 orang|17 Okt 21:00',
          ),
        ],
      );

      expect(recap, contains('Progress : 1/2 (50%)'));
      expect(recap, contains('Andi + Budi - Pengecoran kabel sensor'));
      expect(recap, contains('Serah Terima (belum selesai):'));
      expect(recap, contains('Andi → Budi, Material belum datang'));
      expect(recap, contains('Candra → terbuka, siapa pun boleh ambil'));
      expect(recap, contains('[lanjutan dari Candra]'));
      // tugas bareng terhitung untuk pemilik dan pelaksananya
      expect(recap, contains('Andi : 1/1 selesai'));
      expect(recap, contains('Budi : 1/2 selesai'));
      expect(recap, contains('Candra : 0/1 selesai'));
    });
  });

  group('Tugas terbuka untuk shift berikutnya', () {
    setUp(() => AbsensiSetupService.instance.jamPulang = '17:00');
    tearDown(() => AbsensiSetupService.instance.jamPulang = '');

    final jam5Sore = DateTime(2026, 10, 18, 16, 30);
    final jam9Malam = DateTime(2026, 10, 18, 21, 10);

    test('pending sebelum jam pulang masih milik pemiliknya', () {
      final task = taskContoh(tanggal: '2026-10-18');
      expect(DailyTaskService.isTerbukaUntukShiftLain(task, sekarang: jam5Sore), isFalse);
    });

    test('pending setelah jam pulang otomatis terbuka', () {
      final task = taskContoh(tanggal: '2026-10-18');
      expect(DailyTaskService.isTerbukaUntukShiftLain(task, sekarang: jam9Malam), isTrue);
    });

    test('pending dari hari sebelumnya otomatis terbuka', () {
      final task = taskContoh(tanggal: '2026-10-17');
      expect(DailyTaskService.isTerbukaUntukShiftLain(task, sekarang: jam5Sore), isTrue);
    });

    test('tugas yang dilepas manual langsung terbuka', () {
      final task = taskContoh(
        tanggal: '2026-10-18',
        serahTerima: 'Andi||Waktu habis|18 Okt 16:00',
      );
      expect(DailyTaskService.isTerbukaUntukShiftLain(task, sekarang: jam5Sore), isTrue);
    });

    test('tugas selesai dan jadwal besok tidak ikut terbuka', () {
      expect(
        DailyTaskService.isTerbukaUntukShiftLain(
          taskContoh(tanggal: '2026-10-18', status: TaskStatus.completed),
          sekarang: jam9Malam,
        ),
        isFalse,
      );
      expect(
        DailyTaskService.isTerbukaUntukShiftLain(
          taskContoh(tanggal: '2026-10-19'),
          sekarang: jam9Malam,
        ),
        isFalse,
      );
    });
  });
}
