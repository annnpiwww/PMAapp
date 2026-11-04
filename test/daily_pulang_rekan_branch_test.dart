import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/services/absensi_setup_service.dart';
import 'package:bssparking_timemark/data/services/branch_service.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/camera/widgets/daily_pulang_bottom_sheet.dart';

const String _lastOption = 'Shift Terakhir / Tidak Ada Pengganti';

const List<String> _manadoNames = [
  'Ryan Lumasuge',
  'Raldy Sangkop',
  'Junifer Manua',
  'Alessandro Sulistyo',
];

const String _nextShiftPrefsKey = 'absensi_next_shift_v1';

Future<void> _pumpSheet(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: DailyPulangBottomSheet())),
  );
  await tester.pump();
}

List<String?> _optionValues(WidgetTester tester) {
  final dropdown = tester.widget<DropdownButton<String>>(
    find.byType(DropdownButton<String>),
  );
  return dropdown.items!.map((item) => item.value).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    BranchService.clientOverride = null;
    BranchService.instance.resetForTesting();
  });

  tearDown(() {
    BranchService.clientOverride = null;
    BranchService.instance.resetForTesting();
  });

  testWidgets('pulang dropdown lists only the active branch technicians', (tester) async {
    // ho -> bali -> manado; each pass re-pumps a fresh State so initState re-reads the branch.
    for (final branch in [AppBranch.ho, AppBranch.bali, AppBranch.manado]) {
      await BranchService.instance.setBranch(branch);
      await tester.pumpAndSettle();

      final expected = BranchService.instance.getTechnicians(branch: branch);
      expect(expected, isNotEmpty, reason: 'fallback list for ${branch.name} must exist');

      await _pumpSheet(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final options = _optionValues(tester);
      for (final name in expected) {
        expect(options, contains(name), reason: '${branch.name} must offer $name');
      }
      expect(options.last, _lastOption, reason: 'no-replacement sentinel must stay last');

      if (branch != AppBranch.manado) {
        for (final leaked in _manadoNames) {
          expect(
            options,
            isNot(contains(leaked)),
            reason: '${branch.name} must not offer Manado technician $leaked',
          );
        }
      }

      // Open the dropdown: the rendered menu must match the same rules.
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      expect(find.text(_lastOption), findsOneWidget);
      for (final name in expected) {
        expect(find.text(name), findsOneWidget);
      }
      if (branch != AppBranch.manado) {
        for (final leaked in _manadoNames) {
          expect(find.text(leaked), findsNothing);
        }
      }
      // Close the menu via its barrier: the last item sits at the screen edge.
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('stale cross-branch shiftSelanjutnya leaves no selection and no assert', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nextShiftPrefsKey, _manadoNames.first);
    await BranchService.instance.setBranch(AppBranch.bali);
    await tester.pumpAndSettle();

    expect(AbsensiSetupService.instance.shiftSelanjutnya, _manadoNames.first);

    await _pumpSheet(tester);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    expect(dropdown.value, isNull, reason: 'stale Manado name must not preselect in bali');
    expect(
      _optionValues(tester),
      isNot(contains(_manadoNames.first)),
    );
  });
}
