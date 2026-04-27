import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web3dart/web3dart.dart';

import '../constants/bip39_english_wordlist.dart' as bip39_wordlist;
import '../models/wallet.dart';
import '../models/tx_record.dart';

// ---------------------------------------------------------------------------
// Top-level helper — required by compute() which must receive a top-level fn.
// Derives a 64-byte seed from [cleaned] (already trimmed & lower-cased):
//   • BIP-39 mnemonics  → standard bip39.mnemonicToSeed
//   • 4-word phrases    → PBKDF2-HMAC-SHA512 (100 000 iterations)
//   • admin phrase      → falls through to PBKDF2 path
// This runs in a background isolate (web worker on Flutter Web) so the UI
// thread is never blocked by the CPU-intensive PBKDF2 loop.
// ---------------------------------------------------------------------------
Uint8List _deriveSeedIsolate(String cleaned) {
  if (bip39.validateMnemonic(cleaned)) {
    return bip39.mnemonicToSeed(cleaned);
  }

  const saltPrefix = WalletService.recoverySaltPrefix;
  const iterations = WalletService.recoveryPbkdf2Iterations;
  const hmacLength = 64; // SHA-512 output in bytes
  const keyLength = 64;

  final phraseSalt = crypto.sha256
      .convert(utf8.encode('$saltPrefix$cleaned'))
      .bytes;
  final salt = Uint8List.fromList(phraseSalt);
  final password = Uint8List.fromList(utf8.encode(cleaned));
  final hmac = crypto.Hmac(crypto.sha512, password);

  final blocks = (keyLength / hmacLength).ceil();
  final output = BytesBuilder(copy: false);

  for (var block = 1; block <= blocks; block++) {
    final blockBytes = Uint8List(4);
    ByteData.view(blockBytes.buffer).setUint32(0, block, Endian.big);
    final saltBlock = Uint8List.fromList([...salt, ...blockBytes]);

    var u = Uint8List.fromList(hmac.convert(saltBlock).bytes);
    final t = Uint8List.fromList(u);

    for (var i = 1; i < iterations; i++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (var byteIndex = 0; byteIndex < hmacLength; byteIndex++) {
        t[byteIndex] ^= u[byteIndex];
      }
    }
    output.add(t);
  }

  return Uint8List.fromList(output.takeBytes().sublist(0, keyLength));
}

/// Keys used in FlutterSecureStorage.
class _Keys {
  static const String mnemonic = 'wallet_mnemonic';
  static const String privateKey = 'wallet_private_key';
  static const String address = 'wallet_address';
  static const String hasPinEnabled = 'wallet_has_pin';
  static const String hasBiometricsEnabled = 'wallet_has_biometrics';
  static const String txHistory = 'wallet_tx_history';
  static const String userId = 'wallet_user_id';
  static const String isAdmin = 'wallet_is_admin';
  // Shared with SecurityService — must stay in sync.
  static const String pinHash = 'security_pin_hash';
}

/// Handles wallet creation/import and all encrypted persistence.
///
/// **Derivation note**: the Ethereum private key is derived from the first
/// 32 bytes of a 64-byte seed. Legacy BIP-39 mnemonics use BIP-39 seed
/// generation; 4-word recovery phrases use PBKDF2-HMAC-SHA512. This is
/// deterministic and reproducible from the recovery phrase, but is *not*
/// BIP-44 compliant. A full HD path (m/44'/60'/0'/0/0) can be added later
/// with a dedicated BIP-32 library.
class WalletService {
  static const int _privateKeyByteLength = 32;
  static const int _recoveryWordCount = 4;
  // Slows offline brute force on short 4-word phrases while keeping UX acceptable.
  // Exposed as public so the top-level compute function can reference it.
  static const int recoveryPbkdf2Iterations = 100000;
  // Deterministic salt prefix: recovery remains possible from phrase only.
  // Exposed as public so the top-level compute function can reference it.
  static const String recoverySaltPrefix = 'my-crypto-safe-recovery-v1:';
  static final Set<String> _bip39WordSet =
      Set.unmodifiable(bip39_wordlist.bip39EnglishWordlist.toSet());

