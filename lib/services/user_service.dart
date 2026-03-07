import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// Simple helper service for looking up users in Firestore.
///
/// Currently only supports a prefix search on the `username` field.  You
/// can extend this later with more advanced indexing or a dedicated search
/// service if the dataset grows.
class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Returns a list of users whose username begins with [query].
  ///
  /// The comparison is case‑sensitive because Firestore queries are, so callers
  /// should convert the string to lower case when storing/searching if they
  /// want case‑insensitive behaviour.
  Future<List<UserModel>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    final lower = query.toLowerCase();
    final snapshot = await _db
        .collection('users')
        .where('usernameLower', isGreaterThanOrEqualTo: lower)
        .where('usernameLower', isLessThanOrEqualTo: lower + '\uf8ff')
        .get();

    return snapshot.docs
        .map((d) => UserModel.fromMap(d.data(), d.id))
        .toList();
  }
}
