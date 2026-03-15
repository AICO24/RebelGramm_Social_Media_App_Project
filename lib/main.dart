import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'providers/post_provider.dart';
import 'providers/ai_provider.dart';
import 'screens/splash_screen.dart';
// splash screen handles initial navigation to login/home
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ); // use generated Firebase options
  // Activate App Check in debug mode. This prints a debug token you can
  // register in the Firebase Console under App Check -> Debug tokens.
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: const AndroidDebugProvider(),
      providerApple: const AppleDebugProvider(),
    );
    final token = await FirebaseAppCheck.instance.getToken();
    // token can be copied to Firebase Console for debugging
    // Note: remove debug provider or switch to safety providers before release.
    // ignore: avoid_print
    print('[AppCheck] debug token: $token');
  } catch (e) {
    // ignore: avoid_print
    print('[AppCheck] failed to activate debug provider: $e');
  }
  runApp(const RebelGramApp());
}

class RebelGramApp extends StatelessWidget {
  const RebelGramApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => PostProvider()),
        ChangeNotifierProvider(create: (_) => AIProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'RebelGram',
        theme: ThemeData.dark().copyWith(
          // dark social media style
          scaffoldBackgroundColor: Color(0xFF121212),
          primaryColor: Color(0xFF121212),
          appBarTheme: AppBarTheme(
            backgroundColor: Color(0xFF121212),
            iconTheme: IconThemeData(color: Colors.white),
            titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            elevation: 0,
          ),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: Color(0xFF121212),
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.grey,
            showSelectedLabels: false,
            showUnselectedLabels: false,
          ),
          textTheme: TextTheme(
            bodyMedium: TextStyle(color: Colors.white),
            bodySmall: TextStyle(color: Colors.white70),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey.shade800,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        home: SplashScreen(),
      ),
    );
  }
}