import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/tiket_colors.dart';
import '../../../core/widgets/tiket/tiket.dart';
import '../../../data/services/branch_service.dart';
import '../../../data/services/error_ticket_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/maintenance_log_service.dart';
import 'maintenance_location_detail_screen.dart';

/// Palet warna UI operasional (Light & Dark aware via Theme colorScheme) untuk Maintenance Map & Detail.
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

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bgOf(BuildContext context) =>
      _isDark(context) ? Theme.of(context).scaffoldBackgroundColor : bg;

  static Color surfaceOf(BuildContext context) =>
      _isDark(context) ? Theme.of(context).colorScheme.surface : surface;

  static Color surfaceRaisedOf(BuildContext context) =>
      _isDark(context) ? const Color(0xFF334155) : surfaceRaised;

  static Color dividerOf(BuildContext context) =>
      _isDark(context) ? const Color(0xFF334155) : divider;

  static Color textPrimaryOf(BuildContext context) =>
      _isDark(context) ? Theme.of(context).colorScheme.onSurface : textPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      _isDark(context) ? const Color(0xFF94A3B8) : textSecondary;

  static Color primaryOf(BuildContext context) =>
      _isDark(context) ? Theme.of(context).colorScheme.primary : primary;

  static Color findingBgOf(BuildContext context) =>
      _isDark(context) ? const Color(0xFF451A03) : findingBg;

  static Color findingTextOf(BuildContext context) =>
      _isDark(context) ? const Color(0xFFFBBF24) : findingText;

  static Color safeBgOf(BuildContext context) =>
      _isDark(context) ? const Color(0xFF064E3B) : safeBg;

  static Color safeTextOf(BuildContext context) =>
      _isDark(context) ? const Color(0xFF4ADE80) : safeText;

  static Color urgentBgOf(BuildContext context) =>
      _isDark(context) ? const Color(0xFF450A0A) : urgentBg;

  static Color urgentTextOf(BuildContext context) =>
      _isDark(context) ? const Color(0xFFF87171) : urgentText;

  static Color pendingOf(BuildContext context) =>
      _isDark(context) ? const Color(0xFF94A3B8) : pending;

  static Color pendingBgOf(BuildContext context) =>
      _isDark(context) ? const Color(0xFF334155) : pendingBg;
}

/// Representasi satu temuan individual dari sebuah lokasi POS.
class MaintenanceTemuanItem {
  final PosMaintenanceStatus status;
  final MaintenanceLogEntry log;
  final MaintenanceTemuan temuan;
  final int phase;
  final bool isFixed;

  const MaintenanceTemuanItem({
    required this.status,
    required this.log,
    required this.temuan,
    required this.phase,
    this.isFixed = false,
  });
}

/// Screen peta monitoring status maintenance cabang KC Manado.
class MaintenanceMapScreen extends StatefulWidget {
  final DraggableScrollableController? sheetController;
  final MapController? mapController;
  final bool showTileLayer;
  final Set<String>? initialErrorPosNames;
  final String? initialWilayah;

