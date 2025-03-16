import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _usernameController = TextEditingController();
  String? _email;
  String? _username;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final response = await _supabase
          .from('profiles')
          .select('email, username')
          .eq('id', user.id)
          .maybeSingle();
      if (response != null) {
        setState(() {
          _email = response['email'] ?? user.email;
          _username = response['username'];
          _usernameController.text = _username ?? '';
        });
      } else {
        // إذا لم يكن هناك ملف شخصي بعد، أنشئ واحدًا
        await _supabase.from('profiles').insert({
          'id': user.id,
          'email': user.email,
        });
        setState(() {
          _email = user.email;
        });
      }
    }
  }

  Future<void> _updateProfile() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'username': _usernameController.text,
        'updated_at': DateTime.now().toIso8601String(),
      });
      setState(() {
        _username = _usernameController.text;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث الملف الشخصي!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('البريد الإلكتروني: ${_email ?? "جارٍ التحميل..."}'),
            const SizedBox(height: 20),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'اسم المستخدم'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateProfile,
              child: const Text('تحديث الملف الشخصي'),
            ),
          ],
        ),
      ),
    );
  }
}