import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/blockchain_provider.dart';
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
  @override
  void initState() {
    super.initState();
    // Refresh balance when the home screen is first shown.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshBalance());
  }

  void _refreshBalance() {
    final address = context.read<WalletProvider>().wallet?.address;
    if (address != null) {
      context.read<BlockchainProvider>().refreshBalance(address);
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final blockchainProvider = context.watch<BlockchainProvider>();
    final wallet = walletProvider.wallet;
    final recentHistory = walletProvider.history.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Crypto Safe'),
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
          : RefreshIndicator(
              onRefresh: () => blockchainProvider.refreshBalance(wallet.address),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  BalanceCard(
                    address: wallet.address,
                    blockchainProvider: blockchainProvider,
                    onRefresh: _refreshBalance,
                  ),
                  const SizedBox(height: 24),
                  // Quick action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.arrow_upward,
                          label: 'Envoyer',
                          onTap: () =>
                              Navigator.pushNamed(context, SendScreen.routeName)
                                  .then((_) => _refreshBalance()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.arrow_downward,
                          label: 'Recevoir',
                          onTap: () =>
                              Navigator.pushNamed(context, ReceiveScreen.routeName),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.candlestick_chart_outlined,
                          label: 'Marché',
                          onTap: () => Navigator.pushNamed(
                              context, MarketScreen.routeName),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.history,
                          label: 'Historique',
                          onTap: () => Navigator.pushNamed(
                              context, HistoryScreen.routeName),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (blockchainProvider.status ==
                      BlockchainStatus.error) ...[
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.wifi_off,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                blockchainProvider.error ?? 'Erreur réseau',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer),
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
                          onPressed: () => Navigator.pushNamed(
                              context, HistoryScreen.routeName),
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
                            if (i < recentHistory.length - 1)
                              const Divider(height: 1),
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
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant,
                          ),
                          const SizedBox(height: 16),
                          const Text('Aucune transaction'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
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
