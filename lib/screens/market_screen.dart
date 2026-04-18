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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketProvider>().refreshMarket();
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
    final tickers = marketProvider.tickers;

    return Scaffold(
      appBar: AppBar(title: const Text('Marché Binance')),
      body: RefreshIndicator(
        onRefresh: marketProvider.refreshMarket,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Marché spot Binance (USDT). Les ordres d’achat et de vente sont exécutés sur Binance.',
            ),
            const SizedBox(height: 16),
            if (marketProvider.isLoading && tickers.isEmpty)
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
            else
              ...tickers.map((ticker) => _MarketTickerCard(
                    ticker: ticker,
                    onBuy: () => _openBinanceTrade(ticker, isBuy: true),
                    onSell: () => _openBinanceTrade(ticker, isBuy: false),
                  )),
          ],
        ),
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
                      Text('Prix: ${ticker.lastPrice.toStringAsFixed(6)} ${ticker.quoteAsset}'),
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
