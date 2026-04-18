import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'wallet_create_screen.dart';
import 'wallet_import_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  static const String routeName = '/onboarding';
  static final Uri _pwaUri = Uri.parse('https://dj681-crypto.netlify.app/');

  Future<void> _openExternalLink(BuildContext context, Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (launched) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Impossible d’ouvrir le lien.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bienvenue')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'My Crypto Safe',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Votre portefeuille crypto sécurisé.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, WalletCreateScreen.routeName);
                },
                child: const Text('Créer un portefeuille'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.pushNamed(context, WalletImportScreen.routeName);
                },
                child: const Text('Importer un portefeuille'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => _openExternalLink(context, _pwaUri),
                child: const Text('Progressive Web App'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
