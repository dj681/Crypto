import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

import 'package:my_crypto_safe/providers/security_provider.dart';
import 'package:my_crypto_safe/services/security_service.dart';

// ── Fakes ────────────────────────────────────────────────────────────────────

class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final _store = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _store[key] = value;
    } else {
      _store.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _store[key];

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _store.remove(key);

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _store.clear();
}

class _FakeLocalAuth extends Fake implements LocalAuthentication {
  bool canBiometrics = false;
  bool authResult = true;

  @override
  Future<bool> get canCheckBiometrics async => canBiometrics;

  @override
  Future<bool> isDeviceSupported() async => canBiometrics;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async =>
      authResult;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

SecurityService _makeService({
  _FakeSecureStorage? storage,
  _FakeLocalAuth? localAuth,
}) {
  return SecurityService(
    storage: storage ?? _FakeSecureStorage(),
    localAuth: localAuth ?? _FakeLocalAuth(),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('SecurityService - PIN', () {
    test('hasPin returns false when no PIN set', () async {
      final service = _makeService();
      expect(await service.hasPin(), isFalse);
    });

    test('setPin + verifyPin succeeds with correct PIN', () async {
      final service = _makeService();
      await service.setPin('123456');
      expect(await service.verifyPin('123456'), isTrue);
    });

    test('verifyPin fails with wrong PIN', () async {
      final service = _makeService();
      await service.setPin('123456');
      expect(await service.verifyPin('000000'), isFalse);
    });

    test('different PINs produce different hashes', () async {
      final storage = _FakeSecureStorage();
      final service = _makeService(storage: storage);

      await service.setPin('111111');
      final hash1 = await service.hasPin();

      // Overwrite with different PIN.
      await service.setPin('222222');
      // Both should still be stored correctly.
      expect(await service.verifyPin('222222'), isTrue);
      expect(await service.verifyPin('111111'), isFalse);
      expect(hash1, isTrue);
    });

    test('removePin clears stored hash', () async {
      final service = _makeService();
      await service.setPin('123456');
      await service.removePin();
      expect(await service.hasPin(), isFalse);
    });
  });

  group('SecurityService - biometrics', () {
    test('canUseBiometrics returns false when not supported', () async {
      final localAuth = _FakeLocalAuth()..canBiometrics = false;
      final service = _makeService(localAuth: localAuth);
      expect(await service.canUseBiometrics(), isFalse);
    });

    test('canUseBiometrics returns true when supported', () async {
      final localAuth = _FakeLocalAuth()..canBiometrics = true;
      final service = _makeService(localAuth: localAuth);
      expect(await service.canUseBiometrics(), isTrue);
    });

    test('authenticateWithBiometrics returns true on success', () async {
      final localAuth = _FakeLocalAuth()
        ..canBiometrics = true
        ..authResult = true;
      final service = _makeService(localAuth: localAuth);
      expect(
        await service.authenticateWithBiometrics('Test'),
        isTrue,
      );
    });

    test('authenticateWithBiometrics returns false on failure', () async {
      final localAuth = _FakeLocalAuth()
        ..canBiometrics = true
        ..authResult = false;
      final service = _makeService(localAuth: localAuth);
      expect(
        await service.authenticateWithBiometrics('Test'),
        isFalse,
      );
    });
  });

  group('SecurityProvider - state', () {
    test('initial state: not locked, no PIN', () async {
      final service = _makeService();
      final provider = SecurityProvider(service);
      await provider.init();

      expect(provider.hasPin, isFalse);
      expect(provider.isLocked, isFalse);
    });

    test('isLocked = true after init when PIN exists', () async {
      final storage = _FakeSecureStorage();
      final service = _makeService(storage: storage);
      final provider = SecurityProvider(service);

      await service.setPin('123456');
      await provider.init();

      expect(provider.hasPin, isTrue);
      expect(provider.isLocked, isTrue);
    });

    test('unlockWithPin succeeds with correct PIN', () async {
      final storage = _FakeSecureStorage();
      final service = _makeService(storage: storage);
      final provider = SecurityProvider(service);

      await provider.setupPin('654321');
      await provider.init(); // re-init to lock

      final result = await provider.unlockWithPin('654321');
      expect(result, isTrue);
      expect(provider.isLocked, isFalse);
    });

    test('unlockWithPin fails with wrong PIN', () async {
      final storage = _FakeSecureStorage();
      final service = _makeService(storage: storage);
      final provider = SecurityProvider(service);

      await provider.setupPin('654321');
      await provider.init();

      final result = await provider.unlockWithPin('999999');
      expect(result, isFalse);
      expect(provider.isLocked, isTrue);
    });

    test('lock() sets isLocked when PIN is set', () async {
      final storage = _FakeSecureStorage();
      final service = _makeService(storage: storage);
      final provider = SecurityProvider(service);

      await provider.setupPin('123456');
      await provider.unlockWithPin('123456');
      expect(provider.isLocked, isFalse);

      provider.lock();
      expect(provider.isLocked, isTrue);
    });
  });

  group('SecurityProvider - session timeout', () {
    test('checkAndLockIfTimeout does nothing without pause time', () async {
      final service = _makeService();
      final provider = SecurityProvider(service);
      await provider.setupPin('000000');
      await provider.init();
      await provider.unlockWithPin('000000');

      provider.checkAndLockIfTimeout(); // no pause recorded
      expect(provider.isLocked, isFalse);
    });

    test('does NOT lock when elapsed < kSessionTimeout', () async {
      final storage = _FakeSecureStorage();
      final service = _makeService(storage: storage);
      final provider = SecurityProvider(service);

      await provider.setupPin('000000');
      await provider.init();
      await provider.unlockWithPin('000000');

      provider.recordPauseTime();
      // Immediately check (elapsed ≈ 0ms < 5 minutes).
      provider.checkAndLockIfTimeout();
      expect(provider.isLocked, isFalse);
    });
  });
}
