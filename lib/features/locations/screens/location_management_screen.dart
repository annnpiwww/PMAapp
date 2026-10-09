import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/theme_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/branch_service.dart';

class LocationManagementScreen extends StatefulWidget {
  final ValueChanged<PosLocation>? onLocationSelected;

  const LocationManagementScreen({super.key, this.onLocationSelected});

  @override
  State<LocationManagementScreen> createState() =>
      _LocationManagementScreenState();
}

class _LocationManagementScreenState extends State<LocationManagementScreen> {
  String _searchQuery = '';
  late AppBranch _selectedBranch;

  @override
  void initState() {
    super.initState();
    _selectedBranch = BranchService.instance.currentBranch;
  }

  static const List<Color> _palette = [
    Color(0xFFF59E0B), // Amber / Gold
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Emerald Green
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEF4444), // Red
    Color(0xFF0F172A), // Dark Slate
  ];

  void _showLocationFormDialog({PosLocation? existingLocation}) {
    final isEditing = existingLocation != null;
    final nameController =
        TextEditingController(text: existingLocation?.posName ?? '');
    final cabangController =
        TextEditingController(text: existingLocation?.cabangName ?? _selectedBranch.name);
    final tagController =
        TextEditingController(text: existingLocation?.locationTag ?? _selectedBranch.defaultLocationTag);

    Color selectedColor =
        existingLocation?.tagColor ?? const Color(0xFFF59E0B);
    String? inlineError;

    showDialog(
      context: context,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'Edit Lokasi' : 'Tambah Lokasi Baru',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (inlineError != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.dangerBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                inlineError!,
                                style: const TextStyle(fontSize: 11.5, color: AppColors.danger, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    TextField(
                      controller: nameController,
                      onChanged: (_) {
                        if (inlineError != null) setDlgState(() => inlineError = null);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Nama Lokasi *',
                        hintText: 'Misal: Pasar Bersehati Manado / Gate 1',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: tagController,
                            onChanged: (_) {
                              if (inlineError != null) setDlgState(() => inlineError = null);
                            },
                            decoration: const InputDecoration(
                              labelText: 'Tag Card *',
                              hintText: 'PBM',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: cabangController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Cabang / Area',
                              helperText: 'Sesuai akun aktif',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Pilih Warna Tag Badge Card:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _palette.map((c) {
                        final isSel = selectedColor.toARGB32() == c.toARGB32();
                        return InkWell(
                          onTap: () => setDlgState(() => selectedColor = c),
                          borderRadius: BorderRadius.circular(22),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSel ? AppColors.textPrimary : Colors.black12,
                                  width: isSel ? 3.0 : 1.0,
                                ),
                                boxShadow: isSel
                                    ? [
                                        BoxShadow(
                                          color: c.withValues(alpha: 0.4),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSel
                                  ? const Icon(Icons.check_rounded,
                                      color: Colors.white, size: 20)
                                  : null,
                            ),
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
                    if (nameController.text.trim().isEmpty ||
                        tagController.text.trim().isEmpty) {
                      setDlgState(() {
                        inlineError = 'Nama Lokasi dan Tag Card wajib diisi.';
                      });
                      return;
                    }

                    double lat = 0.0;
                    double lng = 0.0;
                    String address = '';

                    if (isEditing) {
                      lat = existingLocation.lat;
                      lng = existingLocation.lng;
                      address = existingLocation.fullAddress;
                    }

                    // Otomatis isi dengan koordinat GPS realtime dari LocationService (fallback 0.0 jika offline)
                    if (lat == 0.0 && lng == 0.0) {
                      try {
                        final gps = LocationService.lastLocationResult ??
                            await LocationService.getCurrentLocation();
                        lat = gps.lat;
                        lng = gps.lng;
                        if (address.isEmpty) {
                          address = gps.fullAddress;
                        }
                      } catch (_) {
                        lat = 0.0;
                        lng = 0.0;
                      }
                    }

                    if (address.isEmpty) {
                      address = cabangController.text.trim().isNotEmpty
                          ? cabangController.text.trim()
                          : (_selectedBranch == AppBranch.bali ? 'Denpasar, Bali' : 'Manado, Sulawesi Utara');
                    }

                    final pos = PosLocation(
                      posId: isEditing
                          ? existingLocation.posId
                          : (_selectedBranch == AppBranch.bali
                              ? 'POS-DPS-${const Uuid().v4().substring(0, 6)}'
                              : 'POS-${const Uuid().v4().substring(0, 6)}'),
                      posName: nameController.text.trim(),
                      cabangName: cabangController.text.trim().isNotEmpty
                          ? cabangController.text.trim()
                          : _selectedBranch.name,
                      locationTag: tagController.text.trim().toUpperCase(),
                      fullAddress: address,
                      tagColor: selectedColor,
                      lat: lat,
                      lng: lng,
                    );

                    if (isEditing) {
                      await LocationService.updateLocation(pos);
                    } else {
                      await LocationService.addLocation(pos);
                    }

                    setState(() {});
                    if (dlgCtx.mounted) {
                      Navigator.of(dlgCtx).pop();
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Lokasi "${pos.posName}" berhasil disimpan!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(PosLocation pos) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Lokasi?'),
        content: Text('Hapus lokasi "${pos.posName}" [${pos.locationTag}]?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal & Tutup'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              await LocationService.deleteLocation(pos.posId);
              setState(() {});
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allLocations = LocationService.getLocationsByBranch(_selectedBranch);
    final currentPos = LocationService.currentPos;
    final isDark = ThemeService.isDarkMode(context);
    final scaffoldBg = isDark ? const Color(0xFF0B1120) : const Color(0xFFFAF8F5);
    final searchFill = isDark ? const Color(0xFF1E293B) : Colors.grey.shade100;
    final searchBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade300;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;
    final textMuted = isDark ? const Color(0xFF64748B) : AppColors.textMuted;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : AppColors.cardBorder;

    final filteredLocations = allLocations.where((loc) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase().trim();
      return loc.posName.toLowerCase().contains(q) ||
          loc.locationTag.toLowerCase().contains(q) ||
          loc.cabangName.toLowerCase().contains(q) ||
          loc.fullAddress.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('Kelola Lokasi (${_selectedBranch.name})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_rounded),
            tooltip: 'Tambah Lokasi',
            onPressed: () => _showLocationFormDialog(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Locked Branch Banner (Strict Isolation: Manado Manado, Bali Bali)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : AppColors.cardBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.storefront_rounded,
                      size: 18,
                      color: isDark ? AppColors.accent : AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Cabang: ${_selectedBranch.name} (${allLocations.length} Pos Terdaftar)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                style: TextStyle(color: textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Cari nama lokasi, tag, cabang...',
                  hintStyle: TextStyle(color: textMuted, fontSize: 12.5),
                  prefixIcon: Icon(Icons.search, size: 20, color: textMuted),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 18, color: textMuted),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  fillColor: searchFill,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: searchBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: searchBorder),
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            Expanded(
              child: filteredLocations.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? 'Tidak ada lokasi cocok dengan "$_searchQuery"'
                            : 'Belum ada daftar lokasi',
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredLocations.length,
                      separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final pos = filteredLocations[index];
                        final isCurrent = pos.posId == currentPos.posId;

            return Card(
              color: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isCurrent ? AppColors.primary : cardBorder,
                  width: isCurrent ? 2 : 1,
                ),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                leading: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: pos.tagColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    pos.locationTag,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        pos.posName,
                        softWrap: true,
                        maxLines: 3,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.w600,
                          color: isCurrent
                              ? (isDark ? const Color(0xFF38BDF8) : AppColors.primary)
                              : textPrimary,
                        ),
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'AKTIF',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      pos.fullAddress,
                      softWrap: true,
                      maxLines: 3,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'GPS: ${pos.lat.toStringAsFixed(6)}°N, ${pos.lng.toStringAsFixed(6)}°E',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'select') {
                      LocationService.currentPos = pos;
                      widget.onLocationSelected?.call(pos);
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Lokasi aktif diubah ke: ${pos.posName} [${pos.locationTag}]'),
                          backgroundColor: AppColors.primary,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    } else if (val == 'edit') {
                      _showLocationFormDialog(existingLocation: pos);
                    } else if (val == 'delete') {
                      _confirmDelete(pos);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'select',
                      child: Row(
                        children: [
                          Icon(Icons.check, size: 16, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text('Jadikan Lokasi Aktif'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('Edit Lokasi'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: AppColors.danger),
                          SizedBox(width: 8),
                          Text('Hapus',
                              style: TextStyle(color: AppColors.danger)),
                        ],
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  LocationService.currentPos = pos;
                  widget.onLocationSelected?.call(pos);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Lokasi aktif diubah ke: ${pos.posName} [${pos.locationTag}]'),
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
    ],
  ),
),
);
  }
}
