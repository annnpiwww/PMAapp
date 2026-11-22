import 'package:flutter/material.dart';

import '../../../core/constants/tiket_colors.dart';
import '../../../data/services/app_update_service.dart';
import '../updater_controller.dart';
import 'updater_ticket_widgets.dart';

Future<void> showUpdaterSheet(
  BuildContext context, {
  required UpdaterController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => UpdaterSheet(controller: controller),
  );
}

class UpdaterSheet extends StatefulWidget {
  final UpdaterController controller;
  final bool ownsController;

  const UpdaterSheet({
    super.key,
    required this.controller,
    this.ownsController = false,
  });

  @override
  State<UpdaterSheet> createState() => _UpdaterSheetState();
}

class _UpdaterSheetState extends State<UpdaterSheet>
    with SingleTickerProviderStateMixin {
  bool _notesExpanded = true;
  late final AnimationController _enterController;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _enterController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _enterController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _enterController.dispose();
    if (widget.ownsController) {
      widget.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _handleLater() async {
    await widget.controller.dismissLater();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleCancelDownload() async {
    await widget.controller.cancelDownload();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final pad = TiketSpace.padOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final disableAnim = MediaQuery.disableAnimationsOf(context);

    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, _enterController]),
      builder: (context, _) {
        final state = widget.controller.state;
        final t = disableAnim
            ? 1.0
            : kUpdaterEaseOut.transform(_enterController.value);

        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600.0),
            child: Opacity(
              opacity: 0.92 + 0.08 * t,
              child: Transform.translate(
                offset: Offset(0, 16.0 * (1.0 - t)),
                child: Material(
                  color: colors.canvas,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24.0),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildBand(context, colors, state),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            pad,
                            18.0,
                            pad,
                            20.0 + bottomInset,
                          ),
                          child: _buildBody(context, colors, state),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBand(
    BuildContext context,
    TiketColors colors,
    UpdaterState state,
  ) {
    final result = state.checkResult;
    final release = result.release;
    final width = MediaQuery.sizeOf(context).width;
    final titleStyle = TiketType.screenTitleStyle(width, color: colors.onBand);
    final subStyle = TiketType.metaStyle(color: colors.bandCaption);

    switch (state.phase) {
      case UpdaterPhase.available:
        return UpdaterBandContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pembaruan aplikasi tersedia', style: titleStyle),
              const SizedBox(height: 4.0),
              Text(
                'Siap diunduh sekarang atau tunda sampai shift selesai',
                style: subStyle,
              ),
              const SizedBox(height: 14.0),
              UpdaterVersionTicket(
                currentVersion: result.currentVersion,
                newVersion: release.versionName,
                trailing: UpdaterTicketPill(
                  label: AppUpdateService.formatMb(release.sizeBytes),
                ),
              ),
            ],
          ),
        );

      case UpdaterPhase.downloading:
      case UpdaterPhase.verifying:
        final p = state.progress;
        final received = p?.received ?? 0;
        final total = (p?.total ?? 0) > 0 ? p!.total : release.sizeBytes;
        final percent = state.phase == UpdaterPhase.verifying
            ? 100
            : (p?.percent ?? 0);
        final fraction = state.phase == UpdaterPhase.verifying
            ? 1.0
            : (p?.fraction ?? 0.0);

        return UpdaterBandContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mengunduh pembaruan', style: titleStyle),
              const SizedBox(height: 4.0),
              Text(
                'Tetap di layar ini sampai unduhan selesai',
                style: subStyle,
              ),
              const SizedBox(height: 14.0),
              UpdaterProgressTicket(
                currentVersion: result.currentVersion,
                newVersion: release.versionName,
                percent: percent,
                fraction: fraction,
                leftMeta: AppUpdateService.formatMbProgress(received, total),
                rightMeta: state.phase == UpdaterPhase.verifying
                    ? 'Memeriksa file'
                    : AppUpdateService.formatEta(p?.eta),
              ),
            ],
          ),
        );

      case UpdaterPhase.needsPermission:
        return UpdaterBandContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const UpdaterBandBadge(kind: UpdaterBandBadgeKind.shield),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Izinkan pasang pembaruan', style: titleStyle),
                        const SizedBox(height: 4.0),
                        Text(
                          'Cukup dilakukan sekali saja di HP ini',
                          style: subStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14.0),
              UpdaterVersionTicket(
                currentVersion: result.currentVersion,
                newVersion: release.versionName,
                trailing: UpdaterTicketPill(
                  label: 'File aman',
                  icon: Icons.check_rounded,
                  backgroundColor: colors.ok,
                  foregroundColor: colors.white,
                  borderColor: colors.white,
                ),
              ),
            ],
          ),
        );

      case UpdaterPhase.ready:
        return UpdaterBandContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const UpdaterBandBadge(kind: UpdaterBandBadgeKind.ok),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Siap dipasang', style: titleStyle),
                        const SizedBox(height: 4.0),
                        Text(
                          'Unduhan dan pemeriksaan file sudah selesai',
                          style: subStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14.0),
              UpdaterVersionTicket(
                currentVersion: result.currentVersion,
                newVersion: release.versionName,
                trailing: UpdaterTicketPill(
                  label: AppUpdateService.formatMb(release.sizeBytes),
                  backgroundColor: colors.ok,
                  foregroundColor: colors.white,
                  borderColor: colors.white,
                ),
              ),
            ],
          ),
        );

      case UpdaterPhase.error:
        return _buildErrorBand(context, colors, state, titleStyle, subStyle);
    }
  }

  Widget _buildErrorBand(
    BuildContext context,
    TiketColors colors,
    UpdaterState state,
    TextStyle titleStyle,
    TextStyle subStyle,
  ) {
    final result = state.checkResult;
    final release = result.release;
    final kind = state.errorKind ?? AppUpdateErrorKind.interrupted;

    switch (kind) {
      case AppUpdateErrorKind.noInternet:
        return UpdaterBandContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const UpdaterBandBadge(kind: UpdaterBandBadgeKind.signal),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tidak ada koneksi internet', style: titleStyle),
                        const SizedBox(height: 4.0),
                        Text(
                          'Gagal memeriksa atau memulai unduhan',
                          style: subStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              UpdaterVersionTicket(
                currentVersion: result.currentVersion,
                newVersion: release.versionName,
                newFontSize: 16.0,
                trailing: UpdaterTicketPill(
                  label: 'Offline',
                  icon: Icons.wifi_off_rounded,
                  backgroundColor: colors.signal,
                  foregroundColor: colors.black,
                  borderColor: colors.signal,
                ),
              ),
            ],
          ),
        );

      case AppUpdateErrorKind.interrupted:
        final received = state.errorReceivedBytes;
        final total = state.errorTotalBytes > 0
            ? state.errorTotalBytes
            : release.sizeBytes;
        final remaining = (total - received).clamp(0, total);
        final percent = total > 0 ? ((received / total) * 100).round() : 0;
        final fraction = total > 0 ? (received / total) : 0.0;

        return UpdaterBandContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const UpdaterBandBadge(kind: UpdaterBandBadgeKind.signal),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Unduhan terputus', style: titleStyle),
                        const SizedBox(height: 4.0),
                        Text(
                          'Progres tersimpan, tidak perlu mengulang dari awal',
                          style: subStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              UpdaterProgressTicket(
                currentVersion: result.currentVersion,
                newVersion: release.versionName,
                percent: percent,
                fraction: fraction,
                leftMeta:
                    '${AppUpdateService.formatMbProgress(received, total)} tersimpan',
                rightMeta: 'Sisa ${AppUpdateService.formatMb(remaining)}',
                isInterrupted: true,
              ),
            ],
          ),
        );

      case AppUpdateErrorKind.corruptFile:
        return UpdaterBandContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const UpdaterBandBadge(kind: UpdaterBandBadgeKind.danger),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('File pembaruan rusak', style: titleStyle),
                        const SizedBox(height: 4.0),
                        Text(
                          'Pemeriksaan keamanan file tidak cocok',
                          style: subStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              UpdaterVersionTicket(
                currentVersion: result.currentVersion,
                newVersion: release.versionName,
                newFontSize: 16.0,
                trailing: UpdaterTicketPill(
                  label: 'File rusak',
                  icon: Icons.close_rounded,
                  backgroundColor: colors.dangerTint,
                  foregroundColor: colors.danger,
                  borderColor: colors.danger,
                ),
              ),
            ],
          ),
        );

      case AppUpdateErrorKind.storageFull:
        return UpdaterBandContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const UpdaterBandBadge(kind: UpdaterBandBadgeKind.signal),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Penyimpanan penuh', style: titleStyle),
                        const SizedBox(height: 4.0),
                        Text(
                          'Ruang kosong di HP tidak mencukupi',
                          style: subStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              UpdaterVersionTicket(
                currentVersion: result.currentVersion,
                newVersion: release.versionName,
                newFontSize: 16.0,
                trailing: UpdaterTicketPill(
                  label:
                      'Butuh ${AppUpdateService.formatMb(release.sizeBytes)}',
                  backgroundColor: colors.signal,
                  foregroundColor: colors.black,
                  borderColor: colors.signal,
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildBody(
    BuildContext context,
    TiketColors colors,
    UpdaterState state,
  ) {
    final release = state.checkResult.release;
    final bodyStyle = TextStyle(
      fontFamily: TiketType.fontFamily,
      fontSize: 14.0,
      height: 20.0 / 14.0,
      color: colors.body,
    );

    switch (state.phase) {
      case UpdaterPhase.available:
        final notesLines = release.changelog
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Data tugas dan laporan foto Anda tetap tersimpan selama proses pembaruan.',
              style: bodyStyle,
            ),
            const SizedBox(height: 14.0),
            if (notesLines.isNotEmpty) ...[
              Container(
                decoration: BoxDecoration(
                  color: updaterSurfaceTint(context, colors),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: colors.hairline),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      button: true,
                      toggled: _notesExpanded,
                      label: 'Catatan rilis',
                      child: InkWell(
                        onTap: () =>
                            setState(() => _notesExpanded = !_notesExpanded),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48.0),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14.0,
                              vertical: 12.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Catatan rilis',
                                  style: TextStyle(
                                    fontFamily: TiketType.fontFamily,
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w700,
                                    color: colors.ink,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _notesExpanded ? 'Sembunyikan' : 'Lihat',
                                      style: TextStyle(
                                        fontFamily: TiketType.fontFamily,
                                        fontSize: 13.0,
                                        fontWeight: FontWeight.w600,
                                        color: colors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 4.0),
                                    Icon(
                                      _notesExpanded
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      size: 18.0,
                                      color: colors.primary,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_notesExpanded) ...[
                      Divider(height: 1.0, color: colors.hairline),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          14.0,
                          12.0,
                          14.0,
                          14.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (int i = 0; i < notesLines.length; i++) ...[
                              if (i > 0) const SizedBox(height: 8.0),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 6.0,
                                    height: 6.0,
                                    margin: const EdgeInsets.only(top: 6.5),
                                    decoration: BoxDecoration(
                                      color: colors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 9.0),
                                  Expanded(
                                    child: Text(
                                      notesLines[i],
                                      style: TextStyle(
                                        fontFamily: TiketType.fontFamily,
                                        fontSize: 13.0,
                                        height: 19.0 / 13.0,
                                        color: colors.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18.0),
            ],
            UpdaterActionButton(
              label: 'Perbarui sekarang',
              onPressed: () => widget.controller.startDownload(),
            ),
            const SizedBox(height: 10.0),
            UpdaterActionButton(
              label: 'Nanti',
              isPrimary: false,
              onPressed: _handleLater,
            ),
          ],
        );

      case UpdaterPhase.downloading:
      case UpdaterPhase.verifying:
        final p = state.progress;
        final received = p?.received ?? 0;
        final total = (p?.total ?? 0) > 0 ? p!.total : release.sizeBytes;
        final percent = state.phase == UpdaterPhase.verifying
            ? 100
            : (p?.percent ?? 0);
        final isVerifying = state.phase == UpdaterPhase.verifying;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UpdaterStatsRow(progress: p),
            const SizedBox(height: 16.0),
            UpdaterStepItem(
              number: 1,
              title: 'Mengunduh file pembaruan',
              subtitle:
                  '${AppUpdateService.formatMbProgress(received, total)} terunduh ($percent%)',
              status: isVerifying
                  ? UpdaterStepStatus.done
                  : UpdaterStepStatus.active,
            ),
            UpdaterStepItem(
              number: 2,
              title: 'Memeriksa keaslian file',
              subtitle: isVerifying
                  ? 'Sedang memverifikasi keutuhan file...'
                  : 'Berjalan otomatis setelah unduhan selesai',
              status: isVerifying
                  ? UpdaterStepStatus.active
                  : UpdaterStepStatus.waiting,
              showDivider: false,
            ),
            const SizedBox(height: 12.0),
            Text(
              'Jika dibatalkan sekarang, progres tersimpan dan bisa dilanjutkan nanti.',
              style: TiketType.metaStyle(color: colors.body),
            ),
            const SizedBox(height: 16.0),
            UpdaterActionButton(
              label: 'Batalkan',
              isPrimary: false,
              onPressed: _handleCancelDownload,
            ),
          ],
        );

      case UpdaterPhase.needsPermission:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Android meminta izin sebelum PMApp bisa memasang pembaruan langsung tanpa lewat Play Store.',
              style: bodyStyle,
            ),
            const SizedBox(height: 14.0),
            const UpdaterPermissionIllustration(),
            const SizedBox(height: 16.0),
            _NumberedInstruction(
              number: 1,
              prefix: 'Ketuk ',
              bold: 'Buka pengaturan',
              suffix: ' di bawah.',
              colors: colors,
            ),
            const SizedBox(height: 10.0),
            _NumberedInstruction(
              number: 2,
              prefix: 'Aktifkan tombol ',
              bold: 'Izinkan dari sumber ini',
              suffix: '.',
              colors: colors,
            ),
            const SizedBox(height: 10.0),
            _NumberedInstruction(
              number: 3,
              prefix: 'Kembali ke PMApp lalu ketuk ',
              bold: 'Pasang',
              suffix: '.',
              colors: colors,
            ),
            const SizedBox(height: 18.0),
            UpdaterActionButton(
              label: 'Buka pengaturan',
              onPressed: () => widget.controller.openPermissionSettings(),
            ),
            const SizedBox(height: 10.0),
            UpdaterActionButton(
              label: 'Nanti',
              isPrimary: false,
              onPressed: _handleLater,
            ),
          ],
        );

      case UpdaterPhase.ready:
        final installStatus = state.installStatus;
        final coolingDown = widget.controller.installButtonCoolingDown;

        final String heading;
        final String bodyText;
        final String primaryLabel;
        final VoidCallback? primaryAction;
        final bool isFailure = installStatus == InstallStatus.failed;
        final bool isWarning = installStatus == InstallStatus.notInstalled;

        switch (installStatus) {
          case InstallStatus.idle:
            heading = 'Keaslian file terverifikasi';
            bodyText =
                'Setelah mengetuk tombol, pilih Pasang pada dialog sistem Android.';
            primaryLabel = 'Pasang sekarang';
            primaryAction = () => widget.controller.install();
          case InstallStatus.launching:
            heading = 'Keaslian file terverifikasi';
            bodyText =
                'Setelah mengetuk tombol, pilih Pasang pada dialog sistem Android.';
            primaryLabel = coolingDown
                ? 'Membuka pemasang Android...'
                : 'Buka lagi';
            primaryAction = coolingDown
                ? null
                : () => widget.controller.install();
          case InstallStatus.notInstalled:
            heading = 'Pemasangan belum selesai';
            bodyText =
                'Versi baru belum terpasang. File sudah terunduh, tidak perlu unduh ulang.';
            primaryLabel = 'Pasang lagi';
            primaryAction = () => widget.controller.install();
          case InstallStatus.failed:
            heading = 'Pemasangan belum berhasil';
            if (state.installFailureMissingFile) {
              bodyText =
                  'File update tidak ditemukan. Unduh ulang untuk melanjutkan.';
              primaryLabel = 'Unduh ulang';
              primaryAction = () => widget.controller.redownload();
            } else {
              bodyText = 'Pemasang Android tidak bisa dibuka.';
              primaryLabel = 'Pasang lagi';
              primaryAction = () => widget.controller.install();
            }
        }

        final Color badgeBg = isFailure
            ? colors.danger
            : (isWarning ? colors.signal : colors.ok);
        final Color badgeFg = isWarning ? colors.black : colors.white;
        final IconData badgeIcon = isFailure
            ? Icons.close_rounded
            : (isWarning ? Icons.priority_high_rounded : Icons.check_rounded);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14.0,
                vertical: 12.0,
              ),
              decoration: BoxDecoration(
                color: updaterSurfaceTint(context, colors),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: isFailure
                      ? colors.danger
                      : (isWarning ? colors.signal : colors.hairline),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 22.0,
                    height: 22.0,
                    decoration: BoxDecoration(
                      color: badgeBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(badgeIcon, size: 14.0, color: badgeFg),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          heading,
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 14.0,
                            fontWeight: FontWeight.w700,
                            color: colors.ink,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          bodyText,
                          style: TextStyle(
                            fontFamily: TiketType.fontFamily,
                            fontSize: 12.0,
                            color: colors.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14.0),
            UpdaterActionButton(label: primaryLabel, onPressed: primaryAction),
            if (installStatus == InstallStatus.launching ||
                installStatus == InstallStatus.notInstalled) ...[
              const SizedBox(height: 8.0),
              Text(
                'Ketuk Pasang atau Perbarui di layar Android, jangan ditutup sampai selesai.',
                style: TiketType.metaStyle(color: colors.body),
              ),
            ],
            const SizedBox(height: 10.0),
            UpdaterActionButton(
              label: 'Nanti',
              isPrimary: false,
              onPressed: _handleLater,
            ),
          ],
        );

      case UpdaterPhase.error:
        final kind = state.errorKind ?? AppUpdateErrorKind.interrupted;
        final String copy;
        final String primaryLabel;
        final String secondaryLabel;
        final VoidCallback primaryAction;
        final VoidCallback secondaryAction;

        switch (kind) {
          case AppUpdateErrorKind.noInternet:
            copy =
                'Pastikan data seluler atau Wi-Fi aktif lalu ketuk tombol di bawah untuk mengulang.';
            primaryLabel = 'Coba lagi';
            secondaryLabel = 'Nanti';
            primaryAction = () => widget.controller.startDownload();
            secondaryAction = _handleLater;
          case AppUpdateErrorKind.interrupted:
            copy =
                'Koneksi terputus di tengah pengunduhan. Lanjutkan dari bagian terakhir yang tersimpan.';
            primaryLabel = 'Lanjutkan unduhan';
            secondaryLabel = 'Batalkan';
            primaryAction = () => widget.controller.startDownload();
            secondaryAction = _handleCancelDownload;
          case AppUpdateErrorKind.corruptFile:
            copy =
                'File yang terunduh tidak utuh sehingga tidak bisa dipasang. Unduh ulang dari awal agar aman.';
            primaryLabel = 'Unduh ulang';
            secondaryLabel = 'Nanti';
            primaryAction = () =>
                widget.controller.startDownload(resetPartial: true);
            secondaryAction = _handleLater;
          case AppUpdateErrorKind.storageFull:
            copy =
                'Kosongkan sedikit ruang di galeri atau file unduhan, lalu coba unduh pembaruan lagi.';
            primaryLabel = 'Coba lagi';
            secondaryLabel = 'Nanti';
            primaryAction = () => widget.controller.startDownload();
            secondaryAction = _handleLater;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(copy, style: bodyStyle),
            const SizedBox(height: 14.0),
            UpdaterActionButton(label: primaryLabel, onPressed: primaryAction),
            const SizedBox(height: 10.0),
            UpdaterActionButton(
              label: secondaryLabel,
              isPrimary: false,
              onPressed: secondaryAction,
            ),
          ],
        );
    }
  }
}

class _NumberedInstruction extends StatelessWidget {
  final int number;
  final String prefix;
  final String bold;
  final String suffix;
  final TiketColors colors;

  const _NumberedInstruction({
    required this.number,
    required this.prefix,
    required this.bold,
    required this.suffix,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24.0,
          height: 24.0,
          decoration: BoxDecoration(color: colors.soft, shape: BoxShape.circle),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: 12.0,
                fontWeight: FontWeight.w800,
                color: colors.ink,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10.0),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: 14.0,
                height: 20.0 / 14.0,
                color: colors.ink,
              ),
              children: [
                TextSpan(text: prefix),
                TextSpan(
                  text: bold,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: suffix),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
