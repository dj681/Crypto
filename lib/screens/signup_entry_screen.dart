import 'package:flutter/material.dart';

import 'signup_screen.dart';

class SignUpEntryScreen extends StatelessWidget {
  const SignUpEntryScreen({super.key});

  static const String routeName = '/signup/entry';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inscription')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Créez votre compte pour accéder à la création du portefeuille et à votre phrase de récupération.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, SignUpScreen.routeName);
                },
                child: const Text('S\'inscrire avec e-mail'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
