import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class StoryAvatar extends StatelessWidget {
  final String profilePic;
  final String username;
  final bool isCurrentUser;
  final bool hasStory;
  final VoidCallback? onTap;

  const StoryAvatar({
    Key? key,
    required this.profilePic,
    required this.username,
    this.isCurrentUser = false,
    this.hasStory = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(80),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: Stack(
                  children: [
                    Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: hasStory
                            ? LinearGradient(
                                colors: [
                                  Color(0xFF833AB4),
                                  Color(0xFFE1306C),
                                  Color(0xFFF56040),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        border: !hasStory && !isCurrentUser
                            ? Border.all(color: Colors.grey.shade700, width: 1)
                            : null,
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
                                backgroundColor: Colors.grey[800],
                                backgroundImage: NetworkImage(url),
                              );
                            }
                            return CircleAvatar(
                              radius: 32,
                              backgroundColor: Colors.grey[800],
                              child: Text(
                                username.isNotEmpty ? username[0].toUpperCase() : '?',
                                style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (isCurrentUser)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Color(0xFF0095F6),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(Icons.add, color: Colors.white, size: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 6),
          SizedBox(
            width: 70,
            child: Text(
              isCurrentUser ? 'Your Story' : username,
              style: TextStyle(fontSize: 12, color: Colors.white),
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
