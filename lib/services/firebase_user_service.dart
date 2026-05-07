import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Handles non-sensitive user profile sync to Firestore.
///
/// Document path: `users/{userId}` where `userId` comes from WalletService.
class FirebaseUserService {
  FirebaseUserService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    bool enabled = true,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _enabled = enabled;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final bool _enabled;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<void> upsertUserProfile({
    required String userId,
    required String address,
    required bool hasPinEnabled,
    required bool hasBiometricsEnabled,
    required bool isAdmin,
  }) async {
    if (!_enabled) return;

    try {
      await _ensureSignedIn();
      final ownerUid = _auth.currentUser?.uid;
      if (ownerUid == null || ownerUid.isEmpty) return;

      final docRef = _users.doc(userId);
      final existing = await docRef.get();

      final payload = <String, dynamic>{
        'userId': userId,
        'address': address,
        'hasPinEnabled': hasPinEnabled,
        'hasBiometricsEnabled': hasBiometricsEnabled,
        'isAdmin': isAdmin,
        'ownerUid': ownerUid,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (existing.exists) {
        await docRef.set(payload, SetOptions(merge: true));
      } else {
        await docRef.set({
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseException catch (e, st) {
      debugPrint('Firestore sync failed [${e.code}]: ${e.message}\n$st');
    } catch (e, st) {
      debugPrint('Firestore sync failed: $e\n$st');
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    if (!_enabled) return null;

    try {
      await _ensureSignedIn();
      final doc = await _users.doc(userId).get();
      return doc.data();
    } catch (e, st) {
      debugPrint('Firestore read failed: $e\n$st');
      return null;
    }
  }

  Future<void> deleteUserProfile(String userId) async {
    if (!_enabled) return;

    try {
      await _ensureSignedIn();
      await _users.doc(userId).delete();
    } on FirebaseException catch (e, st) {
      debugPrint('Firestore delete failed [${e.code}]: ${e.message}\n$st');
    } catch (e, st) {
      debugPrint('Firestore delete failed: $e\n$st');
    }
  }

  Future<void> _ensureSignedIn() async {
    if (!_enabled || _auth.currentUser != null) return;
    await _auth.signInAnonymously();
  }
}
