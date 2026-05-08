import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class _Keys {
  static const String hash = 'wallet_password_hash';
  static const String salt = 'wallet_password_salt';
  static const String algorithm = 'wallet_password_kdf';
  static const String iterations = 'wallet_password_iterations';
  static const String version = 'wallet_password_version';
}

class WalletPasswordService {
  WalletPasswordService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const int _saltLength = 16;
  static const int _iterations = 120000;
  static const int _outputLength = 32;
  final FlutterSecureStorage _storage;

  Future<void> setWalletPassword(String password) async {
    if (password.length < 10) {
      throw ArgumentError('Le mot de passe portefeuille doit contenir au moins 10 caractères.');
    }
    final salt = _randomBytes(_saltLength);
    final derived = _pbkdf2HmacSha256(
      password: Uint8List.fromList(utf8.encode(password)),
      salt: salt,
      iterations: _iterations,
      keyLength: _outputLength,
    );

    await Future.wait([
      _storage.write(key: _Keys.hash, value: base64Encode(derived)),
      _storage.write(key: _Keys.salt, value: base64Encode(salt)),
      _storage.write(key: _Keys.algorithm, value: 'pbkdf2-hmac-sha256'),
      _storage.write(key: _Keys.iterations, value: '$_iterations'),
      _storage.write(key: _Keys.version, value: '1'),
    ]);
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static Uint8List _pbkdf2HmacSha256({
    required Uint8List password,
    required Uint8List salt,
    required int iterations,
    required int keyLength,
  }) {
    const hmacLength = 32;
    final blockCount = (keyLength / hmacLength).ceil();
    final output = BytesBuilder(copy: false);
    final hmac = crypto.Hmac(crypto.sha256, password);

    for (var blockIndex = 1; blockIndex <= blockCount; blockIndex++) {
      final blockNumber = Uint8List(4);
      ByteData.view(blockNumber.buffer).setUint32(0, blockIndex, Endian.big);
      final initialInput = Uint8List.fromList([...salt, ...blockNumber]);

      var u = Uint8List.fromList(hmac.convert(initialInput).bytes);
      final t = Uint8List.fromList(u);
      for (var i = 1; i < iterations; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var j = 0; j < hmacLength; j++) {
          t[j] ^= u[j];
        }
      }
      output.add(t);
    }

    return Uint8List.fromList(output.takeBytes().sublist(0, keyLength));
  }
}