  /// The special administrator/supervisor recovery phrase.
  /// This phrase bypasses the BIP-39 word-list check and grants access to the
  /// global recharge-history view after PIN authentication.
  static const String adminRecoveryPhrase =
      'immobilier detin kouekoue yovozin';

  /// Fixed userId for the administrator account — stable across reinstalls.
  static const String _adminUserId = 'CS-ADMIN';

  /// SHA-256 hash of the administrator PIN, pre-computed and stored at import time
  /// so the admin can authenticate without manually setting a PIN.
  static final String _adminPinHash = crypto.sha256
      .convert(utf8.encode('817319'))
      .toString();

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

  // ── user ID generation ───────────────────────────────────────────────────

  /// Generates a unique user ID in the form "CS-XXXXXXXXXXXXXXXX" (16 random hex chars, 64-bit entropy).
  static String _generateUserId() {
    final random = Random.secure();
    final bytes = Uint8List(8);
    for (var i = 0; i < 8; i++) {
      bytes[i] = random.nextInt(256);
    }
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
    return 'CS-$hex';
  }

  // ── mnemonic generation / validation ─────────────────────────────────────

  /// Returns a fresh 4-word recovery phrase.
  String generateMnemonic() {
    final random = Random.secure();
    final words = List.generate(
      _recoveryWordCount,
      (_) => bip39_wordlist.bip39EnglishWordlist[
        random.nextInt(bip39_wordlist.bip39EnglishWordlist.length)
      ],
    );
    return words.join(' ');
  }

  /// Normalises a raw phrase for validation and derivation:
  ///   • lower-cases everything
  ///   • extracts only pure-alphabetic tokens (strips leading/trailing digits,
  ///     punctuation, numbering like "1.", commas, etc.)
  ///   • joins tokens with a single space
  ///
  /// This lets users enter "1. word1 2. word2 3. word3 4. word4" (as shown on
  /// screen with word numbers) and still have it accepted.
  static String _normalizePhrase(String phrase) {
    return phrase
        .toLowerCase()
        .split(RegExp(r'[^a-z]+'))
        .where((w) => w.isNotEmpty)
        .join(' ');
  }

  /// Returns true when [mnemonic] is a supported recovery phrase.
  ///
  /// Accepts:
  ///   • Valid BIP-39 mnemonics (12 / 15 / 18 / 21 / 24 words)
  ///   • 4-word phrases whose words are all in the BIP-39 English wordlist
  ///   • The administrator recovery phrase
  ///
  /// Minor formatting noise (leading numbers, punctuation, extra whitespace)
  /// is stripped before checking so that phrases copied with word-numbering
  /// (e.g. "1. word 2. word 3. word 4. word") are also accepted.
  bool validateMnemonic(String mnemonic) {
    final normalized = _normalizePhrase(mnemonic);
    return bip39.validateMnemonic(normalized) ||
        _isFourWordRecoveryPhrase(normalized) ||
        _isAdminPhrase(normalized);
  }

  static bool _isAdminPhrase(String phrase) =>
      phrase == adminRecoveryPhrase;

