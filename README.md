# EmmStagram

Instagram‑style social media app built with Flutter and Firebase.

## Features

1. **Home Feed**: Scrollable list of posts with images, captions, likes and comments.
2. **Search**: Look for users by username or posts by caption keywords.
3. **Add Post**: Upload an image from device or provide an image URL, add a caption, and publish.
4. **Profile**: View your account details and log out.
5. **AI Chatbot**: Ask any question about Instagram and receive helpful answers powered by OpenAI.
6. **Authentication**: Firebase email/password sign up and login.

## Setup

1. Clone repository and open in VS Code or your IDE.
2. Run `flutter pub get` to fetch dependencies.
3. Make sure you have a Firebase project and have added the configuration files.
   The project already contains a generated `firebase_options.dart` file.
4. **AI Key**: Set your OpenAI API key in `lib/services/ai_service.dart` replacing
   `YOUR_OPENAI_API_KEY` with a valid key. For production, consider using
   secure storage or environment variables.
5. Run the app on a simulator or device with `flutter run`.

## Notes

- This application uses Provider for state management.
- All code is written in Dart/Flutter; no platform-specific code is required.
- Error handling and loading states have been added to provide a production‑ready
  experience.

Enjoy experimenting with EmmStagram!
