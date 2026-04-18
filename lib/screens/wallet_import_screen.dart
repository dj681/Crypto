import 'package:flutter/material.dart';

import 'home_screen.dart';

class WalletImportScreen extends StatelessWidget {
  const WalletImportScreen({super.key});

  static const String routeName = '/wallet/import';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importer un portefeuille')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Écran d’import du portefeuille (starter).',
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
