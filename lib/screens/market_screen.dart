import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/market_ticker.dart';
import '../providers/market_provider.dart';

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
      appBar: AppBar(title: const Text('Marché Binance')),
      body: const BinanceMarketView(
        contentPadding: EdgeInsets.all(16),
        showIntroText: true,
      ),
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
    final tickers = query.isEmpty
        ? marketProvider.tickers
        : marketProvider.tickers
            .where((ticker) =>
                ticker.symbol.contains(query) ||
                ticker.baseAsset.contains(query) ||
                ticker.quoteAsset.contains(query))
            .toList(growable: false);

    return RefreshIndicator(
      onRefresh: marketProvider.refreshMarket,
      child: ListView(
        padding: widget.contentPadding,
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
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                ),
              ),
            )
          else if (tickers.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: Text('Aucune donnée de marché disponible.')),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('${tickers.length} paires affichées'),
            ),
            ...tickers.map((ticker) => _MarketTickerCard(
                  ticker: ticker,
                  onBuy: () => _openBinanceTrade(ticker, isBuy: true),
                  onSell: () => _openBinanceTrade(ticker, isBuy: false),
                )),
          ],
        ],
      ),
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

  String _formatPrice(double value) {
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
                      Text('Prix: ${_formatPrice(ticker.lastPrice)} ${ticker.quoteAsset}'),
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
