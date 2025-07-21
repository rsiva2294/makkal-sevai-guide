// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, PlatformDispatcher;
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'package:makkal_sevai_guide/screen/main_scaffold.dart'; // Import MainScreen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kReleaseMode) {
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    debugPrint('Firebase Analytics Collection Enabled (Release Mode)');
  } else {
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);
    debugPrint('Firebase Analytics Collection Disabled (Debug/Profile Mode)');
  }

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    debugPrint('Caught error by PlatformDispatcher.instance.onError: $error');
    return true;
  };

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final bool hasSeenDisclaimer = prefs.getBool('hasSeenDisclaimer') ?? false;
  final String? savedTheme = prefs.getString('themeMode');
  ThemeMode initialThemeMode = ThemeMode.system;

  if (savedTheme != null) {
    if (savedTheme == 'light') {
      initialThemeMode = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      initialThemeMode = ThemeMode.dark;
    }
  }

  runApp(ServiceFinderApp(
    initialThemeMode: initialThemeMode,
    hasSeenDisclaimer: hasSeenDisclaimer,
  ));
}

class ServiceFinderApp extends StatefulWidget {
  final ThemeMode initialThemeMode;
  final bool hasSeenDisclaimer;

  const ServiceFinderApp({
    super.key,
    required this.initialThemeMode,
    required this.hasSeenDisclaimer,
  });

  @override
  State<ServiceFinderApp> createState() => _ServiceFinderAppState();
}

class _ServiceFinderAppState extends State<ServiceFinderApp> {
  late ThemeMode _themeMode;

  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer =
  FirebaseAnalyticsObserver(analytics: analytics);

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
    // Removed the direct call to _showInitialDisclaimerDialog from here
    // It will now be handled by MainScreen
  }

  void _toggleTheme(ThemeMode themeMode) async {
    setState(() {
      _themeMode = themeMode;
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', themeMode.toString().split('.').last);
  }

  // Moved this method to MainScreen, or rather, it will be implemented there.
  // The logic for showing the dialog is now within MainScreen.
  // This method is no longer needed here.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Makkal Sevai Guide',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.blueGrey,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blueGrey,
      ),
      themeMode: _themeMode,
      home: MainScreen( // Pass the hasSeenDisclaimer flag to MainScreen
        onThemeChanged: _toggleTheme,
        hasSeenInitialDisclaimer: widget.hasSeenDisclaimer, // Pass the flag
      ),
      debugShowCheckedModeBanner: false,
      navigatorObservers: [observer],
    );
  }
}