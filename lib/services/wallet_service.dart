import 'dart:convert';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web3dart/web3dart.dart';

import '../models/wallet.dart';
import '../models/tx_record.dart';

/// Keys used in FlutterSecureStorage.
class _Keys {
  static const String mnemonic = 'wallet_mnemonic';
  static const String privateKey = 'wallet_private_key';
  static const String address = 'wallet_address';
  static const String hasPinEnabled = 'wallet_has_pin';
  static const String hasBiometricsEnabled = 'wallet_has_biometrics';
  static const String txHistory = 'wallet_tx_history';
}

/// Handles wallet creation/import and all encrypted persistence.
///
/// **Derivation note**: the Ethereum private key is derived from the first
/// 32 bytes of the 64-byte BIP-39 seed.  This is deterministic and
/// reproducible from the mnemonic, but is *not* BIP-44 compliant.  A full
/// HD path (m/44'/60'/0'/0/0) can be added later with a dedicated BIP-32
/// library.
class WalletService {
  static const int _privateKeyByteLength = 32;
  static const int _recoveryWordCount = 4;

  WalletService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  // ── helpers ──────────────────────────────────────────────────────────────

  static String _bytesToHex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List _privateKeyBytesFromSeed(Uint8List seed) =>
      seed.sublist(0, _privateKeyByteLength);

  static String _privateKeyHexFromSeed(Uint8List seed) =>
      _bytesToHex(_privateKeyBytesFromSeed(seed));

  static EthPrivateKey _credentialsFromSeed(Uint8List seed) {
    // Use the first 32 bytes of the 64-byte seed as private key.
    final privateKeyBytes = _privateKeyBytesFromSeed(seed);
    return EthPrivateKey(privateKeyBytes);
  }

  // ── mnemonic generation / validation ─────────────────────────────────────

  /// Returns a fresh 4-word recovery phrase.
  String generateMnemonic() {
    final words = bip39.generateMnemonic().trim().split(RegExp(r'\s+'));
    return words.take(_recoveryWordCount).join(' ');
  }

  /// Returns true when [mnemonic] is a supported recovery phrase.
  bool validateMnemonic(String mnemonic) {
    final cleaned = mnemonic.trim().toLowerCase();
    return bip39.validateMnemonic(cleaned) || _isFourWordRecoveryPhrase(cleaned);
  }

  bool _isFourWordRecoveryPhrase(String phrase) {
    final words = phrase.split(RegExp(r'\s+'));
    if (words.length != _recoveryWordCount) return false;
    return words.every((word) => RegExp(r'^[a-z]+$').hasMatch(word));
  }

  Uint8List _seedFromMnemonic(String mnemonic) {
    final cleaned = mnemonic.trim().toLowerCase();
    if (bip39.validateMnemonic(cleaned)) {
      return bip39.mnemonicToSeed(cleaned);
    }
    final digest = crypto.sha256.convert(utf8.encode(cleaned));
    return Uint8List.fromList(digest.bytes);
  }

  // ── wallet creation / import ──────────────────────────────────────────────

  /// Creates and persists a wallet from a freshly generated mnemonic.
  /// Returns the [WalletModel] (no secrets).
  Future<WalletModel> createWallet(String mnemonic) async {
    assert(validateMnemonic(mnemonic), 'Invalid mnemonic passed to createWallet');
    return _deriveAndPersist(mnemonic);
  }

  /// Imports a wallet from a user-supplied mnemonic phrase.
  /// Throws [ArgumentError] if the mnemonic is invalid.
  Future<WalletModel> importWallet(String mnemonic) async {
    final cleaned = mnemonic.trim().toLowerCase();
    if (!validateMnemonic(cleaned)) {
      throw ArgumentError("La phrase mnémonique fournie n'est pas valide.");
    }
    return _deriveAndPersist(cleaned);
  }

