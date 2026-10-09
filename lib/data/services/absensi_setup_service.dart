import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/submission_model.dart';
import 'storage_service.dart';
import 'branch_service.dart';

class AbsensiSetupService extends ChangeNotifier {
  static final AbsensiSetupService instance = AbsensiSetupService._internal();
  final Map<AppBranch, String> _branchShifts = {};
  final Map<AppBranch, String> _branchLocations = {};

  AbsensiSetupService._internal() {
    _load();
    BranchService.instance.addListener(_onBranchChanged);
  }

  void _onBranchChanged() {
    final branch = BranchService.instance.currentBranch;
    if (_branchShifts.containsKey(branch)) {
      jadwalShift = _branchShifts[branch]!;
    } else {
      jadwalShift = autoDetectShift();
    }
    if (_branchLocations.containsKey(branch)) {
      lokasiStandby = _branchLocations[branch]!;
    } else {
      lokasiStandby = branch.defaultLocationTag;
    }
    _load();
    notifyListeners();
  }

  static const _kKategori = 'absensi_kategori_v1';
  static const _kLokasi = 'absensi_lokasi_standby_v1';
  static const _kShift = 'absensi_jadwal_shift_v1';
  static String _kShiftKey(AppBranch b) => 'absensi_jadwal_shift_${b.code}';
  static String _kLokasiKey(AppBranch b) => 'absensi_lokasi_standby_${b.code}';
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
  static List<String> get currentShiftOptions => BranchService.instance.getShifts();
  static const List<String> shiftOptions = [
    'Shift 1 (03:00 - 11:00)',
    'Shift 2.2 (10:00 - 14:00)',
    'Shift 2 (10:00 - 18:00)',
    'Shift 3 (14:00 - 22:00)',
  ];

