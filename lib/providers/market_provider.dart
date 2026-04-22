import 'package:flutter/foundation.dart';

import '../models/market_ticker.dart';
import '../services/market_service.dart';

enum MarketStatus { idle, loading, ready, error }

class MarketProvider extends ChangeNotifier {
  MarketProvider({required MarketService marketService}) : _marketService = marketService;

  final MarketService _marketService;

  List<MarketTicker> _tickers = [];
  MarketStatus _status = MarketStatus.idle;
  String? _error;

  List<MarketTicker> get tickers => List.unmodifiable(_tickers);
  MarketStatus get status => _status;
  String? get error => _error;
  bool get isLoading => _status == MarketStatus.loading;

  Future<void> refreshMarket() async {
    _status = MarketStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _tickers = await _marketService.fetchBinanceMarket();
      _status = MarketStatus.ready;
    } catch (e) {
      _status = MarketStatus.error;
      _error = 'Impossible de charger les données de marché : $e';
    }
    notifyListeners();
  }
}
