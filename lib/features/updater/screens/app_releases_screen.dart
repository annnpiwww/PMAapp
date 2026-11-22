import 'package:flutter/material.dart';

import '../../../core/constants/tiket_colors.dart';
import '../../../core/widgets/tiket/tiket.dart';
import '../../../data/services/app_release_admin_service.dart';
import '../../../data/services/app_update_service.dart';
import '../widgets/updater_ticket_widgets.dart';
import 'upload_release_screen.dart';

class AppReleasesScreen extends StatefulWidget {
  final AppReleaseAdminService? service;
  final List<AdminReleaseItem>? initialReleases;
  final String? initialErrorMessage;
  final bool initialForbidden;

  const AppReleasesScreen({
    super.key,
    this.service,
    this.initialReleases,
    this.initialErrorMessage,
    this.initialForbidden = false,
  });

  @override
  State<AppReleasesScreen> createState() => _AppReleasesScreenState();
}

class _AppReleasesScreenState extends State<AppReleasesScreen> {
  static const List<String> _monthsId = [
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

  late final AppReleaseAdminService _service;
  bool _loading = false;
  bool _busyAction = false;
  String? _updatingTargetReleaseId;
  bool _isForbidden = false;
  String? _errorMessage;
  List<AdminReleaseItem> _releases = const [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AppReleaseAdminService.instance;
    if (widget.initialReleases != null ||
        widget.initialErrorMessage != null ||
        widget.initialForbidden) {
      _releases = widget.initialReleases ?? const [];
      _errorMessage = widget.initialErrorMessage;
      _isForbidden = widget.initialForbidden;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _isForbidden = false;
    });
    try {
      final items = await _service.list();
      if (!mounted) return;
      setState(() {
        _releases = items;
        _loading = false;
      });
    } on AppReleaseAdminException catch (e) {
      if (!mounted) return;
      setState(() {
        _isForbidden = e.isForbidden;
        _errorMessage = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat daftar rilis.';
        _loading = false;
      });
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Belum terbit';
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final mon = _monthsId[(local.month - 1).clamp(0, 11)];
    final hr = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$day $mon ${local.year} $hr.$min';
  }

  Future<void> _confirmPublishDraft(AdminReleaseItem item) async {
    final confirmed = await showPublishConfirmDialog(
      context,
      versionName: item.versionName,
      abiShort: AppReleaseAdminService.abiShortLabel(item.abi),
      sizeBytes: item.sizeBytes,
      mandatory: item.mandatory,
      minSupportedVersion: item.minSupportedVersion,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyAction = true);
    try {
      await _service.publish(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rilis v${item.versionName} diterbitkan.')),
      );
      await _load();
    } on AppReleaseAdminException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _confirmRollback(AdminReleaseItem item) async {
    final confirmed = await showRollbackConfirmDialog(
      context,
      versionName: item.versionName,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyAction = true);
    try {
      await _service.rollback(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rilis v${item.versionName} ditarik.')),
      );
      await _load();
    } on AppReleaseAdminException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _confirmWidenToAll(AdminReleaseItem item) async {
    final colors = TiketColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: colors.dialog,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        title: Text(
          'Rilis ke semua cabang?',
          style: TextStyle(
            fontFamily: TiketType.fontFamily,
            fontSize: 18.0,
            fontWeight: FontWeight.w800,
            color: colors.ink,
          ),
        ),
        content: Text(
          'Versi ${item.versionName} akan tersedia untuk semua teknisi. Versi lama di server akan dihapus.',
          style: TextStyle(
            fontFamily: TiketType.fontFamily,
            fontSize: 14.0,
            height: 20.0 / 14.0,
            color: colors.body,
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: UpdaterActionButton(
                  label: 'Batal',
                  isPrimary: false,
                  onPressed: () => Navigator.of(dCtx).pop(false),
                ),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: UpdaterActionButton(
                  label: 'Rilis ke semua',
                  onPressed: () => Navigator.of(dCtx).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busyAction = true;
      _updatingTargetReleaseId = item.id;
    });
    try {
      await _service.setTargets(item.id, null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Versi ${item.versionName} sekarang untuk semua cabang.',
          ),
        ),
      );
      await _load();
    } on AppReleaseAdminException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengubah target rilis.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyAction = false;
          _updatingTargetReleaseId = null;
        });
      }
    }
  }

  Future<void> _deleteDraft(AdminReleaseItem item) async {
    setState(() => _busyAction = true);
    try {
      await _service.deleteDraft(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Draf v${item.versionName} dihapus.')),
      );
      await _load();
    } on AppReleaseAdminException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _confirmDeleteRelease(AdminReleaseItem item) async {
    final colors = TiketColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: colors.dialog,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        title: Text(
          'Hapus rilis v${item.versionName} (Build ${item.versionCode})?',
          style: TextStyle(
            fontFamily: TiketType.fontFamily,
            fontSize: 18.0,
            fontWeight: FontWeight.w800,
            color: colors.ink,
          ),
        ),
        content: Text(
          'File APK dan riwayatnya dihapus permanen. Tidak bisa dibatalkan.',
          style: TextStyle(
            fontFamily: TiketType.fontFamily,
            fontSize: 14.0,
            height: 20.0 / 14.0,
            color: colors.body,
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: UpdaterActionButton(
                  label: 'Batal',
                  isPrimary: false,
                  onPressed: () => Navigator.of(dCtx).pop(false),
                ),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: UpdaterActionButton(
                  label: 'Hapus',
                  isDanger: true,
                  onPressed: () => Navigator.of(dCtx).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyAction = true);
    try {
      await _service.deleteRelease(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rilis v${item.versionName} dihapus.')),
      );
      await _load();
    } on AppReleaseAdminException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal menghapus rilis.')));
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _openUpload() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => UploadReleaseScreen(service: _service)),
    );
    if (changed == true && mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final pad = TiketSpace.padOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final width = MediaQuery.sizeOf(context).width;

    final activeReleases = _releases
        .where((r) => r.status == AdminReleaseStatus.published)
        .toList();
    final historyReleases = _releases
        .where((r) => r.status != AdminReleaseStatus.published)
        .toList();
    final heroVersion = activeReleases.isNotEmpty
        ? 'v${activeReleases.first.versionName}'
        : (_releases.isNotEmpty ? 'v${_releases.first.versionName}' : '-');
    final activeAbisCount = activeReleases.map((e) => e.abi).toSet().length;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UpdaterBandContainer(
                showHandle: false,
                padding: EdgeInsets.fromLTRB(pad, topInset + 10.0, pad, 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TiketIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          semanticLabel: 'Kembali ke menu SPV',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 6.0,
                          ),
                          decoration: BoxDecoration(
                            color: colors.bandRaise,
                            borderRadius: BorderRadius.circular(999.0),
                            border: Border.all(
                              color: colors.bandLine,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            'Menu SPV · Khusus publisher',
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                              color: colors.onBand,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      'Rilis aplikasi',
                      style: TiketType.metaStyle(color: colors.bandCaption),
                    ),
                    const SizedBox(height: 4.0),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10.0,
                      runSpacing: 4.0,
                      children: [
                        Text(
                          heroVersion,
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: width < 375 ? 26.0 : 28.0,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            color: colors.onBand,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          '$activeAbisCount ABI aktif di lapangan',
                          style: TiketType.heroLabelStyle(
                            width,
                            color: colors.bandCaption,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildBody(
                  context,
                  colors,
                  pad,
                  activeReleases,
                  historyReleases,
                ),
              ),
              if (!_isForbidden)
                TiketBottomBar(
                  primary: UpdaterActionButton(
                    label: 'Unggah APK',
                    icon: Icons.upload_rounded,
                    onPressed: (_loading || _busyAction) ? null : _openUpload,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    TiketColors colors,
    double pad,
    List<AdminReleaseItem> activeReleases,
    List<AdminReleaseItem> historyReleases,
  ) {
    if (_loading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: colors.primary),
              const SizedBox(height: 12.0),
              Text(
                'Memuat daftar rilis...',
                style: TiketType.metaStyle(color: colors.body),
              ),
            ],
          ),
        ),
      );
    }

    if (_isForbidden) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48.0,
                height: 48.0,
                decoration: BoxDecoration(
                  color: colors.signal,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_outline_rounded, color: colors.black),
              ),
              const SizedBox(height: 14.0),
              Text(
                'Akun ini belum punya akses rilis.',
                textAlign: TextAlign.center,
                style: TiketType.sectionStyle(color: colors.ink),
              ),
              const SizedBox(height: 6.0),
              Text(
                'Hubungi admin untuk menambahkan akun Anda ke daftar publisher rilis.',
                textAlign: TextAlign.center,
                style: TiketType.metaStyle(color: colors.body),
              ),
              const SizedBox(height: 18.0),
              UpdaterActionButton(
                label: 'Kembali',
                isPrimary: false,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TiketType.rowTitleStyle(color: colors.ink),
              ),
              const SizedBox(height: 14.0),
              UpdaterActionButton(label: 'Coba lagi', onPressed: _load),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: colors.primary,
      child: ListView(
        padding: EdgeInsets.fromLTRB(pad, 18.0, pad, 24.0),
        children: [
          _SectionHeader(
            title: 'Rilis aktif saat ini',
            trailing: 'Per arsitektur',
            colors: colors,
          ),
          const SizedBox(height: 12.0),
          if (activeReleases.isEmpty)
            Container(
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: updaterSurfaceTint(context, colors),
                borderRadius: BorderRadius.circular(14.0),
                border: Border.all(color: colors.hairline),
              ),
              child: Text(
                'Belum ada rilis aktif. Unggah APK untuk memulai.',
                style: TiketType.metaStyle(color: colors.body),
              ),
            )
          else
            for (int i = 0; i < activeReleases.length; i++) ...[
              if (i > 0) const SizedBox(height: 12.0),
              _ActiveReleaseCard(
                item: activeReleases[i],
                dateText: _formatDate(activeReleases[i].publishedAt),
                busy: _busyAction,
                updatingTargets:
                    _updatingTargetReleaseId == activeReleases[i].id,
                onWidenToAll: () => _confirmWidenToAll(activeReleases[i]),
                onRollback: () => _confirmRollback(activeReleases[i]),
              ),
            ],
          const SizedBox(height: 24.0),
          _SectionHeader(
            title: 'Riwayat rilis',
            trailing: '${historyReleases.length} entri',
            colors: colors,
          ),
          const SizedBox(height: 4.0),
          if (historyReleases.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14.0),
              child: Text(
                'Belum ada riwayat rilis lainnya.',
                style: TiketType.metaStyle(color: colors.body),
              ),
            )
          else
            for (int i = 0; i < historyReleases.length; i++) ...[
              _HistoryReleaseRow(
                item: historyReleases[i],
                dateText: _formatDate(
                  historyReleases[i].publishedAt ??
                      historyReleases[i].createdAt,
                ),
                busy: _busyAction,
                onPublish: () => _confirmPublishDraft(historyReleases[i]),
                onDeleteDraft: () => _deleteDraft(historyReleases[i]),
                onDeleteRelease: () =>
                    _confirmDeleteRelease(historyReleases[i]),
              ),
              if (i < historyReleases.length - 1)
                Divider(height: 1.0, color: colors.hairline),
            ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String trailing;
  final TiketColors colors;

  const _SectionHeader({
    required this.title,
    required this.trailing,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(title, style: TiketType.sectionStyle(color: colors.ink)),
        Text(trailing, style: TiketType.metaStyle(color: colors.body)),
      ],
    );
  }
}

class _ActiveReleaseCard extends StatelessWidget {
  final AdminReleaseItem item;
  final String dateText;
  final bool busy;
  final bool updatingTargets;
  final VoidCallback onWidenToAll;
  final VoidCallback onRollback;

  const _ActiveReleaseCard({
    required this.item,
    required this.dateText,
    required this.busy,
    required this.updatingTargets,
    required this.onWidenToAll,
    required this.onRollback,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showWidenAction =
        item.status == AdminReleaseStatus.published && !item.isAllBranches;

    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: updaterSurfaceTint(context, colors),
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9.0,
                        vertical: 3.0,
                      ),
                      decoration: BoxDecoration(
                        color: colors.band,
                        borderRadius: BorderRadius.circular(8.0),
                        border: isDark
                            ? Border.all(color: colors.bandLine)
                            : null,
                      ),
                      child: Text(
                        AppReleaseAdminService.abiShortLabel(item.abi),
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 12.0,
                          fontWeight: FontWeight.w800,
                          color: colors.onBand,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      'v${item.versionName}',
                      style: TextStyle(
                        fontFamily: TiketType.fontFamily,
                        fontSize: 17.0,
                        fontWeight: FontWeight.w800,
                        color: colors.ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6.0,
                  runSpacing: 6.0,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StatusPill(status: item.status),
                    _FlagPill(mandatory: item.mandatory),
                    _TargetCabangBadge(targetCabang: item.targetCabang),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            '${AppUpdateService.formatMb(item.sizeBytes)} · $dateText · Oleh ${item.createdBy}',
            style: TiketType.metaStyle(color: colors.body),
          ),
          if (item.changelog.trim().isNotEmpty) ...[
            const SizedBox(height: 8.0),
            Text(
              item.changelog.trim(),
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: 13.0,
                height: 18.0 / 13.0,
                color: colors.ink,
              ),
            ),
          ],
          const SizedBox(height: 12.0),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (updatingTargets)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16.0,
                        height: 16.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        'Memperbarui...',
                        style: TiketType.metaStyle(color: colors.body),
                      ),
                    ],
                  )
                else if (showWidenAction)
                  TextButton(
                    onPressed: busy ? null : onWidenToAll,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48.0, 44.0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14.0,
                        vertical: 10.0,
                      ),
                      foregroundColor: colors.primary,
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontFamily: TiketType.fontFamily,
                        fontSize: 13.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Rilis ke semua cabang'),
                  ),
                _OutlineSmallButton(
                  label: 'Tarik rilis',
                  onPressed: busy ? null : onRollback,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            'Rilis aktif tidak bisa dihapus. Tarik dulu atau terbitkan versi baru.',
            style: TiketType.metaStyle(color: colors.body),
          ),
        ],
      ),
    );
  }
}

