/// Shared PBKDF2 derivation parameters used by both [WalletService] and the
/// web-specific SubtleCrypto bridge (`_web_crypto.dart`).
///
/// Changing either value is a **breaking change**: existing wallets derived
/// with the old parameters will produce a different private key and become
/// unreachable.
library wallet_derivation_constants;

/// Number of PBKDF2-HMAC-SHA-512 iterations used for 4-word / admin-phrase
/// seed derivation.  100 000 iterations intentionally slows offline
/// brute-force attacks on short phrases.
const int walletPbkdf2Iterations = 100000;

/// Salt prefix mixed into the PBKDF2 salt via SHA-256 to domain-separate
/// this derivation scheme from other potential PBKDF2 uses.
const String walletSaltPrefix = 'my-crypto-safe-recovery-v1:';
