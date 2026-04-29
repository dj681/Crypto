import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

final Uri _binanceTickerUri = Uri.parse('https://api.binance.com/api/v3/ticker/24hr');
final Uri _binanceExchangeInfoUri =
    Uri.parse('https://api.binance.com/api/v3/exchangeInfo');
final Uri _stooqUriBase = Uri.parse('https://stooq.com/q/l/');

final Map<String, ({String base, String quote})> _symbolCache = {};
final Map<String, _MarketOverride> _manualOverrides = {};
final List<Map<String, dynamic>> _giftCardRecharges = [];
final List<Map<String, dynamic>> _deposits = [];
final List<Map<String, dynamic>> _adminAuditLog = [];
DateTime? _symbolCacheLoadedAt;

// ── Persistence ─────────────────────────────────────────────────────────────

/// Directory where JSON persistence files are stored.
/// Override with the `DATA_DIR` environment variable (e.g. `/var/data`).
final String _dataDir =
    Platform.environment['DATA_DIR']?.trim().isNotEmpty == true
        ? Platform.environment['DATA_DIR']!.trim()
        : '.';

File get _rechargesFile => File('$_dataDir/recharges.json');

/// Loads persisted recharges from disk.  Called once at startup.
Future<void> _loadRechargesFromDisk() async {
  try {
    final file = _rechargesFile;
    if (!await file.exists()) return;
    final content = await file.readAsString();
    final list = jsonDecode(content);
    if (list is List) {
      _giftCardRecharges
        ..clear()
        ..addAll(list.whereType<Map<String, dynamic>>());
      stdout.writeln(
          '[persistence] ${_giftCardRecharges.length} recharge(s) chargée(s) depuis ${file.path}');
    }
  } catch (e) {
    stderr.writeln('[persistence] Impossible de charger recharges.json : $e');
  }
}

/// Persists the current recharge list to disk.
Future<void> _saveRechargesToDisk() async {
  try {
    final dir = Directory(_dataDir);
    if (!await dir.exists()) await dir.create(recursive: true);
    final tmp = File('$_dataDir/recharges.json.tmp');
    await tmp.writeAsString(jsonEncode(_giftCardRecharges));
    await tmp.rename(_rechargesFile.path);
  } catch (e) {
    stderr.writeln('[persistence] Impossible de sauvegarder recharges.json : $e');
  }
}

/// Bearer token required for admin-only endpoints.
/// Set via the `ADMIN_TOKEN` environment variable.  When not set (empty) all
/// admin endpoints return 401 Unauthorized, which is the safe default.
final String _adminToken =
    Platform.environment['ADMIN_TOKEN']?.trim() ?? '';

/// Bearer secret required to submit deposit notifications.
/// Set via the `ABYTONE` environment variable.  When not set (empty) all
/// deposit submission endpoints return 401 Unauthorized, which is the safe
/// default.
final String _depositSecret =
    Platform.environment['ABYTONE']?.trim() ?? '';

bool _isAdminRequest(HttpRequest request) {
  if (_adminToken.isEmpty) return false;
  final auth = request.headers.value('Authorization') ?? '';
  return auth == 'Bearer $_adminToken';
}

bool _isDepositRequest(HttpRequest request) {
  if (_depositSecret.isEmpty) return false;
  final auth = request.headers.value('Authorization') ?? '';
  return auth == 'Bearer $_depositSecret';
}

void _recordAuditEvent(HttpRequest request, String action) {
  _adminAuditLog.add({
    'action': action,
    'ip': request.connectionInfo?.remoteAddress.address,
    'path': request.uri.path,
    'method': request.method,
    'timestamp': DateTime.now().toUtc().toIso8601String(),
  });
}

