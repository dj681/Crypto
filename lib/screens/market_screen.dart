import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/market_ticker.dart';
import '../providers/market_provider.dart';

String _formatMarketPrice(double value) {
  final precision = value >= 1000
      ? 2
      : value >= 1
          ? 4
          : value >= 0.01
              ? 6
              : 8;
  var formatted = value.toStringAsFixed(precision);
  if (formatted.contains('.')) {
    formatted = formatted.replaceFirst(RegExp(r'\.?0+$'), '');
  }
  return formatted;
}

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  static const String routeName = '/market';

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Marchés')),
      body: const TraderMarketView(
        contentPadding: EdgeInsets.all(16),
        showIntroText: true,
      ),
    );
  }
}

enum TraderMarketType { crypto, realAssets }

class TraderMarketView extends StatefulWidget {
  const TraderMarketView({
    super.key,
    required this.contentPadding,
    this.showIntroText = false,
  });

  final EdgeInsets contentPadding;
  final bool showIntroText;

  @override
  State<TraderMarketView> createState() => _TraderMarketViewState();
}

class _TraderMarketViewState extends State<TraderMarketView> {
  TraderMarketType _selectedMarket = TraderMarketType.crypto;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: widget.contentPadding.copyWith(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showIntroText) ...[
                const Text(
                  'Choisissez le marché à visiter : crypto-monnaies ou actifs réels.',
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<TraderMarketType>(
                  segments: const [
                    ButtonSegment(
                      value: TraderMarketType.crypto,
                      label: Text('Crypto'),
                      icon: Icon(Icons.currency_bitcoin),
                    ),
                    ButtonSegment(
                      value: TraderMarketType.realAssets,
                      label: Text('Actifs réels'),
                      icon: Icon(Icons.inventory_2_outlined),
                    ),
                  ],
                  selected: {_selectedMarket},
                  onSelectionChanged: (selection) {
                    if (selection.isEmpty) return;
                    setState(() => _selectedMarket = selection.first);
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _selectedMarket == TraderMarketType.crypto
              ? BinanceMarketView(
                  contentPadding: widget.contentPadding.copyWith(top: 8),
                  showIntroText: false,
                )
              : RealAssetsMarketView(
                  contentPadding: widget.contentPadding.copyWith(top: 8),
                ),
        ),
      ],
    );
  }
}

class BinanceMarketView extends StatefulWidget {
  const BinanceMarketView({
    super.key,
    required this.contentPadding,
    this.showIntroText = false,
  });

  final EdgeInsets contentPadding;
  final bool showIntroText;

  @override
  State<BinanceMarketView> createState() => _BinanceMarketViewState();
}

