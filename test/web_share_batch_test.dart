import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/core/utils/share_helper.dart';
import 'package:bssparking_timemark/features/maintenance/widgets/web_share_batch_sheet.dart';

List<WebShareFile> _makeFiles(int count) {
  return List<WebShareFile>.generate(
    count,
    (i) => WebShareFile(
      bytes: Uint8List.fromList([i + 1]),
      name: '${(i + 1).toString().padLeft(2, '0')}_pt_${i + 1}.jpg',
    ),
  );
}

void main() {
  group('webShareChunks & labels', () {
    test('kWebShareChunk is 10', () {
      expect(kWebShareChunk, 10);
    });

    test('0 photos produces no chunks', () {
      expect(webShareChunks(0), isEmpty);
      expect(webShareChunks(-3), isEmpty);
    });

    test('1 photo produces 1..1 and label Kirim foto 1', () {
      final chunks = webShareChunks(1);
      expect(chunks, [(start: 1, end: 1)]);
      expect(webShareChunkLabel(chunks.first), 'Kirim foto 1');
    });

    test('10 photos produces 1..10 and label Kirim foto 1-10', () {
      final chunks = webShareChunks(10);
      expect(chunks, [(start: 1, end: 10)]);
      expect(webShareChunkLabel(chunks.first), 'Kirim foto 1-10');
    });

    test('11 photos produces 1..10 and 11..11', () {
      final chunks = webShareChunks(11);
      expect(chunks, [(start: 1, end: 10), (start: 11, end: 11)]);
      expect(
        chunks.map(webShareChunkLabel).toList(),
        ['Kirim foto 1-10', 'Kirim foto 11'],
      );
    });

    test('23 photos produces 1-10, 11-20, 21-23', () {
      final chunks = webShareChunks(23);
      expect(chunks, [
        (start: 1, end: 10),
        (start: 11, end: 20),
        (start: 21, end: 23),
      ]);
      expect(
        chunks.map(webShareChunkLabel).toList(),
        ['Kirim foto 1-10', 'Kirim foto 11-20', 'Kirim foto 21-23'],
      );
    });

    test('50 photos produces 5 chunks 1-10 through 41-50', () {
      final chunks = webShareChunks(50);
      expect(chunks.length, 5);
      expect(
        chunks.map(webShareChunkLabel).toList(),
        [
          'Kirim foto 1-10',
          'Kirim foto 11-20',
          'Kirim foto 21-30',
          'Kirim foto 31-40',
          'Kirim foto 41-50',
        ],
      );
    });

    test('webSaveChunkLabel progresses across chunks', () {
      final chunks = webShareChunks(50);
      expect(
        webSaveChunkLabel(chunks[0], savedCount: 0, totalChunks: chunks.length),
        'Simpan semua ke Galeri',
      );
      expect(
        webSaveChunkLabel(chunks[1], savedCount: 1, totalChunks: chunks.length),
        'Simpan foto 11-20',
      );
      expect(
        webSaveChunkLabel(chunks[0], savedCount: 5, totalChunks: chunks.length),
        'Semua foto tersimpan',
      );
    });
  });

  group('WebShareBatchSheet widget', () {
    testWidgets('50 photos renders ordered steps and dispatches exact slices',
        (tester) async {
      String? sentText;
      bool? sentTelegram;
      final sentBatches = <({List<String> names, String? text})>[];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: WebShareBatchSheet(
              text: 'Laporan lengkap maintenance 50 foto tanpa terpotong',
              files: _makeFiles(50),
              telegram: false,
              onShareText: ({required text, required telegram}) async {
                sentText = text;
                sentTelegram = telegram;
                return WebShareOutcome.shared;
              },
              onShareFiles: ({required files, text, title}) async {
                sentBatches.add((
                  names: files.map((f) => f.name).toList(),
                  text: text,
                ));
                return WebShareOutcome.shared;
              },
            ),
          ),
        ),
      );

      expect(find.text('Kirim laporan ke grup'), findsOneWidget);
      expect(
        find.text(
          'iPhone cuma bisa kirim 10 foto sekali kirim. Tap tombol berurutan.',
        ),
        findsOneWidget,
      );
      expect(find.text('Kirim teks laporan'), findsOneWidget);
      expect(find.text('Kirim foto 1-10'), findsOneWidget);
      expect(find.text('Kirim foto 11-20'), findsOneWidget);
      expect(find.text('Kirim foto 41-50'), findsOneWidget);
      expect(find.text('Simpan semua ke Galeri'), findsOneWidget);

      await tester.tap(find.byKey(const Key('web-share-step-text')));
      await tester.pumpAndSettle();
      expect(sentText, 'Laporan lengkap maintenance 50 foto tanpa terpotong');
      expect(sentTelegram, isFalse);
      expect(find.text('Kirim teks laporan (Terkirim)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('web-share-step-chunk-1')));
      await tester.pumpAndSettle();
      expect(sentBatches.length, 1);
      expect(sentBatches.first.text, isNull);
      expect(sentBatches.first.names.length, 10);
      expect(sentBatches.first.names.first, '11_pt_11.jpg');
      expect(sentBatches.first.names.last, '20_pt_20.jpg');
      expect(find.text('Kirim foto 11-20 (Terkirim)'), findsOneWidget);

      final saveBtn = find.byKey(const Key('web-share-save-gallery'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();
      expect(sentBatches.length, 2);
      expect(sentBatches.last.names.first, '01_pt_1.jpg');
      expect(sentBatches.last.names.last, '10_pt_10.jpg');
      expect(find.text('Simpan foto 11-20'), findsOneWidget);
    });

    testWidgets('cancelled chunk remains retryable and does not mark Terkirim',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: WebShareBatchSheet(
              text: 'Laporan',
              files: _makeFiles(23),
              telegram: true,
              onShareFiles: ({required files, text, title}) async =>
                  WebShareOutcome.cancelled,
            ),
          ),
        ),
      );

      expect(find.text('Kirim foto 1-10'), findsOneWidget);
      expect(find.text('Kirim foto 11-20'), findsOneWidget);
      expect(find.text('Kirim foto 21-23'), findsOneWidget);

      await tester.tap(find.byKey(const Key('web-share-step-chunk-0')));
      await tester.pumpAndSettle();
      expect(find.text('Kirim foto 1-10'), findsOneWidget);
      expect(find.textContaining('Terkirim'), findsNothing);
    });

    testWidgets('0 photos renders only step 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: WebShareBatchSheet(
              text: 'Teks saja',
              files: [],
              telegram: false,
            ),
          ),
        ),
      );

      expect(find.text('Kirim teks laporan'), findsOneWidget);
      expect(find.byKey(const Key('web-share-step-chunk-0')), findsNothing);
      expect(find.byKey(const Key('web-share-save-gallery')), findsNothing);
    });
  });
}
