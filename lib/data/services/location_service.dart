import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'storage_service.dart';

class PosLocation {
  final String posId;
  final String posName;
  final String cabangName;
  final String fullAddress;
  final String locationTag; // e.g. 'PBM/PKM', 'MEGAMAS', 'GATE 1'
  final Color tagColor;
  final double lat;
  final double lng;

  const PosLocation({
    required this.posId,
    required this.posName,
    required this.cabangName,
    required this.fullAddress,
    required this.locationTag,
    required this.tagColor,
    required this.lat,
    required this.lng,
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
      };

  factory PosLocation.fromJson(Map<String, dynamic> json) => PosLocation(
        posId: json['posId'] as String,
        posName: json['posName'] as String,
        cabangName: json['cabangName'] as String,
        fullAddress: json['fullAddress'] as String,
        locationTag: json['locationTag'] as String,
        tagColor: Color(json['tagColorValue'] as int? ?? 0xFFF59E0B),
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );

  PosLocation copyWith({
    String? posId,
    String? posName,
    String? cabangName,
    String? fullAddress,
    String? locationTag,
    Color? tagColor,
    double? lat,
    double? lng,
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
    );
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
      fullAddress: 'Pasar Bersehati, Kota Manado, Sulawesi Utara',
      locationTag: 'PBM',
      tagColor: Color(0xFFF59E0B),
      lat: 1.493055,
      lng: 124.841972,
    ),
    const PosLocation(
      posId: 'POS-PKM-01',
      posName: 'Pelabuhan Kalimas Manado',
      cabangName: 'KC BSG',
      fullAddress: 'Pelabuhan Kalimas, Kota Manado, Sulawesi Utara',
      locationTag: 'PKM',
      tagColor: Color(0xFFF59E0B),
      lat: 1.494722,
      lng: 124.839167,
    ),
    const PosLocation(
      posId: 'POS-MPP-01',
      posName: 'Mall Pelayanan Publik',
      cabangName: 'KC BSG',
      fullAddress: 'Mall Pelayanan Publik, Kota Manado, Sulawesi Utara',
      locationTag: 'MPP',
      tagColor: Color(0xFFF59E0B),
      lat: 1.487778,
      lng: 124.843056,
    ),
    const PosLocation(
      posId: 'POS-NBM-01',
      posName: 'New Bendar Manado',
      cabangName: 'KC BSG',
      fullAddress: 'New Bendar, Kota Manado, Sulawesi Utara',
      locationTag: 'NBM',
      tagColor: Color(0xFFF59E0B),
      lat: 1.488500,
      lng: 124.838889,
    ),
    const PosLocation(
      posId: 'POS-PPM-01',
      posName: 'Pasar Pinasungkulan Manado',
      cabangName: 'KC BSG',
      fullAddress: 'Pasar Pinasungkulan, Kota Manado, Sulawesi Utara',
      locationTag: 'PPM',
      tagColor: Color(0xFFF59E0B),
      lat: 1.464167,
      lng: 124.844722,
    ),
    const PosLocation(
      posId: 'POS-TBM-01',
      posName: 'Toko Bintang Manado',
      cabangName: 'KC BSG',
      fullAddress: 'Toko Bintang, Kota Manado, Sulawesi Utara',
      locationTag: 'TBM',
      tagColor: Color(0xFFF59E0B),
      lat: 1.492000,
      lng: 124.841000,
    ),
    const PosLocation(
      posId: 'POS-MGAM-01',
      posName: 'Mie Gacoan AA Maramis',
      cabangName: 'KC BSG',
      fullAddress: 'Jl. A.A. Maramis, Kota Manado, Sulawesi Utara',
      locationTag: 'MGAM',
      tagColor: Color(0xFFF59E0B),
      lat: 1.503200,
      lng: 124.878500,
    ),
    const PosLocation(
      posId: 'POS-MGMM-01',
      posName: 'Mie Gacoan AirMadidi',
      cabangName: 'KC BSG',
      fullAddress: 'Airmadidi, Minahasa Utara, Sulawesi Utara',
      locationTag: 'MGMM',
      tagColor: Color(0xFFF59E0B),
      lat: 1.428500,
      lng: 124.981000,
    ),
    const PosLocation(
      posId: 'POS-MGBP-01',
      posName: 'Mie Gacoan Babe Palar',
      cabangName: 'KC BSG',
      fullAddress: 'Jl. Babe Palar, Kota Manado, Sulawesi Utara',
      locationTag: 'MGBP',
      tagColor: Color(0xFFF59E0B),
      lat: 1.472000,
      lng: 124.838000,
    ),
    const PosLocation(
      posId: 'POS-MGTO-01',
      posName: 'Mie Gacoan Tomohon',
      cabangName: 'KC BSG',
      fullAddress: 'Kota Tomohon, Sulawesi Utara',
      locationTag: 'MGTO',
      tagColor: Color(0xFFF59E0B),
      lat: 1.328000,
      lng: 124.839000,
    ),
    const PosLocation(
      posId: 'POS-MGKB-01',
      posName: 'Mie Gacoan Kotamobagu',
      cabangName: 'KC BSG',
      fullAddress: 'Kotamobagu, Sulawesi Utara',
      locationTag: 'MGKB',
      tagColor: Color(0xFFF59E0B),
      lat: 0.742000,
      lng: 124.316000,
    ),
    const PosLocation(
      posId: 'POS-MGNW-01',
      posName: 'Mie Gacoan Nani Wartabone',
      cabangName: 'KC BSG',
      fullAddress: 'Jl. Nani Wartabone, Kota Gorontalo, Gorontalo',
      locationTag: 'MGNW',
      tagColor: Color(0xFFF59E0B),
      lat: 0.543000,
      lng: 123.059000,
    ),
    const PosLocation(
      posId: 'POS-MGGJ-01',
      posName: 'Mie Gacoan Gorontalo Jhon',
      cabangName: 'KC BSG',
      fullAddress: 'Kota Gorontalo, Gorontalo',
      locationTag: 'MGGJ',
      tagColor: Color(0xFFF59E0B),
      lat: 0.551000,
      lng: 123.065000,
    ),
    const PosLocation(
      posId: 'POS-MGLG-01',
      posName: 'Mie Gacoan Limboto Gorontalo',
      cabangName: 'KC BSG',
      fullAddress: 'Limboto, Kab. Gorontalo, Gorontalo',
      locationTag: 'MGLG',
      tagColor: Color(0xFFF59E0B),
      lat: 0.625000,
      lng: 122.980000,
    ),
  ];

