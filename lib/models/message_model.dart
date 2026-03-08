import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp,
      'isRead': isRead,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
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

    return MessageModel(
      id: id,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      message: map['message'] ?? '',
      timestamp: ts,
      isRead: map['isRead'] ?? false,
    );
  }
}

class ConversationModel {
  final String userId;
  final String username;
  final String profilePic;
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;

  ConversationModel({
    required this.userId,
    required this.username,
    required this.profilePic,
    required this.lastMessage,
    required this.timestamp,
    this.unreadCount = 0,
  });
}
