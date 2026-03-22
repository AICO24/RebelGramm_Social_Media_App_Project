// ==========================================
// ROLE: Member 4 - Reels & Video Architecture
// ==========================================
// Handles reading and writing Video posts to the 'reels' collection in Firestore.
// Similar to PostService, but adapted exclusively for the requirements of vertical video feeds.

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

  Future<void> toggleShareStatus(String reelId, String userId) async {
    final docRef = _db.collection('reels').doc(reelId);
    final shareRef = docRef.collection('shares').doc(userId);

    await _db.runTransaction((tx) async {
      final reelSnap = await tx.get(docRef);
      if (!reelSnap.exists) return;
      final shareSnap = await tx.get(shareRef);

      if (shareSnap.exists) {
        tx.delete(shareRef);
        tx.update(docRef, {'shareCount': FieldValue.increment(-1)});
      } else {
        tx.set(shareRef, {'createdAt': FieldValue.serverTimestamp()});
        tx.update(docRef, {'shareCount': FieldValue.increment(1)});
      }
    });
  }

  Future<bool> isReelShared(String reelId, String userId) async {
    final doc = await _db.collection('reels').doc(reelId).collection('shares').doc(userId).get();
    return doc.exists;
  }

  Future<void> shareReel(String reelId, String fromUserId, String toUserId) async {
    await _db.collection('notifications').add({
      'userId': toUserId,
      'type': 'share',
      'message': 'sent you a reel',
      'fromUserId': fromUserId,
      'postId': reelId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
