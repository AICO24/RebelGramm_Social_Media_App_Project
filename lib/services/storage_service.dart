import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/cloudinary_config.dart';
import 'cloudinary_service.dart' as cloudinary;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String folder = 'posts';

  bool get _cloudinaryConfigured {
    return AppCloudinaryConfig.isConfigured;
  }

  String _contentTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    return 'application/octet-stream';
  }

  Future<String> uploadPostImage(File file) async {
    // Prefer Cloudinary (free tier) when configured
    if (_cloudinaryConfigured) {
      try {
        final service = cloudinary.CloudinaryService(config: AppCloudinaryConfig.config);
        final result = await service.uploadImage(file, folder: AppCloudinaryConfig.postsFolder);
        return result.secureUrl;
      } catch (e) {
        if (kDebugMode) print('[StorageService] Cloudinary upload failed, falling back to Firebase: $e');
        // fall through to Firebase fallback
      }
    }

    final String id = Uuid().v4();
    final ref = _storage.ref().child('$folder/$id${_extensionForPath(file.path)}');
    final metadata = SettableMetadata(contentType: _contentTypeForPath(file.path));
    try {
      print('[StorageService] uploadPostImage -> uploading to: ${ref.fullPath}');
      print('[StorageService] uploadPostImage -> contentType: ${metadata.contentType}');
      final UploadTask uploadTask = ref.putFile(file, metadata);
      final TaskSnapshot snapshot = await uploadTask;

      print('[StorageService] uploadPostImage -> snapshot state: ${snapshot.state}');
      if (snapshot.metadata != null) print('[StorageService] uploadPostImage -> uploaded name: ${snapshot.metadata!.name}');

      if (snapshot.state == TaskState.success) {
        final m = await ref.getMetadata();
        print('[StorageService] uploadPostImage -> confirmed metadata name: ${m.name}, path: ${m.fullPath}');
        final url = await ref.getDownloadURL();
        print('[StorageService] uploadPostImage -> downloadURL: $url');
        return url;
      }

      throw FirebaseException(plugin: 'firebase_storage', message: 'Upload failed (state: ${snapshot.state})');
    } on FirebaseException catch (e, st) {
      print('[StorageService] FirebaseException during uploadPostImage: code=${e.code} message=${e.message}');
      print(st);
      rethrow;
    } catch (e, st) {
      print('[StorageService] Unknown exception during uploadPostImage: $e');
      print(st);
      rethrow;
    }
  }

  Future<String> uploadReelVideo(File file) async {
    // Prefer Cloudinary for video uploads when configured
    if (_cloudinaryConfigured) {
      try {
        final service = cloudinary.CloudinaryService(config: AppCloudinaryConfig.config);
        final result = await service.uploadVideo(file, folder: AppCloudinaryConfig.reelsFolder);
        return result.secureUrl;
      } catch (e) {
        if (kDebugMode) print('[StorageService] Cloudinary video upload failed, falling back to Firebase: $e');
      }
    }

    final String id = Uuid().v4();
    final ref = _storage.ref().child('reels/$id${_extensionForPath(file.path)}');
    final metadata = SettableMetadata(contentType: _contentTypeForPath(file.path));
    try {
      print('[StorageService] uploadReelVideo -> uploading to: ${ref.fullPath}');
      print('[StorageService] uploadReelVideo -> contentType: ${metadata.contentType}');
      final UploadTask uploadTask = ref.putFile(file, metadata);
      final TaskSnapshot snapshot = await uploadTask;
      print('[StorageService] uploadReelVideo -> snapshot state: ${snapshot.state}');
      if (snapshot.metadata != null) print('[StorageService] uploadReelVideo -> uploaded name: ${snapshot.metadata!.name}');

      if (snapshot.state == TaskState.success) {
        final m = await ref.getMetadata();
        print('[StorageService] uploadReelVideo -> confirmed metadata name: ${m.name}, path: ${m.fullPath}');
        final url = await ref.getDownloadURL();
        print('[StorageService] uploadReelVideo -> downloadURL: $url');
        return url;
      }

      throw FirebaseException(plugin: 'firebase_storage', message: 'Upload failed (state: ${snapshot.state})');
    } on FirebaseException catch (e, st) {
      print('[StorageService] FirebaseException during uploadReelVideo: code=${e.code} message=${e.message}');
      print(st);
      rethrow;
    } catch (e, st) {
      print('[StorageService] Unknown exception during uploadReelVideo: $e');
      print(st);
      rethrow;
    }
  }

  /// Upload a file to [folder] and return a HTTP download URL.
  Future<String> uploadFileAndGetUrl(File file, {required String folder}) async {
    // Ensure user is authenticated before attempting upload.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'unauthenticated',
        message: 'User must be signed in to upload files',
      );
    }

    final String id = Uuid().v4();
    final ref = _storage.ref().child('$folder/$id${_extensionForPath(file.path)}');
    final metadata = SettableMetadata(contentType: _contentTypeForPath(file.path));
    try {
      final UploadTask task = ref.putFile(file, metadata);
      final TaskSnapshot snap = await task;
      if (snap.state == TaskState.success) {
        await ref.getMetadata();
        return await ref.getDownloadURL();
      }
      throw FirebaseException(plugin: 'firebase_storage', message: 'Upload failed (state: ${snap.state})');
    } on FirebaseException catch (e) {
      if (kDebugMode) print('[StorageService] uploadFileAndGetUrl FirebaseException: ${e.code} ${e.message}');
      // Provide clearer guidance for App Check or rules issues
      if (e.code == 'permission-denied' || e.code == 'unauthenticated') {
        throw FirebaseException(
          plugin: 'firebase_storage',
          code: e.code,
          message: 'Upload blocked. Check Firebase Storage rules and App Check configuration: ${e.message}',
        );
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// Upload profile picture and return download URL.
  Future<String> uploadProfilePicture(File file) async {
    return uploadFileAndGetUrl(file, folder: 'profiles');
  }

  /// Safely returns a HTTP download URL for a stored asset.
  /// Accepts:
  /// - full http/https URLs (returned as-is)
  /// - gs:// URLs (resolved via refFromURL)
  /// - storage paths like 'posts/abc.jpg' (resolved via ref())
  /// Returns null when the object doesn't exist or caller lacks permission.
  Future<String?> getDownloadUrlSafe(String pathOrUrl) async {
    if (pathOrUrl.isEmpty) return null;
    final trimmed = pathOrUrl.trim();
    try {
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
      if (trimmed.startsWith('gs://')) {
        final ref = _storage.refFromURL(trimmed);
        return await ref.getDownloadURL();
      }
      final ref = _storage.ref().child(trimmed);
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      // object-not-found or permission-denied -> return null so UI can fallback
      if (kDebugMode) print('[StorageService] getDownloadUrlSafe failed: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      if (kDebugMode) print('[StorageService] getDownloadUrlSafe unexpected: $e');
      return null;
    }
  }

  // If you stored Cloudinary public IDs or full URLs, getDownloadUrlSafe will
  // already return them. If you want to derive a Cloudinary URL from a public id,
  // add a helper here.

  String _extensionForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return '.png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return '.jpg';
    if (lower.endsWith('.gif')) return '.gif';
    if (lower.endsWith('.mp4')) return '.mp4';
    return '';
  }
}

/// Legacy Cloudinary service for backward compatibility
/// @deprecated Use cloudinary_service.dart instead
class LegacyCloudinaryService {
  /// Upload image file to Cloudinary using an unsigned preset.
  static Future<String> uploadImage(File file, {required String cloudName, required String uploadPreset}) async {
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final respStr = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200 && streamed.statusCode != 201) {
      throw Exception('Cloudinary upload failed: ${streamed.statusCode} $respStr');
    }
    final data = json.decode(respStr) as Map<String, dynamic>;
    return data['secure_url'] as String;
  }

  /// Upload video file to Cloudinary.
  static Future<String> uploadVideo(File file, {required String cloudName, required String uploadPreset}) async {
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/video/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final respStr = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200 && streamed.statusCode != 201) {
      throw Exception('Cloudinary video upload failed: ${streamed.statusCode} $respStr');
    }
    final data = json.decode(respStr) as Map<String, dynamic>;
    return data['secure_url'] as String;
  }
}