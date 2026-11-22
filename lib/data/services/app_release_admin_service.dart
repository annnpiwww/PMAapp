import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../repositories/auth_repository.dart';
import 'app_update_service.dart';
import 'daily_task_service.dart';

enum AdminReleaseStatus {
  draft,
  published,
  rolledBack,
  archived;

  static AdminReleaseStatus fromWire(String? raw) {
    switch (raw) {
      case 'published':
        return AdminReleaseStatus.published;
      case 'rolled_back':
        return AdminReleaseStatus.rolledBack;
      case 'archived':
        return AdminReleaseStatus.archived;
      case 'draft':
      default:
        return AdminReleaseStatus.draft;
    }
  }

  String get label {
    switch (this) {
      case AdminReleaseStatus.draft:
        return 'Draf';
      case AdminReleaseStatus.published:
        return 'Aktif';
      case AdminReleaseStatus.rolledBack:
        return 'Ditarik';
      case AdminReleaseStatus.archived:
        return 'Arsip';
    }
  }
}

String cabangLabel(List<String>? t) {
  if (t == null || t.isEmpty) return 'Semua cabang';
  return t
      .map((c) {
        switch (c) {
          case 'manado':
            return 'Manado';
          case 'bali':
            return 'Bali';
          case 'ho':
            return 'HO';
          default:
            return c;
        }
      })
      .join(', ');
}

class AdminReleaseItem {
  final String id;
  final String app;
  final String abi;
  final int versionCode;
  final int baseVersionCode;
  final String versionName;
  final String sha256;
  final int sizeBytes;
  final String changelog;
  final bool mandatory;
  final String? minSupportedVersion;
  final List<String>? targetCabang;
  final AdminReleaseStatus status;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? publishedAt;

  const AdminReleaseItem({
    required this.id,
    required this.app,
    required this.abi,
    required this.versionCode,
    required this.baseVersionCode,
    required this.versionName,
    required this.sha256,
    required this.sizeBytes,
    required this.changelog,
    required this.mandatory,
    required this.minSupportedVersion,
    this.targetCabang,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.publishedAt,
  });

  bool get isAllBranches => targetCabang == null || targetCabang!.isEmpty;

  factory AdminReleaseItem.fromJson(Map<String, dynamic> json) {
    return AdminReleaseItem(
      id: (json['id'] as String?) ?? '',
      app: (json['app'] as String?) ?? 'pmapp',
      abi: (json['abi'] as String?) ?? '',
      versionCode: (json['version_code'] as num).toInt(),
      baseVersionCode: (json['base_version_code'] as num).toInt(),
      versionName: (json['version_name'] as String?) ?? '',
      sha256: (json['sha256'] as String?) ?? '',
      sizeBytes: (json['size_bytes'] as num).toInt(),
      changelog: (json['changelog'] as String?) ?? '',
      mandatory: json['mandatory'] == true,
      minSupportedVersion: json['min_supported_version'] as String?,
      targetCabang: _parseTargetCabang(json['target_cabang']),
      status: AdminReleaseStatus.fromWire(json['status'] as String?),
      createdBy: (json['created_by'] as String?) ?? '-',
      createdAt: _parseDate(json['created_at']),
      publishedAt: _parseDate(json['published_at']),
    );
  }

  static List<String>? _parseTargetCabang(dynamic raw) {
    if (raw is! List) return null;
    final items = raw
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return items.isEmpty ? null : List<String>.unmodifiable(items);
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}

class AdminUploadTicket {
  final String id;
  final String path;
  final String token;
  final String signedUrl;

  const AdminUploadTicket({
    required this.id,
    required this.path,
    required this.token,
    required this.signedUrl,
  });
}

class PickedApkResult {
  final String path;
  final String fileName;
  final int sizeBytes;

  const PickedApkResult({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
  });
}

class LocalApkInfo {
  final String path;
  final String fileName;
  final String packageName;
  final String versionName;
  final int versionCode;
  final String abi;
  final int baseVersionCode;
  final int sizeBytes;
  final String sha256;

  const LocalApkInfo({
    required this.path,
    required this.fileName,
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    required this.abi,
    required this.baseVersionCode,
    required this.sizeBytes,
    required this.sha256,
  });
}

class AppReleaseAdminException implements Exception {
  final int statusCode;
  final String errorCode;
  final String message;
  final Map<String, String> fieldErrors;

  const AppReleaseAdminException({
    required this.statusCode,
    required this.errorCode,
    required this.message,
    this.fieldErrors = const {},
  });

  bool get isForbidden => statusCode == 403 || errorCode == 'forbidden';

