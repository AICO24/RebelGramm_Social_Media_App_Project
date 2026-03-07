import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/post_service.dart';
import '../models/post_model.dart';
import '../models/story_model.dart';
import '../services/story_service.dart';
import '../providers/user_provider.dart';

class AddPostScreen extends StatefulWidget {
  final bool isStory;

  AddPostScreen({this.isStory = false});

  @override
  _AddPostScreenState createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final TextEditingController captionController = TextEditingController();
  final TextEditingController imageUrlController = TextEditingController();
  String _imageUrl = '';
  bool loading = false;


  void uploadPost() async {
    if (_imageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter an image URL')),
      );
      return;
    }
    
    setState(() => loading = true);
    final user = Provider.of<UserProvider>(context, listen: false).user!;
    try {
      if (widget.isStory) {
        // store as a story instead of a regular post
        final story = StoryModel(
          userId: user.id,
          username: user.username,
          imageUrl: _imageUrl,
          timestamp: DateTime.now(),
        );
        await StoryService().createStory(story);
      } else {
        final postService = PostService();
        final post = PostModel(
          id: '',
          userId: user.id,
          username: user.username, // store current username
          caption: captionController.text,
          imageUrl: _imageUrl,
          timestamp: DateTime.now(),
          likes: [],
        );
        await postService.createPost(post);
      }
      if (!mounted) return;
      // show feedback and return to previous screen
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.isStory ? 'Story added' : 'Post shared')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isStory ? 'Story failed: $e' : 'Post failed: $e')),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Color(0xFF121212),
        elevation: 0,
        title: Text(
          'New Post',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: loading ? null : uploadPost,
            child: Text(
              'Share',
              style: TextStyle(
                color: Color(0xFF0095F6),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image URL input
            Container(
              decoration: BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: imageUrlController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Image URL',
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  prefixIcon: Icon(Icons.link, color: Colors.grey[500], size: 20),
                  suffixIcon: _imageUrl.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey[500]),
                          onPressed: () {
                            setState(() {
                              _imageUrl = '';
                              imageUrlController.clear();
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _imageUrl = value;
                  });
                },
              ),
            ),
            
            SizedBox(height: 16),
            
            // Image preview
            if (_imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: _imageUrl,
                  height: 300,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 300,
                    color: Colors.grey[900],
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0095F6),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 300,
                    color: Colors.grey[900],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, size: 50, color: Colors.grey[600]),
                          SizedBox(height: 8),
                          Text(
                            'Invalid image URL',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        size: 60,
                        color: Colors.grey[600],
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Enter an image URL above',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            SizedBox(height: 20),
            
            // Caption input
            Container(
              decoration: BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: captionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Write a caption...',
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
                style: TextStyle(fontSize: 14),
              ),
            ),
            
            SizedBox(height: 20),
            
            // Post button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : uploadPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0095F6),
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: loading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Post',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
