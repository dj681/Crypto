import 'package:flutter/material.dart';

import '../models/account_entry.dart';

/// Displays a single [AccountEntry] (gift-card recharge or trade) in the
/// unified history list.
class AccountEntryTile extends StatelessWidget {
  const AccountEntryTile({super.key, required this.entry});

  final AccountEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (entry.type) {
      case AccountEntryType.giftCardRecharge:
        return _buildGiftCard(theme);
      case AccountEntryType.tradeBuy:
        return _buildTrade(theme, isBuy: true);
      case AccountEntryType.tradeSell:
        return _buildTrade(theme, isBuy: false);
    }
  }

  // ── gift card ──────────────────────────────────────────────────────────────

  Widget _buildGiftCard(ThemeData theme) {
    final symbol = entry.currency == 'EUR' ? '€' : '\$';
    final amountStr = entry.amount != null
        ? '$symbol${entry.amount!.toStringAsFixed(2)} ${entry.currency ?? ''}'
        : '';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.purple.withOpacity(0.15),
        child: const Icon(Icons.card_giftcard_outlined, color: Colors.purple),
      ),
      title: Text(
        'Carte cadeau — ${entry.cardType ?? ''}',
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.cardCode != null)
            Text('Code : ${entry.cardCode}',
                style: theme.textTheme.bodySmall),
          Text(
            _formatDate(entry.date),
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
      trailing: Text(
        amountStr,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.purple,
          fontWeight: FontWeight.bold,
        ),
      ),
      isThreeLine: true,
    );
  }

  // ── trade ──────────────────────────────────────────────────────────────────

  Widget _buildTrade(ThemeData theme, {required bool isBuy}) {
    final color = isBuy ? Colors.green : Colors.red;
    final sign = isBuy ? '-' : '+';
    final total = (entry.tradeQuantity ?? 0) * (entry.tradeUnitPrice ?? 0);
    final quoteAsset = entry.tradeQuoteAsset ?? 'USD';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.15),
        child: Icon(
          isBuy ? Icons.add_shopping_cart_outlined : Icons.sell_outlined,
          color: color,
        ),
      ),
      title: Text(
        '${isBuy ? 'Achat' : 'Vente'} — ${entry.tradeAsset ?? ''}',
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry.tradeQuantity?.toStringAsFixed(6) ?? '—'} ${entry.tradeAsset ?? ''}'
            ' @ ${entry.tradeUnitPrice?.toStringAsFixed(2) ?? '—'} $quoteAsset',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            _formatDate(entry.date),
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
      trailing: Text(
        '$sign${total.toStringAsFixed(2)} $quoteAsset',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
      isThreeLine: true,
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  static String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