  @override
  String toString() =>
      'AppReleaseAdminException($statusCode $errorCode): $message';
}

class AppReleaseAdminService {
  AppReleaseAdminService({
    http.Client Function()? clientFactory,
    String Function()? baseUrlProvider,
    String Function()? anonKeyProvider,
    String? Function()? sessionTokenProvider,
    Future<void> Function()? onUnauthorized,
    Future<PickedApkResult?> Function()? pickApkProvider,
    Future<Map<String, dynamic>?> Function(String path)? readApkInfoProvider,
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _baseUrlProvider = baseUrlProvider ?? (() => DailyTaskService.baseUrl),
       _anonKeyProvider = anonKeyProvider ?? (() => DailyTaskService.anonKey),
       _sessionTokenProvider =
           sessionTokenProvider ?? (() => AuthRepository.instance.sessionToken),
       _onUnauthorized =
           onUnauthorized ?? AuthRepository.instance.handleUnauthorizedSession,
       _pickApkProvider = pickApkProvider ?? _defaultPickApk,
       _readApkInfoProvider = readApkInfoProvider ?? _defaultReadApkInfo;

  static final AppReleaseAdminService instance = AppReleaseAdminService();

  static const String expectedPackageName =
      'com.bssparking.timemark.bssparking_timemark';

  static const Map<String, int> abiOffsets = {
    'armeabi-v7a': 1000,
    'arm64-v8a': 2000,
    'x86_64': 4000,
  };

  static const Duration requestTimeout = Duration(seconds: 15);
  static const int _isolateHashThreshold = 5 * 1024 * 1024;

  final http.Client Function() _clientFactory;
  final String Function() _baseUrlProvider;
  final String Function() _anonKeyProvider;
  final String? Function() _sessionTokenProvider;
  final Future<void> Function() _onUnauthorized;
  final Future<PickedApkResult?> Function() _pickApkProvider;
  final Future<Map<String, dynamic>?> Function(String path)
  _readApkInfoProvider;

  static String abiShortLabel(String abi) {
    switch (abi) {
      case 'arm64-v8a':
        return 'arm64';
      case 'armeabi-v7a':
        return 'arm32';
      default:
        return abi;
    }
  }

  static Future<PickedApkResult?> _defaultPickApk() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    final raw = await AppUpdateService.channel.invokeMapMethod<String, dynamic>(
      'pickApkFile',
    );
    if (raw == null) return null;
    final path = raw['path'] as String?;
    final name = raw['name'] as String?;
    final size = (raw['sizeBytes'] as num?)?.toInt();
    if (path == null || path.isEmpty || size == null || size <= 0) return null;
    return PickedApkResult(
      path: path,
      fileName: (name != null && name.isNotEmpty) ? name : 'release.apk',
      sizeBytes: size,
    );
  }

  static Future<Map<String, dynamic>?> _defaultReadApkInfo(String path) async {
    if (kIsWeb || !Platform.isAndroid) return null;
    return AppUpdateService.channel.invokeMapMethod<String, dynamic>(
      'readApkInfo',
      {'path': path},
    );
  }

  Future<PickedApkResult?> pickApkFile() => _pickApkProvider();

  /// Validates a local APK's package name, single-ABI rule, base version code,
  /// and computes SHA-256 + byte length off the UI isolate for large files.
  Future<LocalApkInfo> inspectLocalApk(String path, {String? fileName}) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw const AppReleaseAdminException(
        statusCode: 400,
        errorCode: 'missing_file',
        message: 'File APK tidak ditemukan.',
      );
    }

    final raw = await _readApkInfoProvider(path);
    if (raw == null) {
      throw const AppReleaseAdminException(
        statusCode: 400,
        errorCode: 'invalid_apk',
        message: 'File tidak bisa dibaca sebagai APK Android yang valid.',
      );
    }

    final sizeBytes = await file.length();
    if (sizeBytes <= 0 || sizeBytes > 52428800) {
      throw const AppReleaseAdminException(
        statusCode: 400,
        errorCode: 'file_too_large',
        message: 'Ukuran APK harus antara 1 byte hingga 50 MB.',
      );
    }

    final sha256Hex = sizeBytes > _isolateHashThreshold
        ? await Isolate.run(() => computeFileSha256Sync(path))
        : computeFileSha256Sync(path);

    return validateParsedApk(
      raw: raw,
      path: path,
      fileName: fileName ?? file.uri.pathSegments.last,
      sizeBytes: sizeBytes,
      sha256: sha256Hex,
    );
  }

