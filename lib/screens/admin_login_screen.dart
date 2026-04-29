import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/market_provider.dart';
import '../providers/wallet_provider.dart';
import 'admin_recharge_history_screen.dart';
import 'pin_setup_screen.dart';

/// Hidden administrator login page.
///
/// Accessible directly via the URL fragment `#/abytone` but intentionally
/// not linked from any public UI element.  Prompts the operator for the
/// admin recovery phrase and, on success, imports the admin account.
class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  static const String routeName = '/abytone';

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _controller = TextEditingController();
  String? _error;
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final phrase = _controller.text.trim();
    if (phrase.isEmpty) {
      setState(() => _error = 'Veuillez saisir la phrase administrateur.');
      return;
    }

    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      await context.read<WalletProvider>().importWallet(phrase);
      if (!mounted) return;

      final wallet = context.read<WalletProvider>().wallet;
      if (wallet?.isAdmin != true) {
        await context.read<WalletProvider>().clearWallet();
        if (!mounted) return;
        setState(() {
          _error = 'Accès refusé.';
          _isLoading = false;
        });
        return;
      }

      // Reset market state for the admin account.
      await context.read<MarketProvider>().resetState();
      if (!mounted) return;

      final setupPin = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Sécuriser avec un PIN ?'),
              content: const Text(
                'Nous recommandons de protéger ce compte avec un code PIN.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Non'),
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
        Navigator.pushNamedAndRemoveUntil(
          context,
          PinSetupScreen.routeName,
          (route) => false,
        );
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AdminRechargeHistoryScreen.routeName,
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Phrase invalide ou non autorisée.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Accès administrateur',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _controller,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Phrase de récupération',
                    border: const OutlineInputBorder(),
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Connexion'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
