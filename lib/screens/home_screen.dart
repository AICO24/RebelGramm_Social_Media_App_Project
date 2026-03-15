import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../providers/user_provider.dart';
import '../services/post_service.dart';
import '../models/post_model.dart';
import '../models/story_model.dart';
import '../services/story_service.dart';
import '../widgets/post_card.dart';
import '../widgets/friend_suggestion_card.dart';
import '../widgets/story_avatar.dart';
import 'add_post_screen.dart';
import 'add_reel_screen.dart';
import '../services/reel_service.dart';
import '../models/reel_model.dart';
import 'profile_screen.dart';
import 'chatbot_screen.dart';
import 'search_screen.dart';
import 'inbox_screen.dart';  // new messaging inbox screen

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PostService _postService = PostService();
  final StoryService _storyService = StoryService();
  int _currentIndex = 0;
  bool _showNotifications = false;
  int _feedTab = 0; // 0 = For you, 1 = Following
  // Pagination state
  final List<PostModel> _posts = [];
  DocumentSnapshot? _lastDoc;
  bool _isLoadingPosts = false;
  bool _hasMorePosts = true;
  final ScrollController _scrollController = ScrollController();

  void _showNotificationPanel() {
    setState(() {
      _showNotifications = !_showNotifications;
    });
    
    if (_showNotifications) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          return Container(
            padding: EdgeInsets.all(16),
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
                Row(
                  children: [
                    Icon(Icons.notifications, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final currentUser = Provider.of<UserProvider>(context, listen: false).user;
                      if (currentUser == null) {
                        return Center(
                          child: Text('Sign in to see notifications', style: TextStyle(color: Colors.grey[400])),
                        );
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('notifications')
                            .where('userId', isEqualTo: currentUser.id)
                            .orderBy('timestamp', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF0095F6),
                              ),
                            );
                          }

                          final notifications = snapshot.data!.docs;
                          if (notifications.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.notifications_none,
                                    size: 60,
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No notifications yet',
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
                            itemCount: notifications.length,
                            itemBuilder: (context, index) {
                              final notif = notifications[index].data() as Map<String, dynamic>;
                              return ListTile(
                                tileColor: Color(0xFF1E1E1E),
                                leading: CircleAvatar(
                                  backgroundColor: Color(0xFF0095F6),
                                  child: Icon(
                                    notif['type'] == 'like'
                                        ? Icons.favorite
                                        : notif['type'] == 'comment'
                                            ? Icons.chat_bubble
                                            : Icons.person_add,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  notif['message'] ?? 'New notification',
                                  style: TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  _formatTimestamp(
                                    (notif['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
                                  ),
                                  style: TextStyle(color: Colors.grey[400]),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ).then((_) {
        if (!mounted) return;
        setState(() {
          _showNotifications = false;
        });
      });
    }
  }

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
    _posts.clear();
    _lastDoc = null;
    _hasMorePosts = true;
    await _loadMorePosts();
  }

  Future<void> _loadMorePosts({int pageSize = 10}) async {
    if (_isLoadingPosts || !_hasMorePosts) return;
    setState(() => _isLoadingPosts = true);
    try {
      final currentUser = Provider.of<UserProvider>(context, listen: false).user;
      QuerySnapshot snap;
      if (_feedTab == 1) {
        snap = await _postService.fetchFollowingPostsPageSnapshot(currentUser?.id ?? '', startAfter: _lastDoc, pageSize: pageSize);
      } else {
        snap = await _postService.fetchPostsPageSnapshot(startAfter: _lastDoc, pageSize: pageSize);
      }
      if (snap.docs.isNotEmpty) {
        if (!mounted) return;
        final newPosts = snap.docs.map((d) => PostModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
        setState(() {
          _posts.addAll(newPosts);
          _lastDoc = snap.docs.last;
          if (snap.docs.length < pageSize) _hasMorePosts = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _hasMorePosts = false;
        });
      }
    } catch (e) {
      // ignore load errors for now
    } finally {
      if (mounted) setState(() => _isLoadingPosts = false);
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildStories() {
    final currentUser = Provider.of<UserProvider>(context).user;

    // if there's no signed-in user, avoid creating a doc(null) stream
    if (currentUser == null) {
      return Container(
        height: 100,
        color: Color(0xFF121212),
        child: Center(
          child: Text(
            'Sign in to see stories',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ),
      );
    }

    // if there's no signed-in user, avoid creating a doc(null) stream
    if (currentUser == null) {
      return Container(
        height: 100,
        color: Color(0xFF121212),
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
          .collection('users')
          .doc(currentUser.id)
          .collection('following')
          .snapshots(),
      builder: (context, followingSnapshot) {
        final followingIds = <String>[];
        if (currentUser != null) followingIds.add(currentUser.id);
        if (followingSnapshot.hasData) {
          followingIds.addAll(followingSnapshot.data!.docs.map((d) => d.id));
        }

        return StreamBuilder<List<StoryModel>>(
          stream: _storyService.fetchStories(followingIds),
          builder: (context, storySnapshot) {
            final hasStorySet = <String>{};
            if (storySnapshot.hasData) {
              for (var s in storySnapshot.data!) {
                if (DateTime.now().difference(s.timestamp).inHours < 24) {
                  hasStorySet.add(s.userId);
                }
              }
            }

            return Container(
              height: 110,
              color: Color(0xFF121212),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                itemCount: followingIds.length,
                itemBuilder: (context, index) {
                  final uid = followingIds[index];
                  String profilePic = '';
                  String username = 'User';
                  bool isCurrentUser = currentUser != null && uid == currentUser.id;
                  bool hasStory = hasStorySet.contains(uid);

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
                        ? _addStory
                        : hasStory
                            ? () => _viewStory(uid, username, profilePic)
                            : null,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStoryItem(String profilePic, String username, String userId, {required bool isCurrentUser, required bool hasStory}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: isCurrentUser 
            ? _addStory 
            : hasStory 
                ? () => _viewStory(userId, username, profilePic)
                : null,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasStory 
                      ? LinearGradient(
                          colors: [Color(0xFF833AB4), Color(0xFFE1306C), Color(0xFFF56040)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                    border: !hasStory && !isCurrentUser 
                      ? Border.all(color: Colors.grey[700]!, width: 1)
                      : null,
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: profilePic.isNotEmpty 
                      ? NetworkImage(profilePic) 
                      : null,
                    child: profilePic.isEmpty
                      ? Text(
                          username.isNotEmpty ? username[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                  ),
                ),
                if (isCurrentUser)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Color(0xFF0095F6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 4),
            SizedBox(
              width: 70,
              child: Text(
                isCurrentUser ? 'Your Story' : username,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewStory(String userId, String username, String profilePic) {
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
              child: profilePic.isNotEmpty
                  ? Image.network(
                      profilePic,
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

  Widget _buildTabSwitcher() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () async { setState(() => _feedTab = 0); await _loadInitialPosts(); },
            child: Column(
              children: [
                Text('For you', style: TextStyle(color: _feedTab == 0 ? Colors.white : Colors.grey)),
                SizedBox(height: 4),
                Container(height: 2, width: 50, color: _feedTab == 0 ? Colors.white : Colors.transparent),
              ],
            ),
          ),
          SizedBox(width: 32),
          GestureDetector(
            onTap: () async { setState(() => _feedTab = 1); await _loadInitialPosts(); },
            child: Column(
              children: [
                Text('Following', style: TextStyle(color: _feedTab == 1 ? Colors.white : Colors.grey)),
                SizedBox(height: 4),
                Container(height: 2, width: 70, color: _feedTab == 1 ? Colors.white : Colors.transparent),
              ],
            ),
          ),
        ],
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
            if (user != null && (user.username.isEmpty || user.profilePic.isEmpty))
              _buildProfileCompletionBanner(userId: user.id),
            _buildTabSwitcher(),
            // FOR YOU: show suggestions and all posts
            if (_feedTab == 0)
              Column(
                children: [
                  // Suggestions horizontal list
                  SizedBox(
                    height: 140,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
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

                  // Posts feed below suggestions
                  SizedBox(height: 8),
                ],
              ),

            // Feed area (paginated)
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await _loadInitialPosts();
                },
                child: _posts.isEmpty && _isLoadingPosts
                    ? Center(child: CircularProgressIndicator(color: Color(0xFF0095F6)))
                    : _posts.isEmpty
                        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(FontAwesomeIcons.photoFilm, size: 60, color: Colors.grey[600]),
                            SizedBox(height: 16),
                            Text('No posts yet', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                            SizedBox(height: 8),
                            Text('Follow friends or create a post!', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                          ]))
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount: _posts.length + (_hasMorePosts ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _posts.length) {
                                // loading indicator
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Center(child: CircularProgressIndicator(color: Color(0xFF0095F6))),
                                );
                              }
                              final post = _posts[index];
                              return PostCard(post: post, currentUser: user!);
                            },
                          ),
              ),
            ),
          ],
        );
      case 1:
        // Reels feed
        return StreamBuilder<List<ReelModel>>(
          stream: ReelService().fetchReels(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator(color: Color(0xFF0095F6)));
            }
            final reels = snapshot.data!;
            if (reels.isEmpty) {
              return Center(child: Text('No reels yet', style: TextStyle(color: Colors.grey[500])));
            }
            return ListView.builder(
              itemCount: reels.length,
              itemBuilder: (context, index) {
                final r = reels[index];
                return ListTile(
                  tileColor: Color(0xFF1E1E1E),
                  leading: Container(
                    width: 64,
                    height: 64,
                    color: Colors.grey[800],
                    child: Center(child: Icon(Icons.play_arrow, color: Colors.white)),
                  ),
                  title: Text(r.username, style: TextStyle(color: Colors.white)),
                  subtitle: Text(r.caption, style: TextStyle(color: Colors.grey[400])),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: Color(0xFF121212),
                        title: Text('Reel', style: TextStyle(color: Colors.white)),
                        content: Text('Video URL:\n${r.videoUrl}', style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close')),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      case 2:
        return Container();
      case 3:
        return SearchScreen();
      case 4:
        return ProfileScreen();
      default:
        return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        leading: IconButton(
          icon: FaIcon(FontAwesomeIcons.solidCommentDots, size: 24),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InboxScreen())),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/images/rebelgram-icon.svg',
              width: 28,
              height: 28,
            ),
            SizedBox(width: 8),
            Text(
              'RebelGram',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFF121212),
        elevation: 0,
        actions: [
          IconButton(
            icon: FaIcon(
              FontAwesomeIcons.robot,
              color: Colors.white,
            ),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatbotScreen())),
          ),
          IconButton(
            icon: FaIcon(
              FontAwesomeIcons.bell,
              color: Colors.white,
            ),
            onPressed: _showNotificationPanel,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Color(0xFF121212),
              border: Border(
                bottom: BorderSide(color: Color(0xFF2C2C2C), width: 0.5),
              ),
            ),
            child: _buildStories(),
          ),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton(
              backgroundColor: Color(0xFF0095F6),
              child: Icon(Icons.add),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddReelScreen())),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Color(0xFF121212),
          border: Border(
            top: BorderSide(
              color: Color(0xFF2C2C2C),
              width: 0.5,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
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
              icon: FaIcon(FontAwesomeIcons.house, size: 24),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.play, size: 24),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF833AB4), Color(0xFFE1306C), Color(0xFFF56040)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FaIcon(FontAwesomeIcons.plus, color: Colors.white, size: 18),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.magnifyingGlass, size: 24),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.user, size: 24),
              label: '',
            ),
          ],
        ),
      ),
    );
  }
}
