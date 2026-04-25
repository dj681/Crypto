import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account_entry.dart';
import '../providers/account_history_provider.dart';
import '../widgets/account_entry_tile.dart';
import 'gift_card_screen.dart';

/// Displays the list of past gift card recharges recorded in
/// [AccountHistoryProvider], filtered to [AccountEntryType.giftCardRecharge].
class GiftCardHistoryScreen extends StatelessWidget {
  const GiftCardHistoryScreen({super.key});

  static const String routeName = '/gift-card-history';

  @override
  Widget build(BuildContext context) {
    final entries = context
        .watch<AccountHistoryProvider>()
        .entries
        .where((e) => e.type == AccountEntryType.giftCardRecharge)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Mes cartes cadeaux')),
      body: entries.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.card_giftcard_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  const Text('Aucune recharge pour l\'instant'),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      GiftCardScreen.routeName,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Recharger une carte cadeau'),
                  ),
                ],
              ),
            )
          : ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  AccountEntryTile(entry: entries[index]),
            ),
      floatingActionButton: entries.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.pushNamed(
                context,
                GiftCardScreen.routeName,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle recharge'),
            )
          : null,
    );
  }
}
