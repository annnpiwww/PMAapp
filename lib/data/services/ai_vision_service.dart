import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/ai_vision_config.dart';
import '../models/submission_model.dart';
import '../models/template_model.dart';
import 'storage_service.dart';

class AiConnectionTestResult {
  final bool isSuccess;
  final String message;
  final int? latencyMs;
  final String? modelUsed;

  AiConnectionTestResult({
    required this.isSuccess,
    required this.message,
    this.latencyMs,
    this.modelUsed,
  });
}

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
  bool get isRejected => status == VerificationStatus.tidakSesuai;
  bool get isManualReview => status == VerificationStatus.perluCekManual;

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
  static String toNegativeStatement(String criterion) {
    final lower = criterion.toLowerCase();
    if (lower.contains('seragam') && lower.contains('dimasukkan')) {
      return 'Seragam tidak dimasukkan dalam celana / diluar dan tidak rapi';
    } else if (lower.contains('seragam')) {
      return 'Tidak menggunakan seragam resmi BSS Parking / seragam tidak rapi dan tidak terkancing';
    } else if (lower.contains('lanyard') || lower.contains('yoyo') || lower.contains('id card') || lower.contains('name tag')) {
      return 'ID Card / Name Tag tidak terpasang di saku atau dada';
    } else if (lower.contains('peluit')) {
      return 'Peluit biru bertali tidak terpasang di leher atau dada';
    } else if (lower.contains('topi')) {
      return 'Topi dinas BSS tidak digunakan';
    } else if (lower.contains('pin smile')) {
      return 'Pin smile tidak terpasang di dada sebelah kanan';
    } else if (lower.contains('rambut') || lower.contains('jilbab') || lower.contains('grooming')) {
      return 'Grooming tidak rapi (rambut atau jilbab melebihi standar BSS)';
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
      return 'Terdapat karat atau korosi pada perangkat';
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
    text = text.replaceAll(RegExp(r'dalam kondisi optimal', caseSensitive: false), 'kondisi baik dan normal');
    text = text.replaceAll(RegExp(r'memiliki integritas struktural', caseSensitive: false), 'terpasang dengan kokoh');
    text = text.replaceAll(RegExp(r'permukaan mengalami degradasi', caseSensitive: false), 'permukaan mulai rusak');
    text = text.replaceAll(RegExp(r'sesuai standar operasional', caseSensitive: false), 'berfungsi normal');
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
      if (trimmed.length >= 10) {
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

  static Future<void> updateConfig(AiVisionConfig config) async {
    _cachedConfig = config;
    await StorageService.saveAiVisionConfig(config);
  }

  static List<String> filterCriteriaByConfig(
      List<String> criteria, AiVisionConfig config) {
    return criteria.where((c) {
      final cl = c.toLowerCase();
      if ((cl.contains('seragam') ||
              cl.contains('rambut') ||
              cl.contains('jilbab') ||
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

  static Future<AiConnectionTestResult> testConnection(
      AiVisionConfig config) async {
    final effectiveApiKey = config.apiKey.trim().isNotEmpty
        ? config.apiKey.trim()
        : AiVisionConfig.defaultApiKey.trim();

    if (effectiveApiKey.isEmpty) {
      return AiConnectionTestResult(
        isSuccess: false,
        message: 'API Key AI belum dikonfigurasi. Masukkan API Key di Pengaturan.',
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      final uri = Uri.parse('${config.effectiveBaseUrl}/chat/completions');
      final testPayload = <String, dynamic>{
        'model': config.effectiveModelName,
        'messages': [
          {'role': 'user', 'content': 'ping'}
        ],
        'max_tokens': 5,
      };
      if (config.effectiveModelName.contains('3.1') ||
          config.effectiveModelName.contains('reasoning') ||
          config.effectiveModelName.contains('thinking')) {
        testPayload['reasoning_effort'] = 'none';
      }

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $effectiveApiKey',
            },
            body: jsonEncode(testPayload),
          )
          .timeout(const Duration(seconds: AiVisionConfig.perModelTimeoutSeconds));

      stopwatch.stop();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return AiConnectionTestResult(
          isSuccess: true,
          message:
              'Koneksi berhasil (${stopwatch.elapsedMilliseconds}ms) menggunakan model ${config.effectiveModelName}',
          latencyMs: stopwatch.elapsedMilliseconds,
          modelUsed: config.effectiveModelName,
        );
      } else {
        return AiConnectionTestResult(
          isSuccess: false,
          message: 'Gagal HTTP ${response.statusCode}: ${response.body}',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      }
    } catch (e) {
      stopwatch.stop();
      return AiConnectionTestResult(
        isSuccess: false,
        message: 'Koneksi error: $e',
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    }
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

    // Root QA SPV Bypass (Auto-Ijo untuk Testing Farhan Lakoro)
    // SEC-02: bypass hanya diizinkan pada debug build; di release diblokir & di-log.
    if (StorageService.isSpvQaBypassActive()) {
      assert(kDebugMode, 'SPV QA bypass must only be active in debug builds');
      if (!kDebugMode) {
        debugPrint('[SECURITY][SEC-02] SPV QA bypass attempt blocked in release mode');
      } else {
        return AiVerificationResult(
          status: VerificationStatus.sesuai,
          alasan: '⚡ Root QA SPV: AI Absensi dibypass otomatis (Mode Testing Farhan Lakoro).',
          poinGagal: [],
          poinLolos: criteria.map(SopCriteriaHelper.toPositiveStatement).toList(),
          confidenceScore: 1.0,
          providerName: 'Root QA Engine (SPV Farhan)',
          isFallback: false,
        );
      }
    }

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
        providerName: 'Google Gemini (${config.effectiveModelName})',
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

  /// Briefing dengan counting: AI hitung jumlah orang dan klasifikasi kecil/besar.
  static Future<AiVerificationResult> verifyBriefing({
    required TemplateModel template,
    required String? imageBase64,
    AiVisionConfig? customConfig,
  }) async {
    final config = customConfig ?? getConfig();
    final criteria = filterCriteriaByConfig(template.sopCriteria, config);
    if (imageBase64 == null || imageBase64.isEmpty) {
      return AiVerificationResult(
        status: VerificationStatus.tidakSesuai,
        alasan: 'Foto briefing kosong',
        poinGagal: ['Foto tidak ada'],
        poinLolos: [],
        confidenceScore: 1.0,
        providerName: 'Google Gemini (${config.effectiveModelName})',
      );
    }
    return _runCustomEndpointVerification(
      imageBase64: imageBase64,
      criteria: criteria,
      config: config,
      isBriefingCountMode: true,
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
    final effectiveApiKey = config.apiKey.trim().isNotEmpty
        ? config.apiKey.trim()
        : AiVisionConfig.defaultApiKey.trim();

    if (effectiveApiKey.isEmpty) {
      return AiVerificationResult(
        status: VerificationStatus.perluCekManual,
        alasan: 'API Key AI belum dikonfigurasi. Foto dialihkan untuk Cek Manual oleh Supervisor.',
        poinGagal: ['API Key AI Belum Dikonfigurasi'],
        poinLolos: [],
        confidenceScore: 0.0,
        providerName: 'Google Gemini',
      );
    }

    final uri = Uri.parse('${config.effectiveBaseUrl}/chat/completions');
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
      systemPrompt = '''
You are BSS-Vision, expert technical maintenance auditor for BSS Parking (Bahana Sulut Sentosa).
Task: Audit SINGLE maintenance point from hardware/infrastructure photo using NATURAL TECHNICIAN LANGUAGE.

CONTEXT: $extraContext
CRITERIA: $criteriaListStr

PANDUAN GAYA BAHASA TEKNISI LAPANGAN (NATURAL TECHNICIAN LANGUAGE):
Prinsip: "Teknisi melihat kondisi langsung di lapangan -> Teknisi menulis hasil pengecekan secara singkat, jelas, dan natural."
Bukan seperti hasil generate AI atau laporan audit akademis yang kaku!

1. POLA PENULISAN:
   [Objek] + [kondisi yang terlihat] + [detail masalah jika ada].

2. KOSAKATA NATURAL YANG WAJIB DIPRIORITASKAN:
   - "tampak kotor", "tampak berdebu", "terdapat tumpukan debu"
   - "kabel kurang rapi", "kabel perlu dirapikan dengan cable tie", "kabel belum tertata rapi"
   - "terdapat korosi", "terdapat karat", "plat besi berkarat", "terdapat kerusakan fisik"
   - "stiker tampak kusam", "stiker terkelupas", "stiker rusak"
   - "cat tampak pudar", "lantai pulau gate berdebu", "permukaan pulau gate kotor"
   - "terdapat sisa material", "terdapat bekas stiker"
   - "terpasang dengan kokoh", "berfungsi normal", "tercetak dengan baik", "bersih dan bebas debu"

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
     * Contoh: "Palang terpasang lurus dan baut pengikat kencang."
     * Contoh: "Per spring dan bearing terlumasi grease baru."
     * Contoh: "Kapasitas Drive C aman (>20GB) dan folder temp bersih."
   - TIDAK_SESUAI (Temuan/Merah): Langsung sebut objek dan masalah fisiknya, to the point tanpa basa-basi (6-14 kata).
     * Format: [Objek] + [kondisi: kotor / berkarat / pudar / rusak / retak / kendor] + [lokasi].
     * JANGAN: "Baut dynabolt terpasang kokoh, namun area dudukan kotor" (SALAH: bertele-tele).
     * GUNAKAN: "Area dudukan mesin kotor dan banyak tumpukan debu." (BENAR: langsung to the point).
     * Contoh Kotor: "Head printer kotor dan ada sisa robekan kertas di dalam printer."
     * Contoh Berkarat: "Baut dynabolt berkarat dan plat dudukan mesin mulai korosi."
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
   - Contoh alasan sesuai: "Jalur kabel sensor tertanam rapi di bawah paving block dan permukaan rata." ATAU "Jalur coran kabel sensor tertutup rapi dan tidak ada kabel mencuat."
   - Hanya beri "tidak_sesuai" jika paving/aspal amblas parah, bongkaran rusak, atau ada kabel fisik yang terkelupas/mencuat keluar ke permukaan.

6. ATURAN KHUSUS STANDARISASI ITEM DALAM POS (POS KASIR):
   - Fokus utama poin ini adalah KELENGKAPAN ITEM DALAM POS: Monitor, Keyboard, Mouse, Scanner, Printer, dan Kipas Angin.
   - JIKA item di atas terlihat ada di meja pos, status WAJIB "sesuai" (LULUS / HIJAU).
   - DILARANG memberi status "tidak_sesuai" atau "perlu_cek_manual" hanya karena meja tampak kusam, cat meja terkelupas, serat kayu terlihat, atau ada debu wajar pada meja! Itu kondisi keausan meja lama, BUKAN masalah item pos.
   - Cukup dengan adanya item utama (monitor, keyboard, scanner, printer, kipas angin), status LANGSUNG HIJAU.
   - Contoh alasan sesuai: "Item dalam pos lengkap: monitor, keyboard, scanner, printer, dan kipas angin ada."
   - Hanya beri "tidak_sesuai" jika item utama tidak ada sama sekali atau pos kosong.

7. ATURAN KHUSUS DUDUKAN MESIN & BAUT DYNABOLT (BARRIER GATE):
   - Fokus HANYA pada baut dynabolt dan plat baseplate dudukan mesin: apakah baseplate terpasang kokoh ke lantai/beton.
   - Debu semen, pasir, noda oli jalanan, atau noda cuaca pada lantai pulau parkir adalah kondisi wajar -> status WAJIB "sesuai" (LULUS / HIJAU).
   - DILARANG memberi status "tidak_sesuai" hanya karena area lantai berdebu atau kotor wajar!
   - Hanya beri "tidak_sesuai" jika baut dynabolt hilang/lepas, drat kendur, atau plat baseplate retak/patah.
   - Contoh alasan sesuai: "Baut dynabolt baseplate terpasang kokoh pada dudukan mesin."
   - Contoh alasan tidak sesuai: "Baut dynabolt tidak terpasang lengkap pada baseplate dudukan mesin."

8. ATURAN KHUSUS PELUMAS SPRING / BEARING (BARRIER GATE):
   - JIKA foto menampilkan bagian dalam mesin barrier gate dengan per spring (pegas) atau bearing/as terlihat di dalam frame, status WAJIB "sesuai" (LULUS / HIJAU).
   - Toleransi kondisi grease dan pencahayaan dalam mesin: jangan mempermasalahkan warna gemuk gelap, grease lama, atau sedikit karat wajar. Yang penting per spring / mekanik barrier terdokumentasi jelas di dalam mesin.
   - Contoh alasan sesuai: "Per spring dan bearing mekanik barrier gate terdokumentasi terpasang baik."
   - Hanya beri "tidak_sesuai" jika per spring patah/terlepas atau bagian dalam mesin kosong tanpa komponen mekanik.

9. ATURAN KHUSUS SPEEDBUMP GATE (BARRIER GATE):
   - Fokus HANYA pada kondisi fisik karet speed bump di lajur jalan.
   - DILARANG mengecek, menghitung, atau mempermasalahkan baut dynabolt kecil di aspal jalan (abaikan baut)!
   - JIKA karet speed bump terpasang di lajur, fisik utuh, tidak sobek, dan tidak hancur, status WAJIB "sesuai" (LULUS / HIJAU). Debu dan jejak ban kendaraan adalah wajar.
   - Hanya beri "tidak_sesuai" jika karet speed bump robek, pecah/hancur berantakan, terlepas dari lajur, atau kotor ekstrem tertimbun lumpur/sampah tebal.
   - Contoh alasan sesuai: "Karet speed bump terpasang utuh dan rata di lajur gate."
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
   - Contoh alasan sesuai: "Proteksi antivirus dan firewall dalam status nonaktif."
   - Contoh alasan tidak sesuai: "Windows Defender Real-time Protection masih aktif."

12. ATURAN KHUSUS STORAGE DRIVE C & FILE TEMP (SERVER & KASIR):
   - Toleransi moire/garis layar monitor dan tata letak jendela:
   - JIKA foto menampilkan File Explorer / "This PC" dengan bar kapasitas Drive C: berwarna BIRU (indikator sisa kapasitas aman >15-20 GB) ATAU di Linux terminal menampilkan perintah `df -h` dengan Use% partisi root <80%, status WAJIB "sesuai" (LULUS / HIJAU).
   - DILARANG menolak atau memberi status tidak sesuai hanya karena jendela folder temp tidak terlihat di foto (folder temp biasanya sudah dihapus/dibersihkan sebelum jendela ditutup).
   - Hanya beri "tidak_sesuai" jika bar kapasitas Drive C: berwarna MERAH (kritis hampir penuh) atau sisa free space <10 GB.
   - Contoh alasan sesuai: "Kapasitas Drive C aman indikator biru dan storage lega."
   - Contoh alasan tidak sesuai: "Kapasitas Drive C kritis indikator merah dan sisa storage menipis."

13. ATURAN KHUSUS KABEL BELAKANG CPU & PORT USB (SERVER & KASIR):
   - Di bagian belakang PC kasir dan server terdapat banyak kabel perangkat (kabel power, LAN, VGA/HDMI, USB scanner, tap reader, printer).
   - JIKA kabel belakang CPU terikat (menggunakan cable tie, spiral organizer, atau terikat berkelompok) dan port USB terpasang kencang, status WAJIB "sesuai" (LULUS / HIJAU).
   - DILARANG memberi status "tidak_sesuai" hanya karena jumlah kabel banyak atau ada debu wajar pada ventilasi belakang casing!
   - Hanya beri "tidak_sesuai" jika kabel menjuntai lepas ke lantai tanpa ikatan sama sekali, kabel terkelupas bahaya, atau konektor USB/LAN kendur hampir lepas.
   - Contoh alasan sesuai: "Kabel belakang CPU terikat rapi dan colokan port USB kencang."
   - Contoh alasan tidak sesuai: "Kabel belakang CPU menjuntai semrawut tanpa ikatan pengikat."

14. ATURAN KHUSUS KEYBOARD, MOUSE & PING JARINGAN (SERVER & KASIR):
   - Uji Keyboard & Mouse: Segala bentuk tampilan tes ketikan pada jendela Notepad / Terminal Console (misal deretan huruf/angka) atau tuts aktif pada browser KeyTest.com adalah bukti sah keyboard & mouse merespon normal -> status WAJIB "sesuai" (LULUS / HIJAU).
   - Koneksi Jaringan: Tampilan layar Command Prompt (CMD) atau terminal Linux dengan hasil ping lancar (terdapat baris `Reply from ...` dengan time <10ms dan `0% loss` / tanpa RTO) adalah bukti sah koneksi jaringan lancar -> status WAJIB "sesuai" (LULUS / HIJAU).
   - Contoh alasan sesuai: "Keyboard merespon normal dan teks tes terketik jelas."
   - Contoh alasan sesuai (ping): "Hasil ping stabil 0% loss koneksi bebas RTO."
   - Hanya beri "tidak_sesuai" jika layar CMD penuh pesan "Request timed out" (RTO) atau Packet Loss tinggi.

OUTPUT STRICT JSON ONLY:
{"status":"sesuai"|"tidak_sesuai"|"perlu_cek_manual","confidenceScore":95,"alasan":"...","poinLolos":["..."],"poinGagal":["..."]}
''';
    } else if (absensiKategori == AbsensiKategori.teknisi) {
      final hari = (hariKerja ?? 'SENIN').toUpperCase();
      final isPulang = tipeLaporan == 'Pulang';
      if (isPulang) {
        systemPrompt = '''
You are BSS-Vision. Evaluasi kerapian teknisi untuk absen pulang ($hari).

ATURAN ABSEN PULANG:
1. Foto setengah badan sah dan lulus. Tidak perlu cek sepatu.
2. ID Card atau tali lanyard terpasang di leher/dada. Jika tali lanyard terlihat, status LULUS (sesuai).
3. Mengenakan seragam teknisi resmi atau seragam dinas hari $hari.
4. Gaya bahasa alasan: Singkat, natural, to the point (5-10 kata).
   - Contoh sesuai: "Seragam teknisi rapi dan tali lanyard terpasang."
   - Contoh tidak sesuai: "Tidak memakai seragam resmi dan tanpa ID Card."

STATUS:
- sesuai: Seragam rapi dan ID Card/lanyard terpasang.
- tidak_sesuai: Pakaian non-resmi (kaos oblong/bebas) atau tanpa ID Card/lanyard.
- perlu_cek_manual: Foto sangat blur sehingga seragam tidak terbaca.

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
* Catatan: Seragam Teknisi resmi BSS selalu sah di semua hari (Senin-Minggu).

KRITERIA:
1. Seragam: Seragam Teknisi resmi atau sesuai jadwal hari $hari, dipakai rapi.
2. ID Card / tali lanyard terpasang di dada/leher.
3. Celana panjang dan sepatu tertutup (tidak boleh sandal).
4. Gaya bahasa alasan: Singkat, natural, to the point (5-10 kata).
   - Contoh sesuai: "Seragam teknisi rapi, ID Card dan sepatu terpasang lengkap."
   - Contoh tidak sesuai: "ID Card tidak terpasang di dada."
   - Contoh tidak sesuai: "Memakai sandal, wajib sepatu kerja tertutup."

STATUS:
- sesuai: Seragam rapi, ID Card/lanyard ada, sepatu tertutup.
- tidak_sesuai: Tanpa ID Card, pakai sandal, atau kaos oblong non-resmi.
- perlu_cek_manual: Foto setengah badan (sepatu terpotong) atau foto blur.

OUTPUT STRICT JSON ONLY:
{"status":"sesuai"|"tidak_sesuai"|"perlu_cek_manual","confidenceScore":95,"alasan":"...","poinLolos":["..."],"poinGagal":["..."]}
''';
      }
    } else {
      systemPrompt = '''
You are BSS-Vision. Evaluasi kesesuaian foto terhadap kriteria SOP BSS Parking.

CRITERIA:
$criteriaListStr

ATURAN:
1. Evaluasi atribut dan seragam yang tampak di frame kamera secara objektif.
2. Gunakan bahasa ringkas, padat, to the point (5-10 kata).
   - Contoh sesuai: "Seragam rapi dan atribut lengkap sesuai SOP."
   - Contoh tidak sesuai: "[Sebutkan atribut yang kurang/salah]."
3. Foto setengah badan wajar, nilai atribut yang terlihat.

OUTPUT STRICT JSON ONLY:
{"status":"sesuai"|"tidak_sesuai"|"perlu_cek_manual","confidenceScore":95,"alasan":"...","poinLolos":["..."],"poinGagal":["..."]}
''';
    }

    final userContent = [
      {'type': 'text', 'text': 'Evaluasi foto ini terhadap SOP BSS Parking.'},
      {'type': 'image_url', 'image_url': {'url': formattedImage}},
    ];

    final primaryModel = config.effectiveModelName;
    // Smart Fast Fallback: jika model utama lambat/gangguan, alihkan cepat ke gemini-flash-lite-latest
    final fallbackModel = (primaryModel == 'gemini-3.1-flash-lite')
        ? 'gemini-flash-lite-latest'
        : 'gemini-3.1-flash-lite';
    final candidateModels = [primaryModel, fallbackModel];

    final DateTime budgetStart = DateTime.now();
    final Duration totalBudget =
        const Duration(seconds: AiVisionConfig.totalBudgetSeconds);
    String errorMessage = '';

    const maxAttempts = 2;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (DateTime.now().difference(budgetStart) >= totalBudget) {
        errorMessage = 'Batas waktu ${AiVisionConfig.totalBudgetSeconds}s tercapai';
        break;
      }

      final remaining = totalBudget - DateTime.now().difference(budgetStart);
      if (remaining.inSeconds < 2) break;

      final currentModel =
          candidateModels[attempt.clamp(0, candidateModels.length - 1)];
      final isFallback = currentModel != primaryModel;

      // Timeout ringkas per attempt (default 8s) agar modal segera tampil
      final perModelTimeout = Duration(
        seconds: config.timeoutSeconds.clamp(4, remaining.inSeconds),
      );

      final isRetry = attempt > 0;
      if (isRetry) {
        debugPrint('[BSS-Vision] RETRY/FAILOVER ${attempt + 1}/$maxAttempts ke $currentModel');
      }

      final client = http.Client();
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

        // Bypass CoT reasoning thinking delay 30s pada gemini-3.1 agar inferensi vision instan (<2 detik)
        if (currentModel.contains('3.1') ||
            currentModel.contains('reasoning') ||
            currentModel.contains('thinking')) {
          requestBody['reasoning_effort'] = 'none';
        }

        final response = await client
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $effectiveApiKey',
              },
              body: jsonEncode(requestBody),
            )
            .timeout(perModelTimeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final choices = data['choices'] as List<dynamic>?;
          if (choices != null && choices.isNotEmpty) {
            final rawContent =
                choices[0]['message']?['content'] as String? ?? '{}';
            final parsedResult =
                _parseAiJsonResponse(rawContent, criteria, config);
            if (parsedResult != null) {
              return parsedResult.copyWith(
                providerName: isFallback
                    ? 'Google Gemini ($currentModel - Failover)'
                    : 'Google Gemini ($currentModel)',
              );
            }
            errorMessage = 'Format JSON response tidak sesuai';
            break;
          }
          errorMessage = 'Response dari server kosong';
          break;
        } else {
          errorMessage = 'Server error HTTP ${response.statusCode}';
          debugPrint('[BSS-Vision] HTTP ${response.statusCode} $currentModel: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
          final retryable = [429, 502, 503, 504].contains(response.statusCode);
          if (retryable && attempt == 0 && remaining.inSeconds > 4) {
            await Future.delayed(const Duration(milliseconds: 300));
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
        if ((isTimeout || isSocket) && attempt == 0 && remaining.inSeconds > 4) {
          errorMessage = 'Failover jaringan ($currentModel) -> switch ke $fallbackModel';
          await Future.delayed(const Duration(milliseconds: 300));
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

    if (errorMessage.isEmpty || errorMessage == 'null') {
      errorMessage = 'Koneksi terputus / Timeout';
    }
    debugPrint('[BSS-Vision] FINAL FAIL ${config.effectiveModelName}: $errorMessage | url=${uri.toString()}');

    return AiVerificationResult(
      status: VerificationStatus.perluCekManual,
      alasan:
          'Koneksi ke server AI terputus ($errorMessage). Foto dialihkan untuk Cek Manual oleh Supervisor.',
      poinGagal: ['Koneksi Server Vision Terganggu / Gagal'],
      poinLolos: [],
      confidenceScore: 0.0,
      providerName: 'AI Fallback Alert (${config.provider.displayName})',
      isFallback: true,
    );
  }

  static AiVerificationResult? parseAiJsonResponseForTest(
    String rawContent,
    List<String> criteria,
    AiVisionConfig config,
  ) {
    return _parseAiJsonResponse(rawContent, criteria, config);
  }

  static AiVerificationResult? _parseAiJsonResponse(
    String rawContent,
    List<String> criteria,
    AiVisionConfig config,
  ) {
    try {
      String sanitized = rawContent.trim();
      if (sanitized.contains('```json')) {
        final start = sanitized.indexOf('```json') + 7;
        final end = sanitized.indexOf('```', start);
        if (end != -1) {
          sanitized = sanitized.substring(start, end).trim();
        }
      } else if (sanitized.contains('```')) {
        final start = sanitized.indexOf('```') + 3;
        final end = sanitized.indexOf('```', start);
        if (end != -1) {
          sanitized = sanitized.substring(start, end).trim();
        }
      }

      if (!sanitized.startsWith('{') && sanitized.contains('{')) {
        final start = sanitized.indexOf('{');
        final end = sanitized.lastIndexOf('}');
        if (end != -1 && end > start) {
          sanitized = sanitized.substring(start, end + 1);
        }
      }

      final jsonMap = jsonDecode(sanitized) as Map<String, dynamic>;

      final rawStatus = (jsonMap['status'] as String? ?? '').toLowerCase();
      VerificationStatus status;
      if (rawStatus.contains('tidak') ||
          rawStatus.contains('fail') ||
          rawStatus.contains('reject') ||
          rawStatus.contains('not_')) {
        status = VerificationStatus.tidakSesuai;
      } else if (rawStatus.contains('lolos') ||
          rawStatus.contains('sesuai') ||
          rawStatus.contains('pass') ||
          rawStatus.contains('approve')) {
        status = VerificationStatus.sesuai;
      } else {
        status = VerificationStatus.perluCekManual;
      }

      final rawAlasan = jsonMap['alasan'] as String? ??
          jsonMap['reason'] as String? ??
          'Evaluasi selesai.';
      final alasan = cleanTechnicianReason(rawAlasan);

      final rawPoinGagal = jsonMap['poinGagal'] as List<dynamic>? ??
          jsonMap['poin_gagal'] as List<dynamic>? ??
          [];
      final poinGagal = rawPoinGagal
          .map((e) => SopCriteriaHelper.toNegativeStatement(e.toString()))
          .toList();

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

      // KRITERIA STRICT MUTLAK: Jika ada poin gagal (ID card tidak ada, salah seragam, dsb), status WAJIB tidakSesuai!
      if (poinGagal.isNotEmpty) {
        status = VerificationStatus.tidakSesuai;
      } else if (poinGagal.isEmpty && status == VerificationStatus.tidakSesuai) {
        poinGagal.add('Kriteria SOP belum terpenuhi');
      }

      // briefing counting fields
      final rawCount = jsonMap['personCount'] ?? jsonMap['person_count'] ?? jsonMap['jumlahPersonel'];
      int? personCount;
      if (rawCount is num) personCount = rawCount.toInt();
      final kategori = jsonMap['briefingKategori'] as String? ?? jsonMap['kategori'] as String?;
      // auto derive kategori jika tidak ada tapi count ada
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
        providerName: 'Google Gemini (${config.effectiveModelName})',
        personCount: personCount,
        briefingKategori: finalKategori,
      );
    } catch (_) {
      return _parseFreeTextFallback(rawContent, criteria, config);
    }
  }

  static AiVerificationResult? _parseFreeTextFallback(
    String rawContent,
    List<String> criteria,
    AiVisionConfig config,
  ) {
    final text = rawContent.toLowerCase();
    String reason = rawContent.trim();
    if (reason.length > 200) {
      reason = '${reason.substring(0, 200).trim()}...';
    }

    final unverifiableKeywords = [
      'motion-blurred',
      'motion blurred',
      'motion blur',
      'blurred',
      'out of focus',
      'out-of-focus',
      'unfocused',
      'obscure',
      'no details',
      'no detail',
      'no readable',
      'no visible',
      'unreadable',
      'no text',
      'cannot read',
      "can't read",
      'too dark',
      'too small',
      'too blurry',
      'cannot identify',
      "can't identify",
      'unable to',
      'indistinct',
      'incomplete image',
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
      return AiVerificationResult(
        status: VerificationStatus.perluCekManual,
        alasan: 'Foto tidak dapat diverifikasi otomatis: $reason',
        poinGagal: [],
        poinLolos: [],
        confidenceScore: 0.5,
        providerName: 'Google Gemini (${config.effectiveModelName})',
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
        if (cl.contains('sepatu')) 'shoes',
        if (cl.contains('postur') || cl.contains('sikap')) 'posture',
      ].where((s) => s.trim().isNotEmpty).toList();

      if (candidates.any((cand) => text.contains(cand))) {
        matchCount++;
      }
    }

    if (matchCount >= (criteria.length / 2).ceil() && criteria.isNotEmpty) {
      return AiVerificationResult(
        status: VerificationStatus.sesuai,
        alasan: reason,
        poinGagal: [],
        poinLolos:
            criteria.map(SopCriteriaHelper.toPositiveStatement).toList(),
        confidenceScore: 0.7,
        providerName: 'Google Gemini (${config.effectiveModelName})',
        isFallback: true,
      );
    }

    return AiVerificationResult(
      status: VerificationStatus.perluCekManual,
      alasan: 'AI tidak mengembalikan JSON terstruktur. Respons: $reason',
      poinGagal: [],
      poinLolos: [],
      confidenceScore: 0.4,
      providerName: 'Google Gemini (${config.effectiveModelName})',
      isFallback: true,
    );
  }
}
