import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../models/reel_model.dart';
import '../services/reel_service.dart';
import '../services/cloudinary_service.dart' as cloudinary;
import '../config/cloudinary_config.dart';
import '../providers/user_provider.dart';

class AddReelScreen extends StatefulWidget {
  const AddReelScreen({Key? key}) : super(key: key);

  @override
  _AddReelScreenState createState() => _AddReelScreenState();
}

class _AddReelScreenState extends State<AddReelScreen> {
  final TextEditingController captionController = TextEditingController();
  File? _selectedFile;
  final ImagePicker _picker = ImagePicker();
  VideoPlayerController? _videoController;
  bool _loading = false;
  
  // Upload progress
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void dispose() {
    captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  /// Upload video to Cloudinary
  Future<String?> _uploadToCloudinary(File file) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      // Create Cloudinary service with app config
      final cloudinaryService = cloudinary.CloudinaryService(
        config: AppCloudinaryConfig.config,
      );

      // Upload video with progress tracking
      final result = await cloudinaryService.uploadVideo(
        file,
        folder: AppCloudinaryConfig.reelsFolder,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 1.0;
        });
      }

      return result.secureUrl;
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final picked = await _picker.pickVideo(
        source: source, 
        maxDuration: Duration(seconds: AppCloudinaryConfig.maxVideoDurationSeconds),
      );
      if (picked == null) return;
      
      _selectedFile = File(picked.path);
      _videoController?.dispose();
      _videoController = VideoPlayerController.file(_selectedFile!)
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {});
          _videoController?.setLooping(true);
          _videoController?.play();
        });
      
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick video: $e')),
      );
    }
  }

  Future<void> _uploadReel() async {
    if (_selectedFile == null) {
      // prompt to pick
      await showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Wrap(children: [
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickVideo(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Record a video'),
              onTap: () {
                Navigator.pop(ctx);
                _pickVideo(ImageSource.camera);
              },
            ),
          ]),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    final user = Provider.of<UserProvider>(context, listen: false).user!;
    
    try {
      // Upload to Cloudinary
      final videoUrl = await _uploadToCloudinary(_selectedFile!);
      
      if (videoUrl == null) {
        // Upload failed
        if (mounted) setState(() => _loading = false);
        return;
      }
      
      final reel = ReelModel(
        id: '',
        userId: user.id,
        username: user.username,
        caption: captionController.text,
        videoUrl: videoUrl,
        timestamp: DateTime.now(),
        likes: [],
      );
      await ReelService().createReel(reel);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reel uploaded successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text(
          'New Reel',
          style: TextStyle(
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
            onPressed: _loading ? null : _uploadReel,
            child: _loading
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
              children: [
                // Video preview
                if (_videoController != null && _videoController!.value.isInitialized)
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      ),
                      // Clear button
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          onPressed: () {
                            _videoController?.dispose();
                            setState(() {
                              _selectedFile = null;
                              _videoController = null;
                            });
                          },
                          icon: const Icon(Icons.close),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withOpacity(0.5),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      // Play/Pause overlay
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_videoController!.value.isPlaying) {
                                _videoController!.pause();
                              } else {
                                _videoController!.play();
                              }
                            });
                          },
                          child: Center(
                            child: AnimatedOpacity(
                              opacity: _videoController!.value.isPlaying ? 0.0 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow,
                                  size: 50,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.videocam, size: 60, color: Colors.grey[600]),
                          const SizedBox(height: 8),
                          Text(
                            'Pick or record a short video (max ${AppCloudinaryConfig.maxVideoDurationSeconds}s)',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                const SizedBox(height: 12),
                
                // Pick video buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _loading ? null : () => _pickVideo(ImageSource.gallery),
                      icon: const Icon(Icons.video_library),
                      label: const Text('Gallery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D2D2D),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _loading ? null : () => _pickVideo(ImageSource.camera),
                      icon: const Icon(Icons.videocam),
                      label: const Text('Camera'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D2D2D),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                
                // Upload progress
                if (_isUploading) ...[
                  const SizedBox(height: 16),
                  _buildUploadProgress(),
                ],
                
                const SizedBox(height: 16),
                
                // Caption input
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: captionController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Write a caption...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Post button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _uploadReel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0095F6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Post Reel',
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
                '${(_uploadProgress * 100).toInt()}%',
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
              value: _uploadProgress,
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
    if (_uploadProgress < 0.3) {
      return 'Preparing video upload...';
    } else if (_uploadProgress < 0.7) {
      return 'Uploading video...';
    } else if (_uploadProgress < 1.0) {
      return 'Processing on Cloudinary...';
    } else {
      return 'Upload complete!';
    }
  }
}
