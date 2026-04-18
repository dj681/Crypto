class MarketTicker {
  const MarketTicker({
    required this.symbol,
    required this.baseAsset,
    required this.quoteAsset,
    required this.lastPrice,
    required this.priceChangePercent,
    required this.quoteVolume,
  });

  final String symbol;
  final String baseAsset;
  final String quoteAsset;
  final double lastPrice;
  final double priceChangePercent;
  final double quoteVolume;
}
