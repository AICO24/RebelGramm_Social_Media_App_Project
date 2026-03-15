import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

/// Enum representing the type of media that can be picked
enum MediaType {
  image,
  video,
  any,
}

/// Result of a media picking operation
class MediaPickResult {
  /// The selected file
  final File file;
  
  /// The type of media that was picked
  final MediaType mediaType;
  
  /// Original path from the picker
  final String originalPath;

  MediaPickResult({
    required this.file,
    required this.mediaType,
    required this.originalPath,
  });

  /// Check if the picked file is an image
  bool get isImage => mediaType == MediaType.image;
  
  /// Check if the picked file is a video
  bool get isVideo => mediaType == MediaType.video;
}

/// Service for picking images and videos from device
/// 
/// This service wraps the image_picker package and provides a unified
/// interface for picking media from either the gallery or camera.
/// 
/// Example usage:
/// ```dart
/// final picker = MediaPickerService();
/// 
/// // Pick image from gallery
/// final result = await picker.pickImage();
/// if (result != null) {
///   print('Picked image: ${result.file.path}');
/// }
/// 
/// // Pick video from camera
/// final videoResult = await picker.pickVideo(fromCamera: true);
/// if (videoResult != null) {
///   print('Picked video: ${videoResult.file.path}');
/// }
/// ```
class MediaPickerService {
  final ImagePicker _picker = ImagePicker();

