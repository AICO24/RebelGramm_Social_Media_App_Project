import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'profile_screen.dart'; // Just in case, though usually we tap to open generic profile
import 'other_user_profile_screen.dart';

class FollowingListScreen extends StatefulWidget {
  final String userId;

  const FollowingListScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _FollowingListScreenState createState() => _FollowingListScreenState();
}

class _FollowingListScreenState extends State<FollowingListScreen> {
  Future<void> _unfollowUser(String targetId, String username, String currentUserId) async {
    try {
      await FirebaseFirestore.instance.collection('followers').doc(currentUserId).collection('following').doc(targetId).delete();
      await FirebaseFirestore.instance.collection('followers').doc(targetId).collection('followers').doc(currentUserId).delete();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unfollowed $username')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to unfollow: $e')));
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

  @override
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<UserProvider>(context, listen: false).user?.id ?? '';
    final isCurrentUser = widget.userId == currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text('Following'),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('followers').doc(widget.userId).collection('following').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: Color(0xFF0095F6)));
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("Start following people to see them here", style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          final following = snapshot.data!.docs;
          return ListView.builder(
            itemCount: following.length,
            itemBuilder: (context, index) {
              final data = following[index].data() as Map<String, dynamic>;
              final targetId = data['userId'] ?? following[index].id;
              final username = data['username'] ?? 'User';
              final profilePic = data['profilePic'] ?? '';

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('followers').doc(currentUserId).collection('following').doc(targetId).snapshots(),
                builder: (context, followSnap) {
                  final isFollowingBack = followSnap.hasData && followSnap.data!.exists;

                  Widget? trailingWidget;
                  if (isCurrentUser) {
                    trailingWidget = OutlinedButton(
                      onPressed: () => _unfollowUser(targetId, username, currentUserId),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        side: const BorderSide(color: Color(0xFFDBDBDB)),
                        minimumSize: const Size(90, 36),
                      ),
                      child: Text('Following', style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color)),
                    );
                  } else if (targetId != currentUserId && currentUserId.isNotEmpty) {
                    trailingWidget = isFollowingBack
                        ? OutlinedButton(
                            onPressed: () => _unfollowUser(targetId, username, currentUserId),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              side: const BorderSide(color: Color(0xFFDBDBDB)),
                              minimumSize: const Size(90, 36),
                            ),
                            child: Text('Following', style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color)),
                          )
                        : ElevatedButton(
                            onPressed: () => _followUser(targetId, username, profilePic, currentUserId),
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
                      backgroundImage: profilePic.isNotEmpty ? NetworkImage(profilePic) : null,
                      child: profilePic.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                    ),
                    title: Text(username, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: trailingWidget,
                    onTap: () {
                      if (targetId != currentUserId) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => OtherUserProfileScreen(userId: targetId)));
                      }
                    },
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
