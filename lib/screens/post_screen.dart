import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({super.key});

  @override
  _PostScreenState createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final _contentController = TextEditingController();
  final _supabase = Supabase.instance.client;
  File? _postImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _postImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadPostImage() async {
    if (_postImage == null) return null;
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
      await _supabase.storage.from('postimages').upload(fileName, _postImage!);
      final publicUrl = _supabase.storage.from('postimages').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      print('Error uploading post image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في رفع الصورة: $e')),
      );
      return null;
    }
  }

  Future<void> _createPost() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final imageUrl = await _uploadPostImage();
      await _supabase.from('posts').insert({
        'user_id': user.id,
        'content': _contentController.text,
        'image_url': imageUrl,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم النشر بنجاح!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في النشر: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // title: Container(
        //   padding: const EdgeInsets.symmetric(vertical: 8.0),
        //   child: Image.asset('assets/images/Logo.png', height: 40),
        // ),
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
              'إنشاء منشور جديد',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.brown),
            ),
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                    image: _postImage != null
                        ? DecorationImage(
                      image: FileImage(_postImage!),
                      fit: BoxFit.cover,
                    )
                        : null,
                  ),
                  child: _postImage == null
                      ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'اكتب منشورك هنا',
                prefixIcon: Icon(Icons.edit),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _createPost,
                child: const Text('نشر'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}