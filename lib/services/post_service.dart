import 'dart:ui';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post.dart';

class PostService {
  final _supabase = Supabase.instance.client;

  Future<List<Post>> loadPosts() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final response = await _supabase
          .from('posts')
          .select('id, content, image_url, user_id, created_at')
          .order('created_at', ascending: false);

      return Future.wait(response.map((post) async {
        final profile = await _supabase
            .from('profiles')
            .select('username, avatar_url')
            .eq('id', post['user_id'])
            .maybeSingle();

        final likesCount = await _supabase
            .from('likes')
            .select('id')
            .eq('post_id', post['id'])
            .count();

        final userLike = userId != null
            ? await _supabase
                .from('likes')
                .select('id')
                .eq('post_id', post['id'])
                .eq('user_id', userId)
                .maybeSingle()
            : null;

        final commentsCount = await _supabase
            .from('comments')
            .select('id')
            .eq('post_id', post['id'])
            .count();

        return Post(
          id: post['id'].toString(),
          content: post['content'] ?? '',
          imageUrl: post['image_url'],
          username: profile?['username'] ?? 'مجهول',
          likesCount: likesCount.count,
          isLiked: userLike != null,
          avatarUrl: profile?['avatar_url'],
          createdAt: DateTime.parse(post['created_at']),
          commentsCount: commentsCount.count,
        );
      }));
    } catch (e) {
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
      rethrow;
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _supabase.from('posts').delete().eq('id', int.parse(postId));
    } catch (e) {
      rethrow;
    }
  }
}