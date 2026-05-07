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
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  bool get _isFirebaseReady => Firebase.apps.isNotEmpty;

  /// Creates a new account with [email] and [password] via Firebase Auth,
  /// then immediately stores [pin] and [recoveryWords] alongside the user's
  /// UID in the Firestore `Users` collection.
  ///
  /// Throws [SignUpException] with a localised message on known errors
  /// (email already in use, weak password, invalid email).
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String pin,
    required String recoveryWords,
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

      await _firestore.collection('Users').doc(uid).set(<String, dynamic>{
        'id': uid,
        'pin': pin,
        'recoverywords': recoveryWords,
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
