import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/share_helper.dart';
import '../../../data/models/maintenance_temuan_fix.dart';
import '../../../data/services/maintenance_fix_service.dart';
import '../../../data/services/maintenance_log_service.dart';
import '../../../data/services/whatsapp_report_service.dart';
import '../widgets/temuan_fix_sheet.dart';
import 'maintenance_map_screen.dart';

/// Halaman detail inspeksi maintenance untuk suatu lokasi pos parkir.
class MaintenanceLocationDetailScreen extends StatefulWidget {
  final PosMaintenanceStatus status;
  final DateTime month;
  final Future<String?> Function()? sheetOnPickPhoto;
  final Future<FixSubmitResult> Function({
    required MaintenanceLogEntry log,
    required MaintenanceTemuan temuan,
    required String catatan,
    required List<String> photoPaths,
  })? sheetOnSubmit;

  const MaintenanceLocationDetailScreen({
    super.key,
    required this.status,
    required this.month,
    this.sheetOnPickPhoto,
    this.sheetOnSubmit,
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
  final Map<String, MaintenanceTemuanFix> _localFixes = {};
  bool _hasFixedAny = false;
  bool _isPopping = false;

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return widget.month.year == now.year && widget.month.month == now.month;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Muat fix yang sudah ada dari logs dan pending local
    for (final log in widget.status.logs) {
      for (final t in log.temuan) {
        if (t.fix != null) {
          _localFixes['${log.id}|${t.label}'] = t.fix!;
        }
      }
    }
    for (final fix in MaintenanceFixService.pendingLocal()) {
      _localFixes['${fix.logId}|${fix.temuanLabel}'] = fix;
    }

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
    final topLog = phaseLogs.isNotEmpty ? phaseLogs.first : null;
    final openTemuanCount = topLog != null
        ? topLog.temuan.where((t) {
            final fix = _localFixes['${topLog.id}|${t.label}'] ?? t.fix;
            return fix == null;
          }).length
        : 0;
    final logCount = widget.status.logs.length;
    final bgColor = MaintenanceMapPalette.bgOf(context);
    final surfaceColor = MaintenanceMapPalette.surfaceOf(context);
    final textPrimaryColor = MaintenanceMapPalette.textPrimaryOf(context);
    final textSecondaryColor = MaintenanceMapPalette.textSecondaryOf(context);
    final primaryColor = MaintenanceMapPalette.primaryOf(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _isPopping) return;
        _isPopping = true;
        Navigator.of(context).pop(_hasFixedAny ? true : null);
      },
      child: Scaffold(
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
            onPressed: () {
              if (!_isPopping) {
                _isPopping = true;
                Navigator.of(context).pop(_hasFixedAny ? true : null);
              }
            },
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
                    _buildProgresMaintenanceCard(),
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
                      indicatorWeight: 3,
                      labelColor: primaryColor,
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
                        Tab(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Temuan ($openTemuanCount)'),
                                if (openTemuanCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 18,
                                    height: 18,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: MaintenanceMapPalette.urgentIcon,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$openTemuanCount',
                                      style: const TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        height: 1.0,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        Tab(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Riwayat ($logCount)'),
                          ),
                        ),
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
      padding: const EdgeInsets.all(16),
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
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: textPrimaryColor,
                  ),
                ),
              ),
              if (s.location.locationTag.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          const SizedBox(height: 10),

          // Address (Row 1)
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: textSecondaryColor,
              ),
              const SizedBox(width: 8),
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
                size: 16,
                color: textSecondaryColor,
              ),
              const SizedBox(width: 8),
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
                size: 16,
                color: textSecondaryColor,
              ),
              const SizedBox(width: 8),
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

          // 'Buka di Maps' full-width tonal button (hide when lat==0 && lng==0)
          if (s.location.lat != 0 && s.location.lng != 0) ...[
            const SizedBox(height: 14),
            Semantics(
              button: true,
              label: 'Buka di Maps',
              child: InkWell(
                onTap: () => _openInMaps(s.location.lat, s.location.lng),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 18,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Buka di Maps',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.open_in_new,
                        size: 18,
                        color: primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgresMaintenanceCard() {
    final surfaceColor = MaintenanceMapPalette.surfaceOf(context);
    final surfaceRaisedColor = MaintenanceMapPalette.surfaceRaisedOf(context);
    final dividerColor = MaintenanceMapPalette.dividerOf(context);
    final textPrimaryColor = MaintenanceMapPalette.textPrimaryOf(context);
    final textSecondaryColor = MaintenanceMapPalette.textSecondaryOf(context);
    final primaryColor = MaintenanceMapPalette.primaryOf(context);
    final pendingColor = MaintenanceMapPalette.pendingOf(context);

    final doneCount = [1, 2, 3, 4]
        .where((p) => widget.status.isPhaseDone(p))
        .length;

    final currentPhaseLogs = widget.status.logsForPhase(_selectedPhase);
    final topLog = currentPhaseLogs.isNotEmpty ? currentPhaseLogs.first : null;
    final openTemuanCount = topLog != null
        ? topLog.temuan.where((t) {
            final fix = _localFixes['${topLog.id}|${t.label}'] ?? t.fix;
            return fix == null;
          }).length
        : 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
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
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.build_rounded,
                      size: 18,
                      color: primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Progres Maintenance',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$doneCount / 4 Fase',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textSecondaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            thickness: 0.8,
            color: dividerColor,
          ),
          const SizedBox(height: 12),

          // 4 Phase cards in one row
          Row(
            key: const Key('phase_cards_row'),
            children: List.generate(4, (i) {
              final p = i + 1;
              final isSelected = _selectedPhase == p;
              final isDone = widget.status.isPhaseDone(p);
              final pLogs = widget.status.logsForPhase(p);
              final pLog = pLogs.isNotEmpty ? pLogs.first : null;
              final hasTemuan = widget.status.hasPhaseTemuan(p);

              Color statusColor;
              Color statusBg;
              IconData statusIcon;
              String statusText;

              if (!isDone) {
                statusColor = pendingColor;
                statusBg = MaintenanceMapPalette.pendingBgOf(context);
                statusIcon = Icons.schedule_rounded;
                statusText = 'Belum';
              } else if (hasTemuan) {
                statusColor = MaintenanceMapPalette.findingTextOf(context);
                statusBg = MaintenanceMapPalette.findingBgOf(context);
                statusIcon = Icons.warning_amber_rounded;
                statusText = 'Temuan';
              } else {
                statusColor = MaintenanceMapPalette.safeTextOf(context);
                statusBg = MaintenanceMapPalette.safeBgOf(context);
                statusIcon = Icons.check_circle_outline_rounded;
                statusText = 'Aman';
              }

              final String line2Text = (isDone && pLog != null)
                  ? '${pLog.sesuaiPoin} / ${pLog.totalPoin}'
                  : _phaseDateRange(p);

              final textScaler = MediaQuery.textScalerOf(context);
              final showStatusText = textScaler.scale(1.0) <= 1.1;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: i == 0 ? 0 : 3,
                    right: i == 3 ? 0 : 3,
                  ),
                  child: InkWell(
                    onTap: () => setState(() => _selectedPhase = p),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryColor.withValues(alpha: 0.08)
                            : surfaceColor,
                        borderRadius: BorderRadius.circular(10),
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
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? primaryColor : textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              line2Text,
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: textPrimaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Semantics(
                            label: statusText,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: showStatusText ? 4 : 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(statusIcon, size: 12, color: statusColor),
                                    if (showStatusText) ...[
                                      const SizedBox(width: 2),
                                      Text(
                                        statusText,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ],
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
            }),
          ),

          const SizedBox(height: 12),

          // 3 Stat tiles below phase cards
          Row(
            children: [
              _buildStatTile(
                icon: Icons.assignment_outlined,
                iconColor: textSecondaryColor,
                value: topLog != null ? '${topLog.totalPoin}' : '–',
                valueColor: textPrimaryColor,
                label: 'Total Item',
                labelColor: textSecondaryColor,
                bgColor: surfaceRaisedColor,
                border: Border.all(color: dividerColor, width: 0.8),
              ),
              const SizedBox(width: 8),
              _buildStatTile(
                icon: Icons.check_circle_outline_rounded,
                iconColor: MaintenanceMapPalette.safeIcon,
                value: topLog != null ? '${topLog.sesuaiPoin}' : '–',
                valueColor: MaintenanceMapPalette.safeTextOf(context),
                label: 'Sesuai',
                labelColor: MaintenanceMapPalette.safeTextOf(context),
                bgColor: MaintenanceMapPalette.safeBgOf(context),
              ),
              const SizedBox(width: 8),
              _buildStatTile(
                icon: Icons.warning_amber_rounded,
                iconColor: MaintenanceMapPalette.findingIcon,
                value: topLog != null ? '$openTemuanCount' : '–',
                valueColor: MaintenanceMapPalette.findingTextOf(context),
                label: 'Temuan',
                labelColor: MaintenanceMapPalette.findingTextOf(context),
                bgColor: MaintenanceMapPalette.findingBgOf(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required Color iconColor,
    required String value,
    required Color valueColor,
    required String label,
    required Color labelColor,
    required Color bgColor,
    Border? border,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: border,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: valueColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFixMetaShort(MaintenanceTemuanFix fix) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final localDt = fix.fixedAt.toLocal();
    final d = localDt.day;
    final m = months[localDt.month - 1];
    final hh = localDt.hour.toString().padLeft(2, '0');
    final mm = localDt.minute.toString().padLeft(2, '0');
    return '$d $m $hh:$mm WITA';
  }

  Future<void> _handleTandaiDiperbaiki(
    MaintenanceLogEntry log,
    MaintenanceTemuan temuan,
  ) async {
    final result = await TemuanFixSheet.show(
      context,
      log: log,
      temuan: temuan,
      onPickPhoto: widget.sheetOnPickPhoto,
      onSubmit: widget.sheetOnSubmit,
    );

    if (result == null || !mounted) return;

    final submitRes = result.submitResult;
    final fix = submitRes.fix;
    if (fix != null) {
      setState(() {
        _localFixes['${log.id}|${temuan.label}'] = fix;
        _hasFixedAny = true;
      });
    }

    if (submitRes.status == FixSubmitStatus.synced) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Temuan ditandai sudah diperbaiki')),
      );
    } else if (submitRes.status == FixSubmitStatus.queued) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tersimpan. Dikirim otomatis saat ada sinyal'),
        ),
      );
    }

    if (fix != null && mounted) {
      await _showWhatsAppShareDialog(log, temuan, fix, result.photoPaths);
    }
  }

  Future<void> _showWhatsAppShareDialog(
    MaintenanceLogEntry log,
    MaintenanceTemuan temuan,
    MaintenanceTemuanFix fix,
    List<String> photoPaths,
  ) async {
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Kirim laporan ke WhatsApp?',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Nanti'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
            child: const Text('Kirim WA'),
          ),
        ],
      ),
    );

    if (send == true) {
      final text = WhatsAppReportService.formatTemuanFixReport(
        log: log,
        temuan: temuan,
        fix: fix,
      );
      final validPaths = photoPaths
          .where((p) => !p.startsWith('http') && File(p).existsSync())
          .toList();
      await ShareHelper.shareToWhatsApp(
        text: text,
        imagePaths: validPaths.isNotEmpty ? validPaths : null,
      );
    }
  }

  Future<void> _handleReshareWhatsApp(
    MaintenanceLogEntry log,
    MaintenanceTemuan temuan,
    MaintenanceTemuanFix fix,
  ) async {
    final text = WhatsAppReportService.formatTemuanFixReport(
      log: log,
      temuan: temuan,
      fix: fix,
    );
    final validPaths = fix.photoUrls
        .where((p) => !p.startsWith('http') && File(p).existsSync())
        .toList();
    await ShareHelper.shareToWhatsApp(
      text: text,
      imagePaths: validPaths.isNotEmpty ? validPaths : null,
    );
  }

  Widget _buildTemuanTab() {
    final phaseLogs = widget.status.logsForPhase(_selectedPhase);
    final isDone = phaseLogs.isNotEmpty;
    final currentLog = isDone ? phaseLogs.first : null;
    final temuanList = currentLog != null ? currentLog.temuan : const <MaintenanceTemuan>[];
    final surfaceColor = MaintenanceMapPalette.surfaceOf(context);
    final dividerColor = MaintenanceMapPalette.dividerOf(context);
    final textPrimaryColor = MaintenanceMapPalette.textPrimaryOf(context);
    final textSecondaryColor = MaintenanceMapPalette.textSecondaryOf(context);
    final safeTextColor = MaintenanceMapPalette.safeTextOf(context);
    final safeBgColor = MaintenanceMapPalette.safeBgOf(context);
    final primaryColor = MaintenanceMapPalette.primaryOf(context);

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

    final enrichedTemuanList = temuanList.map((t) {
      if (currentLog != null) {
        final fix = _localFixes['${currentLog.id}|${t.label}'] ?? t.fix;
        if (fix != null) {
          return t.copyWith(fix: fix);
        }
      }
      return t;
    }).toList();

    final sorted = List<MaintenanceTemuan>.from(enrichedTemuanList)
      ..sort((a, b) {
        if (a.isFixed != b.isFixed) {
          return a.isFixed ? 1 : -1;
        }
        if (a.urgent != b.urgent) {
          return a.urgent ? -1 : 1;
        }
        return 0;
      });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final t = sorted[index];
        final isFixed = t.isFixed;
        final fix = t.fix;
        final isExpanded = _expandedAlasanIndices.contains(index);

        Color badgeBg;
        Color badgeTextColor;
        String badgeLabel;
        if (isFixed) {
          badgeBg = safeBgColor;
          badgeTextColor = safeTextColor;
          badgeLabel = 'Diperbaiki';
        } else if (t.urgent) {
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
          badgeLabel = 'Perlu Cek';
        }

        // Leading 48x48 rounded-12 tinted square
        Color leadingBg;
        Color leadingIconColor;
        IconData leadingIcon;
        if (isFixed) {
          leadingBg = safeBgColor;
          leadingIconColor = MaintenanceMapPalette.safeIcon;
          leadingIcon = Icons.check_circle_rounded;
        } else if (t.urgent) {
          leadingBg = MaintenanceMapPalette.urgentBgOf(context);
          leadingIconColor = MaintenanceMapPalette.urgentIcon;
          leadingIcon = Icons.warning_amber_rounded;
        } else {
          leadingBg = MaintenanceMapPalette.findingBgOf(context);
          leadingIconColor = MaintenanceMapPalette.findingIcon;
          leadingIcon = Icons.warning_amber_rounded;
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
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: leadingBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      leadingIcon,
                      size: 24,
                      color: leadingIconColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textPrimaryColor,
                          ),
                        ),
                        if (t.alasan.isNotEmpty) ...[
                          const SizedBox(height: 4),
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
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: textSecondaryColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
              if (isFixed && fix != null) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.build_outlined,
                      size: 16,
                      color: textSecondaryColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        fix.catatan,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: textPrimaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 15,
                      color: textSecondaryColor,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Oleh ${fix.teknisiNama}',
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '|',
                        style: TextStyle(
                          color: dividerColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.schedule,
                      size: 15,
                      color: textSecondaryColor,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _formatFixMetaShort(fix),
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
                if (fix.pendingSync) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.sync_rounded,
                        size: 14,
                        color: MaintenanceMapPalette.pendingOf(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Menunggu sinyal, dikirim otomatis',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: MaintenanceMapPalette.pendingOf(context),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: currentLog != null
                        ? () => _handleReshareWhatsApp(
                              currentLog,
                              t,
                              fix,
                            )
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(
                        color: primaryColor,
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.share_rounded,
                      size: 18,
                    ),
                    label: const Text(
                      'Kirim ulang laporan WA',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
              if (!isFixed &&
                  t.status == 'tidak_sesuai' &&
                  currentLog != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: Semantics(
                    label:
                        'Tandai temuan ${t.label} sudah diperbaiki',
                    button: true,
                    child: OutlinedButton.icon(
                      onPressed: () => _handleTandaiDiperbaiki(
                        currentLog,
                        t,
                      ),
                      icon: const Icon(
                        Icons.check_rounded,
                        size: 18,
                      ),
                      label: const Text(
                        'Tandai Sudah Diperbaiki',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: BorderSide(
                          color: primaryColor,
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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
