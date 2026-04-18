import 'package:flutter/material.dart';

import '../models/tx_record.dart';

/// A single row in the transaction history list.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.record,
    required this.currentAddress,
  });

  final TxRecord record;
  final String currentAddress;

  bool get _isSent =>
      record.from.toLowerCase() == currentAddress.toLowerCase();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSent = _isSent;
    final statusColor = _statusColor(record.status, theme);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            (isSent ? Colors.red : Colors.green).withOpacity(0.15),
        child: Icon(
          isSent ? Icons.arrow_upward : Icons.arrow_downward,
          color: isSent ? Colors.red : Colors.green,
        ),
      ),
      title: Text(
        isSent ? 'Envoi' : 'Réception',
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isSent
                ? 'Vers: ${_shortAddress(record.to)}'
                : 'De: ${_shortAddress(record.from)}',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            _formatDate(record.timestamp),
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${isSent ? '-' : '+'}${record.valueEth.toStringAsFixed(6)} ETH',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isSent ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _statusLabel(record.status),
              style: theme.textTheme.labelSmall?.copyWith(color: statusColor),
            ),
          ),
        ],
      ),
      isThreeLine: true,
    );
  }

  static String _shortAddress(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}…${address.substring(address.length - 4)}';
  }

  static String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  static Color _statusColor(TxStatus status, ThemeData theme) {
    switch (status) {
      case TxStatus.confirmed:
        return Colors.green;
      case TxStatus.failed:
        return Colors.red;
      case TxStatus.pending:
        return Colors.orange;
    }
  }

  static String _statusLabel(TxStatus status) {
    switch (status) {
      case TxStatus.confirmed:
        return 'Confirmé';
      case TxStatus.failed:
        return 'Échoué';
      case TxStatus.pending:
        return 'En attente';
    }
  }
}