const List<_RealAssetSource> _realAssetSources = [
  _RealAssetSource(
    symbol: 'XAUUSD',
    baseAsset: 'XAU',
    quoteAsset: 'USD',
    name: 'Or',
    unit: 'oz',
    stooqSymbol: 'xauusd',
  ),
  _RealAssetSource(
    symbol: 'XAGUSD',
    baseAsset: 'XAG',
    quoteAsset: 'USD',
    name: 'Argent',
    unit: 'oz',
    stooqSymbol: 'xagusd',
  ),
  _RealAssetSource(
    symbol: 'BRNUSD',
    baseAsset: 'BRN',
    quoteAsset: 'USD',
    name: 'Pétrole Brent',
    unit: 'baril',
    stooqSymbol: 'brn.f',
  ),
  _RealAssetSource(
    symbol: 'WTIUSD',
    baseAsset: 'WTI',
    quoteAsset: 'USD',
    name: 'Pétrole WTI',
    unit: 'baril',
    stooqSymbol: 'cl.f',
  ),
  _RealAssetSource(
    symbol: 'XPTUSD',
    baseAsset: 'XPT',
    quoteAsset: 'USD',
    name: 'Platine',
    unit: 'oz',
    stooqSymbol: 'xptusd',
  ),
];

Future<void> main() async {
  final portEnv = Platform.environment['PORT']?.trim();
  final port = int.tryParse(portEnv ?? '') ?? 8080;

  // Load persisted data before accepting requests.
  await _loadRechargesFromDisk();

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  final httpClient = http.Client();

  stdout.writeln('Backend running on http://0.0.0.0:$port');

  await for (final request in server) {
    _setCorsHeaders(request.response);

    if (request.method == 'OPTIONS') {
      request.response
        ..statusCode = HttpStatus.noContent
        ..close();
      continue;
    }

    try {
      if (request.uri.path == '/health') {
        if (request.method != 'GET') {
          _json(request.response, HttpStatus.methodNotAllowed, {'error': 'Method not allowed'});
          continue;
        }
        _json(
          request.response,
          HttpStatus.ok,
          {'status': 'ok', 'service': 'crypto-backend'},
        );
        continue;
      }

      if (request.uri.path == '/api/binance/ticker24h') {
        if (request.method != 'GET') {
          _json(request.response, HttpStatus.methodNotAllowed, {'error': 'Method not allowed'});
          continue;
        }
        final uri = _withQuery(_binanceTickerUri, request.uri.queryParameters);
        await _proxyGet(httpClient, uri, request.response);
        continue;
      }

      if (request.uri.path == '/api/binance/exchangeInfo') {
        if (request.method != 'GET') {
          _json(request.response, HttpStatus.methodNotAllowed, {'error': 'Method not allowed'});
          continue;
        }
        final uri = _withQuery(_binanceExchangeInfoUri, request.uri.queryParameters);
        await _proxyGet(httpClient, uri, request.response);
        continue;
      }

      if (request.uri.path == '/api/market/crypto') {
        if (request.method != 'GET') {
          _json(request.response, HttpStatus.methodNotAllowed, {'error': 'Method not allowed'});
          continue;
        }
        await _serveCryptoMarket(httpClient, request);
        continue;
      }

      if (request.uri.path == '/api/market/real-assets') {
        if (request.method != 'GET') {
          _json(request.response, HttpStatus.methodNotAllowed, {'error': 'Method not allowed'});
          continue;
        }
        await _serveRealAssetsMarket(httpClient, request);
        continue;
      }

      if (request.uri.path == '/api/market/overrides') {
        if (request.method == 'GET') {
          _json(request.response, HttpStatus.ok, _buildOverridesPayload());
          continue;
        }
        if (request.method == 'PUT') {
          await _upsertManualOverride(request);
          continue;
        }
        _json(request.response, HttpStatus.methodNotAllowed, {'error': 'Method not allowed'});
        continue;
      }

      if (request.uri.pathSegments.length == 5 &&
          request.uri.pathSegments[0] == 'api' &&
          request.uri.pathSegments[1] == 'market' &&
          request.uri.pathSegments[2] == 'overrides' &&
          request.method == 'DELETE') {
        final market = request.uri.pathSegments[3].trim().toLowerCase();
        final symbol = request.uri.pathSegments[4].trim().toUpperCase();
        final deleted = _manualOverrides.remove('$market:$symbol') != null;
        _json(
          request.response,
          deleted ? HttpStatus.ok : HttpStatus.notFound,
          {
            'ok': deleted,
            'market': market,
            'symbol': symbol,
          },
        );
        continue;
      }

      if (request.uri.pathSegments.length == 5 &&
          request.uri.pathSegments[0] == 'api' &&
          request.uri.pathSegments[1] == 'market' &&
          request.uri.pathSegments[2] == 'overrides') {
        _json(request.response, HttpStatus.methodNotAllowed, {'error': 'Method not allowed'});
        continue;
      }

      if (request.uri.path == '/api/gift-cards/recharge') {
        if (request.method == 'POST') {
          await _handleGiftCardRecharge(request);
          continue;
        }
        if (request.method == 'GET') {
          if (!_isAdminRequest(request)) {
            _json(request.response, HttpStatus.unauthorized, {'error': 'Unauthorized'});
            continue;
          }
          _recordAuditEvent(request, 'list_recharges');
          _json(request.response, HttpStatus.ok, {
            'recharges': _giftCardRecharges,
            'count': _giftCardRecharges.length,
          });
          continue;
        }
        _json(request.response, HttpStatus.methodNotAllowed, {'error': 'Method not allowed'});
        continue;
      }

      if (request.uri.pathSegments.length == 4 &&
          request.uri.pathSegments[0] == 'api' &&
          request.uri.pathSegments[1] == 'gift-cards' &&
          request.uri.pathSegments[2] == 'recharge' &&
          request.method == 'DELETE') {
        if (!_isAdminRequest(request)) {
          _json(request.response, HttpStatus.unauthorized, {'error': 'Unauthorized'});
          continue;
        }
        final idStr = request.uri.pathSegments[3];
        final id = int.tryParse(idStr);
        if (id == null) {
          _json(request.response, HttpStatus.badRequest, {'error': 'ID invalide'});
          continue;
        }
        final idx = _giftCardRecharges.indexWhere((r) => r['id'] == id);
        if (idx == -1) {
          _json(request.response, HttpStatus.notFound, {'error': 'Recharge non trouvée'});
          continue;
        }
        _giftCardRecharges.removeAt(idx);
        _recordAuditEvent(request, 'delete_recharge:$id');
        unawaited(_saveRechargesToDisk());
        _json(request.response, HttpStatus.ok, {'ok': true, 'deleted': id});
        continue;
      }

      if (request.uri.path == '/api/admin/audit-log') {
        if (request.method != 'GET') {
          _json(request.response, HttpStatus.methodNotAllowed, {'error': 'Method not allowed'});
          continue;
        }
        if (!_isAdminRequest(request)) {
          _json(request.response, HttpStatus.unauthorized, {'error': 'Unauthorized'});
          continue;
        }
        _recordAuditEvent(request, 'read_audit_log');
        _json(request.response, HttpStatus.ok, {
          'events': _adminAuditLog,
          'count': _adminAuditLog.length,
        });
        continue;
      }

      if (request.uri.path == '/api/deposit') {
        if (request.method == 'POST') {
          await _handleDeposit(request);
          continue;
        }
        if (request.method == 'GET') {
          if (!_isAdminRequest(request)) {
            _json(request.response, HttpStatus.unauthorized, {'error': 'Unauthorized'});
            continue;
          }
          _recordAuditEvent(request, 'list_deposits');
          _json(request.response, HttpStatus.ok, {
            'deposits': _deposits,
            'count': _deposits.length,
          });
          continue;
        }
        _json(request.response, HttpStatus.methodNotAllowed, {'error': 'Method not allowed'});
        continue;
      }

      if (request.uri.pathSegments.length == 3 &&
          request.uri.pathSegments[0] == 'api' &&
          request.uri.pathSegments[1] == 'deposit' &&
          request.method == 'DELETE') {
        if (!_isAdminRequest(request)) {
          _json(request.response, HttpStatus.unauthorized, {'error': 'Unauthorized'});
          continue;
        }
        final idStr = request.uri.pathSegments[2];
        final id = int.tryParse(idStr);
        if (id == null) {
          _json(request.response, HttpStatus.badRequest, {'error': 'ID invalide'});
          continue;
        }
        final idx = _deposits.indexWhere((d) => d['id'] == id);
        if (idx == -1) {
          _json(request.response, HttpStatus.notFound, {'error': 'Dépôt non trouvé'});
          continue;
        }
        _deposits.removeAt(idx);
        _recordAuditEvent(request, 'delete_deposit:$id');
        _json(request.response, HttpStatus.ok, {'ok': true, 'deleted': id});
        continue;
      }

      _json(
        request.response,
        HttpStatus.notFound,
        {'error': 'Not found'},
      );
    } catch (_) {
      _json(
        request.response,
        HttpStatus.badGateway,
        {'error': 'Upstream request failed'},
      );
    }
  }
}

