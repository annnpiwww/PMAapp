import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/core/constants/app_theme.dart';
import 'package:bssparking_timemark/core/constants/tiket_colors.dart';
import 'package:bssparking_timemark/core/widgets/tiket/tiket.dart';

Widget _buildThemedHarness({
  required Widget child,
  Brightness brightness = Brightness.light,
  double width = 390.0,
  double height = 844.0,
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets padding = EdgeInsets.zero,
}) {
  final theme = brightness == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme;
  return MaterialApp(
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, height),
        textScaler: textScaler,
        padding: padding,
      ),
      child: Scaffold(
        body: child,
      ),
    ),
  );
}

void main() {
  group('Tiket Widgets Rendering & Theming (Light & Dark)', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final modeName = brightness == Brightness.light ? 'Light' : 'Dark';

      testWidgets('TiketBand renders in $modeName mode', (tester) async {
        await tester.pumpWidget(
          _buildThemedHarness(
            brightness: brightness,
            child: TiketBand(
              leading: TiketIconButton(
                icon: Icons.arrow_back,
                semanticLabel: 'Kembali',
                onPressed: () {},
              ),
              actions: [
                TiketIconButton(
                  icon: Icons.refresh,
                  semanticLabel: 'Muat ulang',
                  onPressed: () {},
                ),
              ],
              caption: 'KC Manado · 09 Nov 2026',
              hero: const Text('1/4 tugas selesai'),
              footer: const Text('Footer info'),
            ),
          ),
        );

        expect(find.text('KC Manado · 09 Nov 2026'), findsOneWidget);
        expect(find.text('1/4 tugas selesai'), findsOneWidget);
        expect(find.text('Footer info'), findsOneWidget);
        expect(find.byType(TiketIconButton), findsNWidgets(2));
      });

      testWidgets('TiketSliverBand renders in $modeName mode', (tester) async {
        await tester.pumpWidget(
          _buildThemedHarness(
            brightness: brightness,
            child: const CustomScrollView(
              slivers: [
                TiketSliverBand(
                  compactTitle: 'Daily Task',
                  caption: 'KC Manado',
                  hero: Text('1/4 tugas selesai'),
                ),
              ],
            ),
          ),
        );

        expect(find.text('Daily Task'), findsOneWidget);
        expect(find.text('1/4 tugas selesai'), findsOneWidget);
      });

      testWidgets('TiketPill renders all kinds in $modeName mode', (tester) async {
        await tester.pumpWidget(
          _buildThemedHarness(
            brightness: brightness,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TiketPill(label: 'Primary', kind: TiketPillKind.primary, onPressed: () {}),
                  TiketPill(label: 'Secondary', kind: TiketPillKind.secondary, onPressed: () {}),
                  const TiketPill(label: 'Disabled', kind: TiketPillKind.disabled),
                  TiketPill(label: 'Band', kind: TiketPillKind.band, onPressed: () {}),
                  TiketPill(label: 'BandSelected', kind: TiketPillKind.bandSelected, onPressed: () {}),
                  TiketPill(label: 'With Badge', badge: '3', onPressed: () {}),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Primary'), findsOneWidget);
        expect(find.text('Secondary'), findsOneWidget);
        expect(find.text('Disabled'), findsOneWidget);
        expect(find.text('Band'), findsOneWidget);
        expect(find.text('BandSelected'), findsOneWidget);
        expect(find.text('With Badge'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
      });

      testWidgets('StatusMarker renders all states in $modeName mode', (tester) async {
        await tester.pumpWidget(
          _buildThemedHarness(
            brightness: brightness,
            child: const Row(
              children: [
                StatusMarker(status: TiketStatus.ok),
                StatusMarker(status: TiketStatus.attention),
                StatusMarker(status: TiketStatus.notStarted),
                StatusMarker(status: TiketStatus.danger),
                StatusMarker(status: TiketStatus.ok, onBand: true),
                StatusMarker(status: TiketStatus.notStarted, onBand: true),
              ],
            ),
          ),
        );

        expect(find.byType(StatusMarker), findsNWidgets(6));
        expect(find.bySemanticsLabel('Selesai'), findsNWidgets(2));
        expect(find.bySemanticsLabel('Perlu perhatian'), findsOneWidget);
        expect(find.bySemanticsLabel('Belum'), findsNWidgets(2));
        expect(find.bySemanticsLabel('Harus diganti'), findsOneWidget);
      });

      testWidgets('StatusChip renders all kinds in $modeName mode', (tester) async {
        await tester.pumpWidget(
          _buildThemedHarness(
            brightness: brightness,
            child: const Row(
              children: [
                StatusChip(label: 'Sesuai', kind: TiketChipKind.ok),
                StatusChip(label: 'Perlu cek', kind: TiketChipKind.attention),
                StatusChip(label: 'Belum diperbaiki', kind: TiketChipKind.neutral),
                StatusChip(label: 'Urgent', kind: TiketChipKind.danger),
              ],
            ),
          ),
        );

        expect(find.text('Sesuai'), findsOneWidget);
        expect(find.text('Perlu cek'), findsOneWidget);
        expect(find.text('Belum diperbaiki'), findsOneWidget);
        expect(find.text('Urgent'), findsOneWidget);
      });

      testWidgets('TiketRow renders in $modeName mode', (tester) async {
        await tester.pumpWidget(
          _buildThemedHarness(
            brightness: brightness,
            child: TiketRow(
              leading: const StatusMarker(status: TiketStatus.ok),
              title: 'Pemeriksaan Pos Masuk',
              meta: const ['Gate 1', '09:15 WITA'],
              status: ('Selesai', TiketColors.light.ok),
              trailing: TiketPill(label: 'Detail', onPressed: () {}),
              below: const Text('Catatan teknisi aman'),
              onTap: () {},
            ),
          ),
        );

        expect(find.text('Pemeriksaan Pos Masuk'), findsOneWidget);
        expect(find.text('Gate 1 · 09:15 WITA'), findsOneWidget);
        expect(find.text('Selesai'), findsWidgets);
        expect(find.text('Detail'), findsOneWidget);
        expect(find.text('Catatan teknisi aman'), findsOneWidget);
      });

      testWidgets('TiketSegmented renders in $modeName mode', (tester) async {
        String selected = 'Semua';
        await tester.pumpWidget(
          _buildThemedHarness(
            brightness: brightness,
            child: StatefulBuilder(
              builder: (ctx, setState) {
                return TiketSegmented<String>(
                  options: const [
                    ('Semua', 'Semua'),
                    ('Pending', 'Pending'),
                    ('Selesai', 'Selesai'),
                  ],
                  selected: selected,
                  onChanged: (val) {
                    setState(() => selected = val);
                  },
                );
              },
            ),
          ),
        );

        expect(find.text('Semua'), findsOneWidget);
        expect(find.text('Pending'), findsOneWidget);
        expect(find.text('Selesai'), findsOneWidget);

        await tester.tap(find.text('Pending'));
        await tester.pump();
        expect(selected, 'Pending');
      });

      testWidgets('TiketDropdownField renders in $modeName mode', (tester) async {
        bool tapped = false;
        await tester.pumpWidget(
          _buildThemedHarness(
            brightness: brightness,
            child: TiketDropdownField(
              label: 'Pilih Teknisi',
              value: 'Aan (Teknisi 1)',
              onTap: () => tapped = true,
            ),
          ),
        );

        expect(find.text('Pilih Teknisi'), findsOneWidget);
        expect(find.text('Aan (Teknisi 1)'), findsOneWidget);

        await tester.tap(find.byType(TiketDropdownField));
        expect(tapped, isTrue);
      });

      testWidgets('TiketBottomBar renders in $modeName mode', (tester) async {
        await tester.pumpWidget(
          _buildThemedHarness(
            brightness: brightness,
            child: TiketBottomBar(
              helper: '6 poin belum difoto',
              primary: TiketPill(label: 'Lanjutkan', onPressed: () {}),
              secondary: TiketPill(label: 'Simpan Draft', kind: TiketPillKind.secondary, onPressed: () {}),
            ),
          ),
        );

        expect(find.text('6 poin belum difoto'), findsOneWidget);
        expect(find.text('Lanjutkan'), findsOneWidget);
        expect(find.text('Simpan Draft'), findsOneWidget);
      });
    }
  });

  group('Accessibility & Tap Target Sizes (>= 48x48)', () {
    testWidgets('TiketIconButton tap target is at least 48x48', (tester) async {
      await tester.pumpWidget(
        _buildThemedHarness(
          child: TiketIconButton(
            icon: Icons.refresh,
            semanticLabel: 'Refresh',
            onPressed: () {},
          ),
        ),
      );

      final size = tester.getSize(find.byType(TiketIconButton));
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('TiketPill tap target is at least 48x48', (tester) async {
      await tester.pumpWidget(
        _buildThemedHarness(
          child: Center(
            child: TiketPill(
              label: 'Action',
              onPressed: () {},
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(TiketPill));
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('TiketDropdownField tap target height is at least 48', (tester) async {
      await tester.pumpWidget(
        _buildThemedHarness(
          child: TiketDropdownField(
            label: 'Filter',
            value: 'Semua',
            onTap: () {},
          ),
        ),
      );

      final size = tester.getSize(find.byType(TiketDropdownField));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('TiketRow tap target height is at least 48', (tester) async {
      await tester.pumpWidget(
        _buildThemedHarness(
          child: TiketRow(
            title: 'Tugas Harian',
            onTap: () {},
          ),
        ),
      );

      final size = tester.getSize(find.byType(TiketRow));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('TiketSegmented hit region height is at least 48', (tester) async {
      await tester.pumpWidget(
        _buildThemedHarness(
          child: TiketSegmented<int>(
            options: const [(1, 'A'), (2, 'B')],
            selected: 1,
            onChanged: (_) {},
          ),
        ),
      );

      final size = tester.getSize(find.byType(TiketSegmented<int>));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });
  });

  group('TiketSegmented Constraints', () {
    test('TiketSegmented asserts max 3 options', () {
      expect(
        () => TiketSegmented<int>(
          options: const [
            (1, 'A'),
            (2, 'B'),
            (3, 'C'),
            (4, 'D'),
          ],
          selected: 1,
          onChanged: (_) {},
        ),
        throwsAssertionError,
      );
    });
  });

  group('showTiketPickerDialog Interaction', () {
    testWidgets('returns tapped option value', (tester) async {
      int? result;
      await tester.pumpWidget(
        _buildThemedHarness(
          child: Builder(
            builder: (ctx) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showTiketPickerDialog<int>(
                    context: ctx,
                    title: 'Pilih Angka',
                    options: const [
                      TiketOption(value: 10, label: 'Sepuluh'),
                      TiketOption(value: 20, label: 'Dua Puluh'),
                    ],
                    selected: 10,
                  );
                },
                child: const Text('Buka'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();

      expect(find.text('Pilih Angka'), findsOneWidget);
      expect(find.text('Sepuluh'), findsOneWidget);
      expect(find.text('Dua Puluh'), findsOneWidget);

      await tester.tap(find.text('Dua Puluh'));
      await tester.pumpAndSettle();

      expect(result, 20);
      expect(find.text('Pilih Angka'), findsNothing);
    });

    testWidgets('returns null on Tutup button tap', (tester) async {
      int? result = 999;
      await tester.pumpWidget(
        _buildThemedHarness(
          child: Builder(
            builder: (ctx) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showTiketPickerDialog<int>(
                    context: ctx,
                    title: 'Pilih Angka',
                    options: const [
                      TiketOption(value: 1, label: 'Satu'),
                    ],
                  );
                },
                child: const Text('Buka'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();

      expect(find.text('Tutup'), findsOneWidget);
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();

      expect(result, isNull);
      expect(find.text('Pilih Angka'), findsNothing);
    });
  });

  group('Responsive & Text Scaling Constraints', () {
    testWidgets('TiketRow title wraps without overflow at width 360 and textScaler 1.3', (tester) async {
      await tester.pumpWidget(
        _buildThemedHarness(
          width: 360.0,
          textScaler: const TextScaler.linear(1.3),
          child: TiketRow(
            leading: const StatusMarker(status: TiketStatus.ok),
            title: 'Pemeriksaan dan Perbaikan Gate Barrier Parkir Masuk Gedung Utama Terminal 1 Bandara Sam Ratulangi Manado',
            meta: const ['Gate 1', '09:15 WITA', 'Selesai tepat waktu'],
            status: ('Selesai', TiketColors.light.ok),
            trailing: TiketPill(label: 'Detail', onPressed: () {}),
            onTap: () {},
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Pemeriksaan dan Perbaikan'), findsOneWidget);
    });

    testWidgets('TiketBottomBar respects MediaQuery bottom padding 34', (tester) async {
      await tester.pumpWidget(
        _buildThemedHarness(
          padding: const EdgeInsets.only(bottom: 34.0),
          child: TiketBottomBar(
            primary: TiketPill(label: 'Selesai', onPressed: () {}),
          ),
        ),
      );

      final sizeWithInset = tester.getSize(find.byType(TiketBottomBar));

      await tester.pumpWidget(
        _buildThemedHarness(
          padding: EdgeInsets.zero,
          child: TiketBottomBar(
            primary: TiketPill(label: 'Selesai', onPressed: () {}),
          ),
        ),
      );

      final sizeWithoutInset = tester.getSize(find.byType(TiketBottomBar));
      expect(sizeWithInset.height - sizeWithoutInset.height, closeTo(34.0, 0.1));
    });
  });
}
