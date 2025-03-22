class Reel {
  final String id;
  final String userId;
  final String? imageUrl;
  final String? videoUrl;
  final String? caption;
  final DateTime createdAt;
  final int likesCount;
  final String? username; // لعرض اسم المستخدم
  final String? avatarUrl; // لعرض الصورة الشخصية للمستخدم

  Reel({
    required this.id,
    required this.userId,
    this.imageUrl,
    this.videoUrl,
    this.caption,
    required this.createdAt,
    this.likesCount = 0,
    this.username,
    this.avatarUrl,
  });

  factory Reel.fromJson(Map<String, dynamic> json) {
    return Reel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      imageUrl: json['image_url'] as String?,
      videoUrl: json['video_url'] as String?,
      caption: json['caption'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      likesCount: json['likes_count'] as int? ?? 0,
      username: json['profiles']?['username'] as String?,
      avatarUrl: json['profiles']?['avatar_url'] as String?,
    );
  }
}