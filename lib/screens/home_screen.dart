import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wallet.dart';
import '../providers/blockchain_provider.dart';
import '../providers/market_provider.dart';
import '../providers/wallet_provider.dart';
import '../widgets/balance_card.dart';
import '../widgets/transaction_tile.dart';
import 'history_screen.dart';
import 'market_screen.dart';
import 'receive_screen.dart';
import 'send_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const String routeName = '/home';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _marketViewBottomPadding = kBottomNavigationBarHeight + 24;
  // Snackbar timing tuned for short-to-medium French action messages.
  static const _minSnackbarSeconds = 4;
  static const _maxSnackbarSeconds = 8;
  static const _snackbarCharsPerSecond = 20;

  static const _tabTitles = [
    'Accueil',
    'Trader',
    'Récompense',
    'Découvrir',
    'Convertir',
  ];

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshBalance();
      _refreshMarket();
    });
  }

  void _refreshBalance() {
    if (!mounted) return;
    final address = context.read<WalletProvider>().wallet?.address;
    if (address != null) {
      context.read<BlockchainProvider>().refreshBalance(address);
    }
  }

  void _refreshMarket() {
    if (!mounted) return;
    final marketProvider = context.read<MarketProvider>();
    if (marketProvider.isLoading) return;
    marketProvider.refreshMarket();
  }

  void _showActionMessage(String message) {
    if (!mounted) return;
    final seconds = math.max(
      _minSnackbarSeconds,
      math.min(
        _maxSnackbarSeconds,
        (message.length / _snackbarCharsPerSecond).ceil(),
      ),
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: seconds),
        ),
      );
  }

  void _openTraderWithMessage(String message) {
    setState(() => _selectedIndex = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showActionMessage(message);
    });
  }

  Future<void> _openHistoryAsync() async {
    try {
      await Navigator.pushNamed(context, HistoryScreen.routeName);
    } on Exception catch (error) {
      debugPrint('Navigation to history failed: $error');
      _showActionMessage("Impossible d'ouvrir l'historique pour le moment.");
    }
  }

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
    final walletProvider = context.watch<WalletProvider>();
    final blockchainProvider = context.watch<BlockchainProvider>();
    final marketProvider = context.watch<MarketProvider>();
    final wallet = walletProvider.wallet;

    return Scaffold(
      appBar: AppBar(
        title: Text(_tabTitles[_selectedIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, SettingsScreen.routeName),
            tooltip: 'Paramètres',
          ),
        ],
      ),
      body: wallet == null
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _selectedIndex,
              children: [
                _AccueilTab(
                  wallet: wallet,
                  walletProvider: walletProvider,
                  blockchainProvider: blockchainProvider,
                  marketProvider: marketProvider,
                  onRefreshBalance: _refreshBalance,
                  onRefreshMarket: _refreshMarket,
                  formatPrice: _formatPrice,
                  onOpenTrader: () => setState(() => _selectedIndex = 1),
                ),
                const TraderMarketView(
                  contentPadding:
                      EdgeInsets.fromLTRB(16, 16, 16, _marketViewBottomPadding),
                  showIntroText: false,
                ),
                _RewardsTab(
                  onOpenDailyMissions: () => _openTraderWithMessage(
                    'Consultez le marché pour réaliser vos missions quotidiennes.',
                  ),
                  onOpenReferral: () => _showActionMessage(
                    'Parrainage pris en compte. Fonctionnalité détaillée bientôt disponible.',
                  ),
                  onOpenCashback: () => _showActionMessage(
                    'Vos récompenses cashback seront affichées ici prochainement.',
                  ),
                ),
                _DiscoverTab(
                  onOpenDapps: () => _showActionMessage(
                    'Ouverture des DApps populaires en préparation.',
                  ),
                  onOpenTrends: () => _openTraderWithMessage(
                    'Voici les tendances de marché en temps réel.',
                  ),
                  onOpenLearn: () => _showActionMessage(
                    'La section apprentissage sera disponible bientôt.',
                  ),
                ),
                _ConvertTab(
                  onOpenInstantConvert: () => _openTraderWithMessage(
                    'Accédez au marché pour convertir vos actifs.',
                  ),
                  onOpenRates: () => _openTraderWithMessage(
                    'Consultez maintenant les taux en temps réel.',
                  ),
                  onOpenConvertHistory: () => _openHistoryAsync(),
                ),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.candlestick_chart_outlined),
            selectedIcon: Icon(Icons.candlestick_chart),
            label: 'Trader',
          ),
          NavigationDestination(
            icon: Icon(Icons.card_giftcard_outlined),
            selectedIcon: Icon(Icons.card_giftcard),
            label: 'Récompense',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Découvrir',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_outlined),
            selectedIcon: Icon(Icons.swap_horiz),
            label: 'Convertir',
          ),
        ],
      ),
    );
  }
}

class _AccueilTab extends StatelessWidget {
  static const int _marketPreviewItemCount = 12;

  const _AccueilTab({
    required this.wallet,
    required this.walletProvider,
    required this.blockchainProvider,
    required this.marketProvider,
    required this.onRefreshBalance,
    required this.onRefreshMarket,
    required this.formatPrice,
    required this.onOpenTrader,
  });

  final WalletModel wallet;
  final WalletProvider walletProvider;
  final BlockchainProvider blockchainProvider;
  final MarketProvider marketProvider;
  final VoidCallback onRefreshBalance;
  final VoidCallback onRefreshMarket;
  final String Function(double value) formatPrice;
  final VoidCallback onOpenTrader;

