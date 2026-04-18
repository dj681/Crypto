import 'package:flutter/foundation.dart';

import '../services/security_service.dart';

/// How the app session is currently locked.
enum LockReason { none, pinRequired, biometricRequired }

/// Session timeout before the app auto-locks.
const Duration kSessionTimeout = Duration(minutes: 5);

/// Manages session state: PIN, biometrics, and inactivity locking.
class SecurityProvider extends ChangeNotifier {
  SecurityProvider(this._service);

  final SecurityService _service;

  bool _isLocked = false;
  bool _hasPin = false;
  bool _biometricsAvailable = false;
  DateTime? _pausedAt;

  bool get isLocked => _isLocked;
  bool get hasPin => _hasPin;
  bool get biometricsAvailable => _biometricsAvailable;

  // ── initialise ────────────────────────────────────────────────────────────

  Future<void> init() async {
    var hasPin = false;
    var biometricsAvailable = false;

    try {
      hasPin = await _service.hasPin();
    } catch (e, st) {
      debugPrint('SecurityProvider.init failed during hasPin(): $e\n$st');
    }

    try {
      biometricsAvailable = await _service.canUseBiometrics();
    } catch (e, st) {
      debugPrint(
        'SecurityProvider.init failed during canUseBiometrics(): $e\n$st',
      );
    }

    _hasPin = hasPin;
    _biometricsAvailable = biometricsAvailable;
    // Lock the app on startup if a PIN has been set.
    _isLocked = _hasPin;
    notifyListeners();
  }

  // ── PIN ───────────────────────────────────────────────────────────────────

  Future<void> setupPin(String pin) async {
    await _service.setPin(pin);
    _hasPin = true;
    notifyListeners();
  }

  /// Returns true when the supplied PIN is correct and unlocks the session.
  Future<bool> unlockWithPin(String pin) async {
    final ok = await _service.verifyPin(pin);
    if (ok) {
      _isLocked = false;
      notifyListeners();
    }
    return ok;
  }

  Future<void> removePin() async {
    await _service.removePin();
    _hasPin = false;
    notifyListeners();
  }

  // ── biometrics ────────────────────────────────────────────────────────────

  /// Returns true when biometric authentication succeeds and unlocks the session.
  Future<bool> unlockWithBiometrics() async {
    final ok = await _service.authenticateWithBiometrics(
      'Déverrouillez My Crypto Safe',
    );
    if (ok) {
      _isLocked = false;
      notifyListeners();
    }
    return ok;
  }

  // ── session lifecycle ─────────────────────────────────────────────────────

  /// Called when the app goes to background.
  void recordPauseTime() {
    _pausedAt = DateTime.now();
  }

  /// Called when the app resumes.  Locks the session if the timeout elapsed.
  void checkAndLockIfTimeout() {
    if (!_hasPin) return;
    if (_pausedAt == null) return;
    final elapsed = DateTime.now().difference(_pausedAt!);
    if (elapsed >= kSessionTimeout) {
      _isLocked = true;
      notifyListeners();
    }
    _pausedAt = null;
  }

  /// Manually lock the session (e.g. from the settings screen).
  void lock() {
    if (!_hasPin) return;
    _isLocked = true;
    notifyListeners();
  }

  /// Force-unlock (used internally after successful auth).
  void unlock() {
    _isLocked = false;
    notifyListeners();
  }
}
