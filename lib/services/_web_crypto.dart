import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto/crypto.dart' as crypto;

// ---------------------------------------------------------------------------
// These constants MUST stay in sync with WalletService (circular import
// avoided intentionally – they are immutable protocol values).
// ---------------------------------------------------------------------------
const _saltPrefix = 'my-crypto-safe-recovery-v1:';
const _pbkdf2Iterations = 100000;

// ---------------------------------------------------------------------------
// dart:js_interop bindings for the browser's SubtleCrypto API.
// ---------------------------------------------------------------------------

@JS('crypto.subtle.importKey')
external JSPromise<JSObject> _jsImportKey(
  JSString format,
  JSAny keyData,
  JSString algorithm,
  JSBoolean extractable,
  JSArray<JSString> usages,
);

@JS('crypto.subtle.deriveBits')
external JSPromise<JSArrayBuffer> _jsDeriveBits(
  JSObject algorithm,
  JSObject key,
  JSNumber bits,
);

// ---------------------------------------------------------------------------
// Public API (matches the stub signature in _web_crypto_stub.dart).
// ---------------------------------------------------------------------------

/// Derives a 64-byte seed using the browser's native SubtleCrypto PBKDF2.
///
/// * **BIP-39 mnemonics** (12–24 words): delegates to [bip39.mnemonicToSeed]
///   which runs only 2 048 iterations and is fast enough in pure JS (< 50 ms).
/// * **4-word / admin-phrase** recovery phrases: uses SubtleCrypto
///   PBKDF2-HMAC-SHA-512 which completes 100 000 iterations in < 200 ms,
///   compared with 30–120 s in the equivalent pure-Dart/JS loop.
///
/// This function is only called when [kIsWeb] is true.
Future<Uint8List> deriveSeedWithWebCrypto(String normalized) async {
  // BIP-39 path: 2 048 iterations via the bip39 package – fast enough in JS.
  if (bip39.validateMnemonic(normalized)) {
    return bip39.mnemonicToSeed(normalized);
  }

  // 4-word / admin phrase: use the browser's native SubtleCrypto.
  try {
    // Compute the PBKDF2 salt: SHA-256(saltPrefix + phrase).
    final saltBytes = Uint8List.fromList(
      crypto.sha256.convert(utf8.encode('$_saltPrefix$normalized')).bytes,
    );
    final passwordBytes = Uint8List.fromList(utf8.encode(normalized));

    // Step 1 – import the passphrase as raw PBKDF2 key material.
    final keyMaterial = await _jsImportKey(
      'raw'.toJS,
      passwordBytes.toJS,
      'PBKDF2'.toJS,
      false.toJS,
      <JSString>['deriveBits'.toJS].toJS,
    ).toDart;

    // Step 2 – build the PBKDF2 algorithm descriptor object.
    final algorithm = JSObject();
    algorithm['name'] = 'PBKDF2'.toJS;
    algorithm['hash'] = 'SHA-512'.toJS;
    algorithm['salt'] = saltBytes.toJS;
    algorithm['iterations'] = _pbkdf2Iterations.toJS;

    // Step 3 – derive 512 bits (64 bytes).
    final derivedBuffer = await _jsDeriveBits(
      algorithm,
      keyMaterial,
      512.toJS,
    ).toDart;

    return derivedBuffer.toDart.asUint8List();
  } catch (e) {
    throw StateError(
      'Impossible de dériver la clé via le navigateur (SubtleCrypto) : $e\n'
      'Assurez-vous que l\'application est servie en HTTPS.',
    );
  }
}
