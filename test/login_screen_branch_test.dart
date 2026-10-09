import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/auth/screens/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.instance.resetForTesting();
  });

  testWidgets('LoginScreen displays branch selector pills and toggles branch correctly', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify branch selector exists with Manado selected by default
    expect(find.text('Cabang Operasional'), findsOneWidget);
    expect(find.text('📍 KC Manado'), findsOneWidget);
    expect(find.text('📍 KC Bali'), findsOneWidget);
    expect(BranchService.instance.currentBranch, equals(AppBranch.manado));

    // 2. Tap KC Bali pill
    await tester.tap(find.text('📍 KC Bali'));
    await tester.pumpAndSettle();

    // Verify branch changed to Bali
    expect(BranchService.instance.currentBranch, equals(AppBranch.bali));

    // 3. Tap KC Manado pill
    await tester.tap(find.text('📍 KC Manado'));
    await tester.pumpAndSettle();

    // Verify branch changed back to Manado
    expect(BranchService.instance.currentBranch, equals(AppBranch.manado));
  });
}
