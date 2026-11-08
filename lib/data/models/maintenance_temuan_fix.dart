import 'dart:convert';

/// Model pencatatan perbaikan temuan (insert-only).
class MaintenanceTemuanFix {
  final String id;
  final String logId;
  final String temuanLabel;
  final String posId;
  final String posName;
  final String branch;
  final String teknisiNama;
  final String? teknisiNpp;
  final String catatan;
  final List<String> photoUrls;
  final DateTime fixedAt;
  final bool pendingSync;

  const MaintenanceTemuanFix({
    required this.id,
    required this.logId,
    required this.temuanLabel,
    required this.posId,
    this.posName = '',
    this.branch = 'MDO',
    required this.teknisiNama,
    this.teknisiNpp,
    required this.catatan,
    this.photoUrls = const [],
    required this.fixedAt,
    this.pendingSync = false,
  });

  /// Identifier unik komposit untuk memetakan perbaikan ke temuan di log
  String get key => '$logId|$temuanLabel';

  factory MaintenanceTemuanFix.fromJson(
    Map<String, dynamic> json, {
    bool pendingSync = false,
  }) {
    final rawPhotos = json['photo_urls'];
    final urls = <String>[];
    if (rawPhotos is List) {
      urls.addAll(rawPhotos.map((e) => e.toString()));
    } else if (rawPhotos is String) {
      try {
        final decoded = jsonDecode(rawPhotos);
        if (decoded is List) {
          urls.addAll(decoded.map((e) => e.toString()));
        }
      } catch (_) {}
    }

    final rawFixedAt = json['fixed_at'] as String?;
    final dt = rawFixedAt != null
        ? DateTime.tryParse(rawFixedAt)?.toLocal()
        : null;

    return MaintenanceTemuanFix(
      id: json['id'] as String? ?? '',
      logId: json['log_id'] as String? ?? '',
      temuanLabel: json['temuan_label'] as String? ?? '',
      posId: json['pos_id'] as String? ?? '',
      posName: json['pos_name'] as String? ?? '',
      branch: json['branch'] as String? ?? 'MDO',
      teknisiNama: json['teknisi_nama'] as String? ?? '',
      teknisiNpp: json['teknisi_npp'] as String?,
      catatan: json['catatan'] as String? ?? '',
      photoUrls: urls,
      fixedAt: dt ?? DateTime.now(),
      pendingSync: pendingSync,
    );
  }

  Map<String, dynamic> toRow() => {
    'id': id,
    'log_id': logId,
    'temuan_label': temuanLabel,
    'pos_id': posId,
    'pos_name': posName,
    'branch': branch,
    'teknisi_nama': teknisiNama,
    if (teknisiNpp != null && teknisiNpp!.isNotEmpty) 'teknisi_npp': teknisiNpp,
    'catatan': catatan,
    'photo_urls': photoUrls,
    'fixed_at': fixedAt.toUtc().toIso8601String(),
  };

  Map<String, dynamic> toLocalJson() => {
    'id': id,
    'logId': logId,
    'temuanLabel': temuanLabel,
    'posId': posId,
    'posName': posName,
    'branch': branch,
    'teknisiNama': teknisiNama,
    'teknisiNpp': teknisiNpp,
    'catatan': catatan,
    'photoUrls': photoUrls,
    'fixedAt': fixedAt.toIso8601String(),
    'pendingSync': pendingSync,
  };

  factory MaintenanceTemuanFix.fromLocalJson(Map<String, dynamic> json) {
    final rawPhotos = json['photoUrls'] ?? json['photo_urls'];
    final urls = <String>[];
    if (rawPhotos is List) {
      urls.addAll(rawPhotos.map((e) => e.toString()));
    } else if (rawPhotos is String) {
      try {
        final decoded = jsonDecode(rawPhotos);
        if (decoded is List) {
          urls.addAll(decoded.map((e) => e.toString()));
        }
      } catch (_) {}
    }

    final rawFixedAt = json['fixedAt'] ?? json['fixed_at'];
    final dt = rawFixedAt != null
        ? DateTime.tryParse(rawFixedAt.toString())?.toLocal()
        : null;

    return MaintenanceTemuanFix(
      id: json['id'] as String? ?? '',
      logId: (json['logId'] ?? json['log_id']) as String? ?? '',
      temuanLabel:
          (json['temuanLabel'] ?? json['temuan_label']) as String? ?? '',
      posId: (json['posId'] ?? json['pos_id']) as String? ?? '',
      posName: (json['posName'] ?? json['pos_name']) as String? ?? '',
      branch: (json['branch'] as String?) ?? 'MDO',
      teknisiNama:
          (json['teknisiNama'] ?? json['teknisi_nama']) as String? ?? '',
      teknisiNpp: (json['teknisiNpp'] ?? json['teknisi_npp']) as String?,
      catatan: json['catatan'] as String? ?? '',
      photoUrls: urls,
      fixedAt: dt ?? DateTime.now(),
      pendingSync: (json['pendingSync'] as bool?) ?? true,
    );
  }

  MaintenanceTemuanFix copyWith({
    String? id,
    String? logId,
    String? temuanLabel,
    String? posId,
    String? posName,
    String? branch,
    String? teknisiNama,
    String? teknisiNpp,
    String? catatan,
    List<String>? photoUrls,
    DateTime? fixedAt,
    bool? pendingSync,
  }) {
    return MaintenanceTemuanFix(
      id: id ?? this.id,
      logId: logId ?? this.logId,
      temuanLabel: temuanLabel ?? this.temuanLabel,
      posId: posId ?? this.posId,
      posName: posName ?? this.posName,
      branch: branch ?? this.branch,
      teknisiNama: teknisiNama ?? this.teknisiNama,
      teknisiNpp: teknisiNpp ?? this.teknisiNpp,
      catatan: catatan ?? this.catatan,
      photoUrls: photoUrls ?? this.photoUrls,
      fixedAt: fixedAt ?? this.fixedAt,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }
}
