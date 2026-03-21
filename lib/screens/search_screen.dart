import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/user_model.dart';
import '../models/post_model.dart';
import '../providers/user_provider.dart';
import '../services/user_service.dart';
import '../services/post_service.dart';
import '../screens/post_detail_screen.dart';
import '../widgets/friend_suggestion_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final UserService _userService = UserService();
  final PostService _postService = PostService();
  
  List<UserModel> _users = [];
  List<PostModel> _posts = [];
  bool _loading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadDefaultExplore();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultExplore() async {
    setState(() => _loading = true);
    try {
      // Fetch random/recent users for "Discover people"
      final usersSnap = await FirebaseFirestore.instance.collection('users').limit(15).get();
      final users = usersSnap.docs.map((d) => UserModel.fromMap(d.data(), d.id)).toList();
      
      // Fetch recent posts for explore grid
      final postsQuery = await _postService.fetchPostsPageSnapshot(pageSize: 30);
      final posts = postsQuery.docs.map((d) => PostModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
      
      if (!mounted) return;
      setState(() {
        _users = users;
        _posts = posts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _doSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _isSearching = false);
      _loadDefaultExplore();
      return;
    }
    
    setState(() {
      _loading = true;
      _isSearching = true;
    });
    
    try {
      final users = await _userService.searchUsers(query.trim());
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _followUser(UserModel user) async {
    final currentUser = Provider.of<UserProvider>(context, listen: false).user;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('followers')
          .doc(currentUser.id)
          .collection('following')
          .doc(user.id)
          .set({
            'userId': user.id,
            'username': user.username,
            'profilePic': user.profilePic,
            'timestamp': FieldValue.serverTimestamp(),
          });

      await FirebaseFirestore.instance
          .collection('followers')
          .doc(user.id)
          .collection('followers')
          .doc(currentUser.id)
          .set({
            'userId': currentUser.id,
            'username': currentUser.username,
            'profilePic': currentUser.profilePic,
            'timestamp': FieldValue.serverTimestamp(),
          });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Now following ${user.username}!')));
      setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to follow: $e')));
    }
  }

  Future<void> _unfollowUser(UserModel user) async {
    final currentUser = Provider.of<UserProvider>(context, listen: false).user;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('followers')
          .doc(currentUser.id)
          .collection('following')
          .doc(user.id)
          .delete();

      await FirebaseFirestore.instance
          .collection('followers')
          .doc(user.id)
          .collection('followers')
          .doc(currentUser.id)
          .delete();

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unfollowed ${user.username}')));
      setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to unfollow: $e')));
    }
  }

  Future<bool> _isFollowing(String userId) async {
    final currentUser = Provider.of<UserProvider>(context, listen: false).user;
    if (currentUser == null) return false;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('followers')
          .doc(currentUser.id)
          .collection('following')
          .doc(userId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  void _showPostDetail(PostModel post) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)));
  }

  Widget _buildSearchResults(UserModel? currentUser) {
    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 60, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text('No users found', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        if (user.id == currentUser?.id) return SizedBox.shrink();
        
        return FutureBuilder<bool>(
          future: _isFollowing(user.id),
          builder: (context, snapshot) {
            final isFollowing = snapshot.data ?? false;
            return ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[800],
                backgroundImage: user.profilePic.isNotEmpty ? NetworkImage(user.profilePic) : null,
                child: user.profilePic.isEmpty
                    ? Text(user.username.isNotEmpty ? user.username[0].toUpperCase() : '?', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600))
                    : null,
              ),
              title: Text(user.username, style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(user.email, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              trailing: isFollowing
                  ? OutlinedButton(
                      onPressed: () => _unfollowUser(user),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        side: BorderSide(color: Color(0xFFDBDBDB)),
                        minimumSize: Size(100, 36),
                      ),
                      child: Text('Following', style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color)),
                    )
                  : ElevatedButton(
                      onPressed: () => _followUser(user),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0095F6),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        elevation: 0,
                        minimumSize: Size(100, 36),
                      ),
                      child: Text('Follow', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildDefaultExplore() {
    final filteredUsers = _users.where((u) => u.id != Provider.of<UserProvider>(context, listen: false).user?.id).toList();

    return RefreshIndicator(
      onRefresh: _loadDefaultExplore,
      child: CustomScrollView(
        slivers: [
          if (filteredUsers.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Text('Discover people', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: filteredUsers.length,
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  itemBuilder: (context, index) {
                    final targetUser = filteredUsers[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: FriendSuggestionCard(
                        userId: targetUser.id,
                        username: targetUser.username,
                        profilePic: targetUser.profilePic,
                        currentUserId: Provider.of<UserProvider>(context, listen: false).user?.id ?? '',
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
          
          if (_posts.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Text('Explore', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final post = _posts[index];
                  return GestureDetector(
                    onTap: () => _showPostDetail(post),
                    child: CachedNetworkImage(
                      imageUrl: post.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[200]),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.broken_image, color: Colors.grey[400]),
                      ),
                    ),
                  );
                },
                childCount: _posts.length,
              ),
            ),
          ] else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(child: Text('No posts to explore yet.', style: TextStyle(color: Colors.grey))),
              ),
            )
          ]
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<UserProvider>(context).user;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200],
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
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF0095F6)))
          : _isSearching
              ? _buildSearchResults(currentUser)
              : _buildDefaultExplore(),
    );
  }
}
