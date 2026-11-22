import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/tiket_colors.dart';
import '../../../data/services/app_update_service.dart';
import '../updater_controller.dart';
import '../widgets/updater_ticket_widgets.dart';

class MandatoryUpdateScreen extends StatefulWidget {
  final UpdaterController controller;
  final bool autoStartDownload;
  final bool ownsController;

  const MandatoryUpdateScreen({
    super.key,
    required this.controller,
    this.autoStartDownload = true,
    this.ownsController = false,
  });

  @override
  State<MandatoryUpdateScreen> createState() => _MandatoryUpdateScreenState();
}

class _MandatoryUpdateScreenState extends State<MandatoryUpdateScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoStartDownload &&
        widget.controller.state.phase == UpdaterPhase.available) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(widget.controller.startDownload());
        }
      });
    }
  }

  @override
  void dispose() {
    if (widget.ownsController) {
      widget.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final pad = TiketSpace.padOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final width = MediaQuery.sizeOf(context).width;

    return PopScope(
      canPop: false,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final state = widget.controller.state;
          final result = state.checkResult;
          final release = result.release;
          final p = state.progress;
          final received = state.phase == UpdaterPhase.error
              ? state.errorReceivedBytes
              : (p?.received ?? 0);
          final total = release.sizeBytes;
          final percent =
              state.phase == UpdaterPhase.verifying ||
                  state.phase == UpdaterPhase.needsPermission ||
                  state.phase == UpdaterPhase.ready
              ? 100
              : (total > 0
                    ? ((received / total) * 100).round().clamp(0, 100)
                    : (p?.percent ?? 0));
          final fraction = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;

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
                      padding: EdgeInsets.fromLTRB(
                        pad,
                        topInset + 14.0,
                        pad,
                        20.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              UpdaterBandBadge(
                                kind: state.phase == UpdaterPhase.ready
                                    ? UpdaterBandBadgeKind.ok
                                    : (state.phase == UpdaterPhase.error &&
                                              state.errorKind ==
                                                  AppUpdateErrorKind.corruptFile
                                          ? UpdaterBandBadgeKind.danger
                                          : UpdaterBandBadgeKind.signal),
                              ),
                              const SizedBox(width: 12.0),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pembaruan wajib diperlukan',
                                      style: TiketType.screenTitleStyle(
                                        width,
                                        color: colors.onBand,
                                      ),
                                    ),
                                    const SizedBox(height: 6.0),
                                    Text(
                                      'Versi ini sudah tidak didukung. Perbarui untuk lanjut bekerja.',
                                      style: TextStyle(
                                        fontFamily: TiketType.fontFamily,
                                        fontSize: 14.0,
                                        height: 20.0 / 14.0,
                                        fontWeight: FontWeight.w500,
                                        color: colors.onBand,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          UpdaterProgressTicket(
                            currentVersion: result.currentVersion,
                            newVersion: release.versionName,
                            percent: percent,
                            fraction:
                                state.phase == UpdaterPhase.verifying ||
                                    state.phase ==
                                        UpdaterPhase.needsPermission ||
                                    state.phase == UpdaterPhase.ready
                                ? 1.0
                                : fraction,
                            leftMeta: AppUpdateService.formatMbProgress(
                              received,
                              total,
                            ),
                            rightMeta: _ticketRightMeta(state),
                            isInterrupted: state.phase == UpdaterPhase.error,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(pad, 18.0, pad, 18.0),
                        child: _buildBody(context, colors, state),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: colors.bar,
                        border: Border(top: BorderSide(color: colors.hairline)),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        pad,
                        12.0,
                        pad,
                        14.0 + bottomInset,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildBottomAction(state, percent),
                          const SizedBox(height: 8.0),
                          Text(
                            'Pembaruan wajib tidak bisa dilewati',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                              color: colors.signalText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _ticketRightMeta(UpdaterState state) {
    switch (state.phase) {
      case UpdaterPhase.available:
        return AppUpdateService.formatMb(state.checkResult.release.sizeBytes);
      case UpdaterPhase.downloading:
        return AppUpdateService.formatEta(state.progress?.eta);
      case UpdaterPhase.verifying:
        return 'Memeriksa file';
      case UpdaterPhase.needsPermission:
        return 'Perlu izin pasang';
      case UpdaterPhase.ready:
        return 'Siap dipasang';
      case UpdaterPhase.error:
        switch (state.errorKind ?? AppUpdateErrorKind.interrupted) {
          case AppUpdateErrorKind.noInternet:
            return 'Offline';
          case AppUpdateErrorKind.interrupted:
            return 'Terputus';
          case AppUpdateErrorKind.corruptFile:
            return 'File rusak';
          case AppUpdateErrorKind.storageFull:
            return 'Penyimpanan penuh';
        }
    }
  }

  Widget _buildBody(
    BuildContext context,
    TiketColors colors,
    UpdaterState state,
  ) {
    final release = state.checkResult.release;
    final p = state.progress;
    final received = state.phase == UpdaterPhase.error
        ? state.errorReceivedBytes
        : (p?.received ?? 0);
    final total = release.sizeBytes;
    final percent = total > 0
        ? ((received / total) * 100).round().clamp(0, 100)
        : 0;

    final step1Status = switch (state.phase) {
      UpdaterPhase.verifying ||
      UpdaterPhase.needsPermission ||
      UpdaterPhase.ready => UpdaterStepStatus.done,
      UpdaterPhase.downloading ||
      UpdaterPhase.available => UpdaterStepStatus.active,
      UpdaterPhase.error =>
        state.errorKind == AppUpdateErrorKind.corruptFile
            ? UpdaterStepStatus.waiting
            : UpdaterStepStatus.active,
    };

    final step2Status = switch (state.phase) {
      UpdaterPhase.verifying => UpdaterStepStatus.active,
      UpdaterPhase.needsPermission ||
      UpdaterPhase.ready => UpdaterStepStatus.done,
      _ => UpdaterStepStatus.waiting,
    };

    final step3Status = switch (state.phase) {
      UpdaterPhase.needsPermission ||
      UpdaterPhase.ready => UpdaterStepStatus.active,
      _ => UpdaterStepStatus.waiting,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.phase == UpdaterPhase.needsPermission) ...[
          Text(
            'Android meminta izin sebelum PMApp bisa memasang pembaruan langsung tanpa lewat Play Store.',
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 14.0,
              height: 20.0 / 14.0,
              color: colors.body,
            ),
          ),
          const SizedBox(height: 14.0),
          const UpdaterPermissionIllustration(),
          const SizedBox(height: 16.0),
        ] else if (state.phase == UpdaterPhase.error) ...[
          Container(
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: updaterSurfaceTint(context, colors),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: state.errorKind == AppUpdateErrorKind.corruptFile
                    ? colors.danger
                    : colors.signal,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _errorTitle(state.errorKind),
                  style: TextStyle(
                    fontFamily: TiketType.fontFamily,
                    fontSize: 15.0,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  _errorDetail(state.errorKind),
                  style: TextStyle(
                    fontFamily: TiketType.fontFamily,
                    fontSize: 13.0,
                    height: 19.0 / 13.0,
                    color: colors.body,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16.0),
        ] else ...[
          UpdaterStatsRow(progress: p),
          const SizedBox(height: 16.0),
        ],
        Text(
          'Tahap pembaruan',
          style: TiketType.sectionStyle(color: colors.ink),
        ),
        const SizedBox(height: 4.0),
        UpdaterStepItem(
          number: 1,
          title: 'Mengunduh pembaruan wajib',
          subtitle:
              '${AppUpdateService.formatMbProgress(received, total)} selesai ($percent%)',
          status: step1Status,
        ),
        UpdaterStepItem(
          number: 2,
          title: 'Memeriksa keaslian file',
          subtitle: state.phase == UpdaterPhase.verifying
              ? 'Sedang memverifikasi keutuhan file...'
              : 'Otomatis setelah unduhan penuh',
          status: step2Status,
        ),
        UpdaterStepItem(
          number: 3,
          title: 'Pasang versi terbaru',
          subtitle: 'Tugas di perangkat tetap aman',
          status: step3Status,
          showDivider: false,
        ),
        const SizedBox(height: 12.0),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: updaterSurfaceTint(context, colors),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: colors.hairline),
          ),
          child: Text(
            'PMApp akan membuka dialog pasang otomatis setelah verifikasi selesai. Jika unduhan belum mulai, tombol utama di bawah berfungsi untuk memulai ulang.',
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 13.0,
              height: 19.0 / 13.0,
              color: colors.body,
            ),
          ),
        ),
      ],
    );
  }

  String _errorTitle(AppUpdateErrorKind? kind) {
    switch (kind ?? AppUpdateErrorKind.interrupted) {
      case AppUpdateErrorKind.noInternet:
        return 'Tidak ada koneksi internet';
      case AppUpdateErrorKind.interrupted:
        return 'Unduhan terputus';
      case AppUpdateErrorKind.corruptFile:
        return 'File pembaruan rusak';
      case AppUpdateErrorKind.storageFull:
        return 'Penyimpanan penuh';
    }
  }

  String _errorDetail(AppUpdateErrorKind? kind) {
    switch (kind ?? AppUpdateErrorKind.interrupted) {
      case AppUpdateErrorKind.noInternet:
        return 'Pastikan data seluler atau Wi-Fi aktif lalu ketuk tombol di bawah untuk mengulang.';
      case AppUpdateErrorKind.interrupted:
        return 'Koneksi terputus di tengah pengunduhan. Lanjutkan dari bagian terakhir yang tersimpan.';
      case AppUpdateErrorKind.corruptFile:
        return 'File yang terunduh tidak utuh sehingga tidak bisa dipasang. Unduh ulang dari awal agar aman.';
      case AppUpdateErrorKind.storageFull:
        return 'Kosongkan sedikit ruang di galeri atau file unduhan, lalu coba unduh pembaruan lagi.';
    }
  }

  Widget _buildBottomAction(UpdaterState state, int percent) {
    switch (state.phase) {
      case UpdaterPhase.available:
        return UpdaterActionButton(
          label: 'Perbarui sekarang',
          onPressed: () => widget.controller.startDownload(),
        );
      case UpdaterPhase.downloading:
        return UpdaterActionButton(
          label: 'Mengunduh $percent%...',
          onPressed: null,
        );
      case UpdaterPhase.verifying:
        return const UpdaterActionButton(
          label: 'Memeriksa file...',
          onPressed: null,
        );
      case UpdaterPhase.needsPermission:
        return UpdaterActionButton(
          label: 'Buka pengaturan',
          onPressed: () => widget.controller.openPermissionSettings(),
        );
      case UpdaterPhase.ready:
        return UpdaterActionButton(
          label: 'Pasang sekarang',
          onPressed: () => widget.controller.install(),
        );
      case UpdaterPhase.error:
        final kind = state.errorKind ?? AppUpdateErrorKind.interrupted;
        final label = switch (kind) {
          AppUpdateErrorKind.interrupted => 'Lanjutkan unduhan',
          AppUpdateErrorKind.corruptFile => 'Unduh ulang',
          AppUpdateErrorKind.noInternet ||
          AppUpdateErrorKind.storageFull => 'Coba lagi',
        };
        return UpdaterActionButton(
          label: label,
          onPressed: () => widget.controller.startDownload(
            resetPartial: kind == AppUpdateErrorKind.corruptFile,
          ),
        );
    }
  }
}
