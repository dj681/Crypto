import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account_entry.dart';
import '../models/tx_record.dart';
import '../providers/account_history_provider.dart';
import '../providers/wallet_provider.dart';
import '../widgets/account_entry_tile.dart';
import '../widgets/transaction_tile.dart';

/// Unified account history: ETH blockchain transactions (from [WalletProvider])
/// merged with gift-card recharges and trades (from [AccountHistoryProvider]),
/// sorted newest-first.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static const String routeName = '/history';

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WalletProvider>();
    final ahp = context.watch<AccountHistoryProvider>();
    final address = wp.wallet?.address ?? '';

    // Build a unified list: each item is either a TxRecord or an AccountEntry.
    final items = _mergedItems(wp.history, ahp.entries);

    return Scaffold(
      appBar: AppBar(title: const Text('Historique')),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  const Text("Aucune transaction pour l'instant"),
                ],
              ),
            )
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                if (item is TxRecord) {
                  return TransactionTile(
                    record: item,
                    currentAddress: address,
                  );
                }
                return AccountEntryTile(entry: item as AccountEntry);
              },
            ),
    );
  }

  /// Merges [ethTxs] and [accountEntries] into a single list sorted
  /// newest-first by date.
  static List<Object> _mergedItems(
    List<TxRecord> ethTxs,
    List<AccountEntry> accountEntries,
  ) {
    final items = <Object>[...ethTxs, ...accountEntries];
    items.sort((a, b) {
      final da = a is TxRecord ? a.timestamp : (a as AccountEntry).date;
      final db = b is TxRecord ? b.timestamp : (b as AccountEntry).date;
      return db.compareTo(da); // newest first
    });
    return items;
  }
}
