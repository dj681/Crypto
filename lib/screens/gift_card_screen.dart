import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  final GiftCardService _service = GiftCardService();

  GiftCardType _selectedType = giftCardTypes.first;
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
    try {
      final wallet = context.read<WalletProvider>().wallet;
      await _service.submitRecharge(
        cardType: _selectedType.name,
        amount: double.parse(_amountController.text.trim()),
        code: normalizeGiftCardCode(_codeController.text),
        walletAddress: wallet?.address,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recharge envoyée avec succès !'),
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
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmer la recharge'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type : ${_selectedType.name}'),
                Text('Montant : ${_amountController.text.trim()} USDT'),
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

              // ── Montant ───────────────────────────────────────────────────
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Montant (USDT)',
                  hintText: '25.00',
                  prefixIcon: Icon(Icons.monetization_on_outlined),
                  border: OutlineInputBorder(),
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
