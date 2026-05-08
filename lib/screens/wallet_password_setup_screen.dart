import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/market_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/auth_service.dart';
import '../services/wallet_password_service.dart';
import 'home_screen.dart';

class WalletPasswordSetupScreen extends StatefulWidget {
  const WalletPasswordSetupScreen({super.key});

  static const String routeName = '/signup/wallet-password';

  @override
  State<WalletPasswordSetupScreen> createState() =>
      _WalletPasswordSetupScreenState();
}

class _WalletPasswordSetupScreenState extends State<WalletPasswordSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  final _walletPasswordService = WalletPasswordService();

  String? _recoveryWords;
  bool _didInitRecoveryWords = false;
  bool _backedUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitRecoveryWords) return;
    _recoveryWords = context.read<WalletProvider>().generateMnemonic();
    _didInitRecoveryWords = true;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_backedUp) {
      setState(() {
        _errorMessage =
            'Veuillez confirmer avoir noté votre phrase de récupération.';
      });
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      setState(() {
        _errorMessage = 'Session invalide. Veuillez recommencer l’inscription.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _walletPasswordService.setWalletPassword(_passwordController.text);
      await _authService.markWalletPasswordSet(uid: uid);

      await context.read<WalletProvider>().createWallet(_recoveryWords!);
      if (!mounted) return;
      await context.read<MarketProvider>().resetState();
      if (!mounted) return;

      final wallet = context.read<WalletProvider>().wallet;
      await _authService.markWalletReady(
        uid: uid,
        walletAddress: wallet?.address ?? '',
        hasBackupConfirmed: _backedUp,
        hasPinEnabled: wallet?.hasPinEnabled ?? false,
        hasBiometricsEnabled: wallet?.hasBiometricsEnabled ?? false,
      );

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        HomeScreen.routeName,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Erreur\u00a0: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final recoveryWords = _recoveryWords;
    if (recoveryWords == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final words = recoveryWords.trim().split(RegExp(r'\s+'));

    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe portefeuille')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Mot de passe portefeuille',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                  ),
                ),
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un mot de passe.';
                  }
                  if (value.length < 10) {
                    return 'Minimum 10 caractères.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirmer le mot de passe portefeuille',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Les mots de passe ne correspondent pas.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
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
                          Clipboard.setData(ClipboardData(text: recoveryWords));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Phrase copiée (à stocker en sécurité)'),
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
                  'J\'ai noté ma phrase de récupération en lieu sûr',
                ),
                contentPadding: EdgeInsets.zero,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _completeOnboarding,
                child: _isLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Finaliser l’inscription'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