  /// Pure validation helper exposed for deterministic unit tests.
  static LocalApkInfo validateParsedApk({
    required Map<String, dynamic> raw,
    required String path,
    required String fileName,
    required int sizeBytes,
    required String sha256,
  }) {
    final packageName = (raw['packageName'] as String?)?.trim() ?? '';
    if (packageName != expectedPackageName) {
      throw const AppReleaseAdminException(
        statusCode: 400,
        errorCode: 'wrong_package',
        message: 'Package APK harus $expectedPackageName.',
      );
    }

    final versionName = (raw['versionName'] as String?)?.trim() ?? '';
    final versionCode = (raw['versionCode'] as num?)?.toInt() ?? 0;
    final abisRaw = raw['abis'];
    final abis = abisRaw is List
        ? abisRaw.whereType<String>().where(abiOffsets.containsKey).toList()
        : <String>[];

    if (abis.isEmpty) {
      throw const AppReleaseAdminException(
        statusCode: 400,
        errorCode: 'missing_abi',
        message: 'Arsitektur APK tidak ditemukan atau tidak didukung.',
      );
    }
    if (abis.length > 1) {
      throw const AppReleaseAdminException(
        statusCode: 400,
        errorCode: 'universal_apk',
        message: 'Unggah APK per arsitektur, bukan universal.',
      );
    }

    final abi = abis.first;
    final offset = abiOffsets[abi]!;
    final baseVersionCode = versionCode - offset;
    if (baseVersionCode <= 0) {
      throw const AppReleaseAdminException(
        statusCode: 400,
        errorCode: 'invalid_version_code',
        message: 'Kode versi APK tidak valid untuk arsitektur tersebut.',
      );
    }

    return LocalApkInfo(
      path: path,
      fileName: fileName,
      packageName: packageName,
      versionName: versionName,
      versionCode: versionCode,
      abi: abi,
      baseVersionCode: baseVersionCode,
      sizeBytes: sizeBytes,
      sha256: sha256.toLowerCase(),
    );
  }

  Future<Map<String, dynamic>> _postAction(Map<String, dynamic> body) async {
    final baseUrl = _baseUrlProvider();
    final anonKey = _anonKeyProvider();
    final sessionToken = _sessionTokenProvider();

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'apikey': anonKey,
      'Authorization': 'Bearer $anonKey',
      if (sessionToken != null && sessionToken.isNotEmpty)
        'x-app-session': sessionToken,
    };

    final client = _clientFactory();
    try {
      final response = await client
          .post(
            Uri.parse('$baseUrl/functions/v1/app-releases'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);

      Map<String, dynamic> decoded = const {};
      try {
        final raw = jsonDecode(response.body);
        if (raw is Map<String, dynamic>) decoded = raw;
      } catch (_) {}

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      final errorCode = (decoded['error'] as String?) ?? 'server_error';
      if (response.statusCode == 401) {
        await _onUnauthorized();
        throw const AppReleaseAdminException(
          statusCode: 401,
          errorCode: 'unauthorized',
          message: 'Sesi habis, silakan login ulang.',
        );
      }
      if (response.statusCode == 403) {
        throw const AppReleaseAdminException(
          statusCode: 403,
          errorCode: 'forbidden',
          message: 'Akun ini belum punya akses rilis.',
        );
      }

      if (response.statusCode == 409) {
        final String msg;
        if (errorCode == 'version_code_must_increase' ||
            errorCode == 'duplicate') {
          msg = 'Nomor versi harus lebih tinggi dari rilis sebelumnya.';
        } else if (errorCode == 'not_editable') {
          msg = 'Rilis ini sudah tidak bisa diubah.';
        } else {
          msg = 'Status rilis sudah berubah. Muat ulang daftar.';
        }
        throw AppReleaseAdminException(
          statusCode: 409,
          errorCode: errorCode,
          message: msg,
        );
      }

      if (response.statusCode == 400) {
        final rawErrors = decoded['errors'];
        final fieldErrors = <String, String>{};
        if (rawErrors is Map) {
          rawErrors.forEach((k, v) {
            fieldErrors[k.toString()] = v.toString();
          });
        }
        final firstMsg = fieldErrors.isNotEmpty
            ? fieldErrors.entries.map((e) => '${e.key}: ${e.value}').join('\n')
            : 'Data rilis tidak valid.';
        throw AppReleaseAdminException(
          statusCode: 400,
          errorCode: errorCode,
          message: firstMsg,
          fieldErrors: fieldErrors,
        );
      }

      if (response.statusCode == 422) {
        final msg = errorCode == 'hash_mismatch'
            ? 'Berkas terunggah tidak cocok dengan checksum APK.'
            : 'File APK belum terunggah lengkap ke server.';
        throw AppReleaseAdminException(
          statusCode: 422,
          errorCode: errorCode,
          message: msg,
        );
      }

      throw AppReleaseAdminException(
        statusCode: response.statusCode,
        errorCode: errorCode,
        message: 'Terjadi gangguan pada server (${response.statusCode}).',
      );
    } finally {
      client.close();
    }
  }

