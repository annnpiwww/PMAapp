import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/services/branch_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/maintenance_log_service.dart';
import 'maintenance_location_detail_screen.dart';

/// Palet warna UI operasional light untuk Maintenance Map & Detail.
class MaintenanceMapPalette {
  static const Color bg = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceRaised = Color(0xFFF1F5F9);
  static const Color divider = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryBlue = primary;

  // Finding (Orange/Amber)
  static const Color findingIcon = Color(0xFFD97706);
  static const Color findingText = Color(0xFFB45309);
  static const Color findingBg = Color(0xFFFEF3C7);
  static const Color findingOrange = findingIcon;

  // Safe (Green)
  static const Color safeIcon = Color(0xFF16A34A);
  static const Color safeText = Color(0xFF15803D);
  static const Color safeBg = Color(0xFFDCFCE7);
  static const Color safeGreen = safeIcon;

  // Urgent (Red)
  static const Color urgentIcon = Color(0xFFDC2626);
  static const Color urgentText = Color(0xFFB91C1C);
  static const Color urgentBg = Color(0xFFFEE2E2);
  static const Color urgentRed = urgentIcon;

  // Pending (Slate/Gray)
  static const Color pending = Color(0xFF475569);
  static const Color pendingBg = Color(0xFFF1F5F9);
  static const Color pendingGray = pending;
}

/// Representasi satu temuan individual dari sebuah lokasi POS.
class MaintenanceTemuanItem {
  final PosMaintenanceStatus status;
  final MaintenanceLogEntry log;
  final MaintenanceTemuan temuan;
  final int phase;

  const MaintenanceTemuanItem({
    required this.status,
    required this.log,
    required this.temuan,
    required this.phase,
  });
}

/// Screen peta monitoring status maintenance cabang KC Manado.
class MaintenanceMapScreen extends StatefulWidget {
  final DraggableScrollableController? sheetController;
  final MapController? mapController;

  const MaintenanceMapScreen({
    super.key,
    this.sheetController,
    this.mapController,
  });

  @visibleForTesting
  static String shortName(PosLocation l) {
    var name = l.posName.trim();
    name = name.replaceFirst(
      RegExp(r'^mie gacoan\s+', caseSensitive: false),
      'Gacoan ',
    );
    name = name.replaceFirst(RegExp(r'\s+manado$', caseSensitive: false), '');
    if (name.toLowerCase() == 'mie gacoan') {
      name = 'Gacoan';
    }
    return name.trim();
  }

