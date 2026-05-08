import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Handles non-sensitive user profile sync to Firestore.
///
/// Document path: `users/{uid}` where `uid` is the Firebase Auth user ID.
class FirebaseUserService {
  FirebaseUserService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    bool enabled = true,
  })  : _auth = auth,
        _firestore = firestore,
        _enabled = enabled;

  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final bool _enabled;

  FirebaseAuth get _authOrDefault => _auth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestoreOrDefault =>
      _firestore ?? FirebaseFirestore.instance;
  bool get _isFirebaseReady => Firebase.apps.isNotEmpty;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestoreOrDefault.collection('users');

  Future<void> upsertUserProfile({
    required String userId,
    required String address,
    required bool hasPinEnabled,
    required bool hasBiometricsEnabled,
    required bool isAdmin,
    bool hasBackupConfirmed = true,
  }) async {
    if (!_enabled || !_isFirebaseReady) return;

    try {
      await _ensureSignedIn();
      final ownerUid = _authOrDefault.currentUser?.uid;
      if (ownerUid == null || ownerUid.isEmpty) return;

      final docRef = _users.doc(ownerUid);
      final provider = _authOrDefault.currentUser?.providerData.isNotEmpty == true
          ? _authOrDefault.currentUser!.providerData.first.providerId
          : (_authOrDefault.currentUser?.isAnonymous == true
              ? 'anonymous'
              : 'unknown');
      final payload = <String, dynamic>{
        'uid': ownerUid,
        'email': _authOrDefault.currentUser?.email,
        'emailVerified': _authOrDefault.currentUser?.emailVerified ?? false,
        'authProvider': provider,
        'walletUserId': userId,
        'address': address,
        'walletAddress': address,
        'walletCreated': true,
        'onboardingStep': 'wallet_ready',
        'hasBackupConfirmed': hasBackupConfirmed,
        'hasPinEnabled': hasPinEnabled,
        'hasBiometricsEnabled': hasBiometricsEnabled,
        'isAdmin': isAdmin,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestoreOrDefault.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (snapshot.exists) {
          transaction.set(docRef, payload, SetOptions(merge: true));
        } else {
          transaction.set(docRef, {
            ...payload,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } on FirebaseException catch (e, st) {
      debugPrint('Firestore sync failed [${e.code}]: ${e.message}\n$st');
    } catch (e, st) {
      debugPrint('Firestore sync failed: $e\n$st');
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String _) async {
    if (!_enabled || !_isFirebaseReady) return null;

    try {
      await _ensureSignedIn();
      final uid = _authOrDefault.currentUser?.uid;
      if (uid == null || uid.isEmpty) return null;
      final doc = await _users.doc(uid).get();
      return doc.data();
    } catch (e, st) {
      debugPrint('Firestore read failed: $e\n$st');
      return null;
    }
  }

  Future<void> deleteUserProfile(String _) async {
    if (!_enabled || !_isFirebaseReady) return;

    try {
      await _ensureSignedIn();
      final uid = _authOrDefault.currentUser?.uid;
      if (uid == null || uid.isEmpty) return;
      await _users.doc(uid).delete();
    } on FirebaseException catch (e, st) {
      debugPrint('Firestore delete failed [${e.code}]: ${e.message}\n$st');
    } catch (e, st) {
      debugPrint('Firestore delete failed: $e\n$st');
    }
  }

  Future<void> _ensureSignedIn() async {
    if (!_enabled || !_isFirebaseReady || _authOrDefault.currentUser != null) {
      return;
    }
    await _authOrDefault.signInAnonymously();
  }
}
