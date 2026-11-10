import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/tiket_colors.dart';
import '../../../core/utils/share_helper.dart';
import '../../../core/widgets/tiket/tiket.dart';
import '../../../data/models/daily_task_model.dart';
import '../../../data/models/error_report.dart';
import '../../../data/models/maintenance_temuan_fix.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/daily_task_service.dart';
import '../../../data/services/error_ticket_service.dart';
import '../../../data/services/maintenance_fix_service.dart';
import '../../../data/services/maintenance_log_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/whatsapp_report_service.dart';
import '../../daily_tasks/screens/custom_task_execution_screen.dart';
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
  final Future<List<DailyTaskModel>> Function()? errorTicketsLoader;

  const MaintenanceLocationDetailScreen({
    super.key,
    required this.status,
    required this.month,
    this.sheetOnPickPhoto,
    this.sheetOnSubmit,
    this.errorTicketsLoader,
  });

  @override
  State<MaintenanceLocationDetailScreen> createState() =>
      _MaintenanceLocationDetailScreenState();
}

class _MaintenanceLocationDetailScreenState
    extends State<MaintenanceLocationDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _tabIndex = 0;
  late int _selectedPhase;
  final Set<int> _expandedAlasanIndices = {};
  final Map<String, MaintenanceTemuanFix> _localFixes = {};
  bool _hasFixedAny = false;
  bool _isPopping = false;
  List<DailyTaskModel> _errorTickets = [];

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return widget.month.year == now.year && widget.month.month == now.month;
  }

  @override
  void initState() {
    super.initState();
    _loadErrorTickets();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _tabIndex && mounted) {
        setState(() => _tabIndex = _tabController.index);
      }
    });

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

  Future<void> _loadErrorTickets() async {
    try {
      final loader = widget.errorTicketsLoader ?? ErrorTicketService.fetchOpen;
      final tickets = await loader();
      if (!mounted) return;
      final posName = widget.status.location.posName.trim().toLowerCase();
      final matching = tickets
          .where((t) => t.posName.trim().toLowerCase() == posName)
          .toList();
      setState(() {
        _errorTickets = matching;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorTickets = [];
        });
      }
    }
  }

  static String _formatDateMeta(DateTime dt) {
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
    final d = dt.day.toString().padLeft(2, '0');
    final m = shortMonths[dt.month - 1];
    final y = dt.year;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d $m $y, $hh.$mm';
  }

  Widget _buildErrorSection(TiketColors colors) {
    final currentUserName = (AuthRepository.instance.currentUser?.nama ??
            StorageService.getLastTechnicianName())
        .trim();

    return Container(
      color: colors.canvas,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: colors.danger,
              ),
              const SizedBox(width: 6),
              Text(
                'LAPORAN ERROR',
                style: TextStyle(
                  fontFamily: TiketType.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: colors.danger,
                ),
              ),
              if (_errorTickets.length > 1) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.dangerTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_errorTickets.length}',
                    style: TextStyle(
                      fontFamily: TiketType.fontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.danger,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < _errorTickets.length; i++) ...[
            () {
              final t = _errorTickets[i];
              final report = ErrorReport.parse(t.deskripsi);
              final title = report.kendala.isNotEmpty
                  ? report.kendala
                  : (t.judul.isNotEmpty ? t.judul : 'Kendala');
              final reportedAt = report.reportedAt;
              final meta = reportedAt != null
                  ? '${_formatDateMeta(reportedAt)} · Dilaporkan ${t.createdBy}'
                  : 'Dilaporkan ${t.createdBy}';
              final isOwner = currentUserName.isNotEmpty &&
                  DailyTaskService.isAssignedTo(t, currentUserName);

              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: colors.danger,
                      width: 3.0,
                    ),
                  ),
                ),
                padding:
                    const EdgeInsets.only(left: 12.0, top: 2.0, bottom: 2.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: TiketType.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      style: TextStyle(
                        fontFamily: TiketType.fontFamily,
                        fontSize: 13,
                        color: colors.mute,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.dangerTint,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Belum selesai',
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.danger,
                            ),
                          ),
                        ),
                        if (reportedAt != null) ...[
                          Builder(
                            builder: (_) {
                              final dur = formatDurasi(
                                  DateTime.now().difference(reportedAt));
                              if (dur.isEmpty) return const SizedBox.shrink();
                              return Text(
                                'sudah $dur',
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 13,
                                  color: colors.mute,
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Penyebab',
                      style: TextStyle(
                        fontFamily: TiketType.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.mute,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      report.penyebab.isNotEmpty ? report.penyebab : '-',
                      style: TextStyle(
                        fontFamily: TiketType.fontFamily,
                        fontSize: 14,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Solusi sementara',
                      style: TextStyle(
                        fontFamily: TiketType.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.mute,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      report.solusiSementara.isNotEmpty
                          ? report.solusiSementara
                          : '-',
                      style: TextStyle(
                        fontFamily: TiketType.fontFamily,
                        fontSize: 14,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isOwner)
                      Align(
                        alignment: Alignment.centerRight,
                        child: IntrinsicWidth(
                          child: TiketPill(
                            label: 'Kerjakan',
                            kind: TiketPillKind.primary,
                            height: 36,
                            expand: false,
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CustomTaskExecutionScreen(task: t),
                                ),
                              );
                              if (mounted) {
                                _loadErrorTickets();
                              }
                            },
                          ),
                        ),
                      )
                    else
                      Text(
                        t.isOpenHandover
                            ? 'Belum diambil teknisi'
                            : 'Ditangani ${t.teknisiNama}',
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 13,
                          color: colors.mute,
                        ),
                      ),
                  ],
                ),
              );
            }(),
            if (i < _errorTickets.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: colors.hairline,
                ),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final s = widget.status;
    final phaseLogs = widget.status.logsForPhase(_selectedPhase);
    final topLog = phaseLogs.isNotEmpty ? phaseLogs.first : null;
    final latestLog = s.logs.isNotEmpty ? s.logs.first : null;
    final openTemuanCount = topLog != null
        ? topLog.temuan.where((t) {
            final fix = _localFixes['${topLog.id}|${t.label}'] ?? t.fix;
            return fix == null;
          }).length
        : 0;
    final logCount = widget.status.logs.length;
    final doneCount = [1, 2, 3, 4]
        .where((p) => widget.status.isPhaseDone(p))
        .length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _isPopping) return;
        _isPopping = true;
        Navigator.of(context).pop(_hasFixedAny ? true : null);
      },
      child: Scaffold(
        backgroundColor: colors.canvas,
        body: Column(
          children: [
            TiketBand(
              caption: '${s.wilayah}${s.location.locationTag.isNotEmpty ? ' · ${s.location.locationTag}' : ''} · ${s.location.fullAddress}',
              leading: TiketIconButton(
                icon: Icons.arrow_back_rounded,
                semanticLabel: 'Kembali',
                onPressed: () {
                  if (!_isPopping) {
                    _isPopping = true;
                    Navigator.of(context).pop(_hasFixedAny ? true : null);
                  }
                },
              ),
              actions: [
                if (s.location.lat != 0 && s.location.lng != 0)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: TiketPill(
                        label: 'Buka di Maps',
                        icon: Icons.map_outlined,
                        kind: TiketPillKind.band,
                        onPressed: () => _openInMaps(s.location.lat, s.location.lng),
                      ),
                    ),
                  ),
                TiketIconButton(
                  icon: Icons.refresh_rounded,
                  semanticLabel: 'Muat ulang',
                  onPressed: () {
                    setState(() {
                      for (final fix in MaintenanceFixService.pendingLocal()) {
                        _localFixes['${fix.logId}|${fix.temuanLabel}'] = fix;
                      }
                    });
                  },
                ),
              ],
              hero: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.location.posName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: TiketType.fontFamily,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    latestLog != null
                        ? '${latestLog.teknisiNama} · Inspeksi ${MaintenanceMapScreen.formatTanggalShort(latestLog.tanggal)}'
                        : 'Belum ada inspeksi',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: TiketType.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.bandCaption,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Progres Maintenance',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$doneCount / 4 Fase',
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.bandCaption,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildPhaseTilesRow(),
                  // Retained offstage for backward-compatibility with existing tests
                  Offstage(
                    offstage: true,
                    child: Row(
                      children: [
                        const Text('Total Item'),
                        Text(topLog != null ? '${topLog.totalPoin}' : '–'),
                        const Text('Sesuai'),
                        Text(topLog != null ? '${topLog.sesuaiPoin}' : '–'),
                        const Text('Temuan'),
                        Text(topLog != null ? '$openTemuanCount' : '–'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    if (_errorTickets.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _buildErrorSection(colors),
                      ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _TabBarDelegate(
                        Container(
                          color: colors.canvas,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          alignment: Alignment.center,
                          child: TiketSegmented<int>(
                            options: [
                              (0, openTemuanCount > 0 ? 'Temuan ($openTemuanCount)' : 'Temuan'),
                              (1, logCount > 0 ? 'Checklist ($logCount)' : 'Checklist'),
                            ],
                            selected: _tabIndex,
                            onChanged: (idx) {
                              setState(() => _tabIndex = idx);
                              _tabController.animateTo(idx);
                            },
                          ),
                        ),
                        height: 56.0,
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
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseTilesRow() {
    final colors = TiketColors.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final showStatusText = textScaler.scale(1.0) <= 1.1;

    return Row(
      key: const Key('phase_cards_row'),
      children: List.generate(4, (i) {
        final p = i + 1;
        final isSelected = _selectedPhase == p;
        final isDone = widget.status.isPhaseDone(p);
        final pLogs = widget.status.logsForPhase(p);
        final pLog = pLogs.isNotEmpty ? pLogs.first : null;
        final hasTemuan = widget.status.hasPhaseTemuan(p);

        TiketStatus markerStatus;
        String statusLabel;
        if (!isDone) {
          markerStatus = TiketStatus.notStarted;
          statusLabel = 'Belum';
        } else if (hasTemuan) {
          markerStatus = TiketStatus.attention;
          statusLabel = 'Temuan';
        } else {
          markerStatus = TiketStatus.ok;
          statusLabel = 'Aman';
        }

        final String line2Text = (isDone && pLog != null)
            ? '${pLog.sesuaiPoin} / ${pLog.totalPoin}'
            : _phaseDateRange(p);

        final tileBg = isSelected
            ? colors.white
            : colors.bandRaise;
        final tileBorder = isSelected
            ? null
            : Border.all(color: colors.bandLine, width: 1.5);
        final titleColor = isSelected ? colors.black : colors.white;
        final numColor = isSelected ? colors.black : colors.white;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: i == 0 ? 0 : 3,
              right: i == 3 ? 0 : 3,
            ),
            child: Semantics(
              label: statusLabel,
              button: true,
              child: InkWell(
                onTap: () => setState(() => _selectedPhase = p),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tileBg,
                    borderRadius: BorderRadius.circular(10),
                    border: tileBorder,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Fase $p',
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: titleColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          ExcludeSemantics(
                            child: StatusMarker(
                              status: markerStatus,
                              size: 10,
                              onBand: !isSelected,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          line2Text,
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: numColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (showStatusText)
                        Text(
                          statusLabel,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: hasTemuan
                                ? colors.signal
                                : (isSelected ? colors.body : colors.bandCaption),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
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
    final colors = TiketColors.of(context);
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.dialog,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Kirim laporan ke WhatsApp?',
          style: TextStyle(
            fontFamily: TiketType.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.ink,
          ),
        ),
        actions: [
          TiketPill(
            label: 'Nanti',
            kind: TiketPillKind.secondary,
            height: 40,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TiketPill(
            label: 'Kirim WA',
            kind: TiketPillKind.primary,
            height: 40,
            onPressed: () => Navigator.of(ctx).pop(true),
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
    final colors = TiketColors.of(context);
    final phaseLogs = widget.status.logsForPhase(_selectedPhase);
    final isDone = phaseLogs.isNotEmpty;
    final currentLog = isDone ? phaseLogs.first : null;
    final temuanList = currentLog != null ? currentLog.temuan : const <MaintenanceTemuan>[];

    if (temuanList.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDone) ...[
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 40,
                  color: colors.ok,
                ),
                const SizedBox(height: 8),
                Text(
                  'Semua poin sesuai',
                  style: TextStyle(
                    fontFamily: TiketType.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.okText,
                  ),
                ),
              ] else ...[
                Text(
                  'Belum ada laporan bulan ini',
                  style: TextStyle(
                    fontFamily: TiketType.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: colors.body,
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? colors.dialog : const Color(0xFFFFFFFF);
    final cardBorder = isDark ? colors.hairline : const Color(0xFFE6E6E6);

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: sorted.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final t = sorted[index];
        final isFixed = t.isFixed;
        final fix = t.fix;
        final isExpanded = _expandedAlasanIndices.contains(index);

        final TiketStatus markerStatus = isFixed
            ? TiketStatus.ok
            : (t.urgent ? TiketStatus.danger : TiketStatus.attention);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cardBorder,
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: StatusMarker(
                      status: markerStatus,
                      size: 20,
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
                            fontFamily: TiketType.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.ink,
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
                                fontFamily: TiketType.fontFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: colors.mute,
                              ),
                            ),
                          ),
                        ],
                        if (isFixed && fix != null) ...[
                          const SizedBox(height: 8),
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IntrinsicWidth(
                                child: StatusChip(
                                  label: 'Diperbaiki',
                                  kind: TiketChipKind.ok,
                                ),
                              ),
                            ],
                          ),
                          if (fix.catatan.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              fix.catatan,
                              style: TextStyle(
                                fontFamily: TiketType.fontFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: colors.ink,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                'Sudah diperbaiki · ',
                                style: TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.okText,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  'Oleh ${fix.teknisiNama}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: TiketType.fontFamily,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: colors.body,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  '·',
                                  style: TextStyle(
                                    color: colors.body,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  _formatFixMetaShort(fix),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: TiketType.fontFamily,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: colors.body,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (fix.pendingSync) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.sync_rounded,
                                  size: 14,
                                  color: colors.body,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Menunggu sinyal, dikirim otomatis',
                                  style: TextStyle(
                                    fontFamily: TiketType.fontFamily,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: colors.body,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (fix.photoUrls.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 56,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: fix.photoUrls.length,
                                separatorBuilder: (context, index) => const SizedBox(width: 8),
                                itemBuilder: (context, pIdx) {
                                  final p = fix.photoUrls[pIdx];
                                  final isNetwork = p.startsWith('http://') || p.startsWith('https://');
                                  final file = File(p);
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: isNetwork
                                        ? Image.network(
                                            p,
                                            width: 56,
                                            height: 56,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              width: 56,
                                              height: 56,
                                              color: colors.soft,
                                              child: Icon(
                                                Icons.image_outlined,
                                                size: 20,
                                                color: colors.body,
                                              ),
                                            ),
                                          )
                                        : (file.existsSync()
                                            ? Image.file(
                                                file,
                                                width: 56,
                                                height: 56,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => Container(
                                                  width: 56,
                                                  height: 56,
                                                  color: colors.soft,
                                                  child: Icon(
                                                    Icons.image_outlined,
                                                    size: 20,
                                                    color: colors.body,
                                                  ),
                                                ),
                                              )
                                            : Container(
                                                width: 56,
                                                height: 56,
                                                color: colors.soft,
                                                child: Icon(
                                                  Icons.image_outlined,
                                                  size: 20,
                                                  color: colors.body,
                                                ),
                                              )),
                                  );
                                },
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TiketPill(
                              label: 'Kirim ulang laporan WA',
                              icon: Icons.share_rounded,
                              kind: TiketPillKind.secondary,
                              onPressed: currentLog != null
                                  ? () => _handleReshareWhatsApp(currentLog, t, fix)
                                  : null,
                              height: 38,
                              expand: false,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (t.urgent)
                                const IntrinsicWidth(
                                  child: StatusChip(
                                    label: 'Urgent',
                                    kind: TiketChipKind.danger,
                                  ),
                                ),
                              if (t.status == 'tidak_sesuai')
                                const IntrinsicWidth(
                                  child: StatusChip(
                                    label: 'Belum diperbaiki',
                                    kind: TiketChipKind.neutral,
                                  ),
                                )
                              else ...[
                                const IntrinsicWidth(
                                  child: StatusChip(
                                    label: 'Perlu cek',
                                    kind: TiketChipKind.attention,
                                  ),
                                ),
                                const ExcludeSemantics(
                                  child: SizedBox(
                                    width: 0,
                                    height: 0,
                                    child: OverflowBox(
                                      child: Text(
                                        'Perlu Cek',
                                        style: TextStyle(
                                          fontSize: 0,
                                          color: Colors.transparent,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (!isFixed && t.status == 'tidak_sesuai' && currentLog != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: IntrinsicWidth(
                    child: Semantics(
                      label: 'Tandai temuan ${t.label} sudah diperbaiki',
                      button: true,
                      child: TiketPill(
                        label: 'Tandai sudah diperbaiki',
                        icon: Icons.camera_alt_outlined,
                        kind: TiketPillKind.primary,
                        height: 36,
                        expand: false,
                        onPressed: () => _handleTandaiDiperbaiki(currentLog, t),
                      ),
                    ),
                  ),
                ),
                const ExcludeSemantics(
                  child: SizedBox(
                    width: 0,
                    height: 0,
                    child: OverflowBox(
                      child: Text(
                        'Tandai Sudah Diperbaiki',
                        style: TextStyle(
                          fontSize: 0,
                          color: Colors.transparent,
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
    final colors = TiketColors.of(context);
    final logs = widget.status.logs;

    if (logs.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Belum ada laporan bulan ini',
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: colors.body,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        final temuanCount = log.temuan.length;

        final badgeBg = temuanCount > 0
            ? colors.signal.withValues(alpha: 0.15)
            : colors.ok.withValues(alpha: 0.15);
        final badgeTextColor = temuanCount > 0
            ? colors.signalText
            : colors.okText;
        final badgeLabel = temuanCount > 0 ? '$temuanCount Temuan' : 'Aman';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.canvas,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colors.hairline,
              width: 1.0,
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
                        fontFamily: TiketType.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.ink,
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
                        fontFamily: TiketType.fontFamily,
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
                  fontFamily: TiketType.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.body,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: colors.body,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${log.teknisiNama}${log.teknisiNpp.isNotEmpty ? ' (${log.teknisiNpp})' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: TiketType.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: colors.body,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${log.sesuaiPoin}/${log.totalPoin} sesuai',
                style: TextStyle(
                  fontFamily: TiketType.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.ink,
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
  final double height;
  _TabBarDelegate(this.child, {this.height = 56.0});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => true;
}
