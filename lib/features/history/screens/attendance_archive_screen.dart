import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/tiket_colors.dart';
import '../../../core/widgets/app_file_image.dart';
import '../../../core/widgets/tiket/tiket.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/utils/share_helper.dart';
import '../../../core/utils/spreadsheet_escape.dart';
import '../../../core/utils/timemark_formatter.dart';
import '../../../core/utils/web_photo_store/web_photo_store.dart';
import '../../../data/models/attendance_record.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/branch_service.dart';
import '../../../data/services/absensi_setup_service.dart';
import '../../../data/repositories/auth_repository.dart';

class AttendanceArchiveScreen extends StatefulWidget {
  const AttendanceArchiveScreen({super.key});

  @override
  State<AttendanceArchiveScreen> createState() => _AttendanceArchiveScreenState();
}

class _AttendanceArchiveScreenState extends State<AttendanceArchiveScreen> {
  List<AttendanceRecord> _records = [];
  bool _isLoading = true;

  /// Byte foto web dari IndexedDB, di-cache per id record. `photoPath` di web
  /// hanya blob: URL yang mati setelah Safari reload tab.
  /// Dibatesin 12 entri (LRU) supaya foto 1080p tidak menumpuk di memori iPhone.
  final Map<String, Future<Uint8List?>> _webPhotoFutures = {};

  Future<Uint8List?> _webPhoto(AttendanceRecord record) {
    if (!kIsWeb) return Future.value(null);
    final cached = _webPhotoFutures.remove(record.id);
    if (cached != null) {
      _webPhotoFutures[record.id] = cached;
      return cached;
    }
    if (_webPhotoFutures.length >= 12) {
      _webPhotoFutures.remove(_webPhotoFutures.keys.first);
    }
    final future = getPhotoBlob(record.id);
    _webPhotoFutures[record.id] = future;
    return future;
  }

  Future<void> _openPhoto(AttendanceRecord record) async {
    final bytes = await _webPhoto(record);
    if (!mounted) return;
    _showPhotoDialog(record.photoPath, record, photoBytes: bytes);
  }

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    final list = StorageService.getAttendanceRecords();
    final currentBranch = BranchService.instance.currentBranch;
    final filtered = list.where((r) {
      // 1. Cek nama teknisi jika ada (teknisi cabang lain tidak muncul di arsip cabang ini)
      final nameClean = r.technicianName.toLowerCase().trim();
      if (nameClean.isNotEmpty) {
        for (final b in AppBranch.values) {
          if (b == currentBranch) continue;
          final belongsOther = BranchService.instance.getTechnicians(branch: b)
              .any((t) => t.toLowerCase().contains(nameClean) || nameClean.contains(t.toLowerCase()));
          if (belongsOther) return false;
        }
      }
      // 2. Cek lokasi pos
      final pos = LocationService.findPosByTagOrName(r.posName);
      if (pos != null) {
        return pos.matchesBranch(currentBranch);
      }
      // 3. Cek format shift resmi cabang lain
      for (final b in AppBranch.values) {
        if (b == currentBranch) continue;
        if (BranchService.instance.getShifts(branch: b).contains(r.shiftName.trim())) {
          return false;
        }
      }
      return true;
    }).toList();

