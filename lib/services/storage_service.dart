import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String folder = 'posts';

  Future<String> uploadPostImage(File file) async {
    String id = Uuid().v4();
    final ref = _storage.ref().child('$folder/$id.jpg');
    try {
      final task = await ref.putFile(file);
      if (task.state == TaskState.success) {
        return await ref.getDownloadURL();
      } else {
        throw Exception('Upload failed (state: ${task.state})');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String> uploadReelVideo(File file) async {
    String id = Uuid().v4();
    final ref = _storage.ref().child('reels/$id.mp4');
    try {
      final task = await ref.putFile(file);
      if (task.state == TaskState.success) {
        return await ref.getDownloadURL();
      } else {
        throw Exception('Upload failed (state: ${task.state})');
      }
    } catch (e) {
      rethrow;
    }
  }
}