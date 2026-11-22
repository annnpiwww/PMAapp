import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/tiket_colors.dart';
import '../../../core/widgets/tiket/tiket.dart';
import '../../../data/services/app_release_admin_service.dart';
import '../../../data/services/app_update_service.dart';
import '../widgets/updater_ticket_widgets.dart';

Future<bool> showPublishConfirmDialog(
  BuildContext context, {
  required String versionName,
  required String abiShort,
  required int sizeBytes,
  required bool mandatory,
  String? minSupportedVersion,
}) async {
  final colors = TiketColors.of(context);
  final minClean = minSupportedVersion?.trim();
  final modeText = mandatory
      ? 'Wajib'
      : (minClean != null && minClean.isNotEmpty
            ? 'Opsional (wajib di bawah v$minClean)'
            : 'Opsional');

  final result = await showDialog<bool>(
    context: context,
    builder: (dCtx) => AlertDialog(
      backgroundColor: colors.dialog,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      title: Text(
        'Terbitkan rilis v$versionName?',
        style: TextStyle(
          fontFamily: TiketType.fontFamily,
          fontSize: 18.0,
          fontWeight: FontWeight.w800,
          color: colors.ink,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Teknisi akan mendapat pembaruan ini saat membuka aplikasi.',
            style: TextStyle(
              fontFamily: TiketType.fontFamily,
              fontSize: 14.0,
              height: 20.0 / 14.0,
              color: colors.body,
            ),
          ),
          const SizedBox(height: 12.0),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 10.0,
            ),
            decoration: BoxDecoration(
              color: updaterSurfaceTint(dCtx, colors),
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(color: colors.hairline),
            ),
            child: Text(
              '$abiShort · ${AppUpdateService.formatMb(sizeBytes)} · $modeText',
              style: TextStyle(
                fontFamily: TiketType.fontFamily,
                fontSize: 13.0,
                fontWeight: FontWeight.w600,
                color: colors.ink,
              ),
            ),
          ),
        ],
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
                label: 'Terbitkan',
                onPressed: () => Navigator.of(dCtx).pop(true),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return result == true;
}

