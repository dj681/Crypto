import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/wallet_provider.dart';
import '../widgets/mnemonic_grid.dart';
import 'home_screen.dart';
import 'pin_setup_screen.dart';

/// Three-step flow: generate → reveal → confirm → (optional PIN setup).
class WalletCreateScreen extends StatefulWidget {
  const WalletCreateScreen({super.key});

  static const String routeName = '/wallet/create';

  @override
  State<WalletCreateScreen> createState() => _WalletCreateScreenState();
}

enum _CreateStep { reveal, confirm }

class _WalletCreateScreenState extends State<WalletCreateScreen> {
  late final String _mnemonic;
  _CreateStep _step = _CreateStep.reveal;
  bool _backedUp = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _mnemonic = context.read<WalletProvider>().generateMnemonic();
  }

  Future<void> _createWallet() async {
    setState(() => _isCreating = true);
    try {
      await context.read<WalletProvider>().createWallet(_mnemonic);
      if (!mounted) return;

      final setupPin = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Sécuriser avec un PIN ?'),
              content: const Text(
                'Nous recommandons de protéger votre portefeuille avec un code PIN.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Plus tard'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Configurer le PIN'),
                ),
              ],
            ),
          ) ??
          false;

      if (!mounted) return;
      if (setupPin) {
        await Navigator.pushNamed(context, PinSetupScreen.routeName);
      }
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        HomeScreen.routeName,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un portefeuille')),
      body: _step == _CreateStep.reveal
          ? _buildRevealStep()
          : _buildConfirmStep(),
    );
  }

  Widget _buildRevealStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                     child: Text(
                       'Notez ces 4 mots dans l\'ordre et conservez-les en lieu sûr. '
                       'Ils sont la seule façon de récupérer votre portefeuille. '
                       'Une sauvegarde réduite à 2 mots n\'est pas suffisamment sûre.',
                       style: TextStyle(
                         color: Theme.of(context).colorScheme.onErrorContainer,
                       ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          MnemonicGrid(mnemonic: _mnemonic),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _mnemonic));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Phrase copiée (à stocker en sécurité)')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copier la phrase'),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _backedUp,
            onChanged: (v) => setState(() => _backedUp = v ?? false),
            title: const Text(
                'J\'ai noté ma phrase de récupération en lieu sûr'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _backedUp
                ? () => setState(() => _step = _CreateStep.confirm)
                : null,
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmStep() {
    final words = _mnemonic.trim().split(RegExp(r'\s+'));
    const indices = [2, 0, 3, 1];
    return _WordConfirmationStep(
      words: words,
      indices: indices,
      onConfirmed: _createWallet,
      isLoading: _isCreating,
    );
  }
}

class _WordConfirmationStep extends StatefulWidget {
  const _WordConfirmationStep({
    required this.words,
    required this.indices,
    required this.onConfirmed,
    required this.isLoading,
  });

  final List<String> words;
  final List<int> indices;
  final VoidCallback onConfirmed;
  final bool isLoading;

  @override
  State<_WordConfirmationStep> createState() => _WordConfirmationStepState();
}

class _WordConfirmationStepState extends State<_WordConfirmationStep> {
  late final List<TextEditingController> _controllers;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controllers =
        List.generate(widget.indices.length, (_) => TextEditingController());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _verify() {
    for (var i = 0; i < widget.indices.length; i++) {
      final expected = widget.words[widget.indices[i]];
      final entered = _controllers[i].text.trim().toLowerCase();
      if (entered != expected) {
        setState(() => _error = 'Mot n°${widget.indices[i] + 1} incorrect.');
        return;
      }
    }
    setState(() => _error = null);
    widget.onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Vérification',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Saisissez les mots demandés pour confirmer que vous avez bien noté votre phrase.',
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < widget.indices.length; i++) ...[
            TextFormField(
              controller: _controllers[i],
              decoration: InputDecoration(
                labelText: 'Mot n°${widget.indices[i] + 1}',
                border: const OutlineInputBorder(),
              ),
              autocorrect: false,
              textInputAction: i < widget.indices.length - 1
                  ? TextInputAction.next
                  : TextInputAction.done,
            ),
            const SizedBox(height: 12),
          ],
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
          ],
          ElevatedButton(
            onPressed: widget.isLoading ? null : _verify,
            child: widget.isLoading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Créer le portefeuille'),
          ),
        ],
      ),
    );
  }
}
