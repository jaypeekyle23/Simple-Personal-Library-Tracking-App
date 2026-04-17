import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 

import 'screens/main_navigation.dart';
import 'screens/auth_screen.dart'; 

import 'services/push_notification_service.dart'; 

// CHANGED: Initialize the ValueNotifier with ThemeMode.dark instead of light
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final prefs = await SharedPreferences.getInstance();
  // CHANGED: Default to true (Dark Mode) if the user has no saved preference yet
  final isDarkMode = prefs.getBool('isDarkMode') ?? true; 
  
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  runApp(const MyLibraryApp());
}

// We made this a StatefulWidget to preserve the Auth Stream!
class MyLibraryApp extends StatefulWidget {
  const MyLibraryApp({super.key});

  @override
  State<MyLibraryApp> createState() => _MyLibraryAppState();
}

class _MyLibraryAppState extends State<MyLibraryApp> {
  // We store the auth stream here so it doesn't recreate on theme change
  late final Stream<User?> _authStream;

  @override
  void initState() {
    super.initState();
    // Initialize the stream only ONCE
    _authStream = FirebaseAuth.instance.authStateChanges();
    
    // Initialize push notifications when the app starts
    PushNotificationService.init();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false, 
          title: 'Folio',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
          darkTheme: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple, 
              brightness: Brightness.dark,
            ),
          ),
          themeMode: currentMode,
          
          home: StreamBuilder<User?>(
            // Use the stored stream instead of calling the method again!
            stream: _authStream, 
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasData) {
                return const MainNavigation();
              }
              return const AuthScreen();
            },
          ),
        );
      },
    );
  }
}