import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:reciclaje_app/screen/distribuidor/reset_password_link_screen.dart';
import 'package:reciclaje_app/screen/splash_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Configure image cache to limit memory usage
  PaintingBinding.instance.imageCache.maximumSize = 100; // Limit to 100 images
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      50 * 1024 * 1024; // 50MB max

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
    print('✅ .env file loaded successfully');
  } catch (e) {
    print('❌ Error loading .env file: $e');
    print('⚠️ Make sure:');
    print('   1. .env file exists in the root directory');
    print('   2. .env is listed in pubspec.yaml assets');
    print('   3. You ran "flutter clean" and "flutter pub get"');
    print('   4. You stopped and restarted the app (hot reload won\'t work)');
  }

  // setup supabase
  await Supabase.initialize(
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imthc2lseGt0a3h3cWhldWRrZHByIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY3NDg2MDQsImV4cCI6MjA3MjMyNDYwNH0.jbE2a6LEWCvH6Yuq8CuIIfIQ3DFK5yRRvVVuM320RsQ',
    url: 'https://kasilxktkxwqheudkdpr.supabase.co',
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _setupDeepLinkListener();
  }

  /// Listen for deep links (password reset, magic links, etc.)
  void _setupDeepLinkListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;

      print('🔗 Auth event: $event');

      // When user clicks password reset link, redirect to reset password screen
      if (event == AuthChangeEvent.passwordRecovery) {
        print('🔑 Password recovery detected - navigating to reset screen');
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const ResetPasswordLinkScreen(),
          ),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Reciclaje App',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2D8A8A)),
      ),
      home: const SplashScreen(),
    );
  }
}
