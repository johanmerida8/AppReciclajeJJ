import 'package:flutter/material.dart';
import 'package:reciclaje_app/auth/auth_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // setup supabase
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imthc2lseGt0a3h3cWhldWRrZHByIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY3NDg2MDQsImV4cCI6MjA3MjMyNDYwNH0.jbE2a6LEWCvH6Yuq8CuIIfIQ3DFK5yRRvVVuM320RsQ',
    url: 'https://kasilxktkxwqheudkdpr.supabase.co',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Reciclaje App',
      home: AuthGate(),
    );
  }
}