import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';

class MessageService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Send a direct message from [senderId] to [receiverId]
  Future<void> sendMessage(String senderId, String receiverId, String message) async {
    // Validate message content
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) return;
    if (trimmedMessage.length > 1000) {
      throw Exception('Message too long (max 1000 characters)');
    }
    
    final id = Uuid().v4();
    await _db.collection('messages').doc(id).set({
      'senderId': senderId,
      'receiverId': receiverId,
      'message': trimmedMessage,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  /// Get a stream of messages between two users
  Stream<List<MessageModel>> getMessages(String userId1, String userId2) {
    return _db
        .collection('messages')
        .where('senderId', whereIn: [userId1, userId2])
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            // Only include messages between these two users
            if ((data['senderId'] == userId1 && data['receiverId'] == userId2) ||
                (data['senderId'] == userId2 && data['receiverId'] == userId1)) {
              return MessageModel.fromMap(data, doc.id);
            }
            return null;
          })
          .where((m) => m != null)
          .cast<MessageModel>()
          .toList();
    });
  }

  /// Get list of conversations for a user
  Stream<List<Map<String, dynamic>>> getConversations(String currentUserId) {
    return _db
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      final conversations = <String, Map<String, dynamic>>{};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final senderId = data['senderId'] as String;
        final receiverId = data['receiverId'] as String;
        
        // Determine the other user in the conversation
        String otherUserId;
        if (senderId == currentUserId) {
          otherUserId = receiverId;
        } else if (receiverId == currentUserId) {
          otherUserId = senderId;
        } else {
          continue; // Skip messages not involving current user
        }
        
        // Only keep the latest message per conversation
        if (!conversations.containsKey(otherUserId)) {
          conversations[otherUserId] = {
            'lastMessage': data['message'] ?? '',
            'timestamp': data['timestamp'] is Timestamp 
                ? (data['timestamp'] as Timestamp).toDate()
                : DateTime.now(),
            'senderId': senderId,
            'isRead': data['isRead'] ?? false,
          };
        }
      }
      
      return conversations.entries.map((e) => {
        'userId': e.key,
        ...e.value,
      }).toList();
    });
  }

  /// Mark messages as read
  Future<void> markAsRead(String messageId) async {
    await _db.collection('messages').doc(messageId).update({'isRead': true});
  }

  /// Get unread message count for a user
  Future<int> getUnreadCount(String userId) async {
    final snapshot = await _db
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    return snapshot.docs.length;
  }
}
