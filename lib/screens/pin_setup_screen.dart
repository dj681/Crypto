import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/security_provider.dart';
import '../providers/wallet_provider.dart';
import '../widgets/pin_pad.dart';
import 'admin_recharge_history_screen.dart';

/// Allows the user to set, change, or remove their PIN.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  static const String routeName = '/pin-setup';

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

enum _PinStep { enterNew, confirmNew, enterCurrent }

class _PinSetupScreenState extends State<PinSetupScreen> {
  // Incrementing this key forces PinPad to fully rebuild (clearing entered digits).
  int _padResetKey = 0;
  _PinStep _step = _PinStep.enterNew;
  String? _firstPin;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // If the user already has a PIN, ask for the current one first.
    final security = context.read<SecurityProvider>();
    if (security.hasPin) {
      _step = _PinStep.enterCurrent;
    }
  }

  void _resetPad() => setState(() => _padResetKey++);

  void _onPin(String pin) async {
    switch (_step) {
      case _PinStep.enterCurrent:
        final ok = await context.read<SecurityProvider>().unlockWithPin(pin);
        if (ok) {
          setState(() {
            _step = _PinStep.enterNew;
            _errorMessage = null;
          });
        } else {
          setState(() => _errorMessage = 'PIN incorrect');
          _resetPad();
        }
        break;

      case _PinStep.enterNew:
        setState(() {
          _firstPin = pin;
          _step = _PinStep.confirmNew;
          _errorMessage = null;
        });
        _resetPad();
        break;

      case _PinStep.confirmNew:
        if (pin == _firstPin) {
          await context.read<SecurityProvider>().setupPin(pin);
          final walletProvider = context.read<WalletProvider>();
          await walletProvider.setPinEnabled(enabled: true);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN configuré avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          final isAdmin = walletProvider.wallet?.isAdmin == true;
          if (isAdmin) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AdminRechargeHistoryScreen.routeName,
              (route) => false,
            );
          } else {
            Navigator.pop(context);
          }
        } else {
          setState(() {
            _firstPin = null;
            _step = _PinStep.enterNew;
            _errorMessage = 'Les PINs ne correspondent pas. Réessayez.';
          });
          _resetPad();
        }
        break;
    }
  }

  String get _title {
    switch (_step) {
      case _PinStep.enterCurrent:
        return 'Saisissez votre PIN actuel';
      case _PinStep.enterNew:
        return 'Choisissez un nouveau PIN';
      case _PinStep.confirmNew:
        return 'Confirmez votre PIN';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuration du PIN')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 32),
            PinPad(
              key: ValueKey(_padResetKey),
              onCompleted: _onPin,
              errorMessage: _errorMessage,
            ),
          ],
        ),
      ),
    );
  }
}
