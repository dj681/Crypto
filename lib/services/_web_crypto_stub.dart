import 'dart:typed_data';

/// Stub used on native (iOS, Android, desktop) platforms.
///
/// [WalletService._seedFromMnemonic] guards this code path with [kIsWeb] so
/// this function is never called at runtime.  It exists only to satisfy the
/// conditional-import contract.
Future<Uint8List> deriveSeedWithWebCrypto(String normalized) {
  throw UnsupportedError(
    'Web Crypto is only available on the web platform.',
  );
}
