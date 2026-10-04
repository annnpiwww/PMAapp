enum AttendanceType {
  masuk,
  pulang;

  String get displayName => this == AttendanceType.masuk ? 'Masuk' : 'Pulang';

  static AttendanceType fromString(String? val) {
    if (val == null) return AttendanceType.masuk;
    switch (val.toLowerCase().trim()) {
      case 'pulang':
        return AttendanceType.pulang;
      case 'masuk':
      default:
        return AttendanceType.masuk;
    }
  }
}

class AttendanceRecord {
  final String id;
  final DateTime timestamp;
  final AttendanceType type;
  final String shiftName;
  final String technicianName;
  final String posName;
  final double lat;
  final double lng;
  final String fullAddress;
  final String? photoPath;
  final String? workDuration;
  final bool isAiVerified;
  final String aiStatusText;

  AttendanceRecord({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.shiftName,
    required this.technicianName,
    required this.posName,
    required this.lat,
    required this.lng,
    required this.fullAddress,
    this.photoPath,
    this.workDuration,
    this.isAiVerified = true,
    this.aiStatusText = 'SESUAI SOP',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'shiftName': shiftName,
      'technicianName': technicianName,
      'posName': posName,
      'lat': lat,
      'lng': lng,
      'fullAddress': fullAddress,
      'photoPath': photoPath,
      'workDuration': workDuration,
      'isAiVerified': isAiVerified,
      'aiStatusText': aiStatusText,
    };
  }

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? (DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now())
          : DateTime.now(),
      type: AttendanceType.fromString(json['type'] as String?),
      shiftName: json['shiftName'] as String? ?? '',
      technicianName: json['technicianName'] as String? ?? '',
      posName: json['posName'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      fullAddress: json['fullAddress'] as String? ?? '',
      photoPath: json['photoPath'] as String?,
      workDuration: json['workDuration'] as String?,
      isAiVerified: json['isAiVerified'] as bool? ?? true,
      aiStatusText: json['aiStatusText'] as String? ?? 'SESUAI SOP',
    );
  }

  AttendanceRecord copyWith({
    String? id,
    DateTime? timestamp,
    AttendanceType? type,
    String? shiftName,
    String? technicianName,
    String? posName,
    double? lat,
    double? lng,
    String? fullAddress,
    String? photoPath,
    String? workDuration,
    bool? isAiVerified,
    String? aiStatusText,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      shiftName: shiftName ?? this.shiftName,
      technicianName: technicianName ?? this.technicianName,
      posName: posName ?? this.posName,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      fullAddress: fullAddress ?? this.fullAddress,
      photoPath: photoPath ?? this.photoPath,
      workDuration: workDuration ?? this.workDuration,
      isAiVerified: isAiVerified ?? this.isAiVerified,
      aiStatusText: aiStatusText ?? this.aiStatusText,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceRecord &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
