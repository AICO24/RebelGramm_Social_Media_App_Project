import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class FriendSuggestionCard extends StatefulWidget {
  final String userId;
  final String username;
  final String profilePic;
  final String currentUserId;

  const FriendSuggestionCard({
    Key? key,
    required this.userId,
    required this.username,
    required this.profilePic,
    required this.currentUserId,
  }) : super(key: key);

  @override
  _FriendSuggestionCardState createState() => _FriendSuggestionCardState();
}

class _FriendSuggestionCardState extends State<FriendSuggestionCard> {
  bool _isFollowing = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    if (widget.currentUserId.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .collection('following')
        .doc(widget.userId)
        .get();
    if (!mounted) return;
    setState(() => _isFollowing = doc.exists);
  }

  Future<void> _toggleFollow() async {
    if (_loading || widget.currentUserId.isEmpty) return;
    setState(() => _loading = true);
    try {
      final followingRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .collection('following')
          .doc(widget.userId);
      final followerRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('followers')
          .doc(widget.currentUserId);

      if (_isFollowing) {
        await followingRef.delete();
        await followerRef.delete();
        if (!mounted) return;
        setState(() => _isFollowing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unfollowed ${widget.username}')),
        );
      } else {
        await followingRef.set({
          'timestamp': FieldValue.serverTimestamp(),
          'username': widget.username,
          'profilePic': widget.profilePic,
        });
        await followerRef.set({'timestamp': FieldValue.serverTimestamp()});
        if (!mounted) return;
        setState(() => _isFollowing = true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Following ${widget.username}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Follow failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: FutureBuilder<String?>(
              future: widget.profilePic.isNotEmpty ? StorageService().getDownloadUrlSafe(widget.profilePic) : Future.value(null),
              builder: (context, snap) {
                final url = snap.data;
                if (url != null && url.isNotEmpty) {
                  return CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: NetworkImage(url),
                  );
                }
                return CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.grey[800],
                  child: Text(
                    widget.username.isNotEmpty ? widget.username[0].toUpperCase() : '?',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              },
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.username,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Suggested for you',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isFollowing ? Colors.grey[700] : Color(0xFF0095F6),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _toggleFollow,
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: 250),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: _loading
                  ? SizedBox(
                      key: ValueKey('loading'),
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isFollowing ? 'Following' : 'Follow',
                      key: ValueKey(_isFollowing ? 'following' : 'follow'),
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
