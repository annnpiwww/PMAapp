import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';

DailyTaskModel _task(String teknisi, {TaskStatus status = TaskStatus.completed}) {
  return DailyTaskModel(
    id: 'id-$teknisi',
    tanggal: '2026-10-18',
    teknisiId: 't-$teknisi',
    teknisiNama: teknisi,
    posName: 'PBM',
    posTag: 'PBM',
    judul: 'Cek gate',
    status: status,
  );
}

void main() {
  group('Rekap SPV tidak kebawa tugas cabang lain', () {
    final teknisiBali = BranchService.instance.getTechnicians(branch: AppBranch.bali).first;
    final teknisiManado = BranchService.instance.getTechnicians(branch: AppBranch.manado).first;

    final tasks = [
      _task(teknisiBali),
      _task(teknisiBali, status: TaskStatus.pending),
      _task(teknisiManado),
      _task(teknisiManado, status: TaskStatus.pending),
    ];

    test('SPV Bali hanya melihat tugas teknisi Bali', () {
      final hasil = DailyTaskService.tasksForBranch(tasks, branch: AppBranch.bali);
      expect(hasil.length, 2);
      expect(hasil.every((t) => t.teknisiNama == teknisiBali), isTrue);
      expect(hasil.where((t) => t.isCompleted).length, 1);
    });

    test('SPV Manado hanya melihat tugas teknisi Manado', () {
      final hasil = DailyTaskService.tasksForBranch(tasks, branch: AppBranch.manado);
      expect(hasil.length, 2);
      expect(hasil.every((t) => t.teknisiNama == teknisiManado), isTrue);
    });

    test('rekap cabang bersih: tanpa tugas cabang lain, progress 0/0', () {
      final hanyaManado = [for (final t in tasks) t];
      final untukBali = DailyTaskService.tasksForBranch(hanyaManado, branch: AppBranch.bali);
      final kosong = DailyTaskService.tasksForBranch(
        hanyaManado.where((t) => t.teknisiNama == teknisiManado).toList(),
        branch: AppBranch.bali,
      );
      expect(kosong, isEmpty, reason: 'tugas Manado tidak boleh muncul di cabang Bali');

      final recap = DailyTaskService.formatSpvTeamRecap(
        tanggal: '2026-10-18',
        tasks: untukBali,
        spvName: 'SPV Bali',
        cabangName: 'KC Bali',
      );
      expect(recap.contains(teknisiManado), isFalse);
      expect(recap.contains('Progress : 1/2'), isTrue);
    });
  });
}
