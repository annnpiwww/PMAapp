import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/submission_model.dart';
import 'storage_service.dart';
import 'branch_service.dart';
import 'secure_time_service.dart';

class AbsensiSetupService extends ChangeNotifier {
  static final AbsensiSetupService instance = AbsensiSetupService._internal();
  final Map<AppBranch, String> _branchShifts = {};
  final Map<AppBranch, String> _branchLocations = {};
  final Map<AppBranch, DateTime> _branchShiftSetAt = {};

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
  static String _kShiftSetAtKey(AppBranch b) =>
      'absensi_jadwal_shift_set_at_${b.code}';
  static String _kLokasiKey(AppBranch b) => 'absensi_lokasi_standby_${b.code}';
  static const _kTipe = 'absensi_tipe_laporan_v1';
  static const _kJamPulang = 'absensi_jam_pulang_v1';
  static const _kNextShift = 'absensi_next_shift_v1';
  static const _kSelesai = 'absensi_pekerjaan_selesai_v1';
  static const _kBelum = 'absensi_pekerjaan_belum_v1';
  static const _kHandoverDate = 'absensi_handover_date_v1';

  AbsensiKategori selectedKategori = AbsensiKategori.teknisi;
  // Default mengikuti cabang aktif, bukan dipaku PBM.
  String lokasiStandby =
      BranchService.instance.currentBranch.defaultLocationTag;
  String jadwalShift = '';
  String tipeLaporan = 'Masuk';
  String jamPulang = '';
  String shiftSelanjutnya = '';
  String pekerjaanSelesai = '';
  String pekerjaanBelum = '';
  String handoverDate = '';

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

