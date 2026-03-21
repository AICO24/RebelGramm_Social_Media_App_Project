import 'package:cloud_firestore/cloud_firestore.dart';

class ReelModel {
  final String id;
  final String userId;
  final String username;
  final String caption;
  final String videoUrl;
  final String musicArtist;
  final String musicTitle;
  final String duration;
  final DateTime timestamp;
  final List<String> likes;

  ReelModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.caption,
    required this.videoUrl,
    this.musicArtist = 'Original Audio',
    this.musicTitle = 'RebelGram',
    this.duration = '0:15',
    required this.timestamp,
    required this.likes,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'caption': caption,
      'videoUrl': videoUrl,
      'musicArtist': musicArtist,
      'musicTitle': musicTitle,
      'duration': duration,
      'timestamp': timestamp,
      'likes': likes,
    };
  }

  factory ReelModel.fromMap(Map<String, dynamic> map, String id) {
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

    return ReelModel(
      id: id,
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      caption: map['caption'] ?? '',
      videoUrl: map['videoUrl'] ?? '',
      musicArtist: map['musicArtist'] ?? 'Original Audio',
      musicTitle: map['musicTitle'] ?? 'User Audio',
      duration: map['duration'] ?? '0:15',
      timestamp: ts,
      likes: List<String>.from(map['likes'] ?? []),
    );
  }
}
