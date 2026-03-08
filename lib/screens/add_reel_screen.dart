import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../models/reel_model.dart';
import '../services/reel_service.dart';
import '../services/storage_service.dart';
import '../providers/user_provider.dart';

class AddReelScreen extends StatefulWidget {
  @override
  _AddReelScreenState createState() => _AddReelScreenState();
}

class _AddReelScreenState extends State<AddReelScreen> {
  final TextEditingController captionController = TextEditingController();
  File? _selectedFile;
  final ImagePicker _picker = ImagePicker();
  VideoPlayerController? _videoController;
  bool _loading = false;

  @override
  void dispose() {
    captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final picked = await _picker.pickVideo(source: source, maxDuration: Duration(seconds: 90));
      if (picked == null) return;
      _selectedFile = File(picked.path);
      _videoController?.dispose();
      _videoController = VideoPlayerController.file(_selectedFile!)..initialize().then((_) {
        setState(() {});
        _videoController?.setLooping(true);
        _videoController?.play();
      });
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick video: $e')));
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
              leading: Icon(Icons.video_library),
              title: Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickVideo(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.videocam),
              title: Text('Record a video'),
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
      final videoUrl = await StorageService().uploadReelVideo(_selectedFile!);
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reel uploaded')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('New Reel'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _uploadReel,
            child: Text('Share', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            if (_videoController != null && _videoController!.value.isInitialized)
              AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              )
            else
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam, size: 60, color: Colors.grey[600]),
                      SizedBox(height: 8),
                      Text('Pick or record a short video (max 90s)', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                ),
              ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickVideo(ImageSource.gallery),
                  icon: Icon(Icons.video_library),
                  label: Text('Gallery'),
                ),
                SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _pickVideo(ImageSource.camera),
                  icon: Icon(Icons.videocam),
                  label: Text('Camera'),
                ),
              ],
            ),
            SizedBox(height: 16),
            TextField(
              controller: captionController,
              maxLines: 4,
              decoration: InputDecoration(hintText: 'Write a caption...'),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _uploadReel,
                child: _loading ? CircularProgressIndicator() : Text('Post Reel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
