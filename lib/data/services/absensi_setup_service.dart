import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/submission_model.dart';
import 'storage_service.dart';

class AbsensiSetupService extends ChangeNotifier {
  static final AbsensiSetupService instance = AbsensiSetupService._internal();
  AbsensiSetupService._internal() {
    _load();
  }

  static const _kKategori = 'absensi_kategori_v1';
  static const _kLokasi = 'absensi_lokasi_standby_v1';
  static const _kShift = 'absensi_jadwal_shift_v1';
  static const _kTipe = 'absensi_tipe_laporan_v1';
  static const _kJamPulang = 'absensi_jam_pulang_v1';
  static const _kNextShift = 'absensi_next_shift_v1';
  static const _kSelesai = 'absensi_pekerjaan_selesai_v1';
  static const _kBelum = 'absensi_pekerjaan_belum_v1';
  static const _kHandoverDate = 'absensi_handover_date_v1';

  AbsensiKategori selectedKategori = AbsensiKategori.teknisi;
  String lokasiStandby = 'PBM';
  String jadwalShift = '';
  String tipeLaporan = 'Masuk';
  String jamPulang = '';
  String shiftSelanjutnya = '';
  String pekerjaanSelesai = '';
  String pekerjaanBelum = '';
  String handoverDate = '';
  static const List<String> shiftOptions = [
    'Shift 1 (03:00 - 11:00)',
    'Shift 2.2 (10:00 - 14:00)',
    'Shift 2 (10:00 - 18:00)',
    'Shift 3 (14:00 - 22:00)',
  ];

  /// Mendeteksi nama shift otomatis sesuai jam saat ini (atau waktu foto):
  /// - 09:50 - 13:49 ➔ Shift 2 (10:00 - 18:00) (otomatis Shift 2 mulai 09:50)
  /// - 13:50 - 21:49 ➔ Shift 3 (14:00 - 22:00) (otomatis Shift 3 mulai 13:50)
  /// - 21:50 - 09:49 ➔ Shift 1 (03:00 - 11:00)
  static String autoDetectShift([DateTime? time]) {
    final local = (time ?? DateTime.now()).toLocal();
    final minutes = local.hour * 60 + local.minute;

    if (minutes >= 590 && minutes < 830) {
      // 09:50 - 13:49: Shift 2 (10:00 - 18:00)
      return 'Shift 2 (10:00 - 18:00)';
    } else if (minutes >= 830 && minutes < 1310) {
      // 13:50 - 21:49: Shift 3 (14:00 - 22:00)
      return 'Shift 3 (14:00 - 22:00)';
    } else {
      // 21:50 - 09:49: Shift 1 (03:00 - 11:00)
      return 'Shift 1 (03:00 - 11:00)';
    }
  }

  /// Durasi kerja minimal: 4 jam untuk Shift 2.2, 8 jam untuk Shift 1, 2, 3.
  /// Jika Mode Demo / SPV Bypass aktif: Durasi minimal 0 detik (bisa langsung pulang untuk demo).
  static Duration getMinimumWorkDuration(String shift) {
    if (StorageService.isDemoBypassActive()) {
      return Duration.zero;
    }
    final isShift2_2 = shift.contains('Shift 2.2') ||
        (shift.contains('10:00') && shift.contains('14:00'));
    return isShift2_2 ? const Duration(hours: 4) : const Duration(hours: 8);
  }

  /// Menghitung sisa waktu kerja sebelum boleh absensi pulang.
  /// Mengembalikan Duration.zero jika sudah memenuhi syarat, atau sisa durasi jika belum.
  static Duration? getRemainingWorkTime({
    required String shift,
    required DateTime? checkInTime,
    DateTime? currentTime,
  }) {
    if (checkInTime == null) return null;
    if (StorageService.isDemoBypassActive()) return Duration.zero;
    final now = currentTime ?? DateTime.now();
    final minDuration = getMinimumWorkDuration(shift);
    final worked = now.isAfter(checkInTime) ? now.difference(checkInTime) : Duration.zero;
    if (worked >= minDuration) return Duration.zero;
    return minDuration - worked;
  }

  /// Menghitung DateTime akhir jadwal shift berdasarkan checkInTime.
  /// Contoh: Shift 1 (03:00 - 11:00) ➔ 11:00 hari tersebut.
  /// Jika jam akhir shift sebelum jam checkIn (misal shift malam melintasi tengah malam),
  /// waktu akhir shift ditambahkan 1 hari.
  static DateTime getScheduledPulangTime({
    required String shift,
    required DateTime checkInTime,
  }) {
    final jamPulangStr = autoDetectJamPulang(shift: shift, time: checkInTime);
    final parts = jamPulangStr.split(':');
    final targetH = parts.length == 2 ? (int.tryParse(parts[0]) ?? 18) : 18;
    final targetM = parts.length == 2 ? (int.tryParse(parts[1]) ?? 0) : 0;

    var scheduledPulang = DateTime(
      checkInTime.year,
      checkInTime.month,
      checkInTime.day,
      targetH,
      targetM,
    );
    if (scheduledPulang.isBefore(checkInTime)) {
      scheduledPulang = scheduledPulang.add(const Duration(days: 1));
    }
    return scheduledPulang;
  }

