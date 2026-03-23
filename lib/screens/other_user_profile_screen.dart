import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/user_provider.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import 'post_detail_screen.dart';
import 'followers_list_screen.dart';
import 'following_list_screen.dart';
import 'inbox_screen.dart';

class OtherUserProfileScreen extends StatefulWidget {
  final String userId;

  const OtherUserProfileScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  _OtherUserProfileScreenState createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen> {
  final PostService _postService = PostService();
  UserModel? _targetUser;
  bool _isLoadingUser = true;

  int _followersCount = 0;
  int _followingCount = 0;
  int _postsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final currentUser = Provider.of<UserProvider>(context, listen: false).user;
    if (currentUser == null) return;

    try {
      // 1. Fetch Target User Data
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      if (userDoc.exists) {
        _targetUser = UserModel.fromMap(userDoc.data()!, userDoc.id);
      }

      // 2. Fetch Stats
      final followersSnap = await FirebaseFirestore.instance.collection('followers').doc(widget.userId).collection('followers').get();
      final followingSnap = await FirebaseFirestore.instance.collection('followers').doc(widget.userId).collection('following').get();
      final postsSnap = await FirebaseFirestore.instance.collection('posts').where('userId', isEqualTo: widget.userId).get();

      if (mounted) {
        setState(() {
          _followersCount = followersSnap.docs.length;
          _followingCount = followingSnap.docs.length;
          _postsCount = postsSnap.docs.length;
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUser = false);
      }
    }
  }

  Future<void> _toggleFollow(bool isFollowingBack) async {
    final currentUser = Provider.of<UserProvider>(context, listen: false).user;
    if (currentUser == null || _targetUser == null) return;

    try {
      if (isFollowingBack) {
        // Unfollow
        await FirebaseFirestore.instance.collection('followers').doc(currentUser.id).collection('following').doc(_targetUser!.id).delete();
        await FirebaseFirestore.instance.collection('followers').doc(_targetUser!.id).collection('followers').doc(currentUser.id).delete();
      } else {
        // Follow
        await FirebaseFirestore.instance.collection('followers').doc(currentUser.id).collection('following').doc(_targetUser!.id).set({
          'userId': _targetUser!.id,
          'username': _targetUser!.username,
          'profilePic': _targetUser!.profilePic,
          'timestamp': FieldValue.serverTimestamp(),
        });
        await FirebaseFirestore.instance.collection('followers').doc(_targetUser!.id).collection('followers').doc(currentUser.id).set({
          'userId': currentUser.id,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      _loadData(); // refresh counts
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update follow status: $e')));
    }
  }

  Widget _buildStatColumn(String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildPostsGrid() {
    return StreamBuilder<List<PostModel>>(
      stream: _postService.fetchPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator(color: Color(0xFF0095F6))));
        }

        final posts = snapshot.data?.where((p) => p.userId == widget.userId).toList() ?? [];

        if (posts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined, size: 60, color: Colors.grey[500]),
                  const SizedBox(height: 16),
                  Text('No posts yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[400])),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: post))),
              child: CachedNetworkImage(
                imageUrl: post.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.grey[800]),
                errorWidget: (context, url, error) => Container(color: Colors.grey[800], child: Icon(Icons.broken_image, color: Colors.grey[500])),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<UserProvider>(context).user?.id ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: _isLoadingUser
            ? const SizedBox.shrink()
            : Text(_targetUser?.username ?? 'User', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 22)),
        centerTitle: false,
        iconTheme: Theme.of(context).iconTheme,
      ),
      body: _isLoadingUser
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0095F6)))
          : _targetUser == null
              ? const Center(child: Text('User not found'))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.grey.shade800,
                                  backgroundImage: _targetUser!.profilePic.isNotEmpty ? NetworkImage(_targetUser!.profilePic) : null,
                                  child: _targetUser!.profilePic.isEmpty ? const Icon(Icons.person, size: 40, color: Colors.white) : null,
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildStatColumn('Posts', _postsCount.toString(), () {}),
                                      _buildStatColumn('Followers', _followersCount.toString(), () {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => FollowersListScreen(userId: _targetUser!.id)));
                                      }),
                                      _buildStatColumn('Following', _followingCount.toString(), () {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => FollowingListScreen(userId: _targetUser!.id)));
                                      })
                                    ]
                                  )
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(_targetUser!.username, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            if (_targetUser!.email.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(_targetUser!.email, style: const TextStyle(fontSize: 14)),
                            ],
                            const SizedBox(height: 16),
                            
                            StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance.collection('followers').doc(currentUserId).collection('following').doc(_targetUser!.id).snapshots(),
                              builder: (context, followSnap) {
                                final isFollowing = followSnap.hasData && followSnap.data!.exists;

                                return Row(
                                  children: [
                                    Expanded(
                                      child: isFollowing
                                          ? OutlinedButton(
                                              onPressed: () => _toggleFollow(true),
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                side: BorderSide(color: Theme.of(context).dividerColor),
                                                backgroundColor: Theme.of(context).cardColor,
                                              ),
                                              child: Text('Following', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color)),
                                            )
                                          : ElevatedButton(
                                              onPressed: () => _toggleFollow(false),
                                              style: ElevatedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                backgroundColor: const Color(0xFF0095F6),
                                                elevation: 0,
                                              ),
                                              child: const Text('Follow', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white)),
                                            ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ChatScreen(
                                                currentUserId: currentUserId,
                                                otherUserId: _targetUser!.id,
                                              ),
                                            ),
                                          );
                                        },
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          side: BorderSide(color: Theme.of(context).dividerColor),
                                          backgroundColor: Theme.of(context).cardColor,
                                        ),
                                        child: Text('Message', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color)),
                                      ),
                                    ),
                                  ],
                                );
                              }
                            ),
                          ],
                        ),
                      ),
                      
                      const Divider(height: 1, color: Color(0xFF2C2C2C)),
                      
                      // Tab Indicator
                      Container(
                        color: const Color(0xFF1E1E1E),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                child: const Icon(Icons.grid_on, color: Colors.white, size: 26),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const Divider(height: 1, color: Color(0xFF2C2C2C)),
                      
                      _buildPostsGrid(),
                    ],
                  ),
                ),
    );
  }
}
