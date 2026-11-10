class ErrorReport {
  final DateTime? reportedAt;
  final String lokasi;
  final String kendala;
  final String penyebab;
  final String solusiSementara;
  final String pelapor;

  const ErrorReport({
    this.reportedAt,
    this.lokasi = '',
    this.kendala = '',
    this.penyebab = '',
    this.solusiSementara = '',
    this.pelapor = '',
  });

  ErrorReport withFallbackTime(DateTime now) {
    if (reportedAt != null) return this;
    return ErrorReport(
      reportedAt: now,
      lokasi: lokasi,
      kendala: kendala,
      penyebab: penyebab,
      solusiSementara: solusiSementara,
      pelapor: pelapor,
    );
  }

  static ErrorReport parse(String text) {
    String? rawTanggal;
    String? rawWaktu;
    String? lokasi;
    String? kendala;
    String? penyebab;
    String? solusiSementara;
    String? pelapor;

    final lines = text.split('\n');
    final lineRegex = RegExp(r'^\s*[-•*]?\s*([^:]+?)\s*:\s*(.*)$');

    for (final line in lines) {
      final match = lineRegex.firstMatch(line);
      if (match == null) continue;

      final label = match.group(1)!.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      final rawVal = match.group(2)!.trim();
      final value = rawVal == '-' ? '' : rawVal;

      if (label == 'tanggal') {
        rawTanggal ??= value;
      } else if (label == 'waktu' || label == 'jam') {
        rawWaktu ??= value;
      } else if (label == 'lokasi') {
        lokasi ??= value;
      } else if (label == 'pelapor') {
        pelapor ??= value;
      } else if (label == 'kendala') {
        kendala ??= value;
      } else if (label == 'penyebab') {
        penyebab ??= value;
      } else if (label == 'solusi sementara' || label == 'solusi') {
        solusiSementara ??= value;
      }
    }

    final reportedAt = _parseDateTime(rawTanggal, rawWaktu);

    return ErrorReport(
      reportedAt: reportedAt,
      lokasi: lokasi ?? '',
      kendala: kendala ?? '',
      penyebab: penyebab ?? '',
      solusiSementara: solusiSementara ?? '',
      pelapor: pelapor ?? '',
    );
  }

  static DateTime? _parseDateTime(String? rawTanggal, String? rawWaktu) {
    if (rawTanggal == null || rawWaktu == null) return null;
    final cleanTgl = rawTanggal.trim();
    final cleanWkt = rawWaktu.trim();
    if (cleanTgl.isEmpty || cleanWkt.isEmpty) return null;

    final dMatch = RegExp(r'^(\d{1,2})[-/. ](\d{1,2})[-/. ](\d{2}|\d{4})$').firstMatch(cleanTgl);
    final tMatch = RegExp(r'^(\d{1,2})[:.](\d{2})$').firstMatch(cleanWkt);
    if (dMatch == null || tMatch == null) return null;

    final day = int.parse(dMatch.group(1)!);
    final month = int.parse(dMatch.group(2)!);
    var year = int.parse(dMatch.group(3)!);
    if (year < 100) year += 2000;

    final hour = int.parse(tMatch.group(1)!);
    final minute = int.parse(tMatch.group(2)!);

    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    final dt = DateTime(year, month, day, hour, minute);
    // Reject rollover dates (e.g. 31-02-2026)
    if (dt.year != year || dt.month != month || dt.day != day || dt.hour != hour || dt.minute != minute) {
      return null;
    }
    return dt;
  }

  String toDeskripsi(String original, {String pelapor = ''}) {
    final lines = <String>[];
    if (reportedAt != null) {
      final dStr = reportedAt!.day.toString().padLeft(2, '0');
      final mStr = reportedAt!.month.toString().padLeft(2, '0');
      final yStr = reportedAt!.year.toString().padLeft(4, '0');
      final hStr = reportedAt!.hour.toString().padLeft(2, '0');
      final minStr = reportedAt!.minute.toString().padLeft(2, '0');
      lines.add('Tanggal : $dStr-$mStr-$yStr');
      lines.add('Waktu : $hStr.$minStr');
    }
    if (lokasi.trim().isNotEmpty) lines.add('Lokasi : ${lokasi.trim()}');
    final effectivePelapor = pelapor.trim().isNotEmpty ? pelapor.trim() : this.pelapor.trim();
    if (effectivePelapor.isNotEmpty) lines.add('Pelapor : $effectivePelapor');
    if (kendala.trim().isNotEmpty) lines.add('Kendala : ${kendala.trim()}');
    if (penyebab.trim().isNotEmpty) lines.add('Penyebab : ${penyebab.trim()}');
    if (solusiSementara.trim().isNotEmpty) lines.add('Solusi sementara : ${solusiSementara.trim()}');

    final header = lines.join('\n');
    final orig = original.trim();
    if (orig.isEmpty) return header;
    if (header.isEmpty) {
      return orig.length > 2000 ? orig.substring(0, 2000) : orig;
    }

    final prefix = '$header\n\n';
    final available = 2000 - prefix.length;
    if (available <= 0) {
      return header.length > 2000 ? header.substring(0, 2000) : header;
    }
    if (orig.length > available) {
      return prefix + orig.substring(0, available);
    }
    return prefix + orig;
  }

  String judul(String original) {
    final k = kendala.trim();
    if (k.isNotEmpty) {
      return k.length > 120 ? k.substring(0, 120) : k;
    }

    final lines = original.split('\n');
    final labelPattern = RegExp(r'^\s*[-•*]?\s*[^:]+?\s*:\s*.*$');

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.toLowerCase().startsWith('selamat ')) continue;
      if (labelPattern.hasMatch(line)) continue;
      return line.length > 120 ? line.substring(0, 120) : line;
    }

    return '';
  }
}

