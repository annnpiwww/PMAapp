import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/models/error_report.dart';

void main() {
  const adminSample = '''
Selamat pagi, izin melaporkan, telah terjadi kendala dengan kronologi sebagai berikut:

Tanggal : 07-11-2026
Waktu : 05.35

Lokasi : PBM

Kendala : Pos 1 Palang Tidak bisa terangkat 

Penyebab : Tidak diketahui 

Solusi sementara : Pos 1 ditutup Smntra

Durasi Error : 

Berikut kami lampirkan dokumentasi kerusakan.

Terima kasih.
''';

  group('ErrorReport unit tests', () {
    // (a) Exact admin sample parsing
    test('(a) parses exact admin sample from contract', () {
      final report = ErrorReport.parse(adminSample);
      expect(report.reportedAt, equals(DateTime(2026, 11, 7, 5, 35)));
      expect(report.lokasi, equals('PBM'));
      expect(report.kendala, equals('Pos 1 Palang Tidak bisa terangkat'));
      expect(report.penyebab, equals('Tidak diketahui'));
      expect(report.solusiSementara, equals('Pos 1 ditutup Smntra'));
    });

    // (b) Waktu with ':' and Tanggal with '/', 2-digit year
    test('(b) handles waktu with colon, tanggal with slash and 2-digit year', () {
      const msg = '''
Tanggal : 07/11/26
Waktu : 05:35
Lokasi : PBM
''';
      final report = ErrorReport.parse(msg);
      expect(report.reportedAt, equals(DateTime(2026, 11, 7, 5, 35)));
      expect(report.lokasi, equals('PBM'));
    });

    // (c) Missing waktu -> reportedAt null, withFallbackTime fills it
    test('(c) missing waktu leaves reportedAt null, withFallbackTime fills it', () {
      const msg = '''
Tanggal : 07-11-2026
Lokasi : PBM
''';
      final report = ErrorReport.parse(msg);
      expect(report.reportedAt, isNull);

      final fallback = DateTime(2026, 11, 7, 8, 0);
      final updated = report.withFallbackTime(fallback);
      expect(updated.reportedAt, equals(fallback));
      expect(updated.lokasi, equals('PBM'));

      // If already present, withFallbackTime does not overwrite
      final alreadySet = ErrorReport(reportedAt: DateTime(2026, 1, 1));
      expect(alreadySet.withFallbackTime(fallback).reportedAt, equals(DateTime(2026, 1, 1)));
    });

    // (d) Invalid date 31-02-2026 -> null
    test('(d) invalid date 31-02-2026 evaluates to null', () {
      const msg = '''
Tanggal : 31-02-2026
Waktu : 10.00
''';
      final report = ErrorReport.parse(msg);
      expect(report.reportedAt, isNull);
    });

    // (e) Bullet form and mixed case labels
    test('(e) parses bullet forms and mixed case labels', () {
      const msg = '''
- Tanggal : 07-11-2026
• Waktu : 05.35
* LOKASI : PBM
- KENDALA : Palang macet
  Solusi  SEMENTARA  : Tutup gate
- PENYEBAB : Motor terbakar
''';
      final report = ErrorReport.parse(msg);
      expect(report.reportedAt, equals(DateTime(2026, 11, 7, 5, 35)));
      expect(report.lokasi, equals('PBM'));
      expect(report.kendala, equals('Palang macet'));
      expect(report.solusiSementara, equals('Tutup gate'));
      expect(report.penyebab, equals('Motor terbakar'));
    });

    // (f) Round-trip parse(toDeskripsi(sample))
    test('(f) round-trips parse(toDeskripsi(sample))', () {
      final originalReport = ErrorReport.parse(adminSample);
      final deskripsi = originalReport.toDeskripsi(adminSample);
      final reloaded = ErrorReport.parse(deskripsi);

      expect(reloaded.reportedAt, equals(originalReport.reportedAt));
      expect(reloaded.lokasi, equals(originalReport.lokasi));
      expect(reloaded.kendala, equals(originalReport.kendala));
      expect(reloaded.penyebab, equals(originalReport.penyebab));
      expect(reloaded.solusiSementara, equals(originalReport.solusiSementara));
    });

    // (g) 2000-char cap keeps the normalized block intact
    test('(g) 2000-char cap preserves normalized block and truncates only original text', () {
      final report = ErrorReport(
        reportedAt: DateTime(2026, 11, 7, 5, 35),
        lokasi: 'PBM',
        kendala: 'Palang macet',
        penyebab: 'Motor terbakar',
        solusiSementara: 'Tutup gate',
      );

      final hugeOriginal = 'X' * 3000;
      final deskripsi = report.toDeskripsi(hugeOriginal);

      expect(deskripsi.length, lessThanOrEqualTo(2000));
      expect(deskripsi, startsWith('Tanggal : 07-11-2026\nWaktu : 05.35\nLokasi : PBM\nKendala : Palang macet\nPenyebab : Motor terbakar\nSolusi sementara : Tutup gate\n\n'));

      final parsedBack = ErrorReport.parse(deskripsi);
      expect(parsedBack.reportedAt, equals(DateTime(2026, 11, 7, 5, 35)));
      expect(parsedBack.lokasi, equals('PBM'));
      expect(parsedBack.kendala, equals('Palang macet'));
    });

    // (h) judul from kendala, and fallback skipping greetings & label lines
    test('(h) judul prefers kendala, then falls back skipping greetings and label lines', () {
      const reportWithKendala = ErrorReport(kendala: 'Palang Gate Rusak');
      expect(reportWithKendala.judul('random text'), equals('Palang Gate Rusak'));

      const fallbackText = '''
Selamat pagi, izin melaporkan kendala berikut:
Tanggal : 07-11-2026
Waktu : 05.35
Palang gate 2 patah tertabrak mobil
Lokasi : PBM
''';
      const emptyReport = ErrorReport();
      expect(emptyReport.judul(fallbackText), equals('Palang gate 2 patah tertabrak mobil'));

      // If nothing valid
      expect(emptyReport.judul('Selamat pagi\nTanggal : 01-01-2026'), equals(''));
    });

    // (i) formatDurasi table
    test('(i) formatDurasi table cases', () {
      expect(formatDurasi(const Duration(minutes: -1)), equals(''));
      expect(formatDurasi(const Duration(seconds: 30)), equals('1 menit'));
      expect(formatDurasi(const Duration(minutes: 8)), equals('8 menit'));
      expect(formatDurasi(const Duration(minutes: 60)), equals('1 jam'));
      expect(formatDurasi(const Duration(minutes: 80)), equals('1 jam 20 menit'));
      expect(formatDurasi(const Duration(days: 2, hours: 3)), equals('2 hari 3 jam'));
    });

    // (j) buildErrorReply golden string
    test('(j) buildErrorReply golden string matches contract', () {
      final result = buildErrorReply(
        kendala: 'Gate in 3 tidak keluar karcis',
        penyebab: 'printer error',
        solusiPerbaikan: 'perbaiki posisi thermal',
        reportedAt: DateTime(2026, 6, 3, 7, 0),
        selesai: DateTime(2026, 6, 3, 7, 8),
      );

      const expected = 'Selamat pagi\n'
          'Izin melaporkan hasil support maintenance Rabu, 03 Juni 2026\n\n'
          '- Kendala : Gate in 3 tidak keluar karcis\n\n'
          '- Penyebab : printer error\n\n'
          '- Solusi Perbaikan : perbaiki posisi thermal\n\n'
          '- Durasi Perbaikan : 8 menit\n\n'
          'Terima Kasih 🙏';

      expect(result, equals(expected));
    });

    // (k) buildErrorReply with catatan
    test('(k) buildErrorReply adds catatan block when non-empty', () {
      final result = buildErrorReply(
        kendala: 'Gate in 3 tidak keluar karcis',
        penyebab: 'printer error',
        solusiPerbaikan: 'perbaiki posisi thermal',
        reportedAt: DateTime(2026, 6, 3, 7, 0),
        selesai: DateTime(2026, 6, 3, 7, 8),
        catatan: 'ganti kertas juga',
      );

      const expected = 'Selamat pagi\n'
          'Izin melaporkan hasil support maintenance Rabu, 03 Juni 2026\n\n'
          '- Kendala : Gate in 3 tidak keluar karcis\n\n'
          '- Penyebab : printer error\n\n'
          '- Solusi Perbaikan : perbaiki posisi thermal\n\n'
          '- Durasi Perbaikan : 8 menit\n\n'
          '- Catatan : ganti kertas juga\n\n'
          'Terima Kasih 🙏';

      expect(result, equals(expected));
    });

    // (l) buildErrorReply with reportedAt null omits Durasi line
    test('(l) buildErrorReply omits durasi line when reportedAt is null', () {
      final result = buildErrorReply(
        kendala: 'Gate in 3 tidak keluar karcis',
        penyebab: 'printer error',
        solusiPerbaikan: 'perbaiki posisi thermal',
        reportedAt: null,
        selesai: DateTime(2026, 6, 3, 7, 8),
      );

      expect(result, isNot(contains('- Durasi Perbaikan :')));
      expect(result, endsWith('- Solusi Perbaikan : perbaiki posisi thermal\n\nTerima Kasih 🙏'));
    });

    // (m) greeting boundaries: 10:59 pagi, 11:00 siang, 15:00 sore, 18:00 malam
    test('(m) greeting boundaries according to selesai hour', () {
      String getGreeting(int hour, int minute) {
        final reply = buildErrorReply(
          kendala: 'K',
          penyebab: 'P',
          solusiPerbaikan: 'S',
          reportedAt: null,
          selesai: DateTime(2026, 6, 3, hour, minute),
        );
        return reply.split('\n').first;
      }

      expect(getGreeting(10, 59), equals('Selamat pagi'));
      expect(getGreeting(11, 0), equals('Selamat siang'));
      expect(getGreeting(14, 59), equals('Selamat siang'));
      expect(getGreeting(15, 0), equals('Selamat sore'));
      expect(getGreeting(17, 59), equals('Selamat sore'));
      expect(getGreeting(18, 0), equals('Selamat malam'));
      expect(getGreeting(23, 0), equals('Selamat malam'));
    });

    // (n) errorCatatanTeknisi with and without catatan
    test('(n) errorCatatanTeknisi formats correctly with and without catatan', () {
      expect(
        errorCatatanTeknisi(penyebab: 'printer error', solusiPerbaikan: 'perbaiki thermal'),
        equals('Penyebab : printer error\nSolusi Perbaikan : perbaiki thermal'),
      );

      expect(
        errorCatatanTeknisi(penyebab: 'printer error', solusiPerbaikan: 'perbaiki thermal', catatan: 'ganti kertas'),
        equals('Penyebab : printer error\nSolusi Perbaikan : perbaiki thermal\nCatatan : ganti kertas'),
      );

      expect(
        errorCatatanTeknisi(penyebab: '', solusiPerbaikan: ''),
        equals('Penyebab : -\nSolusi Perbaikan : -'),
      );
    });

    test('buildErrorReply uses the admin report date, not the completion date', () {
      final result = buildErrorReply(
        kendala: 'Pos 1 Palang Tidak bisa terangkat',
        penyebab: 'limit switch kendor',
        solusiPerbaikan: 'kencangkan limit switch',
        reportedAt: DateTime(2026, 11, 7, 22, 0),
        selesai: DateTime(2026, 11, 8, 8, 15),
      );
      expect(result, startsWith('Selamat pagi\nIzin melaporkan hasil support maintenance Sabtu, 07 November 2026\n'));
      expect(result, contains('- Durasi Perbaikan : 10 jam 15 menit'));
    });

    test('pelapor round trip and old deskripsi without Pelapor defaults to empty string', () {
      const oldDeskripsi = '''
Tanggal : 07-11-2026
Waktu : 05.35
Lokasi : PBM
Kendala : Tiket macet
''';
      final oldParsed = ErrorReport.parse(oldDeskripsi);
      expect(oldParsed.pelapor, equals(''));

      final report = ErrorReport(
        reportedAt: DateTime(2026, 11, 7, 5, 35),
        lokasi: 'PBM',
        kendala: 'Tiket macet',
        pelapor: 'Farhan Lakoro',
      );
      final deskripsiWithPelapor = report.toDeskripsi('Original paste text');
      expect(deskripsiWithPelapor, contains('Lokasi : PBM\nPelapor : Farhan Lakoro\nKendala : Tiket macet'));

      final reloaded = ErrorReport.parse(deskripsiWithPelapor);
      expect(reloaded.pelapor, equals('Farhan Lakoro'));
      expect(reloaded.lokasi, equals('PBM'));
      expect(reloaded.kendala, equals('Tiket macet'));

      // Passing pelapor explicitly in toDeskripsi
      final customPelaporDeskripsi = report.toDeskripsi('Sample', pelapor: 'Aan Supervisor');
      expect(customPelaporDeskripsi, contains('Pelapor : Aan Supervisor'));
      final reloadedCustom = ErrorReport.parse(customPelaporDeskripsi);
      expect(reloadedCustom.pelapor, equals('Aan Supervisor'));
    });
  });
}
