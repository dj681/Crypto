import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:my_crypto_safe/services/market_service.dart';

void main() {
  group('MarketService', () {
    test('fetchBinanceMarket sorts by quoteVolume', () async {
      final mockClient = MockClient((request) async {
        expect(
          request.url.toString(),
          startsWith('https://api.coingecko.com/api/v3/coins/markets'),
        );
        return http.Response(
          '''
[
  {"symbol":"eth","current_price":2000.0,"price_change_percentage_24h":1.5,"total_volume":6000.0},
  {"symbol":"btc","current_price":30000.0,"price_change_percentage_24h":2.0,"total_volume":12000.0}
]
''',
          200,
        );
      });

      final service = MarketService(httpClient: mockClient);
      final tickers = await service.fetchBinanceMarket(limit: 10);

      expect(tickers.length, 2);
      expect(tickers.first.symbol, 'BTCUSD');
      expect(tickers.last.symbol, 'ETHUSD');
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

    test('fetchBinanceMarket ignores rows with null or missing numeric values', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '''
[
  {"symbol":"sol","current_price":null,"price_change_percentage_24h":1.1,"total_volume":4000.0},
  {"symbol":"ada","current_price":0.50,"price_change_percentage_24h":-0.5,"total_volume":3000.0}
]
''',
          200,
        );
      });

      final service = MarketService(httpClient: mockClient);
      final tickers = await service.fetchBinanceMarket();

      expect(tickers.length, 1);
      expect(tickers.first.symbol, 'ADAUSD');
    });
  });
}
