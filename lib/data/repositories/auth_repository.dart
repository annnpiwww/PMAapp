import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../services/location_service.dart';
import '../services/daily_task_service.dart';
import '../services/branch_service.dart';

class AuthRepository extends ChangeNotifier {
  static final AuthRepository instance = AuthRepository._internal();
  AuthRepository._internal();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// Login resmi via Supabase Backend (Online dengan offline session fallback)
  Future<bool> loginWithPassword({
    required String identity,
    required String password,
  }) async {
    final cleanIdentity = identity.trim().toLowerCase();
    final cleanPass = password.trim();
    if (cleanIdentity.isEmpty || cleanPass.isEmpty) return false;

    final userPrefix = cleanIdentity.contains('@') ? cleanIdentity.split('@').first : cleanIdentity;

    // 1. Coba koneksi ke backend Supabase (table public.app_users)
    try {
      final orFilters = <String>[
        'username.ilike.$cleanIdentity',
        'email.ilike.$cleanIdentity',
        'nama.ilike.$cleanIdentity',
        if (cleanIdentity.length >= 3) 'nama.ilike.*$cleanIdentity*',
        if (cleanIdentity.length >= 3) 'username.ilike.*$cleanIdentity*',
        if (userPrefix.isNotEmpty && userPrefix != cleanIdentity) ...[
          'username.ilike.$userPrefix',
          'email.ilike.*$userPrefix*',
        ],
      ];

      final uri = Uri.parse('${DailyTaskService.baseUrl}/rest/v1/app_users').replace(
        queryParameters: {
          'or': '(${orFilters.join(',')})',
          'select': '*',
          'limit': '1',
        },
      );
      final res = await http.get(
        uri,
        headers: DailyTaskService.getHeaders,
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List items = decoded is List ? decoded : [];
        if (items.isNotEmpty) {
          final record = items.first as Map<String, dynamic>;
          final dbPassword = (record['password'] as String? ?? '').trim();
          final userName = (record['username'] as String? ?? '').toLowerCase();
          final userNama = (record['nama'] as String? ?? '').toLowerCase();

          bool isPasswordMatch = dbPassword.toLowerCase() == cleanPass.toLowerCase();
          if (!isPasswordMatch) {
            // Dukungan alias password supervisor Farhan & demo
            final isFarhan = userName == 'farhan' || userNama.contains('farhan');
            if (isFarhan &&
                (cleanPass.toLowerCase() == 'flakoro05' ||
                    cleanPass.toLowerCase() == 'spv123' ||
                    cleanPass.toLowerCase() == 'farhan123')) {
              isPasswordMatch = true;
            }
          }

          if (isPasswordMatch) {
            final roleStr = (record['role'] as String? ?? 'teknisi').toLowerCase();
            final role = roleStr == 'spv' ? UserRole.supervisor : UserRole.petugas;
            final name = record['nama'] as String? ?? record['name'] as String? ?? cleanIdentity;
            final email = record['email'] as String? ?? cleanIdentity;
            final cabangStr = record['cabang'] as String? ?? record['cabang_name'] as String?;
            final branch = BranchService.determineBranch(
              cabang: cabangStr,
              email: email,
              username: cleanIdentity,
              name: name,
              fallback: BranchService.instance.currentBranch,
            );

            await BranchService.instance.setBranch(branch);

            final user = UserModel(
              id: record['id'] as String? ?? 'usr_sb',
              nama: name,
              npp: role == UserRole.supervisor
                  ? (branch == AppBranch.bali ? 'BSS-SPV-DPS-01' : 'BSS-SPV-01')
                  : (branch == AppBranch.bali ? 'BSS-TEK-DPS-01' : 'BSS-TEK-01'),
              email: email,
              role: role,
              posId: branch == AppBranch.bali ? 'POS-DPS-01' : 'POS-01',
              posName: branch == AppBranch.bali ? 'PBKD' : 'Pos Gate Utama',
              cabangName: branch.name,
            );

            DailyTaskService.setAuthToken('sb_token_${user.id}');
            _currentUser = user;
            await StorageService.saveUser(user);
            await StorageService.saveLastTechnicianName(name);
            notifyListeners();
            return true;
          } else {
            debugPrint('[AuthRepository] Password mismatch untuk user: $cleanIdentity');
          }
        }
      } else {
        debugPrint('[AuthRepository] Supabase login query status: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[AuthRepository] Online login error, checking fallback: $e');
    }

    // 2. Offline Fallback: Akun lokal tetap aktif untuk memastikan aplikasi bisa login
    // saat terjadi kendala koneksi, mati lampu, atau basement tanpa sinyal di release APK & Vercel.
    final hardcodedAccounts = [
      // --- KC Manado Accounts ---
      {'user': 'farhan lakoro', 'pass': 'flakoro05', 'role': UserRole.supervisor, 'name': 'Farhan Lakoro', 'branch': AppBranch.manado},
      {'user': 'farhan@pma.com', 'pass': 'flakoro05', 'role': UserRole.supervisor, 'name': 'Farhan Lakoro', 'branch': AppBranch.manado},
      {'user': 'farhan@bssparking.id', 'pass': 'flakoro05', 'role': UserRole.supervisor, 'name': 'Farhan Lakoro', 'branch': AppBranch.manado},
      {'user': 'farhan', 'pass': 'flakoro05', 'role': UserRole.supervisor, 'name': 'Farhan Lakoro', 'branch': AppBranch.manado},

      {'user': 'ryan lumasuge', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Ryan Lumasuge', 'branch': AppBranch.manado},
      {'user': 'ryan@pma.com', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Ryan Lumasuge', 'branch': AppBranch.manado},
      {'user': 'ryan@bssparking.id', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Ryan Lumasuge', 'branch': AppBranch.manado},
      {'user': 'ryan', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Ryan Lumasuge', 'branch': AppBranch.manado},

      {'user': 'raldy sangkop', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Raldy Sangkop', 'branch': AppBranch.manado},
      {'user': 'raldy@pma.com', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Raldy Sangkop', 'branch': AppBranch.manado},
      {'user': 'raldy@bssparking.id', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Raldy Sangkop', 'branch': AppBranch.manado},
      {'user': 'raldy', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Raldy Sangkop', 'branch': AppBranch.manado},

      {'user': 'junifer manua', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Junifer Manua', 'branch': AppBranch.manado},
      {'user': 'junifer@pma.com', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Junifer Manua', 'branch': AppBranch.manado},
      {'user': 'junifer@bssparking.id', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Junifer Manua', 'branch': AppBranch.manado},
      {'user': 'junifer', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Junifer Manua', 'branch': AppBranch.manado},

      {'user': 'alessandro sulistyo', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Alessandro Sulistyo', 'branch': AppBranch.manado},
      {'user': 'ale@pma.com', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Alessandro Sulistyo', 'branch': AppBranch.manado},
      {'user': 'alessandro@bssparking.id', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Alessandro Sulistyo', 'branch': AppBranch.manado},
      {'user': 'ale', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Alessandro Sulistyo', 'branch': AppBranch.manado},

      // --- KC Bali Accounts ---
      // SPV: Indra Yohana
      {'user': 'indra@pma.com', 'pass': 'spvbali', 'role': UserRole.supervisor, 'name': 'Indra Yohana', 'branch': AppBranch.bali},
      {'user': 'indra', 'pass': 'spvbali', 'role': UserRole.supervisor, 'name': 'Indra Yohana', 'branch': AppBranch.bali},
      {'user': 'i putu indra yohana', 'pass': 'spvbali', 'role': UserRole.supervisor, 'name': 'Indra Yohana', 'branch': AppBranch.bali},

      // Teknisi 1: Putu Hyan Parta Wijaya
      {'user': 'parta@pma.com', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Putu Hyan Parta Wijaya', 'branch': AppBranch.bali},
      {'user': 'parta', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Putu Hyan Parta Wijaya', 'branch': AppBranch.bali},
      {'user': 'putu hyan parta wijaya', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Putu Hyan Parta Wijaya', 'branch': AppBranch.bali},

      // Teknisi 2: Alif Candra Triantoro
      {'user': 'toro@pma.com', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Alif Candra Triantoro', 'branch': AppBranch.bali},
      {'user': 'toro', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Alif Candra Triantoro', 'branch': AppBranch.bali},
      {'user': 'alif candra triantoro', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Alif Candra Triantoro', 'branch': AppBranch.bali},

      // Teknisi 3: I Putu Gede Suardana Putra
      {'user': 'suardana@pma.com', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'I PUTU GEDE SUARDANA PUTRA', 'branch': AppBranch.bali},
      {'user': 'suardana', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'I PUTU GEDE SUARDANA PUTRA', 'branch': AppBranch.bali},
      {'user': 'i putu gede suardana putra', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'I PUTU GEDE SUARDANA PUTRA', 'branch': AppBranch.bali},

      // Teknisi 4: Aditya Caesar Bagaskara
      {'user': 'dika@pma.com', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'ADITYA CAESAR BAGASKARA', 'branch': AppBranch.bali},
      {'user': 'dika', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'ADITYA CAESAR BAGASKARA', 'branch': AppBranch.bali},
      {'user': 'aditya caesar bagaskara', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'ADITYA CAESAR BAGASKARA', 'branch': AppBranch.bali},

      // Teknisi 5: Anak Agung Gede Agung Yustikawangsa
      {'user': 'cokagung@pma.com', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'ANAK AGUNG GEDE AGUNG YUSTIKAWANGSA', 'branch': AppBranch.bali},
      {'user': 'cokagung', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'ANAK AGUNG GEDE AGUNG YUSTIKAWANGSA', 'branch': AppBranch.bali},
      {'user': 'anak agung gede agung yustikawangsa', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'ANAK AGUNG GEDE AGUNG YUSTIKAWANGSA', 'branch': AppBranch.bali},
    ];

    for (final acc in hardcodedAccounts) {
      final accUser = (acc['user'] as String).toLowerCase();
      final accName = (acc['name'] as String).toLowerCase();
      final accPass = (acc['pass'] as String).toLowerCase();

      final matchesIdentity = accUser == cleanIdentity ||
          accUser == userPrefix ||
          accName == cleanIdentity ||
          (cleanIdentity.length >= 4 && accName.contains(cleanIdentity));

      final cleanPassLower = cleanPass.toLowerCase();
      final matchesPassword = accPass == cleanPassLower ||
          (accUser.contains('farhan') &&
              (cleanPassLower == 'flakoro05' ||
                  cleanPassLower == 'spv123' ||
                  cleanPassLower == 'farhan123'));

      if (matchesIdentity && matchesPassword) {
        final role = acc['role'] as UserRole;
        final name = acc['name'] as String;
        final branch = (acc['branch'] as AppBranch?) ?? AppBranch.manado;
        await BranchService.instance.setBranch(branch);

        final emailStr = cleanIdentity.contains('@')
            ? cleanIdentity
            : (branch == AppBranch.bali ? '$cleanIdentity@pma.com' : '$cleanIdentity@bssparking.id');

        final user = UserModel(
          id: 'usr_${name.replaceAll(' ', '_').toLowerCase()}',
          nama: name,
          npp: role == UserRole.supervisor
              ? (branch == AppBranch.bali ? 'BSS-SPV-DPS-01' : 'BSS-SPV-01')
              : (branch == AppBranch.bali ? 'BSS-TEK-DPS-01' : 'BSS-TEK-01'),
          email: emailStr,
          role: role,
          posId: branch == AppBranch.bali ? 'POS-DPS-01' : 'POS-01',
          posName: branch == AppBranch.bali ? 'PBKD' : 'Pos Gate Utama',
          cabangName: branch.name,
        );
        _currentUser = user;
        await StorageService.saveUser(user);
        await StorageService.saveLastTechnicianName(name);
        notifyListeners();
        return true;
      }
    }

    return false;
  }

  Future<void> logout() async {
    _currentUser = null;
    DailyTaskService.stopRealtimeListener();
    DailyTaskService.setAuthToken(null);
    await StorageService.clearUser();
    await StorageService.remove('user');
    notifyListeners();
  }

  static final List<UserModel> demoUsers = [
    UserModel(
      id: 'usr_001',
      nama: 'Farhan Lakoro',
      npp: 'BSS-MN-104',
      email: 'farhan.lakoro@bssparking.com',
      role: UserRole.petugas,
      posId: 'POS-PBM-01',
      posName: 'Pasar Bersehati Manado',
      cabangName: 'KC BSG',
    ),
    UserModel(
      id: 'usr_002',
      nama: 'Jefri Wowor',
      npp: 'BSS-SPV-02',
      email: 'jefri.wowor@bssparking.com',
      role: UserRole.supervisor,
      posId: 'POS-PBM-01',
      posName: 'Pasar Bersehati Manado',
      cabangName: 'KC BSG',
    ),
    UserModel(
      id: 'usr_003',
      nama: 'Siti Rahmawati',
      npp: 'BSS-HO-01',
      email: 'siti.rahmawati@bssparking.com',
      role: UserRole.ho,
      posId: 'POS-PBM-01',
      posName: 'Pasar Bersehati Manado',
      cabangName: 'KC BSG',
    ),
  ];

  Future<void> init() async {
    final authToken = StorageService.getString('sb_auth_token') ?? StorageService.getString('pb_auth_token');
    final savedUser = StorageService.getUser();

    // Pertahankan session jika user valid tersimpan di local storage
    if (savedUser != null) {
      _currentUser = savedUser;
      if (authToken != null && authToken.isNotEmpty) {
        DailyTaskService.setAuthToken(authToken);
      }
    } else {
      _currentUser = null;
    }
    notifyListeners();
  }

  Future<void> syncTechnicianName(String nama) async {
    final clean = nama.trim();
    if (clean.isEmpty) return;
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(nama: clean);
      await StorageService.saveUser(_currentUser!);
    }
    await StorageService.saveLastTechnicianName(clean);
    notifyListeners();
  }

  Future<void> login(UserModel user) async {
    _currentUser = user;
    await StorageService.saveUser(user);
    notifyListeners();
  }

  Future<void> updateProfile({
    required String nama,
    required String npp,
    required String email,
  }) async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(
      nama: nama,
      npp: npp,
      email: email,
    );
    await StorageService.saveUser(_currentUser!);
    await StorageService.saveLastTechnicianName(nama);
    notifyListeners();
  }

  Future<void> switchPos(PosLocation pos) async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(
      posId: pos.posId,
      posName: pos.posName,
      cabangName: pos.cabangName,
    );
    LocationService.currentPos = pos;
    await StorageService.saveUser(_currentUser!);
    notifyListeners();
  }
}