    if (BranchService.instance.currentBranch == AppBranch.ho) {
      return _autoDetectHoShift(minutes);
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

  /// Shift manual bisa basi: Shift 1 kemarin masih tersimpan padahal hari ini
  /// teknisi masuk siang, sehingga absen tercatat Terlambat. Reset ke auto-detect
  /// hanya kalau tidak ada sesi Masuk aktif (< 16 jam) dan teknisi tidak baru
  /// memilih shift sendiri (< 4 jam), supaya alur Pulang tetap pakai shift Masuk.
  static bool shouldResetShift({
    DateTime? lastCheckIn,
    DateTime? shiftSetAt,
    required DateTime now,
  }) {
    if (lastCheckIn != null &&
        now.difference(lastCheckIn) < const Duration(hours: 16)) {
      return false;
    }
    if (shiftSetAt != null &&
        now.difference(shiftSetAt) < const Duration(hours: 4)) {
      return false;
    }
    return true;
  }

  /// Shift terpilih kemungkinan salah kalau jam mulai shift itu sudah lewat
  /// > 2 jam. Datang lebih awal (masih > 6 jam sebelum shift berikutnya, mis.
  /// 21:00 untuk shift 03:00) tidak pernah dianggap salah.
  /// shortcut: jendela 18 jam (bukan 12 jam) supaya 15:55 vs shift 03:00 tetap
  /// terdeteksi; revisit kalau pola shift berubah.
  static bool isLikelyWrongShift(String shift, DateTime now) {
    final match = RegExp(r'(\d{1,2})[:.](\d{2})').firstMatch(shift);
    if (match == null) return false;
    final startMin =
        ((int.tryParse(match.group(1)!) ?? 0) % 24) * 60 +
        (int.tryParse(match.group(2)!) ?? 0);
    final nowMin = now.hour * 60 + now.minute;
    final lateMin = (nowMin - startMin) % 1440;
    return lateMin > 120 && lateMin < 1080;
  }

  /// Shift HO lama masih menyimpan nomor (RSWS 1 / JP 2); label baru tanpa nomor
  /// karena pembeda cukup jam. Normalisasi saat load supaya pilihan shift tetap
  /// terpilih tanpa mengubah riwayat absensi yang sudah tersimpan.
  static String _normalizeShiftLabel(String shift) {
    return shift
        .replaceFirst('RSWS 1 (', 'RSWS (')
        .replaceFirst('RSWS 2 (', 'RSWS (')
        .replaceFirst('JP 1 (', 'JP (')
        .replaceFirst('JP 2 (', 'JP (');
  }

  /// HO Makassar punya 11 shift dan beberapa berbagi jam mulai (Shift 1 vs Shift 1.1,
  /// GMM 2 vs RSWS). Auto-detect memakai shift dengan jam mulai terakhir
  /// yang <= jam sekarang; sisanya dipilih manual oleh teknisi.
  /// shortcut: hanya satu shift per jam mulai yang auto-terdeteksi, upgrade kalau
  /// nanti HO butuh deteksi berbasis pos.
  static String _autoDetectHoShift(int minutes) {
    const starts = <int, String>{
      0: 'Shift 3 (24.00 - 08.00)',
      480: 'Shift 1 (08.00 - 16.00)',
      510: 'HO.1 (08.30 - 12.30)',
      540: 'GMM 1 (09.00 - 17.00)',
      900: 'RSWS (15.00 - 23.00)',
      960: 'Shift 2 (16.00 - 24.00)',
      1020: 'JP (17.00 - 01.00)',
    };
    var picked = 'Shift 3 (24.00 - 08.00)';
    var best = -1;
    for (final entry in starts.entries) {
      if (entry.key <= minutes && entry.key > best) {
        best = entry.key;
        picked = entry.value;
      }
    }
    return picked;
  }

  /// Durasi kerja minimal: 4 jam untuk Shift paruh waktu (Shift 2.2 / Shift 4.1), 8 jam untuk shift penuh.
  /// Jika Mode Demo / SPV Bypass aktif: Durasi minimal 0 detik (bisa langsung pulang untuk demo).
  static Duration getMinimumWorkDuration(String shift) {
    if (StorageService.isDemoBypassActive()) {
      return Duration.zero;
    }
    final isShiftPartTime =
        shift.contains('Shift 2.2') ||
        shift.contains('Shift 4.1') ||
        shift.contains('HO.1') ||
        (shift.contains('10:00') && shift.contains('14:00')) ||
        (shift.contains('18.00') && shift.contains('22.00')) ||
        (shift.contains('08.00') && shift.contains('12.00'));
    return isShiftPartTime
        ? const Duration(hours: 4)
        : const Duration(hours: 8);
  }

  /// Batas paling awal teknisi boleh absen pulang.
  ///
  /// Patokan utama = jam akhir shift (Shift 1.1 ➔ 14:00, Shift 2 ➔ 18:00), bukan
  /// "8 jam sejak jam masuk". Contoh kasus: masuk 05:56 di Shift 1.1 (06:00 - 14:00),
  /// hitungan 8 jam jatuh 13:56 sehingga teknisi pulang sebelum shift berakhir.
  /// Kalau teknisi masuk SETELAH jam akhir shiftnya (telat masuk / shift malam yang
  /// berakhir besok pagi), patokannya durasi kerja minimal supaya pos tetap
  /// diserahterimakan dan teknisi tidak terkunci sampai besok.
  static DateTime pulangAllowedFrom({
    required String shift,
    required DateTime checkInTime,
  }) {
    final parts = autoDetectJamPulang(
      shift: shift,
      time: checkInTime,
    ).split(':');
    final endH = parts.length == 2 ? (int.tryParse(parts[0]) ?? 18) : 18;
    final endM = parts.length == 2 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final shiftEnd = DateTime(
      checkInTime.year,
      checkInTime.month,
      checkInTime.day,
      endH,
      endM,
    );
    if (shiftEnd.isBefore(checkInTime)) {
      return checkInTime.add(getMinimumWorkDuration(shift));
    }
    return shiftEnd;
  }

  /// Menghitung sisa waktu sebelum boleh absensi pulang.
  /// Mengembalikan Duration.zero jika sudah boleh pulang, atau sisa waktu jika belum.
  static Duration? getRemainingWorkTime({
    required String shift,
    required DateTime? checkInTime,
    DateTime? currentTime,
  }) {
    if (checkInTime == null) return null;
    if (StorageService.isDemoBypassActive()) return Duration.zero;
    // honey: waktu terverifikasi mencegah manipulasi jam device; fallback ke currentTime untuk unit test
    final now = currentTime ?? SecureTimeService.getVerifiedTime().accurateTime;
    final gate = pulangAllowedFrom(shift: shift, checkInTime: checkInTime);
    if (!now.isBefore(gate)) return Duration.zero;
    return gate.difference(now);
  }

  /// Memeriksa apakah syarat absensi kepulangan sudah terpenuhi:
  /// Absen pulang baru boleh SETELAH jam akhir shift (Shift 1.1 >= 14:00,
  /// Shift 2.2 >= 14:00, Shift 2 >= 18:00, Shift 3 >= 22:00).
  /// Durasi kerja minimal tidak lagi jadi jalan pintas pulang lebih awal, karena
  /// jam masuk yang maju beberapa menit membuat 8 jam jatuh sebelum shift berakhir.
  /// Teknisi yang telat masuk tetap diizinkan pulang saat jam pergantian shift.
  /// Mode Demo / SPV Bypass aktif: selalu true.
  static bool isEligibleForAutoPulang({
    required String shift,
    required DateTime checkInTime,
    DateTime? currentTime,
  }) {
    if (StorageService.isDemoBypassActive()) {
      return true;
    }

    // honey: waktu terverifikasi mencegah bypass pulang cepat via ubah jam device
    final now = currentTime ?? SecureTimeService.getVerifiedTime().accurateTime;
    return !now.isBefore(
      pulangAllowedFrom(shift: shift, checkInTime: checkInTime),
    );
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
    final rangeMatch = RegExp(
      r'(\d{1,2})[:.](\d{2})\s*[-–—]\s*(\d{1,2})[:.](\d{2})',
    ).firstMatch(s);
    if (rangeMatch != null) {
      final endH = rangeMatch.group(3)!.padLeft(2, '0');
      final endM = rangeMatch.group(4)!.padLeft(2, '0');
      return '$endH:$endM';
    }

    final allTimeMatches = RegExp(
      r'(\d{1,2})[:.](\d{2})',
    ).allMatches(s).toList();
    if (allTimeMatches.length >= 2) {
      final second = allTimeMatches[1];
      final endH = second.group(1)!.padLeft(2, '0');
      final endM = second.group(2)!.padLeft(2, '0');
      return '$endH:$endM';
    }

    if (s.contains('Shift 2.2') ||
        (s.contains('10:00') && s.contains('14:00'))) {
      return '14:00';
    } else if (s.contains('03:00') ||
        s.contains('Shift 1') ||
        (s.contains('11:00') && !s.contains('18:00'))) {
      return '11:00';
    } else if (s.contains('18:00') || s.contains('Shift 2')) {
      return '18:00';
    } else if (s.contains('22:00') || s.contains('Shift 3')) {
      return '22:00';
    }
    return '18:00';
  }

  /// Cek apakah shift merupakan shift kustom teknisi (bukan shift bawaan cabang aktif maupun cabang lain).
  static bool isCustomShift(String shift) {
    final clean = shift.trim();
    return clean.isNotEmpty &&
        !BranchService.instance.getShifts().contains(clean) &&
        !BranchService.isShiftOfOtherBranch(clean);
  }

  /// Jadwal shift efektif: jika kosong atau merupakan shift milik cabang lain, gunakan auto-detect cabang
  String get effectiveJadwalShift {
    final clean = jadwalShift.trim();
    if (clean.isEmpty) return autoDetectShift();
    if (BranchService.isShiftOfOtherBranch(clean)) {
      return autoDetectShift();
    }
    return clean;
  }

  /// Lokasi standby efektif: pakai isian teknisi apa adanya (teknisi Bali bisa isi
  /// manual pos lain). Hanya kalau kosong baru jatuh ke pos default cabang.
  String get effectiveLokasiStandby {
    final clean = lokasiStandby.trim();
    if (clean.isNotEmpty) return clean.toUpperCase();
    return BranchService.instance.currentBranch.defaultLocationTag;
  }

  /// Jam pulang efektif: jika kosong, ambil jam akhir shift
  String get effectiveJamPulang {
    if (jamPulang.trim().isEmpty) {
      return autoDetectJamPulang(shift: effectiveJadwalShift);
    }
    return jamPulang;
  }

  String get hariKerja {
    const map = [
      'SENIN',
      'SELASA',
      'RABU',
      'KAMIS',
      'JUMAT',
      'SABTU',
      'MINGGU',
    ];
    return map[DateTime.now().weekday - 1];
  }

  String get seragamHariIni {
    switch (hariKerja) {
      case 'SENIN':
        return 'Teknisi / PDH navy';
      case 'SELASA':
        return 'PDH biru navy / Teknisi';
      case 'RABU':
        return 'Seragam Teknisi';
      case 'KAMIS':
        return 'BSS Putih / Teknisi';
      case 'JUMAT':
        return 'Batik / Teknisi';
      case 'SABTU':
        return 'Olahraga biru-kuning / Teknisi';
      case 'MINGGU':
        return 'Bebas rapi / Teknisi';
      default:
        return 'Seragam Teknisi';
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cat = prefs.getString(_kKategori);
      if (cat != null) selectedKategori = AbsensiKategori.fromString(cat);

      final branch = BranchService.instance.currentBranch;
      // Nilai global lama (sebelum kunci per cabang) hanya dipakai kalau tag-nya
      // memang milik cabang aktif, biar tidak bocor lintas cabang.
      final legacyLokasi = prefs.getString(_kLokasi);
      final legacyValid =
          legacyLokasi != null &&
          BranchService.instance
              .getLocationTags(branch: branch)
              .contains(legacyLokasi.trim().toUpperCase());
      final rawLokasi =
          prefs.getString(_kLokasiKey(branch)) ??
          (legacyValid ? legacyLokasi : null);
      // Isian manual teknisi dipakai apa adanya, termasuk pos di luar daftar default.
      if (rawLokasi != null && rawLokasi.trim().isNotEmpty) {
        lokasiStandby = rawLokasi.trim().toUpperCase();
        _branchLocations[branch] = lokasiStandby;
      } else {
        lokasiStandby = branch.defaultLocationTag;
      }

      final rawShift =
          prefs.getString(_kShiftKey(branch)) ?? prefs.getString(_kShift);
      final normalizedShift = rawShift == null
          ? ''
          : _normalizeShiftLabel(rawShift.trim());
      if (normalizedShift.isNotEmpty &&
          !BranchService.isShiftOfOtherBranch(normalizedShift)) {
        jadwalShift = normalizedShift;
        _branchShifts[branch] = jadwalShift;
      } else {
        jadwalShift = autoDetectShift();
      }

      final rawShiftSetAt = prefs.getInt(_kShiftSetAtKey(branch));
      if (rawShiftSetAt != null) {
        _branchShiftSetAt[branch] = DateTime.fromMillisecondsSinceEpoch(
          rawShiftSetAt,
        );
      } else {
        _branchShiftSetAt.remove(branch);
      }
      if (_resetStaleShiftIfNeeded()) _save();

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
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
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
    } catch (e, st) {
      debugPrint('[AbsensiSetup] _load failed: $e');
      debugPrint('$st');
    }
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
      final setAt = _branchShiftSetAt[branch];
      if (setAt == null) {
        await prefs.remove(_kShiftSetAtKey(branch));
      } else {
        await prefs.setInt(
          _kShiftSetAtKey(branch),
          setAt.millisecondsSinceEpoch,
        );
      }
      await prefs.setString(_kTipe, tipeLaporan);
      await prefs.setString(_kJamPulang, effectiveJamPulang);
      await prefs.setString(_kNextShift, shiftSelanjutnya);
      await prefs.setString(_kSelesai, pekerjaanSelesai);
      await prefs.setString(_kBelum, pekerjaanBelum);
      await prefs.setString(_kHandoverDate, handoverDate);
    } catch (e, st) {
      debugPrint('[AbsensiSetup] _save failed: $e');
      debugPrint('$st');
    }
  }

