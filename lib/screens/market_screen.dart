import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

String _formatAmount(double value, {int maxFractionDigits = 6}) {
  var formatted = value.toStringAsFixed(maxFractionDigits);
  if (formatted.contains('.')) {
    formatted = formatted.replaceFirst(RegExp(r'\.?0+$'), '');
  }
  return formatted;
}

String _formatDateTime(DateTime dateTime) {
  final d = dateTime.day.toString().padLeft(2, '0');
  final m = dateTime.month.toString().padLeft(2, '0');
  final y = dateTime.year.toString();
  final h = dateTime.hour.toString().padLeft(2, '0');
  final min = dateTime.minute.toString().padLeft(2, '0');
  return '$d/$m/$y $h:$min';
}

double? _findEthPriceInUsdt(List<MarketTicker> tickers) {
  for (final ticker in tickers) {
    final isEth = ticker.baseAsset.toUpperCase() == 'ETH';
    final isUsdQuote = ticker.quoteAsset.toUpperCase() == 'USD' ||
        ticker.quoteAsset.toUpperCase() == 'USDT';
    if (isEth && isUsdQuote && ticker.lastPrice > 0) {
      return ticker.lastPrice;
    }
  }
  return null;
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
    final marketProvider = context.watch<MarketProvider>();
    final accountBalanceUsdt = marketProvider.accountBalanceUsdt;
    final accountBalanceEur = marketProvider.accountBalanceEur;
    final ethQuotePrice = _findEthPriceInUsdt(marketProvider.tickers);
    final accountBalanceEth = ethQuotePrice != null && ethQuotePrice > 0
        ? accountBalanceUsdt / ethQuotePrice
        : null;
    return Column(
      children: [
        Padding(
          padding: widget.contentPadding.copyWith(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showIntroText) ...[
                const Text(
                  'Choisissez le marché à consulter : crypto-monnaies ou actifs réels.',
                ),
                const SizedBox(height: 12),
              ],
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Total du compte: '
                          '${_formatAmount(accountBalanceUsdt, maxFractionDigits: 2)} USDT'
                          ' • ${_formatAmount(accountBalanceEur, maxFractionDigits: 2)} EUR'
                          '${accountBalanceEth != null ? ' • ${_formatAmount(accountBalanceEth)} ETH' : ''}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
              ? CryptoMarketView(
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

class CryptoMarketView extends StatefulWidget {
  const CryptoMarketView({
    super.key,
    required this.contentPadding,
    this.showIntroText = false,
  });

  final EdgeInsets contentPadding;
  final bool showIntroText;

  @override
  State<CryptoMarketView> createState() => _CryptoMarketViewState();
}

class _CryptoMarketViewState extends State<CryptoMarketView> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final marketProvider = context.read<MarketProvider>();
      if (marketProvider.isLoading || marketProvider.tickers.isNotEmpty) return;
      marketProvider.refreshMarket();
    });
  }

  Future<void> _openTradeSheet(
    MarketTicker ticker, {
    required TradeSide initialSide,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _TradeComposerSheet(
          market: 'crypto',
          ticker: ticker,
          initialSide: initialSide,
        ),
      ),
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
          SliverToBoxAdapter(
            child: Padding(
              padding: widget.contentPadding.copyWith(bottom: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showIntroText) ...[
                    const Text(
                      'Marché crypto applicatif en temps réel. Toutes les paires disponibles sont listées ci-dessous.',
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
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    )
                  else if (!showList)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(
                        child: Text('Aucune donnée de marché disponible.'),
                      ),
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
                  final orders = marketProvider.ordersFor(
                    market: 'crypto',
                    symbol: ticker.symbol,
                  );
                  final buyCount =
                      orders.where((order) => order.side == TradeSide.buy).length;
                  final sellCount =
                      orders.where((order) => order.side == TradeSide.sell).length;

                  return _MarketTickerCard(
                    ticker: ticker,
                    buyCount: buyCount,
                    sellCount: sellCount,
                    onBuy: () => _openTradeSheet(ticker, initialSide: TradeSide.buy),
                    onSell: () => _openTradeSheet(ticker, initialSide: TradeSide.sell),
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
  String _query = '';

  static const Map<String, ({String name, String unit})> _realAssetsMetadata = {
    'XAUUSD': (name: 'Or', unit: 'oz'),
    'XAGUSD': (name: 'Argent', unit: 'oz'),
    'BRNUSD': (name: 'Pétrole Brent', unit: 'baril'),
    'WTIUSD': (name: 'Pétrole WTI', unit: 'baril'),
    'XPTUSD': (name: 'Platine', unit: 'oz'),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final marketProvider = context.read<MarketProvider>();
      if (marketProvider.isRealAssetsLoading || marketProvider.realAssetTickers.isNotEmpty) {
        return;
      }
      marketProvider.refreshRealAssetsMarket();
    });
  }

  Future<void> _openTradeSheet(
    MarketTicker ticker, {
    required TradeSide initialSide,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _TradeComposerSheet(
          market: 'real-assets',
          ticker: ticker,
          initialSide: initialSide,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final marketProvider = context.watch<MarketProvider>();
    final query = _query.trim().toUpperCase();
    final allAssets = marketProvider.realAssetTickers
        .map((ticker) => _toDisplayTicker(ticker))
        .toList(growable: false);
    final assets = query.isEmpty
        ? allAssets
        : allAssets
            .where((asset) =>
                asset.symbol.contains(query) ||
                (asset.name ?? '').toUpperCase().contains(query))
            .toList(growable: false);
    final showList = !marketProvider.isRealAssetsLoading &&
        marketProvider.realAssetsStatus != MarketStatus.error &&
        assets.isNotEmpty;

    return RefreshIndicator(
      onRefresh: marketProvider.refreshRealAssetsMarket,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: widget.contentPadding.copyWith(bottom: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Actifs réels disponibles avec cotations backend en temps réel.',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Vous pouvez surcharger les prix côté backend pour ajuster manuellement les valeurs.',
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
                  if (marketProvider.isRealAssetsLoading &&
                      marketProvider.realAssetTickers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (marketProvider.realAssetsStatus == MarketStatus.error)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          marketProvider.realAssetsError ?? 'Erreur de chargement.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    )
                  else if (!showList)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
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
          if (showList)
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
                  final orders = marketProvider.ordersFor(
                    market: 'real-assets',
                    symbol: asset.symbol,
                  );
                  final buyCount =
                      orders.where((order) => order.side == TradeSide.buy).length;
                  final sellCount =
                      orders.where((order) => order.side == TradeSide.sell).length;

                  return _RealAssetTickerCard(
                    ticker: asset,
                    buyCount: buyCount,
                    sellCount: sellCount,
                    formatPrice: _formatMarketPrice,
                    onBuy: () => _openTradeSheet(asset, initialSide: TradeSide.buy),
                    onSell: () => _openTradeSheet(asset, initialSide: TradeSide.sell),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  MarketTicker _toDisplayTicker(MarketTicker ticker) {
    final metadata = _realAssetsMetadata[ticker.symbol];
    return MarketTicker(
      symbol: ticker.symbol,
      baseAsset: ticker.baseAsset,
      quoteAsset: ticker.quoteAsset,
      lastPrice: ticker.lastPrice,
      priceChangePercent: ticker.priceChangePercent,
      quoteVolume: ticker.quoteVolume,
      name: ticker.name ?? metadata?.name ?? ticker.baseAsset,
      unit: ticker.unit ?? metadata?.unit ?? 'unité',
      market: ticker.market ?? 'real-assets',
    );
  }
}

class _TradeComposerSheet extends StatefulWidget {
  const _TradeComposerSheet({
    required this.market,
    required this.ticker,
    required this.initialSide,
  });

  final String market;
  final MarketTicker ticker;
  final TradeSide initialSide;

  @override
  State<_TradeComposerSheet> createState() => _TradeComposerSheetState();
}

class _TradeComposerSheetState extends State<_TradeComposerSheet> {
  // Relative amplitude used to synthesize a 24h intraday curve from 24h change.
  static const _amplitudeRatio = 0.015;
  // Absolute minimum amplitude to keep a visible curve for tiny prices.
  static const _minAmplitude = 0.0001;
  // Safety floor to avoid non-positive values in synthetic chart points.
  static const _minSyntheticPrice = 0.00000001;

  late TradeSide _selectedSide;
  final TextEditingController _quantityController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _selectedSide = widget.initialSide;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  List<double> _buildEvolutionSeries() {
    final current = widget.ticker.lastPrice;
    final ratio = 1 + (widget.ticker.priceChangePercent / 100);
    final start = ratio <= 0 ? current : current / ratio;
    final direction = current >= start ? 1 : -1;
    // Symbol-based seed keeps curve shape stable per asset across rebuilds.
    final symbolSeed = widget.ticker.symbol.hashCode;
    final amplitude = math.max(current.abs() * _amplitudeRatio, _minAmplitude);

    return List<double>.generate(24, (index) {
      final progress = index / 23;
      final baseline = start + ((current - start) * progress);
      final primaryWave = math.sin(progress * math.pi * 2) * amplitude;
      final secondaryWave =
          math.sin(progress * math.pi * 6 + symbolSeed) * amplitude * 0.35;
      return math.max(
        _minSyntheticPrice,
        baseline + ((primaryWave + secondaryWave) * direction),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final marketProvider = context.watch<MarketProvider>();
    final balance = marketProvider.accountBalanceUsdt;
    final position = marketProvider.getPosition(
      market: widget.market,
      symbol: widget.ticker.symbol,
    );
    final orders = marketProvider.ordersFor(
      market: widget.market,
      symbol: widget.ticker.symbol,
    );

    final quantity =
        double.tryParse(_quantityController.text.trim().replaceAll(',', '.'));
    final total = (quantity ?? 0) * widget.ticker.lastPrice;
    final sideLabel = _selectedSide == TradeSide.buy ? 'Achat' : 'Vente';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.ticker.baseAsset}/${widget.ticker.quoteAsset}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Fermer',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Prix actuel: ${_formatMarketPrice(widget.ticker.lastPrice)} ${widget.ticker.quoteAsset}',
              ),
              Text(
                'Variation 24h: ${widget.ticker.priceChangePercent >= 0 ? '+' : ''}${widget.ticker.priceChangePercent.toStringAsFixed(2)}%',
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Évolution du marché (24h)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 140,
                        child: _EvolutionChart(
                          values: _buildEvolutionSeries(),
                          isPositive: widget.ticker.priceChangePercent >= 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Passer un ordre ($sideLabel)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Solde disponible: ${_formatAmount(balance, maxFractionDigits: 2)} USDT',
                      ),
                      Text(
                        'Position ouverte: ${_formatAmount(position)} ${widget.ticker.baseAsset}',
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<TradeSide>(
                        segments: const [
                          ButtonSegment(
                            value: TradeSide.buy,
                            label: Text('Acheter'),
                            icon: Icon(Icons.add_shopping_cart_outlined),
                          ),
                          ButtonSegment(
                            value: TradeSide.sell,
                            label: Text('Vendre'),
                            icon: Icon(Icons.sell_outlined),
                          ),
                        ],
                        selected: {_selectedSide},
                        onSelectionChanged: (selection) {
                          if (selection.isEmpty) return;
                          setState(() => _selectedSide = selection.first);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Quantité (${widget.ticker.baseAsset})',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Montant estimé: ${_formatAmount(total, maxFractionDigits: 2)} USDT',
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: quantity == null || quantity <= 0
                              ? null
                              : () {
                                  try {
                                    marketProvider.placeOrder(
                                      market: widget.market,
                                      ticker: widget.ticker,
                                      side: _selectedSide,
                                      quantity: quantity,
                                    );
                                    final sideText =
                                        _selectedSide == TradeSide.buy ? 'achat' : 'vente';
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Ordre de $sideText exécuté sur ${widget.ticker.baseAsset}.',
                                        ),
                                      ),
                                    );
                                    setState(() => _quantityController.text = '1');
                                  } on StateError catch (error) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error.message)),
                                    );
                                  } on ArgumentError catch (error) {
                                    final message =
                                        error.message?.toString().trim().isNotEmpty == true
                                            ? error.message.toString()
                                            : 'Quantité invalide.';
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(message)),
                                    );
                                  }
                                },
                          icon: Icon(
                            _selectedSide == TradeSide.buy
                                ? Icons.add_shopping_cart_outlined
                                : Icons.sell_outlined,
                          ),
                          label: Text(
                            _selectedSide == TradeSide.buy
                                ? 'Confirmer l\'achat'
                                : 'Confirmer la vente',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Achats / ventes effectués',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (orders.isEmpty)
                        const Text('Aucune opération enregistrée pour cet actif.')
                      else
                        ...orders.map((order) {
                          final isBuy = order.side == TradeSide.buy;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              isBuy ? Icons.add_shopping_cart_outlined : Icons.sell_outlined,
                              color: isBuy
                                  ? Colors.green.shade700
                                  : Theme.of(context).colorScheme.error,
                            ),
                            title: Text(
                              '${isBuy ? 'Achat' : 'Vente'} '
                              '${_formatAmount(order.quantity)} ${order.baseAsset}',
                            ),
                            subtitle: Text(
                              '${_formatAmount(order.total, maxFractionDigits: 2)} USDT • ${_formatDateTime(order.executedAt)}',
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EvolutionChart extends StatelessWidget {
  const _EvolutionChart({
    required this.values,
    required this.isPositive,
  });

  final List<double> values;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _EvolutionChartPainter(
        values: values,
        color: isPositive ? Colors.green.shade700 : Theme.of(context).colorScheme.error,
        gridColor: Theme.of(context).dividerColor,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _EvolutionChartPainter extends CustomPainter {
  static const _minSpan = 0.0000001;

  const _EvolutionChartPainter({
    required this.values,
    required this.color,
    required this.gridColor,
  });

  final List<double> values;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor.withOpacity(0.35)
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (var i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.length < 2) return;

    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final span = math.max(maxValue - minValue, _minSpan);

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final normalized = (values[i] - minValue) / span;
      final y = size.height - (normalized * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _EvolutionChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.color != color ||
        oldDelegate.gridColor != gridColor;
  }
}

class _MarketTickerCard extends StatelessWidget {
  const _MarketTickerCard({
    required this.ticker,
    required this.buyCount,
    required this.sellCount,
    required this.onBuy,
    required this.onSell,
  });

  final MarketTicker ticker;
  final int buyCount;
  final int sellCount;
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
            if (buyCount > 0 || sellCount > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (buyCount > 0) Chip(label: Text('Achats: $buyCount')),
                  if (sellCount > 0) Chip(label: Text('Ventes: $sellCount')),
                ],
              ),
            ],
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

class _RealAssetTickerCard extends StatelessWidget {
  const _RealAssetTickerCard({
    required this.ticker,
    required this.buyCount,
    required this.sellCount,
    required this.formatPrice,
    required this.onBuy,
    required this.onSell,
  });

  final MarketTicker ticker;
  final int buyCount;
  final int sellCount;
  final String Function(double value) formatPrice;
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
                        '${ticker.name ?? ticker.baseAsset} (${ticker.symbol})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Prix: ${formatPrice(ticker.lastPrice)} USD / ${ticker.unit ?? 'unité'}',
                      ),
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
            if (buyCount > 0 || sellCount > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (buyCount > 0) Chip(label: Text('Achats: $buyCount')),
                  if (sellCount > 0) Chip(label: Text('Ventes: $sellCount')),
                ],
              ),
            ],
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
