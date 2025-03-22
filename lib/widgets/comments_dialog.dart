import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  String? _replyToCommentId;
  String? _replyToUsername;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    if (_commentController.text.isEmpty) return;
    try {
      await _commentService.addComment(widget.postId, _commentController.text, parentCommentId: _replyToCommentId);
      _commentController.clear();
      setState(() {
        _replyToCommentId = null;
        _replyToUsername = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في إضافة التعليق: $e')));
    }
  }

  Future<void> _toggleLike(String commentId, bool isLiked) async {
    try {
      await _commentService.toggleCommentLike(commentId, isLiked);
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
                child: StreamBuilder<List<Comment>>(
                  stream: _commentService.getCommentsStream(widget.postId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('لا توجد تعليقات بعد'));
                    }
                    final comments = snapshot.data!;
                    return ListView.builder(
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
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