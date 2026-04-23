import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/market_provider.dart';

/// Displays the account balance in USDT and EUR on the home screen.
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.address,
    required this.marketProvider,
    required this.onRefresh,
  });

  final String address;
  final MarketProvider marketProvider;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mp = marketProvider;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Solde total',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimary.withOpacity(0.8),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: theme.colorScheme.onPrimary,
                    size: 20,
                  ),
                  onPressed: mp.isLoading ? null : onRefresh,
                  tooltip: 'Actualiser',
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildBalanceText(mp, theme),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: address));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Adresse copiée'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      address,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimary.withOpacity(0.7),
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.copy,
                    size: 14,
                    color: theme.colorScheme.onPrimary.withOpacity(0.7),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceText(MarketProvider mp, ThemeData theme) {
    final balanceUsdt = mp.accountBalanceUsdt;
    final balanceEur = mp.accountBalanceEur;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${balanceUsdt.toStringAsFixed(2)} USDT',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${balanceEur.toStringAsFixed(2)} EUR',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onPrimary.withOpacity(0.9),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
