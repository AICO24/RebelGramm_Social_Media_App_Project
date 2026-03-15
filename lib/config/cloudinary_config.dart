import '../services/cloudinary_service.dart';

/// Cloudinary configuration for the app
/// 
/// Replace these values with your own Cloudinary credentials:
/// 1. Go to https://cloudinary.com and create an account
/// 2. Find your cloud name in the dashboard
/// 3. Go to Settings > Upload and create an unsigned upload preset
/// 4. Replace the values below with your credentials
class AppCloudinaryConfig {
  /// Your Cloudinary cloud name
  /// Found in Cloudinary Dashboard
  static const String cloudName = 'ds6bfs15n';
  
  /// Unsigned upload preset name
  /// Created in Cloudinary Settings > Upload > Add upload preset
  /// Make sure to set "Signing Mode" to "Unsigned"
  static const String uploadPreset = 'flutter_upload';
  
  /// API Key (only needed for signed uploads)
  static const String? apiKey = null;
  
  /// API Secret (only needed for signed uploads)
  static const String? apiSecret = null;
  
  /// Folder path for posts
  static const String postsFolder = 'posts';
  
  /// Folder path for reels/videos
  static const String reelsFolder = 'reels';
  
  /// Folder path for stories
  static const String storiesFolder = 'stories';
  
  /// Folder path for profile pictures
  static const String profilesFolder = 'profiles';
  
  /// Maximum image width for uploads
  static const int maxImageWidth = 1920;
  
  /// Maximum image height for uploads
  static const int maxImageHeight = 1920;
  
  /// Image quality (0-100)
  static const int imageQuality = 85;
  
  /// Maximum video duration in seconds
  static const int maxVideoDurationSeconds = 90;
  
  /// Create the CloudinaryConfig object
  static CloudinaryConfig get config => CloudinaryConfig(
    cloudName: cloudName,
    uploadPreset: uploadPreset,
    apiKey: apiKey,
    apiSecret: apiSecret,
  );
  
  /// Check if Cloudinary is properly configured
  static bool get isConfigured => 
    cloudName.isNotEmpty && 
    cloudName != 'YOUR_CLOUD_NAME' && 
    uploadPreset.isNotEmpty && 
    uploadPreset != 'YOUR_UNSIGNED_PRESET';
}
