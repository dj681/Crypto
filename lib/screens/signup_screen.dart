import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/market_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

/// Registration screen: collects email, password, PIN and auto-generates
/// a wallet recovery phrase. On success the Firebase account is created,
/// the profile is written to Firestore, and the wallet is initialised.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  static const String routeName = '/signup';

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _pinController = TextEditingController();

  late final String _recoveryWords;
  bool _backedUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _recoveryWords = context.read<WalletProvider>().generateMnemonic();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_backedUp) {
      setState(() => _errorMessage =
          'Veuillez confirmer avoir noté votre phrase de récupération.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        pin: _pinController.text.trim(),
        recoveryWords: _recoveryWords,
      );

      if (!mounted) return;
      await context.read<WalletProvider>().createWallet(_recoveryWords);
      if (!mounted) return;
      await context.read<MarketProvider>().resetState();
      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        HomeScreen.routeName,
        (route) => false,
      );
    } on SignUpException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Erreur\u00a0: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final words = _recoveryWords.trim().split(RegExp(r'\s+'));

    return Scaffold(
      appBar: AppBar(title: const Text('S\'inscrire')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Email ──────────────────────────────────────────────────────
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Adresse e-mail',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Veuillez entrer votre adresse e-mail.';
                  }
                  if (!value.contains('@')) {
                    return 'Adresse e-mail invalide.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Password ───────────────────────────────────────────────────
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un mot de passe.';
                  }
                  if (value.length < 6) {
                    return 'Le mot de passe doit contenir au moins 6 caractères.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Confirm password ───────────────────────────────────────────
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Les mots de passe ne correspondent pas.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── PIN ────────────────────────────────────────────────────────
              TextFormField(
                controller: _pinController,
                decoration: const InputDecoration(
                  labelText: 'Code PIN (4 chiffres)',
                  prefixIcon: Icon(Icons.pin_outlined),
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                obscureText: true,
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.length != 4) {
                    return 'Le PIN doit contenir exactement 4 chiffres.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // ── Recovery phrase ────────────────────────────────────────────
              Card(
                color: colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_outlined,
                            color: colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Phrase de récupération',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Notez ces mots dans l\'ordre et conservez-les en lieu sûr. '
                        'Ils sont la seule façon de récupérer votre portefeuille.',
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: words
                            .asMap()
                            .entries
                            .map(
                              (e) => Chip(
                                label: Text('${e.key + 1}. ${e.value}'),
                                backgroundColor: colorScheme.surface,
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: _recoveryWords));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Phrase copiée (à stocker en sécurité)'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copier la phrase'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              CheckboxListTile(
                value: _backedUp,
                onChanged: (v) => setState(() => _backedUp = v ?? false),
                title: const Text(
                    'J\'ai noté ma phrase de récupération en lieu sûr'),
                contentPadding: EdgeInsets.zero,
              ),

              // ── Error message ──────────────────────────────────────────────
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),

              // ── Submit ─────────────────────────────────────────────────────
              ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
                child: _isLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('S\'inscrire'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
