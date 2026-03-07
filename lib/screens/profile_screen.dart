import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/user_provider.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../screens/login_screen.dart';
import '../screens/add_post_screen.dart';
import '../models/post_model.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final PostService _postService = PostService();

  void _showEditProfileDialog(BuildContext context) {
    final user = Provider.of<UserProvider>(context, listen: false).user!;
    final profilePicController = TextEditingController(text: user.profilePic);
    final usernameController = TextEditingController(text: user.username);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text('Edit Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                  SizedBox(height: 24),
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[800],
                      backgroundImage: profilePicController.text.isNotEmpty ? NetworkImage(profilePicController.text) : null,
                      child: profilePicController.text.isEmpty ? Icon(Icons.person, size: 50, color: Colors.grey[400]) : null,
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(color: Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(8)),
                    child: TextField(
                      controller: profilePicController,
                      decoration: InputDecoration(
                        hintText: 'Profile Picture URL',
                        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        prefixIcon: Icon(Icons.image_outlined, color: Colors.grey[400], size: 20),
                      ),
                      style: TextStyle(fontSize: 14),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(color: Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(8)),
                    child: TextField(
                      controller: usernameController,
                      decoration: InputDecoration(
                        hintText: 'Username',
                        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        prefixIcon: Icon(Icons.alternate_email, color: Colors.grey[400], size: 20),
                      ),
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await FirebaseFirestore.instance.collection('users').doc(user.id).update({
                            'profilePic': profilePicController.text.trim(),
                            'username': usernameController.text.trim(),
                          });
                          final updatedUser = user.copyWith(
                            profilePic: profilePicController.text.trim(),
                            username: usernameController.text.trim(),
                          );
                          Provider.of<UserProvider>(context, listen: false).setUser(updatedUser);
                          if (!mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile updated!')));
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0095F6),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: Text('Save', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user!;
    
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Color(0xFF121212),
        elevation: 0,
        title: Text(user.username, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: Icon(Icons.add_box_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddPostScreen()))),
          IconButton(icon: Icon(Icons.menu), onPressed: () => _showLogoutMenu(context)),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Color(0xFF1E1E1E),
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 44, backgroundColor: Colors.grey[800], backgroundImage: user.profilePic.isNotEmpty ? NetworkImage(user.profilePic) : null, child: user.profilePic.isEmpty ? Icon(Icons.person, size: 44, color: Colors.grey[400]) : null),
                    SizedBox(width: 24),
                    Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_buildStatColumn('Posts', '0'), _buildStatColumn('Followers', '0'), _buildStatColumn('Following', '0')])),
                  ],
                ),
                SizedBox(height: 16),
                Align(alignment: Alignment.centerLeft, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user.username, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white)), SizedBox(height: 4), Text(user.email, style: TextStyle(color: Colors.grey[400], fontSize: 14))])),
                SizedBox(height: 16),
                SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => _showEditProfileDialog(context), style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), side: BorderSide(color: Color(0xFF444444))), child: Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white)))),
              ],
            ),
          ),
          Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<PostModel>>(
              stream: _postService.fetchPosts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: Color(0xFF0095F6)));
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading posts'));
                }
                
                final posts = snapshot.data?.where((p) => p.userId == user.id).toList() ?? [];
                    
                if (posts.isEmpty) {
                  return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt_outlined, size: 60, color: Colors.grey[500]), SizedBox(height: 16), Text('No posts yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[400])), SizedBox(height: 8), Text('Share your first photo!', style: TextStyle(fontSize: 14, color: Colors.grey[500]))]));
                }
                
                return GridView.builder(
                  padding: EdgeInsets.all(2),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return CachedNetworkImage(imageUrl: post.imageUrl, fit: BoxFit.cover, placeholder: (context, url) => Container(color: Colors.grey[200]), errorWidget: (context, url, error) => Container(color: Colors.grey[200], child: Icon(Icons.broken_image, color: Colors.grey[400])));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(children: [Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)), SizedBox(height: 4), Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14))]);
  }

  void _showLogoutMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text('Log out', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  await AuthService().signOut();
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
                },
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
