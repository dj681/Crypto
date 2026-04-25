import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_crypto_safe/models/market_ticker.dart';
import 'package:my_crypto_safe/providers/market_provider.dart';
import 'package:my_crypto_safe/services/market_service.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

MarketTicker _ticker({
  required String symbol,
  double price = 100.0,
}) =>
    MarketTicker(
      symbol: symbol,
      baseAsset: symbol.replaceAll('USD', ''),
      quoteAsset: 'USD',
      lastPrice: price,
      priceChangePercent: 0,
      quoteVolume: 0,
    );

MarketProvider _makeProvider() => MarketProvider(
      marketService: MarketService(
        httpClient: MockClient((_) async => http.Response('[]', 200)),
      ),
    );

void main() {
  // Reset SharedPreferences before every test so state doesn't bleed between
  // tests.
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('TradeOrder serialisation', () {
    test('round-trips through JSON', () {
      final original = TradeOrder(
        symbol: 'BTCUSD',
        baseAsset: 'BTC',
        quoteAsset: 'USD',
        market: 'crypto',
        side: TradeSide.buy,
        quantity: 0.5,
        unitPrice: 30000.0,
        executedAt: DateTime.utc(2026, 4, 25, 10),
      );

      final restored = TradeOrder.fromJson(original.toJson());

      expect(restored.symbol, original.symbol);
      expect(restored.baseAsset, original.baseAsset);
      expect(restored.quoteAsset, original.quoteAsset);
      expect(restored.market, original.market);
      expect(restored.side, original.side);
      expect(restored.quantity, original.quantity);
      expect(restored.unitPrice, original.unitPrice);
      expect(restored.executedAt, original.executedAt);
      expect(restored.total, original.total);
    });

    test('sell side round-trips', () {
      final order = TradeOrder(
        symbol: 'ETHUSD',
        baseAsset: 'ETH',
        quoteAsset: 'USD',
        market: 'crypto',
        side: TradeSide.sell,
        quantity: 1.0,
        unitPrice: 2000.0,
        executedAt: DateTime.utc(2026, 4, 25),
      );
      expect(TradeOrder.fromJson(order.toJson()).side, TradeSide.sell);
    });
  });

  group('MarketProvider persistence', () {
    test('loadState falls back to default balance when no data is saved', () async {
      final provider = _makeProvider();
      await provider.loadState();
      expect(provider.accountBalanceUsdt, 10000.0);
    });

    test('saveState then loadState restores balance', () async {
      final provider = _makeProvider();
      provider.placeOrder(
        market: 'crypto',
        ticker: _ticker(symbol: 'BTCUSD', price: 1000.0),
        side: TradeSide.buy,
        quantity: 2.0, // costs 2000 USDT
      );
      // placeOrder calls saveState() internally; wait for the microtask queue.
      await Future<void>.delayed(Duration.zero);

      final restored = _makeProvider();
      await restored.loadState();

      expect(restored.accountBalanceUsdt, closeTo(8000.0, 0.001));
    });

    test('saveState then loadState restores position', () async {
      final provider = _makeProvider();
      provider.placeOrder(
        market: 'crypto',
        ticker: _ticker(symbol: 'BTCUSD', price: 500.0),
        side: TradeSide.buy,
        quantity: 1.5,
      );
      await Future<void>.delayed(Duration.zero);

      final restored = _makeProvider();
      await restored.loadState();

      expect(
        restored.getPosition(market: 'crypto', symbol: 'BTCUSD'),
        closeTo(1.5, 0.000001),
      );
    });

    test('saveState then loadState restores orders list', () async {
      final provider = _makeProvider();
      provider.placeOrder(
        market: 'crypto',
        ticker: _ticker(symbol: 'ETHUSD', price: 2000.0),
        side: TradeSide.buy,
        quantity: 1.0,
      );
      await Future<void>.delayed(Duration.zero);

      final restored = _makeProvider();
      await restored.loadState();

      expect(restored.orders.length, 1);
      expect(restored.orders.first.symbol, 'ETHUSD');
      expect(restored.orders.first.side, TradeSide.buy);
    });

    test('deductBalance persists updated balance', () async {
      final provider = _makeProvider();
      provider.deductBalance(500.0);
      await Future<void>.delayed(Duration.zero);

      final restored = _makeProvider();
      await restored.loadState();

      expect(restored.accountBalanceUsdt, closeTo(9500.0, 0.001));
    });

    test('loadState notifies listeners', () async {
      final provider = _makeProvider();
      // Put some data in prefs first.
      final other = _makeProvider();
      other.placeOrder(
        market: 'crypto',
        ticker: _ticker(symbol: 'BTCUSD', price: 100.0),
        side: TradeSide.buy,
        quantity: 1.0,
      );
      await Future<void>.delayed(Duration.zero);

      var notified = false;
      provider.addListener(() => notified = true);
      await provider.loadState();

      expect(notified, isTrue);
    });

    test('position is removed after selling entire holding and persisted', () async {
      final provider = _makeProvider();
      final ticker = _ticker(symbol: 'BTCUSD', price: 100.0);
      provider.placeOrder(
        market: 'crypto',
        ticker: ticker,
        side: TradeSide.buy,
        quantity: 1.0,
      );
      provider.placeOrder(
        market: 'crypto',
        ticker: ticker,
        side: TradeSide.sell,
        quantity: 1.0,
      );
      await Future<void>.delayed(Duration.zero);

      final restored = _makeProvider();
      await restored.loadState();

      expect(restored.getPosition(market: 'crypto', symbol: 'BTCUSD'), 0.0);
      expect(restored.accountBalanceUsdt, closeTo(10000.0, 0.001));
    });
  });
}
