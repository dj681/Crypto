import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const String routeName = '/home';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Crypto Safe')),
      body: const Center(
        child: Text('Accueil: portefeuille prêt à être enrichi.'),
      ),
    );
  }
}
