import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/features/daily_tasks/widgets/completed_daily_task_modal.dart';

void main() {
  testWidgets('CompletedDailyTaskModal renders read-only task details and proof images', (tester) async {
    final taskWithPhotos = DailyTaskModel(
      id: 'task_test_1',
      tanggal: '2026-10-16',
      teknisiId: 'user_1',
      teknisiNama: 'Ryan Lumasuge',
      posName: 'Pos Masuk 1',
      posTag: 'PM1',
      judul: 'Pemeriksaan Barrier Gate & Printer Tiket',
      deskripsi: 'Cek kondisi fisik palang dan sisa kertas tiket',
      kategori: 'maintenance',
      templateId: 'tmpl_pm1',
      status: TaskStatus.completed,
      jamSelesai: '09:45 WITA',
      fotoBuktiUrls: [
        'https://sxsjixnnlzhjinzcyhjb.supabase.co/storage/v1/object/public/task-proofs/test1.jpg',
        'https://sxsjixnnlzhjinzcyhjb.supabase.co/storage/v1/object/public/task-proofs/test2.jpg',
      ],
      catatanTeknisi: 'Kertas tiket sudah diisi ulang 1 roll baru',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompletedDailyTaskModal(task: taskWithPhotos),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verifikasi Judul & Status
    expect(find.text('Pemeriksaan Barrier Gate & Printer Tiket'), findsOneWidget);
    expect(find.textContaining('Selesai'), findsAtLeastNWidgets(1));
    expect(find.text('Read-Only'), findsOneWidget);

    // Verifikasi Metadata
    expect(find.text('Ryan Lumasuge'), findsOneWidget);
    expect(find.text('PM1 • Pos Masuk 1'), findsOneWidget);
    expect(find.text('SOP Maintenance'), findsOneWidget);

    // Verifikasi Catatan Teknisi
    expect(find.text('Kertas tiket sudah diisi ulang 1 roll baru'), findsOneWidget);

    // Verifikasi Foto Bukti
    expect(find.text('Foto Bukti Pengerjaan (2)'), findsOneWidget);
    expect(find.text('Unduh Semua'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('Unduh'), findsNWidgets(2));
    expect(find.text('Zoom'), findsNWidgets(2));

    // Verifikasi Strict Read-Only: Tidak boleh ada form input / text field edit
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Simpan Perubahan'), findsNothing);
    expect(find.text('Kirim Laporan'), findsNothing);
  });

  testWidgets('CompletedDailyTaskModal renders empty photo proof state properly', (tester) async {
    final taskNoPhotos = DailyTaskModel(
      id: 'task_test_2',
      tanggal: '2026-10-16',
      teknisiId: 'user_2',
      teknisiNama: 'Rivo S',
      posName: 'Pos Keluar Mobil',
      posTag: 'PKM',
      judul: 'Tugas Khusus Pembersihan Shelter',
      deskripsi: 'Sapu dan pel shelter',
      kategori: 'khusus',
      status: TaskStatus.completed,
      jamSelesai: '11:20 WITA',
      fotoBuktiUrls: [],
      catatanTeknisi: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompletedDailyTaskModal(task: taskNoPhotos),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verifikasi Header & Metadata
    expect(find.text('Tugas Khusus Pembersihan Shelter'), findsOneWidget);
    expect(find.text('Rivo S'), findsOneWidget);
    expect(find.text('Tugas Khusus'), findsOneWidget);

    // Verifikasi Empty State Foto Bukti
    expect(find.text('Foto Bukti Pengerjaan (0)'), findsOneWidget);
    expect(find.text('Tidak ada lampiran foto bukti pada tugas ini.'), findsOneWidget);
    expect(find.text('Unduh Semua'), findsNothing);
  });
}
