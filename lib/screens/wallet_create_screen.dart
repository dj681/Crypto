import 'package:flutter/material.dart';

import 'home_screen.dart';

class WalletCreateScreen extends StatelessWidget {
  const WalletCreateScreen({super.key});

  static const String routeName = '/wallet/create';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un portefeuille')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Écran de création du portefeuille (starter).',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  HomeScreen.routeName,
                  (route) => false,
                );
              },
              child: const Text('Continuer vers l’accueil'),
            ),
          ],
        ),
      ),
    );
  }
}
