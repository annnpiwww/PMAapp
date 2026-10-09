import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/models/user_model.dart';
import 'package:bssparking_timemark/data/repositories/auth_repository.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
  });

  group('AuthRepository Multi-Branch & Offline Login Tests', () {
    test('Bali SPV can login offline and auto-locks branch to KC Bali', () async {
      final success = await AuthRepository.instance.loginWithPassword(
        identity: 'indra@pma.com',
        password: 'spvbali',
      );

      expect(success, isTrue);
      final user = AuthRepository.instance.currentUser;
      expect(user, isNotNull);
      expect(user!.role, equals(UserRole.supervisor));
      expect(user.nama, contains('Indra Yohana'));
      expect(user.cabangName, equals('KC Bali'));
      expect(BranchService.instance.currentBranch, equals(AppBranch.bali));
    });

    test('Bali technicians can login offline with email and username', () async {
      // 1. Login with email
      final success1 = await AuthRepository.instance.loginWithPassword(
        identity: 'toro@pma.com',
        password: 'teknisi123',
      );
      expect(success1, isTrue);
      expect(AuthRepository.instance.currentUser?.nama, equals('Alif Candra Triantoro'));
      expect(AuthRepository.instance.currentUser?.cabangName, equals('KC Bali'));
      expect(BranchService.instance.currentBranch, equals(AppBranch.bali));

      // 2. Login with clean username
      final success2 = await AuthRepository.instance.loginWithPassword(
        identity: 'cokagung',
        password: 'teknisi123',
      );
      expect(success2, isTrue);
      expect(AuthRepository.instance.currentUser?.nama, equals('ANAK AGUNG GEDE AGUNG YUSTIKAWANGSA'));
      expect(AuthRepository.instance.currentUser?.cabangName, equals('KC Bali'));
      expect(BranchService.instance.currentBranch, equals(AppBranch.bali));

      // 3. Login Parta, Suardana, Dika
      final partaOk = await AuthRepository.instance.loginWithPassword(
        identity: 'parta@pma.com',
        password: 'teknisi123',
      );
      expect(partaOk, isTrue);
      expect(AuthRepository.instance.currentUser?.nama, equals('Putu Hyan Parta Wijaya'));

      final suardanaOk = await AuthRepository.instance.loginWithPassword(
        identity: 'suardana@pma.com',
        password: 'teknisi123',
      );
      expect(suardanaOk, isTrue);
      expect(AuthRepository.instance.currentUser?.nama, equals('I PUTU GEDE SUARDANA PUTRA'));

      final dikaOk = await AuthRepository.instance.loginWithPassword(
        identity: 'dika@pma.com',
        password: 'teknisi123',
      );
      expect(dikaOk, isTrue);
      expect(AuthRepository.instance.currentUser?.nama, equals('ADITYA CAESAR BAGASKARA'));
    });

    test('Manado user login auto-locks branch to KC Manado', () async {
      final success = await AuthRepository.instance.loginWithPassword(
        identity: 'farhan lakoro',
        password: 'flakoro05',
      );

      expect(success, isTrue);
      final user = AuthRepository.instance.currentUser;
      expect(user, isNotNull);
      expect(user!.role, equals(UserRole.supervisor));
      expect(user.nama, equals('Farhan Lakoro'));
      expect(user.cabangName, equals('KC Manado'));
      expect(BranchService.instance.currentBranch, equals(AppBranch.manado));
    });

    test('Manado technicians with @pma.com emails login offline and auto-lock branch to KC Manado', () async {
      final success = await AuthRepository.instance.loginWithPassword(
        identity: 'ryan@pma.com',
        password: 'teknisi123',
      );

      expect(success, isTrue);
      final user = AuthRepository.instance.currentUser;
      expect(user, isNotNull);
      expect(user!.role, equals(UserRole.petugas));
      expect(user.nama, equals('Ryan Lumasuge'));
      expect(user.cabangName, equals('KC Manado'));
      expect(BranchService.instance.currentBranch, equals(AppBranch.manado));

      final farhanOk = await AuthRepository.instance.loginWithPassword(
        identity: 'farhan@pma.com',
        password: 'flakoro05',
      );
      expect(farhanOk, isTrue);
      expect(BranchService.instance.currentBranch, equals(AppBranch.manado));
    });

    test('Wrong password fails offline authentication', () async {
      final fail = await AuthRepository.instance.loginWithPassword(
        identity: 'indra@pma.com',
        password: 'wrong_password',
      );
      expect(fail, isFalse);
    });
  });
}
