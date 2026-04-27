import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account_entry.dart';
import '../providers/account_history_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/gift_card_service.dart';

class GiftCardScreen extends StatefulWidget {
  const GiftCardScreen({super.key});

  static const String routeName = '/gift-card';

  @override
  State<GiftCardScreen> createState() => _GiftCardScreenState();
}

class _GiftCardScreenState extends State<GiftCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _amountController = TextEditingController();
  GiftCardType _selectedType = giftCardTypes.first;
  String _currency = 'USD';
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await _confirmDialog();
    if (!confirmed) return;

    setState(() => _isLoading = true);
    final amount = double.parse(_amountController.text.trim());
    final code = normalizeGiftCardCode(_codeController.text);

    try {
      if (!mounted) return;

      // Record in unified account history.
      final userId = context.read<WalletProvider>().wallet?.userId;
      context.read<AccountHistoryProvider>().addEntry(
            AccountEntry(
              id: '${DateTime.now().microsecondsSinceEpoch}',
              type: AccountEntryType.giftCardRecharge,
              date: DateTime.now(),
              userId: userId,
              cardType: _selectedType.name,
              cardCode: code,
              amount: amount,
              currency: _currency,
            ),
          );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recharge enregistrée avec succès !'),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _confirmDialog() async {
    final symbol = _currency == 'EUR' ? '€' : '\$';
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmer la recharge'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type : ${_selectedType.name}'),
                Text(
                  'Montant : $symbol${_amountController.text.trim()} $_currency',
                ),
                Text('Code : ${_codeController.text.trim().toUpperCase()}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Recharger'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = _currency == 'EUR' ? '€' : '\$';
    return Scaffold(
      appBar: AppBar(title: const Text('Recharger avec carte cadeau')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Type de carte cadeau ─────────────────────────────────────
              DropdownButtonFormField<GiftCardType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type de carte cadeau',
                  prefixIcon: Icon(Icons.card_giftcard_outlined),
                  border: OutlineInputBorder(),
                ),
                items: giftCardTypes
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.name),
                      ),
                    )
                    .toList(),
                onChanged: (type) {
                  if (type == null) return;
                  setState(() {
                    _selectedType = type;
                    _codeController.clear();
                  });
                },
                validator: (v) =>
                    v == null ? 'Veuillez sélectionner un type' : null,
              ),
              const SizedBox(height: 16),

              // ── Devise ────────────────────────────────────────────────────
              Row(
                children: [
                  const Text('Devise :'),
                  const SizedBox(width: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'USD',
                        label: Text('\$ USD'),
                        icon: Icon(Icons.attach_money),
                      ),
                      ButtonSegment(
                        value: 'EUR',
                        label: Text('€ EUR'),
                        icon: Icon(Icons.euro),
                      ),
                    ],
                    selected: {_currency},
                    onSelectionChanged: (selection) {
                      if (selection.isEmpty) return;
                      setState(() => _currency = selection.first);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Montant ───────────────────────────────────────────────────
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Montant ($_currency)',
                  hintText: '25.00',
                  prefixIcon: Icon(
                    _currency == 'EUR'
                        ? Icons.euro_outlined
                        : Icons.attach_money_outlined,
                  ),
                  prefixText: '$currencySymbol ',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Montant requis';
                  final amount = double.tryParse(v.trim());
                  if (amount == null || amount <= 0) return 'Montant invalide';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Code de la carte cadeau ───────────────────────────────────
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Code de la carte cadeau',
                  hintText: _selectedType.example,
                  helperText: 'Format : ${_selectedType.hintText}',
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Code requis';
                  // Normalize: uppercase and strip dashes/spaces so that codes
                  // copied without separators or with spaces are accepted.
                  final normalized = normalizeGiftCardCode(v);
                  if (!_selectedType.pattern.hasMatch(normalized)) {
                    return 'Format invalide. Attendu : ${_selectedType.hintText}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // ── Bouton Recharger ──────────────────────────────────────────
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Recharger'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
