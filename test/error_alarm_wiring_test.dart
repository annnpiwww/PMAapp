import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bssparking_timemark/core/widgets/tiket/error_alarm_overlay.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';

void main() {
  testWidgets('ErrorAlarmOverlay is wired via MaterialApp.builder above home',
      (WidgetTester tester) async {
    int lihatCalls = 0;
    final DailyTaskModel ticket = DailyTaskModel(
      id: 'err-01',
      tanggal: '2026-11-10',
      teknisiId: 'tek-01',
      teknisiNama: 'Teknisi 1',
      posName: 'Pos Masuk Utama',
      posTag: 'TAG-01',
      judul: 'Barrier Gate Error',
      kategori: 'error',
    );

    final ValueNotifier<List<DailyTaskModel>> openErrors =
        ValueNotifier<List<DailyTaskModel>>(<DailyTaskModel>[ticket]);
    final ValueNotifier<bool> ringing = ValueNotifier<bool>(true);

    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) => ErrorAlarmOverlay(
          openErrors: openErrors,
          ringing: ringing,
          onLihat: () => lihatCalls++,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Scaffold(
          body: Center(
            child: Text('Home Screen Content'),
          ),
        ),
      ),
    );

    await tester.pump();

    // Verify home screen content is present
    expect(find.text('Home Screen Content'), findsOneWidget);

    // Verify overlay banner is present above home
    expect(find.text('LOKASI ERROR'), findsOneWidget);
    expect(find.text('Pos Masuk Utama · Barrier Gate Error'), findsOneWidget);

    // Tap 'Lihat' calls callback
    await tester.tap(find.text('Lihat'));
    await tester.pump();
    expect(lihatCalls, 1);
  });
}
