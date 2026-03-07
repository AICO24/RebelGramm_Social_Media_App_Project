import 'package:flutter/material.dart';

class AIProvider with ChangeNotifier {
  List<Map<String, String>> _messages = [];

  List<Map<String, String>> get messages => _messages;

  void addUserMessage(String msg) {
    _messages.add({'user': msg});
    notifyListeners();
  }

  void addAIMessage(String msg) {
    _messages.add({'ai': msg});
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }
}