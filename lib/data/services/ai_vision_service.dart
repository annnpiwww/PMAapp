import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/ai_vision_config.dart';
import '../models/submission_model.dart';
import '../models/template_model.dart';
import '../repositories/auth_repository.dart';
import 'storage_service.dart';
import 'daily_task_service.dart';

class AiVerificationResult {
  final VerificationStatus status;
  final String alasan;
  final List<String> poinGagal;
  final List<String> poinLolos;
  final double confidenceScore;
  final String providerName;
  final bool isFallback;
  final int? personCount;
  final String? briefingKategori;

  AiVerificationResult({
    required this.status,
    required this.alasan,
    required this.poinGagal,
    required this.poinLolos,
    required this.confidenceScore,
    required this.providerName,
    this.isFallback = false,
    this.personCount,
    this.briefingKategori,
  });

  AiVerificationResult copyWith({
    VerificationStatus? status,
    String? alasan,
    List<String>? poinGagal,
    List<String>? poinLolos,
    double? confidenceScore,
    String? providerName,
    bool? isFallback,
    int? personCount,
    String? briefingKategori,
  }) {
    return AiVerificationResult(
      status: status ?? this.status,
      alasan: alasan ?? this.alasan,
      poinGagal: poinGagal ?? this.poinGagal,
      poinLolos: poinLolos ?? this.poinLolos,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      providerName: providerName ?? this.providerName,
      isFallback: isFallback ?? this.isFallback,
      personCount: personCount ?? this.personCount,
      briefingKategori: briefingKategori ?? this.briefingKategori,
    );
  }

  bool get isApproved => status == VerificationStatus.sesuai;
  bool get isSesuai => status == VerificationStatus.sesuai;

