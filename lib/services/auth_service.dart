import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<UserModel?> signUp(String email, String password, String username) async {
    final UserCredential cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = UserModel(
      id: cred.user!.uid,
      email: email,
      username: username,
      profilePic: '',
    );
    // also store a lowercase username for case-insensitive search
    final data = user.toMap();
    data['usernameLower'] = username.toLowerCase();
    await _db.collection('users').doc(user.id).set(data);
    return user;
  }

  Future<UserModel?> signIn(String email, String password) async {
    try {
      if (kDebugMode) print('[AuthService] signIn: attempting sign in for $email');
      final UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user?.uid;
      if (kDebugMode) print('[AuthService] signIn: signed in uid=$uid');
      if (uid == null) return null;

      try {
        final doc = await _db.collection('users').doc(uid).get();
        if (!doc.exists) {
          if (kDebugMode) print('[AuthService] signIn: user document not found for uid=$uid — returning minimal UserModel');
          return UserModel(id: uid, email: cred.user?.email ?? '', username: '', profilePic: '');
        }
        if (kDebugMode) print('[AuthService] signIn: loaded user document for uid=$uid');
        return UserModel.fromMap(doc.data()!, uid);
      } on FirebaseException catch (e) {
        // If Firestore denies access (rules), allow login to proceed with a minimal user
        if (kDebugMode) print('[AuthService] Firestore exception while loading user doc: ${e.code} ${e.message}');
        if (e.code == 'permission-denied' || e.message?.contains('permission-denied') == true) {
          if (kDebugMode) print('[AuthService] Permission denied reading user doc; returning minimal UserModel for uid=$uid');
          return UserModel(id: uid, email: cred.user?.email ?? '', username: '', profilePic: '');
        }
        rethrow;
      }
    } on FirebaseAuthException catch (e, st) {
      if (kDebugMode) print('[AuthService] FirebaseAuthException signIn: code=${e.code} message=${e.message}');
      if (kDebugMode) print(st);
      rethrow;
    } catch (e, st) {
      if (kDebugMode) print('[AuthService] signIn unexpected error: $e');
      if (kDebugMode) print(st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}