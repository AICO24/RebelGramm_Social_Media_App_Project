import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Future<void> createNotification({
    required String userId,
    required String type,
    required String actorId,
    required String actorName,
    String? postId,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': type, // 'like', 'comment', 'follow'
        'actorId': actorId,
        'actorName': actorName,
        'postId': postId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'message': _getMessageForType(type, actorName),
      });
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  String _getMessageForType(String type, String actorName) {
    if (type == 'like') return '$actorName liked your post';
    if (type == 'comment') return '$actorName commented on your post';
    if (type == 'follow') return '$actorName started following you';
    return '$actorName interacted with you';
  }
}