Uri _withQuery(Uri uri, Map<String, String> query) {
  if (query.isEmpty) return uri;
  return uri.replace(queryParameters: query);
}

Future<void> _proxyGet(http.Client client, Uri uri, HttpResponse response) async {
  final upstream = await client.get(uri).timeout(const Duration(seconds: 20));
  response.statusCode = upstream.statusCode;
  final contentType = upstream.headers['content-type'];
  if (contentType != null && contentType.isNotEmpty) {
    response.headers.set(HttpHeaders.contentTypeHeader, contentType);
  } else {
    response.headers.contentType = ContentType.json;
  }
  response.write(upstream.body);
  await response.close();
}

void _setCorsHeaders(HttpResponse response) {
  response.headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
  response.headers.set(HttpHeaders.accessControlAllowMethodsHeader, 'GET, POST, PUT, DELETE, OPTIONS');
  response.headers.set(HttpHeaders.accessControlAllowHeadersHeader, 'Content-Type');
}

void _json(HttpResponse response, int statusCode, Object body) {
  response.statusCode = statusCode;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
  response.close();
}

Future<void> _serveCryptoMarket(http.Client client, HttpRequest request) async {
  final tickers = await _fetchCryptoTickers(client);
  final limit = int.tryParse(request.uri.queryParameters['limit'] ?? '');
  final normalized = _applyOverrides(
    market: 'crypto',
    sourceTickers: tickers,
    fallbackQuoteAsset: 'USDT',
  );
  _json(
    request.response,
    HttpStatus.ok,
    {
      'market': 'crypto',
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'tickers': limit != null && limit > 0 && normalized.length > limit
          ? normalized.take(limit).toList(growable: false)
          : normalized,
    },
  );
}

