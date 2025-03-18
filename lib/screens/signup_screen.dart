import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qahwatahlly/screens/components/avatar.dart';
import 'package:path/path.dart' as path;

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _supabase = Supabase.instance.client;
  File? _selectedImage;
  bool _isLoading = false;

  Future<String?> _uploadAvatar() async {
    if (_selectedImage == null) return null;

    try {
      final userId = _supabase.auth.currentUser!.id;
      final imageExtension = path.extension(_selectedImage!.path).replaceAll('.', '');
      final imagePath = '$userId-profile.$imageExtension';

      await _supabase.storage.from('avatar-url').upload(
            imagePath,
            _selectedImage!,
            fileOptions: const FileOptions(upsert: true),
          );

      return _supabase.storage.from('avatar-url').getPublicUrl(imagePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في رفع الصورة: $e')),
      );
      return null;
    }
  }

  Future<void> _signUp() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase.auth.signUp(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (response.user != null) {
        final avatarUrl = await _uploadAvatar();
        await _supabase.from('profiles').insert({
          'id': response.user!.id,
          'full_name': _fullNameController.text,
          'username': _usernameController.text,
          'email': _emailController.text,
          'bio': _bioController.text,
          'avatar_url': avatarUrl,
        });
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في إنشاء الحساب: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.brown[800],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'إنشاء حساب جديد',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.brown),
            ),
            const SizedBox(height: 30),
            Center(
              child: Avatar(
                imageUrl: null,
                onImageSelected: (imageFile) {
                  setState(() {
                    _selectedImage = imageFile;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'الاسم الكامل',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'اسم المستخدم',
                prefixIcon: Icon(Icons.account_circle),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: 'نبذة عنك (اختياري)',
                prefixIcon: Icon(Icons.info),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور',
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('إنشاء الحساب'),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('لديك حساب؟ تسجيل الدخول', style: TextStyle(color: Colors.brown)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}