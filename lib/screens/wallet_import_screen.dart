import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/security_provider.dart';
import '../providers/wallet_provider.dart';
import 'admin_recharge_history_screen.dart';
import 'home_screen.dart';
import 'pin_setup_screen.dart';

class WalletImportScreen extends StatefulWidget {
  const WalletImportScreen({super.key});

  static const String routeName = '/wallet/import';

  @override
  State<WalletImportScreen> createState() => _WalletImportScreenState();
}

class _WalletImportScreenState extends State<WalletImportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mnemonicController = TextEditingController();
  bool _isImporting = false;
  String? _validationError;

  @override
  void dispose() {
    _mnemonicController.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isImporting = true;
      _validationError = null;
    });

    try {
      await context
          .read<WalletProvider>()
          .importWallet(_mnemonicController.text.trim());

      if (!mounted) return;

      final wallet = context.read<WalletProvider>().wallet;

      if (wallet?.isAdmin == true) {
        // Admin account: PIN is pre-configured (817319). Sync the security
        // provider state so isLocked / hasPin are correct, then navigate.
        await context.read<SecurityProvider>().init();
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AdminRechargeHistoryScreen.routeName,
          (route) => false,
        );
        return;
      }

      final setupPin = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Sécuriser avec un PIN ?'),
              content: const Text(
                'Nous recommandons de protéger votre portefeuille avec un code PIN.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Plus tard'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Configurer le PIN'),
                ),
              ],
            ),
          ) ??
          false;

      if (!mounted) return;
      if (setupPin) {
        await Navigator.pushNamed(context, PinSetupScreen.routeName);
      }
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        HomeScreen.routeName,
        (route) => false,
      );
    } on ArgumentError catch (e) {
      setState(() => _validationError = e.message.toString());
    } catch (e) {
      setState(() => _validationError = 'Erreur inattendue: $e');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importer un portefeuille')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Saisissez vos 4 mots de récupération, '
                'séparés par des espaces. '
                'Les anciennes phrases BIP-39 (12/24 mots) restent acceptées.',
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _mnemonicController,
                maxLines: 4,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Phrase de récupération',
                  hintText: 'mot1 mot2 mot3 ...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'La phrase de récupération est requise';
                  }
                  final wordCount = v.trim().split(RegExp(r'\s+')).length;
                  if (wordCount != 4 && wordCount != 12 && wordCount != 24) {
                    return 'La phrase doit contenir 4, 12 ou 24 mots (actuellement : $wordCount)';
                  }
                  return null;
                },
              ),
              if (_validationError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _validationError!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isImporting ? null : _import,
                icon: _isImporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                label: const Text('Importer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
