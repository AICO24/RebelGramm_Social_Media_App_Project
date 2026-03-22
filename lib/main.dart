import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'providers/post_provider.dart';
import 'providers/ai_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
// splash screen handles initial navigation to login/home
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ); // use generated Firebase options

  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
  } else {
    try {
      await FirebaseFirestore.instance.clearPersistence();
    } catch (e) {
      print('Firebase cache clear error: $e');
    }
  }

  // Reset Firestore connection
  try {
    await FirebaseFirestore.instance.disableNetwork();
    await Future.delayed(const Duration(milliseconds: 500));
    await FirebaseFirestore.instance.enableNetwork();
    print('✅ Firebase network reset and working!');
  } catch (e) {
    print('❌ Firebase network error: $e');
  }

  // Add error handling for Firebase
  FlutterError.onError = (error) {
    print('Flutter error: ${error.exception}');
  };

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
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
        title: 'RebelGram',
        theme: ThemeData.light().copyWith(
          scaffoldBackgroundColor: Colors.white,
          primaryColor: Colors.white,
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.white,
            iconTheme: IconThemeData(color: Colors.black),
            elevation: 0,
            titleTextStyle: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: Colors.white,
            selectedItemColor: Colors.black,
            unselectedItemColor: Colors.grey,
            showSelectedLabels: false,
            showUnselectedLabels: false,
          ),
          dividerColor: Colors.grey.shade300,
        ),
        darkTheme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: Colors.black,
          primaryColor: Colors.black,
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.black,
            iconTheme: IconThemeData(color: Colors.white),
            elevation: 0,
            titleTextStyle: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Colors.black,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.grey,
            showSelectedLabels: false,
            showUnselectedLabels: false,
          ),
          dividerColor: Colors.grey.shade900,
        ),
        themeMode: themeProvider.themeMode,
        home: const SplashScreen(),
      );
    },
  ),
);
  }
}