import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/core/widgets/verification_step_card.dart';

void main() {
  testWidgets('VerificationStepCard displays fast bypass when step >= 2 and triggers callback', (tester) async {
    bool bypassClicked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VerificationStepCard(
            currentStep: 3,
            statusText: 'Sedang diverifikasi',
            templateName: 'Absensi Teknisi',
            onFastBypass: () {
              bypassClicked = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Sedang diverifikasi'), findsOneWidget);
    expect(find.text('Absensi Teknisi'), findsOneWidget);
    expect(find.text('3/4'), findsOneWidget);

    final bypassBtn = find.text('Sinyal Lemah? Lewati & Simpan Cepat');
    expect(bypassBtn, findsOneWidget);

    await tester.tap(bypassBtn);
    await tester.pump(const Duration(milliseconds: 100));

    expect(bypassClicked, isTrue);
  });

  testWidgets('VerificationStepCard hides fast bypass when step is 1 or done', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VerificationStepCard(
            currentStep: 1,
            statusText: 'Memproses foto',
          ),
        ),
      ),
    );

    expect(find.text('Sinyal Lemah? Lewati & Simpan Cepat'), findsNothing);
  });
}
