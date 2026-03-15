import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/story_model.dart';

class StoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Create or update a story for [userId].
  Future<void> createStory(StoryModel story) async {
    // Write fields explicitly and use server timestamp to avoid mixed types
    await _db.collection('stories').doc(story.userId).set({
      'userId': story.userId,
      'username': story.username,
      'imageUrl': story.imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Stream stories for the specified list of [userIds].
  Stream<List<StoryModel>> fetchStories(List<String> userIds) {
    if (userIds.isEmpty) return Stream.value([]);
    // Firestore's whereIn supports up to 10 elements; if we exceed that just
    // listen to all stories and filter on client side instead.
    if (userIds.length <= 10) {
      return _db
          .collection('stories')
          .where('userId', whereIn: userIds)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => StoryModel.fromMap(d.data()))
              .toList());
    } else {
      return _db.collection('stories').orderBy('timestamp', descending: true).snapshots().map((snap) {
        return snap.docs
            .map((d) => StoryModel.fromMap(d.data()))
            .where((s) => userIds.contains(s.userId))
            .toList();
      });
    }
  }
}