class _HistoryReleaseRow extends StatelessWidget {
  final AdminReleaseItem item;
  final String dateText;
  final bool busy;
  final VoidCallback onPublish;
  final VoidCallback onDeleteDraft;
  final VoidCallback onDeleteRelease;

  const _HistoryReleaseRow({
    required this.item,
    required this.dateText,
    required this.busy,
    required this.onPublish,
    required this.onDeleteDraft,
    required this.onDeleteRelease,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final isDraft = item.status == AdminReleaseStatus.draft;
    final canDeleteRelease =
        item.status == AdminReleaseStatus.rolledBack ||
        item.status == AdminReleaseStatus.archived;
    final shownDate = isDraft ? 'Belum terbit' : dateText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 8.0,
              runSpacing: 6.0,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'v${item.versionName}',
                      style: TextStyle(
                        fontFamily: TiketType.fontFamily,
                        fontSize: 15.0,
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 2.0,
                      ),
                      decoration: BoxDecoration(
                        color: colors.soft,
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      child: Text(
                        AppReleaseAdminService.abiShortLabel(item.abi),
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 12.0,
                          fontWeight: FontWeight.w700,
                          color: colors.body,
                        ),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6.0,
                  runSpacing: 6.0,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StatusPill(status: item.status),
                    _FlagPill(mandatory: item.mandatory),
                    _TargetCabangBadge(targetCabang: item.targetCabang),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6.0),
          Text(
            '${AppUpdateService.formatMb(item.sizeBytes)} · $shownDate · Oleh ${item.createdBy}',
            style: TiketType.metaStyle(color: colors.body),
          ),
          if (item.changelog.trim().isNotEmpty) ...[
            const SizedBox(height: 6.0),
            Text(
              item.changelog.trim(),
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: 13.0,
                height: 18.0 / 13.0,
                color: colors.ink,
              ),
            ),
          ],
          if (isDraft) ...[
            const SizedBox(height: 8.0),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                _OutlineSmallButton(
                  label: 'Terbitkan',
                  onPressed: busy ? null : onPublish,
                ),
                _OutlineSmallButton(
                  label: 'Hapus draf',
                  onPressed: busy ? null : onDeleteDraft,
                ),
              ],
            ),
          ] else if (canDeleteRelease) ...[
            const SizedBox(height: 8.0),
            _OutlineSmallButton(
              label: 'Hapus rilis',
              color: colors.danger,
              onPressed: busy ? null : onDeleteRelease,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final AdminReleaseStatus status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final Color bg;
    final Color fg;
    final IconData icon;
    Border? border;

    switch (status) {
      case AdminReleaseStatus.published:
        bg = colors.ok;
        fg = colors.white;
        icon = Icons.check_rounded;
      case AdminReleaseStatus.draft:
        bg = colors.soft;
        fg = colors.ink;
        icon = Icons.radio_button_unchecked_rounded;
        border = Border.all(color: colors.mute);
      case AdminReleaseStatus.rolledBack:
        bg = colors.signal;
        fg = colors.black;
        icon = Icons.undo_rounded;
      case AdminReleaseStatus.archived:
        bg = colors.soft;
        fg = colors.body;
        icon = Icons.inventory_2_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999.0),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.0, color: fg),
          const SizedBox(width: 5.0),
          Text(
            status.label,
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 12.0,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlagPill extends StatelessWidget {
  final bool mandatory;

  const _FlagPill({required this.mandatory});

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: mandatory ? colors.dangerTint : colors.soft,
        borderRadius: BorderRadius.circular(999.0),
      ),
      child: Text(
        mandatory ? 'Wajib' : 'Opsional',
        style: TextStyle(
          fontFamily: TiketType.fontFamily,
          fontSize: 12.0,
          fontWeight: FontWeight.w700,
          color: mandatory ? colors.danger : colors.body,
        ),
      ),
    );
  }
}

class _TargetCabangBadge extends StatelessWidget {
  final List<String>? targetCabang;

  const _TargetCabangBadge({required this.targetCabang});

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final isAll = targetCabang == null || targetCabang!.isEmpty;
    final label = cabangLabel(targetCabang);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: isAll ? colors.soft : colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999.0),
        border: isAll ? null : Border.all(color: colors.primary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isAll) ...[
            Icon(Icons.location_on_outlined, size: 12.0, color: colors.primary),
            const SizedBox(width: 4.0),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 12.0,
              fontWeight: FontWeight.w700,
              color: isAll ? colors.body : colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlineSmallButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  const _OutlineSmallButton({
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final effectiveColor = color ?? colors.primary;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48.0, minWidth: 112.0),
      child: Center(
        widthFactor: 1.0,
        child: SizedBox(
          height: 44.0,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(112.0, 44.0),
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              foregroundColor: effectiveColor,
              side: BorderSide(color: effectiveColor, width: 1.5),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: 13.0,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
