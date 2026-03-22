// ==========================================
// ROLE: Member 1 - User Identity & Profiles
// ==========================================
// This screen displays a user's portfolio, including their grid of posts, 
// followers, and following counts. 
// It also contains logic for:
// - Following/Unfollowing algorithms (updating follower collections)
// - Fetching all posts authored by the specific user ID.
// - Editing the profile (uploading new avatars).

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../providers/user_provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../services/storage_service.dart';
import '../screens/login_screen.dart';
import '../screens/add_post_screen.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import 'package:share_plus/share_plus.dart';
import '../screens/user_posts_grid_screen.dart';
import '../screens/followers_list_screen.dart';
import '../screens/following_list_screen.dart';
import '../widgets/friend_suggestion_card.dart';
import '../screens/post_detail_screen.dart';
import '../screens/discover_people_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final PostService _postService = PostService();
  final ImagePicker _picker = ImagePicker();
  File? _selectedProfileImage;
  int _followersCount = 0;
  int _followingCount = 0;
  int _postsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) return;
    try {
      // Load followers count
      final followersSnap = await FirebaseFirestore.instance
          .collection('followers')
          .doc(user.id)
          .collection('followers')
          .get();

      // Load following count
      final followingSnap = await FirebaseFirestore.instance
          .collection('followers')
          .doc(user.id)
          .collection('following')
          .get();

      // Load posts count
      final postsSnap = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: user.id)
          .get();

      if (mounted) {
        setState(() {
          _followersCount = followersSnap.docs.length;
          _followingCount = followingSnap.docs.length;
          _postsCount = postsSnap.docs.length;
        });
      }
    } on FirebaseException catch (e) {
      // Permission denied or other Firestore errors — fail gracefully
      if (kDebugMode) print('[ProfileScreen] Failed to load stats: ${e.code} ${e.message}');
      return;
    } catch (e) {
      if (kDebugMode) print('[ProfileScreen] Unexpected error loading stats: $e');
      return;
    }
  }

  void _showEditProfileDialog(BuildContext context) {
    final user = Provider.of<UserProvider>(context, listen: false).user!;
    final usernameController = TextEditingController(text: user.username);
    String currentProfilePic = user.profilePic; // Store current profile pic URL

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[700],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text('Edit Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                      SizedBox(height: 24),
                      // Profile Image with edit button
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[800],
                              backgroundImage: _selectedProfileImage != null
                                  ? FileImage(_selectedProfileImage!)
                                  : (currentProfilePic.isNotEmpty ? NetworkImage(currentProfilePic) : null),
                              child: (_selectedProfileImage == null && currentProfilePic.isEmpty)
                                  ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () async {
                                  final source = await showModalBottomSheet<ImageSource>(
                                    context: context,
                                    backgroundColor: Theme.of(context).cardColor,
                                    builder: (ctx) => SafeArea(
                                      child: Wrap(children: [
                                        ListTile(
                                          leading: Icon(Icons.photo_library, color: Colors.white),
                                          title: Text('Choose from gallery', style: TextStyle(color: Colors.white)),
                                          onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                                        ),
                                        ListTile(
                                          leading: Icon(Icons.camera_alt, color: Colors.white),
                                          title: Text('Take a photo', style: TextStyle(color: Colors.white)),
                                          onTap: () => Navigator.pop(ctx, ImageSource.camera),
                                        ),
                                      ]),
                                    ),
                                  );
                                  if (source != null) {
                                    final picked = await _picker.pickImage(source: source, maxWidth: 500, maxHeight: 500);
                                    if (picked != null) {
                                      setModalState(() {
                                        _selectedProfileImage = File(picked.path);
                                      });
                                    }
                                  }
                                },
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Color(0xFF0095F6),
                                  child: Icon(Icons.camera_alt, size: 18, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(8)),
                        child: TextField(
                          controller: usernameController,
                          decoration: InputDecoration(
                            hintText: 'Username',
                            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            prefixIcon: Icon(Icons.alternate_email, color: Colors.grey[400], size: 20),
                          ),
                          style: TextStyle(fontSize: 14, color: Colors.white),
                        ),
                      ),
                      SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              // If user selected an image, upload it first
                              if (_selectedProfileImage != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Uploading image...')),
                                );
                                final profilePicUrl = await StorageService().uploadPostImage(_selectedProfileImage!);
                                
                                await FirebaseFirestore.instance.collection('users').doc(user.id).update({
                                  'profilePic': profilePicUrl,
                                  'username': usernameController.text.trim(),
                                });
                                final updatedUser = user.copyWith(
                                  profilePic: profilePicUrl,
                                  username: usernameController.text.trim(),
                                );
                                Provider.of<UserProvider>(context, listen: false).setUser(updatedUser);
                              } else {
                                // No new image selected, just update username
                                await FirebaseFirestore.instance.collection('users').doc(user.id).update({
                                  'username': usernameController.text.trim(),
                                });
                                final updatedUser = user.copyWith(
                                  username: usernameController.text.trim(),
                                );
                                Provider.of<UserProvider>(context, listen: false).setUser(updatedUser);
                              }
                              
                              if (!mounted) return;
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile updated!')));
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF0095F6),
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: Text('Save', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white)),
                        ),
                      ),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user!;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(user.username, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22)),
        centerTitle: false,
        iconTheme: Theme.of(context).iconTheme,
        actions: [
          IconButton(icon: Icon(Icons.add_box_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddPostScreen()))),
          IconButton(icon: Icon(Icons.menu), onPressed: () => _showLogoutMenu(context)),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: user.profilePic.isNotEmpty ? NetworkImage(user.profilePic) : null,
                      child: user.profilePic.isEmpty ? Icon(Icons.person, size: 40, color: Colors.grey.shade400) : null,
                    ),
                    SizedBox(width: 24),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatColumn('Posts', _postsCount.toString(), () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => UserPostsGridScreen(userId: user.id)));
                          }),
                          _buildStatColumn('Followers', _followersCount.toString(), () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => FollowersListScreen(userId: user.id)));
                          }),
                          _buildStatColumn('Following', _followingCount.toString(), () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => FollowingListScreen(userId: user.id)));
                          })
                        ]
                      )
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(user.username, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (user.email.isNotEmpty) SizedBox(height: 2),
                if (user.email.isNotEmpty) Text(user.email, style: TextStyle(fontSize: 14)),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showEditProfileDialog(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(color: Theme.of(context).dividerColor),
                          backgroundColor: Theme.of(context).cardColor,
                        ),
                        child: Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color)),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          final String profileUrl = "https://rebelgram.com/user/${user.username}";
                          Share.share('Check out ${user.username} on RebelGram!\n$profileUrl');
                        },
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(color: Theme.of(context).dividerColor),
                          backgroundColor: Theme.of(context).cardColor,
                        ),
                        child: Text('Share profile', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildDiscoverPeopleCarousel(user),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          // Tab bar for Posts, Saved, Suggested
          Container(
            color: Color(0xFF1E1E1E),
            child: Row(
              children: [
                Expanded(child: _buildTab('Posts', Icons.grid_on, 0)),
                Expanded(child: _buildTab('Saved', Icons.bookmark_border, 1)),
                Expanded(child: _buildTab('Suggested', Icons.person_add_outlined, 2)),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[800]),
          _buildTabContent(user),
        ],
      ),
      ),
    );
  }

  int _selectedTab = 0;

  Widget _buildTab(String label, IconData icon, int index) {
    final isSelected = _selectedTab == index;
    final themeIconColor = Theme.of(context).iconTheme.color;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? (themeIconColor ?? Colors.black) : Colors.transparent,
              width: 1.5,
            ),
          ),
        ),
        child: Icon(
          icon,
          color: isSelected ? themeIconColor : Colors.grey,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildTabContent(dynamic user) {
    switch (_selectedTab) {
      case 0:
        return _buildPostsTab(user);
      case 1:
        return _buildSavedTab(user);
      case 2:
        return _buildSuggestedTab(user);
      default:
        return _buildPostsTab(user);
    }
  }

  Widget _buildPostsTab(dynamic user) {
    return StreamBuilder<List<PostModel>>(
      stream: _postService.fetchPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Color(0xFF0095F6)));
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error loading posts', style: TextStyle(color: Colors.grey[400])));
        }
        
        final posts = snapshot.data?.where((p) => p.userId == user.id).toList() ?? [];
            
        if (posts.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt_outlined, size: 60, color: Colors.grey[500]), SizedBox(height: 16), Text('No posts yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[400])), SizedBox(height: 8), Text('Share your first photo!', style: TextStyle(fontSize: 14, color: Colors.grey[500]))]));
        }
        
        return GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.all(2),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: post))),
              child: CachedNetworkImage(imageUrl: post.imageUrl, fit: BoxFit.cover, placeholder: (context, url) => Container(color: Colors.grey[800]), errorWidget: (context, url, error) => Container(color: Colors.grey[800], child: Icon(Icons.broken_image, color: Colors.grey[500]))),
            );
          },
        );
      },
    );
  }

  Widget _buildSavedTab(dynamic user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .collection('saved')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Color(0xFF0095F6)));
        }
        
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(child: Text('No saved posts', style: TextStyle(color: Colors.grey[400])));
        }
        
        final savedDocs = snapshot.data!.docs;
        
        if (savedDocs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.bookmark_border, size: 60, color: Colors.grey[500]), SizedBox(height: 16), Text('No saved posts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[400])), SizedBox(height: 8), Text('Save posts to see them here', style: TextStyle(fontSize: 14, color: Colors.grey[500]))]));
        }
        
        return FutureBuilder<List<PostModel>>(
          future: _getSavedPosts(savedDocs.map((d) => d.id).toList()),
          builder: (context, postsSnapshot) {
            if (postsSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: Color(0xFF0095F6)));
            }
            
            final posts = postsSnapshot.data ?? [];
            
            if (posts.isEmpty) {
              return Center(child: Text('No saved posts', style: TextStyle(color: Colors.grey[400])));
            }
            
            return GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              padding: EdgeInsets.all(2),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return CachedNetworkImage(imageUrl: post.imageUrl, fit: BoxFit.cover, placeholder: (context, url) => Container(color: Colors.grey[800]), errorWidget: (context, url, error) => Container(color: Colors.grey[800], child: Icon(Icons.broken_image, color: Colors.grey[500])));
              },
            );
          },
        );
      },
    );
  }

  Future<List<PostModel>> _getSavedPosts(List<String> postIds) async {
    if (postIds.isEmpty) return [];
    
    final posts = <PostModel>[];
    for (final postId in postIds) {
      final doc = await FirebaseFirestore.instance.collection('posts').doc(postId).get();
      if (doc.exists) {
        posts.add(PostModel.fromMap(doc.data()!, doc.id));
      }
    }
    return posts;
  }

  Widget _buildSuggestedTab(dynamic user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Color(0xFF0095F6)));
        }
        
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(child: Text('No suggestions', style: TextStyle(color: Colors.grey[400])));
        }
        
        final allUsers = snapshot.data!.docs
            .map((d) => UserModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .where((u) => u.id != user!.id)
            .toList();
        
        if (allUsers.isEmpty) {
          return Center(child: Text('No suggestions', style: TextStyle(color: Colors.grey[400])));
        }
        
        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.all(8),
          itemCount: allUsers.length,
          itemBuilder: (context, index) {
            final suggestedUser = allUsers[index];
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('followers')
                  .doc(user.id)
                  .collection('following')
                  .doc(suggestedUser.id)
                  .get(),
              builder: (context, followSnap) {
                final isFollowing = followSnap.data?.exists ?? false;
                
                return Card(
                  color: Color(0xFF1E1E1E),
                  margin: EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.grey[700],
                      backgroundImage: suggestedUser.profilePic.isNotEmpty 
                          ? NetworkImage(suggestedUser.profilePic) 
                          : null,
                      child: suggestedUser.profilePic.isEmpty
                          ? Text(
                              suggestedUser.username.isNotEmpty 
                                  ? suggestedUser.username[0].toUpperCase() 
                                  : '?',
                              style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w600),
                            )
                          : null,
                    ),
                    title: Text(
                      suggestedUser.username,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      suggestedUser.email,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    trailing: isFollowing
                        ? OutlinedButton(
                            onPressed: () => _unfollowUser(suggestedUser.id, user),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              side: BorderSide(color: Colors.grey[500]!),
                            ),
                            child: Text('Following', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                          )
                        : ElevatedButton(
                            onPressed: () => _followUser(suggestedUser.id, user),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF0095F6),
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              elevation: 0,
                            ),
                            child: Text('Follow', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _followUser(String targetUserId, dynamic currentUser) async {
    try {
        await FirebaseFirestore.instance
          .collection('followers')
          .doc(currentUser.id)
          .collection('following')
          .doc(targetUserId)
          .set({'timestamp': FieldValue.serverTimestamp()});
      
        await FirebaseFirestore.instance
          .collection('followers')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUser.id)
          .set({'timestamp': FieldValue.serverTimestamp()});
      
      _loadStats(); // Refresh counts
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Now following user!')));
        setState(() {}); // Refresh UI
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to follow: $e')));
    }
  }

  Future<void> _unfollowUser(String targetUserId, dynamic currentUser) async {
    try {
      await FirebaseFirestore.instance
          .collection('followers')
          .doc(currentUser.id)
          .collection('following')
          .doc(targetUserId)
          .delete();
      
      await FirebaseFirestore.instance
          .collection('followers')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUser.id)
          .delete();
      
      _loadStats(); // Refresh counts
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unfollowed user')));
        setState(() {}); // Refresh UI
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to unfollow: $e')));
    }
  }

  Widget _buildStatColumn(String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)), Text(label, style: TextStyle(color: Colors.grey, fontSize: 13))]),
    );
  }

  Widget _buildDiscoverPeopleCarousel(dynamic currentUser) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('users').get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox.shrink();
        final allUsers = snapshot.data!.docs
            .map((d) => UserModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .where((u) => u.id != currentUser.id)
            .toList();
        
        if (allUsers.isEmpty) return SizedBox.shrink();
        
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Discover people', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  GestureDetector(
                    child: Text('See all', style: TextStyle(color: Color(0xFF0095F6), fontWeight: FontWeight.w600, fontSize: 14)),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => DiscoverPeopleScreen()));
                    },
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 8),
                itemCount: allUsers.length > 10 ? 10 : allUsers.length,
                itemBuilder: (context, index) {
                  final targetUser = allUsers[index];
                  return FriendSuggestionCard(
                    userId: targetUser.id,
                    username: targetUser.username,
                    profilePic: targetUser.profilePic,
                    currentUserId: currentUser.id,
                  );
                },
              ),
            ),
            SizedBox(height: 8),
          ],
        );
      },
    );
  }

  void _showLogoutMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              SizedBox(height: 16),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  final isDarkMode = themeProvider.themeMode == ThemeMode.dark;
                  return SwitchListTile(
                    title: Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                    secondary: Icon(Icons.dark_mode, color: Theme.of(context).iconTheme.color),
                    value: isDarkMode,
                    onChanged: (value) {
                      themeProvider.toggleTheme(value);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text('Log out', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  await AuthService().signOut();
                  if (!mounted) return;
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
                },
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
