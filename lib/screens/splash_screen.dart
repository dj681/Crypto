import 'dart:async' show TimeoutException, unawaited;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/security_provider.dart';
import '../providers/wallet_provider.dart';
import 'admin_recharge_history_screen.dart';
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
  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      final walletProvider = context.read<WalletProvider>();
      final securityProvider = context.read<SecurityProvider>();

      // Load wallet and security state in parallel.
      // A generous timeout ensures the app always navigates forward even when
      // the device's secure storage or biometrics API hangs unexpectedly.
      await Future.wait([
        walletProvider.loadWallet(),
        securityProvider.init(),
      ]).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (!walletProvider.hasWallet) {
        Navigator.pushReplacementNamed(context, OnboardingScreen.routeName);
        return;
      }

      if (securityProvider.isLocked) {
        Navigator.pushReplacementNamed(context, LockScreen.routeName);
      } else {
        final isAdmin = walletProvider.wallet?.isAdmin == true;
        Navigator.pushReplacementNamed(
          context,
          isAdmin
              ? AdminRechargeHistoryScreen.routeName
              : HomeScreen.routeName,
        );
      }
    } catch (e, st) {
      debugPrint(
        'Splash init failed with unexpected error - navigating to onboarding: $e\n$st',
      );
      if (e is TimeoutException) {
        debugPrint(
          'Startup timed out after 10 s – secure-storage may be unavailable.',
        );
      }
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, OnboardingScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
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
