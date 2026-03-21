import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

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
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[800],
                      backgroundImage: finalPic.isNotEmpty ? NetworkImage(finalPic) : null,
                      child: finalPic.isEmpty ? Text(finalName.isNotEmpty ? finalName[0].toUpperCase() : '?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null,
                    ),
                    title: Text(finalName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: isCurrentUser
                      ? ElevatedButton(
                          onPressed: () => _removeFollower(targetId, currentUserId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).cardColor,
                            side: const BorderSide(color: Color(0xFFDBDBDB)),
                            elevation: 0,
                          ),
                          child: Text('Remove', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                        )
                      : null,
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
