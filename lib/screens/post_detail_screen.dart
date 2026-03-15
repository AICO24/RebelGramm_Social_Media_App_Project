import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../providers/user_provider.dart';

class PostDetailScreen extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onCommentAdded;

  const PostDetailScreen({Key? key, required this.post, this.onCommentAdded}) : super(key: key);

  @override
  _PostDetailScreenState createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController commentController = TextEditingController();

  void postComment() async {
    final commentText = commentController.text.trim();
    if (commentText.isEmpty) return;
    
    final user = Provider.of<UserProvider>(context, listen: false).user!;
    final id = Uuid().v4();
    await FirebaseFirestore.instance.collection('comments').doc(id).set({
      'postId': widget.post.id,
      'userId': user.id,
      'comment': commentText,
      'timestamp': FieldValue.serverTimestamp(),
    });
    commentController.clear();
    
    // Call the callback if provided
    widget.onCommentAdded?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Color(0xFF121212),
        elevation: 0,
        title: Text(
          'Post',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Caption
          Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    widget.post.caption.isNotEmpty ? widget.post.caption : 'No caption',
                    style: TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey[800]),

          // Comments section header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Comments',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey[800]),

          // Comments list (above the post image)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('comments')
                  .where('postId', isEqualTo: widget.post.id)
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
                final comments = snapshot.data!.docs
                    .map((doc) => CommentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                    .toList();
                if (comments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 50,
                          color: Colors.grey[500],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No comments yet',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Be the first to comment!',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.grey[800],
                            child: Icon(Icons.person, size: 18, color: Colors.grey[600]),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(color: Colors.white, fontSize: 14),
                                    children: [
                                      TextSpan(
                                        text: comment.userId.length > 10 
                                            ? '${comment.userId.substring(0, 10)}...' 
                                            : comment.userId,
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      TextSpan(text: '  ${comment.comment}'),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _formatTimestamp(comment.timestamp),
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
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
            ),
          ),

          // Post image shown below the comments
          CachedNetworkImage(
            imageUrl: widget.post.imageUrl,
            placeholder: (context, url) => Container(
              height: 250,
              color: Colors.grey[900],
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF0095F6),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: 250,
              color: Colors.grey[900],
              child: Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey[600])),
            ),
            width: double.infinity,
            fit: BoxFit.cover,
          ),

          // Comment input
          Container(
            decoration: BoxDecoration(
              color: Color(0xFF1E1E1E),
              border: Border(
                top: BorderSide(color: Color(0xFF2C2C2C), width: 0.5),
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: commentController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  GestureDetector(
                    onTap: postComment,
                    child: Icon(
                      Icons.send,
                      color: Color(0xFF0095F6),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
