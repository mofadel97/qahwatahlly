class Comment {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final String? parentCommentId;
  final DateTime createdAt;
  final String username;
  final String? avatarUrl;
  final int likesCount;
  final bool isLiked;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    this.parentCommentId,
    required this.createdAt,
    required this.username,
    this.avatarUrl,
    this.likesCount = 0,
    this.isLiked = false,
  });
}