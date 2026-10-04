import 'submission_model.dart';

enum PointStatus {
  belumFoto,
  sesuai,
  tidakSesuai,
  perluCekManual;

  String get label {
    switch (this) {
      case PointStatus.belumFoto:
        return 'Belum Foto';
      case PointStatus.sesuai:
        return 'Sesuai';
      case PointStatus.tidakSesuai:
        return 'Tidak Sesuai';
      case PointStatus.perluCekManual:
        return 'Perlu Cek Manual';
    }
  }

  static PointStatus fromString(String s) {
    switch (s.toLowerCase().trim()) {
      case 'sesuai':
        return PointStatus.sesuai;
      case 'tidaksesuai':
      case 'tidak_sesuai':
      case 'tidak sesuai':
        return PointStatus.tidakSesuai;
      case 'perlucekmanual':
      case 'perlu_cek_manual':
      case 'perlu cek manual':
        return PointStatus.perluCekManual;
      case 'belumfoto':
      case 'belum_foto':
      case 'belum foto':
      default:
        return PointStatus.belumFoto;
    }
  }

  VerificationStatus toVerification() {
    switch (this) {
      case PointStatus.sesuai:
        return VerificationStatus.sesuai;
      case PointStatus.tidakSesuai:
        return VerificationStatus.tidakSesuai;
      default:
        return VerificationStatus.perluCekManual;
    }
  }
}

class MaintenancePointResult {
  final String pointId;
  final String label;
  final String? imageBase64;
  final String? imagePath;
  final DateTime? timestamp;
  final double? lat;
  final double? lng;
  final PointStatus status;
  final String alasan;
  final double confidence;
  final String providerName;

  const MaintenancePointResult({
    required this.pointId,
    required this.label,
    this.imageBase64,
    this.imagePath,
    this.timestamp,
    this.lat,
    this.lng,
    this.status = PointStatus.belumFoto,
    this.alasan = '',
    this.confidence = 0,
    this.providerName = '',
  });

  bool get isDone => status != PointStatus.belumFoto;
  bool get isSesuai => status == PointStatus.sesuai;

  Map<String, dynamic> toJson() => {
        'pointId': pointId,
        'label': label,
        // imageBase64 sengaja tidak disimpan ke SharedPreferences agar storage super enteng
        'imagePath': imagePath,
        'timestamp': timestamp?.toIso8601String(),
        'lat': lat,
        'lng': lng,
        'status': status.name,
        'alasan': alasan,
        'confidence': confidence,
        'providerName': providerName,
      };

  factory MaintenancePointResult.fromJson(Map<String, dynamic> j) =>
      MaintenancePointResult(
        pointId: j['pointId'] as String,
        label: j['label'] as String,
        imageBase64: j['imageBase64'] as String?,
        imagePath: j['imagePath'] as String?,
        timestamp: j['timestamp'] != null ? DateTime.parse(j['timestamp'] as String) : null,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        status: PointStatus.fromString(j['status'] as String? ?? 'belumFoto'),
        alasan: j['alasan'] as String? ?? '',
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
        providerName: j['providerName'] as String? ?? '',
      );

  MaintenancePointResult copyWith({
    String? imageBase64,
    String? imagePath,
    DateTime? timestamp,
    double? lat,
    double? lng,
    PointStatus? status,
    String? alasan,
    double? confidence,
    String? providerName,
  }) {
    return MaintenancePointResult(
      pointId: pointId,
      label: label,
      imageBase64: imageBase64 ?? this.imageBase64,
      imagePath: imagePath ?? this.imagePath,
      timestamp: timestamp ?? this.timestamp,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      status: status ?? this.status,
      alasan: alasan ?? this.alasan,
      confidence: confidence ?? this.confidence,
      providerName: providerName ?? this.providerName,
    );
  }
}

class MaintenanceSubmission {
  final String id;
  final String templateId;
  final String templateName;
  final String userId;
  final String userName;
  final String userNpp;
  final String posId;
  final String posName;
  final String cabangName;
  final List<MaintenancePointResult> points;
  final DateTime createdAt;
  final DateTime updatedAt;

  MaintenanceSubmission({
    required this.id,
    required this.templateId,
    required this.templateName,
    required this.userId,
    required this.userName,
    required this.userNpp,
    required this.posId,
    required this.posName,
    required this.cabangName,
    required this.points,
    required this.createdAt,
    required this.updatedAt,
  });
  DateTime get timestamp => createdAt;

  int get totalPoints => points.length;
  int get doneCount => points.where((p) => p.isDone).length;
  int get sesuaiCount => points.where((p) => p.status == PointStatus.sesuai).length;
  double get progress => totalPoints == 0 ? 0 : doneCount / totalPoints;
  bool get isComplete => doneCount == totalPoints;
  bool get isAllSesuai => points.every((p) => p.status == PointStatus.sesuai);
  VerificationStatus get overallStatus {
    if (!isComplete) return VerificationStatus.perluCekManual;
    if (isAllSesuai) return VerificationStatus.sesuai;
    if (points.any((p) => p.status == PointStatus.tidakSesuai)) return VerificationStatus.tidakSesuai;
    return VerificationStatus.perluCekManual;
  }

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
        'points': points.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory MaintenanceSubmission.fromJson(Map<String, dynamic> j) => MaintenanceSubmission(
        id: j['id'] as String,
        templateId: j['templateId'] as String,
        templateName: j['templateName'] as String? ?? '',
        userId: j['userId'] as String,
        userName: j['userName'] as String? ?? '',
        userNpp: j['userNpp'] as String? ?? '',
        posId: j['posId'] as String? ?? '',
        posName: j['posName'] as String? ?? '',
        cabangName: j['cabangName'] as String? ?? '',
        points: (j['points'] as List<dynamic>?)?.map((e) => MaintenancePointResult.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}