Future<bool> showRollbackConfirmDialog(
  BuildContext context, {
  required String versionName,
}) async {
  final colors = TiketColors.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (dCtx) => AlertDialog(
      backgroundColor: colors.dialog,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      title: Text(
        'Tarik rilis v$versionName?',
        style: TextStyle(
          fontFamily: TiketType.fontFamily,
          fontSize: 18.0,
          fontWeight: FontWeight.w800,
          color: colors.ink,
        ),
      ),
      content: Text(
        'Menarik rilis hanya menghentikan HP yang belum memperbarui. HP yang sudah memperbarui tidak bisa turun versi; untuk membatalkan, unggah versi perbaikan dengan nomor lebih tinggi.',
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
                label: 'Tarik rilis',
                isDanger: true,
                onPressed: () => Navigator.of(dCtx).pop(true),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return result == true;
}

class UploadReleaseScreen extends StatefulWidget {
  final AppReleaseAdminService? service;
  final LocalApkInfo? initialApk;

  const UploadReleaseScreen({super.key, this.service, this.initialApk});

  @override
  State<UploadReleaseScreen> createState() => _UploadReleaseScreenState();
}

class _UploadReleaseScreenState extends State<UploadReleaseScreen> {
  static final RegExp _semverRegex = RegExp(r'^[0-9]+\.[0-9]+\.[0-9]+$');

  late final AppReleaseAdminService _service;
  final TextEditingController _changelogCtrl = TextEditingController();
  final TextEditingController _minVersionCtrl = TextEditingController();

  LocalApkInfo? _apk;
  bool _mandatory = false;
  bool _picking = false;
  bool _submitting = false;
  double _uploadFraction = 0.0;
  String? _statusNote;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AppReleaseAdminService.instance;
    _apk = widget.initialApk;
    _changelogCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _changelogCtrl.dispose();
    _minVersionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickApk() async {
    setState(() {
      _picking = true;
      _errorMessage = null;
      _fieldErrors = const {};
    });
    try {
      final picked = await _service.pickApkFile();
      if (picked == null || !mounted) {
        if (mounted) setState(() => _picking = false);
        return;
      }
      final info = await _service.inspectLocalApk(
        picked.path,
        fileName: picked.fileName,
      );
      if (!mounted) return;
      setState(() {
        _apk = info;
        _picking = false;
      });
    } on AppReleaseAdminException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _picking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal membaca file APK yang dipilih.';
        _picking = false;
      });
    }
  }

  bool _validateForm() {
    final errors = <String, String>{};
    if (_apk == null) {
      setState(() {
        _errorMessage = 'Pilih file APK terlebih dahulu.';
        _fieldErrors = const {};
      });
      return false;
    }
    final minVer = _minVersionCtrl.text.trim();
    if (minVer.isNotEmpty && !_semverRegex.hasMatch(minVer)) {
      errors['min_supported_version'] = 'Format harus x.y.z (contoh: 2.0.135).';
    }
    if (_changelogCtrl.text.length > 2000) {
      errors['changelog'] = 'Catatan rilis maksimal 2000 karakter.';
    }
    if (errors.isNotEmpty) {
      setState(() {
        _fieldErrors = errors;
        _errorMessage = errors.values.first;
      });
      return false;
    }
    return true;
  }

  Future<void> _submit({required bool publishNow}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_validateForm()) return;
    final apk = _apk!;

    if (publishNow) {
      final ok = await showPublishConfirmDialog(
        context,
        versionName: apk.versionName,
        abiShort: AppReleaseAdminService.abiShortLabel(apk.abi),
        sizeBytes: apk.sizeBytes,
        mandatory: _mandatory,
        minSupportedVersion: _minVersionCtrl.text.trim(),
      );
      if (!ok || !mounted) return;
    }

    setState(() {
      _submitting = true;
      _uploadFraction = 0.0;
      _statusNote = 'Menyiapkan unggahan...';
      _errorMessage = null;
      _fieldErrors = const {};
    });

    try {
      final ticket = await _service.createUpload(
        apk: apk,
        changelog: _changelogCtrl.text.trim(),
        mandatory: _mandatory,
        minSupportedVersion: _minVersionCtrl.text.trim(),
      );

      if (!mounted) return;
      setState(() => _statusNote = 'Mengunggah APK...');

      await _service.uploadFile(
        ticket.signedUrl,
        File(apk.path),
        onProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          setState(() => _uploadFraction = (sent / total).clamp(0.0, 1.0));
        },
      );

      if (publishNow) {
        if (!mounted) return;
        setState(() {
          _uploadFraction = 1.0;
          _statusNote = 'Memverifikasi & menerbitkan...';
        });
        await _service.publish(ticket.id);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            publishNow
                ? 'Rilis v${apk.versionName} berhasil diterbitkan.'
                : 'Draf v${apk.versionName} disimpan.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on AppReleaseAdminException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _fieldErrors = e.fieldErrors;
        _submitting = false;
        _statusNote = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal mengunggah rilis ke server.';
        _submitting = false;
        _statusNote = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final pad = TiketSpace.padOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final width = MediaQuery.sizeOf(context).width;
    final apk = _apk;

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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    TiketIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      semanticLabel: 'Kembali ke Rilis aplikasi',
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unggah APK',
                            style: TiketType.screenTitleStyle(
                              width,
                              color: colors.onBand,
                            ),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            'Info versi dibaca langsung dari file APK',
                            style: TiketType.metaStyle(
                              color: colors.bandCaption,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    pad,
                    18.0,
                    pad,
                    24.0 + bottomInset,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: colors.dangerTint,
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(color: colors.danger),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 13.0,
                              fontWeight: FontWeight.w600,
                              color: colors.danger,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16.0),
                      ],
                      Container(
                        padding: const EdgeInsets.all(14.0),
                        decoration: BoxDecoration(
                          color: updaterSurfaceTint(context, colors),
                          borderRadius: BorderRadius.circular(14.0),
                          border: Border.all(color: colors.hairline),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    apk?.fileName ?? 'Belum ada file dipilih',
                                    style: TextStyle(
                                      fontFamily: TiketType.fontFamily,
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w700,
                                      color: colors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2.0),
                                  Text(
                                    apk != null
                                        ? AppUpdateService.formatMb(
                                            apk.sizeBytes,
                                          )
                                        : 'Pilih berkas APK per arsitektur',
                                    style: TiketType.metaStyle(
                                      color: colors.body,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12.0),
                            OutlinedButton(
                              onPressed: (_picking || _submitting)
                                  ? null
                                  : _pickApk,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(104.0, 44.0),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14.0,
                                ),
                                foregroundColor: colors.primary,
                                side: BorderSide(
                                  color: colors.primary,
                                  width: 1.5,
                                ),
                                shape: const StadiumBorder(),
                                textStyle: const TextStyle(
                                  fontFamily: TiketType.fontFamily,
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: Text(
                                apk == null ? 'Pilih APK' : 'Ganti file',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18.0),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14.0,
                          vertical: 12.0,
                        ),
                        decoration: BoxDecoration(
                          color: colors.soft,
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Terbaca dari APK (tidak dapat diubah)',
                              style: TextStyle(
                                fontFamily: TiketType.fontFamily,
                                fontSize: 12.0,
                                fontWeight: FontWeight.w700,
                                color: colors.body,
                              ),
                            ),
                            const SizedBox(height: 10.0),
                            Row(
                              children: [
                                Expanded(
                                  child: _MetaPair(
                                    label: 'Versi',
                                    value: apk?.versionName ?? '-',
                                    colors: colors,
                                  ),
                                ),
                                const SizedBox(width: 14.0),
                                Expanded(
                                  child: _MetaPair(
                                    label: 'Kode versi',
                                    value: apk != null
                                        ? '${apk.versionCode}'
                                        : '-',
                                    colors: colors,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10.0),
                            Row(
                              children: [
                                Expanded(
                                  child: _MetaPair(
                                    label: 'Arsitektur',
                                    value: apk != null
                                        ? AppReleaseAdminService.abiShortLabel(
                                            apk.abi,
                                          )
                                        : '-',
                                    colors: colors,
                                  ),
                                ),
                                const SizedBox(width: 14.0),
                                Expanded(
                                  child: _MetaPair(
                                    label: 'Ukuran',
                                    value: apk != null
                                        ? AppUpdateService.formatMb(
                                            apk.sizeBytes,
                                          )
                                        : '-',
                                    colors: colors,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18.0),
                      Row(
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
                          Text(
                            '${_changelogCtrl.text.length} / 2000',
                            style: TextStyle(
                              fontFamily: TiketType.fontFamily,
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                              color: colors.body,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6.0),
                      TextField(
                        controller: _changelogCtrl,
                        maxLength: 2000,
                        maxLines: 5,
                        minLines: 3,
                        enabled: !_submitting,
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 14.0,
                          color: colors.ink,
                        ),
                        decoration: _bottomRuleDecoration(
                          colors,
                          hint:
                              'Tulis perbaikan atau fitur baru pada rilis ini...',
                          errorText: _fieldErrors['changelog'],
                        ).copyWith(counterText: ''),
                      ),
                      const SizedBox(height: 18.0),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: colors.hairline),
                            bottom: BorderSide(color: colors.hairline),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Wajib diperbarui',
                                    style: TextStyle(
                                      fontFamily: TiketType.fontFamily,
                                      fontSize: 15.0,
                                      fontWeight: FontWeight.w700,
                                      color: colors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2.0),
                                  Text(
                                    'Teknisi harus memperbarui untuk lanjut bekerja',
                                    style: TiketType.metaStyle(
                                      color: colors.body,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12.0),
                            Switch.adaptive(
                              value: _mandatory,
                              activeTrackColor: colors.primary,
                              onChanged: _submitting
                                  ? null
                                  : (v) => setState(() => _mandatory = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18.0),
                      Text(
                        'Versi minimum (opsional)',
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 14.0,
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 6.0),
                      TextField(
                        controller: _minVersionCtrl,
                        enabled: !_submitting,
                        keyboardType: TextInputType.text,
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 14.0,
                          color: colors.ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        decoration: _bottomRuleDecoration(
                          colors,
                          hint: 'Contoh: 2.0.135',
                          errorText: _fieldErrors['min_supported_version'],
                        ),
                      ),
                      const SizedBox(height: 6.0),
                      Text(
                        'Format x.y.z. Perangkat di bawah versi ini akan mendapat pembaruan wajib.',
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 12.0,
                          color: colors.body,
                        ),
                      ),
                      if (_submitting) ...[
                        const SizedBox(height: 18.0),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999.0),
                          child: LinearProgressIndicator(
                            value: _uploadFraction > 0 ? _uploadFraction : null,
                            minHeight: 8.0,
                            backgroundColor: colors.soft,
                            color: colors.primary,
                          ),
                        ),
                        if (_statusNote != null) ...[
                          const SizedBox(height: 6.0),
                          Text(
                            _statusNote!,
                            style: TiketType.metaStyle(color: colors.body),
                          ),
                        ],
                      ],
                      const SizedBox(height: 18.0),
                      UpdaterActionButton(
                        label: 'Terbitkan rilis',
                        onPressed: _submitting
                            ? null
                            : () => _submit(publishNow: true),
                      ),
                      const SizedBox(height: 10.0),
                      UpdaterActionButton(
                        label: 'Simpan sebagai draf',
                        isPrimary: false,
                        onPressed: _submitting
                            ? null
                            : () => _submit(publishNow: false),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _bottomRuleDecoration(
    TiketColors colors, {
    required String hint,
    String? errorText,
  }) {
    final baseBorder = UnderlineInputBorder(
      borderSide: BorderSide(color: colors.body, width: 2.0),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8.0)),
    );
    return InputDecoration(
      filled: true,
      fillColor: colors.soft,
      hintText: hint,
      errorText: errorText,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14.0,
        vertical: 12.0,
      ),
      border: baseBorder,
      enabledBorder: baseBorder,
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: colors.primary, width: 2.0),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8.0)),
      ),
    );
  }
}

class _MetaPair extends StatelessWidget {
  final String label;
  final String value;
  final TiketColors colors;

  const _MetaPair({
    required this.label,
    required this.value,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: TiketType.fontFamily,
            fontSize: 12.0,
            fontWeight: FontWeight.w500,
            color: colors.body,
          ),
        ),
        const SizedBox(height: 1.0),
        Text(
          value,
          style: TextStyle(
            fontFamily: TiketType.fontFamily,
            fontSize: 15.0,
            fontWeight: FontWeight.w800,
            color: colors.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
