import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/theme_service.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
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
    _syncLocations();
  }

  Future<void> _syncLocations() async {
    await LocationService.syncFromRemote();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showSpvConfirmDialog({
    required String actionTitle,
    required String description,
    required Future<RemoteWriteResult> Function(
      String identity,
      String password,
    )
    onConfirm,
    required String successMessage,
    VoidCallback? onSuccess,
  }) async {
    final initialEmail = AuthRepository.instance.currentUser?.email ?? '';
    final identityController = TextEditingController(text: initialEmail);
    final passwordController = TextEditingController();
    bool isLoading = false;
    String? inlineError;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isLoading,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            Future<void> submit() async {
              final identity = identityController.text.trim();
              final password = passwordController.text;

              if (identity.isEmpty || password.isEmpty) {
                setDlgState(() {
                  inlineError = 'Username / email dan password wajib diisi.';
                });
                return;
              }

              setDlgState(() {
                isLoading = true;
                inlineError = null;
              });

              try {
                final result = await onConfirm(identity, password);

                if (!ctx.mounted) return;

                switch (result) {
                  case RemoteWriteResult.ok:
                    Navigator.of(dlgCtx).pop();
                    onSuccess?.call();
                    setState(() {});
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(successMessage),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                    break;

                  case RemoteWriteResult.invalidCredentials:
                    passwordController.clear();
                    setDlgState(() {
                      isLoading = false;
                      inlineError = 'Username atau password salah';
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Username atau password salah'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                    break;

                  case RemoteWriteResult.notSupervisor:
                    setDlgState(() {
                      isLoading = false;
                      inlineError = 'Hanya SPV yang bisa mengubah lokasi';
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Hanya SPV yang bisa mengubah lokasi'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                    break;

                  case RemoteWriteResult.offline:
                    setDlgState(() {
                      isLoading = false;
                      inlineError = 'Tidak ada koneksi. Coba lagi saat online.';
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Tidak ada koneksi. Coba lagi saat online.',
                          ),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                    }
                    break;

                  case RemoteWriteResult.failed:
                    setDlgState(() {
                      isLoading = false;
                      inlineError = 'Gagal menyimpan. Coba lagi.';
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Gagal menyimpan. Coba lagi.'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                    break;
                }
              } catch (_) {
                if (ctx.mounted) {
                  setDlgState(() {
                    isLoading = false;
                    inlineError = 'Gagal menyimpan. Coba lagi.';
                  });
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Gagal menyimpan. Coba lagi.'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Konfirmasi SPV',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description.isNotEmpty) ...[
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (inlineError != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.dangerBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.danger,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                inlineError!,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    TextField(
                      controller: identityController,
                      enabled: !isLoading,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Username / email',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      enabled: !isLoading,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(
                        labelText: 'Password SPV',
                        isDense: true,
                      ),
                      onSubmitted: isLoading ? null : (_) => submit(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
                  onPressed: isLoading
                      ? null
                      : () => Navigator.of(dlgCtx).pop(),
                  child: const Text('Batal'),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 44,
                    minWidth: 88,
                  ),
                  child: ElevatedButton(
                    onPressed: isLoading ? null : submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: actionTitle == 'Hapus'
                          ? AppColors.danger
                          : AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(actionTitle),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
    final nameController = TextEditingController(
      text: existingLocation?.posName ?? '',
    );
    final addressController = TextEditingController(
      text: existingLocation?.fullAddress ?? '',
    );
    final cabangController = TextEditingController(
      text: existingLocation?.cabangName ?? _selectedBranch.name,
    );
    final tagController = TextEditingController(
      text: existingLocation?.locationTag ?? _selectedBranch.defaultLocationTag,
    );

    Color selectedColor = existingLocation?.tagColor ?? const Color(0xFFF59E0B);
    String? inlineError;
    bool isGeocoding = false;
    ({double lat, double lng})? previewPoint;

    showDialog(
      context: context,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    previewPoint != null
                        ? 'Pratinjau Titik Lokasi'
                        : (isEditing ? 'Edit Lokasi' : 'Tambah Lokasi Baru'),
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: previewPoint != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 320,
                            height: 160,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: FlutterMap(
                                options: MapOptions(
                                  initialCenter: LatLng(
                                    previewPoint!.lat,
                                    previewPoint!.lng,
                                  ),
                                  initialZoom: 16.0,
                                  interactionOptions: const InteractionOptions(
                                    flags: InteractiveFlag.none,
                                  ),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName:
                                        'com.bssparking.timemark.bssparking_timemark',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: LatLng(
                                          previewPoint!.lat,
                                          previewPoint!.lng,
                                        ),
                                        width: 36,
                                        height: 36,
                                        child: const Icon(
                                          Icons.location_pin,
                                          color: AppColors.danger,
                                          size: 36,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Titik peta mengikuti alamat ini. Kalau meleset, perjelas alamatnya lalu Simpan lagi.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (inlineError != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.dangerLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.dangerBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: AppColors.danger,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      inlineError!,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          TextField(
                            controller: nameController,
                            onChanged: (_) {
                              if (inlineError != null) {
                                setDlgState(() => inlineError = null);
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Nama Lokasi *',
                              hintText:
                                  'Misal: Pasar Bersehati Manado / Gate 1',
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: addressController,
                            maxLines: 2,
                            maxLength: 300,
                            onChanged: (_) {
                              if (inlineError != null) {
                                setDlgState(() => inlineError = null);
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Alamat Lokasi *',
                              hintText:
                                  'Contoh: Jl. Sam Ratulangi No. 5, Makassar',
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
                                    if (inlineError != null) {
                                      setDlgState(() => inlineError = null);
                                    }
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
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _palette.map((c) {
                              final isSel =
                                  selectedColor.toARGB32() == c.toARGB32();
                              return InkWell(
                                onTap: () =>
                                    setDlgState(() => selectedColor = c),
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
                                        color: isSel
                                            ? AppColors.textPrimary
                                            : Colors.black12,
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
                                        ? const Icon(
                                            Icons.check_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          )
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
                if (previewPoint != null) ...[
                  TextButton(
                    onPressed: () {
                      setDlgState(() {
                        previewPoint = null;
                      });
                    },
                    child: const Text('Ubah Alamat'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await _saveLocationFlow(
                        dlgCtx: dlgCtx,
                        isEditing: isEditing,
                        existingLocation: existingLocation,
                        name: nameController.text.trim(),
                        tag: tagController.text.trim().toUpperCase(),
                        cabang: cabangController.text.trim().isNotEmpty
                            ? cabangController.text.trim()
                            : _selectedBranch.name,
                        address: addressController.text.trim(),
                        color: selectedColor,
                        lat: previewPoint!.lat,
                        lng: previewPoint!.lng,
                      );
                    },
                    child: const Text('Lanjut Simpan'),
                  ),
                ] else ...[
                  TextButton(
                    onPressed: isGeocoding
                        ? null
                        : () => Navigator.of(dlgCtx).pop(),
                    child: const Text('Batal'),
                  ),
                  ElevatedButton(
                    onPressed: isGeocoding
                        ? null
                        : () async {
                            final name = nameController.text.trim();
                            final tag = tagController.text.trim();
                            final address = addressController.text.trim();

                            if (name.isEmpty ||
                                tag.isEmpty ||
                                address.isEmpty) {
                              setDlgState(() {
                                inlineError =
                                    'Nama Lokasi, Tag Card, dan Alamat wajib diisi.';
                              });
                              return;
                            }

                            if (isEditing &&
                                address ==
                                    existingLocation.fullAddress.trim() &&
                                (existingLocation.lat != 0.0 ||
                                    existingLocation.lng != 0.0)) {
                              await _saveLocationFlow(
                                dlgCtx: dlgCtx,
                                isEditing: isEditing,
                                existingLocation: existingLocation,
                                name: name,
                                tag: tag.toUpperCase(),
                                cabang: cabangController.text.trim().isNotEmpty
                                    ? cabangController.text.trim()
                                    : _selectedBranch.name,
                                address: address,
                                color: selectedColor,
                                lat: existingLocation.lat,
                                lng: existingLocation.lng,
                              );
                              return;
                            }

                            setDlgState(() {
                              isGeocoding = true;
                              inlineError = null;
                            });

                            final coords = await LocationService.geocodeAddress(
                              address,
                              _selectedBranch,
                            );

                            if (!dlgCtx.mounted) return;

                            if (coords == null) {
                              setDlgState(() {
                                isGeocoding = false;
                                inlineError =
                                    'Alamat tidak ditemukan di peta. Tambahkan nama jalan, kelurahan, atau kota.';
                              });
                              return;
                            }

                            setDlgState(() {
                              isGeocoding = false;
                              previewPoint = coords;
                            });
                          },
                    child: Text(
                      isGeocoding ? 'Mencari titik alamat...' : 'Simpan',
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveLocationFlow({
    required BuildContext dlgCtx,
    required bool isEditing,
    PosLocation? existingLocation,
    required String name,
    required String tag,
    required String cabang,
    required String address,
    required Color color,
    required double lat,
    required double lng,
  }) async {
    final pos = PosLocation(
      posId: isEditing
          ? existingLocation!.posId
          : '${_posPrefixFor(_selectedBranch)}${const Uuid().v4().substring(0, 6)}',
      posName: name,
      cabangName: cabang,
      locationTag: tag,
      fullAddress: address,
      tagColor: color,
      lat: lat,
      lng: lng,
      explicitBranch: _selectedBranch,
    );

    await _showSpvConfirmDialog(
      actionTitle: 'Simpan',
      description:
          'Masukkan kredensial SPV untuk menyimpan lokasi "${pos.posName}".',
      onConfirm: (identity, password) {
        return LocationService.saveLocationRemote(
          pos,
          identity: identity,
          password: password,
        );
      },
      successMessage: 'Lokasi tersimpan untuk semua HP',
      onSuccess: () {
        if (dlgCtx.mounted) {
          Navigator.of(dlgCtx).pop();
        }
      },
    );
  }

  void _confirmDelete(PosLocation pos) {
    _showSpvConfirmDialog(
      actionTitle: 'Hapus',
      description: 'Hapus lokasi "${pos.posName}" [${pos.locationTag}]?',
      onConfirm: (identity, password) {
        return LocationService.deleteLocationRemote(
          pos.posId,
          identity: identity,
          password: password,
        );
      },
      successMessage: 'Lokasi dihapus untuk semua HP',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSpv =
        AuthRepository.instance.currentUser?.role == UserRole.supervisor;
    final allLocations = LocationService.getLocationsByBranch(_selectedBranch);
    final currentPos = LocationService.currentPos;
    final isDark = ThemeService.isDarkMode(context);
    final scaffoldBg = isDark
        ? const Color(0xFF0B1120)
        : const Color(0xFFFAF8F5);
    final searchFill = isDark ? const Color(0xFF1E293B) : Colors.grey.shade100;
    final searchBorder = isDark
        ? const Color(0xFF334155)
        : Colors.grey.shade300;
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : AppColors.textPrimary;
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : AppColors.textSecondary;
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
          if (isSpv)
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : AppColors.cardBorder,
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
            if (!isSpv)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : AppColors.cardBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 16,
                        color: textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lokasi dikelola SPV. Minta SPV kalau ada lokasi baru.',
                          style: TextStyle(
                            fontSize: 12,
                            color: textMuted,
                            fontWeight: FontWeight.w500,
                          ),
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
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
              child: RefreshIndicator(
                onRefresh: _syncLocations,
                child: filteredLocations.isEmpty
                    ? LayoutBuilder(
                        builder: (context, constraints) => SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Center(
                              child: Text(
                                _searchQuery.isNotEmpty
                                    ? 'Tidak ada lokasi cocok dengan "$_searchQuery"'
                                    : 'Belum ada daftar lokasi',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredLocations.length,
                        separatorBuilder: (ctx, idx) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final pos = filteredLocations[index];
                          final isCurrent = pos.posId == currentPos.posId;

                          return Card(
                            color: cardBg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isCurrent
                                    ? AppColors.primary
                                    : cardBorder,
                                width: isCurrent ? 2 : 1,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
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
                                        fontWeight: isCurrent
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        color: isCurrent
                                            ? (isDark
                                                  ? const Color(0xFF38BDF8)
                                                  : AppColors.primary)
                                            : textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (isCurrent)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryLight
                                            .withValues(alpha: 0.1),
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
                              trailing: isSpv
                                  ? PopupMenuButton<String>(
                                      constraints: const BoxConstraints(
                                        minWidth: 180,
                                      ),
                                      onSelected: (val) {
                                        if (val == 'select') {
                                          LocationService.currentPos = pos;
                                          widget.onLocationSelected?.call(pos);
                                          setState(() {});
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Lokasi aktif diubah ke: ${pos.posName} [${pos.locationTag}]',
                                              ),
                                              backgroundColor:
                                                  AppColors.primary,
                                              duration: const Duration(
                                                seconds: 1,
                                              ),
                                            ),
                                          );
                                        } else if (val == 'edit') {
                                          _showLocationFormDialog(
                                            existingLocation: pos,
                                          );
                                        } else if (val == 'delete') {
                                          _confirmDelete(pos);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(
                                          value: 'select',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.check,
                                                size: 16,
                                                color: AppColors.primary,
                                              ),
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
                                              Icon(
                                                Icons.delete,
                                                size: 16,
                                                color: AppColors.danger,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Hapus',
                                                style: TextStyle(
                                                  color: AppColors.danger,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : null,
                              onTap: () {
                                LocationService.currentPos = pos;
                                widget.onLocationSelected?.call(pos);
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Lokasi aktif diubah ke: ${pos.posName} [${pos.locationTag}]',
                                    ),
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
            ),
          ],
        ),
      ),
    );
  }
}

/// Prefiks posId lokasi baru per cabang (pola lama MDO tanpa segmen cabang).
String _posPrefixFor(AppBranch branch) {
  switch (branch) {
    case AppBranch.bali:
      return 'POS-DPS-';
    case AppBranch.ho:
      return 'POS-HO-';
    case AppBranch.manado:
      return 'POS-';
  }
}
