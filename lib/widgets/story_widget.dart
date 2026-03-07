import 'package:flutter/material.dart';

class StoryWidget extends StatelessWidget {
  final String imageUrl;
  final String username;

  StoryWidget({required this.imageUrl, required this.username});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(radius: 30, backgroundImage: NetworkImage(imageUrl)),
        SizedBox(height: 5),
        Text(username),
      ],
    );
  }
}