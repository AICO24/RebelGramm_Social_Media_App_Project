import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/user_model.dart';

class DiscoverPeopleScreen extends StatelessWidget {
  const DiscoverPeopleScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<UserProvider>(context).user;
    
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Discover People')),
        body: Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Discover People'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading suggestions'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final allUsers = snapshot.data!.docs
              .map((d) => UserModel.fromMap(d.data() as Map<String, dynamic>, d.id))
              .where((u) => u.id != currentUser.id)
              .toList();

          return ListView.builder(
            itemCount: allUsers.length,
            itemBuilder: (context, index) {
              final user = allUsers[index];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('followers')
                    .doc(currentUser.id)
                    .collection('following')
                    .doc(user.id)
                    .get(),
                builder: (context, followSnap) {
                  final isFollowing = followSnap.data?.exists ?? false;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user.profilePic.isNotEmpty 
                          ? NetworkImage(user.profilePic) 
                          : null,
                      child: user.profilePic.isEmpty
                          ? Text(user.username.isNotEmpty ? user.username[0].toUpperCase() : '?')
                          : null,
                    ),
                    title: Text(user.username),
                    subtitle: Text(user.email),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowing ? Colors.grey[800] : Color(0xFF0095F6),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        if (isFollowing) {
                          await FirebaseFirestore.instance.collection('followers').doc(currentUser.id).collection('following').doc(user.id).delete();
                          await FirebaseFirestore.instance.collection('followers').doc(user.id).collection('followers').doc(currentUser.id).delete();
                          (context as Element).markNeedsBuild();
                        } else {
                          await FirebaseFirestore.instance.collection('followers').doc(currentUser.id).collection('following').doc(user.id).set({'timestamp': FieldValue.serverTimestamp()});
                          await FirebaseFirestore.instance.collection('followers').doc(user.id).collection('followers').doc(currentUser.id).set({'timestamp': FieldValue.serverTimestamp()});
                          (context as Element).markNeedsBuild();
                        }
                      },
                      child: Text(isFollowing ? 'Following' : 'Follow'),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
