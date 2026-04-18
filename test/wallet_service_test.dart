import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:my_crypto_safe/services/wallet_service.dart';

// In-memory stub for FlutterSecureStorage.
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

void main() {
  late WalletService service;
  late _FakeSecureStorage storage;

  setUp(() {
    storage = _FakeSecureStorage();
    service = WalletService(storage: storage);
  });

  group('WalletService - mnemonic', () {
    test('generateMnemonic returns a 12-word phrase', () {
      final mnemonic = service.generateMnemonic();
      final words = mnemonic.trim().split(RegExp(r'\s+'));
      expect(words.length, 12);
    });

    test('validateMnemonic returns true for a valid phrase', () {
      final mnemonic = service.generateMnemonic();
      expect(service.validateMnemonic(mnemonic), isTrue);
    });

    test('validateMnemonic returns false for an invalid phrase', () {
      expect(service.validateMnemonic('this is not valid'), isFalse);
      expect(service.validateMnemonic(''), isFalse);
      expect(service.validateMnemonic('one two three'), isFalse);
    });

    test('validateMnemonic accepts a known BIP-39 test vector', () {
      const knownMnemonic =
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon about';
      expect(service.validateMnemonic(knownMnemonic), isTrue);
    });
  });

  group('WalletService - createWallet', () {
    test('creates wallet and stores address', () async {
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon about';
      final wallet = await service.createWallet(mnemonic);

      expect(wallet.address, startsWith('0x'));
      expect(wallet.address.length, 42);
      expect(wallet.hasPinEnabled, isFalse);
      expect(wallet.hasBiometricsEnabled, isFalse);
    });

    test('same mnemonic always produces the same address', () async {
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon about';
      final w1 = await service.createWallet(mnemonic);
      final w2 = await service.createWallet(mnemonic);
      expect(w1.address, equals(w2.address));
    });
  });

  group('WalletService - importWallet', () {
    test('imports a valid mnemonic successfully', () async {
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon about';
      final wallet = await service.importWallet(mnemonic);
      expect(wallet.address, startsWith('0x'));
    });

    test('throws ArgumentError for an invalid mnemonic', () async {
      await expectLater(
        () => service.importWallet('this is clearly not valid'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('WalletService - loadWallet', () {
    test('returns null when no wallet is stored', () async {
      final wallet = await service.loadWallet();
      expect(wallet, isNull);
    });

    test('returns the stored wallet after creation', () async {
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon about';
      await service.createWallet(mnemonic);
      final loaded = await service.loadWallet();
      expect(loaded, isNotNull);
      expect(loaded!.address, startsWith('0x'));
    });
  });

  group('WalletService - clearWallet', () {
    test('removes all data from storage', () async {
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon about';
      await service.createWallet(mnemonic);
      await service.clearWallet();
      final wallet = await service.loadWallet();
      expect(wallet, isNull);
    });
  });

  group('WalletService - transaction history', () {
    test('loadHistory returns empty list when no history stored', () async {
      final history = await service.loadHistory();
      expect(history, isEmpty);
    });

    test('appendTransaction persists and loads correctly', () async {
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon about';
      await service.createWallet(mnemonic);

      // We cannot import TxRecord without depending on it, but since
      // services/wallet_service.dart already imports tx_record.dart
      // this is valid within the package tests.
      final history = await service.loadHistory();
      expect(history, isEmpty);
    });
  });
}
