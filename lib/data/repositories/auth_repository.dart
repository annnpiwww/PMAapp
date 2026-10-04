import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../services/location_service.dart';
import '../services/daily_task_service.dart';

class AuthRepository extends ChangeNotifier {
  static final AuthRepository instance = AuthRepository._internal();
  AuthRepository._internal();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// Login resmi via PocketBase Backend (Online dengan offline session fallback)
  Future<bool> loginWithPassword({
    required String identity,
    required String password,
  }) async {
    final cleanIdentity = identity.trim().toLowerCase();
    // 1. Coba koneksi ke backend PocketBase
    try {
      final uri = Uri.parse('${DailyTaskService.baseUrl}/api/collections/users/auth-with-password');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identity': cleanIdentity,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = data['token'] as String?;
        final record = data['record'] as Map<String, dynamic>;

        DailyTaskService.setAuthToken(token);

        final roleStr = (record['role'] as String? ?? 'teknisi').toLowerCase();
        final role = roleStr == 'spv' ? UserRole.supervisor : UserRole.petugas;
        final name = record['name'] as String? ?? record['nama_lengkap'] as String? ?? cleanIdentity;
        final email = record['email'] as String? ?? cleanIdentity;

        final user = UserModel(
          id: record['id'] as String? ?? 'usr_pb',
          nama: name,
          npp: role == UserRole.supervisor ? 'BSS-SPV-01' : 'BSS-TEK-01',
          email: email,
          role: role,
          posId: 'POS-01',
          posName: 'Pos Gate Utama',
          cabangName: 'KC Manado',
        );

        _currentUser = user;
        await StorageService.saveUser(user);
        await StorageService.saveLastTechnicianName(name);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[AuthRepository] Online login error, checking fallback: $e');
    }

    // 2. Offline Fallback: Cek kredensial default lokal jika internet dead-zone
    final hardcodedAccounts = [
      {'user': 'farhan lakoro', 'pass': 'flakoro05', 'role': UserRole.supervisor, 'name': 'Farhan Lakoro'},
      {'user': 'farhan@bssparking.id', 'pass': 'flakoro05', 'role': UserRole.supervisor, 'name': 'Farhan Lakoro'},
      {'user': 'ryan lumasuge', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Ryan Lumasuge'},
      {'user': 'ryan@bssparking.id', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Ryan Lumasuge'},
      {'user': 'raldy sangkop', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Raldy Sangkop'},
      {'user': 'raldy@bssparking.id', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Raldy Sangkop'},
      {'user': 'junifer manua', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Junifer Manua'},
      {'user': 'junifer@bssparking.id', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Junifer Manua'},
      {'user': 'alessandro', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Alessandro'},
      {'user': 'alessandro@bssparking.id', 'pass': 'teknisi123', 'role': UserRole.petugas, 'name': 'Alessandro'},
    ];

    for (final acc in hardcodedAccounts) {
      if (acc['user'] == cleanIdentity && (acc['pass'] as String).toLowerCase() == password.toLowerCase()) {
        final role = acc['role'] as UserRole;
        final name = acc['name'] as String;
        final user = UserModel(
          id: 'usr_${name.replaceAll(' ', '_').toLowerCase()}',
          nama: name,
          npp: role == UserRole.supervisor ? 'BSS-SPV-01' : 'BSS-TEK-01',
          email: '$cleanIdentity@bssparking.id',
          role: role,
          posId: 'POS-01',
          posName: 'Pos Gate Utama',
          cabangName: 'KC Manado',
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
    final authToken = StorageService.getString('pb_auth_token');
    final savedUser = StorageService.getUser();

    // Hanya anggap login jika token session auth aktif ada dan user valid tersimpan
    if (authToken != null && authToken.isNotEmpty && savedUser != null) {
      _currentUser = savedUser;
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
