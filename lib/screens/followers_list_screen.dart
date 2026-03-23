import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'other_user_profile_screen.dart';

class FollowersListScreen extends StatefulWidget {
  final String userId;

  const FollowersListScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _FollowersListScreenState createState() => _FollowersListScreenState();
}

class _FollowersListScreenState extends State<FollowersListScreen> {
  Future<void> _removeFollower(String followerId, String currentUserId) async {
    try {
      await FirebaseFirestore.instance.collection('followers').doc(currentUserId).collection('followers').doc(followerId).delete();
      await FirebaseFirestore.instance.collection('followers').doc(followerId).collection('following').doc(currentUserId).delete();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Follower removed')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to remove: $e')));
    }
  }

  Future<void> _followUser(String targetId, String username, String profilePic, String currentUserId) async {
    try {
      await FirebaseFirestore.instance.collection('followers').doc(currentUserId).collection('following').doc(targetId).set({
        'userId': targetId,
        'username': username,
        'profilePic': profilePic,
        'timestamp': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance.collection('followers').doc(targetId).collection('followers').doc(currentUserId).set({
        'userId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Now following $username!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to follow: $e')));
    }
  }

  Future<void> _unfollowUser(String targetId, String username, String currentUserId) async {
    try {
      await FirebaseFirestore.instance.collection('followers').doc(currentUserId).collection('following').doc(targetId).delete();
      await FirebaseFirestore.instance.collection('followers').doc(targetId).collection('followers').doc(currentUserId).delete();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unfollowed $username')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to unfollow: $e')));
    }
  }
  @override
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<UserProvider>(context, listen: false).user?.id ?? '';
    final isCurrentUser = widget.userId == currentUserId;

    return Scaffold(
      appBar: AppBar(title: Text('Followers'), elevation: 0),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('followers').doc(widget.userId).collection('followers').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: Color(0xFF0095F6)));
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No followers yet", style: TextStyle(color: Colors.grey, fontSize: 16)));
          }

          final followers = snapshot.data!.docs;
          return ListView.builder(
            itemCount: followers.length,
            itemBuilder: (context, index) {
              final data = followers[index].data() as Map<String, dynamic>;
              final targetId = data['userId'] ?? followers[index].id;
              final username = data['username'] ?? 'User';
              final profilePic = data['profilePic'] ?? '';

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(targetId).get(),
                builder: (context, userSnap) {
                  String finalName = username;
                  String finalPic = profilePic;
                  
                  if (userSnap.hasData && userSnap.data!.exists) {
                    final uData = userSnap.data!.data() as Map<String, dynamic>;
                    finalName = uData['username'] ?? username;
                    finalPic = uData['profilePic'] ?? profilePic;
                  }
                  
                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('followers').doc(currentUserId).collection('following').doc(targetId).snapshots(),
                    builder: (context, followSnap) {
                      final isFollowingBack = followSnap.hasData && followSnap.data!.exists;

                      Widget? trailingWidget;
                      if (isCurrentUser) {
                        trailingWidget = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isFollowingBack) ...[
                              ElevatedButton(
                                onPressed: () => _followUser(targetId, finalName, finalPic, currentUserId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0095F6),
                                  elevation: 0,
                                ),
                                child: const Text('Follow Back', style: TextStyle(color: Colors.white)),
                              ),
                              const SizedBox(width: 8),
                            ],
                            ElevatedButton(
                              onPressed: () => _removeFollower(targetId, currentUserId),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).cardColor,
                                side: const BorderSide(color: Color(0xFFDBDBDB)),
                                elevation: 0,
                              ),
                              child: Text('Remove', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                            ),
                          ],
                        );
                      } else if (targetId != currentUserId && currentUserId.isNotEmpty) {
                        trailingWidget = isFollowingBack
                            ? OutlinedButton(
                                onPressed: () => _unfollowUser(targetId, finalName, currentUserId),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  side: const BorderSide(color: Color(0xFFDBDBDB)),
                                  minimumSize: const Size(90, 36),
                                ),
                                child: Text('Following', style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color)),
                              )
                            : ElevatedButton(
                                onPressed: () => _followUser(targetId, finalName, finalPic, currentUserId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0095F6),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  elevation: 0,
                                  minimumSize: const Size(90, 36),
                                ),
                                child: const Text('Follow', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                              );
                      }

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[800],
                          backgroundImage: finalPic.isNotEmpty ? NetworkImage(finalPic) : null,
                          child: finalPic.isEmpty ? Text(finalName.isNotEmpty ? finalName[0].toUpperCase() : '?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null,
                        ),
                        title: Text(finalName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: trailingWidget,
                        onTap: () {
                          if (targetId != currentUserId) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => OtherUserProfileScreen(userId: targetId)));
                          }
                        },
                      );
                    }
                  );
                }
              );
            },
          );
        },
      ),
    );
  }
}
