import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../services/storage_service.dart';
import '../screens/post_detail_screen.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  final dynamic currentUser;

  const PostCard({Key? key, required this.post, required this.currentUser}) : super(key: key);

  @override
  _PostCardState createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final PostService _postService = PostService();
  bool _isSaved = false;
  bool _loadingSave = false;
  bool _isFollowing = false;
  bool _loadingFollow = false;
  bool _isLiked = false;
  int _likeCount = 0;
  String? _displayName;
  int _commentCount = 0;

  @override
  void initState() {
    super.initState();
    _displayName = widget.post.username;
    if ((_displayName ?? '').isEmpty) {
      // fetch username from user record
      _fetchUsername();
    }
    _checkSaved();
    _checkFollowing();
    _checkIsLiked();
    _loadCommentCount();
  }

  Future<void> _checkIsLiked() async {
    if (widget.currentUser == null) return;
    try {
      final liked = await _postService.isPostLiked(widget.post.id, widget.currentUser.id);
      if (!mounted) return;
      setState(() {
        _isLiked = liked;
        _likeCount = (widget.post.likes ?? []).length;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadCommentCount() async {
    final count = await _postService.getCommentCount(widget.post.id);
    if (mounted) {
      setState(() {
        _commentCount = count;
      });
    }
  }

  Future<void> _fetchUsername() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.post.userId).get();
      final name = (doc.data()?['username'] ?? '').toString();
      if (name.isNotEmpty) {
        if (mounted) {
          setState(() {
            _displayName = name;
          });
        }
        // Update the post document so future loads don't need fetch
        await FirebaseFirestore.instance.collection('posts').doc(widget.post.id).update({'username': name});
      }
    } catch (e) {
      // Silently fail - will show userId as fallback
    }
  }

  Future<void> _checkFollowing() async {
    if (widget.currentUser == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUser.id)
        .collection('following')
        .doc(widget.post.userId)
        .get();
    if (!mounted) return;
    setState(() {
      _isFollowing = doc.exists;
    });
  }

  Future<void> _toggleFollow() async {
    final user = widget.currentUser;
    if (user == null) return;
    if (_loadingFollow) return;
    setState(() => _loadingFollow = true);
    try {
      final followingRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .collection('following')
          .doc(widget.post.userId);
      final followersRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.post.userId)
          .collection('followers')
          .doc(user.id);

      final batch = FirebaseFirestore.instance.batch();
      if (_isFollowing) {
        batch.delete(followingRef);
        batch.delete(followersRef);
        await batch.commit();
        if (!mounted) return;
        setState(() => _isFollowing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unfollowed')));
      } else {
        batch.set(followingRef, {'timestamp': FieldValue.serverTimestamp()});
        batch.set(followersRef, {'timestamp': FieldValue.serverTimestamp()});
        await batch.commit();
        if (!mounted) return;
        setState(() => _isFollowing = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Following')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Follow action failed: $e')));
    } finally {
      if (mounted) setState(() => _loadingFollow = false);
    }
  }

  Future<void> _checkSaved() async {
    if (widget.currentUser == null) return;
    final saved = await _postService.isPostSaved(widget.post.id, widget.currentUser.id);
    if (!mounted) return;
    setState(() {
      _isSaved = saved;
    });
  }

  Future<void> _toggleSave() async {
    if (_loadingSave) return;
    setState(() {
      _loadingSave = true;
    });
    try {
      if (_isSaved) {
        await _postService.unsavePost(widget.post.id, widget.currentUser.id);
      } else {
        await _postService.savePost(widget.post.id, widget.currentUser.id);
      }
      if (!mounted) return;
      setState(() {
        _isSaved = !_isSaved;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isSaved ? 'Post saved' : 'Removed from saved')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update save: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _loadingSave = false;
        });
      }
    }
  }

  Future<void> _showShareSheet() async {
    final user = widget.currentUser;
    if (user == null) return;
    final follows = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.id)
        .collection('following')
        .get();
    
    if (follows.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You need to follow someone to share posts')),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1E1E1E),
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          children: follows.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final fid = doc.id;
            // Try to get username from stored data, fallback to fetching from users collection
            String fname = data['username'] ?? 'User';
            final fpic = data['profilePic'] ?? '';
            
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: fpic.isNotEmpty ? NetworkImage(fpic) : null,
                backgroundColor: Colors.grey[700],
                child: fpic.isEmpty
                    ? Text(fname.isNotEmpty ? fname[0].toUpperCase() : '?', style: TextStyle(color: Colors.white))
                    : null,
              ),
              title: Text(fname, style: TextStyle(color: Colors.white)),
              onTap: () async {
                try {
                  await _postService.sharePost(widget.post.id, user.id, fid);
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Post sent to $fname')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send post: $e')));
                }
              },
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _repost() async {
    final user = widget.currentUser;
    if (user == null) return;
    try {
      await _postService.repost(widget.post, user.id, user.username);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reposted')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed repost: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = (_displayName ?? '').isNotEmpty ? _displayName! : widget.post.userId;
    final isLiked = _isLiked;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header with avatar and username
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[800],
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    username,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                // Follow button visible on every post
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: TextButton(
                    onPressed: widget.currentUser == null ? null : _toggleFollow,
                    child: Text(
                      _isFollowing ? 'Following' : 'Follow',
                      style: TextStyle(
                        color: _isFollowing ? Colors.grey[400] : Color(0xFF0095F6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.more_horiz, color: Colors.grey[600]),
                  onPressed: () => _showPostOptions(context),
                ),
              ],
            ),
          ),
          
          // image
          GestureDetector(
            onDoubleTap: () {
              _postService.likePost(widget.post.id, widget.currentUser.id);
            },
                child: AspectRatio(
              aspectRatio: 1,
              child: FutureBuilder<String?>(
                future: StorageService().getDownloadUrlSafe(widget.post.imageUrl),
                builder: (context, snap) {
                  final url = snap.data;
                  if (url == null) {
                    return Container(
                      color: Colors.grey[900],
                      child: Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey[600])),
                    );
                  }
                  return CachedNetworkImage(
                    imageUrl: url,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[900],
                      child: Center(
                        child: CircularProgressIndicator(color: Color(0xFF0095F6)),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[900],
                      child: Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey[600])),
                    ),
                    width: double.infinity,
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),
          ),
          
          // Action buttons
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.white,
                    size: 28,
                  ),
                  onPressed: () async {
                    final user = widget.currentUser;
                    if (user == null) return;
                    try {
                      await _postService.likePost(widget.post.id, user.id);
                      if (!mounted) return;
                      setState(() {
                        _isLiked = !_isLiked;
                        _likeCount = _isLiked ? _likeCount + 1 : (_likeCount > 0 ? _likeCount - 1 : 0);
                      });
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update like: $e')));
                    }
                  },
                ),
                IconButton(
                  icon: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 26),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: widget.post))),
                ),
                IconButton(
                  icon: Icon(Icons.send_outlined, color: Colors.white, size: 26),
                  onPressed: _showShareSheet,
                ),
                IconButton(
                  icon: FaIcon(FontAwesomeIcons.retweet, color: Colors.white, size: 24),
                  onPressed: _repost,
                ),
                IconButton(
                  icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border, color: Colors.white, size: 26),
                  onPressed: _toggleSave,
                ),
              ],
            ),
          ),
          
          // Likes count
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              '$_likeCount likes',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
            ),
          ),
          
          // Caption
          if (widget.post.caption.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(color: Colors.white, fontSize: 14),
                  children: [
                    TextSpan(text: username, style: TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(text: '  ${widget.post.caption}'),
                  ],
                ),
              ),
            ),
          
          // View comments
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: widget.post, onCommentAdded: _loadCommentCount))),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                _commentCount > 0 
                    ? 'View all $_commentCount comments' 
                    : 'Add a comment...',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ),
          ),
          
          // Timestamp
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _formatTimestamp(widget.post.timestamp),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ),
          
          Divider(height: 1),
        ],
      ),
    );
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

  void _showPostOptions(BuildContext context) {
    final isOwner = widget.currentUser != null && widget.currentUser.id == widget.post.userId;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              SizedBox(height: 16),
              if (isOwner)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red),
                  title: Text('Delete Post', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _deletePost();
                  },
                ),
              if (isOwner) Divider(),
              ListTile(
                leading: Icon(Icons.share_outlined, color: Colors.white),
                title: Text('Share to', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showShareSheet();
                },
              ),
              ListTile(
                leading: Icon(Icons.link, color: Colors.white),
                title: Text('Copy Link', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Link copied!')));
                },
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deletePost() async {
    try {
      await _postService.deletePost(widget.post.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Post deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete post: $e')));
    }
  }
}