String formatDurasi(Duration d) {
  if (d.isNegative) return '';
  if (d.inMinutes < 1) return '1 menit';

  final totalMinutes = d.inMinutes;
  final days = totalMinutes ~/ (24 * 60);
  final hours = (totalMinutes % (24 * 60)) ~/ 60;
  final minutes = totalMinutes % 60;

  final parts = <String>[];
  if (days > 0) parts.add('$days hari');
  if (hours > 0) parts.add('$hours jam');
  if (minutes > 0) parts.add('$minutes menit');

  return parts.join(' ');
}

String buildErrorReply({
  required String kendala,
  required String penyebab,
  required String solusiPerbaikan,
  required DateTime? reportedAt,
  required DateTime selesai,
  String catatan = '',
}) {
  final String greeting;
  if (selesai.hour < 11) {
    greeting = 'Selamat pagi';
  } else if (selesai.hour < 15) {
    greeting = 'Selamat siang';
  } else if (selesai.hour < 18) {
    greeting = 'Selamat sore';
  } else {
    greeting = 'Selamat malam';
  }

  const hariNames = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  const bulanNames = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  // Tanggal = tanggal error dilaporkan admin (Aan 2026-11-10); tanpa itu pakai tanggal selesai.
  final tgl = reportedAt ?? selesai;
  final hari = hariNames[tgl.weekday - 1];
  final dd = tgl.day.toString().padLeft(2, '0');
  final bulan = bulanNames[tgl.month - 1];
  final yyyy = tgl.year.toString();

  final valKendala = kendala.trim().isEmpty ? '-' : kendala.trim();
  final valPenyebab = penyebab.trim().isEmpty ? '-' : penyebab.trim();
  final valSolusi = solusiPerbaikan.trim().isEmpty ? '-' : solusiPerbaikan.trim();

  final buf = StringBuffer();
  buf.write('$greeting\n');
  buf.write('Izin melaporkan hasil support maintenance $hari, $dd $bulan $yyyy\n\n');
  buf.write('- Kendala : $valKendala\n\n');
  buf.write('- Penyebab : $valPenyebab\n\n');
  buf.write('- Solusi Perbaikan : $valSolusi');

  if (reportedAt != null) {
    final durasi = formatDurasi(selesai.difference(reportedAt));
    if (durasi.isNotEmpty) {
      buf.write('\n\n- Durasi Perbaikan : $durasi');
    }
  }

  if (catatan.trim().isNotEmpty) {
    buf.write('\n\n- Catatan : ${catatan.trim()}');
  }

  buf.write('\n\nTerima Kasih 🙏');
  return buf.toString();
}

String errorCatatanTeknisi({
  required String penyebab,
  required String solusiPerbaikan,
  String catatan = '',
}) {
  final p = penyebab.trim().isEmpty ? '-' : penyebab.trim();
  final s = solusiPerbaikan.trim().isEmpty ? '-' : solusiPerbaikan.trim();
  final base = 'Penyebab : $p\nSolusi Perbaikan : $s';
  if (catatan.trim().isNotEmpty) {
    return '$base\nCatatan : ${catatan.trim()}';
  }
  return base;
}
