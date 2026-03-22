// ==========================================
// ROLE: Member 6 - Artificial Intelligence & Notifications
// ==========================================
// Integrates an AI large language model into the social app.
// Manages the chat interface, loading indicators during API lag, local chat persistence,
// and applies the consistent 4-color gradient identity to separate AI features from normal networking.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/ai_provider.dart';
import '../providers/user_provider.dart';
import '../services/ai_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({Key? key}) : super(key: key);

  @override
  _ChatbotScreenState createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AIService _aiService = AIService();
  bool _isLoading = false;
  List<Map<String, String>> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChatHistory() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chat_history')
          .doc(user.id)
          .collection('messages')
          .orderBy('timestamp')
          .limit(50)
          .get();

      final List<Map<String, String>> loadedHistory = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['type'] == 'user') {
          loadedHistory.add({'user': data['message'] ?? ''});
        } else {
          loadedHistory.add({'ai': data['message'] ?? ''});
        }
      }
      
      if (!mounted) return;
      setState(() {
        _chatHistory = loadedHistory;
      });

      // Update provider
      final aiProvider = Provider.of<AIProvider>(context, listen: false);
      aiProvider.clearMessages();
      for (var msg in loadedHistory) {
        if (msg.containsKey('user')) {
          aiProvider.addUserMessage(msg['user']!);
        } else if (msg.containsKey('ai')) {
          aiProvider.addAIMessage(msg['ai']!);
        }
      }
    } catch (e) {
      // Silently fail - user can still chat
    }
  }

  Future<void> _saveMessage(String message, bool isUser) async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('chat_history')
          .doc(user.id)
          .collection('messages')
          .add({
        'message': message,
        'type': isUser ? 'user' : 'ai',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silently fail - chat still works
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    final aiProvider = Provider.of<AIProvider>(context, listen: false);
    aiProvider.addUserMessage(text);
    _saveMessage(text, true);
    
    setState(() {
      _chatHistory.add({'user': text});
      _messageController.clear();
      _isLoading = true;
    });

    try {
      final response = await _aiService.sendMessage(text, history: aiProvider.messages);
      aiProvider.addAIMessage(response);
      _saveMessage(response, false);
      
      setState(() {
        _chatHistory.add({'ai': response});
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
      Future.delayed(Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Widget _buildMessageBubble(Map<String, String> msg) {
    final bool fromUser = msg.containsKey('user');
    final String text = fromUser ? msg['user']! : msg['ai']!;
    
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: Column(
          crossAxisAlignment: fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: fromUser ? Color(0xFF0095F6) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(fromUser ? 18 : 4),
                  bottomRight: Radius.circular(fromUser ? 4 : 18),
                ),
                border: fromUser 
                  ? null 
                  : Border.all(color: Color(0xFFDBDBDB), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  color: fromUser ? Colors.white : Colors.black87,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = Provider.of<AIProvider>(context).messages;

    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Color(0xFF121212),
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF833AB4), Color(0xFFE1306C), Color(0xFFF56040), Color(0xFFF77737)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.smart_toy_outlined, color: Colors.white, size: 22),
            ),
            SizedBox(width: 10),
            Text(
              'RebelGram Assistant',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.white),
            color: Color(0xFF2C2C2C),
            onSelected: (value) {
              if (value == 'clear') {
                _clearChatHistory();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Clear conversation', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Chat messages
          if (messages.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF833AB4), Color(0xFFE1306C), Color(0xFFF56040), Color(0xFFF77737)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.smart_toy_outlined, color: Colors.white, size: 50),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Welcome to RebelGram Assistant!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Your chat history is saved. Ask me anything about RebelGram - tips, features, how-tos, and more!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    SizedBox(height: 32),
                    // Quick suggestions
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _quickSuggestion('How to post?'),
                        _quickSuggestion('How to add story?'),
                        _quickSuggestion('How to get more followers?'),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(vertical: 16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  return _buildMessageBubble(msg);
                },
              ),
            ),
          
          // Loading indicator
          if (_isLoading)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SpinKitThreeBounce(
                    color: Color(0xFF0095F6),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Typing...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          
          // Input area - RebelGram style
          Container(
            decoration: BoxDecoration(
              color: Color(0xFF121212),
              border: Border(
                top: BorderSide(color: Color(0xFF2C2C2C), width: 0.5),
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Message...',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        style: TextStyle(fontSize: 15, color: Colors.white),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF833AB4), Color(0xFFE1306C), Color(0xFFF56040), Color(0xFFF77737)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _isLoading ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearChatHistory() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) return;

    try {
      // Delete all messages from Firestore
      final batch = FirebaseFirestore.instance.batch();
      final snapshot = await FirebaseFirestore.instance
          .collection('chat_history')
          .doc(user.id)
          .collection('messages')
          .get();
      
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (!mounted) return;
      // Clear local state
      Provider.of<AIProvider>(context, listen: false).clearMessages();
      setState(() {
        _chatHistory = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chat history cleared')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear chat history')),
      );
    }
  }

  Widget _quickSuggestion(String text) {
    return GestureDetector(
      onTap: () {
        _messageController.text = text;
        _sendMessage();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}
