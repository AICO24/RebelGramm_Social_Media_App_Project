// ==========================================
// ROLE: Member 1 - User Identity & Profiles
// ==========================================
// This Provider manages the global state of the currently logged-in user.
// By using ChangeNotifier, any screen in the app can listen to this provider.
// When the user logs in and the profile is fetched, notifyListeners() is called,
// updating all UI elements that depend on the user's data (like profile avatars).

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';

class UserProvider with ChangeNotifier {
  UserModel? _user;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  UserModel? get user => _user;

  /// Start listening to the user's document and update the provider when it changes.
  void startListening(String uid) {
    _sub?.cancel();
    _sub = FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen((snap) {
      if (snap.exists) {
        _user = UserModel.fromMap(snap.data() ?? <String, dynamic>{}, snap.id);
      } else {
        _user = null;
      }
      notifyListeners();
    });
  }

  void stopListening() {
    _sub?.cancel();
    _sub = null;
  }

  void setUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}