import 'dart:convert';
import 'package:http/http.dart' as http;

/// AI Service for RebelGram chatbot functionality.
/// Uses a hybrid approach: tries external APIs first, falls back to local knowledge base.
class AIService {
  // Toggle between using external API or local knowledge base
  // Set to false to use only local responses (more reliable)
  static const bool _useExternalAPI = false;
  
  // HuggingFace API token - replace with your own or use environment variables
  // DO NOT hardcode tokens in source code
  static const String _hfToken = '';
  
  // Local knowledge base for RebelGram-related questions
  static final Map<String, String> _rebelGramKnowledgeBase = {
    'hello': 'Hey there! 👋 I\'m your RebelGram assistant. Ask me anything about RebelGram features, tips, or how to use the app!',
    'hi': 'Hi! 👋 How can I help you with RebelGram today?',
    'hey': 'Hey there! 👋 What would you like to know about RebelGram?',
    'how to post': 'To post on RebelGram:\n1. Tap the + icon at the bottom center\n2. Choose a photo or video from your gallery or take a new one\n3. Apply filters or edit\n4. Add a caption, hashtags, and location\n5. Tap Share to post!',
    'how to post a photo': 'To post a photo:\n1. Tap the + icon at the bottom\n2. Select your photo from gallery\n3. Tap Next\n4. Add filters or edit\n5. Write a caption\n6. Tap Share',
    'how to add story': 'To add a Story:\n1. Swipe right from your feed or tap Your Story\n2. Take a photo/video or choose from gallery\n3. Add text, stickers, or effects\n4. Tap Send to share to your story',
    'how to go live': 'To go Live:\n1. Swipe right or tap the camera\n2. Swipe to Live at the bottom\n3. Tap Start Live Video\n4. When done, tap End to finish',
    'how to send message': 'To send a DM:\n1. Tap the paper plane icon at the top right\n2. Tap the pencil icon\n3. Select who you want to message\n4. Type your message and send!',
    'how to follow': 'To follow someone:\n1. Search for their username or find them in suggestions\n2. Tap the Follow button on their profile\n3. You\'ll see their posts in your feed',
    'how to unfollow': 'To unfollow someone:\n1. Go to their profile\n2. Tap Following button\n3. It will change to Follow',
    'how to like': 'To like a post:\n1. Double-tap the photo, OR\n2. Tap the heart icon below the post',
    'how to comment': 'To comment:\n1. Tap the speech bubble below a post\n2. Type your comment\n3. Tap Post to share',
    'how to share post': 'To share a post:\n1. Tap the paper plane icon below a post\n2. Select recipients or share to story\n3. Add a message if desired',
    'how to change profile picture': 'To change your profile picture:\n1. Go to your profile\n2. Tap Edit Profile\n3. Tap Change Photo\n4. Choose Take Photo or Choose from Library\n5. Crop and tap Done',
    'how to make account private': 'To make your account private:\n1. Go to your profile\n2. Tap the menu (three lines)\n3. Go to Settings\n4. Tap Privacy\n5. Toggle Private Account on',
    'what is reels': 'Reels are short, entertaining videos (up to 90 seconds). To create one:\n1. Swipe right to open camera\n2. Select Reels at the bottom\n3. Record or upload video\n4. Add music and effects\n5. Tap Share to Reels',
    'how to use hashtags': 'Hashtags help your posts reach more people. Add up to 30 hashtags in your caption or comments. Use relevant ones like #photography #nature etc.',
    'how to block': 'To block someone:\n1. Go to their profile\n2. Tap the three dots menu\n3. Tap Block\n4. Confirm the block',
    'how to report': 'To report a post or account:\n1. Tap the three dots on the post/profile\n2. Tap Report\n3. Follow the prompts',
    'how to remove follower': 'To remove a follower:\n1. Go to your profile\n2. Tap Followers\n3. Find the person\n4. Tap Remove next to their name',
    'followers': 'Followers are people who follow your account and see your posts in their feed. You can see your follower count on your profile.',
    'following': 'Following refers to accounts you follow. Their posts appear in your home feed.',
    'dm': 'DM stands for Direct Message - a private message sent to other RebelGram users.',
    'story': 'Stories are photos/videos that disappear after 24 hours. They appear at the top of your feed.',
    'reels': 'Reels are short videos (up to 90 seconds) that can be discovered by a wider audience through the Reels tab.',
    'igtv': 'IGTV is for longer videos (up to 60 minutes). It\'s being integrated with Reels.',
    'live': 'Live videos let you stream in real-time. Your followers get notified when you go live.',
    'bio': 'Your bio is the short description on your profile. Tap Edit Profile to change it!',
    'highlight': 'Story Highlights keep your stories on your profile permanently. Create them from your story archive.',
    'save': 'To save a post:\n1. Tap the bookmark icon below a post\n2. The post is saved to your Saved collection',
    'archive': 'Archive hides posts from your profile without deleting them. Access via your profile menu.',
    'mute': 'Mute hides posts from someone in your feed without unfollowing them. Long-press their post and select Mute.',
    'tiktok': 'TikTok and Reels are both short-video platforms, but they\'re owned by different companies.',
    'algorithm': 'RebelGram\'s algorithm shows you content based on your interests, relationships, and engagement patterns.',
    'verification': 'To request verification:\n1. Go to Settings\n2. Tap Account\n3. Request Verification\n4. Fill in your info',
    'two factor': 'To enable Two-Factor Authentication:\n1. Go to Settings\n2. Tap Security\n3. Tap Two-Factor Authentication\n4. Turn it on',
  };

