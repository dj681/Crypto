import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/market_ticker.dart';

class MarketService {
  MarketService({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const String _backendBaseUrl =
      String.fromEnvironment('BACKEND_URL', defaultValue: '');
  static final Uri? _backendUri = _parseBackendBaseUri(_backendBaseUrl);
  static final Uri _tickerUri = _resolveApiUri(
    backendPath: '/api/binance/ticker24h',
    fallbackUrl: 'https://api.binance.com/api/v3/ticker/24hr',
  );
  static final Uri _exchangeInfoUri = _resolveApiUri(
    backendPath: '/api/binance/exchangeInfo',
    fallbackUrl: 'https://api.binance.com/api/v3/exchangeInfo',
  );
  static final Uri _cryptoMarketUri = _resolveApiUri(
    backendPath: '/api/market/crypto',
    // Fallback is unused: when no backend is configured, fetchCryptoMarket
    // calls fetchCoinGeckoMarket directly to avoid browser CORS issues.
    fallbackUrl: '',
  );
  // CoinGecko supports browser CORS and is used as the fallback when no backend
  // proxy is configured, replacing direct Binance calls which are blocked by
  // CORS in a browser context.
  static final Uri _coinGeckoUri = Uri.parse(
    'https://api.coingecko.com/api/v3/coins/markets'
    '?vs_currency=usd'
    '&order=market_cap_desc'
    '&per_page=250'
    '&page=1'
    '&sparkline=false'
    '&price_change_percentage=24h',
  );
  static final Uri _realAssetsMarketUri = _resolveApiUri(
    backendPath: '/api/market/real-assets',
    fallbackUrl: '',
  );
  static final bool _hasValidBackend = _backendUri != null;

  // Cache the symbol→(base,quote) map: exchangeInfo is ~3 MB and rarely changes.
  // This service runs only on the main Flutter isolate, so no synchronization needed.
  Map<String, ({String base, String quote})>? _symbolCache;

  static Uri _resolveApiUri({
    required String backendPath,
    required String fallbackUrl,
  }) {
    final parsed = _backendUri;
    if (parsed == null) {
      return Uri.parse(fallbackUrl);
    }
    final basePath = parsed.path.endsWith('/')
        ? parsed.path.substring(0, parsed.path.length - 1)
        : parsed.path;
    return parsed.replace(
      path: '$basePath$backendPath',
      queryParameters: null,
    );
  }

  static Uri? _parseBackendBaseUri(String value) {
    final backend = value.trim();
    if (backend.isEmpty) return null;
    final parsed = Uri.tryParse(backend);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) return null;
    return parsed;
  }

  Future<List<MarketTicker>> fetchCryptoMarket({int? limit}) async {
    if (_hasValidBackend) {
      final response = await _httpClient
          .get(_cryptoMarketUri)
          .timeout(const Duration(seconds: 20))
          .catchError(
              (Object e) => throw StateError('Erreur réseau marché crypto: $e'));
      if (response.statusCode != 200) {
        throw StateError('Erreur backend marché crypto (${response.statusCode})');
      }
      return _extractTickers(response.body, limit: limit);
    }
    // No backend configured: use CoinGecko which supports browser CORS,
    // unlike the Binance public API which is blocked cross-origin.
    return fetchCoinGeckoMarket(limit: limit);
  }

  /// Fetches crypto market data from the CoinGecko public API.
  ///
  /// This endpoint supports browser CORS and does not require a proxy backend.
  /// Results are sorted by market cap (descending) as returned by the API.
  Future<List<MarketTicker>> fetchCoinGeckoMarket({int? limit}) async {
    final response = await _httpClient
        .get(_coinGeckoUri)
        .timeout(const Duration(seconds: 20))
        .catchError(
            (Object e) => throw StateError('Erreur réseau CoinGecko: $e'));
    if (response.statusCode != 200) {
      throw StateError('Erreur CoinGecko (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Réponse CoinGecko inattendue: liste attendue.');
    }
    final tickers = <MarketTicker>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      final rawSymbol = (item['symbol'] ?? '').toString().trim().toUpperCase();
      if (rawSymbol.isEmpty) continue;
      final lastPrice = (item['current_price'] as num?)?.toDouble();
      final priceChangePercent =
          (item['price_change_percentage_24h'] as num?)?.toDouble();
      final quoteVolume = (item['total_volume'] as num?)?.toDouble();
      if (lastPrice == null || priceChangePercent == null || quoteVolume == null) {
        continue;
      }
      tickers.add(
        MarketTicker(
          symbol: '${rawSymbol}USD',
          baseAsset: rawSymbol,
          quoteAsset: 'USD',
          lastPrice: lastPrice,
          priceChangePercent: priceChangePercent,
          quoteVolume: quoteVolume,
          name: (item['name'] as String?)?.trim(),
        ),
      );
    }
    if (limit != null && limit > 0 && tickers.length > limit) {
      return tickers.take(limit).toList(growable: false);
    }
    return tickers;
  }