  void updateKategori(AbsensiKategori k) {
    selectedKategori = k;
    final branch = BranchService.instance.currentBranch;
    if (lokasiStandby.trim().isEmpty) {
      lokasiStandby = branch.defaultLocationTag;
    }
    if (jadwalShift.trim().isEmpty ||
        BranchService.isShiftOfOtherBranch(jadwalShift)) {
      jadwalShift = autoDetectShift();
    }
    _save();
    notifyListeners();
  }

  void updateLokasi(String v) {
    final clean = v.trim().toUpperCase();
    final branch = BranchService.instance.currentBranch;
    lokasiStandby = clean.isNotEmpty ? clean : branch.defaultLocationTag;
    _branchLocations[branch] = lokasiStandby;
    _save();
    notifyListeners();
  }

  void updateShift(String v) {
    final clean = v.trim();
    final branch = BranchService.instance.currentBranch;
    jadwalShift =
        (clean.isNotEmpty && !BranchService.isShiftOfOtherBranch(clean))
        ? clean
        : autoDetectShift();
    _branchShifts[branch] = jadwalShift;
    _branchShiftSetAt[branch] =
        SecureTimeService.getVerifiedTime().accurateTime;
    _save();
    notifyListeners();
  }

  /// Dipanggil saat layar kamera dibuka: buang shift basi tanpa mengganggu
  /// sesi yang sedang berjalan atau pilihan manual yang masih baru.
  void resetStaleShift() {
    if (_resetStaleShiftIfNeeded()) {
      _save();
      notifyListeners();
    }
  }

