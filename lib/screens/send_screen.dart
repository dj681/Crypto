import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/tx_record.dart';
import '../providers/market_provider.dart';
import '../providers/wallet_provider.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  static const String routeName = '/send';

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _formKey = GlobalKey<FormState>();
  final _toController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _toController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await _confirmDialog();
    if (!confirmed) return;

    setState(() => _isSending = true);
    try {
      final marketProvider = context.read<MarketProvider>();
      final walletProvider = context.read<WalletProvider>();
      final wallet = walletProvider.wallet!;
      final amount = double.parse(_amountController.text.trim());

      marketProvider.deductBalance(amount);

      final txHash =
          'usdt-${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
      await walletProvider.appendTransaction(
        TxRecord(
          txHash: txHash,
          from: wallet.address,
          to: _toController.text.trim(),
          valueEth: amount,
          timestamp: DateTime.now(),
          status: TxStatus.confirmed,
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Envoi de ${amount.toStringAsFixed(2)} USDT effectué !',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<bool> _confirmDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Confirmer l'envoi"),
            content: Text(
              'Envoyer ${_amountController.text.trim()} USDT vers '
              '${_toController.text.trim()} ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirmer'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MarketProvider>();
    final balanceUsdt = mp.accountBalanceUsdt;
    final balanceEur = mp.accountBalanceEur;

    return Scaffold(
      appBar: AppBar(title: const Text('Envoyer USDT')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Solde disponible',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${balanceUsdt.toStringAsFixed(2)} USDT',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${balanceEur.toStringAsFixed(2)} EUR',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _toController,
                decoration: const InputDecoration(
                  labelText: 'Adresse destinataire',
                  hintText: '0x...',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Adresse requise';
                  }
                  final addr = v.trim();
                  if (!addr.startsWith('0x') || addr.length != 42) {
                    return 'Adresse Ethereum invalide (0x + 40 hex chars)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Montant (USDT)',
                  hintText: '10.00',
                  prefixIcon: Icon(Icons.monetization_on_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Montant requis';
                  final amount = double.tryParse(v.trim());
                  if (amount == null || amount <= 0) return 'Montant invalide';
                  if (amount > balanceUsdt) return 'Solde insuffisant';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isSending ? null : _send,
                icon: _isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('Envoyer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
