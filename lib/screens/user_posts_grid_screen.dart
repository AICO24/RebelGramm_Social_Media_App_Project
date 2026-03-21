import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import 'post_detail_screen.dart';

class UserPostsGridScreen extends StatelessWidget {
  final String userId;
  final PostService _postService = PostService();

  UserPostsGridScreen({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Posts', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: StreamBuilder<List<PostModel>>(
        stream: _postService.fetchPosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             return Center(child: CircularProgressIndicator());
          }
          final posts = snapshot.data?.where((p) => p.userId == userId).toList() ?? [];
          
          if (posts.isEmpty) {
            return Center(child: Text('No posts yet'));
          }

          return GridView.builder(
            padding: EdgeInsets.all(2),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, 
              crossAxisSpacing: 2, 
              mainAxisSpacing: 2
            ),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)));
                },
                child: CachedNetworkImage(
                  imageUrl: post.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.grey[800]),
                  errorWidget: (context, url, error) => Container(color: Colors.grey[800], child: Icon(Icons.broken_image)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
