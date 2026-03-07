import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../screens/post_detail_screen.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  final dynamic currentUser;

  PostCard({required this.post, required this.currentUser});

  @override
  _PostCardState createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final PostService _postService = PostService();
  bool _isSaved = false;
  bool _loadingSave = false;
  String? _displayName;

  @override
  void initState() {
    super.initState();
    _displayName = widget.post.username;
    if ((_displayName ?? '').isEmpty) {
      // fetch username from user record and patch post
      FirebaseFirestore.instance.collection('users').doc(widget.post.userId).get().then((doc) {
        final name = (doc.data()?['username'] ?? '').toString();
        if (name.isNotEmpty) {
          setState(() {
            _displayName = name;
          });
          // optionally update the post document so future loads don't need fetch
          FirebaseFirestore.instance.collection('posts').doc(widget.post.id).update({'username': name});
        }
      });
    }
    _checkSaved();
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
      setState(() {
        _loadingSave = false;
      });
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1E1E1E),
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          children: follows.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final fid = doc.id;
            final fname = data['username'] ?? 'User';
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
                await FirebaseFirestore.instance.collection('notifications').add({
                  'userId': fid,
                  'type': 'share',
                  'message': 'shared a post with you',
                  'fromUserId': user.id,
                  'postId': widget.post.id,
                  'timestamp': DateTime.now(),
                });
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Post sent to $fname')));
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
    final isLiked = widget.post.likes.contains(widget.currentUser?.id);

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
                IconButton(
                  icon: Icon(Icons.more_horiz, color: Colors.grey[600]),
                  onPressed: () {},
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
              child: CachedNetworkImage(
                imageUrl: widget.post.imageUrl,
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
                  onPressed: () => _postService.likePost(widget.post.id, widget.currentUser.id),
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
              '${widget.post.likes.length} likes',
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
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: widget.post))),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('View all comments', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            ),
          ),
          
          // Timestamp
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _formatTimestamp(widget.post.timestamp),
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
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
}
