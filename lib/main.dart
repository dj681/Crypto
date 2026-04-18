import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/blockchain_provider.dart';
import 'providers/market_provider.dart';
import 'providers/security_provider.dart';
import 'providers/wallet_provider.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/market_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/pin_setup_screen.dart';
import 'screens/receive_screen.dart';
import 'screens/send_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/wallet_create_screen.dart';
import 'screens/wallet_import_screen.dart';
import 'services/blockchain_service.dart';
import 'services/market_service.dart';
import 'services/security_service.dart';
import 'services/wallet_service.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persisted RPC URL (defaults to a public endpoint without API key).
  final prefs = await SharedPreferences.getInstance();
  final savedRpcUrl = prefs.getString('rpc_url');

  final walletService = WalletService();
  final securityService = SecurityService();
  final blockchainService =
      BlockchainService(rpcUrl: savedRpcUrl);
  final marketService = MarketService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => WalletProvider(walletService),
        ),
        ChangeNotifierProvider(
          create: (_) => SecurityProvider(securityService),
        ),
        ChangeNotifierProvider(
          create: (_) => BlockchainProvider(
            blockchainService: blockchainService,
            walletService: walletService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => MarketProvider(marketService: marketService),
        ),
      ],
      child: MyCryptoSafeApp(navigatorKey: _navigatorKey),
    ),
  );
}

class MyCryptoSafeApp extends StatefulWidget {
  const MyCryptoSafeApp({super.key, required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<MyCryptoSafeApp> createState() => _MyCryptoSafeAppState();
}

class _MyCryptoSafeAppState extends State<MyCryptoSafeApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctx = widget.navigatorKey.currentContext;
    if (ctx == null) return;

    final security = Provider.of<SecurityProvider>(ctx, listen: false);

    if (state == AppLifecycleState.paused) {
      security.recordPauseTime();
    } else if (state == AppLifecycleState.resumed) {
      security.checkAndLockIfTimeout();
      if (security.isLocked) {
        widget.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          LockScreen.routeName,
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Crypto Safe',
      navigatorKey: widget.navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: SplashScreen.routeName,
      routes: {
        SplashScreen.routeName: (context) => const SplashScreen(),
        OnboardingScreen.routeName: (context) => const OnboardingScreen(),
        WalletCreateScreen.routeName: (context) => const WalletCreateScreen(),
        WalletImportScreen.routeName: (context) => const WalletImportScreen(),
        HomeScreen.routeName: (context) => const HomeScreen(),
        SendScreen.routeName: (context) => const SendScreen(),
        ReceiveScreen.routeName: (context) => const ReceiveScreen(),
        HistoryScreen.routeName: (context) => const HistoryScreen(),
        MarketScreen.routeName: (context) => const MarketScreen(),
        SettingsScreen.routeName: (context) => const SettingsScreen(),
        PinSetupScreen.routeName: (context) => const PinSetupScreen(),
        LockScreen.routeName: (context) => const LockScreen(),
      },
    );
  }
}
