import 'dart:math';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/theme_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/branch_service.dart';
import '../screens/location_management_screen.dart';

class LocationPickerModal extends StatefulWidget {
  final PosLocation? activePos;
  final ValueChanged<PosLocation> onLocationSelected;

  const LocationPickerModal({
    super.key,
    this.activePos,
    required this.onLocationSelected,
  });

  @override
  State<LocationPickerModal> createState() => _LocationPickerModalState();
}

class _LocationPickerModalState extends State<LocationPickerModal> {
  LocationResult? _currentGps;
  bool _isLoadingGps = true;
  List<Map<String, dynamic>> _rankedLocations = [];
  String _searchQuery = '';

  static const List<Color> _palette = [
    Color(0xFFF59E0B), // Amber / Gold
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Emerald Green
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEF4444), // Red
    Color(0xFF0F172A), // Dark Slate
  ];
  @override
  void initState() {
    super.initState();
    _fetchGpsAndRank();
  }

  Future<void> _fetchGpsAndRank() async {
    setState(() => _isLoadingGps = true);
    final loc = await LocationService.getCurrentLocation();
    final ranked = LocationService.getLocationsRankedByDistance(loc.lat, loc.lng);

    if (mounted) {
      setState(() {
        _currentGps = loc;
        _rankedLocations = ranked;
        _isLoadingGps = false;
      });
    }
  }

  Future<void> _saveCurrentGpsAsNewPos() async {
    if (_currentGps == null) return;

    final currentBranch = BranchService.instance.currentBranch;
    final nameController = TextEditingController(text: 'Lokasi Baru (GPS Live)');
    final tagController = TextEditingController(
      text: currentBranch == AppBranch.bali
          ? 'DPS-${Random().nextInt(90) + 10}'
          : 'POS-${Random().nextInt(90) + 10}',
    );
    final cabangController = TextEditingController(text: currentBranch.name);
    Color selectedColor = const Color(0xFFF59E0B);

    showDialog(
      context: context,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.add_location_alt_rounded, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Simpan Lokasi GPS Saat Ini', style: TextStyle(fontSize: 15)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nama Lokasi *', isDense: true),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: tagController,
                            decoration: const InputDecoration(labelText: 'Tag Card *', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: cabangController,
                            decoration: const InputDecoration(labelText: 'Cabang / Area', isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Pilih Warna Tag Badge Card:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: _palette.map((c) {
                        final isSel = selectedColor.toARGB32() == c.toARGB32();
                        return GestureDetector(
                          onTap: () => setDlgState(() => selectedColor = c),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel ? Colors.black : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: isSel
                                ? const Icon(Icons.check, color: Colors.white, size: 14)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dlgCtx).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty || tagController.text.trim().isEmpty) return;

                    final newPos = PosLocation(
                      posId: currentBranch == AppBranch.bali
                          ? 'POS-DPS-${const Uuid().v4().substring(0, 6)}'
                          : 'POS-${const Uuid().v4().substring(0, 6)}',
                      posName: nameController.text.trim(),
                      cabangName: cabangController.text.trim().isNotEmpty
                          ? cabangController.text.trim()
                          : currentBranch.name,
                      locationTag: tagController.text.trim().toUpperCase(),
                      fullAddress: _currentGps!.fullAddress.isNotEmpty
                          ? _currentGps!.fullAddress
                          : cabangController.text.trim(),
                      tagColor: selectedColor,
                      lat: _currentGps!.lat,
                      lng: _currentGps!.lng,
                    );

                    await LocationService.addLocation(newPos);
                    widget.onLocationSelected(newPos);

                    if (dlgCtx.mounted) Navigator.of(dlgCtx).pop();
                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Lokasi "${newPos.posName}" disimpan dan dijadikan aktif!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                  child: const Text('Simpan & Jadikan Aktif'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activePos = LocationService.currentPos;
    final filteredRanked = _rankedLocations.where((item) {
      if (_searchQuery.trim().isEmpty) return true;
      final pos = item['location'] as PosLocation;
      final q = _searchQuery.toLowerCase().trim();
      return pos.posName.toLowerCase().contains(q) ||
          pos.locationTag.toLowerCase().contains(q) ||
          pos.cabangName.toLowerCase().contains(q) ||
          pos.fullAddress.toLowerCase().contains(q);
    }).toList();

    final isDark = ThemeService.isDarkMode(context);
    final sheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;
    final textMuted = isDark ? const Color(0xFF64748B) : AppColors.textMuted;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : AppColors.cardBorder;
    final searchFill = isDark ? const Color(0xFF1E293B) : Colors.grey.shade100;
    final searchBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade300;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header with GPS Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.near_me_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Pilih Lokasi (${BranchService.instance.currentBranch.name})',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.refresh_rounded, size: 20, color: textPrimary),
                  onPressed: _fetchGpsAndRank,
                  tooltip: 'Refresh GPS',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Live GPS Status Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : AppColors.primaryLight.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gps_fixed, color: AppColors.accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLoadingGps
                              ? 'Mencari sinyal GPS perangkat...'
                              : 'GPS: ${_currentGps!.lat.toStringAsFixed(6)}°N, ${_currentGps!.lng.toStringAsFixed(6)}°E',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: isDark ? const Color(0xFF38BDF8) : AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isLoadingGps
                              ? 'Mengukur jarak ke lokasi terdekat...'
                              : _currentGps!.fullAddress,
                          style: TextStyle(
                            fontSize: 11,
                            color: textSecondary,
                          ),
                          maxLines: 2,
                          softWrap: true,
                        ),
                      ],
                    ),
                  ),
                  if (!_isLoadingGps)
                    TextButton.icon(
                      onPressed: _saveCurrentGpsAsNewPos,
                      icon: const Icon(Icons.add_location, size: 14),
                      label: const Text('Simpan Lokasi', style: TextStyle(fontSize: 10.5)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Search Bar for 100+ locations
            TextField(
              style: TextStyle(color: textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Cari nama lokasi, tag, cabang...',
                hintStyle: TextStyle(color: textMuted, fontSize: 12.5),
                prefixIcon: Icon(Icons.search, size: 18, color: textMuted),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 16, color: textMuted),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: searchFill,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: searchBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: searchBorder),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 10),

            // Nearest Location Title & Manage Link
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daftar Lokasi (Urut Jarak Terdekat):',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: textMuted,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LocationManagementScreen(
                          onLocationSelected: widget.onLocationSelected,
                        ),
                      ),
                    );
                  },
                  child: const Text('Kelola Semua Lokasi', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Ranked List of Locations
            Expanded(
              child: _isLoadingGps
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : filteredRanked.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isNotEmpty
                                ? 'Tidak ada lokasi cocok dengan "$_searchQuery"'
                                : 'Belum ada daftar lokasi',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: textSecondary,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredRanked.length,
                          itemBuilder: (ctx, idx) {
                            final item = filteredRanked[idx];
                            final pos = item['location'] as PosLocation;
                            final distText = item['distanceText'] as String;
                            final isCurrent = pos.posId == activePos.posId;

                            return Card(
                              color: cardBg,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isCurrent ? AppColors.primary : cardBorder,
                                  width: isCurrent ? 2 : 1,
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                leading: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: pos.tagColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    pos.locationTag,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  pos.posName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                    color: isCurrent ? (isDark ? const Color(0xFF38BDF8) : AppColors.primary) : textPrimary,
                                  ),
                                  softWrap: true,
                                  maxLines: 2,
                                ),
                                subtitle: Text(
                                  pos.fullAddress,
                                  style: TextStyle(fontSize: 10.5, color: textSecondary),
                                  softWrap: true,
                                  maxLines: 2,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF334155) : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        distText,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? const Color(0xFF38BDF8) : AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    if (isCurrent) ...[
                                      const SizedBox(width: 6),
                                      const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                                    ],
                                  ],
                                ),
                                onTap: () {
                                  LocationService.currentPos = pos;
                                  widget.onLocationSelected(pos);
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Lokasi aktif: ${pos.posName} [${pos.locationTag}]'),
                                      backgroundColor: AppColors.primary,
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
