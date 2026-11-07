import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:http/http.dart' as http;
import 'storage_service.dart';
import 'branch_service.dart';
import 'daily_task_service.dart';

enum RemoteWriteResult {
  ok,
  invalidCredentials,
  notSupervisor,
  offline,
  failed,
}

String _appBranchToKey(AppBranch b) {
  switch (b) {
    case AppBranch.manado:
      return 'manado';
    case AppBranch.bali:
      return 'bali';
    case AppBranch.ho:
      return 'ho';
  }
}

AppBranch? _appBranchFromKey(String? str) {
  if (str == null) return null;
  final s = str.trim().toLowerCase();
  if (s == 'manado' || s == 'kc manado' || s == 'mdo') return AppBranch.manado;
  if (s == 'bali' || s == 'kc bali' || s == 'dps') return AppBranch.bali;
  if (s == 'ho' || s == 'ho makassar') return AppBranch.ho;
  return null;
}

class PosLocation {
  final String posId;
  final String posName;
  final String cabangName;
  final String fullAddress;
  final String locationTag; // e.g. 'PBM/PKM', 'MEGAMAS', 'GATE 1'
  final Color tagColor;
  final double lat;
  final double lng;
  final AppBranch? explicitBranch;

  const PosLocation({
    required this.posId,
    required this.posName,
    required this.cabangName,
    required this.fullAddress,
    required this.locationTag,
    required this.tagColor,
    required this.lat,
    required this.lng,
    this.explicitBranch,
  });

  Map<String, dynamic> toJson() => {
    'posId': posId,
    'posName': posName,
    'cabangName': cabangName,
    'fullAddress': fullAddress,
    'locationTag': locationTag,
    'tagColorValue': tagColor.toARGB32(),
    'lat': lat,
    'lng': lng,
    if (explicitBranch != null) 'branch': _appBranchToKey(explicitBranch!),
  };

  factory PosLocation.fromJson(Map<String, dynamic> json) {
    return PosLocation(
      posId: json['posId'] as String,
      posName: json['posName'] as String,
      cabangName: json['cabangName'] as String,
      fullAddress: json['fullAddress'] as String,
      locationTag: json['locationTag'] as String,
      tagColor: Color(json['tagColorValue'] as int? ?? 0xFFF59E0B),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      explicitBranch: _appBranchFromKey(json['branch'] as String?),
    );
  }

  Map<String, dynamic> toRemoteJson() => {
    'pos_id': posId,
    'pos_name': posName,
    'cabang_name': cabangName,
    'full_address': fullAddress,
    'location_tag': locationTag,
    'tag_color': tagColor.toARGB32(),
    'branch': _appBranchToKey(explicitBranch ?? branch),
    'lat': lat,
    'lng': lng,
  };

  factory PosLocation.fromRemoteJson(Map<String, dynamic> json) {
    return PosLocation(
      posId: json['pos_id'] as String,
      posName: json['pos_name'] as String,
      cabangName: json['cabang_name'] as String,
      fullAddress: (json['full_address'] as String?) ?? '',
      locationTag: json['location_tag'] as String,
      tagColor: Color((json['tag_color'] as num?)?.toInt() ?? 0xFFF59E0B),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      explicitBranch: _appBranchFromKey(json['branch'] as String?),
    );
  }

