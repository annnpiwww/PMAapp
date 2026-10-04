import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/features/templates/screens/template_list_screen.dart';
import 'package:bssparking_timemark/data/repositories/template_repository.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await TemplateRepository.instance.init();
  });

  testWidgets('TemplateListScreen responsive test on multiple narrow screens (collapsed & expanded)',
      (WidgetTester tester) async {
    final testWidths = [320.0, 360.0, 375.0, 390.0, 412.0, 430.0];

    for (final width in testWidths) {
      tester.view.physicalSize = Size(width, 1200.0);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: TemplateListScreen(),
        ),
      );
      await tester.pumpAndSettle();


      // Tap to expand first expansion tile
      final expansionTileFinder = find.byType(ExpansionTile);
      if (expansionTileFinder.evaluate().isNotEmpty) {
        await tester.tap(expansionTileFinder.first);
        await tester.pumpAndSettle();
      }

      // Expect no RenderFlex overflow
      final err = tester.takeException();
      expect(err, isNull,
          reason: 'Overflow occurred on width: $width');
    }
  });
}
