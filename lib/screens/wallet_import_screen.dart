import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class WalletImportScreen extends StatefulWidget {
  const WalletImportScreen({super.key});

  static const String routeName = '/wallet/import';

  @override
  State<WalletImportScreen> createState() => _WalletImportScreenState();
}

class _WalletImportScreenState extends State<WalletImportScreen> {
  bool _success = false;

  void _onButtonPressed() {
    debugPrint('Bouton cliqué');
    setState(() {
      _success = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importer un portefeuille')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _onButtonPressed,
              child: const Text('Valider'),
            ),
            if (_success) ...[
              const SizedBox(height: 24),
              const Text(
                'SUCCÈS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