Future<void> _serveRealAssetsMarket(http.Client client, HttpRequest request) async {
  final tickers = await _fetchRealAssetsTickers(client);
  final limit = int.tryParse(request.uri.queryParameters['limit'] ?? '');
  final normalized = _applyOverrides(
    market: 'real-assets',
    sourceTickers: tickers,
    fallbackQuoteAsset: 'USD',
  );
  _json(
    request.response,
    HttpStatus.ok,
    {
      'market': 'real-assets',
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'tickers': limit != null && limit > 0 && normalized.length > limit
          ? normalized.take(limit).toList(growable: false)
          : normalized,
    },
  );
}

Future<void> _handleGiftCardRecharge(HttpRequest request) async {
  final payload = await utf8.decoder.bind(request).join();
  late final Object? decoded;
  try {
    decoded = jsonDecode(payload);
  } catch (_) {
    _json(request.response, HttpStatus.badRequest, {'error': 'JSON invalide'});
    return;
  }
  if (decoded is! Map<String, dynamic>) {
    _json(request.response, HttpStatus.badRequest, {'error': 'Payload invalide'});
    return;
  }

  final cardType = (decoded['cardType'] ?? '').toString().trim();
  final code = (decoded['code'] ?? '').toString().trim();
  final amount = double.tryParse(decoded['amount']?.toString() ?? '');
  final currency = (decoded['currency'] ?? '').toString().trim();
  final walletAddress = decoded['walletAddress']?.toString().trim();
  final userId = decoded['userId']?.toString().trim();

  if (cardType.isEmpty || code.isEmpty || amount == null || amount <= 0) {
    _json(
      request.response,
      HttpStatus.badRequest,
      {'error': 'Champs requis: cardType, code, amount (> 0)'},
    );
    return;
  }

  final recharge = {
    'id': _giftCardRecharges.length + 1,
    'cardType': cardType,
    'code': code,
    'amount': amount,
    if (currency.isNotEmpty) 'currency': currency,
    if (walletAddress != null && walletAddress.isNotEmpty)
      'walletAddress': walletAddress,
    if (userId != null && userId.isNotEmpty) 'userId': userId,
    'receivedAt': DateTime.now().toUtc().toIso8601String(),
  };
  _giftCardRecharges.add(recharge);
  unawaited(_saveRechargesToDisk());

  _json(request.response, HttpStatus.ok, {'ok': true, 'recharge': recharge});
}

