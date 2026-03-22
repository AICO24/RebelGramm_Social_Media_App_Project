// ==========================================
// ROLE: Member 3 - Content Creation & Interactions
// ==========================================
// The most complex UI component in the app. This renders individual posts on the feed.
// Responsibilities:
// - Parsing data from PostModel into visual fields (Image, Caption, Username).
// - Displaying dynamic interaction counters for Likes, Comments, Reposts, and Shares.
// - Handling interactive UI states locally before sending transaction requests to Firestore.
// - Managing the 'Save' and 'Follow' quick-actions directly on the card.

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../models/reel_model.dart';
import '../services/post_service.dart';
import '../services/storage_service.dart';
import '../screens/post_detail_screen.dart';

class PostCard extends StatefulWidget {
  final dynamic post;
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
  String? _profilePic;
  int _commentCount = 0;
  bool _isReposted = false;
  int _repostCount = 0;
  bool _isShared = false;
  int _shareCount = 0;
  VideoPlayerController? _videoController;

  bool get isReel => widget.post is ReelModel;

  @override
  void initState() {
    super.initState();
    _displayName = widget.post.username;
    // Always fetch latest user profile data (pic etc) even if username is locally cached
    _fetchUsername();
    
    _isLiked = widget.post.likes?.contains(widget.currentUser?.id) ?? false;
    _likeCount = isReel ? (widget.post.likes?.length ?? 0) : widget.post.likeCount;
    _repostCount = isReel ? 0 : (widget.post.repostCount ?? 0);
    _shareCount = isReel ? 0 : (widget.post.shareCount ?? 0);

    if (isReel) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.post.videoUrl))
        ..initialize().then((_) {
          if (mounted) setState(() {});
          _videoController!.setLooping(true);
          _videoController!.setVolume(0.0);
          _videoController!.play();
        });
    }

    if (!isReel) {
      _checkSaved();
      _checkIsLiked();
      _loadCommentCount();
      _checkIsReposted();
      _checkIsShared();
    }
    _checkFollowing();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
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

  Future<void> _checkIsReposted() async {
    if (widget.currentUser == null) return;
    try {
      final reposted = await _postService.isPostReposted(widget.post.id, widget.currentUser.id);
      if (!mounted) return;
      setState(() => _isReposted = reposted);
    } catch (_) {}
  }

  Future<void> _checkIsShared() async {
    if (widget.currentUser == null) return;
    try {
      final shared = await _postService.isPostShared(widget.post.id, widget.currentUser.id);
      if (!mounted) return;
      setState(() => _isShared = shared);
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
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
  }

  Future<void> _toggleRepost() async {
    final user = widget.currentUser;
    if (user == null || isReel) return;
    try {
      await _postService.toggleRepost(widget.post.id, user.id);
      if (!mounted) return;
      setState(() {
        _isReposted = !_isReposted;
        _repostCount = _isReposted ? _repostCount + 1 : (_repostCount > 0 ? _repostCount - 1 : 0);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update repost: $e')));
    }
  }

  Future<void> _toggleShare() async {
    final user = widget.currentUser;
    if (user == null || isReel) return;
    try {
      await _postService.toggleShareStatus(widget.post.id, user.id);
      if (!mounted) return;
      setState(() {
        _isShared = !_isShared;
        _shareCount = _isShared ? _shareCount + 1 : (_shareCount > 0 ? _shareCount - 1 : 0);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update share: $e')));
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
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;
      
      final name = (data['username'] ?? '').toString();
      final pic = (data['profilePic'] ?? '').toString();
      
      if (mounted) {
        setState(() {
          if (name.isNotEmpty) _displayName = name;
          if (pic.isNotEmpty) _profilePic = pic;
        });
      }
      
      // Update the post document so future loads don't need fetch
      if (name.isNotEmpty) await FirebaseFirestore.instance.collection('posts').doc(widget.post.id).update({'username': name});
    } catch (e) {
      // Silently fail - will show userId as fallback
    }
  }

  Future<void> _checkFollowing() async {
    if (widget.currentUser == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('followers')
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
          .collection('followers')
          .doc(user.id)
          .collection('following')
          .doc(widget.post.userId);
      final followersRef = FirebaseFirestore.instance
          .collection('followers')
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
        .collection('followers')
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

  @override
  Widget build(BuildContext context) {
    final username = (_displayName ?? '').isNotEmpty ? _displayName! : widget.post.userId;
    final iconColor = Theme.of(context).iconTheme.color;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
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
                  radius: 16,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: (_profilePic ?? '').isNotEmpty ? NetworkImage(_profilePic!) : null,
                  child: (_profilePic ?? '').isEmpty
                      ? Text(
                          username.isNotEmpty ? username[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        )
                      : null,
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
                // Follow button visible on every post EXCEPT own posts
                if (widget.currentUser != null && widget.currentUser.id != widget.post.userId)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: TextButton(
                      onPressed: _toggleFollow,
                      child: Text(
                        _isFollowing ? 'Following' : 'Follow',
                        style: TextStyle(
                          color: _isFollowing ? Colors.grey : Color(0xFF0095F6),
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
                  icon: Icon(Icons.more_horiz, color: iconColor),
                  onPressed: () => _showPostOptions(context),
                  constraints: BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          
          // image or video
          GestureDetector(
            onDoubleTap: () {
              if (widget.currentUser != null) {
                if (!isReel) _postService.likePost(widget.post.id, widget.currentUser.id);
                if (!mounted) return;
                setState(() {
                  if (!_isLiked) {
                    _isLiked = true;
                    _likeCount++;
                  }
                });
              }
            },
            onTap: () {
              if (isReel && _videoController != null && _videoController!.value.isInitialized) {
                setState(() {
                  _videoController!.value.isPlaying ? _videoController!.pause() : _videoController!.play();
                });
              }
            },
            child: AspectRatio(
              aspectRatio: isReel ? (_videoController?.value.isInitialized == true ? _videoController!.value.aspectRatio : 4/5) : 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  isReel 
                    ? (_videoController != null && _videoController!.value.isInitialized)
                        ? VisibilityDetector(
                            key: Key('feed_video_${widget.post.id}'),
                            onVisibilityChanged: (info) {
                              if (info.visibleFraction > 0.5) {
                                _videoController?.play();
                              } else {
                                _videoController?.pause();
                              }
                            },
                            child: VideoPlayer(_videoController!),
                          )
                        : Container(color: Colors.black, child: Center(child: CircularProgressIndicator(color: Color(0xFF0095F6))))
                    : FutureBuilder<String?>(
                        future: StorageService().getDownloadUrlSafe(widget.post.imageUrl),
                        builder: (context, snap) {
                          final url = snap.data;
                          if (url == null) {
                            return Container(
                              color: Colors.grey.shade300,
                              child: Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                            );
                          }
                          return CachedNetworkImage(
                            imageUrl: url,
                            placeholder: (context, url) => Container(
                              color: Colors.grey.shade300,
                              child: Center(
                                child: CircularProgressIndicator(color: Color(0xFF0095F6)),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade300,
                              child: Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                            ),
                            width: double.infinity,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                  
                  // Reels Badges
                  if (isReel)
                    Positioned(
                      top: 10,
                      right: 12,
                      child: Icon(Icons.movie_creation_outlined, color: Colors.white, size: 24),
                    ),
                  
                  if (isReel && _videoController != null && _videoController!.value.isInitialized)
                    Positioned(
                      bottom: 10,
                      right: 12,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                        child: Text(widget.post.duration ?? '0:15', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Action buttons
          Padding(
             padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
             child: Row(
               children: [
                 InkWell(
                   onTap: _toggleLike,
                   child: Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                     child: Row(
                       children: [
                         Icon(
                           _isLiked ? Icons.favorite : Icons.favorite_border,
                           color: _isLiked ? Colors.red : iconColor,
                           size: 24,
                         ),
                         SizedBox(width: 4),
                         Text('$_likeCount', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                       ],
                     ),
                   ),
                 ),
                 SizedBox(width: 16),
                 InkWell(
                   onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: widget.post, onCommentAdded: _loadCommentCount))),
                   child: Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                     child: Row(
                       children: [
                         Icon(Icons.chat_bubble_outline, color: iconColor, size: 24),
                         SizedBox(width: 4),
                         Text('$_commentCount', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                       ],
                     ),
                   ),
                 ),
                 SizedBox(width: 16),
                 InkWell(
                   onTap: _toggleRepost,
                   child: Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                     child: Row(
                       children: [
                         Icon(Icons.repeat, color: _isReposted ? Colors.green : iconColor, size: 24),
                         SizedBox(width: 4),
                         Text('$_repostCount', style: TextStyle(color: _isReposted ? Colors.green : textColor, fontWeight: FontWeight.w600)),
                       ],
                     ),
                   ),
                 ),
                 SizedBox(width: 16),
                 InkWell(
                   onTap: () {
                     _toggleShare();
                     _showShareSheet();
                   },
                   child: Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                     child: Row(
                       children: [
                         Icon(Icons.send_outlined, color: _isShared ? Colors.blue : iconColor, size: 24),
                         SizedBox(width: 4),
                         Text('$_shareCount', style: TextStyle(color: _isShared ? Colors.blue : textColor, fontWeight: FontWeight.w600)),
                       ],
                     ),
                   ),
                 ),
                 Spacer(),
                 IconButton(
                   icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border, color: iconColor, size: 26),
                   onPressed: _toggleSave,
                   padding: EdgeInsets.zero,
                   constraints: BoxConstraints(),
                 ),
               ],
             ),
           ),
          
          // Music / Audio info
          if (isReel)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.library_music_outlined, size: 14, color: textColor),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${widget.post.musicArtist} • ${widget.post.musicTitle}',
                      style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w400),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          
          // Caption
          if (widget.post.caption.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(color: textColor, fontSize: 14),
                  children: [
                    TextSpan(text: username, style: TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(text: '  ${widget.post.caption}'),
                  ],
                ),
              ),
            ),
          
          // View comments
          if (_commentCount > 0)
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: widget.post, onCommentAdded: _loadCommentCount))),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(
                  'View all $_commentCount comments',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ),
          
          // Timestamp
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              _formatTimestamp(widget.post.timestamp),
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          
          Divider(height: 8, thickness: 0.5),
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
