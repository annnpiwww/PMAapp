import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/absensi_setup_service.dart';
import 'package:bssparking_timemark/data/models/attendance_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
  });

  group('AbsensiSetupService Branch Isolation & Reactivity Tests', () {
    test('Default branch is Manado: shift is Manado shift and location is PBM', () {
      final setup = AbsensiSetupService.instance;
      expect(BranchService.instance.currentBranch, equals(AppBranch.manado));
      expect(setup.effectiveLokasiStandby, equals('PBM'));
      expect(BranchService.instance.getShifts(branch: AppBranch.manado), contains(setup.effectiveJadwalShift));
    });

    test('Switching branch to Bali automatically updates shifts and standby location', () async {
      final setup = AbsensiSetupService.instance;
      expect(setup.effectiveLokasiStandby, equals('PBM'));

      // Switch to Bali
      await BranchService.instance.setBranch(AppBranch.bali);

      expect(BranchService.instance.currentBranch, equals(AppBranch.bali));
      expect(setup.effectiveLokasiStandby, equals('PBKD'));
      expect(BranchService.instance.getShifts(branch: AppBranch.bali), contains(setup.effectiveJadwalShift));

      // Bali shifts must not contain Manado Shift 1 (03:00 - 11:00)
      expect(setup.effectiveJadwalShift.contains('03:00'), isFalse);
    });

    test('Manual shift selection is scoped per branch and does not bleed', () async {
      final setup = AbsensiSetupService.instance;

      // 1. In Manado, pick Shift 3 (14:00 - 22:00) and location TBM
      await BranchService.instance.setBranch(AppBranch.manado);
      setup.updateShift('Shift 3 (14:00 - 22:00)');
      setup.updateLokasi('TBM');
      expect(setup.effectiveJadwalShift, equals('Shift 3 (14:00 - 22:00)'));
      expect(setup.effectiveLokasiStandby, equals('TBM'));

      // 2. Switch to Bali, pick Shift 4 (08.30 - 16.30) and location PCD
      await BranchService.instance.setBranch(AppBranch.bali);
      setup.updateShift('Shift 4 (08.30 - 16.30)');
      setup.updateLokasi('PCD');
      expect(setup.effectiveJadwalShift, equals('Shift 4 (08.30 - 16.30)'));
      expect(setup.effectiveLokasiStandby, equals('PCD'));

      // 3. Switch back to Manado -> Shift must return to Manado Shift 3 and location TBM
      await BranchService.instance.setBranch(AppBranch.manado);
      expect(setup.effectiveJadwalShift, equals('Shift 3 (14:00 - 22:00)'));
      expect(setup.effectiveLokasiStandby, equals('TBM'));

      // 4. Switch back to Bali -> Shift must return to Bali Shift 4 and location PCD
      await BranchService.instance.setBranch(AppBranch.bali);
      expect(setup.effectiveJadwalShift, equals('Shift 4 (08.30 - 16.30)'));
      expect(setup.effectiveLokasiStandby, equals('PCD'));
    });

    test('AttendanceArchiveScreen filters records strictly per branch without cross-viewing', () async {
      await StorageService.clearAllAttendanceRecords();
      final manadoRecord = AttendanceRecord(
        id: 'att_manado',
        timestamp: DateTime(2026, 10, 9, 8, 0),
        type: AttendanceType.masuk,
        shiftName: 'Shift 1 (03:00 - 11:00)',
        technicianName: 'Ryan Lumasuge',
        posName: 'PBM',
        lat: 1.49,
        lng: 124.84,
        fullAddress: 'Pasar Bersehati Manado',
      );
      final baliRecord = AttendanceRecord(
        id: 'att_bali',
        timestamp: DateTime(2026, 10, 9, 8, 0),
        type: AttendanceType.masuk,
        shiftName: 'Shift 1 (06.00 - 14.00)',
        technicianName: 'Putu Hyan Parta Wijaya',
        posName: 'PBKD',
        lat: -8.67,
        lng: 115.21,
        fullAddress: 'Denpasar, Bali',
      );
      await StorageService.saveAttendanceRecord(manadoRecord);
      await StorageService.saveAttendanceRecord(baliRecord);

      // 1. Manado active:
      await BranchService.instance.setBranch(AppBranch.manado);
      final all = StorageService.getAttendanceRecords();
      expect(all.length, equals(2));

      // Filter logic matches AttendanceArchiveScreen
      final currentBranch = BranchService.instance.currentBranch;
      final manadoFiltered = all.where((r) {
        final manadoTechs = BranchService.instance.getTechnicians(branch: AppBranch.manado);
        final baliTechs = BranchService.instance.getTechnicians(branch: AppBranch.bali);
        final nameClean = r.technicianName.toLowerCase().trim();
        if (nameClean.isNotEmpty) {
          final isManadoTech = manadoTechs.any((t) => t.toLowerCase().contains(nameClean) || nameClean.contains(t.toLowerCase()));
          final isBaliTech = baliTechs.any((t) => t.toLowerCase().contains(nameClean) || nameClean.contains(t.toLowerCase()));
          if (isManadoTech && currentBranch == AppBranch.bali) return false;
          if (isBaliTech && currentBranch == AppBranch.manado) return false;
        }
        return true;
      }).toList();

      expect(manadoFiltered.length, equals(1));
      expect(manadoFiltered.first.id, equals('att_manado'));

      // 2. Bali active:
      await BranchService.instance.setBranch(AppBranch.bali);
      final currentBranchBali = BranchService.instance.currentBranch;
      final baliFiltered = all.where((r) {
        final manadoTechs = BranchService.instance.getTechnicians(branch: AppBranch.manado);
        final baliTechs = BranchService.instance.getTechnicians(branch: AppBranch.bali);
        final nameClean = r.technicianName.toLowerCase().trim();
        if (nameClean.isNotEmpty) {
          final isManadoTech = manadoTechs.any((t) => t.toLowerCase().contains(nameClean) || nameClean.contains(t.toLowerCase()));
          final isBaliTech = baliTechs.any((t) => t.toLowerCase().contains(nameClean) || nameClean.contains(t.toLowerCase()));
          if (isManadoTech && currentBranchBali == AppBranch.bali) return false;
          if (isBaliTech && currentBranchBali == AppBranch.manado) return false;
        }
        return true;
      }).toList();

      expect(baliFiltered.length, equals(1));
      expect(baliFiltered.first.id, equals('att_bali'));
    });
  });
}