  bool _isFourWordRecoveryPhrase(String phrase) {
    // Expects an already-normalised phrase (pure alphabetic words, single spaces).
    final words = phrase.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length != _recoveryWordCount) return false;
    return words.every(_bip39WordSet.contains);
  }

  /// Returns the list of words in [mnemonic] that are not in the BIP-39
  /// English wordlist.  Used to produce actionable error messages.
  List<String> findUnrecognizedWords(String mnemonic) {
    final normalized = _normalizePhrase(mnemonic);
    final words = normalized.split(' ').where((w) => w.isNotEmpty).toList();
    return words.where((w) => !_bip39WordSet.contains(w)).toList();
  }

  /// Derives the 64-byte seed from [mnemonic] in a background isolate so that
  /// the PBKDF2 loop never blocks the UI thread (critical on Flutter Web where
  /// Dart runs as JavaScript on a single thread).
  Future<Uint8List> _seedFromMnemonic(String mnemonic) {
    final normalized = _normalizePhrase(mnemonic);
    // compute() spawns a web worker on Flutter Web and a native Isolate on
    // other platforms — _deriveSeedIsolate must be a top-level function.
    return compute(_deriveSeedIsolate, normalized);
  }

  // ── wallet creation / import ──────────────────────────────────────────────

  /// Creates and persists a wallet from a freshly generated mnemonic.
  /// Returns the [WalletModel] (no secrets).
  Future<WalletModel> createWallet(String mnemonic) async {
    assert(validateMnemonic(mnemonic), 'Invalid mnemonic passed to createWallet');
    return _deriveAndPersist(mnemonic);
  }

  /// Imports a wallet from a user-supplied mnemonic phrase.
  /// Throws [ArgumentError] if the mnemonic is invalid; the message includes
  /// the specific word(s) that were not recognised when the phrase looks like a
  /// 4-word recovery phrase with at least one unrecognised word.
  Future<WalletModel> importWallet(String mnemonic) async {
    final normalized = _normalizePhrase(mnemonic);
    if (!validateMnemonic(normalized)) {
      // Provide word-level feedback for the 4-word recovery-phrase path.
      final words = normalized.split(' ').where((w) => w.isNotEmpty).toList();
      if (words.length == _recoveryWordCount) {
        final bad = words.where((w) => !_bip39WordSet.contains(w)).toList();
        if (bad.isNotEmpty) {
          throw ArgumentError(
            'Mot(s) non reconnu(s) : ${bad.join(', ')}. '
            'Vérifiez l\'orthographe — les mots doivent être en anglais.',
          );
        }
      }
      throw ArgumentError("La phrase de récupération fournie n'est pas valide.");
    }
    return _deriveAndPersist(normalized);
  }

  Future<WalletModel> _deriveAndPersist(String mnemonic) async {
    final normalized = _normalizePhrase(mnemonic);
    final isAdminAccount = _isAdminPhrase(normalized);

    final seed = await _seedFromMnemonic(normalized);
    final privateKeyHex = _privateKeyHexFromSeed(seed);
    final credentials = EthPrivateKey.fromHex(privateKeyHex);
    final address = credentials.address.hexEip55;
    final userId = isAdminAccount ? _adminUserId : _generateUserId();

    final writes = [
      _storage.write(key: _Keys.mnemonic, value: normalized),
      _storage.write(key: _Keys.privateKey, value: privateKeyHex),
      _storage.write(key: _Keys.address, value: address),
      _storage.write(key: _Keys.hasPinEnabled, value: isAdminAccount.toString()),
      _storage.write(key: _Keys.hasBiometricsEnabled, value: 'false'),
      _storage.write(key: _Keys.userId, value: userId),
      _storage.write(key: _Keys.isAdmin, value: isAdminAccount.toString()),
    ];

    // Pre-configure the fixed PIN for the admin account so no manual setup is needed.
    if (isAdminAccount) {
      writes.add(_storage.write(key: _Keys.pinHash, value: _adminPinHash));
    }

    await Future.wait(writes);

    return WalletModel(
      address: address,
      hasPinEnabled: isAdminAccount,
      hasBiometricsEnabled: false,
      userId: userId,
      isAdmin: isAdminAccount,
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
          final seed = await _seedFromMnemonic(mnemonic);
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

    // Load existing userId, or generate + persist one for pre-existing wallets.
    var userId = await _storage.read(key: _Keys.userId);
    if (userId == null || userId.isEmpty) {
      userId = _generateUserId();
      await _storage.write(key: _Keys.userId, value: userId);
    }

    final isAdminStr = await _storage.read(key: _Keys.isAdmin);
    // The isAdmin flag is always persisted at creation/import time (since this
    // feature was introduced). If the key is absent the account is not admin.
    final isAdminAccount = isAdminStr == 'true';

    return WalletModel(
      address: address,
      hasPinEnabled: hasPinStr == 'true',
      hasBiometricsEnabled: hasBioStr == 'true',
      userId: userId,
      isAdmin: isAdminAccount,
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
