// ==========================================
// ROLE: Member 2 - The Main Feed & Stories
// ==========================================
// A reusable UI widget that renders the circular avatars seen at the top of the Home feed.
// Uses a gradient border to signify unviewed stories, and handles tap events to immediately
// launch the full-screen Story Viewer or prompt the user to add a new story.

import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class StoryAvatar extends StatelessWidget {
  final String profilePic;
  final String username;
  final bool isCurrentUser;
  final bool hasStory;
  final VoidCallback? onTap;
  final VoidCallback? onAddStoryTap;

  const StoryAvatar({
    Key? key,
    required this.profilePic,
    required this.username,
    this.isCurrentUser = false,
    this.hasStory = false,
    this.onTap,
    this.onAddStoryTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(80),
              onTap: onTap,
              child: Stack(
                children: [
                   Container(
                     padding: EdgeInsets.all(3),
                     decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: hasStory
                            ? LinearGradient(
                                colors: [Color(0xFF833AB4), Color(0xFFE1306C), Color(0xFFF56040)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        border: !hasStory && !isCurrentUser
                            ? Border.all(color: Colors.grey.shade300, width: 1)
                            : null,
                     ),
                     child: Container(
                       padding: EdgeInsets.all(3),
                       decoration: BoxDecoration(
                         shape: BoxShape.circle,
                         color: Theme.of(context).scaffoldBackgroundColor,
                       ),
                       child: SizedBox(
                         width: 64,
                         height: 64,
                         child: FutureBuilder<String?>(
                           future: profilePic.isNotEmpty ? StorageService().getDownloadUrlSafe(profilePic) : Future.value(null),
                           builder: (context, snap) {
                             final url = snap.data;
                             if (url != null && url.isNotEmpty) {
                               return CircleAvatar(
                                 radius: 32,
                                 backgroundColor: Colors.grey.shade300,
                                 backgroundImage: NetworkImage(url),
                               );
                             }
                             return CircleAvatar(
                               radius: 32,
                               backgroundColor: Colors.grey.shade300,
                               child: Text(
                                 username.isNotEmpty ? username[0].toUpperCase() : '?',
                                 style: TextStyle(fontSize: 24, color: Colors.black87, fontWeight: FontWeight.w600),
                               ),
                             );
                           },
                         ),
                       ),
                     ),
                   ),
                   if (isCurrentUser)
                     Positioned(
                       bottom: 0,
                       right: 0,
                       child: GestureDetector(
                         onTap: onAddStoryTap ?? onTap,
                         child: Container(
                           padding: EdgeInsets.all(2),
                           decoration: BoxDecoration(
                             color: Color(0xFF0095F6),
                             shape: BoxShape.circle,
                             border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                           ),
                           child: Icon(Icons.add, color: Colors.white, size: 14),
                         ),
                       ),
                     ),
                ],
              ),
            ),
          ),
          SizedBox(height: 6),
          SizedBox(
            width: 70,
            child: Text(
              isCurrentUser ? 'Your Story' : username,
              style: TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
