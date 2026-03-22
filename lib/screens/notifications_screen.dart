// ==========================================
// ROLE: Member 6 - Artificial Intelligence & Notifications
// ==========================================
// Acts as the global activity monitor listening to the 'notifications' collection.
// Dynamically parses the interaction 'type' (like, comment, share, follow) 
// to automatically draw the correct visual Icon and intelligently route click events 
// directly to the shared Post or Reel Model.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/user_provider.dart';
import '../models/post_model.dart';
import '../models/reel_model.dart';
import 'post_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<UserProvider>(context).user;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: currentUser == null
          ? Center(
              child: Text(
                'Sign in to see notifications',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: currentUser.id)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Failed to load notifications'),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(snapshot.error.toString(), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            (context as Element).markNeedsBuild();
                          },
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: Color(0xFF0095F6)),
                  );
                }

                final notifications = snapshot.data!.docs;
                if (notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.favorite_border,
                          size: 60,
                          color: Theme.of(context).iconTheme.color?.withOpacity(0.5) ?? Colors.grey.shade400,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No notifications yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text('When someone interacts with your posts, you\'ll see it here', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notif = notifications[index].data() as Map<String, dynamic>;
                    return ListTile(
                      onTap: () async {
                        final type = notif['type'] as String?;
                        if (type == 'like' || type == 'comment' || type == 'share') {
                          final postId = notif['postId'] as String?;
                          if (postId != null) {
                            try {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Looking up item...'), duration: Duration(milliseconds: 600)));
                              
                              final postDoc = await FirebaseFirestore.instance.collection('posts').doc(postId).get();
                              if (postDoc.exists && context.mounted) {
                                final post = PostModel.fromMap(postDoc.data() as Map<String, dynamic>, postDoc.id);
                                Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)));
                                return;
                              }
                              
                              final reelDoc = await FirebaseFirestore.instance.collection('reels').doc(postId).get();
                              if (reelDoc.exists && context.mounted) {
                                final reel = ReelModel.fromMap(reelDoc.data() as Map<String, dynamic>, reelDoc.id);
                                Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: reel)));
                                return;
                              }
                              
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This item no longer exists')));
                              }
                            } catch (e) {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading item: $e')));
                            }
                          }
                        } else if (type == 'follow') {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${notif['actorName'] ?? 'Someone'} has started following you!')));
                        }
                      },
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: Color(0xFF0095F6).withOpacity(0.1),
                        child: Icon(
                          notif['type'] == 'like'
                              ? Icons.favorite
                              : notif['type'] == 'comment'
                                  ? Icons.chat_bubble
                                  : notif['type'] == 'share'
                                      ? Icons.send
                                      : notif['type'] == 'follow'
                                          ? Icons.person_add
                                          : Icons.notifications,
                          color: Color(0xFF0095F6),
                          size: 24,
                        ),
                      ),
                      title: Text(
                        notif['message'] ?? 'New notification',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87,
                            fontSize: 14),
                      ),
                      trailing: Text(
                        _formatTimestamp(
                          (notif['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
                        ),
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
