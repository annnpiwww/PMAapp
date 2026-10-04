enum AbsensiKategori {
  teknisi,
  admin,
  leader,
  sppMerah,
  sppHijauAbu;

  String get displayName {
    switch (this) {
      case AbsensiKategori.teknisi:
        return 'Teknisi';
      case AbsensiKategori.admin:
        return 'Admin';
      case AbsensiKategori.leader:
        return 'Leader';
      case AbsensiKategori.sppMerah:
        return 'SPP/SPL Merah';
      case AbsensiKategori.sppHijauAbu:
        return 'SPP/SPL Hijau-Abu';
    }
  }

  static AbsensiKategori fromString(String? s) {
    if (s == null) return AbsensiKategori.teknisi;
    switch (s.toLowerCase()) {
      case 'admin':
        return AbsensiKategori.admin;
      case 'leader':
        return AbsensiKategori.leader;
      case 'spp_merah':
      case 'sppmerah':
      case 'spp/spl merah':
      case 'merah':
        return AbsensiKategori.sppMerah;
      case 'spp_hijau_abu':
      case 'spphijauabu':
      case 'spp/spl hijau-abu':
      case 'hijau':
        return AbsensiKategori.sppHijauAbu;
      case 'teknisi':
      default:
        return AbsensiKategori.teknisi;
    }
  }
}

enum VerificationStatus {
  sesuai,
  tidakSesuai,
  perluCekManual;

  String get label {
    switch (this) {
      case VerificationStatus.sesuai:
        return 'Sesuai SOP';
      case VerificationStatus.tidakSesuai:
        return 'Ditolak (Tidak Sesuai SOP)';
      case VerificationStatus.perluCekManual:
        return 'Perlu Cek Manual';
    }
  }

  static VerificationStatus fromString(String str) {
    switch (str.toLowerCase()) {
      case 'sesuai':
        return VerificationStatus.sesuai;
      case 'tidak_sesuai':
      case 'tidaksesuai':
        return VerificationStatus.tidakSesuai;
      case 'perlu_cek_manual':
      case 'perlucekmanual':
      default:
        return VerificationStatus.perluCekManual;
    }
  }
}

class SubmissionModel {
  final String id;
  final String templateId;
  final String templateName;
  final String userId;
  final String userName;
  final String userNpp;
  final String posId;
  final String posName;
  final String cabangName;
  final String? imageBase64;
  final String? imagePath;
  final DateTime timestampCapture;
  final String timezone;
  final double? lat;
  final double? lng;
  final double? akurasiMeter;
  final String kodeVerifikasi;
  final VerificationStatus status;
  final String alasanAI;
  final List<String> poinGagal;
  final List<String> poinLolos;
  final bool isOfflineQueue;
  final String? overrideNote;
  final String? overriddenBy;
  final DateTime createdAt;
  // Absensi kategori & teknisi jadwal
  final AbsensiKategori? absensiKategori;
  final String? hariKerja; // SENIN..MINGGU
  final String? lokasiStandby; // PBM etc.
  final String? jadwalShift; // S2 (10:00 - 14:00)
  final String? tipeLaporan; // Masuk / Pulang
  final String? jamPulang; // 11:00
  final String? shiftSelanjutnya; // IT Support Shift Selanjutnya
  final String? pekerjaanSelesai; // List Pekerjaan yang Selesai (multiline)
  final String? pekerjaanBelum; // List Pekerjaan yang Belum Selesai

