import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String userId;
  final String username; // human-readable name stored with post
  final String caption;
  final String imageUrl;
  final DateTime timestamp;
  final List<String> likes;

  PostModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.caption,
    required this.imageUrl,
    required this.timestamp,
    required this.likes,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'caption': caption,
      'imageUrl': imageUrl,
      // store a proper Firestore Timestamp rather than string so queries work
      'timestamp': timestamp,
      'likes': likes,
    };
  }

  factory PostModel.fromMap(Map<String, dynamic> map, String id) {
    // timestamp may be stored as a Timestamp or a string; handle both
    DateTime ts;
    final rawTs = map['timestamp'];
    if (rawTs is DateTime) {
      ts = rawTs;
    } else if (rawTs is Timestamp) {
      ts = rawTs.toDate();
    } else if (rawTs is String) {
      ts = DateTime.tryParse(rawTs) ?? DateTime.now();
    } else {
      ts = DateTime.now();
    }

    return PostModel(
      id: id,
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      caption: map['caption'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      timestamp: ts,
      likes: List<String>.from(map['likes'] ?? []),
    );
  }
}
