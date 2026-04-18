import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Keys used in FlutterSecureStorage.
class _Keys {
  static const String pinHash = 'security_pin_hash';
}

/// Handles PIN verification and biometric authentication.
class SecurityService {
  SecurityService({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _localAuth = localAuth ?? LocalAuthentication();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  // ── PIN ───────────────────────────────────────────────────────────────────

  static String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  /// Stores [pin] as a SHA-256 hash.
  Future<void> setPin(String pin) async {
    assert(pin.isNotEmpty);
    await _storage.write(key: _Keys.pinHash, value: _hashPin(pin));
  }

  /// Returns true when [pin] matches the stored hash.
  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _Keys.pinHash);
    if (stored == null) return false;
    return stored == _hashPin(pin);
  }

  /// Removes the stored PIN hash.
  Future<void> removePin() => _storage.delete(key: _Keys.pinHash);

  /// Returns true when a PIN hash is stored.
  Future<bool> hasPin() async {
    final stored = await _storage.read(key: _Keys.pinHash);
    return stored != null && stored.isNotEmpty;
  }

  // ── biometrics ────────────────────────────────────────────────────────────

  /// Returns true when the device can perform biometric authentication.
  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Prompts the user for biometric / device authentication.
  /// Returns true on success.
  Future<bool> authenticateWithBiometrics(String localizedReason) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
