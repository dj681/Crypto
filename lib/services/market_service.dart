import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/market_ticker.dart';

class MarketService {
  MarketService({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static final Uri _tickerUri = Uri.parse('https://api.binance.com/api/v3/ticker/24hr');
  static final Uri _exchangeInfoUri =
      Uri.parse('https://api.binance.com/api/v3/exchangeInfo');

  // Cache the symbol→(base,quote) map: exchangeInfo is ~3 MB and rarely changes.
  // This service runs only on the main Flutter isolate, so no synchronization needed.
  Map<String, ({String base, String quote})>? _symbolCache;

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
}
