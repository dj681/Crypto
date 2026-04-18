import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/blockchain_provider.dart';
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
      final wallet = context.read<WalletProvider>().wallet!;
      final txHash = await context.read<BlockchainProvider>().sendEth(
            fromAddress: wallet.address,
            toAddress: _toController.text.trim(),
            amountEth: double.parse(_amountController.text.trim()),
          );

      // Reload history from storage (BlockchainProvider already persisted the tx).
      await context.read<WalletProvider>().loadWallet();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaction envoyée !\nHash: ${txHash.substring(0, 20)}…'),
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
            title: const Text('Confirmer l'envoi'),
            content: Text(
              'Envoyer ${_amountController.text.trim()} ETH vers '
              '${_toController.text.trim()}?',
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
    final bp = context.watch<BlockchainProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Envoyer ETH')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (bp.balance != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Solde disponible: ${bp.balance!.toStringAsFixed(6)} ETH',
                      style: Theme.of(context).textTheme.bodyMedium,
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Montant (ETH)',
                  hintText: '0.01',
                  prefixIcon: Icon(Icons.monetization_on_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Montant requis';
                  final amount = double.tryParse(v.trim());
                  if (amount == null || amount <= 0) return 'Montant invalide';
                  if (bp.balance != null && amount > bp.balance!) {
                    return 'Solde insuffisant';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              if (bp.gasPrice != null)
                Text(
                  'Frais de réseau estimés: ${bp.gasPrice!.toStringAsFixed(2)} Gwei',
                  style: Theme.of(context).textTheme.bodySmall,
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
