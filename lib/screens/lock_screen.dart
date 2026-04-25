import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/security_provider.dart';
import '../providers/wallet_provider.dart';
import '../widgets/pin_pad.dart';
import 'admin_recharge_history_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

/// Shown when the session is locked.  Accepts PIN or biometric authentication.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  static const String routeName = '/lock';

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  int _padResetKey = 0;
  String? _errorMessage;
  bool _bioLoading = false;

  void _onPin(String pin) async {
    final ok = await context.read<SecurityProvider>().unlockWithPin(pin);
    if (ok) {
      _navigateAfterUnlock();
    } else {
      setState(() {
        _errorMessage = 'PIN incorrect';
        _padResetKey++;
      });
    }
  }

  Future<void> _onBiometric() async {
    setState(() => _bioLoading = true);
    final ok = await context.read<SecurityProvider>().unlockWithBiometrics();
    if (mounted) setState(() => _bioLoading = false);
    if (ok) _navigateAfterUnlock();
  }

  Future<void> _recoverWithPhrase() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Récupérer avec la phrase ?'),
            content: const Text(
              'Vous allez effacer le portefeuille actuel de cet appareil et '
              'en importer un nouveau à l\'aide de votre phrase de récupération. '
              'Assurez-vous de la connaître avant de continuer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Continuer'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    await context.read<WalletProvider>().clearWallet();
    if (!mounted) return;
    await context.read<SecurityProvider>().init();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      OnboardingScreen.routeName,
      (route) => false,
    );
  }

  void _navigateAfterUnlock() {
    final wallet = context.read<WalletProvider>().wallet;
    final destination = (wallet?.isAdmin == true)
        ? AdminRechargeHistoryScreen.routeName
        : HomeScreen.routeName;
    Navigator.pushNamedAndRemoveUntil(
      context,
      destination,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>().wallet;
    final security = context.watch<SecurityProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'My Crypto Safe',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Session verrouillée',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 40),
              PinPad(
                key: ValueKey(_padResetKey),
                onCompleted: _onPin,
                errorMessage: _errorMessage,
              ),
              if (wallet?.hasBiometricsEnabled == true &&
                  security.biometricsAvailable) ...[
                const SizedBox(height: 16),
                _bioLoading
                    ? const CircularProgressIndicator()
                    : OutlinedButton.icon(
                        onPressed: _onBiometric,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Déverrouiller avec la biométrie'),
                      ),
              ],
              const SizedBox(height: 24),
              TextButton(
                onPressed: _recoverWithPhrase,
                child: const Text('Récupérer avec ma phrase de récupération'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
