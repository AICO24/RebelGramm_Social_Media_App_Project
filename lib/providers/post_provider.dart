import 'package:flutter/material.dart';
import '../models/post_model.dart';

class PostProvider with ChangeNotifier {
  List<PostModel> _posts = [];

  List<PostModel> get posts => _posts;

  void setPosts(List<PostModel> posts) {
    _posts = posts;
    notifyListeners();
  }

  void addPost(PostModel post) {
    _posts.insert(0, post);
    notifyListeners();
  }
}