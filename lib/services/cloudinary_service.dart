import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Callback type for upload progress updates
/// [progress] is a value between 0.0 and 1.0
typedef UploadProgressCallback = void Function(double progress);

/// Result of a Cloudinary upload operation
class CloudinaryUploadResult {
  /// The secure HTTPS URL of the uploaded media
  final String secureUrl;
  
  /// The public ID of the uploaded asset in Cloudinary
  final String publicId;
  
  /// The format of the uploaded file (e.g., 'jpg', 'mp4')
  final String format;
  
  /// The width of the image/video (for images/videos only)
  final int? width;
  
  /// The height of the image/video (for images/videos only)
  final int? height;
  
  /// The resource type (image, video, raw, etc.)
  final String resourceType;
  
  /// Original filename
  final String originalFilename;
  
  /// File size in bytes
  final int? bytes;

  CloudinaryUploadResult({
    required this.secureUrl,
    required this.publicId,
    required this.format,
    this.width,
    this.height,
    required this.resourceType,
    required this.originalFilename,
    this.bytes,
  });

  factory CloudinaryUploadResult.fromJson(Map<String, dynamic> json) {
    return CloudinaryUploadResult(
      secureUrl: json['secure_url'] as String,
      publicId: json['public_id'] as String,
      format: json['format'] as String,
      width: json['width'] as int?,
      height: json['height'] as int?,
      resourceType: json['resource_type'] as String,
      originalFilename: json['original_filename'] as String? ?? '',
      bytes: json['bytes'] as int?,
    );
  }
}

/// Configuration class for Cloudinary
class CloudinaryConfig {
  /// Cloud name from your Cloudinary dashboard
  final String cloudName;
  
  /// Unsigned upload preset (created in Cloudinary dashboard)
  /// For unsigned uploads, create an upload preset in Cloudinary Settings > Upload
  final String uploadPreset;
  
  /// Optional: API key (only needed for signed uploads)
  final String? apiKey;
  
  /// Optional: API secret (only needed for signed uploads)
  final String? apiSecret;

  const CloudinaryConfig({
    required this.cloudName,
    required this.uploadPreset,
    this.apiKey,
    this.apiSecret,
  });

  /// Check if the configuration is valid
  bool get isValid =>
      cloudName.isNotEmpty &&
      uploadPreset.isNotEmpty &&
      cloudName != 'YOUR_CLOUD_NAME' &&
      uploadPreset != 'YOUR_UNSIGNED_PRESET';
}

/// Service class for Cloudinary uploads
/// 
/// This service provides methods to upload images and videos to Cloudinary
/// with progress tracking and proper error handling.
/// 
/// To use this service:
/// 1. Create a Cloudinary account at https://cloudinary.com
/// 2. Get your cloud name from the Cloudinary dashboard
/// 3. Create an unsigned upload preset in Settings > Upload
///    - Add an upload preset name
///    - Set signing mode to "Unsigned"
///    - Configure allowed formats and transformations as needed
/// 
/// Example usage:
/// ```dart
/// final config = CloudinaryConfig(
///   cloudName: 'your-cloud-name',
///   uploadPreset: 'your-unsigned-preset',
/// );
/// 
/// final service = CloudinaryService(config: config);
/// 
/// // Upload with progress tracking
/// final result = await service.uploadImage(
///   file,
///   onProgress: (progress) => print('Upload progress: ${progress * 100}%'),
/// );
/// 
/// print('Uploaded to: ${result.secureUrl}');
/// ```
class CloudinaryService {
  final CloudinaryConfig config;
  
  // Base URLs for Cloudinary API
  static const String _baseUrl = 'https://api.cloudinary.com/v1_1';
  
  CloudinaryService({required this.config});