  /// Memeriksa apakah syarat absensi kepulangan sudah terpenuhi:
  /// Sesuai SOP Operasional Shift Parkir (Opsi 1):
  /// 1. Jam akhir jadwal shift sudah tiba / selesai (misal Shift 1 >= 11:00, Shift 2.2 >= 14:00, Shift 2 >= 18:00, Shift 3 >= 22:00).
  ///    Teknisi yang terlambat tetap diizinkan pulang saat jam pergantian shift agar pos dapat diserahterimakan ke shift berikutnya.
  /// 2. ATAU durasi kerja minimal sudah terpenuhi (>= 8 jam untuk Shift 1, 2, 3, dan >= 4 jam untuk Shift 2.2).
  /// 3. Jika Mode Demo / SPV Bypass aktif: Selalu true.
  ///
  /// Proteksi Pulang Cepat: Jika jam sekarang belum mencapai jam akhir shift DAN durasi kerja belum terpenuhi,
  /// fungsi mengembalikan false.
  static bool isEligibleForAutoPulang({
    required String shift,
    required DateTime checkInTime,
    DateTime? currentTime,
  }) {
    if (StorageService.isDemoBypassActive()) {
      return true;
    }

    final now = currentTime ?? DateTime.now();

    // Syarat 1: Jam akhir jadwal shift sudah tiba / lewat
    final scheduledPulang = getScheduledPulangTime(
      shift: shift,
      checkInTime: checkInTime,
    );
    final isShiftEnded = !now.isBefore(scheduledPulang);

    // Syarat 2: Durasi kerja minimal sudah terpenuhi (misal dinas fleksibel / lembur penuh)
    final minDuration = getMinimumWorkDuration(shift);
    final worked = now.isAfter(checkInTime) ? now.difference(checkInTime) : Duration.zero;
    final isMinDurationMet = worked >= minDuration;

    return isShiftEnded || isMinDurationMet;
  }

  /// Mendeteksi jam akhir shift untuk laporan pulang:
  /// - Shift 1 ➔ 11:00
  /// - Shift 2.2 ➔ 14:00
  /// - Shift 2 ➔ 18:00
  /// - Shift 3 ➔ 22:00
  static String autoDetectJamPulang({String? shift, DateTime? time}) {
    final s = (shift != null && shift.trim().isNotEmpty)
        ? shift
        : autoDetectShift(time);
    
    // Cek pattern jam rentang khusus (misal "08:00 - 16:00" atau "Shift Khusus (08:00 - 17:00)")
    final rangeMatch = RegExp(r'(\d{1,2}):(\d{2})\s*[-–]\s*(\d{1,2}):(\d{2})').firstMatch(s);
    if (rangeMatch != null) {
      final endH = rangeMatch.group(3)!.padLeft(2, '0');
      final endM = rangeMatch.group(4)!.padLeft(2, '0');
      return '$endH:$endM';
    }

    if (s.contains('Shift 2.2') || (s.contains('10:00') && s.contains('14:00'))) {
      return '14:00';
    } else if (s.contains('03:00') || s.contains('Shift 1') || (s.contains('11:00') && !s.contains('18:00'))) {
      return '11:00';
    } else if (s.contains('18:00') || s.contains('Shift 2')) {
      return '18:00';
    } else if (s.contains('22:00') || s.contains('Shift 3')) {
      return '22:00';
    }
    return '18:00';
  }

  /// Jadwal shift efektif: jika kosong, gunakan auto-detect
  String get effectiveJadwalShift {
    if (jadwalShift.trim().isEmpty) {
      return autoDetectShift();
    }
    return jadwalShift;
  }

  /// Jam pulang efektif: jika kosong, ambil jam akhir shift
  String get effectiveJamPulang {
    if (jamPulang.trim().isEmpty) {
      return autoDetectJamPulang(shift: effectiveJadwalShift);
    }
    return jamPulang;
  }

  String get hariKerja {
    const map = ['SENIN','SELASA','RABU','KAMIS','JUMAT','SABTU','MINGGU'];
    return map[DateTime.now().weekday - 1];
  }

  String get seragamHariIni {
    switch (hariKerja) {
      case 'SENIN': return 'Teknisi / PDH navy';
      case 'SELASA': return 'PDH biru navy / Teknisi';
      case 'RABU': return 'Seragam Teknisi';
      case 'KAMIS': return 'BSS Putih / Teknisi';
      case 'JUMAT': return 'Batik / Teknisi';
      case 'SABTU': return 'Olahraga biru-kuning / Teknisi';
      case 'MINGGU': return 'Bebas rapi / Teknisi';
      default: return 'Seragam Teknisi';
    }
  }

