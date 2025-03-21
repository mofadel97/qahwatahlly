import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/comment.dart';

class CommentService {
  final _supabase = Supabase.instance.client;

  Future<List<Comment>> loadComments(String postId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final response = await _supabase
          .from('comments')
          .select('id, post_id, user_id, content, parent_comment_id, created_at')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      return Future.wait(response.map((comment) async {
        final profile = await _supabase
            .from('profiles')
            .select('username, avatar_url')
            .eq('id', comment['user_id'])
            .maybeSingle();

        final likesCount = await _supabase
            .from('comment_likes')
            .select('id')
            .eq('comment_id', comment['id'])
            .count();

        final userLike = userId != null
            ? await _supabase
                .from('comment_likes')
                .select('id')
                .eq('comment_id', comment['id'])
                .eq('user_id', userId)
                .maybeSingle()
            : null;

        return Comment(
          id: comment['id'].toString(),
          postId: comment['post_id'].toString(),
          userId: comment['user_id'],
          content: comment['content'],
          parentCommentId: comment['parent_comment_id']?.toString(),
          createdAt: DateTime.parse(comment['created_at']),
          username: profile?['username'] ?? 'مجهول',
          avatarUrl: profile?['avatar_url'],
          likesCount: likesCount.count,
          isLiked: userLike != null,
        );
      }));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addComment(String postId, String content, {String? parentCommentId}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw 'يرجى تسجيل الدخول';

    try {
      await _supabase.from('comments').insert({
        'post_id': int.parse(postId),
        'user_id': userId,
        'content': content,
        'parent_comment_id': parentCommentId != null ? int.parse(parentCommentId) : null,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> toggleCommentLike(String commentId, bool isLiked) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw 'يرجى تسجيل الدخول';

    try {
      if (isLiked) {
        await _supabase
            .from('comment_likes')
            .delete()
            .eq('comment_id', int.parse(commentId))
            .eq('user_id', userId);
      } else {
        await _supabase.from('comment_likes').insert({
          'comment_id': int.parse(commentId),
          'user_id': userId,
        });
      }
    } catch (e) {
      rethrow;
    }
  }
}