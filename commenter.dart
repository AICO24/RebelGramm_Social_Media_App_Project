import 'dart:io';

void main() {
  final Map<String, String> docs = {
    'lib/providers/user_provider.dart': '''// ==========================================
// ROLE: Member 1 - User Identity & Profiles
// ==========================================
// This Provider manages the global state of the currently logged-in user.
// By using ChangeNotifier, any screen in the app can listen to this provider.
// When the user logs in and the profile is fetched, notifyListeners() is called,
// updating all UI elements that depend on the user's data (like profile avatars).
''',
    'lib/screens/profile_screen.dart': '''// ==========================================
// ROLE: Member 1 - User Identity & Profiles
// ==========================================
// This screen displays a user's portfolio, including their grid of posts, 
// followers, and following counts. 
// It also contains logic for:
// - Following/Unfollowing algorithms (updating follower collections)
// - Fetching all posts authored by the specific user ID.
// - Editing the profile (uploading new avatars).
''',
    'lib/screens/login_screen.dart': '''// ==========================================
// ROLE: Member 1 - User Identity & Profiles
// ==========================================
// Handles the authentication gateway. Uses Firebase Auth to sign in users
// with an email and password. On success, it fetches the user details 
// and populates the UserProvider before navigating to the HomeScreen.
''',
    'lib/screens/register_screen.dart': '''// ==========================================
// ROLE: Member 1 - User Identity & Profiles
// ==========================================
// Allows new users to create accounts. Responsible for:
// 1. Creating the Firebase Auth credential.
// 2. Uploading a selected profile image.
// 3. Generating a custom user document in the Firestore 'users' collection.
''',
    'lib/screens/home_screen.dart': '''// ==========================================
// ROLE: Member 2 - The Main Feed & Stories
// ==========================================
// The core scaffold of the app. Features include:
// - A top app bar with navigation to Messages (Inbox).
// - A horizontal list of Stories fetched dynamically from followed users.
// - A vertically scrolling chronological Feed of Posts using StreamBuilder
//   to ensure real-time updates as users scroll.
// - A bottom navigation bar connecting the main tabs.
''',
    'lib/widgets/story_avatar.dart': '''// ==========================================
// ROLE: Member 2 - The Main Feed & Stories
// ==========================================
// A reusable UI widget that renders the circular avatars seen at the top of the Home feed.
// Uses a gradient border to signify unviewed stories, and handles tap events to immediately
// launch the full-screen Story Viewer or prompt the user to add a new story.
''',
    'lib/widgets/post_card.dart': '''// ==========================================
// ROLE: Member 3 - Content Creation & Interactions
// ==========================================
// The most complex UI component in the app. This renders individual posts on the feed.
// Responsibilities:
// - Parsing data from PostModel into visual fields (Image, Caption, Username).
// - Displaying dynamic interaction counters for Likes, Comments, Reposts, and Shares.
// - Handling interactive UI states locally before sending transaction requests to Firestore.
// - Managing the 'Save' and 'Follow' quick-actions directly on the card.
''',
    'lib/services/post_service.dart': '''// ==========================================
// ROLE: Member 3 - Content Creation & Interactions
// ==========================================
// This Backend Service orchestrates all communication directly with the Firestore 'posts' collection.
// It uses atomic Transactions to ensure counters (like likes or shares) never desync.
// Key functions:
// - uploadPost(): Saves media URLs and texts.
// - likePost(), toggleRepost(), toggleShareStatus(): Modifies arrays and counts securely.
// - addComment(): Injects comments into the subcollections.
''',
    'lib/models/post_model.dart': '''// ==========================================
// ROLE: Member 3 - Content Creation & Interactions
// ==========================================
// The Data structure representing a single post.
// Includes serialization methods (toMap) and deserialization logic (fromMap) 
// required to convert pure JSON from Firebase into strongly-typed Dart objects.
''',
    'lib/screens/reels_feed_screen.dart': '''// ==========================================
// ROLE: Member 4 - Reels & Video Architecture
// ==========================================
// This screen uses a PageView.builder to mimic the infinite vertical snapping scroll of TikTok/Reels.
// Key integrations:
// - video_player: Loads and caches remote network URLs for smooth playback.
// - visibility_detector: Triggers pause/play logic automatically depending on 
//   how much of the reel is actively visible on the user's glass screen.
''',
    'lib/services/reel_service.dart': '''// ==========================================
// ROLE: Member 4 - Reels & Video Architecture
// ==========================================
// Handles reading and writing Video posts to the 'reels' collection in Firestore.
// Similar to PostService, but adapted exclusively for the requirements of vertical video feeds.
''',
    'lib/screens/inbox_screen.dart': '''// ==========================================
// ROLE: Member 5 - Real-time Messaging
// ==========================================
// The Inbox handles individual private chats between followers.
// It leverages real-time Snapshots to instantly render new incoming messages without needing
// to pull-to-refresh. Features the New Message UI to filter connections and spawn ChatScreens.
''',
    'lib/services/message_service.dart': '''// ==========================================
// ROLE: Member 5 - Real-time Messaging
// ==========================================
// Controls the messaging backend infrastructure.
// - sendMessage(): Injects a document into the combined 'messages' thread for two specific User IDs.
// - getConversations(): Subscribes to the stream of active chat heads for the current user.
''',
    'lib/screens/chatbot_screen.dart': '''// ==========================================
// ROLE: Member 6 - Artificial Intelligence & Notifications
// ==========================================
// Integrates an AI large language model into the social app.
// Manages the chat interface, loading indicators during API lag, local chat persistence,
// and applies the consistent 4-color gradient identity to separate AI features from normal networking.
''',
    'lib/services/ai_service.dart': '''// ==========================================
// ROLE: Member 6 - Artificial Intelligence & Notifications
// ==========================================
// Connects the Flutter frontend to the external Generative AI endpoint.
// Generates the system payload formatting and processes the JSON responses.
''',
    'lib/screens/notifications_screen.dart': '''// ==========================================
// ROLE: Member 6 - Artificial Intelligence & Notifications
// ==========================================
// Acts as the global activity monitor listening to the 'notifications' collection.
// Dynamically parses the interaction 'type' (like, comment, share, follow) 
// to automatically draw the correct visual Icon and intelligently route click events 
// directly to the shared Post or Reel Model.
'''
  };

  final baseDir = 'c:/EmmStagram/my_own_social_media_app';

  docs.forEach((relPath, comment) {
    final file = File('$baseDir/$relPath');
    if (file.existsSync()) {
      final content = file.readAsStringSync();
      if (!content.contains('// ROLE:')) {
        file.writeAsStringSync('$comment\n$content');
        print('Commented $relPath');
      } else {
        print('Already commented $relPath');
      }
    } else {
      print('Could not find $relPath');
    }
  });
}
