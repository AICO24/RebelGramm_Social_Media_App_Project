import 'package:flutter/material.dart';

class StoryWidget extends StatelessWidget {
  final String imageUrl;
  final String username;

  const StoryWidget({Key? key, required this.imageUrl, required this.username}) : super(key: key);

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