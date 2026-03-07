import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    final UserCredential cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final doc = await _db.collection('users').doc(cred.user!.uid).get();
    return UserModel.fromMap(doc.data()!, cred.user!.uid);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}