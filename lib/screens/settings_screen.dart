import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/blockchain_provider.dart';
import '../providers/security_provider.dart';
import '../providers/wallet_provider.dart';
import 'onboarding_screen.dart';
import 'pin_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const String routeName = '/settings';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _rpcController;
  bool _rpcEditing = false;

  @override
  void initState() {
    super.initState();
    _rpcController = TextEditingController(
      text: context.read<BlockchainProvider>().rpcUrl,
    );
  }

  @override
  void dispose() {
    _rpcController.dispose();
    super.dispose();
  }

  Future<void> _saveRpcUrl() async {
    final url = _rpcController.text.trim();
    if (url.isNotEmpty) {
      context.read<BlockchainProvider>().updateRpcUrl(url);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rpc_url', url);
      setState(() => _rpcEditing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL RPC mise à jour')),
      );
    }
  }

  Future<void> _confirmClearWallet() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Supprimer le portefeuille'),
            content: const Text(
              'Cette action supprime définitivement les données du portefeuille de cet appareil. '
              "Assurez-vous d'avoir sauvegardé votre phrase de récupération.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed && mounted) {
      await context.read<WalletProvider>().clearWallet();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        OnboardingScreen.routeName,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final security = context.watch<SecurityProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        children: [
          // ── Security section ──────────────────────────────────────────
          _SectionHeader(title: 'Sécurité'),
          ListTile(
            leading: const Icon(Icons.lock_outlined),
            title: const Text('Code PIN'),
            subtitle: Text(security.hasPin ? 'Activé' : 'Désactivé'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, PinSetupScreen.routeName);
            },
          ),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('Biométrie'),
            subtitle: Text(
              security.biometricsAvailable
                  ? 'Disponible sur cet appareil'
                  : 'Non disponible sur cet appareil',
            ),
            trailing: Switch(
              value: context.watch<WalletProvider>().wallet?.hasBiometricsEnabled ?? false,
              onChanged: security.biometricsAvailable
                  ? (v) => context
                      .read<WalletProvider>()
                      .setBiometricsEnabled(enabled: v)
                  : null,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.lock_clock_outlined),
            title: const Text('Verrouiller maintenant'),
            onTap: security.hasPin
                ? () {
                    context.read<SecurityProvider>().lock();
                    Navigator.pop(context);
                  }
                : null,
            enabled: security.hasPin,
          ),
          const Divider(),

          // ── Network section ───────────────────────────────────────────
          _SectionHeader(title: 'Réseau'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _rpcController,
                    enabled: _rpcEditing,
                    decoration: const InputDecoration(
                      labelText: 'URL du nœud RPC',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _rpcEditing
                    ? IconButton(
                        onPressed: _saveRpcUrl,
                        icon: const Icon(Icons.check),
                        tooltip: 'Enregistrer',
                      )
                    : IconButton(
                        onPressed: () => setState(() => _rpcEditing = true),
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Modifier',
                      ),
              ],
            ),
          ),
          const Divider(),

          // ── Danger zone ────────────────────────────────────────────────
          _SectionHeader(title: 'Zone de danger', color: theme.colorScheme.error),
          ListTile(
            leading: Icon(Icons.delete_forever, color: theme.colorScheme.error),
            title: Text(
              'Supprimer le portefeuille',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: const Text('Supprime toutes les données locales'),
            onTap: _confirmClearWallet,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.color});

  final String title;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color ?? Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