  /// Determine the resource type based on file extension
  String _getResourceType(String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm')) {
      return 'video';
    }
    return 'image';
  }

  /// Get the content type based on file extension
  String _getContentType(String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.avi')) return 'video/x-msvideo';
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    if (lower.endsWith('.webm')) return 'video/webm';
    return 'application/octet-stream';
  }

  /// Upload an image file to Cloudinary
  /// 
  /// [file] - The image file to upload
  /// [onProgress] - Optional callback for upload progress (0.0 to 1.0)
  /// [folder] - Optional folder in Cloudinary to store the image
  /// [publicId] - Optional custom public ID for the image
  /// 
  /// Returns a [CloudinaryUploadResult] containing the upload details
  /// 
  /// Throws [CloudinaryException] if the upload fails
  Future<CloudinaryUploadResult> uploadImage(
    File file, {
    UploadProgressCallback? onProgress,
    String? folder,
    String? publicId,
  }) async {
    return _upload(
      file: file,
      resourceType: 'image',
      onProgress: onProgress,
      folder: folder,
      publicId: publicId,
    );
  }

  /// Upload a video file to Cloudinary
  /// 
  /// [file] - The video file to upload
  /// [onProgress] - Optional callback for upload progress (0.0 to 1.0)
  /// [folder] - Optional folder in Cloudinary to store the video
  /// [publicId] - Optional custom public ID for the video
  /// 
  /// Returns a [CloudinaryUploadResult] containing the upload details
  /// 
  /// Throws [CloudinaryException] if the upload fails
  Future<CloudinaryUploadResult> uploadVideo(
    File file, {
    UploadProgressCallback? onProgress,
    String? folder,
    String? publicId,
  }) async {
    return _upload(
      file: file,
      resourceType: 'video',
      onProgress: onProgress,
      folder: folder,
      publicId: publicId,
    );
  }

  /// Upload a media file (auto-detect type based on extension)
  /// 
  /// [file] - The file to upload
  /// [onProgress] - Optional callback for upload progress
  /// [folder] - Optional folder in Cloudinary
  /// [publicId] - Optional custom public ID
  /// 
  /// Returns a [CloudinaryUploadResult]
  Future<CloudinaryUploadResult> uploadMedia(
    File file, {
    UploadProgressCallback? onProgress,
    String? folder,
    String? publicId,
  }) async {
    final resourceType = _getResourceType(file.path);
    return _upload(
      file: file,
      resourceType: resourceType,
      onProgress: onProgress,
      folder: folder,
      publicId: publicId,
    );
  }

  /// Internal method to handle the upload request
  Future<CloudinaryUploadResult> _upload({
    required File file,
    required String resourceType,
    UploadProgressCallback? onProgress,
    String? folder,
    String? publicId,
  }) async {
    // Validate configuration
    if (!config.isValid) {
      throw CloudinaryException(
        'Cloudinary is not properly configured. '
        'Please set your cloud name and upload preset.',
        statusCode: 0,
      );
    }

    // Validate file exists
    if (!await file.exists()) {
      throw CloudinaryException(
        'File does not exist: ${file.path}',
        statusCode: 0,
      );
    }

    // Build the API URL
    final uri = Uri.parse('$_baseUrl/${config.cloudName}/$resourceType/upload');

    // Build the request
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = config.uploadPreset;

    // Add optional fields
    if (folder != null && folder.isNotEmpty) {
      request.fields['folder'] = folder;
    }
    if (publicId != null && publicId.isNotEmpty) {
      request.fields['public_id'] = publicId;
    }

    // Add the file
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: file.path.split('/').last,
      ),
    );

    try {
      // Send the request
      final streamedResponse = await request.send();
      
      // Report 100% progress when response is received
      onProgress?.call(1.0);
      
      // Get the response body
      final responseStr = await streamedResponse.stream.bytesToString();
      
      // Check for errors
      if (streamedResponse.statusCode != 200 && streamedResponse.statusCode != 201) {
        _handleErrorResponse(responseStr, streamedResponse.statusCode);
      }
      
      // Parse the response
      final data = json.decode(responseStr) as Map<String, dynamic>;
      
      if (kDebugMode) {
        print('[CloudinaryService] Upload successful: ${data['secure_url']}');
        print('[CloudinaryService] Public ID: ${data['public_id']}');
      }
      
      return CloudinaryUploadResult.fromJson(data);
      
    } on http.ClientException catch (e) {
      throw CloudinaryException(
        'Network error: ${e.message}',
        statusCode: 0,
      );
    } catch (e) {
      if (e is CloudinaryException) rethrow;
      throw CloudinaryException(
        'Unexpected error during upload: $e',
        statusCode: 0,
      );
    }
  }

  /// Handle error responses from Cloudinary
  void _handleErrorResponse(String responseStr, int statusCode) {
    try {
      final errorData = json.decode(responseStr) as Map<String, dynamic>;
      final errorMessage = errorData['error']?['message'] ?? 
                           errorData['error'] ?? 
                           'Unknown error';
      throw CloudinaryException(errorMessage.toString(), statusCode: statusCode);
    } catch (e) {
      if (e is CloudinaryException) rethrow;
      throw CloudinaryException(
        'Upload failed with status $statusCode: $responseStr',
        statusCode: statusCode,
      );
    }
  }

  /// Generate a transformation URL for the uploaded media
  /// 
  /// Example:
  /// ```dart
  /// final result = await service.uploadImage(file);
  /// final thumbnailUrl = service.getTransformedUrl(
  ///   result.secureUrl,
  ///   width: 200,
  ///   height: 200,
  ///   crop: 'fill',
  ///   gravity: 'face',
  /// );
  /// ```
  String getTransformedUrl(
    String sourceUrl, {
    int? width,
    int? height,
    String? crop,
    String? gravity,
    int? quality,
    String? format,
  }) {
    // Parse the source URL to extract public ID
    final uri = Uri.parse(sourceUrl);
    final pathSegments = uri.path.split('/');
    
    // Find the upload segment and get everything after it
    final uploadIndex = pathSegments.indexOf('upload');
    if (uploadIndex == -1 || uploadIndex >= pathSegments.length - 1) {
      return sourceUrl; // Return original if can't parse
    }
    
    // Build transformation string
    final transformations = <String>[];
    
    if (width != null) transformations.add('w_$width');
    if (height != null) transformations.add('h_$height');
    if (crop != null) transformations.add('c_$crop');
    if (gravity != null) transformations.add('g_$gravity');
    if (quality != null) transformations.add('q_${quality is String ? quality : quality}');
    if (format != null) transformations.add('f_$format');
    
    // Reconstruct URL
    final baseSegments = pathSegments.sublist(0, uploadIndex + 1);
    final fileSegments = pathSegments.sublist(uploadIndex + 1);
    
    final transformationStr = transformations.isNotEmpty 
        ? '${transformations.join(',')}/' 
        : '';
    
    final newPath = [...baseSegments, transformationStr, ...fileSegments].join('/');
    
    return uri.replace(path: newPath).toString();
  }

  /// Generate a thumbnail URL for videos
  String getVideoThumbnail(String videoUrl, {int width = 300}) {
    return getTransformedUrl(
      videoUrl,
      width: width,
      crop: 'scale',
      format: 'jpg',
    );
  }

  /// Generate a profile picture URL with face detection and cropping
  String getProfilePictureUrl(String imageUrl, {int size = 150}) {
    return getTransformedUrl(
      imageUrl,
      width: size,
      height: size,
      crop: 'fill',
      gravity: 'face',
    );
  }

  /// Generate a post image URL optimized for display
  String getPostImageUrl(String imageUrl, {int width = 800}) {
    return getTransformedUrl(
      imageUrl,
      width: width,
      quality: 80,
      format: 'auto',
    );
  }
}

/// Exception class for Cloudinary errors
class CloudinaryException implements Exception {
  final String message;
  final int statusCode;

  CloudinaryException(this.message, {required this.statusCode});

  @override
  String toString() => 'CloudinaryException: $message (status: $statusCode)';
}
