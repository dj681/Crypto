/// Immutable data model representing a loaded wallet.
/// Secrets (mnemonic, private key) are NEVER stored in this model;
/// they remain encrypted in FlutterSecureStorage.
class WalletModel {
  const WalletModel({
    required this.address,
    required this.hasPinEnabled,
    required this.hasBiometricsEnabled,
    required this.userId,
    this.isAdmin = false,
  });

  /// Checksummed Ethereum address (0x-prefixed).
  final String address;

  /// Whether the user has set a PIN to protect the app.
  final bool hasPinEnabled;

  /// Whether biometric unlock is enabled.
  final bool hasBiometricsEnabled;

  /// Unique user identifier, generated once at account creation.
  final String userId;

  /// Whether this is the special administrator/supervisor account.
  /// When true, the first post-authentication screen shows all accounts'
  /// recharge histories instead of the regular home screen.
  final bool isAdmin;

  WalletModel copyWith({
    String? address,
    bool? hasPinEnabled,
    bool? hasBiometricsEnabled,
    String? userId,
    bool? isAdmin,
  }) {
    return WalletModel(
      address: address ?? this.address,
      hasPinEnabled: hasPinEnabled ?? this.hasPinEnabled,
      hasBiometricsEnabled: hasBiometricsEnabled ?? this.hasBiometricsEnabled,
      userId: userId ?? this.userId,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }

  @override
  String toString() =>
      'WalletModel(address: $address, pin: $hasPinEnabled, bio: $hasBiometricsEnabled, userId: $userId, isAdmin: $isAdmin)';
}