class _BinanceMarketViewState extends State<BinanceMarketView> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final marketProvider = context.read<MarketProvider>();
      // Skip auto-refresh if data is already loaded or a fetch is in progress.
      // Users can still trigger a manual refresh via pull-to-refresh.
      if (marketProvider.isLoading || marketProvider.tickers.isNotEmpty) return;
      marketProvider.refreshMarket();
    });
  }

  Future<void> _openBinanceTrade(MarketTicker ticker, {required bool isBuy}) async {
    final sideText = isBuy ? 'achat' : 'vente';
    final uri = Uri.parse(
      'https://www.binance.com/en/trade/${ticker.baseAsset}_${ticker.quoteAsset}?type=spot',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || launched) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Impossible d’ouvrir Binance pour $sideText.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final marketProvider = context.watch<MarketProvider>();
    final query = _query.trim().toUpperCase();
    final List<MarketTicker> tickers = query.isEmpty
        ? marketProvider.tickers
        : marketProvider.tickers
            .where((ticker) =>
                ticker.symbol.contains(query) ||
                ticker.baseAsset.contains(query) ||
                ticker.quoteAsset.contains(query))
            .toList(growable: false);

    final bool showList = !marketProvider.isLoading &&
        marketProvider.status != MarketStatus.error &&
        tickers.isNotEmpty;

    return RefreshIndicator(
      onRefresh: marketProvider.refreshMarket,
      child: CustomScrollView(
        slivers: [
          // Header: intro text, search field, status/count.
          SliverToBoxAdapter(
            child: Padding(
              padding: widget.contentPadding.copyWith(bottom: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showIntroText) ...[
                    const Text(
                      'Marché spot Binance. Toutes les paires disponibles sont listées ci-dessous.',
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () => setState(() => _query = ''),
                              icon: const Icon(Icons.close),
                              tooltip: 'Effacer',
                            ),
                      hintText: 'Rechercher une crypto (ex: BTC, ETH, USDT)',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 12),
                  if (marketProvider.isLoading && marketProvider.tickers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (marketProvider.status == MarketStatus.error)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          marketProvider.error ?? 'Erreur de chargement.',
                          style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.onErrorContainer),
                        ),
                      ),
                    )
                  else if (!showList)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(
                          child: Text('Aucune donnée de marché disponible.')),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('${tickers.length} paires affichées'),
                    ),
                ],
              ),
            ),
          ),
          // Ticker list: lazily rendered with SliverList.builder.
          if (showList)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                widget.contentPadding.left,
                0,
                widget.contentPadding.right,
                widget.contentPadding.bottom,
              ),
              sliver: SliverList.builder(
                itemCount: tickers.length,
                itemBuilder: (context, index) {
                  final ticker = tickers[index];
                  return _MarketTickerCard(
                    ticker: ticker,
                    onBuy: () => _openBinanceTrade(ticker, isBuy: true),
                    onSell: () => _openBinanceTrade(ticker, isBuy: false),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class RealAssetsMarketView extends StatefulWidget {
  const RealAssetsMarketView({
    super.key,
    required this.contentPadding,
  });

  final EdgeInsets contentPadding;

  @override
  State<RealAssetsMarketView> createState() => _RealAssetsMarketViewState();
}

class _RealAssetsMarketViewState extends State<RealAssetsMarketView> {
  static const List<_RealAssetTicker> _realAssets = [
    _RealAssetTicker(
      symbol: 'XAU',
      name: 'Or',
      unit: 'oz',
      lastPrice: 2388.42,
      priceChangePercent: 0.87,
    ),
    _RealAssetTicker(
      symbol: 'XBR',
      name: 'Pétrole Brent',
      unit: 'baril',
      lastPrice: 83.16,
      priceChangePercent: -0.42,
    ),
    _RealAssetTicker(
      symbol: 'XTI',
      name: 'Pétrole WTI',
      unit: 'baril',
      lastPrice: 79.95,
      priceChangePercent: -0.35,
    ),
    _RealAssetTicker(
      symbol: 'XAG',
      name: 'Argent',
      unit: 'oz',
      lastPrice: 28.74,
      priceChangePercent: 0.65,
    ),
    _RealAssetTicker(
      symbol: 'DIA',
      name: 'Diamant',
      unit: 'ct',
      lastPrice: 1265.30,
      priceChangePercent: 0.18,
    ),
  ];

  String _query = '';
  final Map<String, int> _buyPositions = {};
  final Map<String, int> _sellPositions = {};

  void _takePosition(_RealAssetTicker ticker, {required bool isBuy}) {
    setState(() {
      final target = isBuy ? _buyPositions : _sellPositions;
      target[ticker.symbol] = (target[ticker.symbol] ?? 0) + 1;
    });
    final sideText = isBuy ? 'achat' : 'vente';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Position de $sideText ouverte sur ${ticker.name}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toUpperCase();
    final assets = query.isEmpty
        ? _realAssets
        : _realAssets
            .where((asset) =>
                asset.symbol.contains(query) || asset.name.toUpperCase().contains(query))
            .toList(growable: false);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: widget.contentPadding.copyWith(bottom: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Actifs réels disponibles pour des positions d’achat ou de vente.',
                ),
                const SizedBox(height: 6),
                Text(
                  'Données de prix indicatives. Positions suivies localement sur cette session.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () => setState(() => _query = ''),
                            icon: const Icon(Icons.close),
                            tooltip: 'Effacer',
                          ),
                    hintText: 'Rechercher un actif réel (or, pétrole, diamant...)',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 8),
                if (assets.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: Text('Aucun actif réel trouvé.')),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('${assets.length} actifs affichés'),
                  ),
              ],
            ),
          ),
        ),
        if (assets.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              widget.contentPadding.left,
              0,
              widget.contentPadding.right,
              widget.contentPadding.bottom,
            ),
            sliver: SliverList.builder(
              itemCount: assets.length,
              itemBuilder: (context, index) {
                final asset = assets[index];
                return _RealAssetTickerCard(
                  ticker: asset,
                  buyPositions: _buyPositions[asset.symbol] ?? 0,
                  sellPositions: _sellPositions[asset.symbol] ?? 0,
                  formatPrice: _formatMarketPrice,
                  onBuy: () => _takePosition(asset, isBuy: true),
                  onSell: () => _takePosition(asset, isBuy: false),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _MarketTickerCard extends StatelessWidget {
  const _MarketTickerCard({
    required this.ticker,
    required this.onBuy,
    required this.onSell,
  });

  final MarketTicker ticker;
  final VoidCallback onBuy;
  final VoidCallback onSell;

  @override
  Widget build(BuildContext context) {
    final positive = ticker.priceChangePercent >= 0;
    final changeColor =
        positive ? Colors.green.shade700 : Theme.of(context).colorScheme.error;
    final formattedChange = '${positive ? '+' : ''}${ticker.priceChangePercent.toStringAsFixed(2)}%';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${ticker.baseAsset}/${ticker.quoteAsset}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text('Prix: ${_formatMarketPrice(ticker.lastPrice)} ${ticker.quoteAsset}'),
                    ],
                  ),
                ),
                Text(
                  formattedChange,
                  style: TextStyle(
                    color: changeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onBuy,
                    icon: const Icon(Icons.add_shopping_cart_outlined),
                    label: const Text('Acheter'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSell,
                    icon: const Icon(Icons.sell_outlined),
                    label: const Text('Vendre'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RealAssetTicker {
  const _RealAssetTicker({
    required this.symbol,
    required this.name,
    required this.unit,
    required this.lastPrice,
    required this.priceChangePercent,
  });

  final String symbol;
  final String name;
  final String unit;
  final double lastPrice;
  final double priceChangePercent;
}

class _RealAssetTickerCard extends StatelessWidget {
  const _RealAssetTickerCard({
    required this.ticker,
    required this.buyPositions,
    required this.sellPositions,
    required this.formatPrice,
    required this.onBuy,
    required this.onSell,
  });

  final _RealAssetTicker ticker;
  final int buyPositions;
  final int sellPositions;
  final String Function(double value) formatPrice;
  final VoidCallback onBuy;
  final VoidCallback onSell;

  @override
  Widget build(BuildContext context) {
    final positive = ticker.priceChangePercent >= 0;
    final changeColor =
        positive ? Colors.green.shade700 : Theme.of(context).colorScheme.error;
    final formattedChange =
        '${positive ? '+' : ''}${ticker.priceChangePercent.toStringAsFixed(2)}%';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${ticker.name} (${ticker.symbol})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text('Prix: ${formatPrice(ticker.lastPrice)} USD / ${ticker.unit}'),
                    ],
                  ),
                ),
                Text(
                  formattedChange,
                  style: TextStyle(
                    color: changeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (buyPositions > 0 || sellPositions > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (buyPositions > 0) Chip(label: Text('Achats: $buyPositions')),
                    if (sellPositions > 0) Chip(label: Text('Ventes: $sellPositions')),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onBuy,
                    icon: const Icon(Icons.add_shopping_cart_outlined),
                    label: const Text('Acheter'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSell,
                    icon: const Icon(Icons.sell_outlined),
                    label: const Text('Vendre'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
