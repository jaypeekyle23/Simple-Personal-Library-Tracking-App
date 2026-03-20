// main.dart

import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/book.dart';
import 'screens/home_screen.dart';

late Isar isar;

// A global variable that listens for theme changes. Starts in Light Mode by default.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize Isar Database
  // CHANGED: Now looking in the Support Directory where your books likely live!
  final dir = await getApplicationSupportDirectory();
  isar = await Isar.open(
    [BookSchema], 
    directory: dir.path,
  );

  // 2. Load saved theme preference
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false; // Default to false if nothing is saved
  
  // 3. Update the notifier with the saved preference BEFORE running the app
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  runApp(const MyLibraryApp());
}

class MyLibraryApp extends StatelessWidget {
  const MyLibraryApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder redraws the app whenever themeNotifier changes
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'Personal Library',
          // Light Theme settings
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
          // Dark Theme settings
          darkTheme: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple, 
              brightness: Brightness.dark,
            ),
          ),
          // Tells the app which theme to display right now
          themeMode: currentMode,
          home: const HomeScreen(),
        );
      },
    );
  }
}