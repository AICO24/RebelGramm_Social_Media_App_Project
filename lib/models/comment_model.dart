import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String comment;
  final DateTime timestamp;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.comment,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'comment': comment,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory CommentModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime ts;
    final raw = map['timestamp'];
    if (raw is Timestamp) {
      ts = raw.toDate();
    } else if (raw is DateTime) {
      ts = raw;
    } else if (raw is String) {
      ts = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      ts = DateTime.now();
    }

    return CommentModel(
      id: id,
      postId: map['postId'] ?? '',
      userId: map['userId'] ?? '',
      comment: map['comment'] ?? '',
      timestamp: ts,
    );
  }
}
