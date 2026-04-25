import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/market_ticker.dart';
import '../services/market_service.dart';

enum MarketStatus { idle, loading, ready, error }
enum TradeSide { buy, sell }

class TradeOrder {
  const TradeOrder({
    required this.symbol,
    required this.baseAsset,
    required this.quoteAsset,
    required this.market,
    required this.side,
    required this.quantity,
    required this.unitPrice,
    required this.executedAt,
  });

  factory TradeOrder.fromJson(Map<String, dynamic> json) => TradeOrder(
        symbol: json['symbol'] as String,
        baseAsset: json['baseAsset'] as String,
        quoteAsset: json['quoteAsset'] as String,
        market: json['market'] as String,
        side: json['side'] == 'buy' ? TradeSide.buy : TradeSide.sell,
        quantity: (json['quantity'] as num).toDouble(),
        unitPrice: (json['unitPrice'] as num).toDouble(),
        executedAt: DateTime.parse(json['executedAt'] as String),
      );

  final String symbol;
  final String baseAsset;
  final String quoteAsset;
  final String market;
  final TradeSide side;
  final double quantity;
  final double unitPrice;
  final DateTime executedAt;

  double get total => quantity * unitPrice;

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'baseAsset': baseAsset,
        'quoteAsset': quoteAsset,
        'market': market,
        'side': side == TradeSide.buy ? 'buy' : 'sell',
        'quantity': quantity,
        'unitPrice': unitPrice,
        'executedAt': executedAt.toIso8601String(),
      };
}

class MarketProvider extends ChangeNotifier {
  static const _defaultAccountBalanceUsdt = 10000.0;
  // TODO(dj681): Replace this fixed fallback with a live FX feed for EUR display.
  // Fixed fallback rate used for UI-only conversion while no FX feed exists yet
  // (set in April 2026).
  static const _usdtToEurRate = 0.92;
  // Tolerance to avoid tiny floating-point dust when a position should be closed.
  static const _positionEpsilon = 0.00000001;

  MarketProvider({
    required MarketService marketService,
    double initialAccountBalanceUsdt = _defaultAccountBalanceUsdt,
  })  : _marketService = marketService,
        _accountBalanceUsdt = initialAccountBalanceUsdt;

  final MarketService _marketService;

  List<MarketTicker> _cryptoTickers = [];
  List<MarketTicker> _realAssetTickers = [];
  MarketStatus _cryptoStatus = MarketStatus.idle;
  MarketStatus _realAssetsStatus = MarketStatus.idle;
  String? _cryptoError;
  String? _realAssetsError;
  double _accountBalanceUsdt;
  final Map<String, double> _positions = {};
  final List<TradeOrder> _orders = [];

  List<MarketTicker> get tickers => List.unmodifiable(_cryptoTickers);
  List<MarketTicker> get realAssetTickers => List.unmodifiable(_realAssetTickers);
  MarketStatus get status => _cryptoStatus;
  MarketStatus get realAssetsStatus => _realAssetsStatus;
  String? get error => _cryptoError;
  String? get realAssetsError => _realAssetsError;
  double get accountBalanceUsdt => _accountBalanceUsdt;
  double get accountBalanceEur => _accountBalanceUsdt * _usdtToEurRate;
  List<TradeOrder> get orders => List.unmodifiable(_orders);
  bool get isLoading => _cryptoStatus == MarketStatus.loading;
  bool get isRealAssetsLoading => _realAssetsStatus == MarketStatus.loading;

  String _positionKey(String market, String symbol) => '$market::$symbol';

  double getPosition({
    required String market,
    required String symbol,
  }) {
    return _positions[_positionKey(market, symbol)] ?? 0;
  }

