import 'package:cloud_firestore/cloud_firestore.dart';

class StoryModel {
  final String userId;
  final String username;
  final String imageUrl;
  final DateTime timestamp;

  StoryModel({
    required this.userId,
    required this.username,
    required this.imageUrl,
    required this.timestamp,
  });

  factory StoryModel.fromMap(Map<String, dynamic> map) {
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

    return StoryModel(
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      timestamp: ts,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'imageUrl': imageUrl,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
