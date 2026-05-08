import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Handles Firebase Authentication and the corresponding Firestore profile
/// creation for new user accounts.
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _authOverride = auth,
        _firestoreOverride = firestore;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;

  bool get _isFirebaseReady => Firebase.apps.isNotEmpty;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Creates a new account with [email] and [password] via Firebase Auth,
  /// then initializes a minimal profile in Firestore `users/{uid}`.
  ///
  /// Throws [SignUpException] with a localised message on known errors
  /// (email already in use, weak password, invalid email).
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    if (!_isFirebaseReady) {
      throw SignUpException(
        'Firebase n\'est pas initialisé. Veuillez configurer les variables FIREBASE_*.',
      );
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      await _users.doc(uid).set(<String, dynamic>{
        'uid': uid,
        'email': credential.user?.email ?? email.trim(),
        'authProvider': 'password',
        'emailVerified': credential.user?.emailVerified ?? false,
        'onboardingStep': 'auth_created',
        'walletCreated': false,
        'walletAddress': null,
        'hasBackupConfirmed': false,
        'hasPinEnabled': false,
        'hasBiometricsEnabled': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return credential;
    } on FirebaseAuthException catch (e, st) {
      debugPrint('SignUp FirebaseAuthException [${e.code}]: ${e.message}\n$st');
      switch (e.code) {
        case 'email-already-in-use':
          throw SignUpException(
            'Cette adresse e-mail est déjà utilisée par un autre compte.',
          );
        case 'weak-password':
          throw SignUpException(
            'Le mot de passe est trop court (minimum 6 caractères).',
          );
        case 'invalid-email':
          throw SignUpException('L\'adresse e-mail n\'est pas valide.');
        default:
          throw SignUpException(
            'Erreur lors de l\'inscription\u00a0: ${e.message ?? e.code}',
          );
      }
    } on FirebaseException catch (e, st) {
      debugPrint('SignUp FirebaseException [${e.code}]: ${e.message}\n$st');
      throw SignUpException(
        'Impossible d\'enregistrer le profil\u00a0: ${e.message ?? e.code}',
      );
    } catch (e, st) {
      debugPrint('SignUp unexpected error: $e\n$st');
      throw SignUpException('Une erreur inattendue s\'est produite\u00a0: $e');
    }
  }

  Future<void> markWalletPasswordSet({required String uid}) async {
    if (!_isFirebaseReady) return;
    await _users.doc(uid).set(<String, dynamic>{
      'uid': uid,
      'onboardingStep': 'wallet_password_set',
      'walletCreated': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markWalletReady({
    required String uid,
    required String walletAddress,
    required bool hasBackupConfirmed,
    required bool hasPinEnabled,
    required bool hasBiometricsEnabled,
  }) async {
    if (!_isFirebaseReady) return;
    await _users.doc(uid).set(<String, dynamic>{
      'uid': uid,
      'walletCreated': true,
      'walletAddress': walletAddress,
      'hasBackupConfirmed': hasBackupConfirmed,
      'hasPinEnabled': hasPinEnabled,
      'hasBiometricsEnabled': hasBiometricsEnabled,
      'onboardingStep': 'wallet_ready',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

/// Thrown by [AuthService.signUp] when account creation fails.
///
/// [message] is a user-facing, localised description of the problem.
class SignUpException implements Exception {
  const SignUpException(this.message);

  final String message;

  @override
  String toString() => message;
}
