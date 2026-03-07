import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/user_model.dart';
import '../models/post_model.dart';
import '../providers/user_provider.dart';
import '../services/user_service.dart';
import '../services/post_service.dart';
import '../widgets/post_card.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final UserService _userService = UserService();
  final PostService _postService = PostService();
  
  late TabController _tabController;
  
  List<UserModel> _users = [];
  List<PostModel> _posts = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _doSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _users = [];
        _posts = [];
      });
      return;
    }
    
    setState(() {
      _loading = true;
    });
    final users = await _userService.searchUsers(query.trim());
    final posts = await _postService.searchPosts(query.trim());
    setState(() {
      _users = users;
      _posts = posts;
      _loading = false;
    });
  }

  Future<void> _followUser(UserModel user) async {
    final currentUser = Provider.of<UserProvider>(context, listen: false).user;
    if (currentUser == null) return;

    try {
      // Add to following
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.id)
          .collection('following')
          .doc(user.id)
          .set({
        'userId': user.id,
        'username': user.username,
        'profilePic': user.profilePic,
        'timestamp': DateTime.now(),
      });

      // Add to follower's followers
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .collection('followers')
          .doc(currentUser.id)
          .set({
        'userId': currentUser.id,
        'username': currentUser.username,
        'profilePic': currentUser.profilePic,
        'timestamp': DateTime.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Now following ${user.username}!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to follow: $e')),
      );
    }
  }

  Future<bool> _isFollowing(String userId) async {
    final currentUser = Provider.of<UserProvider>(context, listen: false).user;
    if (currentUser == null) return false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.id)
          .collection('following')
          .doc(userId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<UserProvider>(context).user;
    
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Color(0xFF121212),
        elevation: 0,
        title: Container(
          decoration: BoxDecoration(
            color: Color(0xFF2C2C2C),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[500]),
                      onPressed: () {
                        _searchController.clear();
                        _doSearch('');
                      },
                    )
                  : null,
            ),
            textInputAction: TextInputAction.search,
            onChanged: (value) {
              setState(() {});
            },
            onSubmitted: _doSearch,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.white,
          tabs: [
            Tab(icon: Icon(Icons.grid_on, color: Colors.white)),
            Tab(icon: Icon(Icons.people_outline, color: Colors.white)),
          ],
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: Color(0xFF0095F6),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // Posts tab
                _buildPostsTab(currentUser),
                // Users tab
                _buildUsersTab(),
              ],
            ),
    );
  }

  Widget _buildPostsTab(user) {
    if (_posts.isEmpty && _searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore,
              size: 60,
              color: Colors.grey[500],
            ),
            SizedBox(height: 16),
            Text(
              'Discover posts',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Search for posts to see them here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }
    
    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 60,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No posts found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    return GridView.builder(
      padding: EdgeInsets.all(2),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        return GestureDetector(
          onTap: () {
            // Navigate to post detail
            _showPostDetail(post);
          },
          child: CachedNetworkImage(
            imageUrl: post.imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[200],
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[200],
              child: Icon(Icons.broken_image, color: Colors.grey[400]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsersTab() {
    if (_users.isEmpty && _searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 60,
              color: Colors.grey[500],
            ),
            SizedBox(height: 16),
            Text(
              'Find friends',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Search for users to follow them',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }
    
    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 60,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        final currentUser = Provider.of<UserProvider>(context).user;
        
        // Don't show current user
        if (user.id == currentUser?.id) {
          return SizedBox.shrink();
        }
        
        return FutureBuilder<bool>(
          future: _isFollowing(user.id),
          builder: (context, snapshot) {
            final isFollowing = snapshot.data ?? false;
            
            return ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[800],
                backgroundImage: user.profilePic.isNotEmpty 
                    ? NetworkImage(user.profilePic) 
                    : null,
                child: user.profilePic.isEmpty
                    ? Text(
                        user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              title: Text(
                user.username,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                user.email,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              trailing: isFollowing
                  ? OutlinedButton(
                      onPressed: () => _unfollowUser(user),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        side: BorderSide(color: Color(0xFFDBDBDB)),
                      ),
                      child: Text('Following', style: TextStyle(fontSize: 13)),
                    )
                  : ElevatedButton(
                      onPressed: () => _followUser(user),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0095F6),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        elevation: 0,
                      ),
                      child: Text(
                        'Follow',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
            );
          },
        );
      },
    );
  }

  Future<void> _unfollowUser(UserModel user) async {
    final currentUser = Provider.of<UserProvider>(context, listen: false).user;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.id)
          .collection('following')
          .doc(user.id)
          .delete();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .collection('followers')
          .doc(currentUser.id)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unfollowed ${user.username}')),
      );
      
      // Refresh the list
      _doSearch(_searchController.text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to unfollow: $e')),
      );
    }
  }

  void _showPostDetail(PostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Post image
                  CachedNetworkImage(
                    imageUrl: post.imageUrl,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                  // Caption
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.caption.isNotEmpty ? post.caption : 'No caption',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