  bool get isTeknisiReady => true;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cat = prefs.getString(_kKategori);
      if (cat != null) selectedKategori = AbsensiKategori.fromString(cat);
      final rawLokasi = prefs.getString(_kLokasi);
      lokasiStandby = (rawLokasi != null && rawLokasi.trim().isNotEmpty)
          ? rawLokasi.trim().toUpperCase()
          : 'PBM';
      final rawShift = prefs.getString(_kShift);
      if (rawShift != null && rawShift.trim().isNotEmpty) {
        if (rawShift.contains('11:00 - 18:00')) {
          jadwalShift = 'Shift 2 (10:00 - 18:00)';
          _save();
        } else {
          jadwalShift = rawShift.trim();
        }
      } else {
        jadwalShift = autoDetectShift();
      }
      tipeLaporan = prefs.getString(_kTipe) ?? 'Masuk';
      final lastCheck = StorageService.getLastCheckInTime();
      if (lastCheck != null &&
          isEligibleForAutoPulang(
            shift: effectiveJadwalShift,
            checkInTime: lastCheck,
          )) {
        tipeLaporan = 'Pulang';
      }
      final rawJamPulang = prefs.getString(_kJamPulang);
      if (rawJamPulang != null && rawJamPulang.trim().isNotEmpty) {
        jamPulang = rawJamPulang.trim();
      } else {
        jamPulang = autoDetectJamPulang(shift: jadwalShift);
      }
      shiftSelanjutnya = prefs.getString(_kNextShift) ?? '';
      handoverDate = prefs.getString(_kHandoverDate) ?? '';
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      if (handoverDate != todayStr) {
        // Jika handover bukan dari hari ini, reset agar wajib sinkron/isi tugas hari ini
        pekerjaanSelesai = '';
        pekerjaanBelum = '';
        handoverDate = '';
      } else {
        pekerjaanSelesai = prefs.getString(_kSelesai) ?? '';
        pekerjaanBelum = prefs.getString(_kBelum) ?? '';
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kKategori, selectedKategori.name);
      await prefs.setString(_kLokasi, lokasiStandby.trim().isNotEmpty ? lokasiStandby.trim().toUpperCase() : 'PBM');
      await prefs.setString(_kShift, effectiveJadwalShift);
      await prefs.setString(_kTipe, tipeLaporan);
      await prefs.setString(_kJamPulang, effectiveJamPulang);
      await prefs.setString(_kNextShift, shiftSelanjutnya);
      await prefs.setString(_kSelesai, pekerjaanSelesai);
      await prefs.setString(_kBelum, pekerjaanBelum);
      await prefs.setString(_kHandoverDate, handoverDate);
    } catch (_) {}
  }

  void updateKategori(AbsensiKategori k) {
    selectedKategori = k;
    if (lokasiStandby.trim().isEmpty) lokasiStandby = 'PBM';
    if (jadwalShift.trim().isEmpty) jadwalShift = autoDetectShift();
    _save();
    notifyListeners();
  }

  void updateLokasi(String v) {
    final clean = v.trim().toUpperCase();
    lokasiStandby = clean.isNotEmpty ? clean : 'PBM';
    _save();
    notifyListeners();
  }

  void updateShift(String v) {
    final clean = v.trim();
    jadwalShift = clean.isNotEmpty ? clean : autoDetectShift();
    _save();
    notifyListeners();
  }

  void updateTipe(String v) {
    tipeLaporan = v;
    _save();
    notifyListeners();
  }

  void updateJamPulang(String v) {
    jamPulang = v;
    _save();
    notifyListeners();
  }

  void _syncTodayDate() {
    final now = DateTime.now();
    handoverDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void updateNextShift(String v) {
    shiftSelanjutnya = v;
    _syncTodayDate();
    _save();
    notifyListeners();
  }

  void updatePekerjaanSelesai(String v) {
    pekerjaanSelesai = v;
    _syncTodayDate();
    _save();
    notifyListeners();
  }

  void updatePekerjaanBelum(String v) {
    pekerjaanBelum = v;
    _syncTodayDate();
    _save();
    notifyListeners();
  }

  void updateDailyHandover({
    required String nextShift,
    required String selesai,
    required String belum,
    String? date,
  }) {
    final now = DateTime.now();
    final todayStr = date ?? '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    shiftSelanjutnya = nextShift;
    pekerjaanSelesai = selesai;
    pekerjaanBelum = belum;
    handoverDate = todayStr;
    _save();
    notifyListeners();
  }

  /// Memeriksa apakah teknisi sudah mengisi laporan daily & IT Support pengganti
  /// Kebijakan: 'Isi daily dulu ya!' sebelum absensi pulang (harus bertanggal hari ini)
  bool isDailyHandoverComplete({String? targetDate}) {
    final now = DateTime.now();
    final todayStr = targetDate ??
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Tolak jika data berasal dari tanggal kemarin (data basi)
    if (handoverDate.isNotEmpty && handoverDate != todayStr) {
      return false;
    }

    final next = shiftSelanjutnya.trim();
    final selesai = pekerjaanSelesai.trim();

    final hasNext = next.isNotEmpty &&
        next != '-' &&
        !next.toLowerCase().contains('tidak ada petugas');

    final hasSelesai = selesai.isNotEmpty &&
        selesai != '-' &&
        selesai != '1. -' &&
        selesai.length >= 3;

    return hasNext && hasSelesai;
  }
}
