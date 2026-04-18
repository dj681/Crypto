import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/wallet_create_screen.dart';
import 'screens/wallet_import_screen.dart';

void main() {
  runApp(const MyCryptoSafeApp());
}

class MyCryptoSafeApp extends StatelessWidget {
  const MyCryptoSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Crypto Safe',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: SplashScreen.routeName,
      routes: {
        SplashScreen.routeName: (context) => const SplashScreen(),
        OnboardingScreen.routeName: (context) => const OnboardingScreen(),
        WalletCreateScreen.routeName: (context) => const WalletCreateScreen(),
        WalletImportScreen.routeName: (context) => const WalletImportScreen(),
        HomeScreen.routeName: (context) => const HomeScreen(),
      },
    );
  }
}