  static List<PosLocation> _locations = [];
  static LocationResult? _cachedLocationResult;
  static DateTime? _lastLocationFetchTime;

  static bool get isLastLocationMocked => _cachedLocationResult?.isMockLocation ?? false;
  static bool get isLastLocationDefaultFallback => _cachedLocationResult?.isDefaultFallback ?? false;
  static LocationResult? get lastLocationResult => _cachedLocationResult;

  @visibleForTesting
  static void setCachedLocationForTesting(LocationResult? result) {
    _cachedLocationResult = result;
  }
  static List<PosLocation> get availablePosList {
    if (_locations.isEmpty) {
      final saved = StorageService.getLocations();
      if (saved != null && saved.isNotEmpty) {
        final existingTags = saved.map((e) => e.locationTag.trim().toUpperCase()).toSet();
        // Migrasikan warna default seed menjadi standard BSS Orange (#F59E0B)
        final merged = saved.map((pos) {
          final isSeed = _defaultSeed.any((s) => s.posId == pos.posId);
          if (isSeed && pos.tagColor != const Color(0xFFF59E0B)) {
            return pos.copyWith(tagColor: const Color(0xFFF59E0B));
          }
          return pos;
        }).toList();
        for (final seed in _defaultSeed) {
          if (!existingTags.contains(seed.locationTag.trim().toUpperCase())) {
            merged.add(seed);
          }
        }
        _locations = merged;
        StorageService.saveLocations(_locations);
      } else {
        _locations = List.from(_defaultSeed);
        StorageService.saveLocations(_locations);
      }
    }
    return List.unmodifiable(_locations);
  }

  static PosLocation get currentPos {
    final list = availablePosList;
    return list.isNotEmpty ? list.first : _defaultSeed.first;
  }

  static void setCurrentPos(PosLocation pos) => currentPos = pos;

  static set currentPos(PosLocation pos) {
    final list = List<PosLocation>.from(availablePosList);
    final idx = list.indexWhere((p) => p.posId == pos.posId);
    if (idx != -1) {
      list.removeAt(idx);
      list.insert(0, pos);
    } else {
      list.insert(0, pos);
    }
    _locations = list;
    StorageService.saveLocations(_locations);
    clearLocationCache();
  }

  static void clearLocationCache() {
    _cachedLocationResult = null;
    _lastLocationFetchTime = null;
  }