  Future<List<MarketTicker>> fetchRealAssetsMarket({int? limit}) async {
    if (_hasValidBackend) {
      final response = await _httpClient
          .get(_realAssetsMarketUri)
          .timeout(const Duration(seconds: 20))
          .catchError(
              (Object e) => throw StateError('Erreur réseau actifs réels: $e'));
      if (response.statusCode != 200) {
        throw StateError('Erreur backend actifs réels (${response.statusCode})');
      }
      return _extractTickers(response.body, limit: limit);
    }
    final defaults = _defaultRealAssets;
    if (limit != null && limit > 0 && defaults.length > limit) {
      return defaults.take(limit).toList(growable: false);
    }
    return defaults;
  }

  Future<List<MarketTicker>> fetchBinanceMarket({
    int? limit,
    String? quoteAsset = 'USDT',
  }) async {
    // Fetch ticker data; only fetch exchangeInfo when the cache is empty.
    final List<http.Response> responses;
    if (_symbolCache == null) {
      responses = await Future.wait([
        _httpClient
            .get(_tickerUri)
            .timeout(const Duration(seconds: 20))
            .catchError((Object e) => throw StateError('Erreur réseau Binance ticker.')),
        _httpClient
            .get(_exchangeInfoUri)
            .timeout(const Duration(seconds: 20))
            .catchError(
                (Object e) => throw StateError('Erreur réseau Binance exchangeInfo.')),
      ]);
    } else {
      responses = [
        await _httpClient
            .get(_tickerUri)
            .timeout(const Duration(seconds: 20))
            .catchError((Object e) => throw StateError('Erreur réseau Binance ticker.')),
      ];
    }

    final tickersResponse = responses[0];

    if (tickersResponse.statusCode != 200) {
      throw StateError('Erreur Binance ticker (${tickersResponse.statusCode})');
    }

    // Build or reuse the symbol cache.
    if (_symbolCache == null) {
      final exchangeInfoResponse = responses[1];
      if (exchangeInfoResponse.statusCode != 200) {
        throw StateError(
            'Erreur Binance exchangeInfo (${exchangeInfoResponse.statusCode})');
      }

      final decodedExchangeInfo = jsonDecode(exchangeInfoResponse.body);
      if (decodedExchangeInfo is! Map<String, dynamic>) {
        throw const FormatException('Réponse Binance exchangeInfo inattendue.');
      }

      final rawSymbols = decodedExchangeInfo['symbols'];
      if (rawSymbols is! List) {
        throw const FormatException('Liste des symboles Binance introuvable.');
      }

      final cache = <String, ({String base, String quote})>{};
      for (final item in rawSymbols) {
        if (item is! Map<String, dynamic>) continue;
        final symbol = (item['symbol'] ?? '').toString().toUpperCase();
        final baseAsset = (item['baseAsset'] ?? '').toString().toUpperCase();
        final listedQuoteAsset = (item['quoteAsset'] ?? '').toString().toUpperCase();
        if (symbol.isEmpty || baseAsset.isEmpty || listedQuoteAsset.isEmpty) continue;
        cache[symbol] = (base: baseAsset, quote: listedQuoteAsset);
      }
      _symbolCache = cache;
    }

    // At this point _symbolCache is guaranteed non-null:
    // either it was already populated before this call, or the block above just set it.
    final symbolToBaseQuote = _symbolCache!;

    final decodedTickers = jsonDecode(tickersResponse.body);
    if (decodedTickers is! List) {
      throw const FormatException('Réponse Binance ticker inattendue.');
    }

    final normalizedQuoteAsset = quoteAsset?.trim().toUpperCase();
    final tickers = <MarketTicker>[];
    for (final item in decodedTickers) {
      if (item is! Map<String, dynamic>) continue;
      final symbol = (item['symbol'] ?? '').toString().toUpperCase();
      final assets = symbolToBaseQuote[symbol];
      if (assets == null) continue;
      if (normalizedQuoteAsset != null && assets.quote != normalizedQuoteAsset) {
        continue;
      }

      final lastPrice = double.tryParse(item['lastPrice']?.toString() ?? '');
      final priceChangePercent =
          double.tryParse(item['priceChangePercent']?.toString() ?? '');
      final quoteVolume = double.tryParse(item['quoteVolume']?.toString() ?? '');
      if (lastPrice == null || priceChangePercent == null || quoteVolume == null) {
        continue;
      }

      tickers.add(
        MarketTicker(
          symbol: symbol,
          baseAsset: assets.base,
          quoteAsset: assets.quote,
          lastPrice: lastPrice,
          priceChangePercent: priceChangePercent,
          quoteVolume: quoteVolume,
        ),
      );
    }

    tickers.sort((a, b) => b.quoteVolume.compareTo(a.quoteVolume));
    if (limit != null && limit > 0 && tickers.length > limit) {
      return tickers.take(limit).toList(growable: false);
    }
    return tickers;
  }

