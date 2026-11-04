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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detail Lokasi',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: MaintenanceMapPalette.textPrimary,
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
                  color: MaintenanceMapPalette.surface,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: MaintenanceMapPalette.primary,
                    indicatorWeight: 2,
                    labelColor: MaintenanceMapPalette.textPrimary,
                    unselectedLabelColor: MaintenanceMapPalette.textSecondary,
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

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MaintenanceMapPalette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MaintenanceMapPalette.divider,
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
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: MaintenanceMapPalette.textPrimary,
                  ),
                ),
              ),
              if (s.location.locationTag.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: MaintenanceMapPalette.surfaceRaised,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: MaintenanceMapPalette.divider,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    s.location.locationTag,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: MaintenanceMapPalette.primary,
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
              const Icon(
                Icons.location_on_outlined,
                size: 15,
                color: MaintenanceMapPalette.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${s.wilayah} · ${s.location.fullAddress}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: MaintenanceMapPalette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Teknisi (Row 2)
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 15,
                color: MaintenanceMapPalette.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Teknisi: ${latestLog?.teknisiNama ?? '-'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: MaintenanceMapPalette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Date & Time (Row 3)
          Row(
            children: [
              const Icon(
                Icons.access_time,
                size: 15,
                color: MaintenanceMapPalette.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  latestLog != null
                      ? '${MaintenanceMapScreen.formatTanggalShort(latestLog.tanggal)} · ${latestLog.jamSelesai}'
                      : 'Belum ada laporan bulan ini',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: MaintenanceMapPalette.textSecondary,
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
              icon: const Icon(
                Icons.map_outlined,
                size: 16,
                color: MaintenanceMapPalette.primary,
              ),
              label: const Text(
                'Buka di Maps',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MaintenanceMapPalette.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                  color: MaintenanceMapPalette.primary,
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: const Size(double.infinity, 40),
                maximumSize: const Size(double.infinity, 40),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhaseStepper() {
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
            statusColor = MaintenanceMapPalette.pending;
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
                    color: isSelected
                        ? MaintenanceMapPalette.surfaceRaised
                        : MaintenanceMapPalette.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? MaintenanceMapPalette.primary
                          : MaintenanceMapPalette.divider,
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
                          color: isSelected
                              ? MaintenanceMapPalette.primary
                              : MaintenanceMapPalette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _phaseDateRange(p),
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: MaintenanceMapPalette.textSecondary,
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

    String badgeText;
    Color badgeBg;
    Color badgeTextColor;
    if (!isDone) {
      badgeText = 'Belum dikerjakan';
      badgeBg = MaintenanceMapPalette.pendingBg;
      badgeTextColor = MaintenanceMapPalette.pending;
    } else if (temuanCount > 0) {
      badgeText = '$temuanCount Temuan';
      badgeBg = MaintenanceMapPalette.findingBg;
      badgeTextColor = MaintenanceMapPalette.findingText;
    } else {
      badgeText = 'Aman';
      badgeBg = MaintenanceMapPalette.safeBg;
      badgeTextColor = MaintenanceMapPalette.safeText;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MaintenanceMapPalette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MaintenanceMapPalette.divider,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Hasil Inspeksi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: MaintenanceMapPalette.textPrimary,
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
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: MaintenanceMapPalette.textPrimary,
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
                backgroundColor: MaintenanceMapPalette.surfaceRaised,
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
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: MaintenanceMapPalette.safeText,
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
                          ? MaintenanceMapPalette.findingText
                          : MaintenanceMapPalette.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              'Belum dikerjakan pada bulan ini',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: MaintenanceMapPalette.textSecondary,
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

    if (temuanList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                const Text(
                  'Semua poin sesuai',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MaintenanceMapPalette.safeText,
                  ),
                ),
              ] else ...[
                const Text(
                  'Belum ada laporan bulan ini',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: MaintenanceMapPalette.textSecondary,
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
          badgeBg = MaintenanceMapPalette.urgentBg;
          badgeTextColor = MaintenanceMapPalette.urgentText;
          badgeLabel = 'Urgent';
        } else if (t.status == 'tidak_sesuai') {
          badgeBg = MaintenanceMapPalette.findingBg;
          badgeTextColor = MaintenanceMapPalette.findingText;
          badgeLabel = 'Tidak sesuai';
        } else {
          badgeBg = MaintenanceMapPalette.pendingBg;
          badgeTextColor = MaintenanceMapPalette.pending;
          badgeLabel = 'Perlu cek';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MaintenanceMapPalette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: MaintenanceMapPalette.divider,
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
                    decoration: const BoxDecoration(
                      color: MaintenanceMapPalette.surfaceRaised,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MaintenanceMapPalette.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: MaintenanceMapPalette.textPrimary,
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
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: MaintenanceMapPalette.textSecondary,
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

    if (logs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Belum ada laporan bulan ini',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: MaintenanceMapPalette.textSecondary,
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
            ? MaintenanceMapPalette.findingBg
            : MaintenanceMapPalette.safeBg;
        final badgeTextColor = temuanCount > 0
            ? MaintenanceMapPalette.findingText
            : MaintenanceMapPalette.safeText;
        final badgeLabel = temuanCount > 0 ? '$temuanCount Temuan' : 'Aman';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MaintenanceMapPalette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: MaintenanceMapPalette.divider,
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${MaintenanceMapScreen.formatTanggalShort(log.tanggal)} · ${log.jamSelesai}',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MaintenanceMapPalette.textPrimary,
                    ),
                  ),
                  const Spacer(),
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
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: MaintenanceMapPalette.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 14,
                    color: MaintenanceMapPalette.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${log.teknisiNama}${log.teknisiNpp.isNotEmpty ? ' (${log.teknisiNpp})' : ''}',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: MaintenanceMapPalette.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${log.sesuaiPoin}/${log.totalPoin} sesuai',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MaintenanceMapPalette.textPrimary,
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
