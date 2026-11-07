import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/screens/login_screen.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../services/daily_task_service.dart';
import '../services/branch_service.dart';

class AuthRepository extends ChangeNotifier {
  static final AuthRepository instance = AuthRepository._internal();
  AuthRepository._internal();

  static const String sessionTokenPrefsKey = 'bss_session_token_v1';
  static const String offlineCredentialsPrefsKey = 'bss_offline_credentials_v1';
  static const String sessionExpiredMessage = 'Sesi habis, silakan login ulang.';
  static const String offlineOnlyPreviousLoginMessage =
      'Login offline hanya untuk akun yang pernah login online di HP ini.';
  static const String webOfflineUnsupportedMessage =
      'Login gagal. Periksa koneksi internet Anda.';

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static final RegExp _validIdentityRegex = RegExp(r'^[a-zA-Z0-9 ._@-]+$');
  static const int _pbkdfIterations = 10000;

  @visibleForTesting
  http.Client? httpClient;

  @visibleForTesting
  bool? isWebOverride;

  bool get _isWeb => isWebOverride ?? kIsWeb;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  String? _sessionToken;
  String? get sessionToken => _sessionToken;

  String? _lastErrorMessage;
  String? get lastErrorMessage => _lastErrorMessage;

  @visibleForTesting
  void setSessionTokenForTesting(String? token) {
    _sessionToken = token;
  }

  /// Decodes the `v1.<payloadB64>.<sigB64>` payload client-side to check `exp`.
  static bool isTokenUnexpired(String? token, {DateTime? now}) {
    if (token == null) return false;
    final clean = token.trim();
    final parts = clean.split('.');
    if (parts.length != 3 || parts[0] != 'v1' || parts[1].isEmpty || parts[2].isEmpty) {
      return false;
    }
    try {
      final normalized = base64Url.normalize(parts[1]);
      final payloadStr = utf8.decode(base64Url.decode(normalized));
      final decoded = jsonDecode(payloadStr);
      if (decoded is! Map<String, dynamic>) return false;
      final exp = decoded['exp'];
      if (exp is! num) return false;
      final nowSec = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
      return exp.toInt() > nowSec;
    } catch (_) {
      return false;
    }
  }

  static String _hashPassword(String saltBase64, String password) {
    List<int> data = utf8.encode('$saltBase64$password');
    for (var i = 0; i < _pbkdfIterations; i++) {
      data = sha256.convert(data).bytes;
    }
    return Digest(data).toString();
  }

  static bool _constantTimeEquals(String a, String b) {
    final aBytes = utf8.encode(a);
    final bBytes = utf8.encode(b);
    if (aBytes.length != bBytes.length) return false;
    var diff = 0;
    for (var i = 0; i < aBytes.length; i++) {
      diff |= aBytes[i] ^ bBytes[i];
    }
    return diff == 0;
  }

  Future<void> _saveOfflineCredential({
    required String cleanIdentity,
    required String cleanPassword,
    required UserModel user,
    required String token,
  }) async {
    if (_isWeb) return;
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> all = {};
    final raw = prefs.getString(offlineCredentialsPrefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          all = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    final rand = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => rand.nextInt(256));
    final saltBase64 = base64Encode(saltBytes);
    final hash = _hashPassword(saltBase64, cleanPassword);

    all[cleanIdentity] = {
      'user': user.toJson(),
      'salt': saltBase64,
      'hash': hash,
      'token': token,
    };

    await prefs.setString(offlineCredentialsPrefsKey, jsonEncode(all));
  }

  Future<bool> _tryOfflineLogin({
    required String cleanIdentity,
    required String cleanPassword,
  }) async {
    if (_isWeb) {
      _lastErrorMessage = webOfflineUnsupportedMessage;
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(offlineCredentialsPrefsKey);
    if (raw == null || raw.isEmpty) {
      _lastErrorMessage = offlineOnlyPreviousLoginMessage;
      return false;
    }

    Map<String, dynamic> all;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _lastErrorMessage = offlineOnlyPreviousLoginMessage;
        return false;
      }
      all = decoded;
    } catch (_) {
      _lastErrorMessage = offlineOnlyPreviousLoginMessage;
      return false;
    }

    final entry = all[cleanIdentity];
    if (entry is! Map<String, dynamic>) {
      _lastErrorMessage = offlineOnlyPreviousLoginMessage;
      return false;
    }

    final salt = entry['salt'] as String?;
    final storedHash = entry['hash'] as String?;
    final userJson = entry['user'];
    if (salt == null ||
        salt.isEmpty ||
        storedHash == null ||
        storedHash.isEmpty ||
        userJson is! Map) {
      _lastErrorMessage = offlineOnlyPreviousLoginMessage;
      return false;
    }

    final computedHash = _hashPassword(salt, cleanPassword);
    if (!_constantTimeEquals(computedHash, storedHash)) {
      _lastErrorMessage = 'Username atau password salah.';
      return false;
    }

    final user = UserModel.fromJson(Map<String, dynamic>.from(userJson));
    final branch = BranchService.determineBranch(
      cabang: user.cabangName,
      email: user.email,
      username: cleanIdentity,
      name: user.nama,
      fallback: BranchService.instance.currentBranch,
    );
    await BranchService.instance.setBranch(branch);