  Future<String> sendMessage(String message, {List<Map<String, String>>? history}) async {
    final lowerMessage = message.toLowerCase();
    
    // First, check local knowledge base for quick responses
    for (var entry in _rebelGramKnowledgeBase.entries) {
      if (lowerMessage.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // If using external API, try it as fallback
    if (_useExternalAPI) {
      try {
        return await _sendViaHuggingFace(message, history: history);
      } catch (e) {
        // Fall through to local response
      }
    }
    
    // Default intelligent response based on message analysis
    return _generateContextualResponse(message, lowerMessage);
  }
  
  String _generateContextualResponse(String message, String lowerMessage) {
    // Generate helpful responses based on keywords
    if (lowerMessage.contains('help')) {
      return 'I\'m here to help! You can ask me about:\n📸 Posting photos & stories\n💬 Direct messages\n👥 Followers & following\n📹 Reels & Live videos\n🔒 Privacy & security\n⚙️ Account settings\n\nWhat would you like to know?';
    }
    
    if (lowerMessage.contains('tip') || lowerMessage.contains('advice')) {
      return 'Here are some RebelGram tips:\n✨ Post consistently to grow your audience\n💬 Engage with comments quickly\n📱 Use high-quality images\n🏷️ Use relevant hashtags\n👁️ Watch Reels for reach\n💡 Post at peak times when your audience is active';
    }
    
    if (lowerMessage.contains('grow') || lowerMessage.contains('increase')) {
      return 'To grow on RebelGram:\n1. Post quality content consistently\n2. Use relevant hashtags\n3. Engage with your community\n4. Use Stories and Reels\n5. Collaborate with others\n6. Post at optimal times\n7. Use compelling captions';
    }
    
    if (lowerMessage.contains('delete') || lowerMessage.contains('remove')) {
      return 'To delete content on RebelGram:\n📝 Posts: Go to post > tap three dots > Delete\n💬 DMs: Long press message > Delete\n📖 Story: Your story disappears after 24h or manually delete from archive';
    }
    
    if (lowerMessage.contains('privacy') || lowerMessage.contains('private')) {
      return 'Privacy options on RebelGram:\n🔒 Make account private in Settings > Privacy\n🚫 Block or restrict users\n👁️ Control story visibility\n📝 Control comment settings\n🔐 Enable Two-Factor Authentication';
    }
    
    // Default response
    return 'Thanks for your message! I\'m your RebelGram assistant focused on helping with this app. You can ask me about:\n\n📸 Posting & Stories\n💬 Direct Messages\n👥 Followers & Following\n📹 Reels & Live Videos\n🔒 Privacy & Security\n\nHow can I help you today?';
  }

  Future<String> _sendViaHuggingFace(String message, {List<Map<String, String>>? history}) async {
    final url = Uri.parse('https://api-inference.huggingface.co/models/google/flan-t5-small');
    
    final prompt = '''
  You are a helpful RebelGram assistant. Answer user questions about RebelGram features, tips, and how to use the app.

  User question: $message

  Provide a helpful, concise answer:
  ''';

    final resp = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $_hfToken',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({'inputs': prompt}),
    );
    
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (data is List && data.isNotEmpty) {
        return (data[0]['generated_text'] as String).trim();
      } else if (data is Map && data['generated_text'] != null) {
        return (data['generated_text'] as String).trim();
      }
    }
    
    throw Exception('HF request failed with status: ${resp.statusCode}');
  }
}
