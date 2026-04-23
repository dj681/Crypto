class MarketTicker {
  const MarketTicker({
    required this.symbol,
    required this.baseAsset,
    required this.quoteAsset,
    required this.lastPrice,
    required this.priceChangePercent,
    required this.quoteVolume,
    this.name,
    this.unit,
    this.market,
  });

  final String symbol;
  final String baseAsset;
  final String quoteAsset;
  final double lastPrice;
  final double priceChangePercent;
  final double quoteVolume;
  final String? name;
  final String? unit;
  final String? market;

  factory MarketTicker.fromJson(Map<String, dynamic> json) {
    final lastPrice = double.tryParse(json['lastPrice']?.toString() ?? '');
    final priceChangePercent =
        double.tryParse(json['priceChangePercent']?.toString() ?? '');
    final quoteVolume = double.tryParse(json['quoteVolume']?.toString() ?? '');
    if (lastPrice == null || priceChangePercent == null || quoteVolume == null) {
      throw const FormatException(
        'Ticker invalide: lastPrice, priceChangePercent ou quoteVolume manquant/invalide.',
      );
    }

    return MarketTicker(
      symbol: (json['symbol'] ?? '').toString().toUpperCase(),
      baseAsset: (json['baseAsset'] ?? '').toString().toUpperCase(),
      quoteAsset: (json['quoteAsset'] ?? '').toString().toUpperCase(),
      lastPrice: lastPrice,
      priceChangePercent: priceChangePercent,
      quoteVolume: quoteVolume,
      name: (json['name'] ?? '').toString().trim().isEmpty
          ? null
          : json['name'].toString().trim(),
      unit: (json['unit'] ?? '').toString().trim().isEmpty
          ? null
          : json['unit'].toString().trim(),
      market: (json['market'] ?? '').toString().trim().isEmpty
          ? null
          : json['market'].toString().trim(),
    );
  }
}
