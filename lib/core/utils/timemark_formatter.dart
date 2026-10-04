import 'package:intl/intl.dart';

class TimemarkFormatter {
  static const List<String> _namaHari = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  static const List<String> _namaBulan = [
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

  /// Formats date to Indonesian style: "Minggu, 23 Agustus 2026"
  static String formatIndonesianFullDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final dayName = _namaHari[local.weekday - 1];
    final day = local.day;
    final monthName = _namaBulan[local.month - 1];
    final year = local.year;
    return '$dayName, $day $monthName $year';
  }

  /// Formats time to big digital clock: "12:43"
  static String formatClockTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Formats time with seconds: "12:43:25 WITA"
  static String formatTimeWithSeconds(DateTime dateTime, {String timezone = 'WITA'}) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second $timezone';
  }

  /// Format GPS coordinates to exact degree format: "1.497558°N, 124.841501°E"
  static String formatGpsDegree(double? lat, double? lng) {
    if (lat == null || lng == null) {
      return 'Lokasi tidak terdeteksi (GPS Nonaktif)';
    }

    final latDir = lat >= 0 ? 'N' : 'S';
    final lngDir = lng >= 0 ? 'E' : 'W';
    final latAbs = lat.abs().toStringAsFixed(6);
    final lngAbs = lng.abs().toStringAsFixed(6);

    return '$latAbs°$latDir, $lngAbs°$lngDir';
  }

  /// Formats standard audit timemark: "23 Aug 2026 • 14:35:10 WITA"
  static String formatTimemarkWib(DateTime dateTime, {String timezone = 'WITA'}) {
    final format = DateFormat('dd MMM yyyy • HH:mm:ss');
    return '${format.format(dateTime)} $timezone';
  }

  /// Menghitung durasi kerja: misal "8h 19 min"
  static String formatWorkDuration(Duration diff) {
    if (diff.isNegative || diff.inMinutes <= 0) return '0h 00 min';
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    return '${hours}h ${minutes.toString().padLeft(2, '0')} min';
  }
}
