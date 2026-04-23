import 'package:flutter/foundation.dart';

import '../models/market_ticker.dart';
import '../services/market_service.dart';

enum MarketStatus { idle, loading, ready, error }

class MarketProvider extends ChangeNotifier {
  MarketProvider({required MarketService marketService}) : _marketService = marketService;

  final MarketService _marketService;

  List<MarketTicker> _cryptoTickers = [];
  List<MarketTicker> _realAssetTickers = [];
  MarketStatus _cryptoStatus = MarketStatus.idle;
  MarketStatus _realAssetsStatus = MarketStatus.idle;
  String? _cryptoError;
  String? _realAssetsError;

  List<MarketTicker> get tickers => List.unmodifiable(_cryptoTickers);
  List<MarketTicker> get realAssetTickers => List.unmodifiable(_realAssetTickers);
  MarketStatus get status => _cryptoStatus;
  MarketStatus get realAssetsStatus => _realAssetsStatus;
  String? get error => _cryptoError;
  String? get realAssetsError => _realAssetsError;
  bool get isLoading => _cryptoStatus == MarketStatus.loading;
  bool get isRealAssetsLoading => _realAssetsStatus == MarketStatus.loading;

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
