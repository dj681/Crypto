import 'dart:convert';

import 'package:http/http.dart' as http;

/// Describes a supported gift card type with its code format.
class GiftCardType {
  const GiftCardType({
    required this.name,
    required this.hintText,
    required this.pattern,
    required this.example,
  });

  final String name;

  /// User-visible format hint (e.g. "XXXX-XXXX-XXXX-XXXX").
  final String hintText;

  /// Regex pattern used to validate the code.
  final RegExp pattern;

  /// Example code shown as placeholder.
  final String example;
}

final List<GiftCardType> giftCardTypes = [
  GiftCardType(
    name: 'Apple / iTunes',
    hintText: 'XXXX-XXXX-XXXX-XXXX',
    pattern: _applePattern,
    example: 'A1B2-C3D4-E5F6-G7H8',
  ),
  GiftCardType(
    name: 'Google Play',
    hintText: 'XXXX-XXXX-XXXX-XXXX',
    pattern: _googlePattern,
    example: 'ABCD-1234-EFGH-5678',
  ),
  GiftCardType(
    name: 'Amazon',
    hintText: 'XXXX-XXXXXX-XXXX',
    pattern: _amazonPattern,
    example: 'A1B2-3C4D5E-F6G7',
  ),
  GiftCardType(
    name: 'Steam',
    hintText: 'XXXXX-XXXXX-XXXXX',
    pattern: _steamPattern,
    example: 'A1B2C-D3E4F-G5H6I',
  ),
  GiftCardType(
    name: 'Paysafecard',
    hintText: 'XXXX-XXXX-XXXX-XXXX (chiffres)',
    pattern: _paysafecardPattern,
    example: '1234-5678-9012-3456',
  ),
];

// RegExp patterns matched against the *normalized* code (separators stripped).
// The validator in the UI strips dashes and spaces before checking these patterns
// so that codes copied without hyphens or with spaces are accepted.

/// Strips dashes and spaces from [code] and uppercases it for validation
/// and submission.
String normalizeGiftCardCode(String code) =>
    code.trim().toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
final RegExp _applePattern = RegExp(r'^[A-Z0-9]{16}$');
final RegExp _googlePattern = RegExp(r'^[A-Z0-9]{16}$');
final RegExp _amazonPattern = RegExp(r'^[A-Z0-9]{14}$');
final RegExp _steamPattern = RegExp(r'^[A-Z0-9]{15}$');
final RegExp _paysafecardPattern = RegExp(r'^\d{16}$');

class GiftCardService {
  GiftCardService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const String _backendBaseUrl =
      String.fromEnvironment('BACKEND_URL', defaultValue: '');
  static final Uri? _backendUri = _parseUri(_backendBaseUrl);

  static Uri? _parseUri(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    final parsed = Uri.tryParse(v);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) return null;
    return parsed;
  }

  Uri get _rechargeUri {
    final base = _backendUri;
    if (base == null) {
      throw StateError(
        'BACKEND_URL non configuré. Définissez --dart-define=BACKEND_URL pour activer la recharge.',
      );
    }
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return base.replace(path: '$basePath/api/gift-cards/recharge', queryParameters: null);
  }

  /// Sends gift card recharge data to the backend.
  /// Throws [StateError] on non-200 responses.
  Future<void> submitRecharge({
    required String cardType,
    required double amount,
    required String code,
    String? walletAddress,
  }) async {
    final body = jsonEncode({
      'cardType': cardType,
      'amount': amount,
      'code': code,
      if (walletAddress != null) 'walletAddress': walletAddress,
      'submittedAt': DateTime.now().toUtc().toIso8601String(),
    });

    final response = await _httpClient
        .post(
          _rechargeUri,
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200 && response.statusCode != 201) {
      final detail = response.body.isNotEmpty ? ' — ${response.body}' : '';
      throw StateError(
          'Erreur backend carte cadeau (${response.statusCode})$detail');
    }
  }
}