  @override
  Widget build(BuildContext context) {
    final recentHistory = walletProvider.history.take(5).toList();
    final marketTickers =
        marketProvider.tickers.take(_marketPreviewItemCount).toList();

    return RefreshIndicator(
      onRefresh: () => blockchainProvider.refreshBalance(wallet.address),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BalanceCard(
            address: wallet.address,
            blockchainProvider: blockchainProvider,
            onRefresh: onRefreshBalance,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.arrow_upward,
                  label: 'Envoyer',
                  onTap: () => Navigator.pushNamed(context, SendScreen.routeName)
                      .then((_) => onRefreshBalance()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.arrow_downward,
                  label: 'Recevoir',
                  onTap: () => Navigator.pushNamed(context, ReceiveScreen.routeName),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.history,
                  label: 'Historique',
                  onTap: () => Navigator.pushNamed(context, HistoryScreen.routeName),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Marché crypto',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: marketProvider.isLoading ? null : onRefreshMarket,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Actualiser'),
                      ),
                    ],
                  ),
                  if (marketProvider.isLoading && marketTickers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (marketProvider.status == MarketStatus.error)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        marketProvider.error ?? 'Erreur de chargement du marché.',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    )
                  else if (marketTickers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text('Aucune donnée de marché disponible.'),
                    )
                  else ...[
                    ...marketTickers.map((ticker) {
                      final positive = ticker.priceChangePercent >= 0;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text('${ticker.baseAsset}/${ticker.quoteAsset}'),
                        subtitle: Text(
                          '${formatPrice(ticker.lastPrice)} ${ticker.quoteAsset}',
                        ),
                        trailing: Text(
                          '${positive ? '+' : ''}${ticker.priceChangePercent.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: positive
                                ? Colors.green.shade700
                                : Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: onOpenTrader,
                        child: const Text('Voir toutes les cryptos'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (blockchainProvider.status == BlockchainStatus.error) ...[
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi_off,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        blockchainProvider.error ?? 'Erreur réseau',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (recentHistory.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transactions récentes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, HistoryScreen.routeName),
                  child: const Text('Tout voir'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < recentHistory.length; i++) ...[
                    TransactionTile(
                      record: recentHistory[i],
                      currentAddress: wallet.address,
                    ),
                    if (i < recentHistory.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ] else ...[
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  const Text('Aucune transaction'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RewardsTab extends StatelessWidget {
  const _RewardsTab({
    required this.onOpenDailyMissions,
    required this.onOpenReferral,
    required this.onOpenCashback,
  });

  final VoidCallback onOpenDailyMissions;
  final VoidCallback onOpenReferral;
  final VoidCallback onOpenCashback;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _FeatureCard(
          icon: Icons.task_alt_outlined,
          title: 'Missions quotidiennes',
          description: 'Complétez des actions simples pour gagner des récompenses.',
          onTap: onOpenDailyMissions,
        ),
        _FeatureCard(
          icon: Icons.group_add_outlined,
          title: 'Parrainage',
          description: 'Invitez des amis et recevez des bonus en crypto.',
          onTap: onOpenReferral,
        ),
        _FeatureCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Cashback',
          description: 'Suivez vos gains et récompenses disponibles.',
          onTap: onOpenCashback,
        ),
      ],
    );
  }
}

class _DiscoverTab extends StatelessWidget {
  const _DiscoverTab({
    required this.onOpenDapps,
    required this.onOpenTrends,
    required this.onOpenLearn,
  });

  final VoidCallback onOpenDapps;
  final VoidCallback onOpenTrends;
  final VoidCallback onOpenLearn;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _FeatureCard(
          icon: Icons.public_outlined,
          title: 'DApps populaires',
          description: 'Explorez les applications Web3 les plus utilisées.',
          onTap: onOpenDapps,
        ),
        _FeatureCard(
          icon: Icons.auto_graph_outlined,
          title: 'Tendances crypto',
          description: 'Suivez les actifs en progression et les nouveautés.',
          onTap: onOpenTrends,
        ),
        _FeatureCard(
          icon: Icons.school_outlined,
          title: 'Apprendre',
          description: 'Guides et ressources pour mieux comprendre la crypto.',
          onTap: onOpenLearn,
        ),
      ],
    );
  }
}

class _ConvertTab extends StatelessWidget {
  const _ConvertTab({
    required this.onOpenInstantConvert,
    required this.onOpenRates,
    required this.onOpenConvertHistory,
  });

  final VoidCallback onOpenInstantConvert;
  final VoidCallback onOpenRates;
  final VoidCallback onOpenConvertHistory;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _FeatureCard(
          icon: Icons.swap_horiz_outlined,
          title: 'Conversion instantanée',
          description: 'Convertissez rapidement vos cryptos entre différentes paires.',
          onTap: onOpenInstantConvert,
        ),
        _FeatureCard(
          icon: Icons.currency_exchange_outlined,
          title: 'Taux en temps réel',
          description: 'Consultez les taux du marché avant de confirmer la conversion.',
          onTap: onOpenRates,
        ),
        _FeatureCard(
          icon: Icons.schedule_outlined,
          title: 'Historique de conversion',
          description: 'Retrouvez vos dernières opérations de conversion.',
          onTap: onOpenConvertHistory,
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}
