import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/market_ticker.dart';

class MarketService {
  MarketService({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  // CoinGecko public API supports CORS from browsers, unlike Binance.
  static const String _quoteLabel = 'USD';
  static Uri _marketsUri({int perPage = 250}) => Uri.parse(
      'https://api.coingecko.com/api/v3/coins/markets'
      '?vs_currency=usd&order=market_cap_desc&per_page=$perPage&page=1');

  Future<List<MarketTicker>> fetchBinanceMarket({int? limit}) async {
    final perPage = (limit != null && limit > 0) ? limit.clamp(1, 250) : 250;
    final response = await _httpClient
        .get(_marketsUri(perPage: perPage))
        .timeout(const Duration(seconds: 20))
        .catchError((Object e) => throw StateError('Erreur réseau marché crypto : $e'));

    if (response.statusCode != 200) {
      throw StateError('Erreur API marché (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Réponse API marché inattendue.');
    }

    final tickers = <MarketTicker>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      final baseAsset = (item['symbol'] ?? '').toString().toUpperCase();
      if (baseAsset.isEmpty) continue;

      final lastPrice = (item['current_price'] as num?)?.toDouble();
      final priceChangePercent =
          (item['price_change_percentage_24h'] as num?)?.toDouble();
      final quoteVolume = (item['total_volume'] as num?)?.toDouble();
      if (lastPrice == null || priceChangePercent == null || quoteVolume == null) {
        continue;
      }

      tickers.add(
        MarketTicker(
          symbol: '$baseAsset$_quoteLabel',
          baseAsset: baseAsset,
          quoteAsset: _quoteLabel,
          lastPrice: lastPrice,
          priceChangePercent: priceChangePercent,
          quoteVolume: quoteVolume,
        ),
      );
    }

    tickers.sort((a, b) => b.quoteVolume.compareTo(a.quoteVolume));
    return tickers;
  }
}
