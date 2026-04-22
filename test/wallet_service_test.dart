import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

import 'package:my_crypto_safe/models/tx_record.dart';
import 'package:my_crypto_safe/services/wallet_service.dart';

// In-memory stub for FlutterSecureStorage.
class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final _store = <String, String>{};

  @visibleForTesting
  void removeKey(String key) => _store.remove(key);
  @visibleForTesting
  String? getValue(String key) => _store[key];

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
    test('generateMnemonic returns a 4-word phrase', () {
      final mnemonic = service.generateMnemonic();
      final words = mnemonic.trim().split(RegExp(r'\s+'));
      expect(words.length, 4);
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

    test('validateMnemonic accepts a valid 4-word phrase', () {
      const knownMnemonic = 'abandon ability able about';
      expect(service.validateMnemonic(knownMnemonic), isTrue);
    });

    test('validateMnemonic rejects 4 words outside BIP-39 wordlist', () {
      const invalidFourWords = 'alpha beta gamma delta';
      expect(service.validateMnemonic(invalidFourWords), isFalse);
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
      const mnemonic = 'abandon ability able about';
      final wallet = await service.createWallet(mnemonic);

      expect(wallet.address, startsWith('0x'));
      expect(wallet.address.length, 42);
      expect(wallet.hasPinEnabled, isFalse);
      expect(wallet.hasBiometricsEnabled, isFalse);
    });

    test('same mnemonic always produces the same address', () async {
      const mnemonic = 'abandon ability able about';
      final w1 = await service.createWallet(mnemonic);
      final w2 = await service.createWallet(mnemonic);
      expect(w1.address, equals(w2.address));
    });
  });

  group('WalletService - importWallet', () {
    test('imports a valid mnemonic successfully', () async {
      const mnemonic = 'abandon ability able about';
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
      const mnemonic = 'abandon ability able about';
      await service.createWallet(mnemonic);
      final loaded = await service.loadWallet();
      expect(loaded, isNotNull);
      expect(loaded!.address, startsWith('0x'));
    });

    test('recovers wallet when address key is missing but private key exists',
        () async {
      const mnemonic = 'abandon ability able about';
      await service.createWallet(mnemonic);
      storage.removeKey('wallet_address');

      final loaded = await service.loadWallet();

      expect(loaded, isNotNull);
      expect(loaded!.address, startsWith('0x'));
      expect(storage.getValue('wallet_address'), isNotEmpty);
    });

    test('recovers wallet from mnemonic when address and private key are missing',
        () async {
      const mnemonic = 'abandon ability able about';
      await service.createWallet(mnemonic);
      storage.removeKey('wallet_address');
      storage.removeKey('wallet_private_key');

      final loaded = await service.loadWallet();

      expect(loaded, isNotNull);
      expect(loaded!.address, startsWith('0x'));
      expect(storage.getValue('wallet_address'), isNotEmpty);
      expect(storage.getValue('wallet_private_key'), isNotEmpty);
    });
  });

  group('WalletService - clearWallet', () {
    test('removes all data from storage', () async {
      const mnemonic = 'abandon ability able about';
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

    test('appendTransaction persists and can be loaded back', () async {
      const mnemonic = 'abandon ability able about';
      await service.createWallet(mnemonic);

      final record = TxRecord(
        txHash: '0xabc123',
        from: '0xFromAddress',
        to: '0xToAddress',
        valueEth: 0.5,
        timestamp: DateTime(2024, 1, 15, 10, 30),
        status: TxStatus.confirmed,
      );

      await service.appendTransaction(record);
      final history = await service.loadHistory();

      expect(history, hasLength(1));
      expect(history.first.txHash, equals('0xabc123'));
      expect(history.first.valueEth, equals(0.5));
      expect(history.first.status, equals(TxStatus.confirmed));
    });

    test('appendTransaction inserts newest first', () async {
      const mnemonic = 'abandon ability able about';
      await service.createWallet(mnemonic);

      final first = TxRecord(
        txHash: '0xfirst',
        from: '0xA',
        to: '0xB',
        valueEth: 1.0,
        timestamp: DateTime(2024, 1, 1),
      );
      final second = TxRecord(
        txHash: '0xsecond',
        from: '0xA',
        to: '0xB',
        valueEth: 2.0,
        timestamp: DateTime(2024, 1, 2),
      );

      await service.appendTransaction(first);
      await service.appendTransaction(second);
      final history = await service.loadHistory();

      expect(history, hasLength(2));
      // Most recent should be at index 0.
      expect(history.first.txHash, equals('0xsecond'));
    });
  });
}
