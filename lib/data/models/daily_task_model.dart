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

/// Satu baris log serah terima tugas antar shift.
/// Disimpan di kolom `serah_terima` dengan pemisah `|`, antar entri dipisah newline.
class TaskHandover {
  final String dari; // teknisi yang menyerahkan
  final String ke; // '' = terbuka untuk siapa pun
  final String alasan;
  final String waktu; // '18 Okt 21:10'

  const TaskHandover({
    required this.dari,
    required this.ke,
    required this.alasan,
    required this.waktu,
  });

  bool get isOpen => ke.trim().isEmpty;

  /// Alasan tidak boleh memuat '|' atau newline, karena itu pemisah baris log.
  String toLine() => '$dari|$ke|$alasan|$waktu';

  static TaskHandover? tryParse(String line) {
    final parts = line.split('|');
    if (parts.length < 4) return null;
    return TaskHandover(
      dari: parts[0].trim(),
      ke: parts[1].trim(),
      alasan: parts[2].trim(),
      waktu: parts.sublist(3).join('|').trim(),
    );
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

  /// Pelaksana tambahan (tugas dikerjakan bareng), dipisah koma.
  final String peserta;

  /// Log serah terima antar shift (baris-baris `TaskHandover`).
  final String serahTerima;

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
    this.peserta = '',
    this.serahTerima = '',
  });

  bool get isCompleted => status == TaskStatus.completed;
  bool get isMaintenance => kategori == 'maintenance';

  /// Nama pelaksana tambahan (tanpa pemilik).
  List<String> get pesertaList => peserta
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  /// Tugas dikerjakan lebih dari satu orang.
  bool get isShared => pesertaList.isNotEmpty;

  /// Tugas hasil serah terima shift sebelumnya.
  bool get isHandover => handoverList.isNotEmpty;

  /// Serah terima yang belum ada penerusnya: siapa pun boleh ambil.
  bool get isOpenHandover =>
      !isCompleted && handoverList.isNotEmpty && handoverList.last.isOpen;

  List<TaskHandover> get handoverList => serahTerima
      .split('\n')
      .map((l) => TaskHandover.tryParse(l))
      .whereType<TaskHandover>()
      .toList();

  /// Teknisi yang menyerahkan tugas ini (untuk badge "Lanjutan dari X").
  String? get handoverDari {
    final list = handoverList;
    return list.isEmpty ? null : list.last.dari;
  }

  /// Label pelaksana untuk laporan, mis. `Andi + Budi`.
  String get labelPelaksana => isShared
      ? '$teknisiNama + ${pesertaList.join(' + ')}'
      : teknisiNama;

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
    String? peserta,
    String? serahTerima,
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
      peserta: peserta ?? this.peserta,
      serahTerima: serahTerima ?? this.serahTerima,
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
    'peserta': peserta,
    'serah_terima': serahTerima,
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
      peserta: json['peserta'] as String? ?? '',
      serahTerima: json['serah_terima'] as String? ?? '',
    );
  }
}
