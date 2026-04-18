import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/market_ticker.dart';

class MarketService {
  MarketService({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static final Uri _tickerUri = Uri.parse('https://api.binance.com/api/v3/ticker/24hr');

  Future<List<MarketTicker>> fetchBinanceMarket({
    int limit = 100,
    String quoteAsset = 'USDT',
  }) async {
    final response = await _httpClient.get(_tickerUri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('Erreur Binance (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Réponse Binance inattendue.');
    }

    final normalizedQuoteAsset = quoteAsset.toUpperCase();
    final tickers = <MarketTicker>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      final symbol = (item['symbol'] ?? '').toString().toUpperCase();
      if (!symbol.endsWith(normalizedQuoteAsset)) continue;
      final baseAsset =
          symbol.substring(0, symbol.length - normalizedQuoteAsset.length);
      if (baseAsset.isEmpty) continue;
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
          baseAsset: baseAsset,
          quoteAsset: normalizedQuoteAsset,
          lastPrice: lastPrice,
          priceChangePercent: priceChangePercent,
          quoteVolume: quoteVolume,
        ),
      );
    }

    tickers.sort((a, b) => b.quoteVolume.compareTo(a.quoteVolume));
    if (tickers.length > limit) {
      return tickers.take(limit).toList(growable: false);
    }
    return tickers;
  }
}
