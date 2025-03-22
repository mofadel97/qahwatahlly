import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qahwatahlly/screens/ReelsScreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/post_screen.dart';
import 'screens/comments_screen.dart';
import 'screens/profile_screen.dart';

// متغير عالمي للتأكد من اكتمال تهيئة Supabase
bool _isSupabaseInitialized = false;

bool get isSupabaseInitialized => _isSupabaseInitialized;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // إعداد HttpClient مخصص
  final context = SecurityContext.defaultContext;
  final httpClient = HttpClient(context: context)
    ..badCertificateCallback = (X509Certificate cert, String host, int port) => true; // للاختبار فقط
  final ioClient = IOClient(httpClient);

  // تهيئة Supabase مع التعامل مع الأخطاء
  try {
    await Supabase.initialize(
      url: 'https://ctzledpmhhzxsryioogq.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN0emxlZHBtaGh6eHNyeWlvb2dxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIwNjM1MDksImV4cCI6MjA1NzYzOTUwOX0.2eXSZDB_pFno2SBu_B8i6OiAtRfU5BurSFsakjXjQpc',
      httpClient: ioClient,
    );
    _isSupabaseInitialized = true; // تحديث المتغير بعد التهيئة
  } catch (e) {
    print('Error initializing Supabase: $e');
    _isSupabaseInitialized = false;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Qahwa Ahly v2',
      theme: ThemeData(
        primarySwatch: Colors.brown,
        scaffoldBackgroundColor: Colors.grey[100],
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.brown[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),
          bodyMedium: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.brown, width: 2),
          ),
          prefixIconColor: Colors.brown,
        ),
      ),
      home: const AuthCheck(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/home': (context) => const HomeScreen(),
        '/post': (context) => const PostScreen(),
        '/profile': (context) => const ProfileScreen(),
         '/reels': (context) => const ReelsScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/comments') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => CommentsScreen(postId: args['postId']),
          );
        }
        return null;
      },
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      return const HomeScreen();
    }
    return const LoginScreen();
  }
}