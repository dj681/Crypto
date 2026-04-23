import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:my_crypto_safe/services/market_service.dart';

void main() {
  group('MarketService', () {
    test('fetchBinanceMarket filters on USDT and sorts by quoteVolume', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://api.binance.com/api/v3/exchangeInfo') {
          return http.Response(
            '''
{
  "symbols": [
    {"symbol":"ETHUSDT","baseAsset":"ETH","quoteAsset":"USDT"},
    {"symbol":"BTCUSDT","baseAsset":"BTC","quoteAsset":"USDT"},
    {"symbol":"BTCBUSD","baseAsset":"BTC","quoteAsset":"BUSD"}
  ]
}
''',
            200,
          );
        }
        expect(request.url.toString(), 'https://api.binance.com/api/v3/ticker/24hr');
        return http.Response(
          '''
[
  {"symbol":"ETHUSDT","lastPrice":"2000","priceChangePercent":"1.5","quoteVolume":"6000"},
  {"symbol":"BTCUSDT","lastPrice":"30000","priceChangePercent":"2.0","quoteVolume":"12000"},
  {"symbol":"BTCBUSD","lastPrice":"29900","priceChangePercent":"1.9","quoteVolume":"20000"}
]
''',
          200,
        );
      });

      final service = MarketService(httpClient: mockClient);
      final tickers = await service.fetchBinanceMarket(limit: 10);

      expect(tickers.length, 2);
      expect(tickers.first.symbol, 'BTCUSDT');
      expect(tickers.last.symbol, 'ETHUSDT');
    });

    test('fetchBinanceMarket throws when API status is not 200', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://api.binance.com/api/v3/exchangeInfo') {
          return http.Response(
            '{"symbols":[{"symbol":"BTCUSDT","baseAsset":"BTC","quoteAsset":"USDT"}]}',
            200,
          );
        }
        return http.Response('error', 500);
      });

      final service = MarketService(httpClient: mockClient);
      await expectLater(
        service.fetchBinanceMarket(),
        throwsA(isA<StateError>()),
      );
    });

    test('fetchBinanceMarket ignores rows with invalid numeric values', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://api.binance.com/api/v3/exchangeInfo') {
          return http.Response(
            '''
{
  "symbols": [
    {"symbol":"SOLUSDT","baseAsset":"SOL","quoteAsset":"USDT"},
    {"symbol":"ADAUSDT","baseAsset":"ADA","quoteAsset":"USDT"}
  ]
}
''',
            200,
          );
        }
        return http.Response(
          '''
[
  {"symbol":"SOLUSDT","lastPrice":"invalid","priceChangePercent":"1.1","quoteVolume":"4000"},
  {"symbol":"ADAUSDT","lastPrice":"0.50","priceChangePercent":"-0.5","quoteVolume":"3000"}
]
''',
          200,
        );
      });

      final service = MarketService(httpClient: mockClient);
      final tickers = await service.fetchBinanceMarket();

      expect(tickers.length, 1);
      expect(tickers.first.symbol, 'ADAUSDT');
    });

    test('fetchRealAssetsMarket returns fallback assets when backend is disabled', () async {
      final service = MarketService(httpClient: MockClient((request) async {
        return http.Response('', 500);
      }));

      final tickers = await service.fetchRealAssetsMarket();

      expect(tickers, isNotEmpty);
      expect(tickers.any((ticker) => ticker.symbol == 'XAUUSD'), isTrue);
    });
  });
}
