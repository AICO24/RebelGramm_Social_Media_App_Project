import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reel_model.dart';
import 'package:uuid/uuid.dart';

class ReelService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createReel(ReelModel reel) async {
    final id = Uuid().v4();
    final data = reel.toMap();
    data['timestamp'] = FieldValue.serverTimestamp();
    await _db.collection('reels').doc(id).set(data);
  }

  Stream<List<ReelModel>> fetchReels() {
    return _db.collection('reels')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => ReelModel.fromMap(doc.data(), doc.id))
        .toList());
  }

  Future<QuerySnapshot> fetchReelsPageSnapshot({DocumentSnapshot? startAfter, int pageSize = 5}) async {
    Query q = _db.collection('reels').orderBy('timestamp', descending: true).limit(pageSize);
    if (startAfter != null) q = q.startAfterDocument(startAfter);
    return await q.get();
  }

  Future<void> likeReel(String reelId, String userId) async {
    final docRef = _db.collection('reels').doc(reelId);
    final doc = await docRef.get();
    if (!doc.exists) throw Exception('Reel does not exist');

    List<dynamic> likes = doc.data()?['likes'] ?? [];
    if (likes.contains(userId)) {
      likes.remove(userId);
    } else {
      likes.add(userId);
    }
    
    await docRef.update({'likes': likes});
  }
}