    final cachedToken = entry['token'] as String?;
    if (cachedToken != null && isTokenUnexpired(cachedToken)) {
      _sessionToken = cachedToken;
      await prefs.setString(sessionTokenPrefsKey, cachedToken);
    } else {
      _sessionToken = null;
      await prefs.remove(sessionTokenPrefsKey);
    }

    _currentUser = user;
    await StorageService.saveUser(user);
    await StorageService.saveLastTechnicianName(user.nama);
    _lastErrorMessage = null;
    notifyListeners();
    return true;
  }

  /// Server-side login via Supabase Edge Function `auth-login` (with Android offline fallback)
  Future<bool> loginWithPassword({
    required String identity,
    required String password,
  }) async {
    _lastErrorMessage = null;
    final cleanIdentity = identity.trim().toLowerCase();
    final cleanPass = password.trim();
    if (cleanIdentity.isEmpty ||
        cleanIdentity.length > 64 ||
        !_validIdentityRegex.hasMatch(cleanIdentity) ||
        cleanPass.isEmpty ||
        cleanPass.length > 128) {
      _lastErrorMessage = 'Username atau password salah.';
      return false;
    }

    try {
      final uri = Uri.parse('${DailyTaskService.baseUrl}/functions/v1/auth-login');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'apikey': DailyTaskService.anonKey,
        'Authorization': 'Bearer ${DailyTaskService.anonKey}',
      };
      final body = jsonEncode({
        'identity': cleanIdentity,
        'password': cleanPass,
      });

      final client = httpClient;
      final res = await (client != null
              ? client.post(uri, headers: headers, body: body)
              : http.post(uri, headers: headers, body: body))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is! Map<String, dynamic>) {
          _lastErrorMessage = 'Username atau password salah.';
          return false;
        }
        final token = (decoded['token'] as String? ?? '').trim();
        final record = decoded['user'];
        if (token.isEmpty || record is! Map<String, dynamic>) {
          _lastErrorMessage = 'Username atau password salah.';
          return false;
        }

        final roleStr = (record['role'] as String? ?? 'technician').toLowerCase();
        final role = (roleStr == 'spv' ||
                roleStr == 'supervisor' ||
                roleStr == 'ho' ||
                roleStr == 'headoffice')
            ? UserRole.supervisor
            : UserRole.petugas;
        final usernameStr = record['username'] as String? ?? cleanIdentity;
        final name = record['nama'] as String? ?? record['name'] as String? ?? usernameStr;
        final email = record['email'] as String? ?? cleanIdentity;
        final cabangStr = record['cabang'] as String? ?? record['cabang_name'] as String?;
        final branch = BranchService.determineBranch(
          cabang: cabangStr,
          email: email,
          username: usernameStr,
          name: name,
          fallback: BranchService.instance.currentBranch,
        );

        await BranchService.instance.setBranch(branch);

        final user = UserModel(
          id: record['id'] as String? ?? 'usr_sb',
          nama: name,
          npp:
              '${role == UserRole.supervisor ? 'BSS-SPV' : 'BSS-TEK'}-${branch == AppBranch.manado ? '' : '${branch.code}-'}01',
          email: email,
          role: role,
          posId: branch == AppBranch.manado ? 'POS-01' : 'POS-${branch.code}-01',
          posName: branch == AppBranch.manado ? 'Pos Gate Utama' : branch.defaultLocationTag,
          cabangName: branch.name,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(sessionTokenPrefsKey, token);
        _sessionToken = token;
        DailyTaskService.setAuthToken(null);

        _currentUser = user;
        await StorageService.saveUser(user);
        await StorageService.saveLastTechnicianName(name);
        await _saveOfflineCredential(
          cleanIdentity: cleanIdentity,
          cleanPassword: cleanPass.toLowerCase(),
          user: user,
          token: token,
        );
        _lastErrorMessage = null;
        notifyListeners();
        return true;
      } else if (res.statusCode == 400 || res.statusCode == 401 || res.statusCode == 403) {
        _lastErrorMessage = 'Username atau password salah.';
        return false;
      } else {
        debugPrint('[AuthRepository] auth-login status: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[AuthRepository] Online login error, checking fallback: $e');
    }

    return _tryOfflineLogin(
      cleanIdentity: cleanIdentity,
      cleanPassword: cleanPass.toLowerCase(),
    );
  }

  Future<void> logout() async {
    _currentUser = null;
    _sessionToken = null;
    DailyTaskService.stopRealtimeListener();
    DailyTaskService.setAuthToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(sessionTokenPrefsKey);
    await StorageService.clearUser();
    await StorageService.remove('user');
    notifyListeners();
  }

  /// Clears session on HTTP 401 from any edge function, routes to login, and shows snackbar.
  Future<void> handleUnauthorizedSession() async {
    await logout();
    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger != null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text(sessionExpiredMessage)),
      );
    }
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(sessionTokenPrefsKey);
    final savedUser = StorageService.getUser();

    if (savedUser == null || !isTokenUnexpired(token)) {
      await logout();
      return;
    }

    _currentUser = savedUser;
    _sessionToken = token;
    DailyTaskService.setAuthToken(null);
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
}
