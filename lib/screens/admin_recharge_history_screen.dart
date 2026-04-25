import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account_entry.dart';
import '../providers/account_history_provider.dart';
import 'home_screen.dart';

/// Special screen displayed to the administrator/supervisor account after PIN
/// authentication.  Lists **all** gift-card recharge entries from every account
/// that has ever used this app on the device, sorted newest-first, each row
/// showing the originating account's [AccountEntry.userId].
class AdminRechargeHistoryScreen extends StatelessWidget {
  const AdminRechargeHistoryScreen({super.key});

  static const String routeName = '/admin/recharge-history';

  static String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    final hour = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$min';
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = context
        .watch<AccountHistoryProvider>()
        .entries
        .where((e) => e.type == AccountEntryType.giftCardRecharge)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historiques de recharge – Tous comptes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Accueil',
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              HomeScreen.routeName,
              (route) => false,
            ),
          ),
        ],
      ),
      body: allEntries.isEmpty
          ? _buildEmpty(context)
          : _buildList(context, allEntries),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.card_giftcard_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          const Text('Aucun historique de recharge disponible.'),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<AccountEntry> entries) {
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final accountLabel = entry.userId ?? 'Compte inconnu';
        final currencySymbol = entry.currency == 'EUR' ? '€' : '\$';
        final amountStr = entry.amount != null
            ? '$currencySymbol${entry.amount!.toStringAsFixed(2)} ${entry.currency ?? ''}'
            : '—';

        return ListTile(
          leading: CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.card_giftcard,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          title: Text(entry.cardType ?? 'Carte cadeau'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      accountLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (entry.cardCode != null)
                Text(
                  entry.cardCode!,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountStr,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                _formatDate(entry.date),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          isThreeLine: true,
        );
      },
    );
  }
}
