import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/tiket_colors.dart';
import '../../../core/widgets/tiket/tiket.dart';
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

  static final List<Color> _palette = [
    const Color.fromARGB(255, 245, 158, 11), // Amber / Gold
    const Color.fromARGB(255, 59, 130, 246), // Blue
    const Color.fromARGB(255, 16, 185, 129), // Emerald Green
    const Color.fromARGB(255, 139, 92, 246), // Purple
    const Color.fromARGB(255, 239, 68, 68), // Red
    const Color.fromARGB(255, 15, 23, 42), // Dark Slate
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
    Color selectedColor = _palette.first;
    final colors = TiketColors.of(context);

    showDialog(
      context: context,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              backgroundColor: colors.dialog,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.add_location_alt_rounded, color: colors.ink),
                  const SizedBox(width: 8),
                  Text(
                    'Simpan Lokasi GPS Saat Ini',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.ink),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: colors.ink),
                      decoration: InputDecoration(
                        labelText: 'Nama Lokasi *',
                        labelStyle: TextStyle(color: colors.body),
                        isDense: true,
                        filled: true,
                        fillColor: colors.soft,
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(color: colors.hairline, width: 2.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: tagController,
                            style: TextStyle(color: colors.ink),
                            decoration: InputDecoration(
                              labelText: 'Tag Card *',
                              labelStyle: TextStyle(color: colors.body),
                              isDense: true,
                              filled: true,
                              fillColor: colors.soft,
                              border: UnderlineInputBorder(
                                borderSide: BorderSide(color: colors.hairline, width: 2.0),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: cabangController,
                            style: TextStyle(color: colors.ink),
                            decoration: InputDecoration(
                              labelText: 'Cabang / Area',
                              labelStyle: TextStyle(color: colors.body),
                              isDense: true,
                              filled: true,
                              fillColor: colors.soft,
                              border: UnderlineInputBorder(
                                borderSide: BorderSide(color: colors.hairline, width: 2.0),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Pilih Warna Tag Badge Card:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.body),
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
                                color: isSel ? colors.ink : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: isSel
                                ? Icon(Icons.check, color: colors.canvas, size: 14)
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
                  child: Text('Batal', style: TextStyle(color: colors.body)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                  ),
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty || tagController.text.trim().isEmpty) return;

                    final newPos = PosLocation(
                      posId: '${currentBranch == AppBranch.bali ? 'POS-DPS-' : currentBranch == AppBranch.ho ? 'POS-HO-' : 'POS-'}${const Uuid().v4().substring(0, 6)}',
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
                          content: Text('Lokasi "${newPos.posName}" disimpan dan jadi aktif!'),
                          backgroundColor: colors.ok,
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

    final colors = TiketColors.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: colors.dialog,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header with GPS Status and Close Button
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Pilih Lokasi',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: colors.ink,
                              fontFamily: 'PlusJakartaSans',
                            ),
                          ),
                          Flexible(
                            child: Text(
                              ' (${BranchService.instance.currentBranch.name})',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: colors.body,
                                fontFamily: 'PlusJakartaSans',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pilih atau simpan titik lokasi aktif',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.body,
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: Icon(Icons.refresh_rounded, size: 20, color: colors.mute),
                  onPressed: _fetchGpsAndRank,
                  tooltip: 'Refresh GPS',
                ),
                IconButton(
                  tooltip: 'Tutup',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: Icon(Icons.close_rounded, color: colors.mute, size: 22),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: colors.hairline, height: 1),
            const SizedBox(height: 10),

            // Live GPS Status Banner (flat on canvas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: colors.ok, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLoadingGps
                              ? 'Mencari sinyal GPS...'
                              : '${_currentGps!.lat.toStringAsFixed(4)}, ${_currentGps!.lng.toStringAsFixed(4)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'PlusJakartaSans',
                            color: colors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isLoadingGps
                              ? 'Mengukur jarak...'
                              : _currentGps!.fullAddress,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colors.body,
                            fontFamily: 'PlusJakartaSans',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!_isLoadingGps)
                    TiketPill(
                      kind: TiketPillKind.secondary,
                      icon: Icons.location_on_outlined,
                      label: 'Simpan Lokasi',
                      onPressed: _saveCurrentGpsAsNewPos,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Search Bar for locations (Input language: soft fill, radius 0, 2px bottom rule)
            Container(
              decoration: BoxDecoration(
                color: colors.soft,
                border: Border(
                  bottom: BorderSide(color: colors.body, width: 2.0),
                ),
              ),
              child: TextField(
                style: TextStyle(color: colors.ink, fontSize: 13, fontFamily: 'PlusJakartaSans'),
                decoration: InputDecoration(
                  hintText: 'Cari nama lokasi, tag, cabang...',
                  hintStyle: TextStyle(color: colors.mute, fontSize: 12.5, fontFamily: 'PlusJakartaSans'),
                  prefixIcon: Icon(Icons.search, size: 18, color: colors.mute),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          icon: Icon(Icons.clear, size: 16, color: colors.mute),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            const SizedBox(height: 10),

            // Nearest Location Title & Manage Link
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Daftar lokasi (urut jarak terdekat)',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: colors.body,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
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
                  child: Text(
                    'Kelola Semua Lokasi',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colors.ink, fontFamily: 'PlusJakartaSans'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Ranked List of Locations (flat rows with hairline dividers)
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
                              color: colors.body,
                              fontFamily: 'PlusJakartaSans',
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredRanked.length,
                          separatorBuilder: (context, index) => Divider(color: colors.hairline, height: 1),
                          itemBuilder: (ctx, idx) {
                            final item = filteredRanked[idx];
                            final pos = item['location'] as PosLocation;
                            final distText = item['distanceText'] as String;
                            final isCurrent = pos.posId == activePos.posId;

                            return InkWell(
                              onTap: () {
                                LocationService.currentPos = pos;
                                widget.onLocationSelected(pos);
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Lokasi aktif: ${pos.posName} [${pos.locationTag}]'),
                                    backgroundColor: colors.primary,
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  children: [
                                    // Code as neutral soft pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: colors.soft,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        pos.locationTag,
                                        style: TextStyle(
                                          color: colors.ink,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                          fontFamily: 'PlusJakartaSans',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Status dot
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isCurrent ? colors.primary : colors.signal,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Name & Address
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pos.posName,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w700,
                                              color: colors.ink,
                                              fontFamily: 'PlusJakartaSans',
                                            ),
                                            softWrap: true,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            pos.fullAddress,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: colors.body,
                                              fontFamily: 'PlusJakartaSans',
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            softWrap: true,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Distance as trailing meta text
                                    Text(
                                      distText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: colors.body,
                                        fontFamily: 'PlusJakartaSans',
                                      ),
                                    ),
                                    // Selected = StatusMarker ok trailing
                                    if (isCurrent) ...[
                                      const SizedBox(width: 8),
                                      Icon(Icons.check_circle, color: colors.ok, size: 18),
                                    ],
                                  ],
                                ),
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
