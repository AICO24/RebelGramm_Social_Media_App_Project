// ==========================================
// ROLE: Member 5 - Real-time Messaging
// ==========================================
// The Inbox handles individual private chats between followers.
// It leverages real-time Snapshots to instantly render new incoming messages without needing
// to pull-to-refresh. Features the New Message UI to filter connections and spawn ChatScreens.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/user_provider.dart';
import '../services/message_service.dart';
import '../models/message_model.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({Key? key}) : super(key: key);

  @override
  _InboxScreenState createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final MessageService _messageService = MessageService();

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<UserProvider>(context).user;
    
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: Color(0xFF121212),
          title: Text('Messages', style: TextStyle(color: Colors.white)),
          iconTheme: IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: Center(
          child: Text(
            'Please sign in to view messages',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Color(0xFF121212),
        title: Text('Messages', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => _showNewMessageDialog(context, currentUser.id),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _messageService.getConversations(currentUser.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mail_outline,
                    size: 80,
                    color: Colors.grey[600],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[400],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start a conversation with your followers!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showNewMessageDialog(context, currentUser.id),
                    icon: Icon(Icons.send),
                    label: Text('New Message'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0095F6),
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            );
          }

          final conversations = snapshot.data!;
          
          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conv = conversations[index];
              return _ConversationTile(
                userId: conv['userId'],
                lastMessage: conv['lastMessage'] ?? '',
                timestamp: conv['timestamp'] ?? DateTime.now(),
                currentUserId: currentUser.id,
                onTap: () => _openChat(context, currentUser.id, conv['userId']),
              );
            },
          );
        },
      ),
    );
  }

  void _showNewMessageDialog(BuildContext context, String currentUserId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1E1E1E),
      isScrollControlled: true,
      builder: (context) {
        return _NewMessageSheet(currentUserId: currentUserId);
      },
    );
  }

  void _openChat(BuildContext context, String currentUserId, String otherUserId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(currentUserId: currentUserId, otherUserId: otherUserId),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String userId;
  final String lastMessage;
  final DateTime timestamp;
  final String currentUserId;
  final VoidCallback onTap;

  _ConversationTile({
    required this.userId,
    required this.lastMessage,
    required this.timestamp,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        String username = 'User';
        String profilePic = '';
        
        if (snapshot.hasData && snapshot.data != null) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          username = data?['username'] ?? 'User';
          profilePic = data?['profilePic'] ?? '';
        }

        return ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey[800],
            backgroundImage: profilePic.isNotEmpty ? NetworkImage(profilePic) : null,
            child: profilePic.isEmpty
                ? Text(
                    username.isNotEmpty ? username[0].toUpperCase() : '?',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  )
                : null,
          ),
          title: Text(
            username,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            lastMessage,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            _formatTime(timestamp),
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inDays > 0) {
      return '${diff.inDays}d';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m';
    } else {
      return 'Now';
    }
  }
}

class _NewMessageSheet extends StatefulWidget {
  final String currentUserId;

  const _NewMessageSheet({Key? key, required this.currentUserId}) : super(key: key);

  @override
  _NewMessageSheetState createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends State<_NewMessageSheet> {
  String _searchQuery = '';
  List<Map<String, dynamic>> _followersData = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFollowers();
  }

  Future<void> _loadFollowers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .collection('following')
        .get();

    List<Map<String, dynamic>> loadedData = [];
    for (var doc in snapshot.docs) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(doc.id).get();
        if (userDoc.exists) {
            final data = userDoc.data()!;
            data['id'] = userDoc.id; // Store ID for chat navigation
            loadedData.add(data);
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _followersData = loadedData;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'New Message',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Color(0xFF2C2C2C),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search followers...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
              ),
              style: TextStyle(color: Colors.white),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Following',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: Color(0xFF0095F6)))
                : ListView.builder(
                    itemCount: _followersData.length,
                    itemBuilder: (context, index) {
                      final data = _followersData[index];
                      final username = data['username'] ?? 'User';
                      final profilePic = data['profilePic'] ?? '';
                      
                      if (_searchQuery.isNotEmpty && 
                          !username.toLowerCase().contains(_searchQuery)) {
                        return SizedBox.shrink();
                      }

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: profilePic.isNotEmpty 
                              ? NetworkImage(profilePic) 
                              : null,
                          backgroundColor: Colors.grey[800],
                          child: profilePic.isEmpty
                              ? Text(username.isNotEmpty ? username[0].toUpperCase() : '?', 
                                  style: TextStyle(color: Colors.white))
                              : null,
                        ),
                        title: Text(username, style: TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                currentUserId: widget.currentUserId,
                                otherUserId: data['id'],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String currentUserId;
  final String otherUserId;

  const ChatScreen({Key? key, required this.currentUserId, required this.otherUserId}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final MessageService _messageService = MessageService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _otherUsername = 'User';
  String _otherProfilePic = '';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadOtherUser();
  }

  Future<void> _loadOtherUser() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.otherUserId)
        .get();
    
    if (doc.exists && mounted) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        _otherUsername = data['username'] ?? 'User';
        _otherProfilePic = data['profilePic'] ?? '';
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Color(0xFF121212),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[800],
              backgroundImage: _otherProfilePic.isNotEmpty 
                  ? NetworkImage(_otherProfilePic) 
                  : null,
              child: _otherProfilePic.isEmpty
                  ? Text(
                      _otherUsername.isNotEmpty ? _otherUsername[0].toUpperCase() : '?',
                      style: TextStyle(color: Colors.white),
                    )
                  : null,
            ),
            SizedBox(width: 12),
            Text(
              _otherUsername,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _messageService.getMessages(widget.currentUserId, widget.otherUserId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(color: Color(0xFF0095F6)),
                  );
                }

                final messages = snapshot.data!;
                
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey[600]),
                        SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(color: Colors.grey[500], fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Send a message to start the conversation!',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == widget.currentUserId;
                    
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        margin: EdgeInsets.only(bottom: 8),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? Color(0xFF0095F6) : Color(0xFF2C2C2C),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          msg.message,
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFF1E1E1E),
              border: Border(top: BorderSide(color: Colors.grey[800]!)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        filled: true,
                        fillColor: Color(0xFF2C2C2C),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF0095F6),
                      shape: BoxShape.circle,
                    ),
                      child: _isSending
                          ? Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 20, 
                                height: 20, 
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                            )
                          : IconButton(
                              icon: Icon(Icons.send, color: Colors.white),
                              onPressed: _sendMessage,
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

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      await _messageService.sendMessage(
        widget.currentUserId,
        widget.otherUserId,
        text,
      ).timeout(const Duration(seconds: 1), onTimeout: () => null);
      
      _messageController.clear();
      
      // Scroll to bottom
      Future.delayed(Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }
}
