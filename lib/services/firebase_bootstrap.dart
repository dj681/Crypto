import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

Future<bool> initializeFirebase() async {
  if (!DefaultFirebaseOptions.isConfigured) {
    debugPrint(
      'Firebase disabled: missing FIREBASE_* dart-define values.',
    );
    return false;
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return true;
  } catch (e, st) {
    debugPrint('Firebase initialization failed: $e\n$st');
    return false;
  }
}
