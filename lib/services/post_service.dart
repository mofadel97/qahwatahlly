import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post.dart';

class PostService {
  final _supabase = Supabase.instance.client;

  Future<List<Post>> loadPosts({int limit = 10, int offset = 0}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;

      // جلب المنشورات مع بيانات الملف الشخصي في طلب واحد باستخدام العلاقات
      final response = await _supabase
          .from('posts')
          .select('''
            id, content, image_url, user_id, created_at,
            profiles!posts_user_id_fkey(username, avatar_url),
            likes!likes_post_id_fkey(id, user_id),
            comments!comments_post_id_fkey(id)
          ''')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response.map((post) {
        final likes = post['likes'] as List<dynamic>;
        final comments = post['comments'] as List<dynamic>;
        final likesCount = likes.length;
        final userLike = userId != null
            ? likes.any((like) => like['user_id'] == userId)
            : false;

        return Post(
          id: post['id'].toString(),
          content: post['content'] ?? '',
          imageUrl: post['image_url'],
          username: post['profiles']?['username'] ?? 'مجهول',
          likesCount: likesCount,
          isLiked: userLike,
          avatarUrl: post['profiles']?['avatar_url'],
          createdAt: DateTime.parse(post['created_at']),
          commentsCount: comments.length,
        );
      }).toList();
    } catch (e) {
      print('Error in loadPosts: $e');
      rethrow;
    }
  }

  Future<List<Post>> loadUserPosts({int limit = 10, int offset = 0}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw 'يرجى تسجيل الدخول';

    try {
      // جلب منشورات المستخدم مع بيانات الملف الشخصي في طلب واحد
      final response = await _supabase
          .from('posts')
          .select('''
            id, content, image_url, user_id, created_at,
            profiles!posts_user_id_fkey(username, avatar_url),
            likes!likes_post_id_fkey(id, user_id),
            comments!comments_post_id_fkey(id)
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response.map((post) {
        final likes = post['likes'] as List<dynamic>;
        final comments = post['comments'] as List<dynamic>;
        final likesCount = likes.length;
        final userLike = likes.any((like) => like['user_id'] == userId);

        return Post(
          id: post['id'].toString(),
          content: post['content'] ?? '',
          imageUrl: post['image_url'],
          username: post['profiles']?['username'] ?? 'مجهول',
          likesCount: likesCount,
          isLiked: userLike,
          avatarUrl: post['profiles']?['avatar_url'],
          createdAt: DateTime.parse(post['created_at']),
          commentsCount: comments.length,
        );
      }).toList();
    } catch (e) {
      print('Error in loadUserPosts: $e');
      rethrow;
    }
  }

  Future<String?> loadUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final response = await _supabase.from('profiles').select('avatar_url').eq('id', user.id).maybeSingle();
        return response?['avatar_url'] as String?;
      }
      return null;
    } catch (e) {
      print('Error in loadUserProfile: $e');
      rethrow;
    }
  }

  RealtimeChannel setupRealtime(VoidCallback onUpdate) {
    return _supabase
        .channel('public:posts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'posts',
          callback: (_) => onUpdate(),
        )
        .subscribe();
  }

  Future<void> toggleLike(String postId, bool isLiked) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      if (isLiked) {
        await _supabase.from('likes').delete().eq('post_id', int.parse(postId)).eq('user_id', userId);
      } else {
        await _supabase.from('likes').insert({'post_id': int.parse(postId), 'user_id': userId});
      }
    } catch (e) {
      print('Error in toggleLike: $e');
      rethrow;
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _supabase.from('posts').delete().eq('id', int.parse(postId));
    } catch (e) {
      print('Error in deletePost: $e');
      rethrow;
    }
  }
}