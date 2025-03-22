import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qahwatahlly/services/reel_service.dart'; // استدعاء خدمة الريلز

class NewPostDialog extends StatefulWidget {
  final VoidCallback onPostSubmitted;

  const NewPostDialog({super.key, required this.onPostSubmitted});

  static void show(BuildContext context, {required VoidCallback onPostSubmitted}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => NewPostDialog(onPostSubmitted: onPostSubmitted),
    );
  }

  @override
  _NewPostDialogState createState() => _NewPostDialogState();
}

class _NewPostDialogState extends State<NewPostDialog> {
  final _supabase = Supabase.instance.client;
  final _contentController = TextEditingController();
  File? _imageFile;
  File? _videoFile;
  bool _isReel = false; // للتحكم إذا كان منشور أم ريل
  final _picker = ImagePicker();
  final _reelService = ReelService(); // خدمة الريلز

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isReel ? 'إضافة ريل جديد' : 'إضافة منشور جديد',
            style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contentController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: _isReel ? 'اكتب تعليق الريل (اختياري)...' : 'اكتب منشورك هنا...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMediaOption(Icons.image, 'صورة', () async {
                final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                if (pickedFile != null) {
                  setState(() {
                    _imageFile = File(pickedFile.path);
                    _videoFile = null;
                    _isReel = false; // إذا اختار صورة، ليس ريل
                  });
                }
              }),
              _buildMediaOption(Icons.videocam, 'فيديو', () {
                _showComingSoon(); // خاصية الفيديو العادي غير مفعلة
              }),
              _buildMediaOption(Icons.video_library, 'ريل', () async {
                setState(() {
                  _isReel = true;
                });

                // فتح المعرض مباشرة لاختيار فيديو
                final pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
                if (pickedFile != null) {
                  setState(() {
                    _videoFile = File(pickedFile.path);
                    _imageFile = null;
                  });
                } else {
                  // المستخدم لم يختار فيديو، نعيد للوضع العادي
                  setState(() {
                    _isReel = false;
                  });
                }
              }, isToggle: true),
            ],
          ),
          if (_imageFile != null || _videoFile != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _imageFile != null
                  ? Image.file(_imageFile!, height: 100, width: double.infinity, fit: BoxFit.cover)
                  : const Text('تم اختيار فيديو', style: TextStyle(fontSize: 16)),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text('نشر', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMediaOption(IconData icon, String label, VoidCallback onTap, {bool isToggle = false}) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: isToggle && _isReel ? Colors.red : null),
          onPressed: onTap,
        ),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('قريبًا')));
  }

  Future<void> _submit() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تسجيل الدخول أولاً')));
      return;
    }

    if (_contentController.text.isEmpty && _imageFile == null && _videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إضافة محتوى')));
      return;
    }

    try {
      if (_isReel) {
        // رفع ريل باستخدام ReelService
        await _reelService.uploadReel(
          imageFile: _imageFile,
          videoFile: _videoFile,
          caption: _contentController.text,
        );
      } else {
        // رفع منشور عادي
        String? imageUrl;
        if (_imageFile != null) {
          final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          await _supabase.storage.from('post-images').upload(fileName, _imageFile!);
          imageUrl = _supabase.storage.from('post-images').getPublicUrl(fileName);
        }

        await _supabase.from('posts').insert({
          'user_id': userId,
          'content': _contentController.text,
          'image_url': imageUrl,
        });
      }

      Navigator.pop(context);
      widget.onPostSubmitted();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النشر بنجاح')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في النشر: $e')));
    }
  }
}