  Future<List<AdminReleaseItem>> list() async {
    final decoded = await _postAction({'action': 'list'});
    final rawList = decoded['releases'];
    if (rawList is! List) return const [];
    return rawList
        .whereType<Map<String, dynamic>>()
        .map(AdminReleaseItem.fromJson)
        .toList();
  }

  Future<AdminUploadTicket> createUpload({
    required LocalApkInfo apk,
    required String changelog,
    required bool mandatory,
    String? minSupportedVersion,
    List<String>? targetCabang,
  }) async {
    final minVerClean = minSupportedVersion?.trim();
    final normalizedTarget = (targetCabang != null && targetCabang.isNotEmpty)
        ? (targetCabang.toSet().toList()..sort())
        : null;
    final decoded = await _postAction({
      'action': 'create_upload',
      'abi': apk.abi,
      'base_version_code': apk.baseVersionCode,
      'version_code': apk.versionCode,
      'version_name': apk.versionName,
      'sha256': apk.sha256,
      'size_bytes': apk.sizeBytes,
      'changelog': changelog,
      'mandatory': mandatory,
      'min_supported_version': (minVerClean != null && minVerClean.isNotEmpty)
          ? minVerClean
          : null,
      'target_cabang': normalizedTarget,
    });

    final id = (decoded['id'] as String?) ?? '';
    final upload = decoded['upload'];
    if (id.isEmpty || upload is! Map<String, dynamic>) {
      throw const AppReleaseAdminException(
        statusCode: 500,
        errorCode: 'invalid_response',
        message: 'Respons upload dari server tidak lengkap.',
      );
    }

    return AdminUploadTicket(
      id: id,
      path: (upload['path'] as String?) ?? '',
      token: (upload['token'] as String?) ?? '',
      signedUrl: (upload['signedUrl'] as String?) ?? '',
    );
  }

  Future<void> uploadFile(
    String signedUrl,
    File file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final total = await file.length();
    final baseUrl = _baseUrlProvider();
    final uri = signedUrl.startsWith('http')
        ? Uri.parse(signedUrl)
        : Uri.parse('$baseUrl$signedUrl');

    final client = _clientFactory();
    try {
      final request = http.StreamedRequest('PUT', uri)
        ..headers['Content-Type'] = 'application/vnd.android.package-archive'
        ..headers['x-upsert'] = 'false'
        ..contentLength = total;

      var sent = 0;
      final sendFuture = client.send(request);
      await for (final chunk in file.openRead()) {
        request.sink.add(chunk);
        sent += chunk.length;
        onProgress?.call(sent, total);
      }
      await request.sink.close();

      final streamedRes = await sendFuture.timeout(const Duration(minutes: 5));
      final body = await streamedRes.stream.bytesToString();
      if (streamedRes.statusCode < 200 || streamedRes.statusCode >= 300) {
        throw AppReleaseAdminException(
          statusCode: streamedRes.statusCode,
          errorCode: 'upload_failed',
          message:
              'Gagal mengunggah file APK (${streamedRes.statusCode}): $body',
        );
      }
    } finally {
      client.close();
    }
  }

  Future<AdminReleaseItem> publish(String id) async {
    final decoded = await _postAction({'action': 'publish', 'id': id});
    final releaseJson = decoded['release'];
    if (releaseJson is! Map<String, dynamic>) {
      throw const AppReleaseAdminException(
        statusCode: 500,
        errorCode: 'invalid_response',
        message: 'Respons terbit tidak valid.',
      );
    }
    return AdminReleaseItem.fromJson(releaseJson);
  }

  Future<AdminReleaseItem> rollback(String id) async {
    final decoded = await _postAction({'action': 'rollback', 'id': id});
    final releaseJson = decoded['release'];
    if (releaseJson is! Map<String, dynamic>) {
      throw const AppReleaseAdminException(
        statusCode: 500,
        errorCode: 'invalid_response',
        message: 'Respons tarik rilis tidak valid.',
      );
    }
    return AdminReleaseItem.fromJson(releaseJson);
  }

  Future<AdminReleaseItem> setTargets(
    String id,
    List<String>? targetCabang,
  ) async {
    final normalizedTarget = (targetCabang != null && targetCabang.isNotEmpty)
        ? (targetCabang.toSet().toList()..sort())
        : null;
    final decoded = await _postAction({
      'action': 'set_targets',
      'id': id,
      'target_cabang': normalizedTarget,
    });
    final releaseJson = decoded['release'];
    if (releaseJson is! Map<String, dynamic>) {
      throw const AppReleaseAdminException(
        statusCode: 500,
        errorCode: 'invalid_response',
        message: 'Respons ubah target tidak valid.',
      );
    }
    return AdminReleaseItem.fromJson(releaseJson);
  }

  Future<void> deleteDraft(String id) async {
    await _postAction({'action': 'delete_draft', 'id': id});
  }
}
