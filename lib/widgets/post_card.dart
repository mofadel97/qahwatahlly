import 'package:flutter/material.dart';
import '../models/post.dart';
import 'comments_dialog.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final Function(String, bool, int) onToggleLike;
  final Function(String, int) onDelete;

  const PostCard({super.key, required this.post, required this.onToggleLike, required this.onDelete});

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
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz),
                    onSelected: (value) {
                      if (value == 'edit') {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعديل المنشور قيد التطوير')));
                      } else if (value == 'delete') {
                        onDelete(post.id, -1); // سيتم تمرير index من ListView.builder
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('تعديل المنشور')),
                      const PopupMenuItem(value: 'delete', child: Text('حذف المنشور')),
                    ],
                  ),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(post.username, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black)),
                          Text(_timeAgo(post.createdAt), style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: post.avatarUrl != null ? NetworkImage(post.avatarUrl!) : null,
                        child: post.avatarUrl == null ? Text(post.username[0], style: const TextStyle(fontSize: 16)) : null,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(post.content, style: Theme.of(context).textTheme.bodyMedium),
              if (post.imageUrl != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(post.imageUrl!, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.error)),
                ),
              ],
              const SizedBox(height: 8),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المشاركة قيد التطوير'))),
                    icon: const Icon(Icons.share),
                    label: const Text('مشاركة'),
                  ),
                  TextButton.icon(
                    onPressed: () => CommentsDialog.show(context, post.id),
                    icon: const Icon(Icons.comment),
                    label: Text('${post.commentsCount} تعليق'),
                  ),
                  TextButton.icon(
                    onPressed: () => onToggleLike(post.id, post.isLiked, -1), // سيتم تمرير index من ListView.builder
                    icon: Icon(post.isLiked ? Icons.favorite : Icons.favorite_border, color: post.isLiked ? Colors.red : null),
                    label: Text('${post.likesCount} إعجاب'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}