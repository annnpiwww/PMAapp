import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/services/maintenance_log_service.dart';
import 'maintenance_map_screen.dart';

/// Halaman detail inspeksi maintenance untuk suatu lokasi pos parkir.
class MaintenanceLocationDetailScreen extends StatefulWidget {
  final PosMaintenanceStatus status;
  final DateTime month;

  const MaintenanceLocationDetailScreen({
    super.key,
    required this.status,
    required this.month,
  });

  @override
  State<MaintenanceLocationDetailScreen> createState() =>
      _MaintenanceLocationDetailScreenState();
}

class _MaintenanceLocationDetailScreenState
    extends State<MaintenanceLocationDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _selectedPhase;
  final Set<int> _expandedAlasanIndices = {};

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return widget.month.year == now.year && widget.month.month == now.month;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final now = DateTime.now();
    if (_isCurrentMonth) {
      final currentPhase = MaintenanceLogService.phaseForDate(now);
      if (widget.status.isPhaseDone(currentPhase)) {
        _selectedPhase = currentPhase;
      } else {
        int? latestDone;
        for (int p = 4; p >= 1; p--) {
          if (widget.status.isPhaseDone(p)) {
            latestDone = p;
            break;
          }
        }
        _selectedPhase = latestDone ?? currentPhase;
      }
    } else {
      int? latestDone;
      for (int p = 4; p >= 1; p--) {
        if (widget.status.isPhaseDone(p)) {
          latestDone = p;
          break;
        }
      }
      _selectedPhase = latestDone ?? 1;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _phaseDateRange(int phase) {
    switch (phase) {
      case 1:
        return '1-7';
      case 2:
        return '8-14';
      case 3:
        return '15-21';
      case 4:
      default:
        final lastDay =
            DateTime(widget.month.year, widget.month.month + 1, 0).day;
        return '22-$lastDay';
    }
  }

  Future<void> _openInMaps(double lat, double lng) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    try {
      final success =
          await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka Maps')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka Maps')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final phaseLogs = widget.status.logsForPhase(_selectedPhase);
    final temuanCount =
        phaseLogs.isNotEmpty ? phaseLogs.first.temuan.length : 0;
    final bgColor = MaintenanceMapPalette.bgOf(context);
    final surfaceColor = MaintenanceMapPalette.surfaceOf(context);
    final textPrimaryColor = MaintenanceMapPalette.textPrimaryOf(context);
    final textSecondaryColor = MaintenanceMapPalette.textSecondaryOf(context);
    final primaryColor = MaintenanceMapPalette.primaryOf(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: textPrimaryColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Detail Lokasi',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimaryColor,
          ),
        ),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderBlock(),
                  _buildPhaseStepper(),
                  _buildSelectedPhaseResult(),
                ],
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                Container(
                  color: surfaceColor,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: primaryColor,
                    indicatorWeight: 2,
                    labelColor: textPrimaryColor,
                    unselectedLabelColor: textSecondaryColor,
                    labelStyle: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: [
                      Tab(text: 'Temuan ($temuanCount)'),
                      const Tab(text: 'Riwayat'),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTemuanTab(),
            _buildRiwayatTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBlock() {
    final s = widget.status;
    final latestLog = s.logs.isNotEmpty ? s.logs.first : null;
    final surfaceColor = MaintenanceMapPalette.surfaceOf(context);
    final surfaceRaisedColor = MaintenanceMapPalette.surfaceRaisedOf(context);
    final dividerColor = MaintenanceMapPalette.dividerOf(context);
    final textPrimaryColor = MaintenanceMapPalette.textPrimaryOf(context);
    final textSecondaryColor = MaintenanceMapPalette.textSecondaryOf(context);
    final primaryColor = MaintenanceMapPalette.primaryOf(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dividerColor,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // posName + tag pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  s.location.posName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textPrimaryColor,
                  ),
                ),
              ),
              if (s.location.locationTag.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: surfaceRaisedColor,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: dividerColor,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    s.location.locationTag,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Address (Row 1)
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 15,
                color: textSecondaryColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${s.wilayah} · ${s.location.fullAddress}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: textSecondaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Teknisi (Row 2)
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 15,
                color: textSecondaryColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Teknisi: ${latestLog?.teknisiNama ?? '-'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: textSecondaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Date & Time (Row 3)
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 15,
                color: textSecondaryColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  latestLog != null
                      ? '${MaintenanceMapScreen.formatTanggalShort(latestLog.tanggal)} · ${latestLog.jamSelesai}'
                      : 'Belum ada laporan bulan ini',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: textSecondaryColor,
                  ),
                ),
              ),
            ],
          ),

          // 'Buka di Maps' button (hide when lat==0 || lng==0)
          if (s.location.lat != 0 && s.location.lng != 0) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openInMaps(s.location.lat, s.location.lng),
              icon: Icon(
                Icons.map_outlined,
                size: 16,
                color: primaryColor,
              ),
              label: Text(
                'Buka di Maps',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: primaryColor,
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhaseStepper() {
    final surfaceColor = MaintenanceMapPalette.surfaceOf(context);
    final surfaceRaisedColor = MaintenanceMapPalette.surfaceRaisedOf(context);
    final dividerColor = MaintenanceMapPalette.dividerOf(context);
    final textPrimaryColor = MaintenanceMapPalette.textPrimaryOf(context);
    final textSecondaryColor = MaintenanceMapPalette.textSecondaryOf(context);
    final primaryColor = MaintenanceMapPalette.primaryOf(context);
    final pendingColor = MaintenanceMapPalette.pendingOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: List.generate(4, (i) {
          final p = i + 1;
          final isSelected = _selectedPhase == p;
          final isDone = widget.status.isPhaseDone(p);
          final hasTemuan = widget.status.hasPhaseTemuan(p);

          Color statusColor;
          IconData statusIcon;
          String statusText;

          if (!isDone) {
            statusColor = pendingColor;
            statusIcon = Icons.schedule_rounded;
            statusText = 'Belum';
          } else if (hasTemuan) {
            statusColor = MaintenanceMapPalette.findingIcon;
            statusIcon = Icons.warning_amber_rounded;
            statusText = 'Temuan';
          } else {
            statusColor = MaintenanceMapPalette.safeIcon;
            statusIcon = Icons.check_circle_outline_rounded;
            statusText = 'Aman';
          }

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: i == 0 ? 0 : 4,
                right: i == 3 ? 0 : 4,
              ),
              child: InkWell(
                onTap: isDone ? () => setState(() => _selectedPhase = p) : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? surfaceRaisedColor : surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? primaryColor : dividerColor,
                      width: isSelected ? 1.5 : 0.8,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Fase $p',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? primaryColor : textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _phaseDateRange(p),
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              statusText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSelectedPhaseResult() {
    final phaseLogs = widget.status.logsForPhase(_selectedPhase);
    final isDone = phaseLogs.isNotEmpty;
    final topLog = isDone ? phaseLogs.first : null;
    final temuanCount = topLog != null ? topLog.temuan.length : 0;
    final surfaceColor = MaintenanceMapPalette.surfaceOf(context);
    final surfaceRaisedColor = MaintenanceMapPalette.surfaceRaisedOf(context);
    final dividerColor = MaintenanceMapPalette.dividerOf(context);
    final textPrimaryColor = MaintenanceMapPalette.textPrimaryOf(context);
    final textSecondaryColor = MaintenanceMapPalette.textSecondaryOf(context);

    String badgeText;
    Color badgeBg;
    Color badgeTextColor;
    if (!isDone) {
      badgeText = 'Belum dikerjakan';
      badgeBg = MaintenanceMapPalette.pendingBgOf(context);
      badgeTextColor = MaintenanceMapPalette.pendingOf(context);
    } else if (temuanCount > 0) {
      badgeText = '$temuanCount Temuan';
      badgeBg = MaintenanceMapPalette.findingBgOf(context);
      badgeTextColor = MaintenanceMapPalette.findingTextOf(context);
    } else {
      badgeText = 'Aman';
      badgeBg = MaintenanceMapPalette.safeBgOf(context);
      badgeTextColor = MaintenanceMapPalette.safeTextOf(context);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dividerColor,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Hasil Inspeksi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
          if (isDone && topLog != null) ...[
            const SizedBox(height: 8),
            Text(
              '${topLog.sesuaiPoin} / ${topLog.totalPoin}',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textPrimaryColor,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: topLog.totalPoin == 0
                    ? 0.0
                    : (topLog.sesuaiPoin / topLog.totalPoin),
                minHeight: 4,
                backgroundColor: surfaceRaisedColor,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  MaintenanceMapPalette.safeIcon,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'S Sesuai: ${topLog.sesuaiPoin}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: MaintenanceMapPalette.safeTextOf(context),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'B Bermasalah: ${topLog.totalPoin - topLog.sesuaiPoin}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: (topLog.totalPoin - topLog.sesuaiPoin > 0)
                          ? MaintenanceMapPalette.findingTextOf(context)
                          : textSecondaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Belum dikerjakan pada bulan ini',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: textSecondaryColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTemuanTab() {
    final phaseLogs = widget.status.logsForPhase(_selectedPhase);
    final isDone = phaseLogs.isNotEmpty;
    final temuanList =
        isDone ? phaseLogs.first.temuan : const <MaintenanceTemuan>[];
    final surfaceColor = MaintenanceMapPalette.surfaceOf(context);
    final surfaceRaisedColor = MaintenanceMapPalette.surfaceRaisedOf(context);
    final dividerColor = MaintenanceMapPalette.dividerOf(context);
    final textPrimaryColor = MaintenanceMapPalette.textPrimaryOf(context);
    final textSecondaryColor = MaintenanceMapPalette.textSecondaryOf(context);

    if (temuanList.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDone) ...[
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 40,
                  color: MaintenanceMapPalette.safeIcon,
                ),
                const SizedBox(height: 8),
                Text(
                  'Semua poin sesuai',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MaintenanceMapPalette.safeTextOf(context),
                  ),
                ),
              ] else ...[
                Text(
                  'Belum ada laporan bulan ini',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: textSecondaryColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final sorted = List<MaintenanceTemuan>.from(temuanList)
      ..sort((a, b) {
        if (a.urgent && !b.urgent) return -1;
        if (!a.urgent && b.urgent) return 1;
        return 0;
      });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final t = sorted[index];
        final isExpanded = _expandedAlasanIndices.contains(index);

        Color badgeBg;
        Color badgeTextColor;
        String badgeLabel;
        if (t.urgent) {
          badgeBg = MaintenanceMapPalette.urgentBgOf(context);
          badgeTextColor = MaintenanceMapPalette.urgentTextOf(context);
          badgeLabel = 'Urgent';
        } else if (t.status == 'tidak_sesuai') {
          badgeBg = MaintenanceMapPalette.findingBgOf(context);
          badgeTextColor = MaintenanceMapPalette.findingTextOf(context);
          badgeLabel = 'Tidak sesuai';
        } else {
          badgeBg = MaintenanceMapPalette.pendingBgOf(context);
          badgeTextColor = MaintenanceMapPalette.pendingOf(context);
          badgeLabel = 'Perlu cek';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: dividerColor,
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: surfaceRaisedColor,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textSecondaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: badgeTextColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (t.alasan.isNotEmpty) ...[
                const SizedBox(height: 6),
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedAlasanIndices.remove(index);
                      } else {
                        _expandedAlasanIndices.add(index);
                      }
                    });
                  },
                  child: Text(
                    t.alasan,
                    maxLines: isExpanded ? null : 3,
                    overflow: isExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: textSecondaryColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRiwayatTab() {
    final logs = widget.status.logs;
    final surfaceColor = MaintenanceMapPalette.surfaceOf(context);
    final dividerColor = MaintenanceMapPalette.dividerOf(context);
    final textPrimaryColor = MaintenanceMapPalette.textPrimaryOf(context);
    final textSecondaryColor = MaintenanceMapPalette.textSecondaryOf(context);

    if (logs.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Belum ada laporan bulan ini',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: textSecondaryColor,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        final temuanCount = log.temuan.length;

        final badgeBg = temuanCount > 0
            ? MaintenanceMapPalette.findingBgOf(context)
            : MaintenanceMapPalette.safeBgOf(context);
        final badgeTextColor = temuanCount > 0
            ? MaintenanceMapPalette.findingTextOf(context)
            : MaintenanceMapPalette.safeTextOf(context);
        final badgeLabel = temuanCount > 0 ? '$temuanCount Temuan' : 'Aman';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: dividerColor,
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${MaintenanceMapScreen.formatTanggalShort(log.tanggal)} · ${log.jamSelesai}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: badgeTextColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                log.templateName.isNotEmpty
                    ? log.templateName
                    : (MaintenanceLogService.phaseNames[
                            MaintenanceLogService.phaseForTemplate(
                                log.templateId)] ??
                        'Maintenance'),
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textSecondaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: textSecondaryColor,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${log.teknisiNama}${log.teknisiNpp.isNotEmpty ? ' (${log.teknisiNpp})' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: textSecondaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${log.sesuaiPoin}/${log.totalPoin} sesuai',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textPrimaryColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _TabBarDelegate(this.child);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => 48.0;

  @override
  double get minExtent => 48.0;

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => true;
}
