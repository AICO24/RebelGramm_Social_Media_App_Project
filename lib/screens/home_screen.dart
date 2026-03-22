// ==========================================
// ROLE: Member 2 - The Main Feed & Stories
// ==========================================
// The core scaffold of the app. Features include:
// - A top app bar with navigation to Messages (Inbox).
// - A horizontal list of Stories fetched dynamically from followed users.
// - A vertically scrolling chronological Feed of Posts using StreamBuilder
//   to ensure real-time updates as users scroll.
// - A bottom navigation bar connecting the main tabs.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../providers/user_provider.dart';
import '../services/post_service.dart';
import '../models/post_model.dart';
import '../models/story_model.dart';
import '../models/reel_model.dart';
import '../services/story_service.dart';
import '../services/reel_service.dart';
import '../widgets/post_card.dart';
import '../widgets/friend_suggestion_card.dart';
import '../widgets/story_avatar.dart';
import 'login_screen.dart';
import 'add_post_screen.dart';
import 'profile_screen.dart';
import 'chatbot_screen.dart';
import 'search_screen.dart';
import 'inbox_screen.dart';
import 'notifications_screen.dart';
import 'reels_feed_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PostService _postService = PostService();
  final StoryService _storyService = StoryService();
  int _currentIndex = 0;
  int _feedTab = 0; // 0 = For you, 1 = Following
  // Pagination state
  final List<dynamic> _feedItems = [];
  DocumentSnapshot? _lastPostDoc;
  DocumentSnapshot? _lastReelDoc;
  bool _isLoadingPosts = false;
  bool _hasMorePosts = true;
  bool _hasMoreReels = true;
  String? _feedError;
  final ScrollController _scrollController = ScrollController();

  Widget _buildProfileCompletionBanner({required String userId}) {
    return Container(
      width: double.infinity,
      color: Color(0xFF252525),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Finish your profile to get better recommendations',
              style: TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen()));
            },
            child: Text('Complete', style: TextStyle(color: Color(0xFF0095F6))),
          ),
        ],
      ),
    );
  }

  int _feedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
        _loadMorePosts();
      }
    });
    // initial load
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialPosts());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialPosts() async {
    _feedItems.clear();
    _lastPostDoc = null;
    _lastReelDoc = null;
    _hasMorePosts = true;
    _hasMoreReels = true;
    _feedError = null;
    await _loadMorePosts();
  }

  Future<void> _loadMorePosts({int pageSize = 10}) async {
    if (_isLoadingPosts || (!_hasMorePosts && !_hasMoreReels)) return;
    setState(() {
      _isLoadingPosts = true;
      _feedError = null;
    });
    try {
      final currentUser = Provider.of<UserProvider>(context, listen: false).user;
      List<dynamic> newBatch = [];

      if (_hasMorePosts) {
        QuerySnapshot postSnap;
        if (_feedTab == 1) {
          postSnap = await _postService.fetchFollowingPostsPageSnapshot(currentUser?.id ?? '', startAfter: _lastPostDoc, pageSize: pageSize);
        } else {
          postSnap = await _postService.fetchPostsPageSnapshot(startAfter: _lastPostDoc, pageSize: pageSize);
        }
        if (postSnap.docs.isNotEmpty) {
          final newPosts = postSnap.docs.map((d) => PostModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
          _lastPostDoc = postSnap.docs.last;
          if (postSnap.docs.length < pageSize) _hasMorePosts = false;
          newBatch.addAll(newPosts);
        } else {
          _hasMorePosts = false;
        }
      }

      if (_hasMoreReels && _feedTab == 0) {
        final reelSnap = await ReelService().fetchReelsPageSnapshot(startAfter: _lastReelDoc, pageSize: 2);
        if (reelSnap.docs.isNotEmpty) {
          final newReels = reelSnap.docs.map((doc) => ReelModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
          _lastReelDoc = reelSnap.docs.last;
          if (reelSnap.docs.length < 2) _hasMoreReels = false;
          if (newReels.isNotEmpty) {
            int insertIndex = newBatch.length > 2 ? 2 : newBatch.length;
            newBatch.insertAll(insertIndex, newReels);
          }
        } else {
          _hasMoreReels = false;
        }
      }

      if (mounted) {
        setState(() {
          _feedItems.addAll(newBatch);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _feedError = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load feed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoadingPosts = false);
    }
  }

  Widget _buildStories() {
    final currentUser = Provider.of<UserProvider>(context).user;

    // if there's no signed-in user, avoid creating a doc(null) stream
    if (currentUser == null) {
      return Container(
        height: 120, // Increased to fix bottom overflow inside ListView horizontally children
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: Text(
            'Sign in to see stories',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ),
      );
    }

    // first stream returns the IDs of people we follow (including self)
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('followers')
          .doc(currentUser.id)
          .collection('following')
          .snapshots(),
      builder: (context, followingSnapshot) {
        final followingIds = <String>[];
        followingIds.add(currentUser.id);
        if (followingSnapshot.hasData) {
          followingIds.addAll(followingSnapshot.data!.docs.map((d) => d.id));
        }

        return StreamBuilder<List<StoryModel>>(
          stream: _storyService.fetchStories(followingIds),
          builder: (context, storySnapshot) {
            final Map<String, StoryModel> latestStoryMap = {};
            if (storySnapshot.hasData) {
              for (var s in storySnapshot.data!) {
                if (DateTime.now().difference(s.timestamp).inHours < 24) {
                  if (!latestStoryMap.containsKey(s.userId)) {
                    latestStoryMap[s.userId] = s;
                  }
                }
              }
            }

            return Container(
              height: 120, // Increased to fix bottom overflow
              color: Theme.of(context).scaffoldBackgroundColor,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: followingIds.length,
                itemBuilder: (context, index) {
                  final uid = followingIds[index];
                  String profilePic = '';
                  String username = 'User';
                  bool isCurrentUser = currentUser != null && uid == currentUser.id;
                  bool hasStory = latestStoryMap.containsKey(uid);

                  if (isCurrentUser) {
                    profilePic = currentUser?.profilePic ?? '';
                    username = currentUser?.username ?? 'You';
                  } else if (followingSnapshot.hasData && index > 0) {
                    final doc = followingSnapshot.data!.docs[index - 1];
                    final map = doc.data() as Map<String, dynamic>;
                    profilePic = map['profilePic'] ?? '';
                    username = map['username'] ?? 'User';
                  }

                  return StoryAvatar(
                    profilePic: profilePic,
                    username: username,
                    isCurrentUser: isCurrentUser,
                    hasStory: hasStory,
                    onTap: isCurrentUser
                        ? (hasStory 
                            ? () => _viewStory(uid, username, profilePic, latestStoryMap[uid]!.imageUrl)
                            : _addStory)
                        : hasStory
                            ? () => _viewStory(uid, username, profilePic, latestStoryMap[uid]!.imageUrl)
                            : null,
                    onAddStoryTap: isCurrentUser ? _addStory : null,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }



  void _viewStory(String userId, String username, String profilePic, String storyImageUrl) {
    // Show story in a full screen dialog
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.all(0),
        child: Stack(
          children: [
            // Story image (using cached network image placeholder for now)
            Center(
              child: storyImageUrl.isNotEmpty
                  ? Image.network(
                      storyImageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => _buildStoryPlaceholder(username),
                    )
                  : _buildStoryPlaceholder(username),
            ),
            // Header
            Positioned(
              top: 40,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: profilePic.isNotEmpty ? NetworkImage(profilePic) : null,
                    child: profilePic.isEmpty
                        ? Text(username.isNotEmpty ? username[0].toUpperCase() : '?', style: TextStyle(color: Colors.white))
                        : null,
                  ),
                  SizedBox(width: 12),
                  Text(
                    username,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            // Close button
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryPlaceholder(String username) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF833AB4), Color(0xFFE1306C), Color(0xFFF56040)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 60,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _addStory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddPostScreen(isStory: true)),
    );
  }

  Widget _buildBody() {
    final user = Provider.of<UserProvider>(context).user;
    switch (_currentIndex) {
      case 0:
        return Column(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
              child: _buildStories(),
            ),
            if (user != null && (user.username.isEmpty || user.profilePic.isEmpty))
              _buildProfileCompletionBanner(userId: user.id),
            // FOR YOU: show suggestions and all posts
            if (_feedTab == 0)
              Column(
                children: [
                  // Suggestions horizontal list
                  SizedBox(
                    height: 140,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('followers')
                          .doc(user?.id)
                          .collection('following')
                          .snapshots(),
                      builder: (context, followingSnapshot) {
                        final followingIds = <String>[];
                        if (user != null) followingIds.add(user.id);
                        if (followingSnapshot.hasData) {
                          followingIds.addAll(followingSnapshot.data!.docs.map((d) => d.id));
                        }

                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('users').snapshots(),
                          builder: (context, usersSnapshot) {
                            if (!usersSnapshot.hasData) {
                              return Center(child: CircularProgressIndicator(color: Color(0xFF0095F6)));
                            }

                            // build list of users not followed yet
                            final suggestions = usersSnapshot.data!.docs
                                .where((d) => d.id != user?.id && !followingIds.contains(d.id))
                                .map((d) {
                                  final m = d.data() as Map<String, dynamic>;
                                  return {
                                    'id': d.id,
                                    'username': m['username'] ?? 'User',
                                    'profilePic': m['profilePic'] ?? ''
                                  };
                                })
                                .toList();

                            if (suggestions.isEmpty) {
                              return Center(child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Text('No new suggestions', style: TextStyle(color: Colors.grey[400])),
                              ));
                            }

                            return ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              itemCount: suggestions.length,
                              itemBuilder: (context, idx) {
                                final s = suggestions[idx];
                                return FriendSuggestionCard(
                                  userId: s['id']!,
                                  username: s['username']!,
                                  profilePic: s['profilePic']!,
                                  currentUserId: user?.id ?? '',
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // Feed Tabs
                  Container(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _feedTabIndex = 0),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: _feedTabIndex == 0 ? Theme.of(context).iconTheme.color! : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              child: Center(
                                child: Text('For you', style: TextStyle(
                                  fontWeight: _feedTabIndex == 0 ? FontWeight.bold : FontWeight.normal,
                                  color: _feedTabIndex == 0 ? Theme.of(context).iconTheme.color : Colors.grey,
                                )),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _feedTabIndex = 1),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: _feedTabIndex == 1 ? Theme.of(context).iconTheme.color! : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              child: Center(
                                child: Text('Following', style: TextStyle(
                                  fontWeight: _feedTabIndex == 1 ? FontWeight.bold : FontWeight.normal,
                                  color: _feedTabIndex == 1 ? Theme.of(context).iconTheme.color : Colors.grey,
                                )),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Posts feed below tabs
                  // SizedBox(height: 8),
                ],
              ),

            // Feed area (paginated)
            Expanded(
              child: _feedTabIndex == 1 
                ? _buildFollowingUsersList(user?.id ?? '')
                : RefreshIndicator(
                onRefresh: () async {
                  await _loadInitialPosts();
                },
                child: _feedError != null
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.error_outline, size: 60, color: Colors.red[400]),
                        SizedBox(height: 16),
                        Text('Error loading feed', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                        Text(_feedError!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                        SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadInitialPosts, child: Text('Retry')),
                      ]))
                    : _feedItems.isEmpty && _isLoadingPosts
                    ? Center(child: CircularProgressIndicator(color: Color(0xFF0095F6)))
                    : _feedItems.isEmpty
                        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(FontAwesomeIcons.photoFilm, size: 60, color: Colors.grey[600]),
                            SizedBox(height: 16),
                            Text('No posts yet', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                            SizedBox(height: 8),
                            Text('Follow friends or create a post!', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                          ]))
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount: _feedItems.length + ((_hasMorePosts || _hasMoreReels) ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _feedItems.length) {
                                // loading indicator
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Center(child: CircularProgressIndicator(color: Color(0xFF0095F6))),
                                );
                              }
                              final item = _feedItems[index];
                              return PostCard(post: item, currentUser: user!);
                            },
                          ),
              ),
            ),
          ],
        );
      case 1:
        return SearchScreen();
      case 2:
        return Container(); // Intercepted tap
      case 3:
        return ReelsFeedScreen();
      case 4:
        return ProfileScreen();
      default:
        return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentUser = Provider.of<UserProvider>(context).user;
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'RebelGram',
          style: TextStyle(
            fontFamily: 'Billabong',
            fontSize: 28,
            fontWeight: FontWeight.normal,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('userId', isEqualTo: currentUser.id)
                .where('isRead', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              int unreadCount = 0;
              if (snapshot.hasData && !snapshot.hasError) {
                unreadCount = snapshot.data!.docs.length;
              }
              return IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.favorite_border, color: Theme.of(context).iconTheme.color),
                    if (unreadCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : unreadCount.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () {
                  // Mark as read in background without blocking
                  if (unreadCount > 0 && snapshot.hasData) {
                    final batch = FirebaseFirestore.instance.batch();
                    int count = 0;
                    for (var doc in snapshot.data!.docs) {
                      if (count++ >= 500) break; // Limit batch size just in case
                      batch.update(doc.reference, {'isRead': true});
                    }
                    batch.commit().catchError((_) => null);
                  }
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                },
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.send_outlined, color: Theme.of(context).iconTheme.color),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InboxScreen())),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8.0, right: 4.0),
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatbotScreen())),
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF833AB4), Color(0xFFE1306C), Color(0xFFF56040), Color(0xFFF77737)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Icon(Icons.smart_toy_outlined, color: Colors.white, size: 28),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: _buildBody(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 0.5,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          selectedItemColor: Theme.of(context).iconTheme.color,
          unselectedItemColor: Theme.of(context).iconTheme.color,
          onTap: (index) {
            if (index == 2) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => AddPostScreen()));
            } else {
              setState(() {
                _currentIndex = index;
              });
            }
          },
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, size: 28),
              activeIcon: Icon(Icons.home, size: 28),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search, size: 28),
              activeIcon: Icon(Icons.search, size: 28, weight: 900),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_box_outlined, size: 28),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.video_collection_outlined, size: 28),
              activeIcon: Icon(Icons.video_collection, size: 28),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Consumer<UserProvider>(
                builder: (context, userProvider, child) {
                  final user = userProvider.user;
                  return CircleAvatar(
                    radius: 14,
                    backgroundImage: user?.profilePic != null && user!.profilePic.isNotEmpty
                        ? NetworkImage(user.profilePic)
                        : null,
                    backgroundColor: Colors.grey.shade300,
                    child: user?.profilePic == null || user!.profilePic.isEmpty
                        ? Text(
                            user?.username.isNotEmpty == true ? user!.username[0].toUpperCase() : '?',
                            style: TextStyle(fontSize: 12, color: Colors.black87),
                          )
                        : null,
                  );
                },
              ),
              label: '',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowingUsersList(String currentUserId) {
    if (currentUserId.isEmpty) return SizedBox.shrink();
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('followers').doc(currentUserId).collection('following').snapshots(),
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
            final name = data['name'] ?? ''; // Added to match Instagram

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey[800],
                backgroundImage: profilePic.isNotEmpty ? NetworkImage(profilePic) : null,
                child: profilePic.isEmpty ? Icon(Icons.person, color: Colors.white) : null,
              ),
              title: Text(username, style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: name.isNotEmpty ? Text(name, style: TextStyle(color: Colors.grey)) : null,
              trailing: OutlinedButton(
                onPressed: () => _unfollowUser(targetId, currentUserId),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  side: BorderSide(color: Color(0xFFDBDBDB)),
                  minimumSize: Size(90, 36),
                ),
                child: Text('Following', style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color)),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _unfollowUser(String targetUserId, String currentUserId) async {
    try {
      await FirebaseFirestore.instance.collection('followers').doc(currentUserId).collection('following').doc(targetUserId).delete();
      await FirebaseFirestore.instance.collection('followers').doc(targetUserId).collection('followers').doc(currentUserId).delete();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unfollowed user')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to unfollow: $e')));
    }
  }
}
