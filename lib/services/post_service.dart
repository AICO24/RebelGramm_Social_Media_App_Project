import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import 'package:uuid/uuid.dart';

class PostService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createPost(PostModel post) async {
    final id = Uuid().v4();
    // ensure timestamp is stored as Firestore Timestamp
    final data = post.toMap();
    data['timestamp'] = Timestamp.fromDate(post.timestamp);
    await _db.collection('posts').doc(id).set(data);
  }

  Stream<List<PostModel>> fetchPosts() {
    return _db.collection('posts')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => PostModel.fromMap(doc.data(), doc.id))
          .toList());
  }

  /// Fetch posts from followed users only
  Stream<List<PostModel>> fetchFollowingPosts(String currentUserId) async* {
    if (currentUserId.isEmpty) {
      // If no user logged in, return all posts
      yield* fetchPosts();
      return;
    }

    // Get list of user IDs that current user follows
    final followingSnapshot = await _db
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .get();
    
    final followingIds = followingSnapshot.docs.map((doc) => doc.id).toList();
    
    // Add current user's ID to see own posts too
    if (!followingIds.contains(currentUserId)) {
      followingIds.add(currentUserId);
    }

    // Firestore limits whereIn to 10 elements; if over that, just stream all
    if (followingIds.length > 10) {
      yield* fetchPosts();
      return;
    }

    try {
      // Fetch posts from followed users
      yield* _db
          .collection('posts')
          .where('userId', whereIn: followingIds)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => PostModel.fromMap(doc.data(), doc.id))
              .toList());
    } catch (e) {
      // if query fails for any reason (type mismatch, etc.) fall back
      yield* fetchPosts();
    }
  }

  Future<void> likePost(String postId, String userId) async {
    final doc = _db.collection('posts').doc(postId);
    final snapshot = await doc.get();
    List likes = snapshot['likes'] ?? [];
    if (likes.contains(userId)) {
      likes.remove(userId);
    } else {
      likes.add(userId);
      // Add notification
      final postDoc = await doc.get();
      final postUserId = postDoc['userId'];
      if (postUserId != userId) {
        await _db.collection('notifications').add({
          'userId': postUserId,
          'type': 'like',
          'message': 'liked your post',
          'fromUserId': userId,
          'postId': postId,
          'timestamp': DateTime.now(),
        });
      }
    }
    await doc.update({'likes': likes});
  }

  Future<void> savePost(String postId, String userId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('saved')
        .doc(postId)
        .set({'savedAt': DateTime.now()});
  }

  Future<void> unsavePost(String postId, String userId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('saved')
        .doc(postId)
        .delete();
  }

  /// Check whether [postId] is saved by [userId].
  Future<bool> isPostSaved(String postId, String userId) async {
    final doc = await _db
        .collection('users')
        .doc(userId)
        .collection('saved')
        .doc(postId)
        .get();
    return doc.exists;
  }

  /// Send a share notification from one user to another for a post.
  Future<void> sharePost(String postId, String fromUserId, String toUserId) async {
    await _db.collection('notifications').add({
      'userId': toUserId,
      'type': 'share',
      'message': 'sent you a post',
      'fromUserId': fromUserId,
      'postId': postId,
      'timestamp': DateTime.now(),
    });
  }

  /// Create a repost entry: a new post with current user as author but marking
  /// it as a repost of an existing one.
  Future<void> repost(PostModel original, String newUserId, String newUsername) async {
    final id = Uuid().v4();
    final data = {
      'userId': newUserId,
      'username': newUsername,
      'caption': original.caption,
      'imageUrl': original.imageUrl,
      'timestamp': Timestamp.fromDate(DateTime.now()),
      'likes': <String>[],
      'repostOf': original.id,
    };
    await _db.collection('posts').doc(id).set(data);
  }


  /// Return posts whose captions contain [query] (caseinsensitive).
  ///
  /// This implementation is intentionally naive; it downloads all posts
  /// then filters on the client.  For a large dataset a proper search/index
  /// solution is required.
  Future<List<PostModel>> searchPosts(String query) async {
    if (query.isEmpty) return [];
    final snapshot = await _db.collection('posts').get();
    final lower = query.toLowerCase();
    return snapshot.docs
        .map((doc) => PostModel.fromMap(doc.data(), doc.id))
        .where((p) => p.caption.toLowerCase().contains(lower))
        .toList();
  }

  /// Delete a post by [postId]. This also removes it from the feed.
  Future<void> deletePost(String postId) async {
    await _db.collection('posts').doc(postId).delete();
  }

  /// Get comment count for a post
  Future<int> getCommentCount(String postId) async {
    final snapshot = await _db
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .get();
    return snapshot.docs.length;
  }
}
