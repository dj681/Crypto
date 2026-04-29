import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account_entry.dart';
import '../providers/account_history_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/gift_card_service.dart';
import 'home_screen.dart';

/// Special screen displayed to the administrator/supervisor account after PIN
/// authentication.  Lists **all** gift-card recharge entries from every account
/// that has ever used this app on the device, sorted newest-first, each row
/// showing the originating account's [AccountEntry.userId].
///
/// When a backend is configured ([BACKEND_URL] is set), the screen also fetches
/// recharges submitted from other devices so the admin sees a complete picture.
///
/// Access is guarded: non-admin wallets are immediately redirected to
/// [HomeScreen].
class AdminRechargeHistoryScreen extends StatefulWidget {
  const AdminRechargeHistoryScreen({super.key});

  static const String routeName = '/admin/recharge-history';

  @override
  State<AdminRechargeHistoryScreen> createState() =>
      _AdminRechargeHistoryScreenState();
}

class _AdminRechargeHistoryScreenState
    extends State<AdminRechargeHistoryScreen> {
  List<AccountEntry> _backendEntries = [];
  bool _isLoadingBackend = false;

  /// Non-null when the backend fetch failed or is not configured.
  String? _backendError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _guardAccess();
      _loadBackendRecharges();
    });
  }

  void _guardAccess() {
    if (!mounted) return;
    final wallet = context.read<WalletProvider>().wallet;
    if (wallet?.isAdmin != true) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        HomeScreen.routeName,
        (route) => false,
      );
    }
  }

  Future<void> _loadBackendRecharges() async {
    setState(() {
      _isLoadingBackend = true;
      _backendError = null;
    });
    try {
      final result = await GiftCardService().fetchRechargesWithStatus();
      final entries = result.entries.map((item) {
        final receivedAt = item['receivedAt'] as String?;
        return AccountEntry(
          id: 'backend-${item['id']}',
          type: AccountEntryType.giftCardRecharge,
          date: receivedAt != null
              ? DateTime.tryParse(receivedAt) ?? DateTime.now()
              : DateTime.now(),
          userId: item['userId'] as String? ??
              // walletAddress is sent when userId is unavailable (older clients).
              item['walletAddress'] as String?,
          cardType: item['cardType'] as String?,
          cardCode: item['code'] as String?,
          amount: (item['amount'] as num?)?.toDouble(),
          currency: item['currency'] as String?,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _backendEntries = entries;
          _backendError = result.error;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _backendError = 'Erreur inattendue : $e');
      }
    } finally {
      if (mounted) setState(() => _isLoadingBackend = false);
    }
  }

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
    final wallet = context.watch<WalletProvider>().wallet;

    // If wallet not yet loaded or not admin, show a loading/blank state
    // while the guard in initState redirects.
    if (wallet?.isAdmin != true) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final localEntries = context
        .watch<AccountHistoryProvider>()
        .entries
        .where((e) => e.type == AccountEntryType.giftCardRecharge)
        .toList();

    // Merge local and backend entries, deduplicating by card code.
    // Gift card codes are one-time-use tokens that uniquely identify a
    // recharge, so a matching code means the same recharge is already
    // recorded locally (preferred, as it retains full user context).
    final localCodes = <String>{
      for (final e in localEntries)
        if (e.cardCode != null) e.cardCode!,
    };
    final uniqueBackendEntries = _backendEntries
        .where((e) => e.cardCode == null || !localCodes.contains(e.cardCode))
        .toList();

    final allEntries = [
      ...localEntries,
      ...uniqueBackendEntries,
    ]..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historiques de recharge – Tous comptes'),
        actions: [
          if (_isLoadingBackend)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualiser',
              onPressed: _loadBackendRecharges,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_backendError != null && !_isLoadingBackend)
            _buildBackendBanner(context, _backendError!),
          Expanded(
            child: allEntries.isEmpty
                ? _buildEmpty(context)
                : _buildList(context, allEntries),
          ),
        ],
      ),
    );
  }

  /// Banner shown at the top of the screen when the backend is unavailable
  /// or not configured.
  Widget _buildBackendBanner(BuildContext context, String message) {
    final isConfigIssue = !GiftCardService.isBackendConfigured ||
        !GiftCardService.isAdminTokenConfigured;
    final color = isConfigIssue
        ? Theme.of(context).colorScheme.secondaryContainer
        : Theme.of(context).colorScheme.errorContainer;
    final textColor = isConfigIssue
        ? Theme.of(context).colorScheme.onSecondaryContainer
        : Theme.of(context).colorScheme.onErrorContainer;
    final icon = isConfigIssue ? Icons.info_outline : Icons.warning_amber_rounded;

    return Material(
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: textColor),
              ),
            ),
          ],
        ),
      ),
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
