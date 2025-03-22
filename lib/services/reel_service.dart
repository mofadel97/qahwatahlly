import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qahwatahlly/models/reel.dart';
import 'dart:io';

class ReelService {
  final _supabase = Supabase.instance.client;

  Future<List<Reel>> loadReels({int limit = 10, int offset = 0}) async {
    try {
      final response = await _supabase
          .from('reels')
          .select('*, profiles(username, avatar_url)')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final reels = (response as List<dynamic>)
          .map((json) => Reel.fromJson(json))
          .toList();

      return reels;
    } catch (e) {
      print('Error loading reels: $e');
      throw 'خطأ في تحميل الريلز: $e';
    }
  }

  Future<void> uploadReel({
    File? imageFile,
    File? videoFile,
    String? caption,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw 'يرجى تسجيل الدخول أولاً';

      String? imageUrl;
      String? videoUrl;

      // رفع الصورة إذا كانت موجودة
      if (imageFile != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${userId}_image';
        final response = await _supabase.storage
            .from('reels')
            .upload(fileName, imageFile);
        imageUrl = _supabase.storage.from('reels').getPublicUrl(fileName);
      }

      // رفع الفيديو إذا كان موجودًا
      if (videoFile != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${userId}_video';
        final response = await _supabase.storage
            .from('reels')
            .upload(fileName, videoFile);
        videoUrl = _supabase.storage.from('reels').getPublicUrl(fileName);
      }

      // إضافة الريل إلى جدول reels
      await _supabase.from('reels').insert({
        'user_id': userId,
        'image_url': imageUrl,
        'video_url': videoUrl,
        'caption': caption,
        'created_at': DateTime.now().toIso8601String(),
        'likes_count': 0,
      });
    } catch (e) {
      print('Error uploading reel: $e');
      throw 'خطأ في رفع الريل: $e';
    }
  }
}