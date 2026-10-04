import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class VerificationCodeGenerator {
  static final Random _random = Random.secure();
  static int _counter = 0;

  /// Generates verification code format: BSS-XXXXXXXX (8 uppercase chars)
  static String generateCode({
    required DateTime timestamp,
    double? lat,
    double? lng,
    String? userId,
  }) {
    _counter = (_counter + 1) & 0x7FFFFFFF;
    final salt = _random.nextInt(0x7FFFFFFF).toRadixString(16);
    final rawString = '${timestamp.microsecondsSinceEpoch}_${lat ?? 0}_${lng ?? 0}_${userId ?? "petugas"}_${salt}_$_counter';
    final bytes = utf8.encode(rawString);
    final digest = sha256.convert(bytes);
    final hex = digest.toString().toUpperCase();

    // Take first 8 alphanumeric uppercase characters
    final codeSuffix = hex.substring(0, 8);
    return 'BSS-$codeSuffix';
  }
}
