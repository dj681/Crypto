import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:my_crypto_safe/services/market_service.dart';

void main() {
  group('MarketService', () {
    test('fetchBinanceMarket filters on USDT and sorts by quoteVolume', () async {
      final mockClient = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.binance.com/api/v3/ticker/24hr',
        );
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
        return http.Response('error', 500);
      });

      final service = MarketService(httpClient: mockClient);
      await expectLater(
        service.fetchBinanceMarket(),
        throwsA(isA<StateError>()),
      );
    });
  });
}
