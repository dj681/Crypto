import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/blockchain_provider.dart';

/// Displays the wallet ETH balance prominently on the home screen.
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.address,
    required this.blockchainProvider,
    required this.onRefresh,
  });

  final String address;
  final BlockchainProvider blockchainProvider;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bp = blockchainProvider;

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
                  'Solde ETH',
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
                  onPressed: bp.isLoading ? null : onRefresh,
                  tooltip: 'Actualiser',
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildBalanceText(context, bp, theme),
            if (bp.gasPrice != null) ...[
              const SizedBox(height: 4),
              Text(
                'Gas: ${bp.gasPrice!.toStringAsFixed(2)} Gwei',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimary.withOpacity(0.7),
                ),
              ),
            ],
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

  Widget _buildBalanceText(
    BuildContext context,
    BlockchainProvider bp,
    ThemeData theme,
  ) {
    if (bp.isLoading) {
      return SizedBox(
        height: 40,
        child: CircularProgressIndicator(
          color: theme.colorScheme.onPrimary,
          strokeWidth: 2,
        ),
      );
    }
    if (bp.status == BlockchainStatus.error) {
      return Text(
        'Erreur réseau',
        style: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onPrimary,
        ),
      );
    }
    final balance = bp.balance;
    return Text(
      balance != null ? '${balance.toStringAsFixed(6)} ETH' : '— ETH',
      style: theme.textTheme.headlineMedium?.copyWith(
        color: theme.colorScheme.onPrimary,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