    setState(() {
      _records = filtered;
      _isLoading = false;
    });
  }

  Future<void> _exportCsv() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada catatan absen untuk diekspor.')),
      );
      return;
    }

    try {
      final buffer = StringBuffer();
      // CSV Header
      buffer.writeln('ID,Tipe,Jadwal Shift,Nama Teknisi,Pos Lokasi,Tanggal,Waktu,Durasi Kerja,Latitude,Longitude,Alamat,Status AI');

      for (final r in _records) {
        final dateStr = TimemarkFormatter.formatIndonesianFullDate(r.timestamp);
        final timeStr = TimemarkFormatter.formatClockTime(r.timestamp);
        final tipeStr = r.type == AttendanceType.masuk ? 'Masuk' : 'Pulang';
        final durationStr = r.workDuration ?? '-';
        final safeId = escapeSpreadsheetCell(r.id);
        final safeTipe = escapeSpreadsheetCell(tipeStr);
        final safeShift = '"${escapeSpreadsheetCell(r.shiftName).replaceAll('"', '""')}"';
        final safeTech = '"${escapeSpreadsheetCell(r.technicianName).replaceAll('"', '""')}"';
        final safePos = '"${escapeSpreadsheetCell(r.posName).replaceAll('"', '""')}"';
        final safeDate = '"${escapeSpreadsheetCell(dateStr).replaceAll('"', '""')}"';
        final safeTime = '"${escapeSpreadsheetCell(timeStr).replaceAll('"', '""')}"';
        final safeDuration = '"${escapeSpreadsheetCell(durationStr).replaceAll('"', '""')}"';
        final safeAddress = '"${escapeSpreadsheetCell(r.fullAddress).replaceAll('"', '""')}"';
        final safeAi = '"${escapeSpreadsheetCell(r.aiStatusText).replaceAll('"', '""')}"';

        buffer.writeln('$safeId,$safeTipe,$safeShift,$safeTech,$safePos,$safeDate,$safeTime,$safeDuration,${r.lat},${r.lng},$safeAddress,$safeAi');
      }

      final fileName = 'Arsip_Absensi_BSS_${DateTime.now().millisecondsSinceEpoch}.csv';
      final csvText = buffer.toString();

      if (kIsWeb) {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                utf8.encode(csvText),
                mimeType: 'text/csv',
              ),
            ],
            fileNameOverrides: [fileName],
            text: 'Rekap Absensi BSS Parking (${_records.length} Catatan)',
            subject: 'Rekap Absensi BSS Parking',
          ),
        );
      } else {
        final tempDir = Directory.systemTemp;
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsString(csvText);

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'Rekap Absensi BSS Parking (${_records.length} Catatan)',
            subject: 'Rekap Absensi BSS Parking',
          ),
        );
      }
    } catch (e) {
      LoggerService.error('Gagal export CSV', error: e, tag: 'AttendanceArchive');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengekspor CSV. Silakan coba lagi.')),
        );
      }
    }
  }

  Future<void> _confirmClearHistory() async {
    final count = _records.length;
    final colors = TiketColors.of(context);
    final branchName = BranchService.instance.currentBranch.name;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.dialog,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.hairline),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: colors.danger, size: 24),
            const SizedBox(width: 8),
            Text(
              'Hapus Arsip Absensi?',
              style: TextStyle(
                color: colors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hapus $count catatan absen cabang $branchName? Catatan akan dihapus permanen dari HP ini dan tidak bisa dikembalikan.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: colors.body,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.soft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colors.signal,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: colors.signal, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sebaiknya Ekspor CSV dulu agar data tidak hilang.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.signalText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Batal',
              style: TextStyle(
                color: colors.mute,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Hapus $count Catatan'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final idsToDelete = _records.map((r) => r.id).toList();
      for (final id in idsToDelete) {
        await StorageService.deleteAttendanceRecord(id);
      }
      _webPhotoFutures.clear();
      await _loadRecords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Riwayat absen cabang $branchName dihapus.')),
        );
      }
    }
  }

  void _showPhotoDialog(String? photoPath, AttendanceRecord record, {Uint8List? photoBytes}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.download_rounded, color: Colors.white, size: 28),
                  tooltip: 'Download ke Galeri HP',
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final success = await ShareHelper.savePhotoToGallery(photoPath, imageBytes: photoBytes);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? (kIsWeb ? 'Foto diunduh ke Files/Downloads (bukan Galeri)' : 'Foto timemark berhasil disimpan ke Galeri HP')
                              : (kIsWeb ? 'Gagal mengunduh foto' : 'Gagal menyimpan foto ke Galeri HP'),
                        ),
                        backgroundColor: success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  tooltip: 'Tutup Preview Foto',
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: InteractiveViewer(
                child: AppFileImage(
                  path: photoPath,
                  bytes: photoBytes,
                  fit: BoxFit.contain,
                  errorBuilder: (c, err, st) => Container(
                    height: 250,
                    color: Colors.black87,
                    alignment: Alignment.center,
                    child: const Text(
                      'Foto tidak ditemukan atau sudah dihapus',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${record.type == AttendanceType.masuk ? "Jam Masuk" : "Jam Pulang"} • ${record.posName} • ${TimemarkFormatter.formatClockTime(record.timestamp)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            if (kIsWeb && (photoBytes == null || photoBytes.isEmpty)) ...[
              const SizedBox(height: 8),
              const Text(
                'Foto ini diambil sebelum pembaruan, watermark-nya tidak tersimpan. Absen baru akan tersimpan lengkap.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.35),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isRecordLate(AttendanceRecord record) {
    if (record.type != AttendanceType.masuk) return false;
    return AbsensiSetupService.isLateCheckIn(record.shiftName, record.timestamp);
  }

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final pad = TiketSpace.padOf(context);
    final type = TiketType.of(context);

    final lastTech = StorageService.getLastTechnicianName().trim();
    final authUser = AuthRepository.instance.currentUser;
    final activeTechName = lastTech.isNotEmpty
        ? lastTech
        : (authUser != null && authUser.nama.isNotEmpty ? authUser.nama : 'Teknisi BSS');
    final activePos = LocationService.currentPos;

    final hadirCount = _records.where((r) => r.type == AttendanceType.masuk).length;
    final pulangCount = _records.where((r) => r.type == AttendanceType.pulang).length;
    final terlambatCount = _records.where((r) => r.type == AttendanceType.masuk && _isRecordLate(r)).length;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: Column(
        children: [
          TiketBand(
            leading: TiketIconButton(
              icon: Icons.arrow_back,
              semanticLabel: 'Kembali',
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (_records.isNotEmpty) ...[
                Stack(
                  alignment: Alignment.center,
                  children: [
                    TiketPill(
                      label: 'Export CSV',
                      icon: Icons.share_outlined,
                      kind: TiketPillKind.band,
                      onPressed: _exportCsv,
                    ),
                    const Positioned(
                      left: 0,
                      top: 0,
                      width: 0,
                      height: 0,
                      child: Text(
                        'Export ke Sheets (CSV)',
                        style: TextStyle(fontSize: 0.001, color: Colors.transparent),
                      ),
                    ),
                  ],
                ),
                Tooltip(
                  message: 'Bersihkan Arsip',
                  child: TiketPill(
                    label: 'Opsi',
                    icon: Icons.more_horiz,
                    kind: TiketPillKind.band,
                    onPressed: _confirmClearHistory,
                  ),
                ),
              ],
            ],
            caption: 'Riwayat Kerja',
            hero: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildBandStat(
                  count: '$hadirCount',
                  label: 'Hadir',
                  colors: colors,
                  type: type,
                ),
                Container(width: 1.0, height: 40.0, color: colors.bandTrack),
                _buildBandStat(
                  count: '$pulangCount',
                  label: 'Pulang',
                  colors: colors,
                  type: type,
                ),
                Container(width: 1.0, height: 40.0, color: colors.bandTrack),
                _buildBandStat(
                  count: '$terlambatCount',
                  label: 'Terlambat',
                  colors: colors,
                  type: type,
                  marker: terlambatCount > 0
                      ? const StatusMarker(status: TiketStatus.attention, size: 14.0, onBand: true)
                      : null,
                ),
              ],
            ),
            footer: Text(
              'Tersimpan otomatis 30 hari di HP ini',
              style: type.caption(color: colors.bandCaption),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadRecords,
                    child: _records.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(18.0),
                                    decoration: BoxDecoration(
                                      color: colors.soft,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.folder_open_rounded,
                                      size: 40.0,
                                      color: colors.mute,
                                    ),
                                  ),
                                  const SizedBox(height: 16.0),
                                  Text(
                                    'Belum Ada Catatan Absensi',
                                    style: type.section(color: colors.ink),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6.0),
                                  Text(
                                    'Catatan kehadiran timemark muncul otomatis setelah kamu foto absen masuk atau pulang.',
                                    textAlign: TextAlign.center,
                                    style: type.meta(color: colors.body),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            itemCount: _records.length,
                            itemBuilder: (ctx, i) => _buildRecordRow(
                              _records[i],
                              activeTechName: activeTechName,
                              activePos: activePos,
                              colors: colors,
                              type: type,
                              pad: pad,
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBandStat({
    required String count,
    required String label,
    required TiketColors colors,
    required TiketType type,
    Widget? marker,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                count,
                style: type.hero(color: colors.onBand),
              ),
              if (marker != null) ...[
                const SizedBox(width: 4.0),
                marker,
              ],
            ],
          ),
          const SizedBox(height: 2.0),
          Text(
            label,
            style: type.caption(color: colors.bandCaption),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecordRow(
    AttendanceRecord record, {
    required String activeTechName,
    required PosLocation activePos,
    required TiketColors colors,
    required TiketType type,
    required double pad,
  }) {
    final isMasuk = record.type == AttendanceType.masuk;
    final isLate = isMasuk && _isRecordLate(record);
    final dateStr = TimemarkFormatter.formatIndonesianFullDate(record.timestamp);
    final timeStr = TimemarkFormatter.formatClockTime(record.timestamp);

    final displayTech = (record.technicianName.isNotEmpty &&
            record.technicianName.toLowerCase() != 'farhan lakoro' &&
            record.technicianName.toLowerCase() != 'teknisi')
        ? record.technicianName
        : (activeTechName.isNotEmpty ? activeTechName : record.technicianName);
    final displayPos = (record.posName.isNotEmpty &&
            record.posName.toLowerCase() != 'pasar bersehati manado')
        ? record.posName
        : (activePos.posName.isNotEmpty ? activePos.posName : record.posName);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPhotoThumb(record, colors: colors),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        StatusMarker(
                          status: isLate
                              ? TiketStatus.attention
                              : (isMasuk ? TiketStatus.ok : TiketStatus.notStarted),
                          size: 16.0,
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            isMasuk ? 'Jam Masuk' : 'Jam Pulang',
                            style: type.rowTitle(color: colors.ink),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Row(
                      children: [
                        Text(
                          '$timeStr WITA',
                          style: type.status(
                            color: isLate ? colors.signalText : colors.ink,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.soft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isLate ? 'Terlambat' : 'Tepat Waktu',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: isLate ? colors.signalText : colors.okText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      '$dateStr · ${isLate ? "terlambat" : (isMasuk ? "tepat waktu" : (record.workDuration != null && record.workDuration!.isNotEmpty ? record.workDuration! : "selesai"))}',
                      style: type.meta(color: colors.body),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      '$displayPos · $displayTech · ${record.shiftName}${record.isAiVerified ? " · AI Lolos" : ""}',
                      style: type.caption(color: colors.body),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: pad + 52.0 + 12.0),
          child: Divider(
            height: 1.0,
            thickness: 1.0,
            color: colors.hairline,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoThumb(AttendanceRecord record, {required TiketColors colors}) {
    final path = record.photoPath;
    final placeholder = Icon(
      Icons.photo_camera_outlined,
      color: colors.mute,
      size: 24.0,
    );

    Widget frame({VoidCallback? onTap, Widget? child}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52.0,
          height: 52.0,
          decoration: BoxDecoration(
            color: colors.soft,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: child,
          ),
        ),
      );
    }

    if (!kIsWeb) {
      final hasFile = path != null && File(path).existsSync();
      return frame(
        onTap: hasFile ? () => _openPhoto(record) : null,
        child: hasFile ? _thumbImage(path: path, colors: colors) : placeholder,
      );
    }

    return FutureBuilder<Uint8List?>(
      future: _webPhoto(record),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        final hasPhoto = (bytes != null && bytes.isNotEmpty) || (path?.isNotEmpty ?? false);
        return frame(
          onTap: hasPhoto ? () => _openPhoto(record) : null,
          child: hasPhoto
              ? _thumbImage(path: path, bytes: bytes, colors: colors)
              : placeholder,
        );
      },
    );
  }

  Widget _thumbImage({String? path, Uint8List? bytes, required TiketColors colors}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppFileImage(path: path, bytes: bytes, fit: BoxFit.cover, cacheWidth: 200),
          Positioned(
            right: 2.0,
            bottom: 2.0,
            child: Container(
              padding: const EdgeInsets.all(2.0),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.zoom_in,
                color: Colors.white,
                size: 14.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