  SubmissionModel({
    required this.id,
    required this.templateId,
    required this.templateName,
    required this.userId,
    required this.userName,
    required this.userNpp,
    required this.posId,
    required this.posName,
    required this.cabangName,
    this.imageBase64,
    this.imagePath,
    required this.timestampCapture,
    this.timezone = 'WIB',
    this.lat,
    this.lng,
    this.akurasiMeter,
    required this.kodeVerifikasi,
    required this.status,
    required this.alasanAI,
    this.poinGagal = const [],
    this.poinLolos = const [],
    this.isOfflineQueue = false,
    this.overrideNote,
    this.overriddenBy,
    required this.createdAt,
    this.absensiKategori,
    this.hariKerja,
    this.lokasiStandby,
    this.jadwalShift,
    this.tipeLaporan,
    this.jamPulang,
    this.shiftSelanjutnya,
    this.pekerjaanSelesai,
    this.pekerjaanBelum,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'templateId': templateId,
    'templateName': templateName,
    'userId': userId,
    'userName': userName,
    'userNpp': userNpp,
    'posId': posId,
    'posName': posName,
    'cabangName': cabangName,
    // imageBase64 SENGAJA tidak disimpan: hanya untuk upload AI di memori.
    // Menyimpan base64 foto di SharedPreferences bikin storage bengkak.
    'imagePath': imagePath,
    'timestampCapture': timestampCapture.toIso8601String(),
    'timezone': timezone,
    'lat': lat,
    'lng': lng,
    'akurasiMeter': akurasiMeter,
    'kodeVerifikasi': kodeVerifikasi,
    'status': status.name,
    'alasanAI': alasanAI,
    'poinGagal': poinGagal,
    'poinLolos': poinLolos,
    'isOfflineQueue': isOfflineQueue,
    'overrideNote': overrideNote,
    'overriddenBy': overriddenBy,
    'createdAt': createdAt.toIso8601String(),
    'absensiKategori': absensiKategori?.name,
    'hariKerja': hariKerja,
    'lokasiStandby': lokasiStandby,
    'jadwalShift': jadwalShift,
    'tipeLaporan': tipeLaporan,
    'jamPulang': jamPulang,
    'shiftSelanjutnya': shiftSelanjutnya,
    'pekerjaanSelesai': pekerjaanSelesai,
    'pekerjaanBelum': pekerjaanBelum,
  };

  factory SubmissionModel.fromJson(Map<String, dynamic> json) =>
      SubmissionModel(
        id: json['id'] as String,
        templateId: json['templateId'] as String,
        templateName: json['templateName'] as String? ?? 'Absensi',
        userId: json['userId'] as String,
        userName: json['userName'] as String? ?? 'Petugas BSS',
        userNpp: json['userNpp'] as String? ?? 'BSS-001',
        posId: json['posId'] as String? ?? 'POS-01',
        posName: json['posName'] as String? ?? 'Pos Gate Utama',
        cabangName: json['cabangName'] as String? ?? 'BSS Manado Megamas',
        imageBase64: json['imageBase64'] as String?,
        imagePath: json['imagePath'] as String?,
        timestampCapture: DateTime.parse(json['timestampCapture'] as String),
        timezone: json['timezone'] as String? ?? 'WIB',
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        akurasiMeter: (json['akurasiMeter'] as num?)?.toDouble(),
        kodeVerifikasi: json['kodeVerifikasi'] as String,
        status: VerificationStatus.fromString(
          json['status'] as String? ?? 'sesuai',
        ),
        alasanAI: json['alasanAI'] as String? ?? '',
        poinGagal:
            (json['poinGagal'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        poinLolos:
            (json['poinLolos'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        isOfflineQueue: json['isOfflineQueue'] as bool? ?? false,
        overrideNote: json['overrideNote'] as String?,
        overriddenBy: json['overriddenBy'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        absensiKategori: json['absensiKategori'] != null
            ? AbsensiKategori.fromString(json['absensiKategori'] as String)
            : null,
        hariKerja: json['hariKerja'] as String?,
        lokasiStandby: json['lokasiStandby'] as String?,
        jadwalShift: json['jadwalShift'] as String?,
        tipeLaporan: json['tipeLaporan'] as String?,
        jamPulang: json['jamPulang'] as String?,
        shiftSelanjutnya: json['shiftSelanjutnya'] as String?,
        pekerjaanSelesai: json['pekerjaanSelesai'] as String?,
        pekerjaanBelum: json['pekerjaanBelum'] as String?,
      );

  SubmissionModel copyWith({
    String? id,
    String? templateId,
    String? templateName,
    String? userId,
    String? userName,
    String? userNpp,
    String? posId,
    String? posName,
    String? cabangName,
    String? imageBase64,
    String? imagePath,
    DateTime? timestampCapture,
    String? timezone,
    double? lat,
    double? lng,
    double? akurasiMeter,
    String? kodeVerifikasi,
    VerificationStatus? status,
    String? alasanAI,
    List<String>? poinGagal,
    List<String>? poinLolos,
    bool? isOfflineQueue,
    String? overrideNote,
    String? overriddenBy,
    DateTime? createdAt,
    AbsensiKategori? absensiKategori,
    String? hariKerja,
    String? lokasiStandby,
    String? jadwalShift,
    String? tipeLaporan,
    String? jamPulang,
    String? shiftSelanjutnya,
    String? pekerjaanSelesai,
    String? pekerjaanBelum,
  }) {
    return SubmissionModel(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      templateName: templateName ?? this.templateName,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userNpp: userNpp ?? this.userNpp,
      posId: posId ?? this.posId,
      posName: posName ?? this.posName,
      cabangName: cabangName ?? this.cabangName,
      imageBase64: imageBase64 ?? this.imageBase64,
      imagePath: imagePath ?? this.imagePath,
      timestampCapture: timestampCapture ?? this.timestampCapture,
      timezone: timezone ?? this.timezone,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      akurasiMeter: akurasiMeter ?? this.akurasiMeter,
      kodeVerifikasi: kodeVerifikasi ?? this.kodeVerifikasi,
      status: status ?? this.status,
      alasanAI: alasanAI ?? this.alasanAI,
      poinGagal: poinGagal ?? this.poinGagal,
      poinLolos: poinLolos ?? this.poinLolos,
      isOfflineQueue: isOfflineQueue ?? this.isOfflineQueue,
      overrideNote: overrideNote ?? this.overrideNote,
      overriddenBy: overriddenBy ?? this.overriddenBy,
      createdAt: createdAt ?? this.createdAt,
      absensiKategori: absensiKategori ?? this.absensiKategori,
      hariKerja: hariKerja ?? this.hariKerja,
      lokasiStandby: lokasiStandby ?? this.lokasiStandby,
      jadwalShift: jadwalShift ?? this.jadwalShift,
      tipeLaporan: tipeLaporan ?? this.tipeLaporan,
      jamPulang: jamPulang ?? this.jamPulang,
      shiftSelanjutnya: shiftSelanjutnya ?? this.shiftSelanjutnya,
      pekerjaanSelesai: pekerjaanSelesai ?? this.pekerjaanSelesai,
      pekerjaanBelum: pekerjaanBelum ?? this.pekerjaanBelum,
    );
  }
}
