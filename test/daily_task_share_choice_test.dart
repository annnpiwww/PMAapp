import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';
import 'package:bssparking_timemark/features/daily_tasks/screens/custom_task_execution_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  testWidgets('regular task post-save dialog offers WhatsApp and Telegram', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final task = DailyTaskModel(
      id: 'task_regular_share',
      tanggal: '2026-11-12',
      teknisiId: 'tek_01',
      teknisiNama: 'Farhan Lakoro',
      posName: 'Mie Gacoan Nani Wartabone',
      posTag: 'MGNW',
      judul: 'Ganti kabel LAN booth',
      kategori: 'perbaikan',
    );

    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: CustomTaskExecutionScreen(task: task)));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester.state(find.byType(CustomTaskExecutionScreen));
    state.showPostSaveDialogForTesting();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text('Bagikan ke Grup'), findsNothing);
  });
}
