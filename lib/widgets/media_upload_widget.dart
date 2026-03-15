import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../services/cloudinary_service.dart';
import '../services/media_picker_service.dart';

/// A widget that provides a complete media upload solution
/// with image/video picking and upload progress display.
///
/// Features:
/// - Pick images from gallery or camera
/// - Pick videos from gallery or camera
/// - Display upload progress
/// - Preview selected media before upload
/// - Handle errors gracefully
///
/// Example usage:
/// ```dart
/// MediaUploadWidget(
///   cloudinaryConfig: CloudinaryConfig(
///     cloudName: 'your-cloud-name',
///     uploadPreset: 'your-preset',
///   ),
///   onUploadComplete: (url) {
///     print('Uploaded to: $url');
///     // Save url to Firestore or database
///   },
///   folder: 'posts',
/// )
/// ```
class MediaUploadWidget extends StatefulWidget {
  /// Cloudinary configuration
  final CloudinaryConfig cloudinaryConfig;
  
  /// Callback when upload is complete, returns the uploaded URL
  final void Function(String url)? onUploadComplete;
  
  /// Callback when upload fails
  final void Function(String error)? onUploadError;
  
  /// Optional folder in Cloudinary to store media
  final String? folder;
  
  /// Whether to allow image picking
  final bool allowImages;
  
  /// Whether to allow video picking
  final bool allowVideos;
  
  /// Maximum video duration (for video uploads)
  final Duration? maxVideoDuration;
  
  /// Initial URL to display (for editing existing posts)
  final String? initialImageUrl;
  
  /// Whether to show the upload button
  final bool showUploadButton;
  
  /// Custom label for the upload button
  final String uploadButtonLabel;
  
  /// Height of the media preview container
  final double previewHeight;

  const MediaUploadWidget({
    Key? key,
    required this.cloudinaryConfig,
    this.onUploadComplete,
    this.onUploadError,
    this.folder,
    this.allowImages = true,
    this.allowVideos = false,
    this.maxVideoDuration,
    this.initialImageUrl,
    this.showUploadButton = true,
    this.uploadButtonLabel = 'Upload',
    this.previewHeight = 300,
  }) : super(key: key);

  @override
  State<MediaUploadWidget> createState() => _MediaUploadWidgetState();
}

class _MediaUploadWidgetState extends State<MediaUploadWidget> {
  // Selected file
  File? _selectedFile;
  
  // Upload state
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _errorMessage;
  
  // Video controller (for local video preview)
  VideoPlayerController? _videoController;
  
  // Media picker service
  final MediaPickerService _mediaPicker = MediaPickerService();
  
  // Cloudinary service
  late CloudinaryService _cloudinaryService;

