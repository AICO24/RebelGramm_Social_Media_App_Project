import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../services/post_service.dart';
import '../models/post_model.dart';
import '../models/story_model.dart';
import '../services/story_service.dart';
import '../services/storage_service.dart';
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
  File? _selectedFile;
  final ImagePicker _picker = ImagePicker();
  bool loading = false;


  void uploadPost() async {
    setState(() => loading = true);
    final user = Provider.of<UserProvider>(context, listen: false).user!;
    try {
      // If user picked a local file, upload it first
      String finalImageUrl = _imageUrl;
      if (_selectedFile != null) {
        finalImageUrl = await StorageService().uploadPostImage(_selectedFile!);
      }

      if (finalImageUrl.isEmpty) {
        // Prompt user to pick an image if none provided
        await showModalBottomSheet(
          context: context,
          backgroundColor: Color(0xFF1E1E1E),
          builder: (ctx) {
            return SafeArea(
              child: Wrap(children: [
                ListTile(
                  leading: Icon(Icons.photo_library, color: Colors.white),
                  title: Text('Choose from gallery', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.camera_alt, color: Colors.white),
                  title: Text('Take a photo', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
              ]),
            );
          },
        );
        setState(() => loading = false);
        return;
      }

      if (widget.isStory) {
        final story = StoryModel(
          userId: user.id,
          username: user.username,
          imageUrl: finalImageUrl,
          timestamp: DateTime.now(),
        );
        await StoryService().createStory(story);
      } else {
        final postService = PostService();
        final post = PostModel(
          id: '',
          userId: user.id,
          username: user.username,
          caption: captionController.text,
          imageUrl: finalImageUrl,
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, maxWidth: 1920);
      if (picked == null) return;
      setState(() {
        _selectedFile = File(picked.path);
        _imageUrl = '';
        imageUrlController.text = '';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
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
            // Image URL input / pickers
            Container(
              decoration: BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: imageUrlController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Image URL (or pick from camera/gallery)',
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _imageUrl = value;
                            if (value.isNotEmpty) _selectedFile = null;
                          });
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Gallery',
                      icon: Icon(Icons.photo_library, color: Colors.grey[400]),
                      onPressed: () => _pickImage(ImageSource.gallery),
                    ),
                    IconButton(
                      tooltip: 'Camera',
                      icon: Icon(Icons.camera_alt, color: Colors.grey[400]),
                      onPressed: () => _pickImage(ImageSource.camera),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Image preview: either local file or network URL
            if (_selectedFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _selectedFile!,
                  height: 300,
                  fit: BoxFit.cover,
                ),
              )
            else if (_imageUrl.isNotEmpty)
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
                        'Pick an image from gallery or camera',
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
