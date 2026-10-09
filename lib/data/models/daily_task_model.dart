enum TaskStatus {
  pending,
  inProgress,
  completed;

  String get displayName {
    switch (this) {
      case TaskStatus.pending:
        return 'Belum Dikerjakan';
      case TaskStatus.inProgress:
        return 'Sedang Dikerjakan';
      case TaskStatus.completed:
        return 'Selesai';
    }
  }

  static TaskStatus fromString(String val) {
    switch (val.toLowerCase().trim()) {
      case 'completed':
      case 'selesai':
      case 'done':
      case 'finish':
      case 'finished':
      case 'sukses':
      case 'closed':
        return TaskStatus.completed;
      case 'in_progress':
      case 'proses':
      case 'ongoing':
        return TaskStatus.inProgress;
      case 'pending':
      default:
        return TaskStatus.pending;
    }
  }
}

class DailyTaskModel {
  final String id;
  final String tanggal; // YYYY-MM-DD
  final String teknisiId;
  final String teknisiNama;
  final String posName;
  final String posTag;
  final String judul;
  final String deskripsi;
  final String kategori; // maintenance / khusus
  final String? templateId;
  final TaskStatus status;
  final String? jamSelesai;
  final List<String> fotoBuktiUrls;
  final String? catatanTeknisi;

  DailyTaskModel({
    required this.id,
    required this.tanggal,
    required this.teknisiId,
    required this.teknisiNama,
    required this.posName,
    required this.posTag,
    required this.judul,
    this.deskripsi = '',
    this.kategori = 'khusus',
    this.templateId,
    this.status = TaskStatus.pending,
    this.jamSelesai,
    this.fotoBuktiUrls = const [],
    this.catatanTeknisi,
  });

  bool get isCompleted => status == TaskStatus.completed;
  bool get isMaintenance => kategori == 'maintenance';

  DailyTaskModel copyWith({
    String? id,
    String? tanggal,
    String? teknisiId,
    String? teknisiNama,
    String? posName,
    String? posTag,
    String? judul,
    String? deskripsi,
    String? kategori,
    String? templateId,
    TaskStatus? status,
    String? jamSelesai,
    List<String>? fotoBuktiUrls,
    String? catatanTeknisi,
  }) {
    return DailyTaskModel(
      id: id ?? this.id,
      tanggal: tanggal ?? this.tanggal,
      teknisiId: teknisiId ?? this.teknisiId,
      teknisiNama: teknisiNama ?? this.teknisiNama,
      posName: posName ?? this.posName,
      posTag: posTag ?? this.posTag,
      judul: judul ?? this.judul,
      deskripsi: deskripsi ?? this.deskripsi,
      kategori: kategori ?? this.kategori,
      templateId: templateId ?? this.templateId,
      status: status ?? this.status,
      jamSelesai: jamSelesai ?? this.jamSelesai,
      fotoBuktiUrls: fotoBuktiUrls ?? this.fotoBuktiUrls,
      catatanTeknisi: catatanTeknisi ?? this.catatanTeknisi,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tanggal': tanggal,
    'teknisi_id': teknisiId,
    'teknisi_nama': teknisiNama,
    'pos_name': posName,
    'pos_tag': posTag,
    'judul': judul,
    'deskripsi': deskripsi,
    'kategori': kategori,
    'template_id': templateId,
    'status': status.name,
    'jam_selesai': jamSelesai,
    'foto_bukti': fotoBuktiUrls,
    'catatan_teknisi': catatanTeknisi,
  };

  factory DailyTaskModel.fromJson(Map<String, dynamic> json) {
    List<String> photos = [];
    if (json['foto_bukti'] != null) {
      if (json['foto_bukti'] is List) {
        photos = (json['foto_bukti'] as List).map((e) => e.toString()).toList();
      } else if (json['foto_bukti'] is String && (json['foto_bukti'] as String).isNotEmpty) {
        photos = [json['foto_bukti'] as String];
      }
    }

    return DailyTaskModel(
      id: json['id'] as String? ?? '',
      tanggal: json['tanggal'] as String? ?? '',
      teknisiId: json['teknisi_id'] as String? ?? '',
      teknisiNama: json['teknisi_nama'] as String? ?? '',
      posName: json['pos_name'] as String? ?? '',
      posTag: json['pos_tag'] as String? ?? '',
      judul: json['judul'] as String? ?? '',
      deskripsi: json['deskripsi'] as String? ?? '',
      kategori: json['kategori'] as String? ?? 'khusus',
      templateId: json['template_id'] as String?,
      status: TaskStatus.fromString(json['status'] as String? ?? 'pending'),
      jamSelesai: json['jam_selesai'] as String?,
      fotoBuktiUrls: photos,
      catatanTeknisi: json['catatan_teknisi'] as String?,
    );
  }
}