  @override
  void initState() {
    super.initState();
    _cloudinaryService = CloudinaryService(config: widget.cloudinaryConfig);
    
    // If there's an initial URL, display it
    if (widget.initialImageUrl != null && widget.initialImageUrl!.isNotEmpty) {
      // This is for edit mode - we keep the existing URL
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  /// Handle media picking from gallery or camera
  Future<void> _pickMedia() async {
    try {
      final result = await _mediaPicker.showMediaSourcePicker(
        context: context,
        allowImages: widget.allowImages,
        allowVideos: widget.allowVideos,
        maxVideoDuration: widget.maxVideoDuration,
      );
      
      if (result != null) {
        setState(() {
          _selectedFile = result.file;
          _errorMessage = null;
        });
        
        // If it's a video, initialize the video controller
        if (result.isVideo) {
          _initVideoController(result.file);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick media: $e';
      });
    }
  }

  /// Initialize video controller for local preview
  void _initVideoController(File file) {
    _videoController?.dispose();
    _videoController = VideoPlayerController.file(file)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _videoController?.setLooping(true);
          _videoController?.play();
        }
      });
  }

  /// Upload the selected media to Cloudinary
  Future<void> _uploadMedia() async {
    if (_selectedFile == null) {
      setState(() {
        _errorMessage = 'Please select a file first';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _errorMessage = null;
    });

    try {
      // Determine if it's a video based on extension
      final isVideo = _selectedFile!.path.toLowerCase().endsWith('.mp4') ||
          _selectedFile!.path.toLowerCase().endsWith('.mov') ||
          _selectedFile!.path.toLowerCase().endsWith('.avi') ||
          _selectedFile!.path.toLowerCase().endsWith('.mkv') ||
          _selectedFile!.path.toLowerCase().endsWith('.webm');

      // Upload to Cloudinary
      String uploadedUrl;
      
      if (isVideo) {
        final result = await _cloudinaryService.uploadVideo(
          _selectedFile!,
          folder: widget.folder,
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _uploadProgress = progress;
              });
            }
          },
        );
        uploadedUrl = result.secureUrl;
      } else {
        final result = await _cloudinaryService.uploadImage(
          _selectedFile!,
          folder: widget.folder,
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _uploadProgress = progress;
              });
            }
          },
        );
        uploadedUrl = result.secureUrl;
      }

      // Notify success
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 1.0;
        });
        
        widget.onUploadComplete?.call(uploadedUrl);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload successful!')),
        );
      }
    } on CloudinaryException catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _errorMessage = e.message;
        });
        widget.onUploadError?.call(e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _errorMessage = 'Upload failed: $e';
        });
        widget.onUploadError?.call(e.toString());
      }
    }
  }

  /// Clear the selected file
  void _clearSelection() {
    _videoController?.dispose();
    _videoController = null;
    setState(() {
      _selectedFile = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Error message
        if (_errorMessage != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

        // Media preview or placeholder
        _buildMediaPreview(),

        const SizedBox(height: 12),

        // Pick media button
        _buildPickButton(),

        const SizedBox(height: 12),

        // Upload button
        if (widget.showUploadButton) _buildUploadButton(),

        // Loading indicator with progress
        if (_isUploading) _buildProgressIndicator(),
      ],
    );
  }

  Widget _buildMediaPreview() {
    // If uploading, show progress overlay
    if (_isUploading) {
      return Stack(
        children: [
          _buildPreviewContent(),
          // Progress overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: _uploadProgress > 0 ? _uploadProgress : null,
                        strokeWidth: 4,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF0095F6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _uploadProgress > 0
                          ? '${(_uploadProgress * 100).toInt()}%'
                          : 'Uploading...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return _buildPreviewContent();
  }

  Widget _buildPreviewContent() {
    // Show selected file preview
    if (_selectedFile != null) {
      // Video preview
      if (_selectedFile!.path.toLowerCase().endsWith('.mp4') ||
          _selectedFile!.path.toLowerCase().endsWith('.mov') ||
          _selectedFile!.path.toLowerCase().endsWith('.avi')) {
        return _buildVideoPreview();
      }
      
      // Image preview
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _selectedFile!,
              height: widget.previewHeight,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          // Clear button
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: _clearSelection,
              icon: const Icon(Icons.close),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withOpacity(0.5),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    // Show existing URL preview (for editing)
    if (widget.initialImageUrl != null && widget.initialImageUrl!.isNotEmpty) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: widget.initialImageUrl!,
              height: widget.previewHeight,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: widget.previewHeight,
                color: Colors.grey[900],
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF0095F6),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: widget.previewHeight,
                color: Colors.grey[900],
                child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey, size: 50),
                ),
              ),
            ),
          ),
          // Clear button
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: () {
                // Clear the URL - caller should handle this
                widget.onUploadComplete?.call('');
              },
              icon: const Icon(Icons.close),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withOpacity(0.5),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    // Show placeholder
    return _buildPlaceholder();
  }

  Widget _buildVideoPreview() {
    return Container(
      height: widget.previewHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _videoController != null && _videoController!.value.isInitialized
          ? Stack(
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
                    onPressed: _clearSelection,
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.5),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                // Play/Pause button overlay
                Positioned.fill(
                  child: Center(
                    child: IconButton(
                      onPressed: () {
                        setState(() {
                          if (_videoController!.value.isPlaying) {
                            _videoController!.pause();
                          } else {
                            _videoController!.play();
                          }
                        });
                      },
                      icon: Icon(
                        _videoController!.value.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        size: 60,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF0095F6),
              ),
            ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: widget.previewHeight,
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
              widget.allowVideos ? Icons.add_photo_alternate : Icons.add_photo_alternate,
              size: 60,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 12),
            Text(
              widget.allowVideos
                  ? 'Tap to add photo or video'
                  : 'Tap to add a photo',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.allowImages) ...[
          ElevatedButton.icon(
            onPressed: _isUploading ? null : () => _pickMedia(),
            icon: const Icon(Icons.photo_library),
            label: const Text('Gallery'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D2D2D),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
        ],
        if (widget.allowVideos) ...[
          ElevatedButton.icon(
            onPressed: _isUploading ? null : () => _pickMedia(),
            icon: const Icon(Icons.videocam),
            label: const Text('Video'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D2D2D),
              foregroundColor: Colors.white,
            ),
          ),
        ],
        // If only images allowed and no videos
        if (widget.allowImages && !widget.allowVideos)
          ElevatedButton.icon(
            onPressed: _isUploading ? null : () => _pickMedia(),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Camera'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D2D2D),
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }

  Widget _buildUploadButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_selectedFile != null || 
                    (widget.initialImageUrl != null && widget.initialImageUrl!.isNotEmpty)) 
                    && !_isUploading 
            ? _uploadMedia
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0095F6),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: Text(
          widget.uploadButtonLabel,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: _uploadProgress > 0 ? _uploadProgress : null,
          backgroundColor: Colors.grey[800],
          valueColor: const AlwaysStoppedAnimation<Color>(
            Color(0xFF0095F6),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _uploadProgress > 0
              ? 'Uploading: ${(_uploadProgress * 100).toInt()}%'
              : 'Uploading...',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// A simple progress indicator widget for use in other parts of the app
class UploadProgressIndicator extends StatelessWidget {
  final double progress;
  final String? label;
  final Color? progressColor;
  final Color? backgroundColor;

  const UploadProgressIndicator({
    Key? key,
    required this.progress,
    this.label,
    this.progressColor,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: backgroundColor ?? Colors.grey[800],
          valueColor: AlwaysStoppedAnimation<Color>(
            progressColor ?? const Color(0xFF0095F6),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 4),
          Text(
            label!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
