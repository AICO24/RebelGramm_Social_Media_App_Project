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
import '../services/cloudinary_service.dart' as cloudinary;
import '../config/cloudinary_config.dart';
import '../providers/user_provider.dart';

class AddPostScreen extends StatefulWidget {
  final bool isStory;

  const AddPostScreen({Key? key, this.isStory = false}) : super(key: key);

  @override
  _AddPostScreenState createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final TextEditingController captionController = TextEditingController();
  final TextEditingController imageUrlController = TextEditingController();
  
  // Selected media state
  String _imageUrl = '';
  File? _selectedFile;
  final ImagePicker _picker = ImagePicker();
  
  // Upload state
  bool loading = false;
  double uploadProgress = 0.0;
  bool isUploading = false;

  /// Upload the post to Cloudinary
  Future<String?> _uploadToCloudinary(File file) async {
    setState(() {
      isUploading = true;
      uploadProgress = 0.0;
    });

    try {
      // Create Cloudinary service with app config
      final cloudinaryService = cloudinary.CloudinaryService(
        config: AppCloudinaryConfig.config,
      );

      // Upload image with progress tracking
      final result = await cloudinaryService.uploadImage(
        file,
        folder: AppCloudinaryConfig.postsFolder,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              uploadProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          isUploading = false;
          uploadProgress = 1.0;
        });
      }

      return result.secureUrl;
    } catch (e) {
      if (mounted) {
        setState(() {
          isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
      return null;
    }
  }

  void uploadPost() async {
    setState(() => loading = true);
    final user = Provider.of<UserProvider>(context, listen: false).user!;
    
    try {
      String finalImageUrl = _imageUrl;
      
      // If user picked a local file, upload to Cloudinary first
      if (_selectedFile != null) {
        // Upload to Cloudinary
        final uploadedUrl = await _uploadToCloudinary(_selectedFile!);
        
        if (uploadedUrl == null) {
          // Upload failed, exit
          if (mounted) setState(() => loading = false);
          return;
        }
        
        finalImageUrl = uploadedUrl;
      }

      if (finalImageUrl.isEmpty) {
        // Prompt user to pick an image if none provided
        await showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF1E1E1E),
          builder: (ctx) {
            return SafeArea(
              child: Wrap(children: [
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.white),
                  title: const Text('Choose from gallery', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.white),
                  title: const Text('Take a photo', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
              ]),
            );
          },
        );
        if (!mounted) return;
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
          likeCount: 0,
        );
        await postService.createPost(post);
      }
      if (!mounted) return;
      // show feedback and return to previous screen
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.isStory ? 'Story added' : 'Post shared')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isStory ? 'Story failed: $e' : 'Post failed: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source, 
        maxWidth: AppCloudinaryConfig.maxImageWidth.toDouble(),
        maxHeight: AppCloudinaryConfig.maxImageHeight.toDouble(),
        imageQuality: AppCloudinaryConfig.imageQuality,
      );
      if (picked == null) return;
      setState(() {
        _selectedFile = File(picked.path);
        _imageUrl = '';
        imageUrlController.text = '';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: Text(
          widget.isStory ? 'New Story' : 'New Post',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: loading ? null : uploadPost,
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0095F6)),
                    ),
                  )
                : const Text(
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
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image URL input / pickers
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: imageUrlController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Image URL (or pick from camera/gallery)',
                              hintStyle: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                
                const SizedBox(height: 16),
                
                // Image preview: either local file or network URL
                if (_selectedFile != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedFile!,
                          height: 300,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                      // Clear button
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              _selectedFile = null;
                            });
                          },
                          icon: const Icon(Icons.close),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withOpacity(0.5),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
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
                        child: const Center(
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
                              const SizedBox(height: 8),
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
                      color: const Color(0xFF1E1E1E),
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
                          const SizedBox(height: 12),
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
                
                // Upload progress indicator
                if (isUploading) ...[
                  const SizedBox(height: 16),
                  _buildUploadProgress(),
                ],
                
                const SizedBox(height: 20),
                
                // Caption input
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
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
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Post button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : uploadPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0095F6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
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
        ],
      ),
    );
  }

  Widget _buildUploadProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.cloud_upload,
                color: Color(0xFF0095F6),
                size: 24,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Uploading to Cloudinary...',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${(uploadProgress * 100).toInt()}%',
                style: const TextStyle(
                  color: Color(0xFF0095F6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: uploadProgress,
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF0095F6),
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getUploadStatusText(),
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _getUploadStatusText() {
    if (uploadProgress < 0.3) {
      return 'Preparing upload...';
    } else if (uploadProgress < 0.7) {
      return 'Uploading media...';
    } else if (uploadProgress < 1.0) {
      return 'Processing on Cloudinary...';
    } else {
      return 'Upload complete!';
    }
  }

  @override
  void dispose() {
    captionController.dispose();
    imageUrlController.dispose();
    super.dispose();
  }
}