  String get statusDisplay {
    switch (status) {
      case VerificationStatus.sesuai:
        return 'SESUAI SOP';
      case VerificationStatus.tidakSesuai:
        return 'TIDAK SESUAI';
      case VerificationStatus.perluCekManual:
        return 'PERLU CEK MANUAL';
    }
  }

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'alasan': alasan,
        'poinGagal': poinGagal,
        'poinLolos': poinLolos,
        'confidenceScore': confidenceScore,
        'providerName': providerName,
        'isFallback': isFallback,
        'personCount': personCount,
        'briefingKategori': briefingKategori,
      };

  factory AiVerificationResult.fromJson(Map<String, dynamic> json) {
    VerificationStatus parseStatus(String? name) {
      switch (name) {
        case 'sesuai':
          return VerificationStatus.sesuai;
        case 'tidakSesuai':
        case 'tidak_sesuai':
          return VerificationStatus.tidakSesuai;
        default:
          return VerificationStatus.perluCekManual;
      }
    }

    return AiVerificationResult(
      status: parseStatus(json['status'] as String?),
      alasan: json['alasan'] as String? ?? '',
      poinGagal: (json['poinGagal'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      poinLolos: (json['poinLolos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0.0,
      providerName: json['providerName'] as String? ?? 'Google Gemini',
      isFallback: json['isFallback'] as bool? ?? false,
      personCount: json['personCount'] as int?,
      briefingKategori: json['briefingKategori'] as String?,
    );
  }
}

class SopCriteriaHelper {
  static bool isNegatedOrPlaceholderCriterion(String raw) {
    final lower = raw
        .toLowerCase()
        .replaceAll(RegExp(r'^[\s\-•*0-9.)]+'), '')
        .replaceAll(RegExp(r'[.!;,\s]+$'), '')
        .trim();
    if (lower.isEmpty) return true;
    const placeholders = {
      '-',
      '--',
      'none',
      'null',
      'n/a',
      'na',
      'tidak ada',
      'nihil',
      'aman',
      'bersih',
      'sesuai',
      'ok',
      'normal',
      'lengkap',
      'baik',
    };
    if (placeholders.contains(lower)) return true;
    final hasRequiredGroomingAttr = lower.contains('id card') ||
        lower.contains('name tag') ||
        lower.contains('lanyard') ||
        lower.contains('yoyo') ||
        lower.contains('seragam') ||
        lower.contains('sepatu');
    if (!hasRequiredGroomingAttr &&
        (lower.startsWith('tidak ada ') ||
            lower.startsWith('bebas ') ||
            lower.startsWith('no ') ||
            lower.startsWith('tanpa '))) {
      return true;
    }
    if (RegExp(
      r'\b(tidak\s+ada|bebas|tanpa|tidak|bukan|no|not|without)\b.*\b(debu|kotor|kotoran|karat|korosi|rusak|kerusakan|masalah|kendala|temuan|blur|buram|miring|goyang|kendor|lepas|kusut|retak|pecah|robek|kelupas)\b',
    ).hasMatch(lower)) {
      return true;
    }
    return false;
  }

  static String toNegativeStatement(String criterion) {
    final lower = criterion.toLowerCase();
    if (lower.contains('jaket') ||
        lower.contains('hoodie') ||
        lower.contains('sweater')) {
      return 'Memakai jaket/hoodie di atas seragam, wajib dilepas';
    }
    if ((lower.contains('blur') ||
            lower.contains('miring') ||
            lower.contains('tidak fokus') ||
            lower.contains('goyang')) &&
        (lower.contains('fokus') || lower.contains('foto'))) {
      return 'Foto blur, miring, atau tidak fokus, wajib foto ulang';
    }
    if (isNegatedOrPlaceholderCriterion(criterion)) return '';
    if (lower.contains('blur') ||
        lower.contains('miring') ||
        lower.contains('tidak fokus') ||
        lower.contains('goyang')) {
      return 'Foto blur, miring, atau tidak fokus, wajib foto ulang';
    }
    if (lower.contains('seragam') && lower.contains('dimasukkan')) {
      return 'Seragam tidak dimasukkan dalam celana / diluar dan tidak rapi';
    } else if (lower.contains('seragam')) {
      return 'Tidak menggunakan seragam resmi BSS Parking / seragam tidak rapi dan tidak terkancing';
    } else if (lower.contains('lanyard') || lower.contains('yoyo') || lower.contains('id card') || lower.contains('name tag')) {
      return 'ID Card / Name Tag tidak terpasang di saku atau dada';
    } else if (lower.contains('sepatu')) {
      return 'Tidak mengenakan sepatu kerja warna hitam yang bersih';
    } else if (lower.contains('wajah') || lower.contains('masker') || lower.contains('kacamata')) {
      return 'Wajah tertutup masker/kacamata atau tidak terlihat jelas';
    } else if (lower.contains('postur') || lower.contains('sikap')) {
      return 'Sikap tubuh tidak tegak / posisi tidak siap';
    } else if (lower.contains('kebersihan') || lower.contains('pos') || lower.contains('booth') || lower.contains('meja pos')) {
      return 'Area meja pos kotor atau ada tumpukan barang pribadi';
    } else if (lower.contains('kabel') || lower.contains('cable')) {
      return 'Kabel kurang rapi dan belum tertata dengan baik';
    } else if (lower.contains('debu') || lower.contains('kotor')) {
      return 'Perangkat tampak kotor atau berdebu';
    } else if (lower.contains('karat') || lower.contains('korosi')) {
      return 'Ada karat di perangkat';
    } else if (lower.contains('stiker')) {
      return 'Stiker tampak kusam, terkelupas, atau rusak';
    } else if (lower.contains('printer')) {
      return 'Printer kotor atau cetakan struk tidak jelas';
    } else if (lower.contains('palang')) {
      return 'Posisi palang tidak lurus atau mekanikal bermasalah';
    } else if (lower.contains('dudukan') || lower.contains('dynabolt') || lower.contains('dinabolt')) {
      return 'Dudukan tidak kokoh atau baut pengikat kendor';
    }
    return 'Kondisi belum sesuai standar SOP: $criterion';
  }

  static String toPositiveStatement(String criterion) {
    return criterion;
  }
}

class AiVisionService {
  static AiVisionConfig? _cachedConfig;

  static const String kErrorApiKeyUnconfigured =
      'API Key AI belum dikonfigurasi';
  static const String kErrorConnectionFailed = 'Koneksi ke AI gagal';
  static const String kErrorUnverifiablePhoto =
      'Foto tidak dapat diverifikasi otomatis';
  static const String kErrorInvalidJson = 'AI tidak mengembalikan JSON';

  static const List<String> systemErrorReasonPrefixes = [
    kErrorApiKeyUnconfigured,
    kErrorConnectionFailed,
    kErrorUnverifiablePhoto,
    kErrorInvalidJson,
  ];

  /// Seam test: ganti client HTTP tanpa jaringan sungguhan.
  @visibleForTesting
  static http.Client Function() clientFactory = http.Client.new;

  @visibleForTesting
  static void resetProxyState() {}

  static String cleanTechnicianReason(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return 'Evaluasi selesai';
    text = text.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

    // Normalisasi salam, basa-basi pembuka & penutup khas LLM
    text = text.replaceAll(RegExp(r'\b(halo|selamat\s+(pagi|siang|sore|malam)|terima kasih|baik|tentu|berikut\s+hasil\s+evaluasi|berdasarkan\s+analisis\s+gambar)[,:\s!.]*', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'(terima\s+kasih|semoga\s+membantu|mohon\s+dicek\s+kembali)[.!]*$', caseSensitive: false), '');

    // Normalisasi kata formal/kaku khas AI ke Natural Technician Language
    text = text.replaceAll(RegExp(r'berdasarkan hasil observasi[,:\s]*', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'ditemukan adanya ketidaksesuaian\s*(pada)?', caseSensitive: false), 'terdapat temuan');
    text = text.replaceAll(RegExp(r'tidak terorganisir dengan rapi', caseSensitive: false), 'tidak tertata rapi');
    text = text.replaceAll(RegExp(r'degradasi fisik', caseSensitive: false), 'kerusakan fisik');
    text = text.replaceAll(RegExp(r'mengalami deteriorasi', caseSensitive: false), 'mulai rusak');
    text = text.replaceAll(RegExp(r'parameter tidak terpenuhi', caseSensitive: false), 'tidak sesuai');
    text = text.replaceAll(RegExp(r'kondisi secara keseluruhan', caseSensitive: false), 'kondisi');
    text = text.replaceAll(RegExp(r'secara signifikan\s*', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'dalam kondisi optimal', caseSensitive: false), 'kondisi masih bagus');
    text = text.replaceAll(RegExp(r'memiliki integritas struktural', caseSensitive: false), 'terpasang kencang');
    text = text.replaceAll(RegExp(r'permukaan mengalami degradasi', caseSensitive: false), 'permukaan mulai rusak');
    text = text.replaceAll(RegExp(r'sesuai standar operasional', caseSensitive: false), 'normal');
    text = text.replaceAll(RegExp(r'\bsemrawut\b', caseSensitive: false), 'kurang rapi');
    text = text.replaceAll(RegExp(r'beton pulau gate', caseSensitive: false), 'lantai pulau gate');

    // Sanitasi prefix klise
    text = text.replaceAll(
      RegExp(
        r'^(kondisi\s+|foto hanya menampilkan\s+|foto tidak menampilkan\s+|terlihat\s+bahwa\s+)',
        caseSensitive: false,
      ),
      '',
    );

    // Ambil kalimat pertama saja (strict 1 kalimat fakta lapangan, max 95 karakter)
    final sentences = text.split(RegExp(r'[.!;\n]+\s*'));
    String firstSentence = '';
    for (final s in sentences) {
      final trimmed = s.replaceAll(RegExp(r'^[,\s.-]+'), '').trim();
      if (trimmed.length >= 4) {
        firstSentence = trimmed;
        break;
      }
    }
    if (firstSentence.isNotEmpty) {
      text = firstSentence;
    }
    if (text.length > 95) {
      text = '${text.substring(0, 92).trim()}...';
    }

    text = text.replaceAll(RegExp(r'[.\s]+$'), '').trim();
    if (text.isNotEmpty) {
      text = '${text[0].toUpperCase()}${text.substring(1)}';
    }
    return text.isNotEmpty ? text : 'Kondisi telah diverifikasi';
  }

  static void clearConfigCache() {
    _cachedConfig = null;
  }

  static AiVisionConfig getConfig() {
    _cachedConfig ??= StorageService.getAiVisionConfig();
    return _cachedConfig!;
  }

  static List<String> filterCriteriaByConfig(
      List<String> criteria, AiVisionConfig config) {
    return criteria.where((c) {
      final cl = c.toLowerCase();
      if ((cl.contains('seragam') ||
              cl.contains('rambut') ||
              cl.contains('sepatu')) &&
          !config.enableGroomingCheck) {
        return false;
      }
      if ((cl.contains('id card') || cl.contains('name tag')) &&
          !config.enableIdCardDetection) {
        return false;
      }
      if ((cl.contains('postur') ||
              cl.contains('sikap') ||
              cl.contains('barisan')) &&
          !config.enableFormationCheck) {
        return false;
      }
      if ((cl.contains('kebersihan') ||
              cl.contains('pos') ||
              cl.contains('booth')) &&
          !config.enableCleanlinessCheck) {
        return false;
      }
      return true;
    }).toList();
  }

  static Future<AiVerificationResult> verifyPhoto({
    required TemplateModel template,
    required String? imageBase64,
    AiVisionConfig? customConfig,
    bool forceSimulateFailure = false,
    bool forceSimulateSuccess = false,
    AbsensiKategori? absensiKategori,
    String? hariKerja,
    String? tipeLaporan,
  }) async {
    return verifySubmissionWithAI(
      template: template,
      imageBase64: imageBase64,
      customConfig: customConfig,
      forceSimulateFailure: forceSimulateFailure,
      forceSimulateSuccess: forceSimulateSuccess,
      absensiKategori: absensiKategori,
      hariKerja: hariKerja,
      tipeLaporan: tipeLaporan,
    );
  }

  static Future<AiVerificationResult> verifySubmissionWithAI({
    required TemplateModel template,
    required String? imageBase64,
    AiVisionConfig? customConfig,
    bool forceSimulateFailure = false,
    bool forceSimulateSuccess = false,
    AbsensiKategori? absensiKategori,
    String? hariKerja,
    String? tipeLaporan,
  }) async {
    final config = customConfig ?? getConfig();
    final criteria = filterCriteriaByConfig(template.sopCriteria, config);

    if (forceSimulateFailure) {
      return AiVerificationResult(
        status: VerificationStatus.tidakSesuai,
        alasan: 'Simulasi Gagal: Kriteria SOP tidak terpenuhi.',
        poinGagal: criteria.map(SopCriteriaHelper.toNegativeStatement).toList(),
        poinLolos: [],
        confidenceScore: 0.95,
        providerName: 'Simulasi Test',
        isFallback: false,
      );
    }

    if (forceSimulateSuccess) {
      return AiVerificationResult(
        status: VerificationStatus.sesuai,
        alasan: 'Simulasi Sukses: Semua kriteria SOP terpenuhi.',
        poinGagal: [],
        poinLolos: criteria.map(SopCriteriaHelper.toPositiveStatement).toList(),
        confidenceScore: 0.95,
        providerName: 'Simulasi Test',
        isFallback: false,
      );
    }

    if (config.provider == AiProviderType.onDeviceMock ||
        imageBase64 == null ||
        imageBase64.isEmpty) {
      if (imageBase64 == null || imageBase64.isEmpty) {
        return AiVerificationResult(
          status: VerificationStatus.tidakSesuai,
          alasan: 'Foto tidak valid / kosong.',
          poinGagal: ['Foto tidak ditemukan atau kosong'],
          poinLolos: [],
          confidenceScore: 1.0,
          providerName: 'On-Device Mock Engine',
          isFallback: true,
        );
      }
      return AiVerificationResult(
        status: VerificationStatus.sesuai,
        alasan: 'Verifikasi Mock On-Device (Semua kriteria terpenuhi)',
        poinGagal: [],
        poinLolos: criteria.map(SopCriteriaHelper.toPositiveStatement).toList(),
        confidenceScore: 0.95,
        providerName: 'On-Device Mock Engine',
        isFallback: true,
      );
    }

    return _runCustomEndpointVerification(
      imageBase64: imageBase64,
      criteria: criteria,
      config: config,
      absensiKategori: absensiKategori,
      hariKerja: hariKerja,
      tipeLaporan: tipeLaporan,
    );
  }

  /// Per-point untuk teknisi: 1 point = 1 foto, klasifikasi spesifik point tersebut.
  static Future<AiVerificationResult> verifyMaintenancePoint({
    required SopPoint point,
    required TemplateModel template,
    required String? imageBase64,
    AiVisionConfig? customConfig,
  }) async {
    final config = customConfig ?? getConfig();
    if (imageBase64 == null || imageBase64.isEmpty) {
      return AiVerificationResult(
        status: VerificationStatus.tidakSesuai,
        alasan: 'Foto point ${point.label} kosong',
        poinGagal: [SopCriteriaHelper.toNegativeStatement(point.label)],
        poinLolos: [],
        confidenceScore: 1.0,
        providerName: 'Google Gemini',
      );
    }
    // Untuk per-point, kirim label point + detail checkpoints sebagai kriteria evaluasi presisi
    final pointCriteria = [
      point.label,
      if (point.deskripsi.isNotEmpty) point.deskripsi,
      ...point.checkpoints,
    ];

    final checkpointsStr = point.checkpoints.isNotEmpty
        ? ' — Checkpoints: ${point.checkpoints.join("; ")}'
        : '';

    return _runCustomEndpointVerification(
      imageBase64: imageBase64,
      criteria: pointCriteria,
      config: config,
      extraContext: 'Template: ${template.nama} — Point: ${point.label}${point.deskripsi.isNotEmpty ? " (${point.deskripsi})" : ""}$checkpointsStr',
    );
  }


  /// Analisa ulang foto lama tanpa konteks template SOP tertentu (mis. dari
  /// galeri atau riwayat): kirim ulang ke server AI dengan kriteria umum.
  static Future<AiVerificationResult> reanalyzePhoto({
    required String imageBase64,
    String? konteks,
    AiVisionConfig? customConfig,
  }) {
    return _runCustomEndpointVerification(
      imageBase64: imageBase64,
      criteria: const [
        'Foto terlihat jelas, tidak blur, dan objeknya bisa dikenali',
        'Objek sesuai dengan judul/keterangan foto',
        'Tidak ada tanda foto lama, hasil edit, atau manipulasi',
      ],
      config: customConfig ?? getConfig(),
      extraContext: konteks,
    );
  }

  static Future<AiVerificationResult> _runCustomEndpointVerification({
    required String imageBase64,
    required List<String> criteria,
    required AiVisionConfig config,
    String? extraContext,
    bool isBriefingCountMode = false,
    AbsensiKategori? absensiKategori,
    String? hariKerja,
    String? tipeLaporan,
  }) async {
    if (!AiVisionConfig.proxyEnabled) {
      return AiVerificationResult(
        status: VerificationStatus.perluCekManual,
        alasan:
            '$kErrorApiKeyUnconfigured. Foto dialihkan untuk Cek Manual oleh Supervisor.',
        poinGagal: ['API Key AI Belum Dikonfigurasi'],
        poinLolos: [],
        confidenceScore: 0.0,
        providerName: 'Google Gemini',
      );
    }

    final formattedImage = imageBase64.startsWith('data:image')
        ? imageBase64
        : 'data:image/jpeg;base64,$imageBase64';

    final criteriaListStr = criteria.isEmpty
        ? '1. Seragam rapi dan lengkap\n2. ID card terlihat jelas\n3. Sikap siap'
        : criteria
            .asMap()
            .entries
            .map((e) => '${e.key + 1}. ${e.value}')
            .join('\n');

    final String systemPrompt;
    if (isBriefingCountMode) {
      systemPrompt = '''
You are BSS-Vision, strict briefing auditor for BSS Parking (Bahana Sulut Sentosa).
Task: Count people and classify briefing by uniform colors, roles, and grooming.

RULE KLASIFIKASI SERAGAM RESMI BSS PARKING:
1. ADMIN: Perempuan mengenakan baju kombinasi warna biru dan hijau.
2. LEADER: Laki-laki mengenakan seragam kemeja berkerah warna hitam dengan kombinasi hijau pada pundak dan patch bendera Indonesia di lengan kanan.
3. SPP / SPL (Opsi 1): Seragam kemeja berkerah kombinasi warna abu-abu pada badan tengah, hijau pada dada atas, dan biru cerah pada bagian lengan serta dilengkapi logo BSS Parking.
4. SPP / SPL (Opsi 2): Seragam kemeja berkerah warna merah dengan kombinasi kerah dan lis kancing warna hitam, serta dilengkapi logo BSS Parking.
Keempat seragam di atas adalah SERAGAM RESMI BSS PARKING yang SAH.

CRITERIA:
$criteriaListStr

COUNT RULE: Count every visible person. Return exact count.
KATEGORI: if personCount <5 -> "kecil" (2,3 orang), if >=5 -> "besar" (10-15 orang).
LEADER/ADMIN: Identifikasi pimpinan di depan (Admin perempuan baju biru-hijau ATAU Leader kemeja hitam kombinasi hijau pundak + bendera Indonesia lengan kanan).

OUTPUT STRICT JSON ONLY. No markdown.
Schema:
{"status":"sesuai"|"tidak_sesuai"|"perlu_cek_manual","confidenceScore":95,"alasan":"...","poinLolos":["..."],"poinGagal":["..."],"personCount":7,"briefingKategori":"besar"}
''';
    } else if (extraContext != null) {
      systemPrompt = buildMaintenanceSystemPrompt(
        extraContext: extraContext,
        criteriaListStr: criteriaListStr,
      );
    } else {
      final hari = (hariKerja ?? 'SENIN').toUpperCase();
      final isPulang = tipeLaporan == 'Pulang';
      if (isPulang) {
        systemPrompt = '''
You are BSS-Vision. Evaluasi kerapian teknisi untuk absen pulang ($hari).

ATURAN ABSEN PULANG:
1. Foto setengah badan sah dan lulus. Tidak perlu cek sepatu.
2. ID Card atau tali lanyard terpasang di leher/dada. Jika tali lanyard terlihat, status LULUS (sesuai).
3. Yang LULUS (HIJAU) hanya: seragam teknisi resmi BSS, seragam dinas hari $hari, kemeja rapi berkerah, atau baju polo.
4. JAKET / HOODIE / SWEATER / ROMPI DILARANG: baju luar apa pun yang menutupi seragam atau kaos (jaket kulit, jeans, bomber, hoodie, sweater) WAJIB "tidak_sesuai" (MERAH). Berlaku juga di hari "Bebas rapi" / olahraga: yang sah hanya kemeja rapi atau baju polo.
5. KUALITAS FOTO: foto blur/goyang, miring (badan atau garis horizon tidak tegak/rata), atau terlalu gelap sehingga atribut tidak terbaca WAJIB "tidak_sesuai" (MERAH) supaya teknisi foto ulang.
6. Gaya bahasa alasan: Singkat, natural, to the point (5-10 kata).
   - Contoh sesuai: "Seragam teknisi rapi dan tali lanyard terpasang."
   - Contoh tidak sesuai: "Tidak memakai seragam resmi dan tanpa ID Card."
   - Contoh tidak sesuai: "Memakai hoodie di atas seragam, wajib dilepas."
   - Contoh tidak sesuai: "Foto blur dan miring, ulangi foto dengan posisi tegak."

STATUS:
- sesuai: Seragam, kemeja rapi, atau baju polo rapi, ID Card/lanyard terpasang, foto jelas dan tegak.
- tidak_sesuai: Pakaian non-resmi (kaos oblong/bebas, jaket, hoodie, sweater), tanpa ID Card/lanyard, atau foto blur/goyang/miring/tidak rata/gelap.
- perlu_cek_manual: Hanya kalau atribut benar-benar tidak bisa dinilai (mis. badan terpotong parah).

OUTPUT STRICT JSON ONLY:
{"status":"sesuai"|"tidak_sesuai"|"perlu_cek_manual","confidenceScore":95,"alasan":"...","poinLolos":["..."],"poinGagal":["..."]}
''';
      } else {
        systemPrompt = '''
You are BSS-Vision. Evaluasi kerapian teknisi untuk absen masuk ($hari).

JADWAL SERAGAM:
- Senin: Seragam Teknisi / PDH navy
- Selasa: PDH navy / Seragam Teknisi
- Rabu: Seragam Teknisi
- Kamis: BSS Putih / Seragam Teknisi
- Jumat: Batik / Seragam Teknisi
- Sabtu: Olahraga biru-kuning / Seragam Teknisi
- Minggu: Bebas rapi / Seragam Teknisi
* Catatan: Seragam Teknisi resmi BSS selalu sah di semua hari (Senin-Minggu). Jaket, hoodie, dan sweater tetap DILARANG di hari mana pun (termasuk hari Bebas rapi).

KRITERIA:
1. Seragam: Seragam Teknisi resmi atau sesuai jadwal hari $hari, dipakai rapi.
2. ID Card / tali lanyard terpasang di dada/leher.
3. Celana panjang dan sepatu tertutup (tidak boleh sandal).
4. Yang LULUS (HIJAU) hanya: seragam resmi BSS Parking, seragam dinas hari $hari, kemeja rapi berkerah, atau baju polo.
5. JAKET / HOODIE / SWEATER / ROMPI DILARANG: baju luar apa pun yang menutupi seragam atau kaos (jaket kulit, jeans, bomber, hoodie, sweater) WAJIB "tidak_sesuai" (MERAH), begitu juga kaos oblong/kaos sablon bebas. Hari "Bebas rapi" / olahraga tetap hanya kemeja rapi atau baju polo.
6. KUALITAS FOTO: foto blur/goyang, miring (badan atau garis horizon tidak tegak/rata), atau terlalu gelap WAJIB "tidak_sesuai" (MERAH) supaya teknisi foto ulang.
7. Gaya bahasa alasan: Singkat, natural, to the point (5-10 kata).
   - Contoh sesuai: "Seragam teknisi rapi, ID Card dan sepatu terpasang lengkap."
   - Contoh tidak sesuai: "ID Card tidak terpasang di dada."
   - Contoh tidak sesuai: "Memakai sandal, wajib sepatu kerja tertutup."
   - Contoh tidak sesuai: "Memakai jaket di atas seragam, wajib dilepas."
   - Contoh tidak sesuai: "Foto blur dan miring, ulangi foto dengan posisi tegak."

STATUS:
- sesuai: Seragam, kemeja rapi, atau baju polo rapi, ID Card/lanyard ada, sepatu tertutup, foto jelas dan tegak.
- tidak_sesuai: Tanpa ID Card, pakai sandal, kaos oblong/kaos bebas, jaket/hoodie/sweater, foto blur/goyang/miring/tidak rata/gelap, atau badan terpotong (sepatu tidak terlihat).
- perlu_cek_manual: Hanya kalau atribut benar-benar tidak bisa dinilai (mis. badan tertutup objek).

OUTPUT STRICT JSON ONLY:
{"status":"sesuai"|"tidak_sesuai"|"perlu_cek_manual","confidenceScore":95,"alasan":"...","poinLolos":["..."],"poinGagal":["..."]}
''';
      }
    }

    final userContent = [
      {'type': 'text', 'text': 'Evaluasi foto ini terhadap SOP BSS Parking.'},
      {'type': 'image_url', 'image_url': {'url': formattedImage}},
    ];

    final primaryModel = config.effectiveModelName;
    // Smart Fast Fallback: kalau model utama lambat, 503, atau kuota free tier
    // habis (429 = 20 request/hari untuk 3.6-flash), pindah ke model lite yang
    // masih punya jatah. Diukur 23 Okt 2026: ~1-2 dtk, JSON valid.
    final candidateModels = <String>{
      primaryModel,
      'gemini-3.5-flash-lite',
      'gemini-flash-lite-latest',
    }.toList();

    final DateTime budgetStart = DateTime.now();
    final Duration totalBudget =
        const Duration(seconds: AiVisionConfig.totalBudgetSeconds);
    String errorMessage = '';

    const maxAttempts = 3;
    final proxyUri = Uri.parse(AiVisionConfig.proxyUrl);
    final backendAnonKey = DailyTaskService.anonKey;
    String? lastRawContent;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (DateTime.now().difference(budgetStart) >= totalBudget) {
        errorMessage = 'Batas waktu ${AiVisionConfig.totalBudgetSeconds}s tercapai';
        break;
      }

      final remaining = totalBudget - DateTime.now().difference(budgetStart);
      if (remaining.inSeconds < 2) break;

      final currentModel =
          candidateModels[attempt.clamp(0, candidateModels.length - 1)];

      // Batasi timeout per attempt agar attempt 0 tidak menghabiskan seluruh budget 30s
      // sebelum sempat mencoba candidateModels[1].
      final int requestedTimeout =
          config.timeoutSeconds > AiVisionConfig.perModelTimeoutSeconds
              ? config.timeoutSeconds
              : AiVisionConfig.perModelTimeoutSeconds;
      final int maxAttemptSeconds =
          attempt == 0 ? 10 : remaining.inSeconds;
      final int effectiveSeconds = requestedTimeout < maxAttemptSeconds
          ? requestedTimeout
          : maxAttemptSeconds;
      final perModelTimeout = Duration(
        seconds: effectiveSeconds < remaining.inSeconds
            ? effectiveSeconds
            : remaining.inSeconds,
      );

      final isRetry = attempt > 0;
      if (isRetry) {
        debugPrint('[BSS-Vision] RETRY/FAILOVER ${attempt + 1}/$maxAttempts ke $currentModel');
      }

      final client = clientFactory();
      try {
        final requestBody = <String, dynamic>{
          'model': currentModel,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userContent},
          ],
          'max_tokens': config.maxTokens,
          'temperature': config.temperature,
          'response_format': {'type': 'json_object'},
          'stream': false,
        };

        // Model Gemini 3.x yang mendukung reasoning bisa menghabiskan token
        // untuk "thinking" sampai JSON terpotong (finish_reason=length) dan
        // lama. Matikan thinking supaya output JSON utuh dan cepat (~2-3 dtk).
        // Catatan: varian *-lite (mis. gemini-3.5-flash-lite) menolak param ini
        // dengan HTTP 400, jadi hanya dikirim ke model yang sudah terverifikasi.
        final supportsNoThinking = currentModel.contains('3.1') ||
            currentModel.contains('3.6') ||
            currentModel.contains('3.7') ||
            currentModel.contains('3.8') ||
            currentModel.contains('3-flash') ||
            currentModel.contains('reasoning') ||
            currentModel.contains('thinking');
        if (supportsNoThinking) {
          requestBody['reasoning_effort'] = 'none';
        }

        final bodyJson = jsonEncode(requestBody);
        final sessionToken = AuthRepository.instance.sessionToken;
        final response = await client
            .post(
              proxyUri,
              headers: {
                'Content-Type': 'application/json',
                'apikey': backendAnonKey,
                'Authorization': 'Bearer $backendAnonKey',
                if (sessionToken != null && sessionToken.isNotEmpty)
                  'x-app-session': sessionToken,
              },
              body: bodyJson,
            )
            .timeout(perModelTimeout);

        if (response.statusCode == 401) {
          errorMessage = 'Server error HTTP 401';
          unawaited(AuthRepository.instance.handleUnauthorizedSession());
          break;
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final choices = data['choices'] as List<dynamic>?;
          if (choices != null && choices.isNotEmpty) {
            final firstChoice = choices[0] as Map<String, dynamic>?;
            final finishReason = firstChoice?['finish_reason'] as String?;
            final rawContent =
                firstChoice?['message']?['content'] as String? ?? '{}';
            lastRawContent = rawContent;

            final strictResult = _parseStrictAiJsonResponse(
              rawContent,
              criteria,
              config,
              extraContext: extraContext,
            );

            if (strictResult != null && finishReason != 'length') {
              return strictResult.copyWith(
                providerName: 'Google Gemini',
              );
            }

            final isFailover = finishReason == 'length' || strictResult == null;
            if (isFailover && attempt < maxAttempts - 1 && remaining.inSeconds > 3) {
              debugPrint(
                '[BSS-Vision] Failover attempt ${attempt + 1}/$maxAttempts '
                '($currentModel): finish_reason=$finishReason, strict=${strictResult != null} '
                '-> switch ke model berikutnya (sisa ${remaining.inSeconds}s)',
              );
              await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
              continue;
            }

            final fallbackResult = _parseFreeTextFallback(
              rawContent,
              criteria,
              config,
              extraContext: extraContext,
            );
            return fallbackResult.copyWith(
              providerName: 'Google Gemini',
            );
          }
          errorMessage = 'Response dari server kosong';
          break;
        } else {
          errorMessage = 'Server error HTTP ${response.statusCode}';
          debugPrint('[BSS-Vision] HTTP ${response.statusCode} $currentModel: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
          final retryable =
              [404, 429, 500, 501, 502, 503, 504].contains(response.statusCode);
          if (retryable && attempt < maxAttempts - 1 && remaining.inSeconds > 5) {
            await Future.delayed(Duration(milliseconds: 400 * (attempt + 1)));
            continue;
          }
          break;
        }
      } catch (e, st) {
        debugPrint('[BSS-Vision] ERROR $currentModel attempt ${attempt + 1}: $e\n$st');
        final isTimeout = e is TimeoutException;
        final isSocket = e.toString().contains('SocketException') ||
            e.toString().contains('Connection') ||
            e.toString().contains('ClientException');
        if ((isTimeout || isSocket) &&
            attempt < maxAttempts - 1 &&
            remaining.inSeconds > 6) {
          errorMessage = 'Failover jaringan ($currentModel) -> switch ke model berikutnya';
          await Future.delayed(const Duration(milliseconds: 400));
          continue;
        }
        if (isTimeout) {
          errorMessage = 'Timeout ${config.timeoutSeconds}s ($currentModel)';
        } else {
          errorMessage = e.toString().replaceAll('Exception:', '').trim();
          if (errorMessage.length > 180) errorMessage = errorMessage.substring(0, 180);
        }
        break;
      } finally {
        client.close();
      }
    }

    if (lastRawContent != null) {
      final fallbackResult = _parseFreeTextFallback(
        lastRawContent,
        criteria,
        config,
        extraContext: extraContext,
      );
      return fallbackResult.copyWith(
        providerName: 'Google Gemini',
      );
    }

    if (errorMessage.isEmpty || errorMessage == 'null') {
      errorMessage = 'Koneksi terputus / Timeout';
    }
    debugPrint('[BSS-Vision] FINAL FAIL ${config.effectiveModelName}: $errorMessage | url=${proxyUri.toString()}');

    return AiVerificationResult(
      status: VerificationStatus.perluCekManual,
      // Pesan ke user tetap generik (nama model tidak ditampilkan), tapi kode
      // penyebab singkat ikut dicantumkan supaya masalah jaringan/limit bisa
      // dilaporkan tanpa perlu buka console browser.
      alasan:
          '$kErrorConnectionFailed${_shortErrorSuffix(errorMessage)}. Foto dialihkan untuk Cek Manual oleh Supervisor.',
      poinGagal: ['Koneksi Server Vision Terganggu / Gagal'],
      poinLolos: [],
      confidenceScore: 0.0,
      providerName: 'AI Fallback Alert (${config.provider.displayName})',
      isFallback: true,
    );
  }

  /// Kode penyebab singkat untuk ditampilkan ke user: "(HTTP 503)", "(timeout)".
  static String _shortErrorSuffix(String message) {
    final httpMatch = RegExp(r'HTTP (\d{3})').firstMatch(message);
    if (httpMatch != null) return ' (HTTP ${httpMatch.group(1)})';
    final lower = message.toLowerCase();
    if (lower.contains('timeout') || lower.contains('batas waktu')) {
      return ' (timeout)';
    }
    if (lower.contains('format json')) return ' (format respons)';
    return ' (jaringan)';
  }


  /// Prompt audit maintenance per point (barrier gate, pos, manless, server, kasir).
  /// Dipisah jadi fungsi sendiri supaya aturan promptnya bisa diuji tanpa panggil API.
  @visibleForTesting
  static String buildMaintenanceSystemPrompt({
    required String extraContext,
    required String criteriaListStr,
  }) {
    return '''
You are BSS-Vision, expert technical maintenance auditor for BSS Parking (Bahana Sulut Sentosa).
Task: Audit SINGLE maintenance point from hardware/infrastructure photo using NATURAL TECHNICIAN LANGUAGE.

CONTEXT: $extraContext
CRITERIA: $criteriaListStr

ATURAN WAJIB ANTI SALIN CONTOH (PRIORITAS TERTINGGI):
- Semua kalimat contoh di bawah ini cuma PATOKAN GAYA, BUKAN kalimat siap pakai. DILARANG menyalin kalimat contoh apa adanya.
- KHUSUS TEMUAN (status tidak_sesuai dan perlu_cek_manual): setiap alasan WAJIB memuat minimal 1 detail yang cuma ada di foto ini: arah, posisi, nama bagian, warna, jumlah, atau tingkat kondisi (contoh: "baut sisi kanan", "palang ujung kiri", "paving baris depan").
- Uji sebelum menjawab, khusus temuan: kalau kalimatmu bisa dipakai untuk gate/unit lain tanpa diubah, berarti belum spesifik, tulis ulang pakai detail dari foto ini.
- Kalau dua checkpoint sama-sama TEMUAN dengan kondisi yang sama, WAJIB tulis pembedanya. DILARANG memakai kalimat identik untuk dua temuan.
- KHUSUS poin sesuai (hijau): tetap singkat dan umum, 5 sampai 10 kata, cukup sebut bagian dan kondisinya. TIDAK perlu detail arah/posisi, karena poin aman digabung jadi satu baris untuk beberapa gate sekaligus.
- Kalau foto tidak cukup jelas untuk menyebut detail, status WAJIB "perlu_cek_manual". DILARANG menebak kondisi.

PANDUAN GAYA BAHASA TEKNISI LAPANGAN (NATURAL TECHNICIAN LANGUAGE):
Prinsip: "Teknisi melihat kondisi langsung di lapangan -> Teknisi menulis hasil pengecekan secara singkat, jelas, dan natural."
Bukan seperti hasil generate AI atau laporan audit akademis yang kaku!

1. POLA PENULISAN:
   [Objek] + [kondisi yang terlihat] + [detail masalah jika ada].

2. KOSAKATA NATURAL YANG WAJIB DIPRIORITASKAN:
   - "tampak kotor", "tampak berdebu", "terdapat tumpukan debu"
   - "kabel kurang rapi", "kabel perlu dirapikan dengan cable tie", "kabel belum tertata rapi"
   - "ada karat", "plat besi berkarat", "ada kerusakan fisik"
   - "stiker tampak kusam", "stiker terkelupas", "stiker rusak"
   - "cat tampak pudar", "lantai pulau gate berdebu", "permukaan pulau gate kotor"
   - "terdapat sisa material", "terdapat bekas stiker"
   - "terpasang kencang", "normal dipakai", "tulisan tercetak jelas", "bersih dan bebas debu"

3. KATA/ISTILAH YANG DILARANG KERAS (TERLALU FORMAL / GAYA AI KAKU):
   - DILARANG SALAM & BASA-BASI: Jangan pernah menyertakan salam ("Halo", "Selamat Pagi/Siang", "Terima kasih", "Berdasarkan analisis...").
   - DILARANG LEBIH DARI 1 KALIMAT: Output alasan WAJIB HANYA 1 KALIMAT TUNGGAL (maksimal 12 kata), padat dan to the point.
   - DILARANG KLISE KAKU: "terpasang dengan kokoh, namun...", "tampak bersih dan terlumasi dengan baik", "berdasarkan hasil observasi", "ditemukan adanya ketidaksesuaian", "kondisi secara keseluruhan", "secara signifikan", "mengalami degradasi", "degradasi fisik", "tidak terorganisir dengan rapi", "parameter tidak terpenuhi", "sesuai standar operasional", "dalam kondisi optimal", "memiliki integritas struktural".
   - DILARANG BASA-BASI POSITIF PADA STATUS MERAH: Jika ada masalah (kotor/rusak/berkarat), JANGAN buka dengan pujian palsu seperti "Baut dynabolt terpasang kokoh, namun...". Langsung sebut masalah intinya!
   - DILARANG REDUNDAN: Jangan mengulang kata ("kabel kurang rapi dan tidak tertata").
   - DILARANG KALIMAT PERINTAH: Jangan gunakan "harus dibersihkan", "segera dicat ulang", "segera perbaiki". Tulis faktual apa yang terlihat.

4. ATURAN STATUS:
   - SESUAI (Lulus/Hijau): Tepat 1 kalimat positif singkat, natural, to the point (5-10 kata).
     * Contoh: "Area printer bersih dan bebas debu."
     * Contoh: "Tombol tiket normal dan struk tercetak jelas."
     * Contoh: "Bodi manless bersih dan stiker panduan utuh."
     * Contoh: "Bodi mesin barrier bersih dan penutup mesinnya rapat."
     * Contoh: "Per spring dan bearing masih terlumasi dan tidak kering."
     * Contoh: "Kapasitas Drive C aman (>20GB) dan folder temp bersih."
   - TIDAK_SESUAI (Temuan/Merah): Langsung sebut objek dan masalah fisiknya, to the point tanpa basa-basi (6-14 kata).
     * Format: [Objek] + [kondisi: kotor / berkarat / pudar / rusak / retak / kendor] + [lokasi].
     * JANGAN: "Baut dynabolt terpasang kokoh, namun area dudukan kotor" (SALAH: bertele-tele).
     * GUNAKAN: "Area dudukan mesin kotor dan banyak tumpukan debu." (BENAR: langsung to the point).
     * Contoh Kotor: "Head printer kotor dan ada sisa robekan kertas di dalam printer."
     * Contoh Berkarat: "Baut dynabolt berkarat dan plat dudukan mesin mulai keropos."
     * Contoh Pudar/Kusam: "Cat bodi manless pudar dan stiker panduan kusam."
     * Contoh Rusak/Baut Lepas: "Karet speed bump kotor dan baut dynabolt tidak terpasang."
     * Contoh Kabel Kurang Rapi: "Kabel di dalam manless belum terikat rapi dan adaptor kendur."
     * Contoh Kunci Rusak: "Gembok pintu manless berkarat dan anak kunci macet."
   - PERLU_CEK_MANUAL (Kuning / Warning):
     * Gunakan HANYA JIKA foto bermasalah teknis (blur, goyang, terlalu gelap, atau silau).
     * Contoh: "Foto blur dan kurang fokus, perlu cek fisik langsung."
     * Contoh: "Sudut foto terlalu gelap, indikator LED tidak terlihat."
     * DILARANG pakai kuning jika objek jelas rusak/kotor/berkarat (wajib merah / tidak_sesuai)!

5. ATURAN KHUSUS JALUR KABEL SENSOR LOOP DETECTOR (BARRIER GATE):
   - Kabel sensor loop detector SELALU ditanam DI BAWAH permukaan jalan (bisa di bawah susunan paving block atau di bawah garis potongan aspal/beton yang di-sealant).
   - JIKA foto menampilkan permukaan susunan paving block yang rata/rapi ATAU garis coran aspal/beton yang rata tanpa ada kabel mencuat/terkelupas ke atas, status WAJIB "sesuai" (LULUS / HIJAU).
   - DILARANG memberi status "tidak_sesuai" atau "perlu_cek_manual" hanya karena kabel fisik tidak terlihat di atas paving/lantai! Kabel memang wajib tertanam di bawah permukaan.
   - Contoh alasan sesuai: "Jalur kabel sensor tertanam rapi di bawah paving dan permukaannya rata." ATAU "Jalur coran kabel sensor tertutup rapi dan tidak ada kabel mencuat."
   - Hanya beri "tidak_sesuai" jika paving/aspal amblas parah, bongkaran rusak, atau ada kabel fisik yang terkelupas/mencuat keluar ke permukaan.

6. ATURAN KHUSUS STANDARISASI ITEM DALAM POS (POS KASIR):
   - Fokus utama poin ini adalah KELENGKAPAN ITEM DALAM POS: Monitor, Keyboard, Mouse, Scanner, Printer, dan Kipas Angin.
   - JIKA item di atas terlihat ada di meja pos, status WAJIB "sesuai" (LULUS / HIJAU).
   - DILARANG memberi status "tidak_sesuai" atau "perlu_cek_manual" hanya karena meja tampak kusam, cat meja terkelupas, serat kayu terlihat, atau ada debu wajar pada meja! Itu kondisi keausan meja lama, BUKAN masalah item pos.
   - Cukup dengan adanya item utama (monitor, keyboard, scanner, printer, kipas angin), status LANGSUNG HIJAU.
   - Contoh alasan sesuai: "Item dalam pos lengkap: monitor, keyboard, scanner, printer, dan kipas angin ada."
   - Hanya beri "tidak_sesuai" jika item utama tidak ada sama sekali atau pos kosong.

7. ATURAN KHUSUS DUDUKAN MESIN & BAUT DYNABOLT (BARRIER GATE):
   - Fokus HANYA pada baut dynabolt dan plat dudukan mesin: apakah plat dudukannya terpasang kencang ke lantai/beton.
   - Debu semen, pasir, noda oli jalanan, atau noda cuaca pada lantai pulau parkir adalah kondisi wajar -> status WAJIB "sesuai" (LULUS / HIJAU).
   - DILARANG memberi status "tidak_sesuai" hanya karena area lantai berdebu atau kotor wajar!
   - Hanya beri "tidak_sesuai" jika baut dynabolt hilang/lepas, drat kendur, atau plat dudukan retak/patah.
   - Contoh alasan sesuai: "Baut dynabolt terpasang kencang di plat dudukan mesin."
   - Contoh alasan tidak sesuai: "Baut dynabolt ada yang lepas dan tidak lengkap di plat dudukan."

8. ATURAN KHUSUS PELUMAS SPRING / BEARING (BARRIER GATE):
   - JIKA foto menampilkan bagian dalam mesin barrier gate dengan per spring (pegas) atau bearing/as terlihat di dalam frame, status WAJIB "sesuai" (LULUS / HIJAU).
   - Toleransi kondisi grease dan pencahayaan dalam mesin: jangan mempermasalahkan warna gemuk gelap, grease lama, atau sedikit karat wajar. Yang penting per spring / mekanik barrier kelihatan jelas di dalam mesin.
   - Contoh alasan sesuai: "Per spring dan bearing di dalam mesin kelihatan terpasang dan masih bagus."
   - Hanya beri "tidak_sesuai" jika per spring patah/terlepas atau bagian dalam mesin kosong tanpa komponen mekanik.

9. ATURAN KHUSUS SPEEDBUMP GATE (BARRIER GATE):
   - Fokus HANYA pada kondisi fisik karet speed bump di jalan.
   - DILARANG mengecek, menghitung, atau mempermasalahkan baut dynabolt kecil di aspal jalan (abaikan baut)!
   - JIKA karet speed bump terpasang di jalan, fisik utuh, tidak sobek, dan tidak hancur, status WAJIB "sesuai" (LULUS / HIJAU). Debu dan jejak ban kendaraan adalah wajar.
   - Hanya beri "tidak_sesuai" jika karet speed bump robek, pecah/hancur berantakan, terlepas dari jalan, atau kotor ekstrem tertimbun lumpur/sampah tebal.
   - Contoh alasan sesuai: "Karet speed bump terpasang utuh dan rata di jalan gate."
   - Contoh alasan tidak sesuai: "Karet speed bump robek dan fisik karet pecah."

10. ATURAN KHUSUS DEBU CPU & PASTA PROCESSOR (SERVER & KASIR):
   - Fokus HANYA pada kebersihan bagian dalam casing CPU (kipas pendingin, motherboard, dan heatsink bebas dari gumpalan debu tebal).
   - JIKA bagian dalam casing CPU terlihat terbuka, kipas dan motherboard bersih dari debu, status WAJIB "sesuai" (LULUS / HIJAU).
   - DILARANG menuntut atau mempermasalahkan pasta processor harus terlihat langsung! Melepas heatsink processor setiap maintenance rutin tidak diwajibkan karena berisiko merusak pin/heatsink di lapangan.
   - Hanya beri "tidak_sesuai" jika kipas CPU, motherboard, atau kisi heatsink tertutup tumpukan debu tebal/kotor berkerak.
   - Contoh alasan sesuai: "Bagian dalam CPU bersih dan kipas bebas debu."
   - Contoh alasan tidak sesuai: "Kipas CPU dan motherboard kotor dengan tumpukan debu tebal."

11. ATURAN KHUSUS MATIKAN UPDATE, ANTIVIRUS & FIREWALL (SERVER & KASIR):
   - Toleransi resolusi layar monitor kasir/server: teknisi memfoto layar monitor yang menampilkan jendela pengaturan keamanan.
   - JIKA foto menampilkan minimal 1-2 indikator utama nonaktif (misal Windows Security Real-time Protection status OFF/silang merah, atau Firewall OFF/inactive, atau di Linux terminal `ufw status: inactive` / firewalld dead), status WAJIB "sesuai" (LULUS / HIJAU).
   - DILARANG memberi status "tidak_sesuai" hanya karena ketiga jendela tidak muat berjajar di satu layar monitor kecil! Cukup ada bukti proteksi/firewall nonaktif.
   - Hanya beri "tidak_sesuai" jika indikator proteksi jelas aktif (misal Real-time protection ON centang hijau, atau Firewall aktif memblokir jaringan pos).
   - Contoh alasan sesuai: "Antivirus dan firewall sudah dimatikan (OFF)."
   - Contoh alasan tidak sesuai: "Windows Defender Real-time Protection masih aktif."

12. ATURAN KHUSUS STORAGE DRIVE C & FILE TEMP (SERVER & KASIR):
   - Toleransi moire/garis layar monitor dan tata letak jendela:
   - JIKA foto menampilkan File Explorer / "This PC" dengan bar kapasitas Drive C: berwarna BIRU (indikator sisa kapasitas aman >15-20 GB) ATAU di Linux terminal menampilkan perintah `df -h` dengan Use% partisi root <80%, status WAJIB "sesuai" (LULUS / HIJAU).
   - DILARANG menolak atau memberi status tidak sesuai hanya karena jendela folder temp tidak terlihat di foto (folder temp biasanya sudah dihapus/dibersihkan sebelum jendela ditutup).
   - Hanya beri "tidak_sesuai" jika bar kapasitas Drive C: berwarna MERAH (kritis hampir penuh) atau sisa free space <10 GB.
   - Contoh alasan sesuai: "Kapasitas Drive C aman indikator biru dan storage lega."
   - Contoh alasan tidak sesuai: "Kapasitas Drive C kritis indikator merah dan sisa storage menipis."

13. ATURAN KHUSUS PERKABELAN (KABEL BELAKANG CPU, PORT USB, DAN SEMUA POIN YANG MEMOTRET KABEL):
   - Di bagian belakang PC kasir dan server memang terdapat banyak kabel perangkat (kabel power, LAN, VGA/HDMI, USB scanner, tap reader, printer). Kabel yang turun/menggantung dari port ke bawah karena gravitasi adalah kondisi NORMAL, BUKAN temuan.
   - DEFAULT poin kabel adalah "sesuai" (LULUS / HIJAU). Kabel yang tersambung ke port, jalurnya jelas, dan tidak kusut WAJIB "sesuai", walau tanpa cable tie, walau kabelnya menggantung/menjuntai wajar, walau jumlahnya banyak, dan walau ada debu wajar.
   - DILARANG memakai kata "menjuntai" sebagai alasan temuan. DILARANG memberi "perlu_cek_manual" untuk poin kabel hanya karena ragu soal kerapian; kalau ragu, pilih "sesuai".
   - Beri "tidak_sesuai" (MERAH) HANYA jika kabel jelas berantakan: kusut melilit seperti benang kusut, bertumpuk semrawut di lantai/jalur kaki, kabel terkelupas/terbakar, atau konektor USB/LAN/power kendur hampir lepas.
   - Contoh alasan sesuai: "Kabel belakang CPU tersambung rapi dan port USB kencang."
   - Contoh alasan tidak sesuai: "Kabel belakang CPU kusut melilit dan menumpuk di lantai."

14. ATURAN KHUSUS KEYBOARD, MOUSE & PING JARINGAN (SERVER & KASIR):
   - Uji Keyboard & Mouse: Segala bentuk tampilan tes ketikan pada jendela Notepad / Terminal Console (misal deretan huruf/angka) atau tuts aktif pada browser KeyTest.com adalah bukti sah keyboard & mouse merespon normal -> status WAJIB "sesuai" (LULUS / HIJAU).
   - Koneksi Jaringan: Tampilan layar Command Prompt (CMD) atau terminal Linux dengan hasil ping lancar (terdapat baris `Reply from ...` dengan time <10ms dan `0% loss` / tanpa RTO) adalah bukti sah koneksi jaringan lancar -> status WAJIB "sesuai" (LULUS / HIJAU).
   - Contoh alasan sesuai: "Keyboard dan mouse normal, hasil tes ketikan kelihatan jelas."
   - Contoh alasan sesuai (ping): "Hasil ping stabil 0% loss koneksi bebas RTO."
   - Hanya beri "tidak_sesuai" jika layar CMD penuh pesan "Request timed out" (RTO) atau Packet Loss tinggi.

15. ATURAN KHUSUS FISIK PALANG TERTUTUP vs TERBUKA (BARRIER GATE):
   - Ini DUA checkpoint berbeda dan kalimat alasannya WAJIB BEDA. Dilarang memakai kalimat yang sama untuk keduanya.
   - Checkpoint "Fisik Palang Tertutup Lurus" = palang TURUN menutup jalan (posisi mendatar / 0°).
     * Contoh sesuai: "Palang turun rata menutup jalan dan bautnya kencang."
     * Contoh tidak sesuai: "Palang tertutup tidak rata, ujungnya miring ke kanan dan bautnya kendor."
   - Checkpoint "Fisik Palang Terbuka" = palang NAIK/terbuka penuh (tegak / 90°, lancar tanpa macet).
     * Contoh sesuai: "Palang naik tegak waktu dibuka dan gerakannya lancar."
     * Contoh tidak sesuai: "Palang terbuka tidak sampai tegak dan macet di tengah."
   - WAJIB sebut arah palangnya (turun/menutup atau naik/terbuka) supaya supervisor tidak tertukar antara gate IN dan gate OUT.

16. ATURAN KHUSUS PEMBERSIHAN KIPAS ANGIN (POS KASIR):
   - Fokus HANYA pada kebersihan baling-baling dan cover penutup (jaring/grill) kipas angin di dalam pos. Ini BUKAN poin kelengkapan item pos.
   - JIKA baling-baling dan cover kipas tampak bersih tanpa debu tebal, status WAJIB "sesuai" (LULUS / HIJAU).
   - Beri "tidak_sesuai" jika baling-baling atau cover kipas tertutup debu tebal, kotor menghitam, atau cover penutup tidak terpasang.
   - Contoh alasan sesuai: "Baling-baling dan cover kipas angin bersih bebas debu."
   - Contoh alasan tidak sesuai: "Baling-baling kipas angin berdebu tebal dan cover depan kotor menghitam."

OUTPUT STRICT JSON ONLY:
{"status":"sesuai"|"tidak_sesuai"|"perlu_cek_manual","confidenceScore":95,"alasan":"...","poinLolos":["..."],"poinGagal":["..."]}
''';
  }
  static VerificationStatus _resolveStatusToken(String raw) {
    final normalized = raw
        .toLowerCase()
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .trim()
        .replaceAll(RegExp(r'[\s\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    const exactSesuai = {
      'sesuai',
      'lolos',
      'pass',
      'passed',
      'approve',
      'approved',
      'ok',
      'aman',
      'hijau',
    };
    const exactTidakSesuai = {
      'tidak_sesuai',
      'tidak_lolos',
      'gagal',
      'fail',
      'failed',
      'reject',
      'rejected',
      'merah',
    };
    const exactManual = {
      'perlu_cek_manual',
      'cek_manual',
      'manual',
      'ragu',
      'kuning',
    };

    if (exactSesuai.contains(normalized)) return VerificationStatus.sesuai;
    if (exactTidakSesuai.contains(normalized)) {
      return VerificationStatus.tidakSesuai;
    }
    if (exactManual.contains(normalized)) {
      return VerificationStatus.perluCekManual;
    }

    if (normalized.contains('perlu_cek_manual') ||
        normalized.contains('cek_manual') ||
        normalized.contains('manual')) {
      return VerificationStatus.perluCekManual;
    }
    if (normalized.contains('tidak_sesuai') ||
        normalized.contains('tidak_lolos') ||
        normalized.contains('gagal') ||
        normalized.contains('fail') ||
        normalized.contains('reject') ||
        normalized.contains('not_sesuai') ||
        normalized.contains('not_pass')) {
      return VerificationStatus.tidakSesuai;
    }
    if (normalized.contains('sesuai') ||
        normalized.contains('lolos') ||
        normalized.contains('pass') ||
        normalized.contains('approve')) {
      return VerificationStatus.sesuai;
    }
    return VerificationStatus.perluCekManual;
  }

  static bool _hasKnownStatusToken(String rawStatus) {
    final normalized = rawStatus
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[\s\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (normalized.isEmpty) return false;

    const exactTokens = {
      'sesuai',
      'lolos',
      'pass',
      'passed',
      'approve',
      'approved',
      'ok',
      'aman',
      'hijau',
      'tidak_sesuai',
      'tidak_lolos',
      'gagal',
      'fail',
      'failed',
      'reject',
      'rejected',
      'merah',
      'perlu_cek_manual',
      'cek_manual',
      'manual',
      'ragu',
      'kuning',
    };
    if (exactTokens.contains(normalized)) return true;

    return normalized.contains('perlu_cek_manual') ||
        normalized.contains('cek_manual') ||
        normalized.contains('manual') ||
        normalized.contains('tidak_sesuai') ||
        normalized.contains('tidak_lolos') ||
        normalized.contains('gagal') ||
        normalized.contains('fail') ||
        normalized.contains('reject') ||
        normalized.contains('not_sesuai') ||
        normalized.contains('not_pass') ||
        normalized.contains('sesuai') ||
        normalized.contains('lolos') ||
        normalized.contains('pass') ||
        normalized.contains('approve');
  }

  static String _extractJsonCandidate(String rawContent) {
    String sanitized = rawContent.trim();
    if (sanitized.contains('```json')) {
      final start = sanitized.indexOf('```json') + 7;
      final end = sanitized.indexOf('```', start);
      if (end != -1) {
        sanitized = sanitized.substring(start, end).trim();
      } else {
        sanitized = sanitized.substring(start).trim();
      }
    } else if (sanitized.contains('```')) {
      final start = sanitized.indexOf('```') + 3;
      final end = sanitized.indexOf('```', start);
      if (end != -1) {
        sanitized = sanitized.substring(start, end).trim();
      } else {
        sanitized = sanitized.substring(start).trim();
      }
    }

    if (sanitized.contains('{')) {
      final start = sanitized.indexOf('{');
      final end = sanitized.lastIndexOf('}');
      if (end != -1 && end > start) {
        sanitized = sanitized.substring(start, end + 1).trim();
      } else {
        sanitized = sanitized.substring(start).trim();
      }
    }
    return sanitized;
  }

  static AiVerificationResult? _parseStrictAiJsonResponse(
    String rawContent,
    List<String> criteria,
    AiVisionConfig config, {
    String? extraContext,
    bool? isMaintenance,
  }) {
    try {
      final sanitized = _extractJsonCandidate(rawContent);
      final decoded = jsonDecode(sanitized);
      if (decoded is! Map) return null;
      final jsonMap = Map<String, dynamic>.from(decoded);

      final rawStatus = jsonMap['status'] as String? ?? '';
      if (!_hasKnownStatusToken(rawStatus)) {
        return null;
      }
      VerificationStatus status = _resolveStatusToken(rawStatus);

      final rawAlasan = jsonMap['alasan'] as String? ??
          jsonMap['reason'] as String? ??
          'Evaluasi selesai.';
      final alasan = cleanTechnicianReason(rawAlasan);

      final rawPoinGagal = jsonMap['poinGagal'] as List<dynamic>? ??
          jsonMap['poin_gagal'] as List<dynamic>? ??
          [];
      final poinGagal = <String>[];
      final poinGagalUnik = <String>{};
      for (final e in rawPoinGagal) {
        final rawItem = e.toString().trim();
        if (SopCriteriaHelper.isNegatedOrPlaceholderCriterion(rawItem)) {
          continue;
        }
        final kalimat = SopCriteriaHelper.toNegativeStatement(rawItem).trim();
        if (kalimat.isEmpty) continue;
        if (poinGagalUnik.add(kalimat.toLowerCase())) poinGagal.add(kalimat);
      }

      final rawPoinLolos = jsonMap['poinLolos'] as List<dynamic>? ??
          jsonMap['poin_lolos'] as List<dynamic>? ??
          [];
      final poinLolos = rawPoinLolos.map((e) => e.toString()).toList();

      final rawConf = jsonMap['confidenceScore'] ??
          jsonMap['confidence_score'] ??
          jsonMap['confidence'];
      double conf = 0.85;
      if (rawConf is num) {
        conf = rawConf > 1.0 ? rawConf / 100.0 : rawConf.toDouble();
      }

      if (poinGagal.isNotEmpty &&
          status != VerificationStatus.perluCekManual) {
        status = VerificationStatus.tidakSesuai;
      } else if (poinGagal.isEmpty && status == VerificationStatus.tidakSesuai) {
        poinGagal.add('Kriteria SOP belum terpenuhi');
      }

      final rawCount = jsonMap['personCount'] ??
          jsonMap['person_count'] ??
          jsonMap['jumlahPersonel'];
      int? personCount;
      if (rawCount is num) personCount = rawCount.toInt();
      final kategori = jsonMap['briefingKategori'] as String? ??
          jsonMap['kategori'] as String?;
      String? finalKategori = kategori;
      if (finalKategori == null && personCount != null) {
        finalKategori = personCount < 5 ? 'kecil' : 'besar';
      }

      return AiVerificationResult(
        status: status,
        alasan: alasan,
        poinGagal: poinGagal,
        poinLolos: poinLolos,
        confidenceScore: conf,
        providerName: 'Google Gemini',
        personCount: personCount,
        briefingKategori: finalKategori,
      );
    } catch (_) {
      return null;
    }
  }

  static AiVerificationResult? parseAiJsonResponseForTest(
    String rawContent,
    List<String> criteria,
    AiVisionConfig config, {
    String? extraContext,
    bool? isMaintenance,
  }) {
    return _parseAiJsonResponse(
      rawContent,
      criteria,
      config,
      extraContext: extraContext,
      isMaintenance: isMaintenance,
    );
  }

  static AiVerificationResult? _parseAiJsonResponse(
    String rawContent,
    List<String> criteria,
    AiVisionConfig config, {
    String? extraContext,
    bool? isMaintenance,
  }) {
    final strict = _parseStrictAiJsonResponse(
      rawContent,
      criteria,
      config,
      extraContext: extraContext,
      isMaintenance: isMaintenance,
    );
    if (strict != null) return strict;

    return _parseFreeTextFallback(
      rawContent,
      criteria,
      config,
      extraContext: extraContext,
      isMaintenance: isMaintenance,
    );
  }

  static String _sanitizeFallbackReason(String raw) {
    var cleaned = raw.trim();
    cleaned = cleaned
        .replaceAll(RegExp(r'```(?:json)?', caseSensitive: false), '')
        .trim();
    if (cleaned.startsWith('{') && cleaned.endsWith('}')) {
      cleaned = cleaned.substring(1, cleaned.length - 1).trim();
    }
    final lower = cleaned.toLowerCase();
    if (cleaned.contains('{') ||
        cleaned.contains('}') ||
        cleaned.contains('```') ||
        lower.contains('"status"') ||
        lower.contains('status:') ||
        lower.contains('json') ||
        cleaned.isEmpty) {
      return '$kErrorUnverifiablePhoto. Hasil AI tidak terbaca, silakan cek manual.';
    }
    if (cleaned.length > 200) {
      cleaned = '${cleaned.substring(0, 200).trim()}...';
    }
    final result = cleanTechnicianReason(cleaned);
    final resultLower = result.toLowerCase();
    if (result.contains('{') ||
        result.contains('}') ||
        result.contains('```') ||
        resultLower.contains('"status"') ||
        resultLower.contains('status:') ||
        resultLower.contains('json')) {
      return '$kErrorUnverifiablePhoto. Hasil AI tidak terbaca, silakan cek manual.';
    }
    return result;
  }

  static bool _isMaintenanceFallbackContext(
    String lowerText,
    List<String> criteria,
  ) {
    final joinedCriteria = criteria.join(' ').toLowerCase();
    final hasGroomingCriteria = joinedCriteria.contains('seragam') ||
        joinedCriteria.contains('id card') ||
        joinedCriteria.contains('name tag') ||
        joinedCriteria.contains('sepatu');
    if (!hasGroomingCriteria && criteria.isNotEmpty) {
      return true;
    }
    return RegExp(
      r'\b(cpu|motherboard|heatsink|barrier|palang|manless|dispenser|printer|dynabolt|dinabolt|loop\s+detector|pos\s+kasir|booth|stopkontak|avometer)\b',
    ).hasMatch(lowerText);
  }

  static AiVerificationResult _parseFreeTextFallback(
    String rawContent,
    List<String> criteria,
    AiVisionConfig config, {
    String? extraContext,
    bool? isMaintenance,
  }) {
    // 1. Jika JSON terpotong (finish_reason=length), pulihkan field "status" dan "alasan"
    final statusFieldMatch = RegExp(
      r'"status"\s*:\s*"([^"]+)"',
      caseSensitive: false,
    ).firstMatch(rawContent);
    if (statusFieldMatch != null) {
      final recoveredStatus = _resolveStatusToken(statusFieldMatch.group(1)!);
      final alasanMatch = RegExp(
        r'"(?:alasan|reason)"\s*:\s*"([^"]*)',
        caseSensitive: false,
      ).firstMatch(rawContent);
      var recoveredAlasan = alasanMatch != null &&
              alasanMatch.group(1)!.trim().isNotEmpty
          ? cleanTechnicianReason(alasanMatch.group(1)!)
          : 'Evaluasi selesai';
      if (recoveredAlasan.startsWith('{') ||
          recoveredAlasan.contains('"status"') ||
          recoveredAlasan.contains('```')) {
        recoveredAlasan =
            '$kErrorUnverifiablePhoto. Hasil AI tidak terbaca, silakan cek manual.';
      }
      return AiVerificationResult(
        status: recoveredStatus,
        alasan: recoveredAlasan,
        poinGagal: recoveredStatus == VerificationStatus.tidakSesuai
            ? const ['Kriteria SOP belum terpenuhi']
            : const [],
        poinLolos: recoveredStatus == VerificationStatus.sesuai
            ? criteria.map(SopCriteriaHelper.toPositiveStatement).toList()
            : const [],
        confidenceScore: 0.75,
        providerName: 'Google Gemini',
        isFallback: true,
      );
    }

    final text = rawContent.toLowerCase();
    final isMaint = isMaintenance ??
        (extraContext != null || _isMaintenanceFallbackContext(text, criteria));

    // Hapus klausa kualitas yang dinegasi ("not blurry", "tidak blur", "tidak gelap", dll.)
    // sebelum mencocokkan qualityKeywords.
    final textWithoutNegatedQuality = text.replaceAll(
      RegExp(
        r'\b(not|no|never|without|tidak|bukan|tanpa|bebas)\s+(?:too\s+|very\s+|terlalu\s+|agak\s+|sedikit\s+|cukup\s+)?(motion[\s-]blurred|motion\s+blur|blurred|blurry|blur|buram|kabur|goyang|out[\s-]of[\s-]focus|unfocused|indistinct|tilted|crooked|slanted|not\s+level|dark|gelap|miring)\b',
      ),
      ' ',
    );

    final qualityKeywords = [
      'motion-blurred',
      'motion blurred',
      'motion blur',
      'blurred',
      'too blurry',
      'blurry',
      'blur',
      'buram',
      'kabur',
      'goyang',
      'out of focus',
      'out-of-focus',
      'unfocused',
      'kurang fokus',
      'tidak fokus',
      'indistinct',
      'tilted',
      'crooked',
      'slanted',
      'not level',
      'too dark',
      'terlalu gelap',
      'agak gelap',
      'gelap',
      'miring',
      'incomplete image',
    ];

    if (qualityKeywords.any((kw) => textWithoutNegatedQuality.contains(kw))) {
      if (isMaint) {
        final sanitizedReason = _sanitizeFallbackReason(rawContent);
        return AiVerificationResult(
          status: VerificationStatus.perluCekManual,
          alasan: sanitizedReason,
          poinGagal: const [],
          poinLolos: const [],
          confidenceScore: 0.6,
          providerName: 'Google Gemini',
          isFallback: true,
        );
      }
      return AiVerificationResult(
        status: VerificationStatus.tidakSesuai,
        alasan: 'Foto blur atau miring, wajib foto ulang',
        poinGagal: const [
          'Foto blur, miring, atau tidak fokus, wajib foto ulang',
        ],
        poinLolos: const [],
        confidenceScore: 0.6,
        providerName: 'Google Gemini',
        isFallback: true,
      );
    }

    final unverifiableKeywords = [
      'obscure',
      'no details',
      'no detail',
      'no readable',
      'no visible',
      'unreadable',
      'no text',
      'cannot read',
      "can't read",
      'too small',
      'cannot identify',
      "can't identify",
      'unable to',
      'no facial',
      'no badge',
      'no uniform',
      'no person',
      'no personnel',
      'no identification',
    ];

    final isUnverifiable =
        unverifiableKeywords.any((kw) => text.contains(kw));

    if (isUnverifiable) {
      final sanitizedReason = _sanitizeFallbackReason(rawContent);
      final finalAlasan = sanitizedReason ==
              '$kErrorUnverifiablePhoto. Hasil AI tidak terbaca, silakan cek manual.'
          ? sanitizedReason
          : '$kErrorUnverifiablePhoto: $sanitizedReason';
      return AiVerificationResult(
        status: VerificationStatus.perluCekManual,
        alasan: finalAlasan,
        poinGagal: const [],
        poinLolos: const [],
        confidenceScore: 0.5,
        providerName: 'Google Gemini',
        isFallback: true,
      );
    }

    int matchCount = 0;
    for (final c in criteria) {
      final cl = c.toLowerCase();
      final candidates = <String>[
        cl,
        cl.replaceAll('seragam resmi bss parking', ''),
        cl.replaceAll('standar', ''),
        cl.replaceAll('wajib', ''),
        cl.replaceAll('resmi bss parking', 'bss parking'),
        if (cl.contains('seragam')) 'uniform',
        if (cl.contains('id card') || cl.contains('name tag')) 'name tag',
        if (cl.contains('id card') || cl.contains('name tag')) 'badge',
        if (cl.contains('id card') || cl.contains('name tag') || cl.contains('jelas')) 'visible',
        if (cl.contains('sepatu')) 'shoes',
        if (cl.contains('postur') || cl.contains('sikap') || cl.contains('rapi')) 'posture',
        if (cl.contains('rapi')) 'neat',
      ].where((s) => s.trim().isNotEmpty).toList();

      if (candidates.any((cand) => text.contains(cand))) {
        matchCount++;
      }
    }

    final hasExplicitPositiveProse = RegExp(
      r'\b(uniform\s+is\s+neat|photo\s+is\s+clear|all\s+criteria\s+met|semua\s+kriteria\s+terpenuhi)\b',
    ).hasMatch(text);

    if ((matchCount >= (criteria.length / 2).ceil() && criteria.isNotEmpty) ||
        hasExplicitPositiveProse) {
      final sanitizedReason = _sanitizeFallbackReason(rawContent);
      return AiVerificationResult(
        status: VerificationStatus.sesuai,
        alasan: sanitizedReason ==
                '$kErrorUnverifiablePhoto. Hasil AI tidak terbaca, silakan cek manual.'
            ? 'Evaluasi selesai'
            : sanitizedReason,
        poinGagal: const [],
        poinLolos:
            criteria.map(SopCriteriaHelper.toPositiveStatement).toList(),
        confidenceScore: 0.7,
        providerName: 'Google Gemini',
        isFallback: true,
      );
    }

    final truncatedRaw = rawContent.length > 300
        ? rawContent.substring(0, 300)
        : rawContent;
    debugPrint('[BSS-Vision] Unparsed AI response: $truncatedRaw');

    return AiVerificationResult(
      status: VerificationStatus.perluCekManual,
      alasan:
          '$kErrorUnverifiablePhoto. Hasil AI tidak terbaca, silakan cek manual.',
      poinGagal: const [],
      poinLolos: const [],
      confidenceScore: 0.4,
      providerName: 'Google Gemini',
      isFallback: true,
    );
  }
}
