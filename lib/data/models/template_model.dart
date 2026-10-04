enum TemplateCategory {
  absensi,
  briefing,
  lokasi,
  custom,
  maintPos,
  maintBarrier,
  maintManless,
  maintServer;

  String get displayName {
    switch (this) {
      case TemplateCategory.absensi:
        return 'Absensi';
      case TemplateCategory.briefing:
        return 'Briefing Operasional Shift';
      case TemplateCategory.lokasi:
        return 'Kondisi Pos & Lokasi';
      case TemplateCategory.custom:
        return 'Inspeksi Khusus / Custom';
      case TemplateCategory.maintPos:
        return 'Maintenance Pos Parkir';
      case TemplateCategory.maintBarrier:
        return 'Maintenance Barrier Gate';
      case TemplateCategory.maintManless:
        return 'Maintenance Manless & Pulau';
      case TemplateCategory.maintServer:
        return 'Maintenance PC Server & Kasir';
    }
  }

  static TemplateCategory fromString(String str) {
    final s = str.toLowerCase();
    if (s.contains('maintpos') || s.contains('maint_pos') || s.contains('pos parkir')) return TemplateCategory.maintPos;
    if (s.contains('maintbarrier') || s.contains('barrier')) return TemplateCategory.maintBarrier;
    if (s.contains('maintmanless') || s.contains('manless')) return TemplateCategory.maintManless;
    if (s.contains('maintserver') || s.contains('server')) return TemplateCategory.maintServer;
    switch (s) {
      case 'absensi':
        return TemplateCategory.absensi;
      case 'briefing':
        return TemplateCategory.briefing;
      case 'lokasi':
        return TemplateCategory.lokasi;
      case 'custom':
      default:
        return TemplateCategory.custom;
    }
  }

  bool get isMaintenance =>
      this == TemplateCategory.maintPos ||
      this == TemplateCategory.maintBarrier ||
      this == TemplateCategory.maintManless ||
      this == TemplateCategory.maintServer;
}

enum TemplateRole {
  all,
  teknisi;

  static TemplateRole fromString(String s) {
    switch (s.toLowerCase()) {
      case 'teknisi':
        return TemplateRole.teknisi;
      default:
        return TemplateRole.all;
    }
  }
}

enum AiMode {
  singleFoto,
  perPoint,
  countClassify;

  static AiMode fromString(String s) {
    switch (s.toLowerCase()) {
      case 'perpoint':
      case 'per_point':
        return AiMode.perPoint;
      case 'countclassify':
      case 'count_classify':
      case 'count':
        return AiMode.countClassify;
      default:
        return AiMode.singleFoto;
    }
  }
}

class SopPoint {
  final String id;
  final String label;
  final String deskripsi;
  final List<String> checkpoints;
  final String panduanFoto;
  final bool wajibFoto;
  final String? contohFoto;

  const SopPoint({
    required this.id,
    required this.label,
    this.deskripsi = '',
    this.checkpoints = const [],
    this.panduanFoto = '',
    this.wajibFoto = true,
    this.contohFoto,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'deskripsi': deskripsi,
        'checkpoints': checkpoints,
        'panduanFoto': panduanFoto,
        'wajibFoto': wajibFoto,
        'contohFoto': contohFoto,
      };

  factory SopPoint.fromJson(Map<String, dynamic> j) => SopPoint(
        id: j['id'] as String,
        label: j['label'] as String,
        deskripsi: j['deskripsi'] as String? ?? '',
        checkpoints: (j['checkpoints'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        panduanFoto: j['panduanFoto'] as String? ?? '',
        wajibFoto: j['wajibFoto'] as bool? ?? true,
        contohFoto: j['contohFoto'] as String?,
      );
}

class TemplateModel {
  final String id;
  final String nama;
  final String deskripsi;
  final TemplateCategory jenis;
  final bool wajibLokasi;
  final List<String> sopCriteria;
  final List<SopPoint> sopPoints;
  final TemplateRole requiredRole;
  final AiMode aiMode;
  final List<String> contohFotoDescriptions;
  final String createdBy;
  final DateTime updatedAt;

  bool get isPerPoint => aiMode == AiMode.perPoint || jenis.isMaintenance;
  bool get requiresTechnician => requiredRole == TemplateRole.teknisi;

  TemplateModel({
    required this.id,
    required this.nama,
    required this.deskripsi,
    required this.jenis,
    this.wajibLokasi = true,
    this.sopCriteria = const [],
    this.sopPoints = const [],
    this.requiredRole = TemplateRole.all,
    this.aiMode = AiMode.singleFoto,
    this.contohFotoDescriptions = const [],
    required this.createdBy,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'nama': nama,
    'deskripsi': deskripsi,
    'jenis': jenis.name,
    'wajibLokasi': wajibLokasi,
    'sopCriteria': sopCriteria,
    'sopPoints': sopPoints.map((e) => e.toJson()).toList(),
    'requiredRole': requiredRole.name,
    'aiMode': aiMode.name,
    'contohFotoDescriptions': contohFotoDescriptions,
    'createdBy': createdBy,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory TemplateModel.fromJson(Map<String, dynamic> json) => TemplateModel(
    id: json['id'] as String,
    nama: json['nama'] as String,
    deskripsi: json['deskripsi'] as String? ?? '',
    jenis: TemplateCategory.fromString(json['jenis'] as String? ?? 'custom'),
    wajibLokasi: json['wajibLokasi'] as bool? ?? true,
    sopCriteria: (json['sopCriteria'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [],
    sopPoints: (json['sopPoints'] as List<dynamic>?)
            ?.map((e) => SopPoint.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    requiredRole: TemplateRole.fromString(json['requiredRole'] as String? ?? 'all'),
    aiMode: AiMode.fromString(json['aiMode'] as String? ?? 'singleFoto'),
    contohFotoDescriptions: (json['contohFotoDescriptions'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [],
    createdBy: json['createdBy'] as String? ?? 'System',
    updatedAt: json['updatedAt'] != null
        ? DateTime.parse(json['updatedAt'] as String)
        : DateTime.now(),
  );

  TemplateModel copyWith({
    String? id,
    String? nama,
    String? deskripsi,
    TemplateCategory? jenis,
    bool? wajibLokasi,
    List<String>? sopCriteria,
    List<SopPoint>? sopPoints,
    TemplateRole? requiredRole,
    AiMode? aiMode,
    List<String>? contohFotoDescriptions,
    String? createdBy,
    DateTime? updatedAt,
  }) {
    return TemplateModel(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      deskripsi: deskripsi ?? this.deskripsi,
      jenis: jenis ?? this.jenis,
      wajibLokasi: wajibLokasi ?? this.wajibLokasi,
      sopCriteria: sopCriteria ?? this.sopCriteria,
      sopPoints: sopPoints ?? this.sopPoints,
      requiredRole: requiredRole ?? this.requiredRole,
      aiMode: aiMode ?? this.aiMode,
      contohFotoDescriptions:
          contohFotoDescriptions ?? this.contohFotoDescriptions,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