  Future<WalletModel> _deriveAndPersist(String mnemonic) async {
    final seed = _seedFromMnemonic(mnemonic);
    final privateKeyHex = _privateKeyHexFromSeed(seed);
    final credentials = EthPrivateKey.fromHex(privateKeyHex);
    final address = credentials.address.hexEip55;

    await Future.wait([
      _storage.write(key: _Keys.mnemonic, value: mnemonic),
      _storage.write(key: _Keys.privateKey, value: privateKeyHex),
      _storage.write(key: _Keys.address, value: address),
      _storage.write(key: _Keys.hasPinEnabled, value: 'false'),
      _storage.write(key: _Keys.hasBiometricsEnabled, value: 'false'),
    ]);

    return WalletModel(
      address: address,
      hasPinEnabled: false,
      hasBiometricsEnabled: false,
    );
  }

  // ── load / check ─────────────────────────────────────────────────────────

  /// Returns [WalletModel] if a wallet is stored, or null otherwise.
  Future<WalletModel?> loadWallet() async {
    var address = await _storage.read(key: _Keys.address);

    // Backward compatibility / recovery:
    // if address is missing but private key or mnemonic still exists, rebuild it.
    if (address == null || address.isEmpty) {
      final privateKeyHex = await _storage.read(key: _Keys.privateKey);
      if (privateKeyHex != null && privateKeyHex.isNotEmpty) {
        try {
          final credentials = EthPrivateKey.fromHex(privateKeyHex);
          address = credentials.address.hexEip55;
          await _storage.write(key: _Keys.address, value: address);
        } catch (e, st) {
          debugPrint(
            'Wallet recovery from private key failed, trying mnemonic fallback: $e\n$st',
          );
        }
      }
    }

    if (address == null || address.isEmpty) {
      final mnemonic = await _storage.read(key: _Keys.mnemonic);
      if (mnemonic != null &&
          mnemonic.isNotEmpty &&
          validateMnemonic(mnemonic)) {
        try {
          final seed = _seedFromMnemonic(mnemonic);
          final privateKeyHex = _privateKeyHexFromSeed(seed);
          final credentials = EthPrivateKey.fromHex(privateKeyHex);
          address = credentials.address.hexEip55;
          await Future.wait([
            _storage.write(key: _Keys.privateKey, value: privateKeyHex),
            _storage.write(key: _Keys.address, value: address),
          ]);
        } catch (e, st) {
          debugPrint(
            'Wallet recovery from mnemonic failed: $e\n$st',
          );
        }
      } else if (mnemonic != null && mnemonic.isNotEmpty) {
        debugPrint('Wallet recovery skipped: stored mnemonic is invalid.');
      }
    }

    if (address == null || address.isEmpty) return null;

    final hasPinStr = await _storage.read(key: _Keys.hasPinEnabled);
    final hasBioStr = await _storage.read(key: _Keys.hasBiometricsEnabled);
    return WalletModel(
      address: address,
      hasPinEnabled: hasPinStr == 'true',
      hasBiometricsEnabled: hasBioStr == 'true',
    );
  }

  /// Loads the raw private key for signing transactions.
  /// Returns null if not stored.
  Future<EthPrivateKey?> loadCredentials() async {
    final hex = await _storage.read(key: _Keys.privateKey);
    if (hex == null) return null;
    return EthPrivateKey.fromHex(hex);
  }

  /// Loads the mnemonic phrase (only needed when the user requests it).
  Future<String?> loadMnemonic() async =>
      _storage.read(key: _Keys.mnemonic);

  // ── security flags ────────────────────────────────────────────────────────

  Future<void> setPinEnabled({required bool enabled}) =>
      _storage.write(key: _Keys.hasPinEnabled, value: enabled.toString());

  Future<void> setBiometricsEnabled({required bool enabled}) =>
      _storage.write(key: _Keys.hasBiometricsEnabled, value: enabled.toString());

  // ── transaction history ───────────────────────────────────────────────────

  Future<List<TxRecord>> loadHistory() async {
    final raw = await _storage.read(key: _Keys.txHistory);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => TxRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHistory(List<TxRecord> records) async {
    final encoded = jsonEncode(records.map((r) => r.toJson()).toList());
    await _storage.write(key: _Keys.txHistory, value: encoded);
  }

  Future<void> appendTransaction(TxRecord record) async {
    final history = await loadHistory();
    history.insert(0, record); // newest first
    await saveHistory(history);
  }

  // ── wipe ─────────────────────────────────────────────────────────────────

  /// Permanently erases all wallet data from secure storage.
  Future<void> clearWallet() => _storage.deleteAll();
}