  /// Cari PosLocation berdasarkan tag (misal 'PBM', 'TBM') atau nama pos
  static PosLocation? findPosByTagOrName(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final pos in availablePosList) {
      if (pos.locationTag.toLowerCase() == q ||
          pos.posName.toLowerCase() == q ||
          pos.posId.toLowerCase() == q) {
        return pos;
      }
    }
    for (final pos in availablePosList) {
      if (pos.locationTag.toLowerCase().contains(q) ||
          pos.posName.toLowerCase().contains(q)) {
        return pos;
      }
    }
    return null;
  }

  static Future<void> addLocation(PosLocation pos) async {
    final list = List<PosLocation>.from(availablePosList);
    list.insert(0, pos);
    _locations = list;
    await StorageService.saveLocations(_locations);
  }

  static Future<void> updateLocation(PosLocation pos) async {
    final list = List<PosLocation>.from(availablePosList);
    final idx = list.indexWhere((p) => p.posId == pos.posId);
    if (idx != -1) {
      list[idx] = pos;
      // Auto-aktif: pindahkan yang di-edit ke posisi 0 agar langsung jadi currentPos
      final updated = list.removeAt(idx);
      list.insert(0, updated);
      _locations = list;
      await StorageService.saveLocations(_locations);
    }
  }

  static Future<void> deleteLocation(String posId) async {
    final list = List<PosLocation>.from(availablePosList);
    list.removeWhere((p) => p.posId == posId);
    _locations = list.isNotEmpty ? list : List.from(_defaultSeed);
    await StorageService.saveLocations(_locations);
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
  static Future<LocationResult> getCurrentLocation({bool simulateGpsOff = false}) async {
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

        if (position != null && (position.latitude != 0.0 || position.longitude != 0.0)) {
          String realAddress = pos.fullAddress;
          if (_cachedLocationResult == null ||
              calculateDistanceInMeters(
                    position.latitude,
                    position.longitude,
                    _cachedLocationResult!.lat,
                    _cachedLocationResult!.lng,
                  ) > 50) {
            try {
              if (!kIsWeb) {
                final placemarks = await geo.Geocoding()
                    .placemarkFromCoordinates(
                      position.latitude,
                      position.longitude,
                    )
                    .timeout(const Duration(seconds: 3));
                if (placemarks.isNotEmpty) {
                  final formatted = formatCleanAddressFromPlacemark(placemarks.first);
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

    // Fallback: GPS tidak tersedia atau belum lock — gunakan titik pos penugasan
    _cachedLocationResult = LocationResult(
      lat: pos.lat,
      lng: pos.lng,
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

    final a = sin(dLat / 2) * sin(dLat / 2) +
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
    double userLng,
  ) {
    final list = availablePosList;
    final ranked = list.map((loc) {
      final dist =
          calculateDistanceInMeters(userLat, userLng, loc.lat, loc.lng);
      return {
        'location': loc,
        'distanceMeters': dist,
        'distanceText': formatDistance(dist),
      };
    }).toList();

    ranked.sort((a, b) =>
        (a['distanceMeters'] as double).compareTo(b['distanceMeters'] as double));

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
    final lowerSubDist = (place.subAdministrativeArea ?? '').trim().toLowerCase();
    final lowerAdmin = (place.administrativeArea ?? '').trim().toLowerCase();

    if (thoroughfare.isNotEmpty) {
      final tLower = thoroughfare.toLowerCase();
      final isGeneric = tLower.contains('indonesia') ||
          tLower.contains('sulawesi') ||
          (lowerSubLoc.isNotEmpty && tLower == lowerSubLoc) ||
          (lowerLoc.isNotEmpty && tLower == lowerLoc) ||
          (lowerSubDist.isNotEmpty && tLower == lowerSubDist) ||
          (lowerAdmin.isNotEmpty && tLower == lowerAdmin);

      if (!isGeneric) {
        final road = subThoroughfare.isNotEmpty ? '$thoroughfare No. $subThoroughfare' : thoroughfare;
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
      final fallbackRaw = (place.street?.isNotEmpty == true ? place.street : place.name) ?? '';
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
    text = text.replaceAll(RegExp(r'[\r\n\t]+'), ' ').replaceAll(RegExp(r'\s+'), ' ');

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
      RegExp(r'[,;]|(?<!\b(?:jl|no|kec|kel|rt|rw|dr|ir|pt|cv))\.\s+', caseSensitive: false),
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
        final existingNorm = existing.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
        if (norm.length > 5 && norm.contains(existingNorm) && norm != existingNorm) {
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