  bool _resetStaleShiftIfNeeded() {
    final branch = BranchService.instance.currentBranch;
    final now = SecureTimeService.getVerifiedTime().accurateTime;
    final shouldReset = shouldResetShift(
      lastCheckIn: StorageService.getLastCheckInTime(),
      shiftSetAt: _branchShiftSetAt[branch],
      now: now,
    );
    if (!shouldReset) return false;
    final detected = autoDetectShift(now);
    if (detected == jadwalShift) return false;
    jadwalShift = detected;
    _branchShifts[branch] = jadwalShift;
    return true;
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
    handoverDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
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
    final todayStr =
        date ??
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
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
    final todayStr =
        targetDate ??
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Tolak jika data berasal dari tanggal kemarin (data basi)
    if (handoverDate.isNotEmpty && handoverDate != todayStr) {
      return false;
    }

    final next = shiftSelanjutnya.trim();
    final selesai = pekerjaanSelesai.trim();

    final hasNext =
        next.isNotEmpty &&
        next != '-' &&
        !next.toLowerCase().contains('tidak ada petugas');

    final hasSelesai =
        selesai.isNotEmpty &&
        selesai != '-' &&
        selesai != '1. -' &&
        selesai.length >= 3;

    return hasNext && hasSelesai;
  }
}