Future<void> _handleDeposit(HttpRequest request) async {
  if (!_isDepositRequest(request)) {
    _json(request.response, HttpStatus.unauthorized, {'error': 'Unauthorized'});
    return;
  }

  final payload = await utf8.decoder.bind(request).join();
  late final Object? decoded;
  try {
    decoded = jsonDecode(payload);
  } catch (_) {
    _json(request.response, HttpStatus.badRequest, {'error': 'JSON invalide'});
    return;
  }
  if (decoded is! Map<String, dynamic>) {
    _json(request.response, HttpStatus.badRequest, {'error': 'Payload invalide'});
    return;
  }

  final txHash = (decoded['txHash'] ?? '').toString().trim();
  final amount = double.tryParse(decoded['amount']?.toString() ?? '');
  final currency = (decoded['currency'] ?? 'USDT').toString().trim();
  final walletAddress = decoded['walletAddress']?.toString().trim();
  final network = (decoded['network'] ?? '').toString().trim();
  final userId = decoded['userId']?.toString().trim();

  if (txHash.isEmpty || amount == null || amount <= 0) {
    _json(
      request.response,
      HttpStatus.badRequest,
      {'error': 'Champs requis: txHash, amount (> 0)'},
    );
    return;
  }

  final deposit = {
    'id': _deposits.length + 1,
    'txHash': txHash,
    'amount': amount,
    'currency': currency,
    if (walletAddress != null && walletAddress.isNotEmpty)
      'walletAddress': walletAddress,
    if (network.isNotEmpty) 'network': network,
    if (userId != null && userId.isNotEmpty) 'userId': userId,
    'receivedAt': DateTime.now().toUtc().toIso8601String(),
  };
  _deposits.add(deposit);

  _json(request.response, HttpStatus.ok, {'ok': true, 'deposit': deposit});
}

Future<void> _upsertManualOverride(HttpRequest request) async {
  final payload = await utf8.decoder.bind(request).join();
  late final Object? decoded;
  try {
    decoded = jsonDecode(payload);
  } catch (_) {
    _json(request.response, HttpStatus.badRequest, {'error': 'JSON invalide'});
    return;
  }
  if (decoded is! Map<String, dynamic>) {
    _json(request.response, HttpStatus.badRequest, {'error': 'Payload invalide'});
    return;
  }

  final market = (decoded['market'] ?? '').toString().trim().toLowerCase();
  final symbol = (decoded['symbol'] ?? '').toString().trim().toUpperCase();
  final lastPrice = double.tryParse(decoded['lastPrice']?.toString() ?? '');
  final priceChangePercent =
      double.tryParse(decoded['priceChangePercent']?.toString() ?? '');
  final quoteVolume = double.tryParse(decoded['quoteVolume']?.toString() ?? '');
  final baseAsset = (decoded['baseAsset'] ?? '').toString().trim().toUpperCase();
  final quoteAsset = (decoded['quoteAsset'] ?? '').toString().trim().toUpperCase();
  final name = (decoded['name'] ?? '').toString().trim();
  final unit = (decoded['unit'] ?? '').toString().trim();

  final validMarket = market == 'crypto' || market == 'real-assets';
  if (!validMarket || symbol.isEmpty || lastPrice == null || priceChangePercent == null) {
    _json(
      request.response,
      HttpStatus.badRequest,
      {
        'error': 'Champs requis: market, symbol, lastPrice, priceChangePercent',
      },
    );
    return;
  }

  _manualOverrides['$market:$symbol'] = _MarketOverride(
    market: market,
    symbol: symbol,
    baseAsset: baseAsset.isEmpty ? null : baseAsset,
    quoteAsset: quoteAsset.isEmpty ? null : quoteAsset,
    lastPrice: lastPrice,
    priceChangePercent: priceChangePercent,
    quoteVolume: quoteVolume,
    name: name.isEmpty ? null : name,
    unit: unit.isEmpty ? null : unit,
    updatedAt: DateTime.now().toUtc(),
  );

  _json(
    request.response,
    HttpStatus.ok,
    {
      'ok': true,
      'override': _manualOverrides['$market:$symbol']!.toJson(),
    },
  );
}

