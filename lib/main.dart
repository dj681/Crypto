import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'providers/account_history_provider.dart';
import 'providers/blockchain_provider.dart';
import 'providers/market_provider.dart';
import 'providers/security_provider.dart';
import 'providers/wallet_provider.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_recharge_history_screen.dart';
import 'screens/history_screen.dart';
import 'screens/gift_card_history_screen.dart';
import 'screens/gift_card_screen.dart';
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
import 'services/firebase_bootstrap.dart';
import 'services/firebase_user_service.dart';
import 'services/market_service.dart';
import 'services/security_service.dart';
import 'services/wallet_service.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

void _runBackgroundInit(Future<void> task, String label) {
  unawaited(
    task.catchError((Object error, StackTrace stack) {
      debugPrint('Background init failed [$label]: $error\n$stack');
    }),
  );
}

Future<T> _measureStartup<T>(String label, Future<T> Function() work) async {
  final sw = Stopwatch()..start();
  try {
    return await work();
  } finally {
    sw.stop();
    debugPrint('Startup timing [$label]: ${sw.elapsedMilliseconds} ms');
  }
}

Future<void> _bootstrapStartup({
  required BlockchainProvider blockchainProvider,
}) async {
  await _measureStartup('firebase_init', () async {
    if (!DefaultFirebaseOptions.isConfigured) {
      debugPrint(
        'Startup bootstrap: Firebase skipped (missing FIREBASE_* dart-define values).',
      );
      return;
    }
    final ok = await initializeFirebase().timeout(const Duration(seconds: 8));
    if (!ok) {
      debugPrint('Startup bootstrap: Firebase disabled due to init failure.');
    }
  });

  await _measureStartup('prefs_rpc_load', () async {
    final prefs = await SharedPreferences.getInstance().timeout(
      const Duration(seconds: 4),
    );
    final savedRpcUrl = prefs.getString('rpc_url');
    if (savedRpcUrl != null && savedRpcUrl.trim().isNotEmpty) {
      blockchainProvider.updateRpcUrl(savedRpcUrl);
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final walletService = WalletService();
  final firebaseUserService = FirebaseUserService(
    enabled: DefaultFirebaseOptions.isConfigured,
  );
  final securityService = SecurityService();
  // Starts with default public RPC URL, then applies persisted user URL
  // asynchronously in _bootstrapStartup().
  final blockchainService = BlockchainService();
  final marketService = MarketService();

  final blockchainProvider = BlockchainProvider(
    blockchainService: blockchainService,
    walletService: walletService,
  );
  final marketProvider = MarketProvider(marketService: marketService);
  _runBackgroundInit(marketProvider.loadState(), 'market_state');

  final accountHistoryProvider = AccountHistoryProvider();
  _runBackgroundInit(accountHistoryProvider.loadState(), 'account_history');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => WalletProvider(
            walletService,
            firebaseUserService: firebaseUserService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SecurityProvider(securityService),
        ),
        ChangeNotifierProvider(
          create: (_) => blockchainProvider,
        ),
        ChangeNotifierProvider.value(value: marketProvider),
        ChangeNotifierProvider.value(value: accountHistoryProvider),
      ],
      child: MyCryptoSafeApp(navigatorKey: _navigatorKey),
    ),
  );

  _runBackgroundInit(
    _bootstrapStartup(blockchainProvider: blockchainProvider),
    'startup_bootstrap',
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
      final wallet = Provider.of<WalletProvider>(ctx, listen: false);
      if (security.isLocked && wallet.hasWallet) {
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
        GiftCardScreen.routeName: (context) => const GiftCardScreen(),
        GiftCardHistoryScreen.routeName: (context) =>
            const GiftCardHistoryScreen(),
        AdminRechargeHistoryScreen.routeName: (context) =>
            const AdminRechargeHistoryScreen(),
        AdminLoginPage.routeName: (context) => const AdminLoginPage(),
      },
    );
  }
}
