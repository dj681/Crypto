import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/wallet_provider.dart';
import 'home_screen.dart';
import 'pin_setup_screen.dart';

class WalletImportScreen extends StatefulWidget {
  const WalletImportScreen({super.key});

  static const String routeName = '/wallet/import';

  @override
  State<WalletImportScreen> createState() => _WalletImportScreenState();
}

class _WalletImportScreenState extends State<WalletImportScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _isImporting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final phrase = _controller.text.trim();
    if (phrase.isEmpty) {
      setState(() => _error = 'Veuillez saisir votre phrase de récupération.');
      return;
    }

    setState(() {
      _error = null;
      _isImporting = true;
    });

    try {
      await context.read<WalletProvider>().importWallet(phrase);
      if (!mounted) return;

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
      if (!mounted) return;
      setState(() => _error = e.message.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Erreur: $e');
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Saisissez votre phrase de récupération (4 mots ou phrase BIP-39) pour restaurer votre portefeuille.',
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Phrase de récupération',
                hintText: 'mot1 mot2 mot3 mot4',
                border: OutlineInputBorder(),
              ),
              autocorrect: false,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _isImporting ? null : _import(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isImporting ? null : _import,
              child: _isImporting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Importer'),
            ),
          ],
        ),
      ),
    );
  }
}