  /// Pick an image from the gallery
  /// 
  /// [maxWidth] - Maximum width of the image (optional)
  /// [maxHeight] - Maximum height of the image (optional)
  /// [imageQuality] - Quality of the image (0-100, optional)
  /// 
  /// Returns [MediaPickResult] if successful, null if cancelled
  Future<MediaPickResult?> pickImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality ?? 85,
      );
      
      if (picked == null) return null;
      
      return MediaPickResult(
        file: File(picked.path),
        mediaType: MediaType.image,
        originalPath: picked.path,
      );
    } catch (e) {
      if (kDebugMode) print('[MediaPickerService] Error picking image: $e');
      rethrow;
    }
  }

  /// Take a photo with the camera
  /// 
  /// [maxWidth] - Maximum width of the image (optional)
  /// [maxHeight] - Maximum height of the image (optional)
  /// [imageQuality] - Quality of the image (0-100, optional)
  /// 
  /// Returns [MediaPickResult] if successful, null if cancelled
  Future<MediaPickResult?> takePhoto({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality ?? 85,
      );
      
      if (picked == null) return null;
      
      return MediaPickResult(
        file: File(picked.path),
        mediaType: MediaType.image,
        originalPath: picked.path,
      );
    } catch (e) {
      if (kDebugMode) print('[MediaPickerService] Error taking photo: $e');
      rethrow;
    }
  }

  /// Pick a video from the gallery
  /// 
  /// [maxDuration] - Maximum duration of the video (optional)
  /// 
  /// Returns [MediaPickResult] if successful, null if cancelled
  Future<MediaPickResult?> pickVideo({Duration? maxDuration}) async {
    try {
      final XFile? picked = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: maxDuration,
      );
      
      if (picked == null) return null;
      
      return MediaPickResult(
        file: File(picked.path),
        mediaType: MediaType.video,
        originalPath: picked.path,
      );
    } catch (e) {
      if (kDebugMode) print('[MediaPickerService] Error picking video: $e');
      rethrow;
    }
  }

  /// Record a video with the camera
  /// 
  /// [maxDuration] - Maximum duration of the video (optional)
  /// 
  /// Returns [MediaPickResult] if successful, null if cancelled
  Future<MediaPickResult?> recordVideo({Duration? maxDuration}) async {
    try {
      final XFile? picked = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: maxDuration,
      );
      
      if (picked == null) return null;
      
      return MediaPickResult(
        file: File(picked.path),
        mediaType: MediaType.video,
        originalPath: picked.path,
      );
    } catch (e) {
      if (kDebugMode) print('[MediaPickerService] Error recording video: $e');
      rethrow;
    }
  }

  /// Pick media (image or video) from gallery
  /// 
  /// Determines whether the file is an image or video based on extension
  /// 
  /// Returns [MediaPickResult] if successful, null if cancelled
  Future<MediaPickResult?> pickMedia({double? maxWidth, double? maxHeight}) async {
    try {
      // First try to pick an image
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );
      
      if (image != null) {
        return MediaPickResult(
          file: File(image.path),
          mediaType: MediaType.image,
          originalPath: image.path,
        );
      }
      
      // If no image, try to pick a video
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      
      if (video != null) {
        return MediaPickResult(
          file: File(video.path),
          mediaType: MediaType.video,
          originalPath: video.path,
        );
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) print('[MediaPickerService] Error picking media: $e');
      rethrow;
    }
  }

  /// Show a bottom sheet for selecting image source
  /// 
  /// Returns [MediaPickResult] if successful, null if cancelled or error
  Future<MediaPickResult?> showImagePicker({
    required BuildContext context,
    bool allowGallery = true,
    bool allowCamera = true,
  }) async {
    return showModalBottomSheet<MediaPickResult>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (allowGallery)
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white),
                title: const Text(
                  'Choose from gallery',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(ctx, await pickImage());
                },
              ),
            if (allowCamera)
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white),
                title: const Text(
                  'Take a photo',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(ctx, await takePhoto());
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Show a bottom sheet for selecting video source
  /// 
  /// Returns [MediaPickResult] if successful, null if cancelled or error
  Future<MediaPickResult?> showVideoPicker({
    required BuildContext context,
    bool allowGallery = true,
    bool allowCamera = true,
    Duration? maxDuration,
  }) async {
    return showModalBottomSheet<MediaPickResult>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (allowGallery)
              ListTile(
                leading: const Icon(Icons.video_library, color: Colors.white),
                title: const Text(
                  'Choose from gallery',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(ctx, await pickVideo(maxDuration: maxDuration));
                },
              ),
            if (allowCamera)
              ListTile(
                leading: const Icon(Icons.videocam, color: Colors.white),
                title: const Text(
                  'Record a video',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(ctx, await recordVideo(maxDuration: maxDuration));
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Show a comprehensive media picker with all options
  /// 
  /// [context] - BuildContext for showing bottom sheet
  /// [allowImages] - Whether to allow image picking
  /// [allowVideos] - Whether to allow video picking
  /// [fromGallery] - Whether to allow picking from gallery
  /// [fromCamera] - Whether to allow picking from camera
  /// [maxVideoDuration] - Maximum video duration
  /// 
  /// Returns [MediaPickResult] if successful, null if cancelled
  Future<MediaPickResult?> showMediaSourcePicker({
    required BuildContext context,
    bool allowImages = true,
    bool allowVideos = true,
    bool fromGallery = true,
    bool fromCamera = true,
    Duration? maxVideoDuration,
  }) async {
    // If only images allowed, use image picker
    if (allowImages && !allowVideos) {
      return showImagePicker(
        context: context,
        allowGallery: fromGallery,
        allowCamera: fromCamera,
      );
    }
    
    // If only videos allowed, use video picker
    if (!allowImages && allowVideos) {
      return showVideoPicker(
        context: context,
        allowGallery: fromGallery,
        allowCamera: fromCamera,
        maxDuration: maxVideoDuration,
      );
    }
    
    // Show combined picker
    return showModalBottomSheet<MediaPickResult>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (allowImages && fromGallery)
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white),
                title: const Text(
                  'Choose from gallery',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(ctx, await pickImage());
                },
              ),
            if (allowImages && fromCamera)
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white),
                title: const Text(
                  'Take a photo',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(ctx, await takePhoto());
                },
              ),
            if (allowVideos && fromGallery)
              ListTile(
                leading: const Icon(Icons.video_library, color: Colors.white),
                title: const Text(
                  'Choose video from gallery',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(ctx, await pickVideo(maxDuration: maxVideoDuration));
                },
              ),
            if (allowVideos && fromCamera)
              ListTile(
                leading: const Icon(Icons.videocam, color: Colors.white),
                title: const Text(
                  'Record a video',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(ctx, await recordVideo(maxDuration: maxVideoDuration));
                },
              ),
          ],
        ),
      ),
    );
  }
}