  List<MarketTicker> _extractTickers(String body, {int? limit}) {
    final decoded = jsonDecode(body);
    final rawTickers = decoded is Map<String, dynamic> ? decoded['tickers'] : decoded;
    if (rawTickers is! List) {
      throw FormatException(
        'Réponse marché inattendue: liste de tickers attendue, reçu ${rawTickers.runtimeType}.',
      );
    }
    final tickers = <MarketTicker>[];
    for (final item in rawTickers) {
      if (item is! Map<String, dynamic>) continue;
      try {
        final ticker = MarketTicker.fromJson(item);
        if (ticker.symbol.isEmpty ||
            ticker.baseAsset.isEmpty ||
            ticker.quoteAsset.isEmpty) {
          continue;
        }
        tickers.add(ticker);
      } catch (_) {
        continue;
      }
    }
    tickers.sort((a, b) => b.quoteVolume.compareTo(a.quoteVolume));
    if (limit != null && limit > 0 && tickers.length > limit) {
      return tickers.take(limit).toList(growable: false);
    }
    return tickers;
  }

  static const List<MarketTicker> _defaultRealAssets = [
    MarketTicker(
      symbol: 'XAUUSD',
      baseAsset: 'XAU',
      quoteAsset: 'USD',
      lastPrice: 2388.42,
      priceChangePercent: 0.87,
      quoteVolume: 1,
      name: 'Or',
      unit: 'oz',
      market: 'real-assets',
    ),
    MarketTicker(
      symbol: 'BRNUSD',
      baseAsset: 'BRN',
      quoteAsset: 'USD',
      lastPrice: 83.16,
      priceChangePercent: -0.42,
      quoteVolume: 1,
      name: 'Pétrole Brent',
      unit: 'baril',
      market: 'real-assets',
    ),
    MarketTicker(
      symbol: 'WTIUSD',
      baseAsset: 'WTI',
      quoteAsset: 'USD',
      lastPrice: 79.95,
      priceChangePercent: -0.35,
      quoteVolume: 1,
      name: 'Pétrole WTI',
      unit: 'baril',
      market: 'real-assets',
    ),
    MarketTicker(
      symbol: 'XAGUSD',
      baseAsset: 'XAG',
      quoteAsset: 'USD',
      lastPrice: 28.74,
      priceChangePercent: 0.65,
      quoteVolume: 1,
      name: 'Argent',
      unit: 'oz',
      market: 'real-assets',
    ),
    MarketTicker(
      symbol: 'XPTUSD',
      baseAsset: 'XPT',
      quoteAsset: 'USD',
      lastPrice: 980.30,
      priceChangePercent: 0.18,
      quoteVolume: 1,
      name: 'Platine',
      unit: 'oz',
      market: 'real-assets',
    ),
  ];
}
