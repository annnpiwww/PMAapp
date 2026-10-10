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

  testWidgets('LoginScreen does not display manual branch selector pills (auto-detected on login)', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify branch selector is removed from UI as requested
    expect(find.text('Cabang Operasional'), findsNothing);
    expect(find.text('📍 KC Manado'), findsNothing);
    expect(find.text('📍 KC Bali'), findsNothing);

    // Verify input fields exist cleanly
    expect(find.text('Email atau Username'), findsOneWidget);
    expect(find.text('Kata Sandi'), findsOneWidget);
  });
}
