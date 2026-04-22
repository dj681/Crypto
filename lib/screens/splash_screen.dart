import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/security_provider.dart';
import '../providers/wallet_provider.dart';
import 'home_screen.dart';
import 'lock_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const String routeName = '/';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Non-null when wallet loading failed and the user should be offered a retry.
  String? _loadError;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    if (!mounted) return;
    setState(() => _loadError = null);
    try {
      final walletProvider = context.read<WalletProvider>();
      final securityProvider = context.read<SecurityProvider>();

      // Load wallet and security state in parallel.
      await Future.wait([
        walletProvider.loadWallet(),
        securityProvider.init(),
      ]);

      if (!mounted) return;

      // If wallet loading itself reported an error, stay on the splash screen
      // and let the user retry instead of sending them to Onboarding (which
      // would be confusing for users who already have an account).
      if (walletProvider.status == WalletStatus.error) {
        setState(() => _loadError = walletProvider.error ?? 'Erreur de chargement du portefeuille.');
        return;
      }

      if (!walletProvider.hasWallet) {
        Navigator.pushReplacementNamed(context, OnboardingScreen.routeName);
        return;
      }

      if (securityProvider.isLocked) {
        Navigator.pushReplacementNamed(context, LockScreen.routeName);
      } else {
        Navigator.pushReplacementNamed(context, HomeScreen.routeName);
      }
    } catch (e, st) {
      debugPrint(
        'Splash init failed with unexpected error: $e\n$st',
      );
      if (!mounted) return;
      setState(() => _loadError = 'Erreur inattendue. Veuillez réessayer.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Impossible de charger le portefeuille',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _loadError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => unawaited(_init()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'My Crypto Safe',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
