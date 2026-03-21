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
import 'package:firebase_auth/firebase_auth.dart';
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
        home: const FirebaseTestScreen(),
      );
    },
  ),
);
  }
}

class FirebaseTestScreen extends StatefulWidget {
  const FirebaseTestScreen({Key? key}) : super(key: key);

  @override
  _FirebaseTestScreenState createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  String _status = "Testing Firebase...";
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    _testFirebase();
  }

  Future<void> _testFirebase() async {
    try {
      // Test 1: Check if Firebase is initialized
      final user = FirebaseAuth.instance.currentUser;
      setState(() {
        _status = "Firebase initialized.\nUser: ${user?.email ?? 'Not logged in'}";
      });

      // Test 2: Try to read from Firestore safely (avoid actual user data to prevent listener crashes)
      final testDoc = await FirebaseFirestore.instance
          .collection('system_test')
          .limit(1)
          .get();

      setState(() {
        _status = "✅ Firebase is WORKING!\nRead test passed.";
        _isWorking = true;
      });

      // Test 3: Try to write
      await FirebaseFirestore.instance.collection('system_test').add({
        'message': 'Test from RebelGram',
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _status = "✅ Read and Write both working!\nFirebase is fully functional.";
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          _status = "❌ Error: $e";
          _isWorking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RebelGram - Firebase Fix'),
        backgroundColor: _isWorking ? Colors.green : Colors.red,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isWorking ? Icons.check_circle : Icons.error,
                size: 80,
                color: _isWorking ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 20),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),
              if (!_isWorking)
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _status = "Retrying...";
                    });
                    _testFirebase();
                  },
                  child: const Text('Retry'),
                ),
              if (_isWorking)
                ElevatedButton(
                  onPressed: () {
                    // Navigate to actual app
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const SplashScreen()),
                    );
                  },
                  child: const Text('Continue to App'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}