  PosLocation copyWith({
    String? posId,
    String? posName,
    String? cabangName,
    String? fullAddress,
    String? locationTag,
    Color? tagColor,
    double? lat,
    double? lng,
    AppBranch? explicitBranch,
  }) {
    return PosLocation(
      posId: posId ?? this.posId,
      posName: posName ?? this.posName,
      cabangName: cabangName ?? this.cabangName,
      fullAddress: fullAddress ?? this.fullAddress,
      locationTag: locationTag ?? this.locationTag,
      tagColor: tagColor ?? this.tagColor,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      explicitBranch: explicitBranch ?? this.explicitBranch,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PosLocation &&
          runtimeType == other.runtimeType &&
          posId == other.posId;

  @override
  int get hashCode => posId.hashCode;

  /// Cek apakah lokasi ini termasuk ke dalam cabang target.
  /// Penanda cabang eksplisit (explicitBranch/cabangName/posId) didahulukan atas tag supaya
  /// lokasi hasil input SPV tidak pindah cabang walau tag-nya mirip cabang lain.
  bool matchesBranch(AppBranch branch) {
    if (explicitBranch != null) {
      return explicitBranch == branch;
    }

    final tag = locationTag.trim().toUpperCase();
    final name = cabangName.toLowerCase();
    final id = posId.toUpperCase();
    final hasHoMarker =
        name.contains('ho makassar') ||
        name.contains('head office') ||
        id.contains('-HO-');
    final hasBaliMarker = name.contains('bali') || id.contains('DPS');

    if (hasHoMarker) return branch == AppBranch.ho;
    if (hasBaliMarker) return branch == AppBranch.bali;

    if (BranchService.instance.getLocationTags(branch: branch).contains(tag)) {
      return true;
    }
    // Sisa lokasi tanpa penanda dianggap milik KC BSG Manado.
    return branch == AppBranch.manado &&
        !BranchService.instance
            .getLocationTags(branch: AppBranch.bali)
            .contains(tag) &&
        !BranchService.instance
            .getLocationTags(branch: AppBranch.ho)
            .contains(tag);
  }

  /// Branch kepemilikan lokasi ini
  AppBranch get branch {
    if (explicitBranch != null) return explicitBranch!;
    for (final b in AppBranch.values) {
      if (b != AppBranch.manado && matchesBranch(b)) return b;
    }
    return AppBranch.manado;
  }
}

class LocationResult {
  final double lat;
  final double lng;
  final double accuracyMeter;
  final bool isGpsEnabled;
  final bool isMockLocation;
  final bool isFallback;
  final bool isDefaultFallback;
  final String posName;
  final String cabangName;
  final String fullAddress;
  final String locationTag;
  final Color tagColor;

  LocationResult({
    required this.lat,
    required this.lng,
    required this.accuracyMeter,
    this.isGpsEnabled = true,
    this.isMockLocation = false,
    this.isFallback = false,
    bool? isDefaultFallback,
    required this.posName,
    required this.cabangName,
    required this.fullAddress,
    required this.locationTag,
    this.tagColor = const Color(0xFFF59E0B),
  }) : isDefaultFallback = isDefaultFallback ?? isFallback;
}

class LocationService {
  // Helper untuk tampilkan "Nama Pos (TAG)" — contoh: Toko Bintang Manado (TBM)
  static String displayName(PosLocation pos) {
    final tag = pos.locationTag.trim();
    if (tag.isEmpty) return pos.posName;
    // Hindari duplikat jika posName sudah mengandung tag
    if (pos.posName.contains('($tag)')) return pos.posName;
    return '${pos.posName} ($tag)';
  }

  static final List<PosLocation> _defaultSeed = [
    const PosLocation(
      posId: 'POS-PBM-01',
      posName: 'Pasar Bersehati Manado',
      cabangName: 'KC BSG',
      fullAddress:
          'Jl. Nusantara No.17, Calaca, Wenang, Kota Manado, Sulawesi Utara',
      locationTag: 'PBM',
      tagColor: Color(0xFFF59E0B),
      lat: 1.4980709,
      lng: 124.8415709,
    ),
    const PosLocation(
      posId: 'POS-PKM-01',
      posName: 'Pelabuhan Kalimas Manado',
      cabangName: 'KC BSG',
      fullAddress: 'Jl. Rumambi, Calaca, Wenang, Kota Manado, Sulawesi Utara',
      locationTag: 'PKM',
      tagColor: Color(0xFFF59E0B),
      lat: 1.4986164,
      lng: 124.8400064,
    ),
    const PosLocation(
      posId: 'POS-MPP-01',
      posName: 'Mall Pelayanan Publik',
      cabangName: 'KC BSG',
      fullAddress:
          'Jl. Piere Tendean, Sario Tumpaan, Sario, Kota Manado, Sulawesi Utara 95114',
      locationTag: 'MPP',
      tagColor: Color(0xFFF59E0B),
      lat: 1.4689489,
      lng: 124.8303596,
    ),
    const PosLocation(
      posId: 'POS-NBM-01',
      posName: 'New Bendar Manado',
      cabangName: 'KC BSG',
      fullAddress:
          'President Shopping Center, Jl. Walanda Maramis, Pinaesaan, Wenang, Kota Manado, Sulawesi Utara',
      locationTag: 'NBM',
      tagColor: Color(0xFFF59E0B),
      lat: 1.4934467,
      lng: 124.8416130,
    ),
    const PosLocation(
      posId: 'POS-PPM-01',
      posName: 'Pasar Pinasungkulan Manado',
      cabangName: 'KC BSG',
      fullAddress:
          'Jl. Pasar Karombasan, Karombasan Utara, Wanea, Kota Manado, Sulawesi Utara',
      locationTag: 'PPM',
      tagColor: Color(0xFFF59E0B),
      lat: 1.4567512,
      lng: 124.8402042,
    ),
    const PosLocation(
      posId: 'POS-TBM-01',
      posName: 'Toko Bintang Manado',
      cabangName: 'KC BSG',
      fullAddress:
          'Jl. A.A. Maramis No.291, Paniki Bawah, Kec. Mapanget, Kota Manado, Sulawesi Utara',
      locationTag: 'TBM',
      tagColor: Color(0xFFF59E0B),
      lat: 1.5030,
      lng: 124.9000,
    ),
    const PosLocation(
      posId: 'POS-MGAM-01',
      posName: 'Mie Gacoan AA Maramis',
      cabangName: 'KC BSG',
      fullAddress:
          'Jl. A.A. Maramis, Paniki Bawah, Kec. Mapanget, Kota Manado, Sulawesi Utara',
      locationTag: 'MGAM',
      tagColor: Color(0xFFF59E0B),
      lat: 1.5059531,
      lng: 124.9033492,
    ),
    const PosLocation(
      posId: 'POS-MGMM-01',
      posName: 'Mie Gacoan AirMadidi',
      cabangName: 'KC BSG',
      fullAddress:
          'CXCP+V34, Airmadidi Atas, Kec. Airmadidi, Kabupaten Minahasa Utara, Sulawesi Utara',
      locationTag: 'MGMM',
      tagColor: Color(0xFFF59E0B),
      lat: 1.4221375,
      lng: 124.9852031,
    ),
    const PosLocation(
      posId: 'POS-MGBP-01',
      posName: 'Mie Gacoan Babe Palar',
      cabangName: 'KC BSG',
      fullAddress:
          'Jl. Babe Palar No.81, Madidir Ure, Kec. Maesa, Kota Bitung, Sulawesi Utara',
      locationTag: 'MGBP',
      tagColor: Color(0xFFF59E0B),
      lat: 1.4429952,
      lng: 125.1583095,
    ),
    const PosLocation(
      posId: 'POS-MGTO-01',
      posName: 'Mie Gacoan Tomohon',
      cabangName: 'KC BSG',
      fullAddress:
          'Jl. Raya Tomohon, Talete Satu, Kec. Tomohon Tengah, Kota Tomohon, Sulawesi Utara',
      locationTag: 'MGTO',
      tagColor: Color(0xFFF59E0B),
      lat: 1.3285085,
      lng: 124.8396419,
    ),
    const PosLocation(
      posId: 'POS-MGKB-01',
      posName: 'Mie Gacoan Kotamobagu',
      cabangName: 'KC BSG',
      fullAddress:
          'P7JX+JXX, Molinow, Kec. Kotamobagu Barat, Kota Kotamobagu, Sulawesi Utara',
      locationTag: 'MGKB',
      tagColor: Color(0xFFF59E0B),
      lat: 0.7316125,
      lng: 124.2999844,
    ),
    const PosLocation(
      posId: 'POS-MGNW-01',
      posName: 'Mie Gacoan Nani Wartabone',
      cabangName: 'KC BSG',
      fullAddress:
          'Jl. Nani Wartabone No.05, Heledulaa Selatan, Kec. Kota Timur, Kota Gorontalo, Gorontalo',
      locationTag: 'MGNW',
      tagColor: Color(0xFFF59E0B),
      lat: 0.5397008,
      lng: 123.0610370,
    ),
    const PosLocation(
      posId: 'POS-MGGJ-01',
      posName: 'Mie Gacoan Gorontalo Jhon',
      cabangName: 'KC BSG',
      fullAddress: 'H3C4+FX9, Tapa, Kec. Sipatana, Kota Gorontalo, Gorontalo',
      locationTag: 'MGGJ',
      tagColor: Color(0xFFF59E0B),
      lat: 0.5711625,
      lng: 123.0574844,
    ),
    const PosLocation(
      posId: 'POS-MGLG-01',
      posName: 'Mie Gacoan Limboto Gorontalo',
      cabangName: 'KC BSG',
      fullAddress:
          'JXCG+6M2, Jl. Jenderal Sudirman, Hunggaluwa, Kec. Limboto, Kabupaten Gorontalo, Gorontalo',
      locationTag: 'MGLG',
      tagColor: Color(0xFFF59E0B),
      lat: 0.6205125,
      lng: 122.9766406,
    ),
    // --- 15 Pos Pengelolaan KC Bali ---
    const PosLocation(
      posId: 'POS-DPS-PBKD',
      posName: 'PBKD',
      cabangName: 'KC Bali',
      fullAddress: 'Pos Pengelolaan PBKD, KC Bali',
      locationTag: 'PBKD',
      tagColor: Color(0xFFF59E0B),
      lat: -8.670458,
      lng: 115.212629,
    ),
    const PosLocation(
      posId: 'POS-DPS-PCD',
      posName: 'PCD',
      cabangName: 'KC Bali',
      fullAddress: 'Pos Pengelolaan PCD, KC Bali',
      locationTag: 'PCD',
      tagColor: Color(0xFFF59E0B),
      lat: -8.670458,
      lng: 115.212629,
    ),
    const PosLocation(
      posId: 'POS-DPS-PKRD',
      posName: 'PKRD',
      cabangName: 'KC Bali',
      fullAddress: 'Pos Pengelolaan PKRD, KC Bali',
      locationTag: 'PKRD',
      tagColor: Color(0xFFF59E0B),
      lat: -8.670458,
      lng: 115.212629,
    ),
    const PosLocation(
      posId: 'POS-DPS-PAS',
      posName: 'PAS',
      cabangName: 'KC Bali',
      fullAddress: 'Pos Pengelolaan PAS, KC Bali',
      locationTag: 'PAS',
      tagColor: Color(0xFFF59E0B),
      lat: -8.670458,
      lng: 115.212629,
    ),
    const PosLocation(
      posId: 'POS-DPS-PSD',
      posName: 'PSD',
      cabangName: 'KC Bali',
      fullAddress: 'Pos Pengelolaan PSD, KC Bali',
      locationTag: 'PSD',
      tagColor: Color(0xFFF59E0B),
      lat: -8.670458,
      lng: 115.212629,
    ),
    const PosLocation(
      posId: 'POS-DPS-PGA',
      posName: 'PGA',
      cabangName: 'KC Bali',
      fullAddress: 'Pos Pengelolaan PGA, KC Bali',
      locationTag: 'PGA',
      tagColor: Color(0xFFF59E0B),
      lat: -8.670458,
      lng: 115.212629,
    ),
    const PosLocation(
      posId: 'POS-DPS-TBB',
      posName: 'TBB',
      cabangName: 'KC Bali',
      fullAddress: 'Pos Pengelolaan TBB, KC Bali',
      locationTag: 'TBB',
      tagColor: Color(0xFFF59E0B),
      lat: -8.670458,
      lng: 115.212629,
    ),
    const PosLocation(
      posId: 'POS-DPS-TBG',
      posName: 'TBG',
      cabangName: 'KC Bali',
      fullAddress: 'Pos Pengelolaan TBG, KC Bali',
      locationTag: 'TBG',
      tagColor: Color(0xFFF59E0B),
      lat: -8.670458,
      lng: 115.212629,
    ),
    const PosLocation(
      posId: 'POS-DPS-KIH',
      posName: 'KIH',
      cabangName: 'KC Bali',
      fullAddress: 'Pos Pengelolaan KIH, KC Bali',
      locationTag: 'KIH',
      tagColor: Color(0xFFF59E0B),
      lat: -8.670458,
      lng: 115.212629,
    ),
    const PosLocation(
      posId: 'POS-DPS-BMS',
      posName: 'BMS',
      cabangName: 'KC Bali',
      fullAddress: 'Pos Pengelolaan BMS, KC Bali',
      locationTag: 'BMS',
      tagColor: Color(0xFFF59E0B),
      lat: -8.670458,
      lng: 115.212629,
    ),
    const PosLocation(
      posId: 'POS-DPS-BMK',
      posName: 'BMK',
      cabangName: 'KC Bali',
      fullAddress: 'Pos Pengelolaan BMK, KC Bali',
      locationTag: 'BMK',
      tagColor: Color(0xFFF59E0B),
      lat: -8.670458,
      lng: 115.212629,
    ),
    const PosLocation(
      posId: 'POS-DPS-SPD',
      posName: 'SPD',
      cabangName: 'KC Bali',
      fullAddress: 'Pos Pengelolaan SPD, KC Bali',
      locationTag: 'SPD',
      tagColor: Color(0xFFF59E0B),
      lat: -8.670458,
      lng: 115.212629,
    ),
    const PosLocation(
      posId: 'POS-DPS-GYS',
      posName: 'GYS',
      cabangName: 'KC Bali',
      fullAddress: 'Pos Pengelolaan GYS, KC Bali',
      locationTag: 'GYS',
      tagColor: Color(0xFFF59E0B),
      lat: -8.670458,
      lng: 115.212629,
    ),
    const PosLocation(
      posId: 'POS-DPS-PBB',
      posName: 'PBB',
      cabangName: 'KC Bali',
      fullAddress: 'Pos Pengelolaan PBB, KC Bali',
      locationTag: 'PBB',
      tagColor: Color(0xFFF59E0B),
      lat: -8.670458,
      lng: 115.212629,
    ),
    const PosLocation(
      posId: 'POS-DPS-RSPM',
      posName: 'RSPM',
      cabangName: 'KC Bali',
      fullAddress: 'Pos Pengelolaan RSPM, KC Bali',
      locationTag: 'RSPM',
      tagColor: Color(0xFFF59E0B),
      lat: -8.670458,
      lng: 115.212629,
    ),

    // HO Makassar: 12 lokasi visit. Koordinat sengaja 0 (tag-only) sampai
    // koordinat GPS asli tiap lokasi dipasang.
    // shortcut: lat/lng 0,0 bikin deteksi lokasi via GPS tidak pernah cocok;
    // isi koordinat asli kalau nanti HO butuh validasi radius GPS.
    const PosLocation(
      posId: 'POS-HO-TBP-01',
      posName: 'Toko Bintang Palangga',
      cabangName: 'HO Makassar',
      fullAddress: 'Toko Bintang Palangga, HO Makassar',
      locationTag: 'TBP',
      tagColor: Color(0xFFF59E0B),
      lat: 0,
      lng: 0,
    ),
    const PosLocation(
      posId: 'POS-HO-GMM-01',
      posName: 'Grand Mall Maros',
      cabangName: 'HO Makassar',
      fullAddress: 'Grand Mall Maros, HO Makassar',
      locationTag: 'GMM',
      tagColor: Color(0xFFF59E0B),
      lat: 0,
      lng: 0,
    ),
    const PosLocation(
      posId: 'POS-HO-RSWS-01',
      posName: 'Rumah Sakit Wahidin Sudirohusodo',
      cabangName: 'HO Makassar',
      fullAddress: 'Rumah Sakit Wahidin Sudirohusodo, HO Makassar',
      locationTag: 'RSWS',
      tagColor: Color(0xFFF59E0B),
      lat: 0,
      lng: 0,
    ),
    const PosLocation(
      posId: 'POS-HO-MGPO-01',
      posName: 'MG Polman',
      cabangName: 'HO Makassar',
      fullAddress: 'MG Polman, HO Makassar',
      locationTag: 'MGPO',
      tagColor: Color(0xFFF59E0B),
      lat: 0,
      lng: 0,
    ),
    const PosLocation(
      posId: 'POS-HO-MGPI-01',
      posName: 'MG Pinrang',
      cabangName: 'HO Makassar',
      fullAddress: 'MG Pinrang, HO Makassar',
      locationTag: 'MGPI',
      tagColor: Color(0xFFF59E0B),
      lat: 0,
      lng: 0,
    ),
    const PosLocation(
      posId: 'POS-HO-MGWJ-01',
      posName: 'MG Wajo',
      cabangName: 'HO Makassar',
      fullAddress: 'MG Wajo, HO Makassar',
      locationTag: 'MGWJ',
      tagColor: Color(0xFFF59E0B),
      lat: 0,
      lng: 0,
    ),
    const PosLocation(
      posId: 'POS-HO-PCC-01',
      posName: 'Private Care Centre',
      cabangName: 'HO Makassar',
      fullAddress: 'Private Care Centre, HO Makassar',
      locationTag: 'PCC',
      tagColor: Color(0xFFF59E0B),
      lat: 0,
      lng: 0,
    ),
    const PosLocation(
      posId: 'POS-HO-MGPP-01',
      posName: 'MG Pepaya Bone',
      cabangName: 'HO Makassar',
      fullAddress: 'MG Pepaya Bone, HO Makassar',
      locationTag: 'MGPP',
      tagColor: Color(0xFFF59E0B),
      lat: 0,
      lng: 0,
    ),
    const PosLocation(
      posId: 'POS-HO-MGSP-01',
      posName: 'MG Sidrap',
      cabangName: 'HO Makassar',
      fullAddress: 'MG Sidrap, HO Makassar',
      locationTag: 'MGSP',
      tagColor: Color(0xFFF59E0B),
      lat: 0,
      lng: 0,
    ),
    const PosLocation(
      posId: 'POS-HO-MGKW-01',
      posName: 'MG Kendari',
      cabangName: 'HO Makassar',
      fullAddress: 'MG Kendari, HO Makassar',
      locationTag: 'MGKW',
      tagColor: Color(0xFFF59E0B),
      lat: 0,
      lng: 0,
    ),
    const PosLocation(
      posId: 'POS-HO-KMS-01',
      posName: 'Karsa Mini Soccer',
      cabangName: 'HO Makassar',
      fullAddress: 'Karsa Mini Soccer, HO Makassar',
      locationTag: 'KMS',
      tagColor: Color(0xFFF59E0B),
      lat: 0,
      lng: 0,
    ),
    const PosLocation(
      posId: 'POS-HO-PJT-01',
      posName: 'Pusat Jantung Terpadu',
      cabangName: 'HO Makassar',
      fullAddress: 'Pusat Jantung Terpadu, HO Makassar',
      locationTag: 'PJT',
      tagColor: Color(0xFFF59E0B),
      lat: 0,
      lng: 0,
    ),
  ];

  static List<PosLocation> _locations = [];
  static LocationResult? _cachedLocationResult;
  static DateTime? _lastLocationFetchTime;

  static bool get isLastLocationMocked =>
      _cachedLocationResult?.isMockLocation ?? false;
  static LocationResult? get lastLocationResult => _cachedLocationResult;

  @visibleForTesting
  static http.Client? clientOverride;

  static http.Client get _client => clientOverride ?? http.Client();

  @visibleForTesting
  static Future<List<geo.Location>> Function(String address)?
  nativeGeocodeLookupOverride;

  @visibleForTesting
  static bool? isWebOverride;

  static bool get _isWeb => isWebOverride ?? kIsWeb;

  @visibleForTesting
  static void setCachedLocationForTesting(LocationResult? result) {
    _cachedLocationResult = result;
  }

  @visibleForTesting
  static void resetForTesting() {
    _locations = [];
    _cachedLocationResult = null;
    _lastLocationFetchTime = null;
    clientOverride = null;
    nativeGeocodeLookupOverride = null;
    isWebOverride = null;
  }

  static bool _isValidIndonesiaCoords(double lat, double lng) {
    if (lat == 0.0 && lng == 0.0) return false;
    if (lat < -11.0 || lat > 6.0 || lng < 95.0 || lng > 141.0) return false;
    return true;
  }

  static Future<({double lat, double lng})?> geocodeAddress(
    String address,
    AppBranch branch,
  ) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return null;

    String query = trimmed;
    final lower = query.toLowerCase();
    switch (branch) {
      case AppBranch.manado:
        if (!lower.contains('manado')) {
          query = '$query, Manado, Sulawesi Utara';
        }
        break;
      case AppBranch.bali:
        if (!lower.contains('bali')) {
          query = '$query, Bali';
        }
        break;
      case AppBranch.ho:
        if (!lower.contains('makassar')) {
          query = '$query, Makassar, Sulawesi Selatan';
        }
        break;
    }

    try {
      if (_isWeb) {
        final encoded = Uri.encodeComponent(query);
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=id&q=$encoded',
        );
        final response = await _client
            .get(url, headers: {'User-Agent': 'bssparking_timemark/1.0'})
            .timeout(const Duration(seconds: 8));
        if (response.statusCode != 200) return null;
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is! List || decoded.isEmpty) return null;
        final first = decoded.first;
        if (first is! Map) return null;
        final latStr = first['lat']?.toString();
        final lonStr = first['lon']?.toString();
        if (latStr == null || lonStr == null) return null;
        final lat = double.tryParse(latStr);
        final lng = double.tryParse(lonStr);
        if (lat == null || lng == null) return null;
        if (!_isValidIndonesiaCoords(lat, lng)) return null;
        return (lat: lat, lng: lng);
      } else {
        final List<geo.Location> locations;
        if (nativeGeocodeLookupOverride != null) {
          locations = await nativeGeocodeLookupOverride!(
            query,
          ).timeout(const Duration(seconds: 8));
        } else {
          locations = await geo.Geocoding()
              .locationFromAddress(query)
              .timeout(const Duration(seconds: 8));
        }
        if (locations.isEmpty) return null;
        final first = locations.first;
        final lat = first.latitude;
        final lng = first.longitude;
        if (!_isValidIndonesiaCoords(lat, lng)) return null;
        return (lat: lat, lng: lng);
      }
    } catch (_) {
      return null;
    }
  }

  static const String keySeedCoordsMigration = 'bss_location_seed_coords_v3';

  static const Set<String> _manadoSeedIds = {
    'POS-PBM-01',
    'POS-PKM-01',
    'POS-MPP-01',
    'POS-PPM-01',
    'POS-NBM-01',
    'POS-TBM-01',
    'POS-MGAM-01',
    'POS-MGMM-01',
    'POS-MGBP-01',
    'POS-MGTO-01',
    'POS-MGKB-01',
    'POS-MGNW-01',
    'POS-MGGJ-01',
    'POS-MGLG-01',
  };

  static void _ensureInitialized() {
    if (_locations.isEmpty) {
      final saved = StorageService.getLocations();
      final hasSynced = StorageService.hasLocationSyncedRemote();
      if (saved != null && saved.isNotEmpty) {
        // Kunci merge = posId (identitas lokasi), bukan tag: dua cabang boleh
        // punya tag mirip dan seed baru tidak boleh tertelan lokasi cabang lain.
        final existingIds = saved.map((e) => e.posId).toSet();
        // Migrasikan warna default seed menjadi standard BSS Orange (#F59E0B)
        final merged = saved.map((pos) {
          final isSeed = _defaultSeed.any((s) => s.posId == pos.posId);
          if (isSeed && pos.tagColor != const Color(0xFFF59E0B)) {
            return pos.copyWith(tagColor: const Color(0xFFF59E0B));
          }
          return pos;
        }).toList();
        if (!hasSynced) {
          for (final seed in _defaultSeed) {
            if (!existingIds.contains(seed.posId)) {
              merged.add(seed);
            }
          }
        }
        _locations = merged;
      } else {
        _locations = List.from(_defaultSeed);
      }
    }

    // Migrasi sekali jalan koordinat & alamat 14 seed Manado (v3) + self-healing koordinat lama
    final isMigrated = StorageService.getBool(keySeedCoordsMigration) ?? false;
    final seedMap = {for (final s in _defaultSeed) s.posId: s};
    final seedTagMap = {
      for (final s in _defaultSeed) s.locationTag.toUpperCase(): s,
    };

    bool needsSave = !isMigrated;
    _locations = _locations.map((loc) {
      final seed =
          seedMap[loc.posId] ??
          seedTagMap[loc.locationTag.trim().toUpperCase()];
      if (seed != null && _manadoSeedIds.contains(seed.posId)) {
        // Deteksi self-healing: jika lokasi masih menggunakan koordinat lama salah
        // (MGBP di Manado, TBM di dekat PBM Pasar 45, atau koordinat lama PBM/PKM)
        final tag = loc.locationTag.trim().toUpperCase();
        final isOldMgbp =
            tag == 'MGBP' &&
            (loc.lng < 125.0 || (loc.lat - 1.472).abs() < 0.005);
        final isOldTbm =
            tag == 'TBM' &&
            (loc.lng < 124.88 || (loc.lat - 1.492).abs() < 0.005);
        final isOldPbm = tag == 'PBM' && (loc.lat - 1.493055).abs() < 0.002;
        final isOldPkm = tag == 'PKM' && (loc.lat - 1.494722).abs() < 0.002;

        if (!isMigrated || isOldMgbp || isOldTbm || isOldPbm || isOldPkm) {
          needsSave = true;
          return loc.copyWith(
            posId: seed.posId,
            lat: seed.lat,
            lng: seed.lng,
            fullAddress: seed.fullAddress,
          );
        }
      }
      return loc;
    }).toList();

    if (needsSave) {
      StorageService.saveLocations(_locations);
      StorageService.setBool(keySeedCoordsMigration, true);
    }
  }

  /// Reset koordinat seluruh lokasi seed cabang tertentu ke nilai default resmi.
  static Future<void> resetCoordinatesToSeed(AppBranch branch) async {
    _ensureInitialized();
    final seedMap = {for (final s in _defaultSeed) s.posId: s};
    final seedTagMap = {
      for (final s in _defaultSeed) s.locationTag.trim().toUpperCase(): s,
    };

    _locations = _locations.map((loc) {
      if (!loc.matchesBranch(branch)) return loc;
      final seed =
          seedMap[loc.posId] ??
          seedTagMap[loc.locationTag.trim().toUpperCase()];
      if (seed != null) {
        return loc.copyWith(
          posId: seed.posId,
          lat: seed.lat,
          lng: seed.lng,
          fullAddress: seed.fullAddress,
        );
      }
      return loc;
    }).toList();

    await StorageService.saveLocations(_locations);
    await StorageService.setBool(keySeedCoordsMigration, true);
  }

  /// Seluruh lokasi tersimpan di sistem (lintas cabang)
  static List<PosLocation> get allLocations {
    _ensureInitialized();
    return List.unmodifiable(_locations);
  }

  /// Lokasi yang aktif dan relevan untuk cabang saat ini (KC BSG/Manado atau KC Bali)
  static List<PosLocation> get availablePosList {
    return getLocationsByBranch(BranchService.instance.currentBranch);
  }

  /// Mengambil daftar lokasi yang secara ketat terisolasi untuk cabang tertentu
  static List<PosLocation> getLocationsByBranch(AppBranch branch) {
    _ensureInitialized();
    return List.unmodifiable(
      _locations.where((p) => p.matchesBranch(branch)).toList(),
    );
  }

  /// Lokasi aktif saat ini untuk cabang yang sedang dipilih
  static PosLocation get currentPos {
    _ensureInitialized();
    final branch = BranchService.instance.currentBranch;
    final branchList = availablePosList;
    if (branchList.isEmpty) {
      return _defaultSeed.firstWhere(
        (p) => p.matchesBranch(branch),
        orElse: () => _defaultSeed.first,
      );
    }

    // 1. Cek apakah ada saved active posId spesifik untuk cabang ini
    final savedPosId = StorageService.getString('active_pos_id_${branch.code}');
    if (savedPosId != null && savedPosId.isNotEmpty) {
      final found = branchList.where((p) => p.posId == savedPosId).firstOrNull;
      if (found != null) return found;
    }

    // 2. Fallback ke default location tag cabang (PBM untuk Manado, PBKD untuk Bali)
    final defaultTag = branch.defaultLocationTag;
    final defaultPos = branchList
        .where((p) => p.locationTag.toUpperCase() == defaultTag)
        .firstOrNull;
    if (defaultPos != null) return defaultPos;

    // 3. Fallback: lokasi pertama di cabang ini
    return branchList.first;
  }

  static void setCurrentPos(PosLocation pos) => currentPos = pos;

  static set currentPos(PosLocation pos) {
    _ensureInitialized();
    final currentBranch = BranchService.instance.currentBranch;
    // Jika pos yang diset tidak cocok dengan cabang yang sedang aktif, tolak
    if (!pos.matchesBranch(currentBranch)) {
      debugPrint(
        '[LocationService] Guard: Pos ${pos.locationTag} (${pos.cabangName}) tidak cocok dengan cabang aktif ${currentBranch.name}',
      );
      return;
    }
    final list = List<PosLocation>.from(_locations);
    final idx = list.indexWhere((p) => p.posId == pos.posId);
    if (idx != -1) {
      list.removeAt(idx);
      list.insert(0, pos);
    } else {
      list.insert(0, pos);
    }
    _locations = list;
    StorageService.saveLocations(_locations);

    final targetBranch = pos.branch;
    StorageService.setString('active_pos_id_${targetBranch.code}', pos.posId);
    clearLocationCache();
  }

  static void clearLocationCache() {
    _cachedLocationResult = null;
    _lastLocationFetchTime = null;
  }

  /// Override hasil lokasi untuk unit/widget testing (SEC-06).
  @visibleForTesting
  static Future<LocationResult> Function()? testLocationOverride;
  static bool get hasTestLocationOverride => testLocationOverride != null;

  /// Cari PosLocation berdasarkan tag (misal 'PBM', 'TBM', 'PBKD'), nama pos, atau kata kunci teks tugas
  static PosLocation? findPosByTagOrName(String query, {AppBranch? branch}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;

    final targetBranch = branch ?? BranchService.instance.currentBranch;
    final list = getLocationsByBranch(targetBranch);
    const stopWords = {
      'pos',
      'gate',
      'maintenance',
      'sop',
      'tugas',
      'cek',
      'titik',
      'unit',
      'keluar',
      'masuk',
      'manado',
      'bali',
      'kc',
      'bss',
      'lokasi',
    };

    // 1. Exact match pada locationTag, posName, atau posId di cabang target
    for (final pos in list) {
      final tag = pos.locationTag.toLowerCase();
      final name = pos.posName.toLowerCase();
      final id = pos.posId.toLowerCase();
      if (tag == q || name == q || id == q) {
        return pos;
      }
    }

    // 2. Exact match tag di dalam string sebagai kata utuh (contoh query: "Pos TBM", "TBM Masuk", "Area TBM")
    for (final pos in list) {
      final tag = pos.locationTag.toLowerCase();
      if (tag.isNotEmpty && !stopWords.contains(tag)) {
        final reg = RegExp('\\b${RegExp.escape(tag)}\\b', caseSensitive: false);
        if (reg.hasMatch(q) || tag == q) {
          return pos;
        }
      }
    }

    // 3. Substring match pada posId (hanya jika query spesifik bukan stop word)
    if (!stopWords.contains(q) && q.length >= 3) {
      for (final pos in list) {
        final id = pos.posId.toLowerCase();
        if (id.contains(q)) {
          return pos;
        }
      }
    }

    // 4. Substring match pada posName (misal 'Toko Bintang' in 'Toko Bintang Manado')
    if (!stopWords.contains(q) && q.length >= 3) {
      for (final pos in list) {
        final name = pos.posName.toLowerCase();
        if (name.contains(q) || q.contains(name)) {
          return pos;
        }
      }
    }

    // 5. Token-based search jika query berupa kalimat panjang (misal 'Maintenance Manless Gate - TBM')
    final tokens = q
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), ' ')
        .split(' ')
        .where((t) => t.length >= 2 && !stopWords.contains(t))
        .toList();

    for (final token in tokens) {
      for (final pos in list) {
        final tag = pos.locationTag.toLowerCase();
        if (tag == token) {
          return pos;
        }
      }
    }

    for (final token in tokens) {
      if (token.length >= 3) {
        for (final pos in list) {
          final name = pos.posName.toLowerCase();
          if (name.contains(token)) {
            return pos;
          }
        }
      }
    }

    // Catatan: Pencarian dibatasi ketat pada cabang target untuk mencegah tag cabang lain (misal PCD Bali) bocor ke Manado
    return null;
  }

  /// Resolve PosLocation dari task daily (posTag, posName, judul)
  /// Mengikuti kata kunci lokasi yang diinputkan SPV secara cerdas terisolasi per cabang
  static PosLocation? resolveLocationFromTask({
    String? posTag,
    String? posName,
    String? judul,
    AppBranch? branch,
  }) {
    final targetBranch = branch ?? BranchService.instance.currentBranch;

    // 1. Cek posTag terlebih dahulu (biasanya paling spesifik, misal 'TBM')
    if (posTag != null && posTag.trim().isNotEmpty && posTag.trim() != '-') {
      final loc = findPosByTagOrName(posTag, branch: targetBranch);
      if (loc != null) return loc;
    }

    // 2. Cek posName (misal 'Toko Bintang Manado' atau 'TBM')
    if (posName != null && posName.trim().isNotEmpty && posName.trim() != '-') {
      final loc = findPosByTagOrName(posName, branch: targetBranch);
      if (loc != null) return loc;
    }

    // 3. Cek judul tugas jika mengandung kata kunci lokasi (misal 'Maintenance Manless Gate - TBM')
    if (judul != null && judul.trim().isNotEmpty) {
      final loc = findPosByTagOrName(judul, branch: targetBranch);
      if (loc != null) return loc;
    }

    // 4. Jika posTag atau posName diisi tetapi belum ada di daftar pos (lokasi baru dari SPV, misal 'MTC'),
    // daftarkan secara dinamis ke cabang yang sesuai agar langsung terpilih di dropdown dan bisa dikerjakan
    final targetRaw =
        (posTag != null && posTag.trim().isNotEmpty && posTag.trim() != '-')
        ? posTag.trim()
        : (posName != null && posName.trim().isNotEmpty && posName.trim() != '-'
              ? posName.trim()
              : null);

    if (targetRaw != null &&
        targetRaw.isNotEmpty &&
        targetRaw.toLowerCase() != 'umum') {
      final cleanTag = targetRaw.toUpperCase();
      final cleanName =
          (posName != null &&
              posName.trim().isNotEmpty &&
              posName.trim() != '-')
          ? posName.trim()
          : targetRaw;

      final posPrefix = targetBranch == AppBranch.bali
          ? 'POS-DPS-'
          : (targetBranch == AppBranch.ho ? 'POS-HO-' : 'POS-');

      final newLoc = PosLocation(
        posId: '$posPrefix${cleanTag.replaceAll(RegExp(r'[^A-Z0-9]'), '')}-01',
        posName: cleanName,
        cabangName: targetBranch.name,
        fullAddress: cleanName,
        locationTag: cleanTag,
        tagColor: const Color(0xFFF59E0B),
        lat: currentPos.lat,
        lng: currentPos.lng,
      );
      addLocation(newLoc);
      return newLoc;
    }

    return null;
  }

  static Future<void> addLocation(PosLocation pos) async {
    _ensureInitialized();
    final list = List<PosLocation>.from(_locations);
    list.insert(0, pos);
    _locations = list;
    await StorageService.saveLocations(_locations);
    final targetBranch = pos.branch;
    await StorageService.setString(
      'active_pos_id_${targetBranch.code}',
      pos.posId,
    );
    clearLocationCache();

    // Enqueue for remote import and fire-and-forget flush
    final queue = StorageService.getLocationImportQueue();
    if (!queue.any((q) => q.posId == pos.posId)) {
      queue.add(pos);
      await StorageService.saveLocationImportQueue(queue);
    }
    unawaited(_flushImportQueue().catchError((_) {}));
  }

  static Future<void> updateLocation(PosLocation pos) async {
    _ensureInitialized();
    final list = List<PosLocation>.from(_locations);
    final idx = list.indexWhere((p) => p.posId == pos.posId);
    if (idx != -1) {
      list[idx] = pos;
      final updated = list.removeAt(idx);
      list.insert(0, updated);
      _locations = list;
      await StorageService.saveLocations(_locations);
      final targetBranch = pos.branch;
      await StorageService.setString(
        'active_pos_id_${targetBranch.code}',
        pos.posId,
      );
      clearLocationCache();
    }
  }

  static Future<void> deleteLocation(String posId) async {
    _ensureInitialized();
    final list = List<PosLocation>.from(_locations);
    list.removeWhere((p) => p.posId == posId);
    _locations = list.isNotEmpty ? list : List.from(_defaultSeed);
    await StorageService.saveLocations(_locations);
    clearLocationCache();
  }

  /// GET active rows, replace local list, keep + queue local-only rows for import, persist. Never throws.
  static Future<bool> syncFromRemote() async {
    _ensureInitialized();
    try {
      final uri = Uri.parse(
        '${DailyTaskService.baseUrl}/rest/v1/pos_locations?select=*&active=eq.true',
      );
      final client = _client;
      final res = await client
          .get(
            uri,
            headers: {
              'apikey': DailyTaskService.anonKey,
              'Authorization': 'Bearer ${DailyTaskService.anonKey}',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) {
        return false;
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! List) return false;

      final remoteLocations = decoded
          .map((m) => PosLocation.fromRemoteJson(m as Map<String, dynamic>))
          .toList();

      final remoteIds = remoteLocations.map((r) => r.posId).toSet();
      final seedIds = _defaultSeed.map((s) => s.posId).toSet();

      final currentList = List<PosLocation>.from(_locations);
      final localOnly = currentList
          .where(
            (loc) =>
                !remoteIds.contains(loc.posId) && !seedIds.contains(loc.posId),
          )
          .toList();

      final queue = StorageService.getLocationImportQueue();
      final queueIds = queue.map((q) => q.posId).toSet();
      for (final loc in localOnly) {
        if (!queueIds.contains(loc.posId)) {
          queue.add(loc);
          queueIds.add(loc.posId);
        }
      }
      await StorageService.saveLocationImportQueue(queue);

      final merged = <PosLocation>[...remoteLocations];
      for (final loc in localOnly) {
        if (!remoteIds.contains(loc.posId)) {
          merged.add(loc);
        }
      }

      _locations = merged;
      await StorageService.saveLocations(_locations);
      await StorageService.setLocationSyncedRemote(true);

      await _flushImportQueue();

      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _flushImportQueue() async {
    final queue = StorageService.getLocationImportQueue();
    if (queue.isEmpty) return;

    final token = DailyTaskService.sessionToken;
    final remaining = List<PosLocation>.from(queue);
    final client = _client;

    while (remaining.isNotEmpty) {
      final chunk = remaining.take(50).toList();
      final body = {
        'action': 'import',
        'locations': chunk.map((loc) => loc.toRemoteJson()).toList(),
      };

      try {
        final uri = Uri.parse(
          '${DailyTaskService.baseUrl}/functions/v1/pos-locations',
        );
        final res = await client
            .post(
              uri,
              headers: {
                'apikey': DailyTaskService.anonKey,
                'Authorization': 'Bearer ${DailyTaskService.anonKey}',
                'Content-Type': 'application/json',
                if (token != null && token.isNotEmpty) 'x-app-session': token,
              },
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final chunkIds = chunk.map((c) => c.posId).toSet();
          queue.removeWhere((q) => chunkIds.contains(q.posId));
          remaining.removeRange(0, chunk.length);
          await StorageService.saveLocationImportQueue(queue);
        } else {
          if (res.statusCode == 401 && token != null && token.isNotEmpty) {
            unawaited(DailyTaskService.handleUnauthorizedSession());
          }
          break;
        }
      } catch (_) {
        break;
      }
    }
  }

  /// SPV write. On ok also updates the local list. Sends x-app-session header and never sends password.
  static Future<RemoteWriteResult> saveLocationRemote(
    PosLocation pos, {
    String identity = '',
    String password = '',
  }) async {
    try {
      final uri = Uri.parse(
        '${DailyTaskService.baseUrl}/functions/v1/pos-locations',
      );
      final client = _client;
      final token = DailyTaskService.sessionToken;
      final body = {
        'action': 'upsert',
        'location': pos.toRemoteJson(),
      };

      final res = await client
          .post(
            uri,
            headers: {
              'apikey': DailyTaskService.anonKey,
              'Authorization': 'Bearer ${DailyTaskService.anonKey}',
              'Content-Type': 'application/json',
              if (token != null && token.isNotEmpty) 'x-app-session': token,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        _ensureInitialized();
        final list = List<PosLocation>.from(_locations);
        final idx = list.indexWhere((p) => p.posId == pos.posId);
        if (idx != -1) {
          list[idx] = pos;
        } else {
          list.insert(0, pos);
        }
        _locations = list;
        await StorageService.saveLocations(_locations);
        clearLocationCache();
        return RemoteWriteResult.ok;
      } else if (res.statusCode == 401) {
        if (token != null && token.isNotEmpty) {
          unawaited(DailyTaskService.handleUnauthorizedSession());
        }
        return RemoteWriteResult.invalidCredentials;
      } else if (res.statusCode == 403) {
        return RemoteWriteResult.notSupervisor;
      } else {
        return RemoteWriteResult.failed;
      }
    } on SocketException {
      return RemoteWriteResult.offline;
    } on TimeoutException {
      return RemoteWriteResult.offline;
    } on http.ClientException catch (e) {
      if (e.message.contains('SocketException') ||
          e.message.contains('Network')) {
        return RemoteWriteResult.offline;
      }
      return RemoteWriteResult.failed;
    } catch (_) {
      return RemoteWriteResult.failed;
    }
  }

  static Future<RemoteWriteResult> deleteLocationRemote(
    String posId, {
    String identity = '',
    String password = '',
  }) async {
    try {
      final uri = Uri.parse(
        '${DailyTaskService.baseUrl}/functions/v1/pos-locations',
      );
      final client = _client;
      final token = DailyTaskService.sessionToken;
      final body = {
        'action': 'delete',
        'pos_id': posId,
      };

      final res = await client
          .post(
            uri,
            headers: {
              'apikey': DailyTaskService.anonKey,
              'Authorization': 'Bearer ${DailyTaskService.anonKey}',
              'Content-Type': 'application/json',
              if (token != null && token.isNotEmpty) 'x-app-session': token,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        _ensureInitialized();
        final list = List<PosLocation>.from(_locations);
        list.removeWhere((p) => p.posId == posId);
        _locations = list;
        await StorageService.saveLocations(_locations);
        clearLocationCache();
        return RemoteWriteResult.ok;
      } else if (res.statusCode == 401) {
        if (token != null && token.isNotEmpty) {
          unawaited(DailyTaskService.handleUnauthorizedSession());
        }
        return RemoteWriteResult.invalidCredentials;
      } else if (res.statusCode == 403) {
        return RemoteWriteResult.notSupervisor;
      } else {
        return RemoteWriteResult.failed;
      }
    } on SocketException {
      return RemoteWriteResult.offline;
    } on TimeoutException {
      return RemoteWriteResult.offline;
    } on http.ClientException catch (e) {
      if (e.message.contains('SocketException') ||
          e.message.contains('Network')) {
        return RemoteWriteResult.offline;
      }
      return RemoteWriteResult.failed;
    } catch (_) {
      return RemoteWriteResult.failed;
    }
  }

  static Future<bool> isGpsServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return true;
    }
  }

  static Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> ensureLocationPermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get real device hardware GPS position in real-time with instant cache
  static Future<LocationResult> getCurrentLocation({
    bool simulateGpsOff = false,
  }) async {
    if (testLocationOverride != null) {
      final res = await testLocationOverride!();
      _cachedLocationResult = res;
      _lastLocationFetchTime = DateTime.now();
      return res;
    }

    final pos = currentPos;

    if (simulateGpsOff) {
      return LocationResult(
        lat: 0.0,
        lng: 0.0,
        accuracyMeter: 0.0,
        isGpsEnabled: false,
        isMockLocation: false,
        isFallback: true,
        isDefaultFallback: true,
        posName: pos.posName,
        cabangName: pos.cabangName,
        fullAddress: 'Lokasi tidak terdeteksi (GPS Nonaktif)',
        locationTag: pos.locationTag,
        tagColor: pos.tagColor,
      );
    }

    // Fast-cache return (valid within 15 seconds for real GPS fixes) to avoid freezing UI
    if (_cachedLocationResult != null &&
        !_cachedLocationResult!.isDefaultFallback &&
        _lastLocationFetchTime != null) {
      if (DateTime.now().difference(_lastLocationFetchTime!).inSeconds < 15) {
        return _cachedLocationResult!;
      }
    }

    try {
      final hasPermission = await ensureLocationPermission();
      if (hasPermission) {
        Position? position;

        // 1. Coba ambil Last Known Position perangkat terlebih dahulu (< 15ms)
        try {
          position = await Geolocator.getLastKnownPosition();
        } catch (_) {}

        // 2. Minta fresh hardware fix dengan timeout realistis 6 detik (bukan 2s)
        try {
          final freshPos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 6),
            ),
          );
          position = freshPos;
        } catch (_) {
          // Jika fresh fix timeout, tetap gunakan lastKnown jika ada
        }

        if (position != null &&
            (position.latitude != 0.0 || position.longitude != 0.0)) {
          String realAddress = pos.fullAddress;
          if (_cachedLocationResult == null ||
              calculateDistanceInMeters(
                    position.latitude,
                    position.longitude,
                    _cachedLocationResult!.lat,
                    _cachedLocationResult!.lng,
                  ) >
                  50) {
            try {
              if (!kIsWeb) {
                final placemarks = await geo.Geocoding()
                    .placemarkFromCoordinates(
                      position.latitude,
                      position.longitude,
                    )
                    .timeout(const Duration(seconds: 3));
                if (placemarks.isNotEmpty) {
                  final formatted = formatCleanAddressFromPlacemark(
                    placemarks.first,
                  );
                  if (formatted.isNotEmpty) {
                    realAddress = formatted;
                  }
                }
              }
            } catch (_) {}
          } else {
            realAddress = _cachedLocationResult!.fullAddress;
          }

          _cachedLocationResult = LocationResult(
            lat: position.latitude,
            lng: position.longitude,
            accuracyMeter: position.accuracy,
            isGpsEnabled: true,
            // Deteksi ketat hardware mock provider dari Position.isMocked
            isMockLocation: position.isMocked,
            isFallback: false,
            isDefaultFallback: false,
            posName: pos.posName,
            cabangName: pos.cabangName,
            fullAddress: realAddress.isNotEmpty
                ? cleanAddressString(realAddress)
                : cleanAddressString(pos.fullAddress),
            locationTag: pos.locationTag,
            tagColor: pos.tagColor,
          );
          _lastLocationFetchTime = DateTime.now();
          return _cachedLocationResult!;
        }
      }
    } catch (_) {}

    // SEC-06: Jangan pernah mensubstitusi koordinat resmi POS ketika GPS belum mengunci.
    _cachedLocationResult = LocationResult(
      lat: 0.0,
      lng: 0.0,
      accuracyMeter: 0,
      isGpsEnabled: false,
      isMockLocation: false,
      isFallback: true,
      isDefaultFallback: true,
      posName: pos.posName,
      cabangName: pos.cabangName,
      fullAddress: pos.fullAddress,
      locationTag: pos.locationTag,
      tagColor: pos.tagColor,
    );
    assert(
      _cachedLocationResult!.isFallback &&
          _cachedLocationResult!.isDefaultFallback,
      'SEC-03: fallback must be flagged isFallback=true',
    );
    // Catat waktu tapi jangan blokir fetch berikutnya jika masih fallback
    _lastLocationFetchTime = DateTime.now();
    return _cachedLocationResult!;
  }

  /// Calculates geodesic distance between two coordinate pairs in meters (Haversine formula)
  static double calculateDistanceInMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static double _degToRad(double deg) => deg * (pi / 180.0);

  /// Human-readable format of distance
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Sorts and returns list of locations by proximity to given coordinate
  static List<Map<String, dynamic>> getLocationsRankedByDistance(
    double userLat,
    double userLng, {
    AppBranch? branch,
  }) {
    final targetBranch = branch ?? BranchService.instance.currentBranch;
    final list = getLocationsByBranch(targetBranch);
    final ranked = list.map((loc) {
      final dist = calculateDistanceInMeters(
        userLat,
        userLng,
        loc.lat,
        loc.lng,
      );
      return {
        'location': loc,
        'distanceMeters': dist,
        'distanceText': formatDistance(dist),
      };
    }).toList();

    ranked.sort(
      (a, b) => (a['distanceMeters'] as double).compareTo(
        b['distanceMeters'] as double,
      ),
    );

    return ranked;
  }

  /// Memformat alamat dari placemark agar bersih, ringkas, tanpa 'Indonesia' dan tanpa duplikasi.
  /// Contoh: "Singkil Satu, Kec. Singkil, Kota Manado, Sulawesi Utara"
  static String formatCleanAddressFromPlacemark(geo.Placemark place) {
    final components = <String>[];

    // 1. Nama Jalan / Thoroughfare (hanya jika spesifik nama jalan, bukan duplikat kelurahan/kota)
    final thoroughfare = (place.thoroughfare ?? '').trim();
    final subThoroughfare = (place.subThoroughfare ?? '').trim();
    final lowerSubLoc = (place.subLocality ?? '').trim().toLowerCase();
    final lowerLoc = (place.locality ?? '').trim().toLowerCase();
    final lowerSubDist = (place.subAdministrativeArea ?? '')
        .trim()
        .toLowerCase();
    final lowerAdmin = (place.administrativeArea ?? '').trim().toLowerCase();

    if (thoroughfare.isNotEmpty) {
      final tLower = thoroughfare.toLowerCase();
      final isGeneric =
          tLower.contains('indonesia') ||
          tLower.contains('sulawesi') ||
          (lowerSubLoc.isNotEmpty && tLower == lowerSubLoc) ||
          (lowerLoc.isNotEmpty && tLower == lowerLoc) ||
          (lowerSubDist.isNotEmpty && tLower == lowerSubDist) ||
          (lowerAdmin.isNotEmpty && tLower == lowerAdmin);

      if (!isGeneric) {
        final road = subThoroughfare.isNotEmpty
            ? '$thoroughfare No. $subThoroughfare'
            : thoroughfare;
        components.add(road);
      }
    }

    // 2. Kelurahan / Desa (subLocality)
    final subLoc = (place.subLocality ?? '').trim();
    if (subLoc.isNotEmpty) {
      components.add(subLoc);
    }

    // 3. Kecamatan (locality)
    final loc = (place.locality ?? '').trim();
    if (loc.isNotEmpty) {
      if (!loc.toLowerCase().startsWith('kec')) {
        components.add('Kec. $loc');
      } else {
        components.add(loc);
      }
    }

    // 4. Kota / Kabupaten (subAdministrativeArea)
    final subAdmin = (place.subAdministrativeArea ?? '').trim();
    if (subAdmin.isNotEmpty) {
      components.add(subAdmin);
    }

    // 5. Provinsi (administrativeArea)
    final admin = (place.administrativeArea ?? '').trim();
    if (admin.isNotEmpty) {
      components.add(admin);
    }

    // Fallback jika komponen kosong: gunakan street atau name yang dibersihkan
    if (components.isEmpty) {
      final fallbackRaw =
          (place.street?.isNotEmpty == true ? place.street : place.name) ?? '';
      return cleanAddressString(fallbackRaw);
    }

    return cleanAddressString(components.join(', '));
  }

  /// Menghilangkan repetisi segmen, membuang kata "Indonesia", dan merapikan kapitalisasi.
  /// Input: "singkil satu kec singkil kota manado sulawesi utara, indonesia. singkil satu kota manado sulawesi utara"
  /// Output: "Singkil Satu, Kec. Singkil, Kota Manado, Sulawesi Utara"
  static String cleanAddressString(String raw) {
    if (raw.trim().isEmpty) return '';

    // 1. Buang kata negara "Indonesia" dan "ID"
    var text = raw
        .replaceAll(RegExp(r'\bIndonesia\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bID\b'), '')
        .trim();

    // 2. Normalisasi whitespace
    text = text
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    // 2b. Pisahkan keyword wilayah jika belum dipisah koma agar tidak tergabung dalam 1 kalimat panjang
    text = text.replaceAllMapped(
      RegExp(
        r'(?<=[^\s,])\s+(kec\.?|kel\.?|desa|kota|kab\.?|provinsi|prov\.?|aceh|sumatera|riau|jambi|bengkulu|lampung|bangka|dki|jakarta|jawa|banten|bali|nusa tenggara|ntb|ntt|kalimantan|sulawesi|gorontalo|maluku|papua)\b',
        caseSensitive: false,
      ),
      (m) => ', ${m[1]}',
    );

    // 3. Pecah berdasarkan koma, titik koma, atau titik pemisah kalimat (kecuali singkatan Jl., No., Kec., dsb.)
    final rawTokens = text.split(
      RegExp(
        r'[,;]|(?<!\b(?:jl|no|kec|kel|rt|rw|dr|ir|pt|cv))\.\s+',
        caseSensitive: false,
      ),
    );
    final resultParts = <String>[];
    final seen = <String>{};

    for (var token in rawTokens) {
      token = token.trim();
      token = token.replaceAll(RegExp(r'^[.,\s]+|[.,\s]+$'), '');
      if (token.isEmpty) continue;

      final norm = token.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      if (norm == 'indonesia' || norm == 'id') continue;

      // Cek apakah sudah pernah muncul atau identik
      bool duplicate = false;
      for (final s in seen) {
        if (s == norm || (s.length > 5 && s.contains(norm))) {
          duplicate = true;
          break;
        }
      }
      if (duplicate) continue;

      // Hapus token lama jika token baru ini superset yang lebih lengkap
      resultParts.removeWhere((existing) {
        final existingNorm = existing.toLowerCase().replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
        if (norm.length > 5 &&
            norm.contains(existingNorm) &&
            norm != existingNorm) {
          seen.remove(existingNorm);
          return true;
        }
        return false;
      });

      // Format kapitalisasi rapi per kata
      resultParts.add(_formatAddressWord(token));
      seen.add(norm);
    }

    return resultParts.join(', ');
  }

  static String _formatAddressWord(String segment) {
    final words = segment.split(' ');
    final out = <String>[];

    for (final w in words) {
      final trimmed = w.trim();
      if (trimmed.isEmpty) continue;
      final lower = trimmed.toLowerCase();

      if (lower == 'kec' || lower == 'kec.') {
        out.add('Kec.');
      } else if (lower == 'kel' || lower == 'kel.') {
        out.add('Kel.');
      } else if (lower == 'jl' || lower == 'jl.') {
        out.add('Jl.');
      } else if (lower == 'no' || lower == 'no.') {
        out.add('No.');
      } else if (lower == 'rt' || lower == 'rt.') {
        out.add('RT');
      } else if (lower == 'rw' || lower == 'rw.') {
        out.add('RW');
      } else if (lower == 'pos') {
        out.add('Pos');
      } else if (lower == 'kota') {
        out.add('Kota');
      } else if (lower == 'kab' || lower == 'kab.') {
        out.add('Kab.');
      } else {
        if (trimmed.length == 1) {
          out.add(trimmed.toUpperCase());
        } else {
          out.add(trimmed[0].toUpperCase() + trimmed.substring(1));
        }
      }
    }

    return out.join(' ');
  }
}