  static String formatTanggalShort(String tanggalStr) {
    try {
      final parts = tanggalStr.split('-');
      if (parts.length == 3) {
        final d = int.parse(parts[2]);
        final m = int.parse(parts[1]);
        const shortMonths = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'Mei',
          'Jun',
          'Jul',
          'Agu',
          'Sep',
          'Okt',
          'Nov',
          'Des',
        ];
        if (m >= 1 && m <= 12) {
          return '$d ${shortMonths[m - 1]}';
        }
      }
    } catch (_) {}
    return tanggalStr;
  }

  @visibleForTesting
  static String formatTanggalMeta(String tanggalStr) {
    try {
      final parts = tanggalStr.split('-');
      if (parts.length == 3) {
        final y = parts[0];
        final m = int.parse(parts[1]);
        final d = int.parse(parts[2]);
        const shortMonths = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'Mei',
          'Jun',
          'Jul',
          'Agu',
          'Sep',
          'Okt',
          'Nov',
          'Des',
        ];
        if (m >= 1 && m <= 12) {
          return '$d ${shortMonths[m - 1]} $y';
        }
      }
    } catch (_) {}
    return tanggalStr;
  }

  /// Ekstraksi daftar lokasi POS yang belum dikerjakan.
  @visibleForTesting
  static List<PosMaintenanceStatus> extractBelumList({
    required List<PosMaintenanceStatus> statuses,
    required bool isCurrentMonth,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final currentPhase = MaintenanceLogService.phaseForDate(currentTime);

    if (isCurrentMonth) {
      return statuses.where((s) => !s.isPhaseDone(currentPhase)).toList();
    } else {
      return statuses.where((s) => !s.isAllPhasesDone).toList();
    }
  }

  /// Ekstraksi dan pengurutan seluruh item temuan individual dari daftar POS.
  @visibleForTesting
  static List<MaintenanceTemuanItem> extractTemuanItems({
    required List<PosMaintenanceStatus> statuses,
    required bool isCurrentMonth,
    required DateTime selectedMonth,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final currentPhase = MaintenanceLogService.phaseForDate(currentTime);
    final items = <MaintenanceTemuanItem>[];

    for (final s in statuses) {
      if (isCurrentMonth) {
        final pLogs = s.logsForPhase(currentPhase);
        if (pLogs.isNotEmpty) {
          final top = pLogs.first;
          for (final t in top.temuan) {
            items.add(MaintenanceTemuanItem(
              status: s,
              log: top,
              temuan: t,
              phase: currentPhase,
            ));
          }
        }
      } else {
        for (int p = 1; p <= 4; p++) {
          final pLogs = s.logsForPhase(p);
          if (pLogs.isNotEmpty) {
            final top = pLogs.first;
            for (final t in top.temuan) {
              items.add(MaintenanceTemuanItem(
                status: s,
                log: top,
                temuan: t,
                phase: p,
              ));
            }
          }
        }
      }
    }

    items.sort(compareTemuanItems);
    return items;
  }

  /// Komparator pengurutan temuan: urgent dulu, lalu tidak_sesuai, lalu perlu_cek_manual, lalu tanggal terbaru.
  @visibleForTesting
  static int compareTemuanItems(
    MaintenanceTemuanItem a,
    MaintenanceTemuanItem b,
  ) {
    if (a.temuan.urgent != b.temuan.urgent) {
      return a.temuan.urgent ? -1 : 1;
    }

    final aScore = _statusSeverityScore(a.temuan.status);
    final bScore = _statusSeverityScore(b.temuan.status);
    if (aScore != bScore) {
      return aScore.compareTo(bScore);
    }

    final dateCmp = b.log.tanggal.compareTo(a.log.tanggal);
    if (dateCmp != 0) {
      return dateCmp;
    }

    return a.temuan.label.compareTo(b.temuan.label);
  }

  static int _statusSeverityScore(String status) {
    switch (status) {
      case 'tidak_sesuai':
        return 0;
      case 'perlu_cek_manual':
        return 1;
      default:
        return 2;
    }
  }

  @override
  State<MaintenanceMapScreen> createState() => _MaintenanceMapScreenState();
}

class _MarkerCluster {
  final List<PosMaintenanceStatus> members;
  final Offset anchorOffset;
  final int maxSeverity;
  final bool isSelected;

  _MarkerCluster({
    required this.members,
    required this.anchorOffset,
    required this.maxSeverity,
    required this.isSelected,
  });
}

class _MaintenanceMapScreenState extends State<MaintenanceMapScreen> {
  static const List<String> _namaBulanShort = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  late final MapController _mapController;
  bool _ownsMapController = false;

  late final MapOptions _mapOptions;
  bool _mapReady = false;

  double _lastRenderedZoom = 12.0;
  LatLng? _lastRenderedCenter;

  late DateTime _selectedMonth;
  bool _isLoading = true;
  bool _isOffline = false;
  DateTime? _lastFetchTime;

  List<PosMaintenanceStatus> _allStatuses = [];
  String _selectedWilayah = 'Semua';
  int? _selectedStatusRank;
  String? _selectedPosId;
  @visibleForTesting
  String? get selectedPosId => _selectedPosId;
  @visibleForTesting
  bool get mapReady => _mapReady;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    if (widget.mapController != null) {
      _mapController = widget.mapController!;
      _ownsMapController = false;
    } else {
      _mapController = MapController();
      _ownsMapController = true;
    }

    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);

    final manadoCoords = LocationService.getLocationsByBranch(AppBranch.manado)
        .where((l) => l.lat != 0 && l.lng != 0)
        .map((l) => LatLng(l.lat, l.lng))
        .toList();

    if (manadoCoords.length >= 2) {
      _mapOptions = MapOptions(
        initialCameraFit: CameraFit.coordinates(
          coordinates: manadoCoords,
          padding: const EdgeInsets.only(
            top: 40,
            left: 20,
            right: 20,
            bottom: 40,
          ),
          maxZoom: 15.0,
        ),
        backgroundColor: const Color(0xFFE5E7EB),
        onTap: (tapPosition, point) {
          if (_selectedPosId != null) {
            setState(() {
              _selectedPosId = null;
            });
          }
        },
        onPositionChanged: (camera, hasGesture) {
          final zoomDelta = (camera.zoom - _lastRenderedZoom).abs();
          double centerPixelDelta = 0.0;
          if (_lastRenderedCenter != null) {
            final curOffset = camera.latLngToScreenOffset(camera.center);
            final lastOffset = camera.latLngToScreenOffset(_lastRenderedCenter!);
            centerPixelDelta = (curOffset - lastOffset).distance;
          } else {
            centerPixelDelta = 999.0;
          }
          if (zoomDelta >= 0.05 || centerPixelDelta >= 8.0) {
            _lastRenderedZoom = camera.zoom;
            _lastRenderedCenter = camera.center;
            if (mounted) {
              setState(() {});
            }
          }
        },
        onMapReady: () {
          _mapReady = true;
          _fitMapToCurrentFilter();
        },
      );
    } else {
      _mapOptions = MapOptions(
        initialCenter: const LatLng(1.4748, 124.8428),
        initialZoom: 12.0,
        backgroundColor: const Color(0xFFE5E7EB),
        onTap: (tapPosition, point) {
          if (_selectedPosId != null) {
            setState(() {
              _selectedPosId = null;
            });
          }
        },
        onPositionChanged: (camera, hasGesture) {
          final zoomDelta = (camera.zoom - _lastRenderedZoom).abs();
          double centerPixelDelta = 0.0;
          if (_lastRenderedCenter != null) {
            final curOffset = camera.latLngToScreenOffset(camera.center);
            final lastOffset = camera.latLngToScreenOffset(_lastRenderedCenter!);
            centerPixelDelta = (curOffset - lastOffset).distance;
          } else {
            centerPixelDelta = 999.0;
          }
          if (zoomDelta >= 0.05 || centerPixelDelta >= 8.0) {
            _lastRenderedZoom = camera.zoom;
            _lastRenderedCenter = camera.center;
            if (mounted) {
              setState(() {});
            }
          }
        },
        onMapReady: () {
          _mapReady = true;
          _fitMapToCurrentFilter();
        },
      );
    }

    _initData();
    _setupRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    if (_ownsMapController) {
      _mapController.dispose();
    }
    super.dispose();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  bool get _canGoNextMonth {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    return _selectedMonth.isBefore(currentMonth);
  }

  void _setupRefreshTimer() {
    _refreshTimer?.cancel();
    if (_isCurrentMonth) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted && _isCurrentMonth) {
          _silentRefresh();
        }
      });
    }
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    await MaintenanceLogService.syncLocal();
    await _loadMonthData();
  }

  Future<void> _loadMonthData() async {
    setState(() => _isLoading = true);

    final locations = LocationService.getLocationsByBranch(AppBranch.manado);
    final result = await MaintenanceLogService.fetchMonth(_selectedMonth);
    final statuses = MaintenanceLogService.buildStatuses(locations, result.logs);

    if (!mounted) return;

    setState(() {
      _allStatuses = statuses;
      _isOffline = result.offline;
      if (!result.offline) {
        _lastFetchTime = DateTime.now();
      }
      _isLoading = false;
    });

    if (_mapReady) {
      _fitMapToCurrentFilter();
    }
  }

  Future<void> _silentRefresh() async {
    final locations = LocationService.getLocationsByBranch(AppBranch.manado);
    final result = await MaintenanceLogService.fetchMonth(_selectedMonth);
    final statuses = MaintenanceLogService.buildStatuses(locations, result.logs);

    if (!mounted) return;

    setState(() {
      _allStatuses = statuses;
      _isOffline = result.offline;
      if (!result.offline) {
        _lastFetchTime = DateTime.now();
      }
    });
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
    _setupRefreshTimer();
    _loadMonthData();
  }

  void _nextMonth() {
    if (!_canGoNextMonth) return;
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
    _setupRefreshTimer();
    _loadMonthData();
  }

  List<PosMaintenanceStatus> get _wilayahStatuses {
    if (_selectedWilayah == 'Semua') return _allStatuses;
    return _allStatuses.where((s) => s.wilayah == _selectedWilayah).toList();
  }

  List<PosMaintenanceStatus> get _filteredStatuses {
    final base = _wilayahStatuses;
    if (_selectedStatusRank == null) return base;
    return base.where((s) => _statusRank(s) == _selectedStatusRank).toList();
  }

  String _statusRankLabel(int rank) {
    switch (rank) {
      case 0:
        return 'Belum';
      case 1:
        return 'Ada temuan';
      case 2:
        return 'Aman';
      default:
        return '';
    }
  }

  List<String> get _availableWilayahList {
    final manadoLocations =
        LocationService.getLocationsByBranch(AppBranch.manado);
    final present =
        manadoLocations.map(MaintenanceLogService.wilayahOf).toSet();
    return [
      'Semua',
      ...MaintenanceLogService.wilayahList.where(present.contains)
    ];
  }

  int _statusRank(PosMaintenanceStatus s) {
    if (_isCurrentMonth) {
      final currentPhase = MaintenanceLogService.phaseForDate(DateTime.now());
      if (!s.isPhaseDone(currentPhase)) return 0;
      if (s.hasPhaseTemuan(currentPhase)) return 1;
      return 2;
    } else {
      if (!s.isAllPhasesDone) return 0;
      final anyTemuan = s.hasPhaseTemuan(1) ||
          s.hasPhaseTemuan(2) ||
          s.hasPhaseTemuan(3) ||
          s.hasPhaseTemuan(4);
      if (anyTemuan) return 1;
      return 2;
    }
  }

  Color _statusColor(PosMaintenanceStatus s) {
    final rank = _statusRank(s);
    if (rank == 0) return MaintenanceMapPalette.pendingGray;
    if (rank == 1) return MaintenanceMapPalette.findingOrange;
    return MaintenanceMapPalette.safeGreen;
  }

  IconData _statusIcon(PosMaintenanceStatus s) {
    final rank = _statusRank(s);
    if (rank == 0) return Icons.schedule_rounded;
    if (rank == 1) return Icons.warning_rounded;
    return Icons.check_circle_rounded;
  }

  int _markerSeverity(PosMaintenanceStatus s, Set<String> urgentPosIds) {
    if (urgentPosIds.contains(s.location.posId)) return 3;
    final rank = _statusRank(s);
    if (rank == 1) return 2;
    if (rank == 0) return 1;
    return 0;
  }

  String _statusLabel(PosMaintenanceStatus s) {
    final rank = _statusRank(s);
    if (rank == 0) return 'Belum';
    if (rank == 1) {
      if (_isCurrentMonth) {
        final p = MaintenanceLogService.phaseForDate(DateTime.now());
        final tCount = s
            .logsForPhase(p)
            .fold<int>(0, (sum, l) => sum + l.temuan.length);
        return tCount > 0 ? '$tCount Temuan' : 'Temuan';
      } else {
        final tCount = s.logs.fold<int>(0, (sum, l) => sum + l.temuan.length);
        return tCount > 0 ? '$tCount Temuan' : 'Temuan';
      }
    }
    return 'Aman';
  }

  void _fitMapToCurrentFilter() {
    if (!_mapReady || !mounted) return;

    final coords = _filteredStatuses
        .where((s) => s.location.lat != 0 && s.location.lng != 0)
        .map((s) => LatLng(s.location.lat, s.location.lng))
        .toList();

    if (coords.isEmpty) return;

    if (coords.length == 1) {
      _mapController.move(coords.first, 14.0);
    } else {
      try {
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: coords,
            padding: const EdgeInsets.only(
              top: 40,
              left: 40,
              right: 40,
              bottom: 80,
            ),
            maxZoom: 15.0,
          ),
        );
      } catch (e) {
        debugPrint('fitCamera error: $e');
        _mapController.move(coords.first, 12.0);
      }
    }
  }

  String _formatJamMenit(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _phaseDateRange(int phase, int year, int month) {
    switch (phase) {
      case 1:
        return '1-7';
      case 2:
        return '8-14';
      case 3:
        return '15-21';
      case 4:
      default:
        final lastDay = DateTime(year, month + 1, 0).day;
        return '22-$lastDay';
    }
  }

  String _formatBulanTahunShort(DateTime dt) {
    return '${_namaBulanShort[dt.month - 1]} ${dt.year}';
  }

  void _centerOnLocation(PosMaintenanceStatus s) {
    if (s.location.lat != 0 && s.location.lng != 0) {
      _mapController.move(LatLng(s.location.lat, s.location.lng), 15.0);
    }
  }

  void _onMarkerTap(PosMaintenanceStatus s) {
    setState(() {
      _selectedPosId = s.location.posId;
    });
    _showLocationSheet(s);
  }

  void _openDetail(PosMaintenanceStatus s) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaintenanceLocationDetailScreen(
          status: s,
          month: _selectedMonth,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MaintenanceMapPalette.bg,
      appBar: AppBar(
        backgroundColor: MaintenanceMapPalette.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: MaintenanceMapPalette.textPrimary,
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Map Maintenance',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: MaintenanceMapPalette.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: MaintenanceMapPalette.textPrimary,
            ),
            tooltip: 'Perbarui data',
            onPressed: _loadMonthData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Loading indicator
          if (_isLoading)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                MaintenanceMapPalette.primary,
              ),
            ),

          // Offline banner
          if (_isOffline) _buildOfflineBanner(),

          // Top filter row: Month switcher + Wilayah chips (44dp)
          _buildTopFilterBar(),

          // Phase Strip (Flat, <= 64dp, 1px bottom divider)
          _buildPhaseStrip(),

          // Body: Map + Floating Controls
          Expanded(
            child: Stack(
              children: [
                // FlutterMap always mounted (Light OSM)
                FlutterMap(
                  mapController: _mapController,
                  options: _mapOptions,
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      retinaMode: RetinaMode.isHighDensity(context),
                      userAgentPackageName:
                          'com.bssparking.timemark.bssparking_timemark',
                    ),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                            'OpenStreetMap contributors'),
                      ],
                    ),
                    MarkerLayer(
                      markers: _buildMarkers(),
                    ),
                  ],
                ),

                if (_filteredStatuses.isEmpty && _selectedStatusRank != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: MaintenanceMapPalette.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: MaintenanceMapPalette.divider,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Tidak ada lokasi ${_statusRankLabel(_selectedStatusRank!)} di $_selectedWilayah',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: MaintenanceMapPalette.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedStatusRank = null;
                                });
                                _fitMapToCurrentFilter();
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                minimumSize: const Size(44, 36),
                              ),
                              child: const Text(
                                'Tampilkan semua',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: MaintenanceMapPalette.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Floating Map Controls Positioned bottom-right
                Positioned(
                  right: 12,
                  bottom: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFloatingControlButton(
                        icon: Icons.center_focus_strong,
                        tooltip: 'Pusatkan Peta',
                        onTap: _fitMapToCurrentFilter,
                      ),
                      const SizedBox(height: 8),
                      _buildZoomControlsPill(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: MaintenanceMapPalette.findingBg,
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 16,
            color: MaintenanceMapPalette.findingText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _lastFetchTime != null
                  ? 'Offline, menampilkan data lokal · Update ${_formatJamMenit(_lastFetchTime!)}'
                  : 'Offline, menampilkan data lokal',
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: MaintenanceMapPalette.findingText,
              ),
            ),
          ),
          TextButton(
            onPressed: _loadMonthData,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(44, 32),
            ),
            child: const Text(
              'Coba lagi',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: MaintenanceMapPalette.findingText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopFilterBar() {
    final list = _availableWilayahList;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: MaintenanceMapPalette.surface,
        border: Border(
          bottom: BorderSide(
            color: MaintenanceMapPalette.divider,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildCompactMonthSwitcher(),
          const SizedBox(width: 6),
          const SizedBox(
            height: 20,
            child: VerticalDivider(
              width: 1,
              color: MaintenanceMapPalette.divider,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              label: 'Filter wilayah, $_selectedWilayah',
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedWilayah,
                  icon: const Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: MaintenanceMapPalette.textSecondary,
                  ),
                  dropdownColor: MaintenanceMapPalette.surface,
                  borderRadius: BorderRadius.circular(12),
                  menuMaxHeight: 360,
                  items: list.map((w) {
                    final count = w == 'Semua'
                        ? _allStatuses.length
                        : _allStatuses.where((s) => s.wilayah == w).length;
                    return DropdownMenuItem<String>(
                      value: w,
                      child: Text(
                        '$w ($count)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          color: MaintenanceMapPalette.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                  selectedItemBuilder: (context) {
                    return list.map((w) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: MaintenanceMapPalette.surfaceRaised,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                size: 16,
                                color: MaintenanceMapPalette.primary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  w,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: MaintenanceMapPalette.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList();
                  },
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _selectedWilayah = v;
                    });
                    _fitMapToCurrentFilter();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMonthSwitcher() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          iconSize: 18,
          color: MaintenanceMapPalette.textPrimary,
          tooltip: 'Bulan sebelumnya',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 44),
          onPressed: _previousMonth,
        ),
        const Icon(
          Icons.calendar_today_rounded,
          size: 14,
          color: MaintenanceMapPalette.primary,
        ),
        const SizedBox(width: 4),
        Text(
          _formatBulanTahunShort(_selectedMonth),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: MaintenanceMapPalette.textPrimary,
          ),
        ),
        Semantics(
          enabled: _canGoNextMonth,
          label: 'Bulan berikutnya',
          child: IconButton(
            icon: const Icon(Icons.chevron_right),
            iconSize: 18,
            color: _canGoNextMonth
                ? MaintenanceMapPalette.textPrimary
                : MaintenanceMapPalette.textSecondary.withValues(alpha: 0.38),
            tooltip: _canGoNextMonth ? 'Bulan berikutnya' : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 44),
            onPressed: _canGoNextMonth ? _nextMonth : null,
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseStrip() {
    final now = DateTime.now();
    final currentPhase = MaintenanceLogService.phaseForDate(now);
    final isCur = _isCurrentMonth;

    final filtered = _wilayahStatuses;
    final totalFiltered = filtered.length;

    int belumCount = 0;
    int temuanCount = 0;
    int amanCount = 0;

    for (final s in filtered) {
      final rank = _statusRank(s);
      if (rank == 0) {
        belumCount++;
      } else if (rank == 1) {
        temuanCount++;
      } else {
        amanCount++;
      }
    }

    final posDone = totalFiltered - belumCount;
    final progress = totalFiltered == 0 ? 0.0 : (posDone / totalFiltered);

    final title = isCur
        ? 'Fase $currentPhase · Tgl ${_phaseDateRange(currentPhase, _selectedMonth.year, _selectedMonth.month)} · ${MaintenanceLogService.phaseNames[currentPhase] ?? ''}'
        : 'Rekap 4 Fase · Seluruh fase bulan ini';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: MaintenanceMapPalette.surface,
        border: Border(
          bottom: BorderSide(
            color: MaintenanceMapPalette.divider,
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Title 13/600 + Pos done count 12 secondary
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MaintenanceMapPalette.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$posDone/$totalFiltered lokasi',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: MaintenanceMapPalette.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Row 2: ● Belum ● Ada temuan ● Aman + 4dp Progress bar
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildPhaseStripStatChip(
                      rank: 0,
                      color: MaintenanceMapPalette.pending,
                      label: '$belumCount Belum',
                    ),
                    _buildPhaseStripStatChip(
                      rank: 1,
                      color: MaintenanceMapPalette.findingIcon,
                      label: '$temuanCount Ada temuan',
                    ),
                    _buildPhaseStripStatChip(
                      rank: 2,
                      color: MaintenanceMapPalette.safeIcon,
                      label: '$amanCount Aman',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 60,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: MaintenanceMapPalette.surfaceRaised,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      MaintenanceMapPalette.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseStripStatChip({
    required int rank,
    required Color color,
    required String label,
  }) {
    final isSelected = _selectedStatusRank == rank;
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Tampilkan lokasi $label saja',
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedStatusRank = _selectedStatusRank == rank ? null : rank;
          });
          _fitMapToCurrentFilter();
        },
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              constraints: const BoxConstraints(minHeight: 32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected ? color : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? MaintenanceMapPalette.textPrimary
                          : MaintenanceMapPalette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Marker> _buildMarkers() {
    final filtered = _filteredStatuses;
    final visibleStatuses = filtered
        .where((s) => s.location.lat != 0 && s.location.lng != 0)
        .toList();

    final temuanItems = MaintenanceMapScreen.extractTemuanItems(
      statuses: filtered,
      isCurrentMonth: _isCurrentMonth,
      selectedMonth: _selectedMonth,
    );
    final urgentPosIds = temuanItems
        .where((t) => t.temuan.urgent)
        .map((t) => t.status.location.posId)
        .toSet();

    final temuanByPos = <String, List<MaintenanceTemuanItem>>{};
    for (final item in temuanItems) {
      temuanByPos.putIfAbsent(item.status.location.posId, () => []).add(item);
    }

    if (!_mapReady) {
      final markers = <Marker>[];
      PosMaintenanceStatus? selectedStatus;
      final normalStatuses = <PosMaintenanceStatus>[];

      for (final s in visibleStatuses) {
        if (_selectedPosId != null && s.location.posId == _selectedPosId) {
          selectedStatus = s;
        } else {
          normalStatuses.add(s);
        }
      }

      normalStatuses.sort((a, b) =>
          _markerSeverity(a, urgentPosIds).compareTo(_markerSeverity(b, urgentPosIds)));

      for (final s in normalStatuses) {
        markers.add(_buildSingleMarker(s, urgentPosIds, temuanByPos));
      }
      if (selectedStatus != null) {
        markers.add(_buildSingleMarker(selectedStatus, urgentPosIds, temuanByPos, isSelected: true));
      }
      return markers;
    }

    // Camera ready: Screen-space greedy clustering
    final sortedStatuses = List<PosMaintenanceStatus>.from(visibleStatuses);
    // Sort severity DESC: 3 (urgent) > 2 (temuan) > 1 (belum) > 0 (aman)
    sortedStatuses.sort((a, b) =>
        _markerSeverity(b, urgentPosIds).compareTo(_markerSeverity(a, urgentPosIds)));

    PosMaintenanceStatus? selectedStatus;
    if (_selectedPosId != null) {
      final idx = sortedStatuses.indexWhere((s) => s.location.posId == _selectedPosId);
      if (idx != -1) {
        selectedStatus = sortedStatuses.removeAt(idx);
      }
    }

    final List<_MarkerCluster> clusters = [];
    for (final s in sortedStatuses) {
      final offset = _mapController.camera
          .latLngToScreenOffset(LatLng(s.location.lat, s.location.lng));
      bool joined = false;
      for (final c in clusters) {
        if ((offset - c.anchorOffset).distance <= 44.0) {
          c.members.add(s);
          joined = true;
          break;
        }
      }
      if (!joined) {
        clusters.add(_MarkerCluster(
          members: [s],
          anchorOffset: offset,
          maxSeverity: _markerSeverity(s, urgentPosIds),
          isSelected: false,
        ));
      }
    }

    // Paint order: emit non-urgent first, urgent last (severity ASC)
    clusters.sort((a, b) => a.maxSeverity.compareTo(b.maxSeverity));

    final markers = <Marker>[];
    for (final c in clusters) {
      if (c.members.length == 1) {
        markers.add(_buildSingleMarker(c.members.first, urgentPosIds, temuanByPos));
      } else {
        markers.add(_buildClusterMarker(c, urgentPosIds, temuanByPos));
      }
    }

    if (selectedStatus != null) {
      markers.add(_buildSingleMarker(selectedStatus, urgentPosIds, temuanByPos, isSelected: true));
    }

    return markers;
  }

  Widget _buildNotificationBadge({
    required int count,
    required bool isUrgent,
  }) {
    if (count <= 0) return const SizedBox.shrink();
    final countStr = count > 9 ? '9+' : '$count';
    return ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isUrgent
              ? const Color(0xFFDC2626)
              : const Color(0xFFD97706),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          countStr,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Marker _buildSingleMarker(
    PosMaintenanceStatus s,
    Set<String> urgentPosIds,
    Map<String, List<MaintenanceTemuanItem>> temuanByPos, {
    bool isSelected = false,
  }) {
    final selected = isSelected || _selectedPosId == s.location.posId;
    final isUrgent = urgentPosIds.contains(s.location.posId);
    final items = temuanByPos[s.location.posId] ?? const [];
    final temuanCount = items.length;

    Color borderColor;
    IconData icon;
    if (isUrgent) {
      borderColor = MaintenanceMapPalette.urgentRed;
      icon = Icons.error_rounded;
    } else {
      borderColor = _statusColor(s);
      icon = _statusIcon(s);
    }

    String semanticLabel;
    if (_statusRank(s) == 0) {
      semanticLabel = '${s.location.locationTag}, belum dikerjakan';
    } else if (temuanCount > 0) {
      if (isUrgent) {
        semanticLabel = '${s.location.locationTag}, $temuanCount temuan, ada urgent';
      } else {
        semanticLabel = '${s.location.locationTag}, $temuanCount temuan';
      }
    } else {
      semanticLabel = '${s.location.locationTag}, 0 temuan';
    }

    return Marker(
      point: LatLng(s.location.lat, s.location.lng),
      width: 100,
      height: 48,
      alignment: Alignment.center,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: GestureDetector(
          onTap: () => _onMarkerTap(s),
          child: Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            alignment: Alignment.center,
            color: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: MaintenanceMapPalette.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected ? MaintenanceMapPalette.primary : borderColor,
                      width: selected ? 2.0 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x14000000),
                        blurRadius: selected ? 6 : 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: borderColor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          s.location.locationTag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: MaintenanceMapPalette.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (temuanCount > 0)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: _buildNotificationBadge(
                      count: temuanCount,
                      isUrgent: isUrgent,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Marker _buildClusterMarker(
    _MarkerCluster cluster,
    Set<String> urgentPosIds,
    Map<String, List<MaintenanceTemuanItem>> temuanByPos,
  ) {
    final n = cluster.members.length;
    final u = cluster.members
        .where((m) => urgentPosIds.contains(m.location.posId))
        .length;
    final hasUrgent = u > 0;
    final sumTemuan = cluster.members.fold<int>(
      0,
      (sum, m) => sum + (temuanByPos[m.location.posId]?.length ?? 0),
    );

    Color clusterBorderColor;
    if (cluster.maxSeverity == 3) {
      clusterBorderColor = MaintenanceMapPalette.urgentRed;
    } else if (cluster.maxSeverity == 2) {
      clusterBorderColor = MaintenanceMapPalette.findingIcon;
    } else if (cluster.maxSeverity == 1) {
      clusterBorderColor = MaintenanceMapPalette.pending;
    } else {
      clusterBorderColor = MaintenanceMapPalette.safeGreen;
    }

    final semanticLabel = hasUrgent
        ? '$n lokasi, $u urgent, $sumTemuan temuan'
        : '$n lokasi, $sumTemuan temuan';

    return Marker(
      point: LatLng(
        cluster.members.first.location.lat,
        cluster.members.first.location.lng,
      ),
      width: 48,
      height: 48,
      alignment: Alignment.center,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: GestureDetector(
          onTap: () {
            final allSameCoords = cluster.members.every((m) =>
                (m.location.lat - cluster.members.first.location.lat).abs() <
                    0.0001 &&
                (m.location.lng - cluster.members.first.location.lng).abs() <
                    0.0001);

            if (_mapController.camera.zoom < 17 && !allSameCoords) {
              _mapController.fitCamera(
                CameraFit.coordinates(
                  coordinates: cluster.members
                      .map((m) => LatLng(m.location.lat, m.location.lng))
                      .toList(),
                  padding: const EdgeInsets.all(40),
                ),
              );
            } else {
              _showClusterMembersSheet(cluster.members);
            }
          },
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            color: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: MaintenanceMapPalette.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: clusterBorderColor, width: 2.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$n',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: MaintenanceMapPalette.textPrimary,
                    ),
                  ),
                ),
                if (sumTemuan > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: _buildNotificationBadge(
                      count: sumTemuan,
                      isUrgent: hasUrgent,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showClusterMembersSheet(List<PosMaintenanceStatus> members) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MaintenanceMapPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 8),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MaintenanceMapPalette.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    '${members.length} Lokasi Terpilih',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: MaintenanceMapPalette.textPrimary,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: members.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      thickness: 0.5,
                      color: MaintenanceMapPalette.divider,
                    ),
                    itemBuilder: (ctx, i) {
                      final m = members[i];
                      return ListTile(
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _statusColor(m).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            _statusIcon(m),
                            size: 16,
                            color: _statusColor(m),
                          ),
                        ),
                        title: Text(
                          '${m.location.locationTag} · ${MaintenanceMapScreen.shortName(m.location)}',
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: MaintenanceMapPalette.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          _statusLabel(m),
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            color: MaintenanceMapPalette.textSecondary,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: MaintenanceMapPalette.textSecondary,
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _centerOnLocation(m);
                          _openDetail(m);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildZoomControlsPill() {
    return Container(
      width: 40,
      height: 88,
      decoration: BoxDecoration(
        color: MaintenanceMapPalette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MaintenanceMapPalette.divider,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: Tooltip(
                message: 'Perbesar',
                child: InkWell(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  onTap: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  },
                  child: const Center(
                    child: Icon(
                      Icons.add,
                      size: 18,
                      color: MaintenanceMapPalette.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Divider(
            height: 1,
            thickness: 0.8,
            color: MaintenanceMapPalette.divider,
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: Tooltip(
                message: 'Perkecil',
                child: InkWell(
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(20)),
                  onTap: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  },
                  child: const Center(
                    child: Icon(
                      Icons.remove,
                      size: 18,
                      color: MaintenanceMapPalette.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: MaintenanceMapPalette.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: MaintenanceMapPalette.divider,
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 18,
                color: MaintenanceMapPalette.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLocationSheet(PosMaintenanceStatus s) {
    final temuanItems = MaintenanceMapScreen.extractTemuanItems(
      statuses: [s],
      isCurrentMonth: _isCurrentMonth,
      selectedMonth: _selectedMonth,
    );
    temuanItems.sort((a, b) {
      if (a.temuan.urgent != b.temuan.urgent) {
        return a.temuan.urgent ? -1 : 1;
      }
      return b.log.tanggal.compareTo(a.log.tanggal);
    });

    final loc = s.location;
    final shortName = MaintenanceMapScreen.shortName(loc);
    final headerTitle = '${loc.locationTag} · $shortName';
    final countText = '${temuanItems.length} temuan';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: MaintenanceMapPalette.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 10,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 6),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: MaintenanceMapPalette.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header row: '<TAG> · <Lokasi name>' (1 line, ellipsis) + trailing '<n> temuan' + close IconButton(tooltip 'Tutup')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            headerTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: MaintenanceMapPalette.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          countText,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: MaintenanceMapPalette.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: 'Tutup',
                          color: MaintenanceMapPalette.textSecondary,
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: MaintenanceMapPalette.divider,
                  ),

                  // Body
                  Expanded(
                    child: temuanItems.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 32,
                              ),
                              child: Text(
                                _statusRank(s) == 0
                                    ? 'Belum dikerjakan bulan ini'
                                    : 'Aman, tidak ada temuan',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: MaintenanceMapPalette.textSecondary,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: temuanItems.length,
                            itemBuilder: (context, index) {
                              final item = temuanItems[index];
                              final showDivider =
                                  index < temuanItems.length - 1;
                              return MaintenanceTemuanRow(
                                item: item,
                                isSelected: false,
                                showDivider: showDivider,
                                onTap: () {
                                  _openDetail(s);
                                },
                                onOpenDetail: () {
                                  _openDetail(s);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _selectedPosId = null;
        });
      }
    });
  }
}

/// Widget baris untuk daftar lokasi belum dikerjakan.
class MaintenanceBelumRow extends StatelessWidget {
  final PosMaintenanceStatus status;
  final bool isCurrentMonth;
  final DateTime selectedMonth;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onOpenDetail;

  const MaintenanceBelumRow({
    super.key,
    required this.status,
    required this.isCurrentMonth,
    required this.selectedMonth,
    this.isSelected = false,
    this.onTap,
    this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final currentPhase = MaintenanceLogService.phaseForDate(DateTime.now());
    final shortName = MaintenanceMapScreen.shortName(status.location);

    final address = status.location.fullAddress.trim();
    final addressLine = address.isNotEmpty
        ? '${status.wilayah} · $address'
        : status.wilayah;

    Widget trailingBadge;
    if (isCurrentMonth) {
      trailingBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: MaintenanceMapPalette.pendingBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Fase $currentPhase',
          maxLines: 1,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MaintenanceMapPalette.pending,
          ),
        ),
      );
    } else {
      final missingPhases = [1, 2, 3, 4]
          .where((p) => !status.isPhaseDone(p))
          .toList();
      final missingLabel = missingPhases.isEmpty
          ? 'Lengkap'
          : 'Belum: Fase ${missingPhases.join(', ')}';

      trailingBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: MaintenanceMapPalette.pendingBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          missingLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MaintenanceMapPalette.pending,
          ),
        ),
      );
    }

    return Material(
      color: isSelected
          ? MaintenanceMapPalette.surfaceRaised
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: EdgeInsets.fromLTRB(isSelected ? 9 : 12, 8, 8, 8),
          decoration: BoxDecoration(
            border: Border(
              left: isSelected
                  ? const BorderSide(
                      color: MaintenanceMapPalette.pending,
                      width: 3,
                    )
                  : BorderSide.none,
              bottom: const BorderSide(
                color: MaintenanceMapPalette.divider,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // 32dp circle icon
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: MaintenanceMapPalette.pendingBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: MaintenanceMapPalette.pending,
                ),
              ),
              const SizedBox(width: 10),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            shortName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: MaintenanceMapPalette.textPrimary,
                            ),
                          ),
                        ),
                        if (status.location.locationTag.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: MaintenanceMapPalette.surfaceRaised,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: MaintenanceMapPalette.divider,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              status.location.locationTag,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: MaintenanceMapPalette.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      addressLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: MaintenanceMapPalette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              trailingBadge,
              const SizedBox(width: 4),
              // Trailing chevron button for opening detail
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onOpenDetail,
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: MaintenanceMapPalette.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget baris untuk daftar item temuan individual.
class MaintenanceTemuanRow extends StatelessWidget {
  final MaintenanceTemuanItem item;
  final bool isSelected;
  final bool showDivider;
  final VoidCallback? onTap;
  final VoidCallback? onOpenDetail;

  const MaintenanceTemuanRow({
    super.key,
    required this.item,
    this.isSelected = false,
    this.showDivider = true,
    this.onTap,
    this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final t = item.temuan;
    final log = item.log;

    IconData severityIcon;
    Color severityIconColor;
    Color iconCircleBg;
    String severityStatusText;
    Color barColor;

    if (t.urgent) {
      severityIcon = Icons.error_rounded;
      severityIconColor = MaintenanceMapPalette.urgentIcon;
      iconCircleBg = MaintenanceMapPalette.urgentBg;
      severityStatusText = 'Urgent';
      barColor = MaintenanceMapPalette.urgentRed;
    } else if (t.status == 'tidak_sesuai') {
      severityIcon = Icons.warning_amber_rounded;
      severityIconColor = MaintenanceMapPalette.findingIcon;
      iconCircleBg = MaintenanceMapPalette.findingBg;
      severityStatusText = 'Tidak sesuai';
      barColor = MaintenanceMapPalette.findingIcon;
    } else {
      severityIcon = Icons.help_outline_rounded;
      severityIconColor = MaintenanceMapPalette.pending;
      iconCircleBg = MaintenanceMapPalette.pendingBg;
      severityStatusText = 'Perlu cek';
      barColor = MaintenanceMapPalette.pending;
    }

    final dateStr = MaintenanceMapScreen.formatTanggalShort(log.tanggal);
    final techFirstWord = log.teknisiNama.trim().isNotEmpty
        ? log.teknisiNama.trim().split(' ').first
        : '';
    final line3 =
        dateStr + (techFirstWord.isNotEmpty ? ' · $techFirstWord' : '');

    final line1 = t.alasan.trim().isNotEmpty ? t.alasan.trim() : t.label;
    final hasLine2 = t.alasan.trim().isNotEmpty;
    final line2 = t.label;

    final semLabel =
        '$severityStatusText, $line1, ${hasLine2 ? '$line2, ' : ''}$line3';

    return Material(
      color: isSelected
          ? MaintenanceMapPalette.surfaceRaised
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: semLabel,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: EdgeInsets.fromLTRB(isSelected ? 9 : 12, 8, 8, 8),
            decoration: BoxDecoration(
              border: Border(
                left: isSelected
                    ? BorderSide(color: barColor, width: 3)
                    : BorderSide.none,
                bottom: showDivider
                    ? const BorderSide(
                        color: MaintenanceMapPalette.divider,
                        width: 0.5,
                      )
                    : BorderSide.none,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 24dp circle icon (14dp icon)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: iconCircleBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(severityIcon, size: 14, color: severityIconColor),
                ),
                const SizedBox(width: 10),
                // Column body
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Line 1: alasan (fallback label), max 2 lines, textPrimary 14/500
                      Text(
                        line1,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: MaintenanceMapPalette.textPrimary,
                        ),
                      ),
                      if (hasLine2) ...[
                        const SizedBox(height: 2),
                        Text(
                          line2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: MaintenanceMapPalette.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        line3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: MaintenanceMapPalette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (t.urgent) ...[
                  const SizedBox(width: 6),
                  Container(
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: MaintenanceMapPalette.urgentBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Urgent',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: MaintenanceMapPalette.urgentText,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                // Trailing chevron button for opening detail
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onOpenDetail,
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: MaintenanceMapPalette.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget baris lokasi pada daftar Maintenance Map.
@visibleForTesting
class MaintenanceLocationRow extends StatelessWidget {
  final PosMaintenanceStatus status;
  final bool isCurrentMonth;
  final DateTime selectedMonth;
  final VoidCallback? onTap;

  const MaintenanceLocationRow({
    super.key,
    required this.status,
    required this.isCurrentMonth,
    required this.selectedMonth,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currentPhase = MaintenanceLogService.phaseForDate(DateTime.now());
    final relevantLogs = isCurrentMonth
        ? status.logsForPhase(currentPhase)
        : status.logs;
    final isDone = isCurrentMonth
        ? status.isPhaseDone(currentPhase)
        : status.isAllPhasesDone;

    final latestLog = relevantLogs.isNotEmpty ? relevantLogs.first : null;
    final temuanCount = latestLog != null ? latestLog.temuan.length : 0;

    Color statusColor;
    Color statusBg;
    IconData statusIcon;
    String trailingLabel;

    if (!isDone) {
      statusColor = MaintenanceMapPalette.pending;
      statusBg = MaintenanceMapPalette.pendingBg;
      statusIcon = Icons.schedule_rounded;
      trailingLabel = 'Belum';
    } else if (temuanCount > 0) {
      statusColor = MaintenanceMapPalette.findingText;
      statusBg = MaintenanceMapPalette.findingBg;
      statusIcon = Icons.warning_rounded;
      trailingLabel = '$temuanCount Temuan';
    } else {
      statusColor = MaintenanceMapPalette.safeText;
      statusBg = MaintenanceMapPalette.safeBg;
      statusIcon = Icons.check_circle_rounded;
      trailingLabel = 'Aman';
    }

    final shortName = MaintenanceMapScreen.shortName(status.location);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: MaintenanceMapPalette.divider,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // 32dp circle icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: statusBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(statusIcon, color: statusColor, size: 16),
              ),
              const SizedBox(width: 10),

              // Title, Subtitle, Meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Line 1: shortName + tag pill
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            shortName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: MaintenanceMapPalette.textPrimary,
                            ),
                          ),
                        ),
                        if (status.location.locationTag.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: MaintenanceMapPalette.surfaceRaised,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: MaintenanceMapPalette.divider,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              status.location.locationTag,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: MaintenanceMapPalette.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),

                    // Line 2: wilayah · fullAddress
                    Text(
                      '${status.wilayah} · ${status.location.fullAddress}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: MaintenanceMapPalette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Meta: calendar + date + 'oleh teknisi'
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: MaintenanceMapPalette.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            latestLog != null
                                ? '${MaintenanceMapScreen.formatTanggalMeta(latestLog.tanggal)} oleh ${latestLog.teknisiNama}'
                                : 'Belum ada laporan bulan ini',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: MaintenanceMapPalette.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Trailing: Badge + 4 dots + Chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          trailingLabel,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: MaintenanceMapPalette.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(4, (i) {
                      final p = i + 1;
                      final done = status.isPhaseDone(p);
                      final temuan = status.hasPhaseTemuan(p);
                      final dotColor = !done
                          ? MaintenanceMapPalette.pending
                          : (temuan
                              ? MaintenanceMapPalette.findingIcon
                              : MaintenanceMapPalette.safeIcon);
                      return Semantics(
                        label:
                            'Fase $p: ${!done ? 'Belum' : (temuan ? 'Temuan' : 'Aman')}',
                        child: Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
