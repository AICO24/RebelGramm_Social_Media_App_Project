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
import 'add_post_screen.dart';
import 'profile_screen.dart';
import 'chatbot_screen.dart';
import 'search_screen.dart';
import 'inbox_screen.dart';  // new messaging inbox screen

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PostService _postService = PostService();
  final StoryService _storyService = StoryService();
  int _currentIndex = 0;
  bool _showNotifications = false;
  int _feedTab = 0; // 0 = For you, 1 = Following

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
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('notifications')
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
                  ),
                ),
              ],
            ),
          );
        },
      ).then((_) {
        setState(() {
          _showNotifications = false;
        });
      });
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
                // only consider stories within last 24h
                if (DateTime.now().difference(s.timestamp).inHours < 24) {
                  hasStorySet.add(s.userId);
                }
              }
            }

            return Container(
              height: 100,
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

                  return _buildStoryItem(
                    profilePic,
                    username,
                    isCurrentUser: isCurrentUser,
                    hasStory: hasStory,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStoryItem(String profilePic, String username, {required bool isCurrentUser, required bool hasStory}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: isCurrentUser ? _addStory : null,
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

  Widget _buildTabSwitcher() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => setState(() => _feedTab = 0),
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
            onTap: () => setState(() => _feedTab = 1),
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
            _buildTabSwitcher(),
            Expanded(
              child: StreamBuilder<List<PostModel>>(
                stream: _postService.fetchPosts(),
                builder: (context, snapshot) {
            if (!snapshot.hasData) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF0095F6),
                        ),
                      );
                    }
                    final posts = snapshot.data!;
                    if (posts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              FontAwesomeIcons.photoFilm,
                              size: 60,
                              color: Colors.grey[600],
                            ),
                    SizedBox(height: 16),
                    Text(
                      'No posts yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Follow friends or create a post!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
                      itemCount: posts.length,
                      itemBuilder: (context, index) => PostCard(post: posts[index], currentUser: user!),
                    );
                  },
                ),
              ),
            ],
          );
      case 1:
        // placeholder reels page
        return Center(child: Text('Reels', style: TextStyle(color: Colors.white, fontSize: 24)));
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
        title: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: SvgPicture.asset(
              'assets/images/rebelgram-icon.svg',
              width: 32,
              height: 32,
            ),
          ),
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
