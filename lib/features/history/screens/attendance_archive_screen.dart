import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/utils/share_helper.dart';
import '../../../core/utils/timemark_formatter.dart';
import '../../../data/models/attendance_record.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/repositories/auth_repository.dart';

class AttendanceArchiveScreen extends StatefulWidget {
  const AttendanceArchiveScreen({super.key});

  @override
  State<AttendanceArchiveScreen> createState() => _AttendanceArchiveScreenState();
}

class _AttendanceArchiveScreenState extends State<AttendanceArchiveScreen> {
  List<AttendanceRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    final list = StorageService.getAttendanceRecords();
    setState(() {
      _records = list;
      _isLoading = false;
    });
  }

  Future<void> _exportCsv() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada catatan absensi untuk diekspor')),
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
        final safeAddress = '"${r.fullAddress.replaceAll('"', '""')}"';
        final safePos = '"${r.posName.replaceAll('"', '""')}"';

        buffer.writeln('${r.id},$tipeStr,"${r.shiftName}","${r.technicianName}",$safePos,"$dateStr","$timeStr","$durationStr",${r.lat},${r.lng},$safeAddress,"${r.aiStatusText}"');
      }

      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/Arsip_Absensi_BSS_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buffer.toString());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Rekap Absensi BSS Parking (${_records.length} Catatan)',
          subject: 'Rekap Absensi BSS Parking',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal export CSV: $e')),
        );
      }
    }
  }

  Future<void> _confirmClearHistory() async {
    final count = _records.length;
    final isDark = ThemeService.isDarkMode(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
            const SizedBox(width: 8),
            Text(
              'Hapus Arsip Absensi?',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimary,
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
              'Sebanyak $count catatan absensi akan dihapus permanen dari perangkat ini dan tidak dapat dipulihkan.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? const Color(0xFFCBD5E1) : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF451A03).withValues(alpha: 0.5) : AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFFD97706) : AppColors.warningBorder,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Disarankan untuk melakukan Ekspor CSV terlebih dahulu agar laporan tidak hilang.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF9A3412),
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
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Hapus $count Catatan'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService.clearAllAttendanceRecords();
      await _loadRecords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Riwayat absensi berhasil dihapus')),
        );
      }
    }
  }

  void _showPhotoDialog(String photoPath, AttendanceRecord record) {
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
                    final success = await ShareHelper.savePhotoToGallery(photoPath);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Foto timemark berhasil disimpan ke Galeri HP'
                              : 'Gagal menyimpan foto ke Galeri HP',
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
                child: Image.file(
                  File(photoPath),
                  fit: BoxFit.contain,
                  errorBuilder: (c, err, st) => Container(
                    height: 250,
                    color: Colors.black87,
                    alignment: Alignment.center,
                    child: const Text(
                      'Foto tidak ditemukan atau telah dihapus',
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
          ],
        ),
      ),
    );
  }

  bool _isRecordLate(AttendanceRecord record) {
    if (record.type != AttendanceType.masuk) return false;
    final shift = record.shiftName;
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(shift);
    if (match == null) return false;

    final startH = int.tryParse(match.group(1) ?? '') ?? 0;
    final startM = int.tryParse(match.group(2) ?? '') ?? 0;

    final recTime = record.timestamp;
    final scheduledMinutes = startH * 60 + startM;
    final actualMinutes = recTime.hour * 60 + recTime.minute;

    // Khusus Shift 1 (03:00 - 11:00):
    // Jam kerja dimulai 03:00 pagi.
    // - Jika teknisi masuk sebelum 03:00 (misal 02:45 atau malam sebelumnya 22:00) -> Tepat Waktu.
    // - Jika teknisi masuk > 03:00 (misal 03:05, 04:00, atau bahkan 11:30) -> Terlambat!
    if (startH == 3) {
      if (recTime.hour >= 21) {
        // Datang malam hari sebelum shift subuh -> Tepat Waktu (Early arrival)
        return false;
      }
      return actualMinutes > scheduledMinutes;
    }

    // Shift 2 (10:00), Shift 2.2 (10:00), Shift 3 (14:00):
    // Jika actualMinutes > scheduledMinutes (misal 10:07 > 10:00) -> Terlambat!
    return actualMinutes > scheduledMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.isDarkMode(context);
    final scaffoldBg = isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : AppColors.cardBorder;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;
    final primaryAccent = isDark ? const Color(0xFF38BDF8) : AppColors.primary;

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
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Riwayat Kerja',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
            fontSize: 16.5,
            color: textPrimary,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (_records.isNotEmpty) ...[
            IconButton(
              icon: Icon(Icons.share_outlined, color: primaryAccent),
              tooltip: 'Export ke Excel / CSV',
              onPressed: _exportCsv,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              tooltip: 'Bersihkan Arsip',
              onPressed: _confirmClearHistory,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRecords,
              child: CustomScrollView(
                slivers: [
                  // Technician & Location Profile Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cardBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: primaryAccent.withValues(alpha: isDark ? 0.2 : 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.person_rounded, color: primaryAccent, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activeTechName,
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: activePos.tagColor.withValues(alpha: isDark ? 0.25 : 0.15),
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          activePos.locationTag,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: activePos.tagColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          activePos.posName,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: textSecondary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Retention Badge Info
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0C4A6E).withValues(alpha: 0.3) : const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF0284C7).withValues(alpha: 0.5) : const Color(0xFFBAE6FD),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Riwayat catatan absensi hanya tersimpan otomatis selama 30 hari',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // KPI Summary Cards (Hadir, Pulang, Terlambat)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Hadir',
                              value: '$hadirCount',
                              icon: Icons.login_rounded,
                              color: const Color(0xFF10B981),
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Pulang',
                              value: '$pulangCount',
                              icon: Icons.logout_rounded,
                              color: const Color(0xFF0284C7),
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Terlambat',
                              value: '$terlambatCount',
                              icon: Icons.access_time_filled_rounded,
                              color: const Color(0xFFF59E0B),
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Empty State
                  if (_records.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: primaryAccent.withValues(alpha: isDark ? 0.2 : 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.folder_open_rounded,
                                size: 54,
                                color: primaryAccent,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Belum Ada Catatan Absensi',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                'Catatan kehadiran timemark akan muncul otomatis setelah Anda melakukan foto absensi masuk atau pulang.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    // Records List
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = _records[index];
                            return _buildRecordCard(
                              item,
                              activeTechName: activeTechName,
                              activePos: activePos,
                              isDark: isDark,
                            );
                          },
                          childCount: _records.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
      bottomSheet: _records.isNotEmpty
          ? Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                border: isDark ? Border(top: BorderSide(color: cardBorder, width: 0.8)) : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          side: isDark ? const BorderSide(color: Color(0xFF334155)) : BorderSide.none,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.table_chart_outlined, size: 18),
                        label: const Text(
                          'Export ke Sheets (CSV)',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        onPressed: _exportCsv,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : AppColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                ),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(
    AttendanceRecord record, {
    required String activeTechName,
    required PosLocation activePos,
    required bool isDark,
  }) {
    final isMasuk = record.type == AttendanceType.masuk;
    final isLate = isMasuk && _isRecordLate(record);
    final dateStr = TimemarkFormatter.formatIndonesianFullDate(record.timestamp);
    final timeStr = TimemarkFormatter.formatClockTime(record.timestamp);

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : AppColors.cardBorder;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;
    final primaryAccent = isDark ? const Color(0xFF38BDF8) : AppColors.primary;

    // Dynamic technician name & pos location fallback
    final displayTech = (record.technicianName.isNotEmpty &&
            record.technicianName.toLowerCase() != 'farhan lakoro' &&
            record.technicianName.toLowerCase() != 'teknisi')
        ? record.technicianName
        : (activeTechName.isNotEmpty ? activeTechName : record.technicianName);
    final displayPos = (record.posName.isNotEmpty &&
            record.posName.toLowerCase() != 'pasar bersehati manado')
        ? record.posName
        : (activePos.posName.isNotEmpty ? activePos.posName : record.posName);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo Thumbnail
            GestureDetector(
              onTap: (record.photoPath != null && File(record.photoPath!).existsSync())
                  ? () => _showPhotoDialog(record.photoPath!, record)
                  : null,
              child: Container(
                width: 64,
                height: 72,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: (record.photoPath != null && File(record.photoPath!).existsSync())
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(record.photoPath!),
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              right: 2,
                              bottom: 2,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.zoom_in,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Icon(
                        Icons.photo_camera_outlined,
                        color: isDark ? const Color(0xFF64748B) : AppColors.textMuted,
                        size: 26,
                      ),
              ),
            ),
            const SizedBox(width: 12),

            // Content details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isMasuk
                                  ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                                  : (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isMasuk
                                    ? (isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0))
                                    : (isDark ? const Color(0xFF2563EB) : const Color(0xFFBFDBFE)),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isMasuk
                                        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF10B981))
                                        : (isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6)),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isMasuk ? 'Jam Masuk' : 'Jam Pulang',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isMasuk
                                        ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857))
                                        : (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isMasuk) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isLate
                                    ? (isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7))
                                    : (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5)),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isLate
                                      ? (isDark ? const Color(0xFFB45309) : const Color(0xFFFDE68A))
                                      : (isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0)),
                                ),
                              ),
                              child: Text(
                                isLate ? 'Terlambat' : 'Tepat Waktu',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: isLate
                                      ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309))
                                      : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: record.isAiVerified
                              ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFF0FDF4))
                              : (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          record.aiStatusText,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: record.isAiVerified
                                ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D))
                                : (isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Pos Name & Technician
                  Text(
                    '$displayPos • $displayTech',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Date & Time
                  Text(
                    '$dateStr • $timeStr',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  // Shift & Work Duration
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        record.shiftName,
                        style: TextStyle(
                          fontSize: 11,
                          color: primaryAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (record.workDuration != null && record.workDuration!.isNotEmpty) ...[
                        Text(' • ', style: TextStyle(color: isDark ? const Color(0xFF64748B) : AppColors.textMuted)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Kerja: ${record.workDuration}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