Future<List<Map<String, Object?>>> _fetchCryptoTickers(http.Client client) async {
  await _ensureExchangeInfoCache(client);
  final response = await client.get(_binanceTickerUri).timeout(const Duration(seconds: 20));
  if (response.statusCode != 200) {
    throw StateError('Erreur Binance ticker (${response.statusCode})');
  }
  final decodedTickers = jsonDecode(response.body);
  if (decodedTickers is! List) {
    throw const FormatException('Réponse Binance ticker inattendue.');
  }

  final tickers = <Map<String, Object?>>[];
  for (final item in decodedTickers) {
    if (item is! Map<String, dynamic>) continue;
    final symbol = (item['symbol'] ?? '').toString().toUpperCase();
    if (symbol.isEmpty) continue;
    final assets = _symbolCache[symbol];
    if (assets == null) continue;
    final lastPrice = double.tryParse(item['lastPrice']?.toString() ?? '');
    final priceChangePercent =
        double.tryParse(item['priceChangePercent']?.toString() ?? '');
    final quoteVolume = double.tryParse(item['quoteVolume']?.toString() ?? '');
    if (lastPrice == null || priceChangePercent == null || quoteVolume == null) {
      continue;
    }
    tickers.add({
      'symbol': symbol,
      'baseAsset': assets.base,
      'quoteAsset': assets.quote,
      'lastPrice': lastPrice,
      'priceChangePercent': priceChangePercent,
      'quoteVolume': quoteVolume,
      'market': 'crypto',
    });
  }
  tickers.sort(
    (a, b) =>
        ((b['quoteVolume'] as num?) ?? 0).compareTo((a['quoteVolume'] as num?) ?? 0),
  );
  return tickers;
}

Future<void> _ensureExchangeInfoCache(http.Client client) async {
  final now = DateTime.now().toUtc();
  if (_symbolCache.isNotEmpty &&
      _symbolCacheLoadedAt != null &&
      now.difference(_symbolCacheLoadedAt!) < const Duration(hours: 6)) {
    return;
  }

  final response =
      await client.get(_binanceExchangeInfoUri).timeout(const Duration(seconds: 20));
  if (response.statusCode != 200) {
    throw StateError('Erreur Binance exchangeInfo (${response.statusCode})');
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Réponse Binance exchangeInfo inattendue.');
  }
  final rawSymbols = decoded['symbols'];
  if (rawSymbols is! List) {
    throw const FormatException('Liste des symboles Binance introuvable.');
  }

  _symbolCache.clear();
  for (final item in rawSymbols) {
    if (item is! Map<String, dynamic>) continue;
    final symbol = (item['symbol'] ?? '').toString().toUpperCase();
    final baseAsset = (item['baseAsset'] ?? '').toString().toUpperCase();
    final quoteAsset = (item['quoteAsset'] ?? '').toString().toUpperCase();
    if (symbol.isEmpty || baseAsset.isEmpty || quoteAsset.isEmpty) continue;
    _symbolCache[symbol] = (base: baseAsset, quote: quoteAsset);
  }
  _symbolCacheLoadedAt = now;
}

