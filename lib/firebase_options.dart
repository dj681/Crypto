import 'package:firebase_core/firebase_core.dart';

/// Firebase options loaded from build-time dart-defines.
///
/// These values can be generated with `flutterfire configure`, then replaced
/// by the generated file if needed.
class DefaultFirebaseOptions {
  static const FirebaseOptions currentPlatform = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY', defaultValue: ''),
    appId: String.fromEnvironment('FIREBASE_APP_ID', defaultValue: ''),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '',
    ),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: ''),
    authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: ''),
    storageBucket: String.fromEnvironment(
      'FIREBASE_STORAGE_BUCKET',
      defaultValue: '',
    ),
    measurementId: String.fromEnvironment(
      'FIREBASE_MEASUREMENT_ID',
      defaultValue: '',
    ),
  );

  static bool get isConfigured =>
      currentPlatform.apiKey.isNotEmpty &&
      currentPlatform.appId.isNotEmpty &&
      currentPlatform.messagingSenderId.isNotEmpty &&
      currentPlatform.projectId.isNotEmpty;
}
