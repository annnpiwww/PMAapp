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
    }
    return 'Tidak memenuhi kriteria: $criterion';
  }

  static String toPositiveStatement(String criterion) {
    return criterion;
  }
}

class AiVisionService {
  static AiVisionConfig? _cachedConfig;

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
    final stopwatch = Stopwatch()..start();
    try {
      final uri = Uri.parse('${config.effectiveBaseUrl}/chat/completions');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (config.apiKey.trim().isNotEmpty)
                'Authorization': 'Bearer ${config.apiKey.trim()}',
            },
            body: jsonEncode({
              'model': config.effectiveModelName,
              'messages': [
                {'role': 'user', 'content': 'ping'}
              ],
              'max_tokens': 5,
            }),
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
    // Untuk per-point, kirim label point sebagai kriteria tunggal + konteks template
    final pointCriteria = [point.label];
    return _runCustomEndpointVerification(
      imageBase64: imageBase64,
      criteria: pointCriteria,
      config: config,
      extraContext: 'Template: ${template.nama} — Point: ${point.label}${point.deskripsi.isNotEmpty ? " (${point.deskripsi})" : ""}',
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
   - "kabel tidak tertata rapi", "kabel tampak semrawut"
   - "terdapat korosi", "terdapat karat", "terdapat kerusakan fisik"
   - "stiker tampak kusam", "stiker rusak/terkelupas"
   - "cat tampak pudar", "terdapat retakan pada beton"
   - "terdapat sisa material", "terdapat bekas stiker"
   - "terpasang dengan kokoh", "berfungsi normal", "tercetak dengan baik", "bersih dan bebas debu"

3. KATA/ISTILAH YANG DILARANG KERAS (TERLALU FORMAL / GAYA AI KAKU):
   - DILARANG: "degradasi fisik", "tidak terorganisir dengan rapi", "berdasarkan hasil observasi", "ditemukan adanya ketidaksesuaian", "kondisi secara keseluruhan", "secara signifikan", "mengalami deteriorasi", "parameter tidak terpenuhi", "sesuai standar operasional", "dalam kondisi optimal", "memiliki integritas struktural", "permukaan mengalami degradasi".
   - DILARANG REDUNDAN: Jangan mengulang arti sama ("kabel tampak semrawut dan tidak terorganisir" -> gunakan "kabel tampak semrawut dan tidak tertata rapi").
   - DILARANG KALIMAT PERINTAH: Jangan gunakan "harus dibersihkan", "segera dicat ulang", "segera perbaiki". Tulis faktual apa yang terlihat.

4. ATURAN STATUS:
   - SESUAI (Lulus/Hijau): Gunakan kalimat positif yang singkat, natural, dan langsung (8-14 kata).
     * Contoh: "Area printer bersih dan bebas debu."
     * Contoh: "Tombol tiket berfungsi normal dan struk tercetak dengan baik."
     * Contoh: "Body manless bersih dan stiker panduan masih utuh."
     * Contoh: "Kunci manless bersih, tidak berkarat, dan terpasang kokoh."
     * Contoh: "Kapasitas Drive C aman indikator biru dan folder temp bersih."
   - TIDAK_SESUAI (Temuan/Merah): Sebutkan masalah utama terlebih dahulu, lalu detail pendukung jika ada (8-16 kata).
     * Contoh: "Kabel di dalam manless tampak semrawut dan tidak tertata rapi."
     * Contoh: "Dudukan bawah manless terdapat tumpukan debu dan korosi pada plat besi."
     * Contoh: "Stiker panduan rusak dan body manless tampak kotor."
     * Contoh: "Beton pulau gate tampak kotor dan terdapat retakan pada permukaan."
     * Contoh: "Stiker receiver kuning tampak retak dan terkelupas pada bodi."
   - PERLU_CEK_MANUAL (Kuning): Foto blur, goyang, terlalu gelap, atau sudut terhalang.
     * Contoh: "Foto tampak blur dan kurang fokus, perlu cek fisik manual."

OUTPUT STRICT JSON ONLY:
{"status":"sesuai"|"tidak_sesuai"|"perlu_cek_manual","confidenceScore":95,"alasan":"...","poinLolos":["..."],"poinGagal":["..."]}
''';
    } else if (absensiKategori == AbsensiKategori.teknisi) {
      final hari = (hariKerja ?? 'SENIN').toUpperCase();
      final isPulang = tipeLaporan == 'Pulang';
      if (isPulang) {
        systemPrompt = '''
BSS-Vision, grooming auditor for Technical Support Staff (Teknisi) at BSS Parking - MODE ABSENSI PULANG SHIFT.
Task: Verify Teknisi grooming for PULANG (CLOCK-OUT) attendance ($hari).

HARI INI: $hari

ATURAN KHUSUS ABSENSI PULANG (TOLERAN & REALISTIS):
1. FOTO SETENGAH BADAN DIPERBOLEHKAN & SAH (LULUS / SESUAI).
2. SEPATU TIDAK DIPERIKSA / TIDAK WAJIB: Jangan periksa sepatu! Jika foto setengah badan atau sepatu tidak kelihatan, STATUS TETAP "sesuai". DILARANG memberi status "perlu_cek_manual" hanya karena sepatu tidak tampak di foto.
3. ID CARD / TALI LANYARD: Tali lanyard ID Card atau kartu ID Card terpasang pada leher/dada. JIKA HANYA TALI LANYARD SAJA YANG TERLIHAT -> TETAP SAH & LULUS ("sesuai")! Hanya beri "tidak_sesuai" jika dada polos tanpa tali lanyard dan tanpa ID Card sama sekali.
4. SERAGAM: Mengenakan seragam dinas hari $hari ATAU Seragam Teknisi resmi BSS dengan rapi. JIKA MEMAKAI SERAGAM TEKNISI RESMI PADA HARI SENIN-MINGGU, WAJIB DIHIJAUKAN (STATUS: SESUAI / LULUS)!

HASIL STATUS:
- sesuai: Seragam hari dinas rapi (atau seragam teknisi resmi) dan tali lanyard/ID card terpasang (foto setengah badan SAH & LULUS tanpa perlu cek sepatu).
- tidak_sesuai: Salah seragam / pakaian bebas non-resmi atau dada polos tanpa tali lanyard / ID Card sama sekali.
- perlu_cek_manual: Foto sangat blur sehingga seragam tidak dapat diidentifikasi.

OUTPUT FORMAT: STRICT JSON ONLY.
Schema:
{"status":"sesuai"|"tidak_sesuai"|"perlu_cek_manual","confidenceScore":95,"alasan":"...","poinLolos":["..."],"poinGagal":["..."]}
''';
      } else {
        systemPrompt = '''
BSS-Vision, strict grooming auditor for Technical Support Staff (Teknisi) at BSS Parking - MODE ABSENSI MASUK SHIFT.
Task: Verify Teknisi grooming strictly based on DAY OF THE WEEK ($hari) and company schedule.

HARI INI: $hari

JADWAL SERAGAM RESMI TEKNISI:
- SENIN: Seragam Teknisi ATAU Seragam PDH biru navy (keduanya SAH & WAJIB LULUS/HIJAU).
- SELASA: Seragam PDH biru navy ATAU Seragam Teknisi (keduanya SAH & WAJIB LULUS/HIJAU).
- RABU: Seragam Teknisi (SAH & WAJIB LULUS/HIJAU).
- KAMIS: Seragam BSS Parking warna putih ATAU Seragam Teknisi (keduanya SAH & WAJIB LULUS/HIJAU).
- JUMAT: Batik ATAU Seragam Teknisi (keduanya SAH & WAJIB LULUS/HIJAU).
- SABTU: Seragam Olahraga biru-kuning ATAU Seragam Teknisi (keduanya SAH & WAJIB LULUS/HIJAU).
- MINGGU: Pakaian bebas rapi ATAU Seragam Teknisi (keduanya SAH & WAJIB LULUS/HIJAU).

ATURAN MUTLAK SERAGAM TEKNISI (SENIN s/d MINGGU):
- SERAGAM TEKNISI SELALU SAH & WAJIB DIHIJAUKAN: Jika teknisi menggunakan Seragam Teknisi resmi BSS pada hari APAPUN (Senin, Selasa, Rabu, Kamis, Jumat, Sabtu, Minggu), status seragam WAJIB DIHIJAUKAN ("sesuai" / HIJAU / LULUS)!
- DILARANG KERAS menggagalkan atau memberi status "tidak_sesuai" / "perlu_cek_manual" jika teknisi mengenakan Seragam Teknisi resmi BSS, sekalipun hari tersebut adalah hari Selasa (PDH), Kamis (Putih), atau Sabtu (Olahraga). Seragam Teknisi adalah seragam kerja standar teknisi yang sah digunakan setiap hari.

KRITERIA WAJIB TEKNISI (MUTLAK):
1. Seragam: Mengenakan Seragam Teknisi resmi ATAU seragam sesuai jadwal hari ($hari), dan dikenakan rapi.
2. ID Card terpasang pada badan (tali lanyard / kartu saku / yoyo terpasang jelas).
3. Celana panjang & sepatu kerja tertutup (tidak boleh sandal/kaki terbuka).

ATURAN EVALUASI KETAT (ZERO TOLERANCE):
- ID CARD (WAJIB MUTLAK): ID Card atau tali lanyard WAJIB terlihat terpasang di baju/dada/leher. Jika ID Card TIDAK ADA / TIDAK TERLIHAT / DADA POLOS -> STATUS WAJIB "tidak_sesuai" (MERAH)! Masukkan "ID Card / Name Tag tidak terpasang di saku atau dada" ke poinGagal! DILARANG MELOLOSKAN JIKA TIDAK ADA ID CARD.
- SEPATU KERJA: Jika kaki terlihat dan memakai sandal/kaki terbuka -> STATUS WAJIB "tidak_sesuai" (MERAH)! Jika kaki terpotong pada foto setengah badan -> beri status "perlu_cek_manual" dengan alasan sepatu tidak terlihat di foto.
- SERAGAM: Jika memakai pakaian santai non-resmi (misal kaos oblong / singlet) bukan seragam dinas ataupun seragam teknisi -> STATUS WAJIB "tidak_sesuai" (MERAH)! Namun jika memakai Seragam Teknisi resmi atau seragam jadwal hari $hari -> WAJIB "sesuai" (HIJAU)!

HASIL STATUS:
- sesuai: Semua kriteria wajib terpenuhi lengkap termasuk ID Card dan seragam (baik Seragam Teknisi maupun seragam dinas hari $hari).
- tidak_sesuai: Ada kriteria wajib yang tidak terpenuhi (misal tidak pakai ID Card, pakaian bebas non-resmi / kaos oblong, pakai sandal).
- perlu_cek_manual: Foto terpotong sehingga sepatu/atribut tidak terlihat lengkap untuk memastikan kepatuhan.

OUTPUT FORMAT: STRICT JSON ONLY.
Schema:
{"status":"sesuai"|"tidak_sesuai"|"perlu_cek_manual","confidenceScore":95,"alasan":"...","poinLolos":["..."],"poinGagal":["..."]}
''';
      }
    } else if (absensiKategori == AbsensiKategori.admin) {
      systemPrompt = '''
BSS-Vision, strict grooming auditor for ADMIN BSS Parking.
Task: Verify Admin (Perempuan) grooming strictly.

RULE ADMIN BSS PARKING:
1. SERAGAM: Perempuan mengenakan baju seragam kombinasi warna BIRU dan HIJAU.
2. ATRIBUT WAJIB:
   - ID Card / Name Tag terpasang di saku/dada (lanyard / yoyo / card holder). JIKA TIDAK ADA ID CARD -> WAJIB "tidak_sesuai" (MERAH)!
   - Pin Smile terpasang di dada.
3. PENGECUALIAN ADMIN: Admin perempuan TIDAK WAJIB peluit dan TIDAK WAJIB topi.
4. SEPATU: Wajib sepatu kerja tertutup rapi jika terlihat di foto.

OUTPUT FORMAT: STRICT JSON ONLY.
Schema:
{"status":"sesuai"|"tidak_sesuai"|"perlu_cek_manual","confidenceScore":95,"alasan":"...","poinLolos":["..."],"poinGagal":["..."]}
''';
    } else if (absensiKategori == AbsensiKategori.leader) {
      systemPrompt = '''
BSS-Vision, strict grooming auditor for LEADER BSS Parking.
Task: Verify Leader (Laki-laki) grooming strictly.

RULE LEADER BSS PARKING:
1. SERAGAM: Kemeja berkerah warna HITAM dengan kombinasi HIJAU pada pundak dan patch BENDERA INDONESIA di lengan kanan.
2. ATRIBUT WAJIB:
   - ID Card / Name Tag terpasang di saku/dada. JIKA TIDAK ADA ID CARD -> WAJIB "tidak_sesuai" (MERAH)!
   - Pin Smile terpasang di dada sebelah kanan pemakai.
   - Peluit: Peluit plastik warna BIRU dengan tali BIRU menggantung di leher/dada.
3. Baju seragam WAJIB dimasukkan ke dalam celana.
4. Sepatu kerja hitam bersih.

OUTPUT FORMAT: STRICT JSON ONLY.
Schema:
{"status":"sesuai"|"tidak_sesuai"|"perlu_cek_manual","confidenceScore":95,"alasan":"...","poinLolos":["..."],"poinGagal":["..."]}
''';
    } else if (absensiKategori == AbsensiKategori.sppMerah) {
      systemPrompt = '''
BSS-Vision, strict grooming auditor for SPP/SPL MERAH BSS Parking.
Task: Verify SPP/SPL Merah grooming strictly.

RULE SPP/SPL MERAH:
1. SERAGAM: Kemeja berkerah warna MERAH dengan kombinasi kerah dan lis kancing warna HITAM serta logo BSS Parking.
2. ATRIBUT WAJIB:
   - ID Card / Name Tag terpasang di saku kiri/dada. JIKA TIDAK ADA ID CARD -> WAJIB "tidak_sesuai" (MERAH)!
   - Pin Smile terpasang di dada.
   - Peluit: Peluit plastik warna BIRU dengan tali BIRU menggantung di leher/dada (petugas laki-laki).
   - Topi dinas BSS Parking (petugas SPL).
3. Baju seragam WAJIB dimasukkan ke dalam celana.
4. Sepatu kerja hitam bersih.

OUTPUT FORMAT: STRICT JSON ONLY.
Schema:
{"status":"sesuai"|"tidak_sesuai"|"perlu_cek_manual","confidenceScore":95,"alasan":"...","poinLolos":["..."],"poinGagal":["..."]}
''';
    } else if (absensiKategori == AbsensiKategori.sppHijauAbu) {
      systemPrompt = '''
BSS-Vision, strict grooming auditor for SPP/SPL HIJAU-ABU BSS Parking.
Task: Verify SPP/SPL Hijau-Abu grooming strictly.

RULE SPP/SPL HIJAU-ABU:
1. SERAGAM: Kemeja berkerah kombinasi warna ABU-ABU pada badan tengah, HIJAU pada dada atas, dan BIRU CERAH pada lengan serta logo BSS Parking.
2. ATRIBUT WAJIB:
   - ID Card / Name Tag terpasang di saku kiri/dada. JIKA TIDAK ADA ID CARD -> WAJIB "tidak_sesuai" (MERAH)!
   - Pin Smile terpasang di dada.
   - Peluit: Peluit plastik warna BIRU dengan tali BIRU menggantung di leher/dada (petugas laki-laki).
   - Topi dinas BSS Parking (petugas SPL).
3. Baju seragam WAJIB dimasukkan ke dalam celana.
4. Sepatu kerja hitam bersih.

OUTPUT FORMAT: STRICT JSON ONLY.
Schema:
{"status":"sesuai"|"tidak_sesuai"|"perlu_cek_manual","confidenceScore":95,"alasan":"...","poinLolos":["..."],"poinGagal":["..."]}
''';
    } else {
      systemPrompt = '''
BSS-Vision, SOP compliance auditor for BSS Parking (Bahana Sulut Sentosa).
Task: Verify photo against SOP criteria objectively and consistently.

CRITERIA:
$criteriaListStr

TOLERANSI & KONSISTENSI:
1. Foto absensi umumnya selfie / setengah badan. Cukup nilai atribut dan seragam yang berada di dalam frame kamera.
2. Jangan mencari-cari kesalahan minor jika seragam resmi dan atribut utama terpasang rapi.
3. Beri status "sesuai" jika atribut utama terpenuhi. HANYA beri "tidak_sesuai" jika terlihat pelanggaran nyata.

OUTPUT FORMAT: STRICT JSON ONLY.
Schema:
{"status":"sesuai"|"tidak_sesuai"|"perlu_cek_manual","confidenceScore":95,"alasan":"...","poinLolos":["..."],"poinGagal":["..."]}
''';
    }

    final userContent = [
      {'type': 'text', 'text': 'Evaluasi foto ini terhadap SOP BSS Parking.'},
      {'type': 'image_url', 'image_url': {'url': formattedImage}},
    ];

    // Model tunggal yang konsisten sesuai konfigurasi user (tidak ada silent fallback siluman ke model berbeda arsitektur)
    final selectedModel = config.effectiveModelName;

    final DateTime budgetStart = DateTime.now();
    final Duration totalBudget =
        const Duration(seconds: AiVisionConfig.totalBudgetSeconds);
    String errorMessage = '';

    // Max 2x attempt pada model yang sama (1st try + 1x quick retry jika jaringan tersendat)
    const maxAttempts = 2;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (DateTime.now().difference(budgetStart) >= totalBudget) {
        errorMessage = 'Batas waktu ${AiVisionConfig.totalBudgetSeconds}s tercapai';
        break;
      }

      final remaining = totalBudget - DateTime.now().difference(budgetStart);
      if (remaining.inSeconds < 2) break;

      // Timeout ringkas per attempt (maks 6-7 detik) agar modal segera tampil
      final perModelTimeout = Duration(
        seconds: config.timeoutSeconds.clamp(4, remaining.inSeconds),
      );

      final isRetry = attempt > 0;
      if (isRetry) {
        debugPrint('[BSS-Vision] RETRY ${attempt + 1}/$maxAttempts on $selectedModel');
      }

      final client = http.Client();
      try {
        final response = await client
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                if (config.apiKey.trim().isNotEmpty)
                  'Authorization': 'Bearer ${config.apiKey.trim()}',
              },
              body: jsonEncode({
                'model': selectedModel,
                'messages': [
                  {'role': 'system', 'content': systemPrompt},
                  {'role': 'user', 'content': userContent},
                ],
                'max_tokens': config.maxTokens,
                'temperature': config.temperature,
                'response_format': {'type': 'json_object'},
                'stream': false,
              }),
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
              return parsedResult;
            }
            errorMessage = 'Format JSON response tidak sesuai';
            break;
          }
          errorMessage = 'Response dari server kosong';
          break;
        } else {
          errorMessage = 'Server error HTTP ${response.statusCode}';
          debugPrint('[BSS-Vision] HTTP ${response.statusCode} $selectedModel: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
          final retryable = [429, 502, 503, 504].contains(response.statusCode);
          if (retryable && attempt == 0 && remaining.inSeconds > 4) {
            await Future.delayed(const Duration(milliseconds: 600));
            continue;
          }
          break;
        }
      } catch (e, st) {
        debugPrint('[BSS-Vision] ERROR $selectedModel attempt ${attempt + 1}: $e\n$st');
        final isTimeout = e is TimeoutException;
        final isSocket = e.toString().contains('SocketException') ||
            e.toString().contains('Connection') ||
            e.toString().contains('ClientException');
        if ((isTimeout || isSocket) && attempt == 0 && remaining.inSeconds > 4) {
          errorMessage = 'Koneksi tersendat ($selectedModel) - coba lagi';
          await Future.delayed(const Duration(milliseconds: 600));
          continue;
        }
        if (isTimeout) {
          errorMessage = 'Timeout ${config.timeoutSeconds}s ($selectedModel)';
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

      final alasan = jsonMap['alasan'] as String? ??
          jsonMap['reason'] as String? ??
          'Evaluasi selesai.';

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
