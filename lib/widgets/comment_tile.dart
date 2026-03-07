import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/comment_model.dart';

class CommentTile extends StatefulWidget {
  final CommentModel comment;
  CommentTile({required this.comment});

  @override
  _CommentTileState createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  String _username = '';

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.comment.userId)
          .get();
      if (doc.exists) {
        setState(() {
          _username = doc['username'] ?? widget.comment.userId;
        });
      }
    } catch (_) {
      setState(() {
        _username = widget.comment.userId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.comment.comment),
      subtitle: Text('by ${_username.isNotEmpty ? _username : widget.comment.userId}'),
    );
  }
}
