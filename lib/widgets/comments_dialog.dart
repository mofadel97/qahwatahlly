import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/comment_service.dart';
import '../models/comment.dart';

class CommentsDialog extends StatefulWidget {
  final String postId;

  const CommentsDialog({super.key, required this.postId});

  static void show(BuildContext context, String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => CommentsDialog(postId: postId),
    );
  }

  @override
  _CommentsDialogState createState() => _CommentsDialogState();
}

class _CommentsDialogState extends State<CommentsDialog> {
  final _commentService = CommentService();
  final _commentController = TextEditingController();
  List<Comment> _comments = [];
  String? _replyToCommentId;
  String? _replyToUsername;
  RealtimeChannel? _commentsChannel;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _setupRealtime();
  }

  @override
  void dispose() {
    _commentsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      _comments = await _commentService.loadComments(widget.postId);
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في تحميل التعليقات: $e')));
    }
  }

  void _setupRealtime() {
    _commentsChannel = Supabase.instance.client
        .channel('public:comments')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: int.parse(widget.postId),
          ),
          callback: (payload) async {
            final newCommentData = payload.newRecord;
            final profile = await Supabase.instance.client
                .from('profiles')
                .select('username, avatar_url')
                .eq('id', newCommentData['user_id'])
                .maybeSingle();

            final newComment = Comment(
              id: newCommentData['id'].toString(),
              postId: newCommentData['post_id'].toString(),
              userId: newCommentData['user_id'],
              content: newCommentData['content'],
              parentCommentId: newCommentData['parent_comment_id']?.toString(),
              createdAt: DateTime.parse(newCommentData['created_at']),
              username: profile?['username'] ?? 'مجهول',
              avatarUrl: profile?['avatar_url'],
              likesCount: 0,
              isLiked: false,
            );

            setState(() {
              _comments.add(newComment);
            });
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            print('Subscribed to comments for post ${widget.postId}');
          } else if (error != null) {
            print('Error subscribing to comments: $error');
          }
        });
  }

  Future<void> _addComment() async {
    if (_commentController.text.isEmpty) return;
    try {
      await _commentService.addComment(widget.postId, _commentController.text, parentCommentId: _replyToCommentId);
      _commentController.clear();
      _replyToCommentId = null;
      _replyToUsername = null;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في إضافة التعليق: $e')));
    }
  }

  Future<void> _toggleLike(String commentId, bool isLiked) async {
    try {
      await _commentService.toggleCommentLike(commentId, isLiked);
      _loadComments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الإعجاب: $e')));
    }
  }

  String _timeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) return 'منذ ${difference.inDays} يوم';
    if (difference.inHours > 0) return 'منذ ${difference.inHours} ساعة';
    if (difference.inMinutes > 0) return 'منذ ${difference.inMinutes} دقيقة';
    return 'الآن';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('التعليقات', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: _comments.isEmpty
                    ? const Center(child: Text('لا توجد تعليقات بعد'))
                    : ListView.builder(
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          final isReply = comment.parentCommentId != null;
                          return Padding(
                            padding: EdgeInsets.only(right: isReply ? 32.0 : 0.0, bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: comment.avatarUrl != null ? NetworkImage(comment.avatarUrl!) : null,
                                  child: comment.avatarUrl == null ? Text(comment.username[0]) : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Text(_timeAgo(comment.createdAt), style: Theme.of(context).textTheme.bodySmall),
                                          const SizedBox(width: 8),
                                          Text(comment.username,
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black)),
                                        ],
                                      ),
                                      Text(comment.content, style: Theme.of(context).textTheme.bodyMedium),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () => _toggleLike(comment.id, comment.isLiked),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  comment.isLiked ? Icons.favorite : Icons.favorite_border,
                                                  color: comment.isLiked ? Colors.red : null,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text('${comment.likesCount} إعجاب'),
                                              ],
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _replyToCommentId = comment.id;
                                                _replyToUsername = comment.username;
                                                _commentController.text = '@${comment.username} ';
                                              });
                                            },
                                            child: const Text('رد'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              if (_replyToUsername != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text('يرد على @$_replyToUsername', style: Theme.of(context).textTheme.bodySmall),
                ),
              TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'اكتب تعليقك...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _addComment,
                  ),
                ),
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}