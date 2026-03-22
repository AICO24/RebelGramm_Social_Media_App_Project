// ==========================================
// ROLE: Member 4 - Reels & Video Architecture
// ==========================================
// This screen uses a PageView.builder to mimic the infinite vertical snapping scroll of TikTok/Reels.
// Key integrations:
// - video_player: Loads and caches remote network URLs for smooth playback.
// - visibility_detector: Triggers pause/play logic automatically depending on 
//   how much of the reel is actively visible on the user's glass screen.

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/reel_model.dart';
import '../services/reel_service.dart';
import '../services/post_service.dart';
import '../providers/user_provider.dart';
import 'add_reel_screen.dart';
import 'post_detail_screen.dart';

class ReelsFeedScreen extends StatefulWidget {
  const ReelsFeedScreen({Key? key}) : super(key: key);

  @override
  _ReelsFeedScreenState createState() => _ReelsFeedScreenState();
}

class _ReelsFeedScreenState extends State<ReelsFeedScreen> {
  final ReelService _reelService = ReelService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          StreamBuilder<List<ReelModel>>(
            stream: _reelService.fetchReels(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: Colors.white));
              }
              final reels = snapshot.data ?? [];
              if (reels.isEmpty) {
                return Center(child: Text('No reels yet', style: TextStyle(color: Colors.white)));
              }

              return PageView.builder(
                scrollDirection: Axis.vertical,
                itemCount: reels.length,
                itemBuilder: (context, index) {
                  return ReelPlayerItem(reel: reels[index]);
                },
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Text('Reels', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 6,
            right: 16,
            child: IconButton(
              icon: Icon(Icons.camera_alt_outlined, color: Colors.white, size: 30),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => AddReelScreen()));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ReelPlayerItem extends StatefulWidget {
  final ReelModel reel;
  const ReelPlayerItem({Key? key, required this.reel}) : super(key: key);

  @override
  _ReelPlayerItemState createState() => _ReelPlayerItemState();
}

class _ReelPlayerItemState extends State<ReelPlayerItem> {
  VideoPlayerController? _controller;
  bool _isPlaying = true;
  bool _isLiked = false;
  int _likeCount = 0;
  int _commentCount = 0;
  int _shareCount = 0;
  bool _isShared = false;

  @override
  void initState() {
    super.initState();
    _likeCount = (widget.reel.likes).length;
    _shareCount = widget.reel.shareCount;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = Provider.of<UserProvider>(context, listen: false).user?.id;
      if (uid != null && (widget.reel.likes).contains(uid)) {
        if (mounted) setState(() => _isLiked = true);
      }
      _loadInteractionData();
    });

    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.reel.videoUrl))
      ..initialize().then((_) {
        if (mounted) setState(() {});
        _controller!.setLooping(true);
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadInteractionData() async {
    final uid = Provider.of<UserProvider>(context, listen: false).user?.id;
    if (uid == null) return;
    
    final comments = await PostService().getCommentCount(widget.reel.id);
    final shared = await ReelService().isReelShared(widget.reel.id, uid);
    if (mounted) {
      setState(() {
        _commentCount = comments;
        _isShared = shared;
      });
    }
  }

  Future<void> _toggleShare() async {
    final uid = Provider.of<UserProvider>(context, listen: false).user?.id;
    if (uid == null) return;
    try {
      await ReelService().toggleShareStatus(widget.reel.id, uid);
      if (mounted) {
        setState(() {
          _isShared = !_isShared;
          _shareCount = _isShared ? _shareCount + 1 : (_shareCount > 0 ? _shareCount - 1 : 0);
        });
      }
    } catch (_) {}
  }

  Future<void> _showShareSheet() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) return;
    final follows = await FirebaseFirestore.instance
        .collection('followers')
        .doc(user.id)
        .collection('following')
        .get();
    
    if (follows.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You need to follow someone to share reels')),
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
            final data = doc.data();
            final fid = doc.id;
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
                  await ReelService().shareReel(widget.reel.id, user.id, fid);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reel sent to $fname')));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send reel: $e')));
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
    return VisibilityDetector(
      key: Key(widget.reel.id),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.7) {
          _controller?.play();
          if (mounted) setState(() => _isPlaying = true);
        } else {
          _controller?.pause();
          if (mounted) setState(() => _isPlaying = false);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          _controller != null && _controller!.value.isInitialized
            ? GestureDetector(
                onTap: () {
                  if (_controller!.value.isPlaying) {
                     _controller?.pause();
                     setState(() => _isPlaying = false);
                  } else {
                     _controller?.play();
                     setState(() => _isPlaying = true);
                  }
                },
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              )
            : Center(child: CircularProgressIndicator(color: Colors.white)),
          
          if (!_isPlaying && _controller != null && _controller!.value.isInitialized)
            Center(child: Icon(Icons.play_arrow, size: 80, color: Colors.white.withOpacity(0.5))),
            
          // Reels UI overlays
          Positioned(
            bottom: 20,
            left: 16,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@${widget.reel.username}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 8),
                Text(widget.reel.caption, style: TextStyle(color: Colors.white)),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.music_note, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text('${widget.reel.musicArtist} • ${widget.reel.musicTitle}', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          
          // Action Buttons
          Positioned(
            bottom: 20,
            right: 8,
            child: Column(
              children: [
                _buildActionBuilder(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  _likeCount.toString(),
                  () async {
                    final uid = Provider.of<UserProvider>(context, listen: false).user?.id;
                    if (uid == null) return;
                    try {
                      await ReelService().likeReel(widget.reel.id, uid);
                      if (mounted) {
                        setState(() {
                          _isLiked = !_isLiked;
                          _likeCount += _isLiked ? 1 : -1;
                        });
                      }
                    } catch (e) {
                      // Silently fail
                    }
                  },
                  color: _isLiked ? Colors.red : Colors.white,
                ),
                _buildActionBuilder(Icons.comment, _commentCount.toString(), () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(
                    post: widget.reel, 
                    onCommentAdded: () => _loadInteractionData(),
                  ))).then((_) => _loadInteractionData());
                }),
                _buildActionBuilder(Icons.send, _shareCount > 0 ? _shareCount.toString() : '0', () {
                  _toggleShare();
                  _showShareSheet();
                }, color: _isShared ? Colors.blue : Colors.white),
                _buildActionBuilder(Icons.more_vert, '', () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBuilder(IconData icon, String label, VoidCallback onTap, {Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            if (label.isNotEmpty) const SizedBox(height: 4),
            if (label.isNotEmpty) Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