  const MaintenanceMapScreen({
    super.key,
    this.sheetController,
    this.mapController,
    this.showTileLayer = true,
    this.initialErrorPosNames,
    this.initialWilayah,
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
            if (t.status != 'tidak_sesuai') continue;
            items.add(MaintenanceTemuanItem(
              status: s,
              log: top,
              temuan: t,
              phase: currentPhase,
              isFixed: t.isFixed,
            ));
          }
        }
      } else {
        for (int p = 1; p <= 4; p++) {
          final pLogs = s.logsForPhase(p);
          if (pLogs.isNotEmpty) {
            final top = pLogs.first;
            for (final t in top.temuan) {
              if (t.status != 'tidak_sesuai') continue;
              items.add(MaintenanceTemuanItem(
                status: s,
                log: top,
                temuan: t,
                phase: p,
                isFixed: t.isFixed,
              ));
            }
          }
        }
      }
    }

    items.sort(compareTemuanItems);
    return items;
  }

  /// Komparator pengurutan temuan: belum selesai diperbaiki dulu, urgent dulu, lalu tidak_sesuai, lalu perlu_cek_manual, lalu tanggal terbaru.
  @visibleForTesting
  static int compareTemuanItems(
    MaintenanceTemuanItem a,
    MaintenanceTemuanItem b,
  ) {
    if (a.isFixed != b.isFixed) {
      return a.isFixed ? 1 : -1;
    }

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

class _MaintenanceMapScreenState extends State<MaintenanceMapScreen>
    with SingleTickerProviderStateMixin {
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

  late final AppBranch _branch;

  static LatLng _fallbackCenterFor(AppBranch branch) {
    switch (branch) {
      case AppBranch.manado:
        return const LatLng(1.4748, 124.8428);
      case AppBranch.bali:
        return const LatLng(-8.6705, 115.2126);
      case AppBranch.ho:
        return const LatLng(-5.1477, 119.4327);
    }
  }

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
  @visibleForTesting
  String get selectedWilayah => _selectedWilayah;
  @visibleForTesting
  set selectedWilayah(String value) {
    _selectedWilayah = value;
    if (mounted) setState(() {});
  }
  int? _selectedStatusRank;
  String? _selectedPosId;
  @visibleForTesting
  String? get selectedPosId => _selectedPosId;
  @visibleForTesting
  bool get mapReady => _mapReady;

  Set<String> _errorPosNames = {};
  @visibleForTesting
  Set<String> get errorPosNames => _errorPosNames;
  @visibleForTesting
  set errorPosNames(Set<String> value) {
    _errorPosNames = value.map((e) => e.trim().toLowerCase()).toSet();
    if (_errorPosNames.isNotEmpty) {
      _triggerRadarAnimation();
    }
    if (mounted) setState(() {});
  }

  late final AnimationController _radarAnimationController;
  int _radarCycleCount = 0;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialWilayah != null) {
      _selectedWilayah = widget.initialWilayah!;
    }
    _branch = BranchService.instance.currentBranch;
    _radarAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.initialErrorPosNames != null) {
      _errorPosNames = widget.initialErrorPosNames!
          .map((e) => e.trim().toLowerCase())
          .toSet();
      if (_errorPosNames.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _triggerRadarAnimation();
        });
      }
    }
    if (widget.mapController != null) {
      _mapController = widget.mapController!;
      _ownsMapController = false;
    } else {
      _mapController = MapController();
      _ownsMapController = true;
    }

    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);

    final branchCoords = LocationService.getLocationsByBranch(_branch)
        .where((l) => l.lat != 0 && l.lng != 0)
        .map((l) => LatLng(l.lat, l.lng))
        .toList();

    if (branchCoords.length >= 2) {
      _mapOptions = MapOptions(
        initialCameraFit: CameraFit.coordinates(
          coordinates: branchCoords,
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
        initialCenter: _fallbackCenterFor(_branch),
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
    _radarAnimationController.dispose();
    if (_ownsMapController) {
      _mapController.dispose();
    }
    super.dispose();
  }

  void _triggerRadarAnimation() {
    if (!mounted) return;
    final disable = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disable) {
      _radarAnimationController.reset();
      return;
    }
    _radarAnimationController.reset();
    _radarCycleCount = 0;
    _startRadarCycle();
  }

  void _startRadarCycle() {
    if (!mounted) return;
    final disable = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disable) {
      _radarAnimationController.reset();
      return;
    }
    _radarAnimationController.forward(from: 0.0).then((_) {
      if (!mounted) return;
      _radarCycleCount++;
      if (_radarCycleCount < 3) {
        _startRadarCycle();
      } else {
        _radarAnimationController.reset();
        if (mounted) setState(() {});
      }
    });
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

    final locations = LocationService.getLocationsByBranch(_branch);
    final monthFuture = MaintenanceLogService.fetchMonth(_selectedMonth, branch: _branch);
    final errorFuture = ErrorTicketService.fetchOpen()
        .then((open) => ErrorTicketService.openPosNames(open))
        .catchError((e) {
          debugPrint('[MaintenanceMapScreen] fetchOpen error: $e');
          return _errorPosNames;
        });

    final result = await monthFuture;
    final newErrorPosNames = await errorFuture;
    final statuses = MaintenanceLogService.buildStatuses(locations, result.logs, _branch);

    if (!mounted) return;

    setState(() {
      _allStatuses = statuses;
      _isOffline = result.offline;
      if (!result.offline) {
        _lastFetchTime = DateTime.now();
      }
      if (widget.initialErrorPosNames != null) {
        _errorPosNames = widget.initialErrorPosNames!
            .map((e) => e.trim().toLowerCase())
            .toSet();
      } else {
        _errorPosNames = newErrorPosNames;
      }
      _isLoading = false;
    });

    if (_errorPosNames.isNotEmpty) {
      _triggerRadarAnimation();
    }

    if (_mapReady) {
      _fitMapToCurrentFilter();
    }
  }

  Future<void> _silentRefresh() async {
    final locations = LocationService.getLocationsByBranch(_branch);
    final monthFuture = MaintenanceLogService.fetchMonth(_selectedMonth, branch: _branch);
    final errorFuture = ErrorTicketService.fetchOpen()
        .then((open) => ErrorTicketService.openPosNames(open))
        .catchError((e) {
          debugPrint('[MaintenanceMapScreen] silentRefresh fetchOpen error: $e');
          return _errorPosNames;
        });

    final result = await monthFuture;
    final newErrorPosNames = await errorFuture;
    final statuses = MaintenanceLogService.buildStatuses(locations, result.logs, _branch);

    if (!mounted) return;

    setState(() {
      _allStatuses = statuses;
      _isOffline = result.offline;
      if (!result.offline) {
        _lastFetchTime = DateTime.now();
      }
      if (widget.initialErrorPosNames != null) {
        _errorPosNames = widget.initialErrorPosNames!
            .map((e) => e.trim().toLowerCase())
            .toSet();
      } else {
        _errorPosNames = newErrorPosNames;
      }
    });

    if (_errorPosNames.isNotEmpty) {
      _triggerRadarAnimation();
    }
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
    final locations =
        LocationService.getLocationsByBranch(_branch);
    final present =
        locations.map((loc) => MaintenanceLogService.wilayahOf(loc, _branch)).toSet();
    return [
      'Semua',
      ...MaintenanceLogService.wilayahListFor(_branch).where(present.contains)
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
            .fold<int>(
              0,
              (sum, l) =>
                  sum +
                  l.temuan.where((t) => t.status == 'tidak_sesuai' && !t.isFixed).length,
            );
        return tCount > 0 ? '$tCount Temuan' : 'Temuan';
      } else {
        final tCount = s.logs.fold<int>(
          0,
          (sum, l) =>
              sum + l.temuan.where((t) => t.status == 'tidak_sesuai' && !t.isFixed).length,
        );
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

  String _formatBulanTahunShort(DateTime dt, {bool compactYear = false}) {
    final month = _namaBulanShort[dt.month - 1];
    if (compactYear) {
      final yy = (dt.year % 100).toString().padLeft(2, '0');
      return '$month $yy';
    }
    return '$month ${dt.year}';
  }

  void _centerOnLocation(PosMaintenanceStatus s) {
    if (s.location.lat != 0 && s.location.lng != 0) {
      _mapController.move(LatLng(s.location.lat, s.location.lng), 15.0);
    }
  }

  Future<void> _onMarkerTap(PosMaintenanceStatus s) async {
    setState(() {
      _selectedPosId = s.location.posId;
    });
    await _openDetail(s);
    if (mounted) {
      setState(() {
        _selectedPosId = null;
      });
    }
  }

  Future<void> _openDetail(PosMaintenanceStatus s) async {
    final refreshed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MaintenanceLocationDetailScreen(
          status: s,
          month: _selectedMonth,
        ),
      ),
    );
    if (refreshed == true && mounted) {
      _loadMonthData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
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

    return Scaffold(
      backgroundColor: colors.canvas,
      body: Column(
        children: [
          TiketBand(
            caption: 'Map Maintenance',
            leading: Expanded(
              child: _buildTopRow(),
            ),
            actions: const [],
            hero: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$posDone/$totalFiltered lokasi',
                      style: TextStyle(
                        fontFamily: TiketType.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.bandCaption,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: colors.bandTrack,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            footer: Row(
              children: [
                Expanded(
                  child: _buildPhaseStripStatTile(
                    rank: 0,
                    count: belumCount,
                    label: 'Belum',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPhaseStripStatTile(
                    rank: 1,
                    count: temuanCount,
                    label: 'Temuan',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPhaseStripStatTile(
                    rank: 2,
                    count: amanCount,
                    label: 'Aman',
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          if (_isOffline) _buildOfflineBanner(),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: _mapOptions,
                  children: [
                    if (widget.showTileLayer)
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        retinaMode: RetinaMode.isHighDensity(context),
                        userAgentPackageName:
                            'com.bssparking.timemark.bssparking_timemark',
                      ),
                    if (widget.showTileLayer)
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
                          color: colors.canvas,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colors.hairline,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.ink.withValues(alpha: 0.08),
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
                              style: TextStyle(
                                fontFamily: TiketType.fontFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colors.ink,
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
                              child: Text(
                                'Tampilkan semua',
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_errorCount > 0) _buildErrorFloatingChip(colors, _errorCount),
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
    final colors = TiketColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colors.signal.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 16,
            color: colors.signalText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _lastFetchTime != null
                  ? 'Offline, menampilkan data lokal · Update ${_formatJamMenit(_lastFetchTime!)}'
                  : 'Offline, menampilkan data lokal',
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.signalText,
              ),
            ),
          ),
          TextButton(
            onPressed: _loadMonthData,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(44, 32),
            ),
            child: Text(
              'Coba lagi',
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.signalText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMonthSwitcher({bool compactYear = false}) {
    final colors = TiketColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          iconSize: 20,
          color: colors.white,
          tooltip: 'Bulan sebelumnya',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: const Size(28, 44),
            padding: EdgeInsets.zero,
          ),
          constraints: const BoxConstraints(minWidth: 28, minHeight: 44),
          onPressed: _previousMonth,
        ),
        Icon(
          Icons.calendar_today_rounded,
          size: 14,
          color: colors.white,
        ),
        const SizedBox(width: 4),
        Text(
          _formatBulanTahunShort(_selectedMonth, compactYear: compactYear),
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontFamily: TiketType.fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colors.white,
          ),
        ),
        Semantics(
          enabled: _canGoNextMonth,
          label: 'Bulan berikutnya',
          child: IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: _canGoNextMonth ? colors.white : colors.white.withValues(alpha: 0.38),
            ),
            iconSize: 20,
            tooltip: _canGoNextMonth ? 'Bulan berikutnya' : null,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: const Size(28, 44),
              padding: EdgeInsets.zero,
            ),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 44),
            onPressed: _canGoNextMonth ? _nextMonth : null,
          ),
        ),
      ],
    );
  }

  Widget _buildWilayahPill() {
    final colors = TiketColors.of(context);
    return Semantics(
      button: true,
      label: 'Filter wilayah, $_selectedWilayah',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showWilayahDialog,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: colors.bandRaise,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.bandLine, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: colors.onBand,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 128),
                      child: Text(
                        _selectedWilayah,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.onBand,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: colors.onBand,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final isNarrow = screenWidth < 380 || constraints.maxWidth < 350;
        return Row(
          children: [
            TiketIconButton(
              icon: Icons.arrow_back_rounded,
              semanticLabel: 'Kembali',
              onPressed: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCompactMonthSwitcher(compactYear: isNarrow),
                    const SizedBox(width: 8),
                    Flexible(
                      child: _buildWilayahPill(),
                    ),
                  ],
                ),
              ),
            ),
            TiketIconButton(
              icon: Icons.refresh_rounded,
              semanticLabel: 'Perbarui data',
              onPressed: _loadMonthData,
            ),
          ],
        );
      },
    );
  }

  Future<void> _showWilayahDialog() async {
    final list = _availableWilayahList;
    final colors = TiketColors.of(context);
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final screenHeight = MediaQuery.sizeOf(ctx).height;
        return Dialog(
          backgroundColor: colors.dialog,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 48,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 360,
              maxHeight: screenHeight * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pilih wilayah',
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: colors.ink,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        tooltip: 'Tutup',
                        color: colors.ink,
                        onPressed: () => Navigator.pop(ctx),
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1.0,
                  color: colors.hairline,
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final w = list[index];
                      final isSelected = w == _selectedWilayah;
                      final count = w == 'Semua'
                          ? _allStatuses.length
                          : _allStatuses.where((s) => s.wilayah == w).length;

                      return Material(
                        color: isSelected
                            ? colors.primary.withValues(alpha: 0.08)
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(ctx, w),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      w,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: TiketType.fontFamily,
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? colors.primary
                                            : colors.ink,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.soft,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '$count',
                                      style: TextStyle(
                                        fontFamily: TiketType.fontFamily,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: colors.body,
                                      ),
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                      color: colors.primary,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
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

    if (selected != null && selected != _selectedWilayah && mounted) {
      setState(() {
        _selectedWilayah = selected;
      });
      _fitMapToCurrentFilter();
    }
  }

  Widget _buildPhaseStripStatTile({
    required int rank,
    required int count,
    required String label,
  }) {
    final colors = TiketColors.of(context);
    final isSelected = _selectedStatusRank == rank;
    final isOrangeTemuan = rank == 1 && count > 0;

    Color tileBg;
    Color textColor;
    Color countColor;
    Border? border;

    if (isOrangeTemuan) {
      tileBg = colors.signal;
      textColor = colors.ink;
      countColor = colors.ink;
      if (isSelected) {
        border = Border.all(color: colors.white, width: 2.0);
      }
    } else if (isSelected) {
      tileBg = colors.white;
      textColor = colors.ink;
      countColor = colors.ink;
    } else {
      tileBg = colors.bandRaise;
      textColor = colors.white;
      countColor = colors.white;
      border = Border.all(color: colors.bandLine, width: 1.0);
    }

    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Tampilkan lokasi $count $label saja',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedStatusRank = _selectedStatusRank == rank ? null : rank;
            });
            _fitMapToCurrentFilter();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: tileBg,
              borderRadius: BorderRadius.circular(12),
              border: border,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: TiketType.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: countColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: TiketType.fontFamily,
                    fontSize: 12,
                    fontWeight: isSelected || isOrangeTemuan ? FontWeight.w700 : FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Marker> _buildMarkers() {
    final filtered = _filteredStatuses;
    final baseStatuses = filtered
        .where((s) => s.location.lat != 0 && s.location.lng != 0)
        .toList();

    // Union pos with open error tickets regardless of status filter
    final existingPosIds = baseStatuses.map((s) => s.location.posId).toSet();
    final errorStatuses = _wilayahStatuses.where((s) {
      if (s.location.lat == 0 || s.location.lng == 0) return false;
      final normName = s.location.posName.toLowerCase().trim();
      return _errorPosNames.contains(normName);
    });

    final visibleStatuses = List<PosMaintenanceStatus>.from(baseStatuses);
    for (final s in errorStatuses) {
      if (!existingPosIds.contains(s.location.posId)) {
        visibleStatuses.add(s);
        existingPosIds.add(s.location.posId);
      }
    }

    final temuanItems = MaintenanceMapScreen.extractTemuanItems(
      statuses: filtered,
      isCurrentMonth: _isCurrentMonth,
      selectedMonth: _selectedMonth,
    );
    final urgentPosIds = temuanItems
        .where((t) => t.temuan.urgent && !t.isFixed)
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
            fontFamily: 'Figtree',
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
    final temuanCount = items.where((i) => !i.isFixed).length;
    final colors = TiketColors.of(context);
    final normName = s.location.posName.toLowerCase().trim();
    final hasError = _errorPosNames.contains(normName);
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final rank = _statusRank(s);
    Color glyphColor;
    Color circleBg;
    Color circleBorder;
    IconData glyphIcon;

    if (isUrgent) {
      glyphColor = colors.white;
      circleBg = colors.danger;
      circleBorder = colors.danger;
      glyphIcon = Icons.priority_high_rounded;
    } else if (rank == 1) {
      glyphColor = colors.black;
      circleBg = colors.signal;
      circleBorder = colors.signal;
      glyphIcon = Icons.priority_high_rounded;
    } else if (rank == 2) {
      glyphColor = colors.white;
      circleBg = colors.ok;
      circleBorder = colors.ok;
      glyphIcon = Icons.check_rounded;
    } else {
      glyphColor = colors.body;
      circleBg = colors.soft;
      circleBorder = colors.mute;
      glyphIcon = Icons.remove_rounded;
    }

    String semanticLabel;
    if (hasError) {
      semanticLabel = '${s.location.posName}, ada tiket error terbuka';
    } else if (rank == 0) {
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

    final pinWidget = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: circleBg,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? colors.primary : circleBorder,
              width: selected ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.ink.withValues(alpha: 0.16),
                blurRadius: selected ? 6 : 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(glyphIcon, size: 16, color: glyphColor),
        ),
        if (temuanCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: _buildNotificationBadge(
              count: temuanCount,
              isUrgent: isUrgent,
            ),
          ),
      ],
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillBg = hasError
        ? (isDark ? const Color(0xFFC81E1E) : colors.danger)
        : colors.canvas;
    final pillBorderColor = hasError
        ? (isDark ? const Color(0xFFC81E1E) : colors.danger)
        : (selected ? colors.primary : colors.mute);
    final pillTextColor = hasError ? colors.white : colors.ink;
    final pillLabel = hasError ? '${s.location.posName} · Error' : s.location.locationTag;

    return Marker(
      point: LatLng(s.location.lat, s.location.lng),
      width: hasError ? 120 : 100,
      height: hasError ? 124 : 60,
      alignment: Alignment.center,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: GestureDetector(
          onTap: () => _onMarkerTap(s),
          child: Container(
            constraints: BoxConstraints(minWidth: 48, minHeight: hasError ? 124 : 60),
            alignment: Alignment.center,
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasError)
                  Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      _buildRadarOuterRing(colors, disableAnimations: disableAnimations),
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: colors.danger.withValues(alpha: 0.20),
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.danger, width: 2.0),
                        ),
                      ),
                      pinWidget,
                    ],
                  )
                else
                  pinWidget,
                const SizedBox(height: 1),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: pillBorderColor,
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.ink.withValues(alpha: 0.10),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    height: 14,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        pillLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: pillTextColor,
                        ),
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
    final hasError = cluster.members.any((m) =>
        _errorPosNames.contains(m.location.posName.toLowerCase().trim()));
    final sumTemuan = cluster.members.fold<int>(
      0,
      (sum, m) =>
          sum +
          (temuanByPos[m.location.posId]?.where((i) => !i.isFixed).length ??
              0),
    );
    final colors = TiketColors.of(context);
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    Color clusterBg;
    Color clusterBorder;
    Color textColor;
    if (cluster.maxSeverity == 3) {
      clusterBg = colors.danger;
      clusterBorder = colors.danger;
      textColor = colors.white;
    } else if (cluster.maxSeverity == 2) {
      clusterBg = colors.signal;
      clusterBorder = colors.signal;
      textColor = colors.black;
    } else if (cluster.maxSeverity == 1) {
      clusterBg = colors.soft;
      clusterBorder = colors.mute;
      textColor = colors.body;
    } else {
      clusterBg = colors.ok;
      clusterBorder = colors.ok;
      textColor = colors.white;
    }

    final semanticLabel = hasUrgent
        ? '$n lokasi, $u urgent, $sumTemuan temuan'
        : '$n lokasi, $sumTemuan temuan';

    final clusterBubble = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: clusterBg,
        shape: BoxShape.circle,
        border: Border.all(color: clusterBorder, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: colors.ink.withValues(alpha: 0.16),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$n',
        style: TextStyle(
          fontFamily: TiketType.fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );

    return Marker(
      point: LatLng(
        cluster.members.first.location.lat,
        cluster.members.first.location.lng,
      ),
      width: hasError ? 110 : 48,
      height: hasError ? 110 : 48,
      alignment: Alignment.center,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: GestureDetector(
          onTap: () => _showClusterMembersSheet(cluster.members),
          child: Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            alignment: Alignment.center,
            color: Colors.transparent,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (hasError) ...[
                  _buildRadarOuterRing(colors, disableAnimations: disableAnimations),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: colors.danger.withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.danger, width: 2.0),
                    ),
                  ),
                ],
                clusterBubble,
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

  Widget _buildRadarOuterRing(TiketColors colors, {required bool disableAnimations}) {
    final outerCircle = Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: colors.danger, width: 1.5),
      ),
    );

    if (disableAnimations || !_radarAnimationController.isAnimating) {
      return Opacity(
        opacity: 0.6,
        child: outerCircle,
      );
    }

    return AnimatedBuilder(
      animation: _radarAnimationController,
      builder: (context, child) {
        final t = _radarAnimationController.value;
        final scale = 0.85 + (1.15 - 0.85) * t;
        final opacity = 0.6 - (0.6 - 0.15) * t;
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: outerCircle,
    );
  }

  List<PosMaintenanceStatus> get _visibleErrorStatuses {
    return _wilayahStatuses.where((s) {
      if (s.location.lat == 0 || s.location.lng == 0) return false;
      return _errorPosNames.contains(s.location.posName.toLowerCase().trim());
    }).toList();
  }

  int get _errorCount => _visibleErrorStatuses.length;

  Widget _buildErrorFloatingChip(TiketColors colors, int count) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? colors.canvas : Colors.white;

    return Positioned(
      top: 16,
      left: 16,
      child: Semantics(
        button: true,
        label: '$count lokasi error',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onFloatingErrorChipTap(_visibleErrorStatuses),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            alignment: Alignment.centerLeft,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.danger, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: colors.ink.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSmallRadarIcon(colors.danger),
                  const SizedBox(width: 8),
                  Text(
                    '$count lokasi error',
                    style: TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.danger,
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

  Widget _buildSmallRadarIcon(Color dangerColor) {
    return SizedBox(
      width: 18,
      height: 18,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: dangerColor, width: 1.5),
              ),
            ),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dangerColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onFloatingErrorChipTap(List<PosMaintenanceStatus> errorStatuses) {
    if (errorStatuses.isEmpty) return;

    final coords = errorStatuses
        .map((s) => LatLng(s.location.lat, s.location.lng))
        .toList();

    if (_mapReady) {
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

    if (errorStatuses.length == 1) {
      _onMarkerTap(errorStatuses.first);
    }
  }

  void _showClusterMembersSheet(List<PosMaintenanceStatus> members) {
    final colors = TiketColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.dialog,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                      color: colors.hairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    '${members.length} Lokasi Terpilih',
                    style: TextStyle(
                      fontFamily: TiketType.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.ink,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: members.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 0.5,
                      color: colors.hairline,
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
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.ink,
                          ),
                        ),
                        subtitle: Text(
                          _statusLabel(m),
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 12,
                            color: colors.body,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: colors.body,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFloatingControlButton(
          icon: Icons.add,
          tooltip: 'Perbesar',
          onTap: () {
            _mapController.move(
              _mapController.camera.center,
              _mapController.camera.zoom + 1,
            );
          },
        ),
        const SizedBox(height: 8),
        _buildFloatingControlButton(
          icon: Icons.remove,
          tooltip: 'Perkecil',
          onTap: () {
            _mapController.move(
              _mapController.camera.center,
              _mapController.camera.zoom - 1,
            );
          },
        ),
      ],
    );
  }

  Widget _buildFloatingControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final colors = TiketColors.of(context);
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
            decoration: BoxDecoration(
              color: colors.canvas,
              shape: BoxShape.circle,
              border: Border.all(
                color: colors.hairline,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.ink.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: colors.ink,
            ),
          ),
        ),
      ),
    );
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
    final surfaceRaisedColor = MaintenanceMapPalette.surfaceRaisedOf(context);
    final dividerColor = MaintenanceMapPalette.dividerOf(context);
    final textPrimaryColor = MaintenanceMapPalette.textPrimaryOf(context);
    final textSecondaryColor = MaintenanceMapPalette.textSecondaryOf(context);
    final pendingColor = MaintenanceMapPalette.pendingOf(context);
    final pendingBgColor = MaintenanceMapPalette.pendingBgOf(context);

    final address = status.location.fullAddress.trim();
    final addressLine = address.isNotEmpty
        ? '${status.wilayah} · $address'
        : status.wilayah;

    Widget trailingBadge;
    if (isCurrentMonth) {
      trailingBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: pendingBgColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Fase $currentPhase',
          maxLines: 1,
          style: TextStyle(
            fontFamily: 'Figtree',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: pendingColor,
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
          color: pendingBgColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          missingLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Figtree',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: pendingColor,
          ),
        ),
      );
    }

    return Material(
      color: isSelected ? surfaceRaisedColor : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: EdgeInsets.fromLTRB(isSelected ? 9 : 12, 8, 8, 8),
          decoration: BoxDecoration(
            border: Border(
              left: isSelected
                  ? BorderSide(
                      color: pendingColor,
                      width: 3,
                    )
                  : BorderSide.none,
              bottom: BorderSide(
                color: dividerColor,
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
                  color: pendingBgColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: pendingColor,
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
                            style: TextStyle(
                              fontFamily: 'Figtree',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textPrimaryColor,
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
                              color: surfaceRaisedColor,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: dividerColor,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              status.location.locationTag,
                              style: TextStyle(
                                fontFamily: 'Figtree',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textSecondaryColor,
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
                      style: TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: textSecondaryColor,
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
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: textSecondaryColor,
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
    final surfaceRaisedColor = MaintenanceMapPalette.surfaceRaisedOf(context);
    final dividerColor = MaintenanceMapPalette.dividerOf(context);
    final textPrimaryColor = MaintenanceMapPalette.textPrimaryOf(context);
    final textSecondaryColor = MaintenanceMapPalette.textSecondaryOf(context);
    final urgentBgColor = MaintenanceMapPalette.urgentBgOf(context);
    final urgentTextColor = MaintenanceMapPalette.urgentTextOf(context);

    IconData severityIcon;
    Color severityIconColor;
    Color iconCircleBg;
    String severityStatusText;
    Color barColor;

    if (t.urgent) {
      severityIcon = Icons.error_rounded;
      severityIconColor = MaintenanceMapPalette.urgentIcon;
      iconCircleBg = urgentBgColor;
      severityStatusText = 'Urgent';
      barColor = MaintenanceMapPalette.urgentRed;
    } else if (t.status == 'tidak_sesuai') {
      severityIcon = Icons.warning_amber_rounded;
      severityIconColor = MaintenanceMapPalette.findingIcon;
      iconCircleBg = MaintenanceMapPalette.findingBgOf(context);
      severityStatusText = 'Tidak sesuai';
      barColor = MaintenanceMapPalette.findingIcon;
    } else {
      severityIcon = Icons.help_outline_rounded;
      severityIconColor = MaintenanceMapPalette.pendingOf(context);
      iconCircleBg = MaintenanceMapPalette.pendingBgOf(context);
      severityStatusText = 'Perlu cek';
      barColor = MaintenanceMapPalette.pendingOf(context);
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
      color: isSelected ? surfaceRaisedColor : Colors.transparent,
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
                    ? BorderSide(
                        color: dividerColor,
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
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textPrimaryColor,
                        ),
                      ),
                      if (hasLine2) ...[
                        const SizedBox(height: 2),
                        Text(
                          line2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: textSecondaryColor,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        line3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: textSecondaryColor,
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
                      color: urgentBgColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Urgent',
                      style: TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: urgentTextColor,
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
                      child: Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: textSecondaryColor,
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
    final temuanCount = latestLog != null
        ? latestLog.temuan.where((t) => t.status == 'tidak_sesuai').length
        : 0;
    final surfaceRaisedColor = MaintenanceMapPalette.surfaceRaisedOf(context);
    final dividerColor = MaintenanceMapPalette.dividerOf(context);
    final textPrimaryColor = MaintenanceMapPalette.textPrimaryOf(context);
    final textSecondaryColor = MaintenanceMapPalette.textSecondaryOf(context);

    Color statusColor;
    Color statusBg;
    IconData statusIcon;
    String trailingLabel;

    if (!isDone) {
      statusColor = MaintenanceMapPalette.pendingOf(context);
      statusBg = MaintenanceMapPalette.pendingBgOf(context);
      statusIcon = Icons.schedule_rounded;
      trailingLabel = 'Belum';
    } else if (temuanCount > 0) {
      statusColor = MaintenanceMapPalette.findingTextOf(context);
      statusBg = MaintenanceMapPalette.findingBgOf(context);
      statusIcon = Icons.warning_rounded;
      trailingLabel = '$temuanCount Temuan';
    } else {
      statusColor = MaintenanceMapPalette.safeTextOf(context);
      statusBg = MaintenanceMapPalette.safeBgOf(context);
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
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: dividerColor,
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
                            style: TextStyle(
                              fontFamily: 'Figtree',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textPrimaryColor,
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
                              color: surfaceRaisedColor,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: dividerColor,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              status.location.locationTag,
                              style: TextStyle(
                                fontFamily: 'Figtree',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textSecondaryColor,
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
                      style: TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Meta: calendar + date + 'oleh teknisi'
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: textSecondaryColor,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            latestLog != null
                                ? '${MaintenanceMapScreen.formatTanggalMeta(latestLog.tanggal)} oleh ${latestLog.teknisiNama}'
                                : 'Belum ada laporan bulan ini',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Figtree',
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: textSecondaryColor,
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
                            fontFamily: 'Figtree',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: textSecondaryColor,
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
                          ? MaintenanceMapPalette.pendingOf(context)
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