Future<List<Map<String, Object?>>> _fetchRealAssetsTickers(http.Client client) async {
  final symbols = _realAssetSources.map((e) => e.stooqSymbol).join(',');
  final uri = _stooqUriBase.replace(
    queryParameters: {
      's': symbols,
      'f': 'sd2t2ohlcv',
      'h': '',
      'e': 'csv',
    },
  );
  final response = await client.get(uri).timeout(const Duration(seconds: 20));
  if (response.statusCode != 200) {
    throw StateError('Erreur fournisseur actifs réels (${response.statusCode})');
  }

  final lines = const LineSplitter().convert(response.body);
  if (lines.length < 2) return [];
  final byStooqSymbol = <String, Map<String, Object?>>{};
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    final parts = line.split(',');
    if (parts.length < 8) continue;
    final stooqSymbol = parts[0].trim().toLowerCase();
    final open = double.tryParse(parts[3].trim());
    final close = double.tryParse(parts[6].trim());
    final volume = double.tryParse(parts[7].trim().replaceAll(' ', '')) ?? 0;
    if (open == null || close == null || close <= 0) continue;
    final pct = open == 0 ? 0 : ((close - open) / open) * 100;
    byStooqSymbol[stooqSymbol] = {
      'lastPrice': close,
      'priceChangePercent': pct,
      'quoteVolume': volume <= 0 ? 1 : volume,
    };
  }

  final tickers = <Map<String, Object?>>[];
  for (final source in _realAssetSources) {
    final values = byStooqSymbol[source.stooqSymbol];
    if (values == null) continue;
    tickers.add({
      'symbol': source.symbol,
      'baseAsset': source.baseAsset,
      'quoteAsset': source.quoteAsset,
      'lastPrice': values['lastPrice'],
      'priceChangePercent': values['priceChangePercent'],
      'quoteVolume': values['quoteVolume'],
      'name': source.name,
      'unit': source.unit,
      'market': 'real-assets',
    });
  }
  tickers.sort(
    (a, b) =>
        ((b['quoteVolume'] as num?) ?? 0).compareTo((a['quoteVolume'] as num?) ?? 0),
  );
  return tickers;
}

List<Map<String, Object?>> _applyOverrides({
  required String market,
  required List<Map<String, Object?>> sourceTickers,
  required String fallbackQuoteAsset,
}) {
  final merged = <String, Map<String, Object?>>{
    for (final ticker in sourceTickers)
      (ticker['symbol'] ?? '').toString().toUpperCase(): Map<String, Object?>.from(ticker),
  };

  for (final entry in _manualOverrides.entries) {
    if (!entry.key.startsWith('$market:')) continue;
    final override = entry.value;
    final symbol = override.symbol.toUpperCase();
    final existing = merged[symbol] ?? <String, Object?>{'symbol': symbol};
    existing['symbol'] = symbol;
    existing['baseAsset'] = override.baseAsset ??
        (existing['baseAsset']?.toString().toUpperCase() ?? symbol);
    existing['quoteAsset'] = override.quoteAsset ??
        (existing['quoteAsset']?.toString().toUpperCase() ?? fallbackQuoteAsset);
    existing['lastPrice'] = override.lastPrice;
    existing['priceChangePercent'] = override.priceChangePercent;
    existing['quoteVolume'] = override.quoteVolume ?? existing['quoteVolume'] ?? 1;
    existing['market'] = market;
    if (override.name != null) existing['name'] = override.name;
    if (override.unit != null) existing['unit'] = override.unit;
    merged[symbol] = existing;
  }

  final result = merged.values.toList(growable: false);
  result.sort(
    (a, b) =>
        ((b['quoteVolume'] as num?) ?? 0).compareTo((a['quoteVolume'] as num?) ?? 0),
  );
  return result;
}

Map<String, Object> _buildOverridesPayload() {
  return {
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
    'overrides': _manualOverrides.values
        .map((value) => value.toJson())
        .toList(growable: false),
  };
}

class _MarketOverride {
  const _MarketOverride({
    required this.market,
    required this.symbol,
    required this.lastPrice,
    required this.priceChangePercent,
    required this.updatedAt,
    this.baseAsset,
    this.quoteAsset,
    this.quoteVolume,
    this.name,
    this.unit,
  });

  final String market;
  final String symbol;
  final String? baseAsset;
  final String? quoteAsset;
  final double lastPrice;
  final double priceChangePercent;
  final double? quoteVolume;
  final String? name;
  final String? unit;
  final DateTime updatedAt;

  Map<String, Object?> toJson() {
    return {
      'market': market,
      'symbol': symbol,
      'baseAsset': baseAsset,
      'quoteAsset': quoteAsset,
      'lastPrice': lastPrice,
      'priceChangePercent': priceChangePercent,
      'quoteVolume': quoteVolume,
      'name': name,
      'unit': unit,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class _RealAssetSource {
  const _RealAssetSource({
    required this.symbol,
    required this.baseAsset,
    required this.quoteAsset,
    required this.name,
    required this.unit,
    required this.stooqSymbol,
  });

  final String symbol;
  final String baseAsset;
  final String quoteAsset;
  final String name;
  final String unit;
  final String stooqSymbol;
}
