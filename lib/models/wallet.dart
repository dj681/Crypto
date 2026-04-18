/// Immutable data model representing a loaded wallet.
/// Secrets (mnemonic, private key) are NEVER stored in this model;
/// they remain encrypted in FlutterSecureStorage.
class WalletModel {
  const WalletModel({
    required this.address,
    required this.hasPinEnabled,
    required this.hasBiometricsEnabled,
  });

  /// Checksummed Ethereum address (0x-prefixed).
  final String address;

  /// Whether the user has set a PIN to protect the app.
  final bool hasPinEnabled;

  /// Whether biometric unlock is enabled.
  final bool hasBiometricsEnabled;

  WalletModel copyWith({
    String? address,
    bool? hasPinEnabled,
    bool? hasBiometricsEnabled,
  }) {
    return WalletModel(
      address: address ?? this.address,
      hasPinEnabled: hasPinEnabled ?? this.hasPinEnabled,
      hasBiometricsEnabled: hasBiometricsEnabled ?? this.hasBiometricsEnabled,
    );
  }

  @override
  String toString() =>
      'WalletModel(address: $address, pin: $hasPinEnabled, bio: $hasBiometricsEnabled)';
}
