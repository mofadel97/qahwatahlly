class Post {
  final String id;
  final String content;
  final String? imageUrl;
  final String username;
  int likesCount;
  bool isLiked;
  final String? avatarUrl;
  final DateTime createdAt;
  int commentsCount; // حذف final للسماح بالتعديل

  Post({
    required this.id,
    required this.content,
    this.imageUrl,
    required this.username,
    this.likesCount = 0,
    this.isLiked = false,
    this.avatarUrl,
    required this.createdAt,
    this.commentsCount = 0,
  });
}