  /// Mendeteksi nama shift otomatis sesuai jam saat ini (atau waktu foto):
  /// - KC Bali:
  ///   * 05:30 - 13:49 ➔ Shift 1 (06.00 - 14.00)
  ///   * 13:50 - 21:49 ➔ Shift 2 (14.00 - 22.00)
  ///   * 21:50 - 05:29 ➔ Shift 3 (22.00 - 06.00)
  /// - KC Manado:
  ///   * 09:50 - 13:49 ➔ Shift 2 (10:00 - 18:00)
  ///   * 13:50 - 21:49 ➔ Shift 3 (14:00 - 22:00)
  ///   * 21:50 - 09:49 ➔ Shift 1 (03:00 - 11:00)
  static String autoDetectShift([DateTime? time]) {
    final local = (time ?? DateTime.now()).toLocal();
    final minutes = local.hour * 60 + local.minute;

    if (BranchService.instance.currentBranch == AppBranch.bali) {
      if (minutes >= 330 && minutes < 830) {
        return 'Shift 1 (06.00 - 14.00)';
      } else if (minutes >= 830 && minutes < 1310) {
        return 'Shift 2 (14.00 - 22.00)';
      } else {
        return 'Shift 3 (22.00 - 06.00)';
      }
    }

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

  /// Durasi kerja minimal: 4 jam untuk Shift paruh waktu (Shift 2.2 / Shift 4.1), 8 jam untuk shift penuh.
  /// Jika Mode Demo / SPV Bypass aktif: Durasi minimal 0 detik (bisa langsung pulang untuk demo).
  static Duration getMinimumWorkDuration(String shift) {
    if (StorageService.isDemoBypassActive()) {
      return Duration.zero;
    }
    final isShiftPartTime = shift.contains('Shift 2.2') ||
        shift.contains('Shift 4.1') ||
        (shift.contains('10:00') && shift.contains('14:00')) ||
        (shift.contains('18.00') && shift.contains('22.00')) ||
        (shift.contains('08.00') && shift.contains('12.00'));
    return isShiftPartTime ? const Duration(hours: 4) : const Duration(hours: 8);
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
    
    // Cek pattern jam rentang khusus (misal "08:00 - 16:00" atau "06.00 - 14.00")
    final rangeMatch = RegExp(r'(\d{1,2})[:.](\d{2})\s*[-–]\s*(\d{1,2})[:.](\d{2})').firstMatch(s);
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

  /// Jadwal shift efektif: jika kosong atau merupakan shift milik cabang lain, gunakan auto-detect cabang
  String get effectiveJadwalShift {
    final clean = jadwalShift.trim();
    if (clean.isEmpty) return autoDetectShift();
    final branch = BranchService.instance.currentBranch;
    final otherBranch = branch == AppBranch.manado ? AppBranch.bali : AppBranch.manado;
    final otherBranchShifts = BranchService.instance.getShifts(branch: otherBranch);
    if (otherBranchShifts.contains(clean)) {
      return autoDetectShift();
    }
    return clean;
  }

  /// Lokasi standby efektif: pastikan selalu valid untuk cabang aktif
  String get effectiveLokasiStandby {
    final branch = BranchService.instance.currentBranch;
    final validTags = BranchService.instance.getLocationTags(branch: branch);
    if (lokasiStandby.trim().isNotEmpty && validTags.contains(lokasiStandby.trim().toUpperCase())) {
      return lokasiStandby.trim().toUpperCase();
    }
    return branch.defaultLocationTag;
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

      final branch = BranchService.instance.currentBranch;
      final rawLokasi = prefs.getString(_kLokasiKey(branch)) ?? prefs.getString(_kLokasi);
      final validTags = BranchService.instance.getLocationTags(branch: branch);
      if (rawLokasi != null && rawLokasi.trim().isNotEmpty && validTags.contains(rawLokasi.trim().toUpperCase())) {
        lokasiStandby = rawLokasi.trim().toUpperCase();
        _branchLocations[branch] = lokasiStandby;
      } else {
        lokasiStandby = branch.defaultLocationTag;
      }

      final rawShift = prefs.getString(_kShiftKey(branch)) ?? prefs.getString(_kShift);
      final otherBranch = branch == AppBranch.manado ? AppBranch.bali : AppBranch.manado;
      final otherBranchShifts = BranchService.instance.getShifts(branch: otherBranch);
      if (rawShift != null && rawShift.trim().isNotEmpty && !otherBranchShifts.contains(rawShift.trim())) {
        jadwalShift = rawShift.trim();
        _branchShifts[branch] = jadwalShift;
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
        jamPulang = autoDetectJamPulang(shift: effectiveJadwalShift);
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
      final branch = BranchService.instance.currentBranch;
      await prefs.setString(_kKategori, selectedKategori.name);
      final cleanLokasi = effectiveLokasiStandby;
      await prefs.setString(_kLokasiKey(branch), cleanLokasi);
      await prefs.setString(_kLokasi, cleanLokasi);
      final cleanShift = effectiveJadwalShift;
      await prefs.setString(_kShiftKey(branch), cleanShift);
      await prefs.setString(_kShift, cleanShift);
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
    final branch = BranchService.instance.currentBranch;
    if (lokasiStandby.trim().isEmpty || !BranchService.instance.getLocationTags().contains(lokasiStandby)) {
      lokasiStandby = branch.defaultLocationTag;
    }
    final otherBranch = branch == AppBranch.manado ? AppBranch.bali : AppBranch.manado;
    final otherBranchShifts = BranchService.instance.getShifts(branch: otherBranch);
    if (jadwalShift.trim().isEmpty || otherBranchShifts.contains(jadwalShift.trim())) {
      jadwalShift = autoDetectShift();
    }
    _save();
    notifyListeners();
  }

  void updateLokasi(String v) {
    final clean = v.trim().toUpperCase();
    final branch = BranchService.instance.currentBranch;
    final validTags = BranchService.instance.getLocationTags(branch: branch);
    lokasiStandby = (clean.isNotEmpty && validTags.contains(clean)) ? clean : branch.defaultLocationTag;
    _branchLocations[branch] = lokasiStandby;
    _save();
    notifyListeners();
  }

  void updateShift(String v) {
    final clean = v.trim();
    final branch = BranchService.instance.currentBranch;
    final otherBranch = branch == AppBranch.manado ? AppBranch.bali : AppBranch.manado;
    final otherBranchShifts = BranchService.instance.getShifts(branch: otherBranch);
    jadwalShift = (clean.isNotEmpty && !otherBranchShifts.contains(clean)) ? clean : autoDetectShift();
    _branchShifts[branch] = jadwalShift;
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
