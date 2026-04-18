import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/wallet_provider.dart';
import '../widgets/transaction_tile.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static const String routeName = '/history';

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WalletProvider>();
    final address = wp.wallet?.address ?? '';
    final history = wp.history;

    return Scaffold(
      appBar: AppBar(title: const Text('Historique')),
      body: history.isEmpty
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
              itemCount: history.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return TransactionTile(
                  record: history[index],
                  currentAddress: address,
                );
              },
            ),
    );
  }
}