  List<TradeOrder> ordersFor({
    required String market,
    required String symbol,
  }) {
    return _orders
        .where((order) => order.market == market && order.symbol == symbol)
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  static const _keyBalance = 'market_balance_usdt';
  static const _keyPositions = 'market_positions';
  static const _keyOrders = 'market_orders';

  /// Restores persisted balance, positions and orders from [SharedPreferences].
  /// Falls back to defaults when no saved state exists (e.g. first launch).
  Future<void> loadState() async {
    final prefs = await SharedPreferences.getInstance();

    final balance = prefs.getDouble(_keyBalance);
    if (balance != null) {
      _accountBalanceUsdt = balance;
    }

    final positionsRaw = prefs.getString(_keyPositions);
    if (positionsRaw != null) {
      final decoded = jsonDecode(positionsRaw) as Map<String, dynamic>;
      _positions
        ..clear()
        ..addAll(decoded.map((k, v) => MapEntry(k, (v as num).toDouble())));
    }

    final ordersRaw = prefs.getString(_keyOrders);
    if (ordersRaw != null) {
      final decoded = jsonDecode(ordersRaw) as List<dynamic>;
      _orders
        ..clear()
        ..addAll(
          decoded.map((e) => TradeOrder.fromJson(e as Map<String, dynamic>)),
        );
    }

    notifyListeners();
  }

  /// Persists balance, positions and orders to [SharedPreferences].
  Future<void> saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyBalance, _accountBalanceUsdt);
    await prefs.setString(_keyPositions, jsonEncode(_positions));
    await prefs.setString(
      _keyOrders,
      jsonEncode(_orders.map((o) => o.toJson()).toList()),
    );
  }

  // ---------------------------------------------------------------------------

  /// Deducts [amountUsdt] from the account balance (e.g. for a USDT send).
  void deductBalance(double amountUsdt) {
    if (amountUsdt <= 0) {
      throw ArgumentError('Le montant doit être supérieur à 0.');
    }
    if (amountUsdt > _accountBalanceUsdt) {
      throw StateError('Solde insuffisant.');
    }
    _accountBalanceUsdt -= amountUsdt;
    notifyListeners();
    saveState();
  }

  void placeOrder({
    required String market,
    required MarketTicker ticker,
    required TradeSide side,
    required double quantity,
  }) {
    if (quantity <= 0) {
      throw ArgumentError('La quantité doit être supérieure à 0.');
    }
    final total = quantity * ticker.lastPrice;
    final key = _positionKey(market, ticker.symbol);
    final currentPosition = _positions[key] ?? 0;

    if (side == TradeSide.buy) {
      if (total > _accountBalanceUsdt) {
        throw StateError('Solde insuffisant pour cet achat.');
      }
      _accountBalanceUsdt -= total;
      _positions[key] = currentPosition + quantity;
    } else {
      if (quantity > currentPosition) {
        throw StateError('Position insuffisante pour cette vente.');
      }
      _accountBalanceUsdt += total;
      final remaining = currentPosition - quantity;
      if (remaining.abs() < _positionEpsilon) {
        _positions.remove(key);
      } else {
        _positions[key] = remaining;
      }
    }

    _orders.insert(
      0,
      TradeOrder(
        symbol: ticker.symbol,
        baseAsset: ticker.baseAsset,
        quoteAsset: ticker.quoteAsset,
        market: market,
        side: side,
        quantity: quantity,
        unitPrice: ticker.lastPrice,
        executedAt: DateTime.now(),
      ),
    );
    notifyListeners();
    saveState();
  }

  Future<void> refreshMarket() async {
    _cryptoStatus = MarketStatus.loading;
    _cryptoError = null;
    notifyListeners();
    try {
      _cryptoTickers = await _marketService.fetchCryptoMarket();
      _cryptoStatus = MarketStatus.ready;
    } catch (e) {
      _cryptoStatus = MarketStatus.error;
      _cryptoError = 'Impossible de charger le marché crypto : $e';
    }
    notifyListeners();
  }

  Future<void> refreshRealAssetsMarket() async {
    _realAssetsStatus = MarketStatus.loading;
    _realAssetsError = null;
    notifyListeners();
    try {
      _realAssetTickers = await _marketService.fetchRealAssetsMarket();
      _realAssetsStatus = MarketStatus.ready;
    } catch (e) {
      _realAssetsStatus = MarketStatus.error;
      _realAssetsError = 'Impossible de charger les actifs réels : $e';
    }
    notifyListeners();
  }
}
