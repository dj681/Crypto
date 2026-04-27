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
    hintText: 'XXXX-XXXX-XXXX-XXXX (commence par X)',
    pattern: _applePattern,
    example: 'X1B2-C3D4-E5F6-G7H8',
  ),
  GiftCardType(
    name: 'Google Play',
    hintText: 'XXXX-XXXX-XXXX-XXXX-XXXX',
    pattern: _googlePattern,
    example: 'ABCD-1234-EFGH-5678-IJKL',
  ),
  GiftCardType(
    name: 'Amazon',
    hintText: 'XXXX-XXXXXX-XXXX ou XXXX-XXXXXX-XXXXX (14-15 car.)',
    pattern: _amazonPattern,
    example: 'AQDM-2WA88M-RPFA',
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
final RegExp _applePattern = RegExp(r'^X[A-Z0-9]{15}$');
final RegExp _googlePattern = RegExp(r'^[A-Z0-9]{20}$');
final RegExp _amazonPattern = RegExp(r'^[A-Z0-9]{14,15}$');
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

  Uri? get _rechargeUri {
    final base = _backendUri;
    if (base == null) return null;
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return base.replace(path: '$basePath/api/gift-cards/recharge', queryParameters: null);
  }

  /// Sends gift card recharge data to the backend.
  ///
  /// When no backend is configured ([BACKEND_URL] not set), the request
  /// completes locally without network access (demo / offline mode).
  /// Throws [StateError] on non-200 responses when a backend is configured.
  Future<void> submitRecharge({
    required String cardType,
    required double amount,
    required String currency,
    required String code,
    String? walletAddress,
    String? userId,
  }) async {
    final uri = _rechargeUri;
    if (uri == null) {
      // No backend configured: simulate a successful recharge locally.
      return;
    }

    final body = jsonEncode({
      'cardType': cardType,
      'amount': amount,
      'currency': currency,
      'code': code,
      if (walletAddress != null) 'walletAddress': walletAddress,
      if (userId != null) 'userId': userId,
      'submittedAt': DateTime.now().toUtc().toIso8601String(),
    });

    final response = await _httpClient
        .post(
          uri,
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

  /// Fetches all gift-card recharge records from the backend.
  ///
  /// Returns an empty list when no backend is configured or on error.
  Future<List<Map<String, dynamic>>> fetchRecharges() async {
    final uri = _rechargeUri;
    if (uri == null) return [];

    try {
      final response = await _httpClient
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return [];

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return [];
      final list = decoded['recharges'];
      if (list is! List) return [];
      return list
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return [];
    }
  }
}
