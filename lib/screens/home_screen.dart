import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'comments_screen.dart';

class _Post {
  final String id;
  final String content;
  final String? imageUrl;
  final String username;
  int likesCount;
  bool isLiked;
  final String? avatarUrl;
  final DateTime createdAt;

  _Post({
    required this.id,
    required this.content,
    this.imageUrl,
    required this.username,
    this.likesCount = 0,
    this.isLiked = false,
    this.avatarUrl,
    required this.createdAt,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  List<_Post> _posts = [];
  RealtimeChannel? _postsChannel;
  String? _userAvatarUrl;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _loadUserProfile();
    _setupRealtime();
  }

  @override
  void dispose() {
    _postsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final response = await _supabase
            .from('profiles')
            .select('avatar_url')
            .eq('id', user.id)
            .maybeSingle();
        setState(() {
          _userAvatarUrl = response?['avatar_url'] as String?;
          print('User Avatar URL: $_userAvatarUrl');
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل الملف الشخصي: $e')),
      );
    }
  }

  Future<void> _loadPosts() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final response = await _supabase
          .from('posts')
          .select('id, content, image_url, user_id, created_at')
          .order('created_at', ascending: false);

      final postsWithProfiles = await Future.wait(response.map((post) async {
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

        return _Post(
          id: post['id'].toString(),
          content: post['content'] ?? '',
          imageUrl: post['image_url'] as String?,
          username: profile?['username'] as String? ?? 'مجهول',
          likesCount: likesCount.count,
          isLiked: userLike != null,
          avatarUrl: profile?['avatar_url'] as String?,
          createdAt: DateTime.parse(post['created_at'] as String),
        );
      }).toList());

      setState(() {
        _posts = postsWithProfiles;
      });
    } catch (e) {
      print('Error loading posts: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل المنشورات: $e')),
      );
    }
  }

  void _setupRealtime() {
    _postsChannel = _supabase
        .channel('public:posts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'posts',
          callback: (payload) {
            _loadPosts();
          },
        )
        .subscribe();
  }

  Future<void> _toggleLike(String postId, bool isLiked, int index) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      if (isLiked) {
        await _supabase
            .from('likes')
            .delete()
            .eq('post_id', int.parse(postId))
            .eq('user_id', userId);
      } else {
        await _supabase.from('likes').insert({
          'post_id': int.parse(postId),
          'user_id': userId,
        });
      }

      setState(() {
        _posts[index].isLiked = !isLiked;
        _posts[index].likesCount += isLiked ? -1 : 1;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في الإعجاب: $e')),
      );
    }
  }

  Future<void> _deletePost(String postId, int index) async {
    try {
      await _supabase.from('posts').delete().eq('id', int.parse(postId));
      setState(() {
        _posts.removeAt(index);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في حذف المنشور: $e')),
      );
    }
  }

  Future<void> _showPostDialog() async {
    final TextEditingController _contentController = TextEditingController();
    File? _imageFile;
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDarkMode ? const Color(0xFF424242) : Colors.grey[100],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'إضافة منشور جديد',
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _contentController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'اكتب منشورك هنا...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: _isDarkMode ? Colors.grey[800] : Colors.white,
                    ),
                    style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          IconButton(
                            icon: Icon(Icons.image, color: _isDarkMode ? Colors.white : Colors.grey),
                            onPressed: () async {
                              final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                              if (pickedFile != null) {
                                setModalState(() {
                                  _imageFile = File(pickedFile.path);
                                });
                              }
                            },
                          ),
                          Text(
                            'صورة',
                            style: TextStyle(color: _isDarkMode ? Colors.white : Colors.grey),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          IconButton(
                            icon: Icon(Icons.videocam, color: _isDarkMode ? Colors.white : Colors.grey),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('الفيديو قريبًا')),
                              );
                            },
                          ),
                          Text(
                            'فيديو\n(قريبًا)',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _isDarkMode ? Colors.white : Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          IconButton(
                            icon: Icon(Icons.video_library, color: _isDarkMode ? Colors.white : Colors.grey),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('الريلز قريبًا')),
                              );
                            },
                          ),
                          Text(
                            'ريلز\n(قريبًا)',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _isDarkMode ? Colors.white : Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_imageFile != null) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        _imageFile!,
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final userId = _supabase.auth.currentUser?.id;
                      if (userId == null || _contentController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('يرجى تسجيل الدخول وكتابة منشور')),
                        );
                        return;
                      }

                      try {
                        String? imageUrl;
                        if (_imageFile != null) {
                          final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
                          await _supabase.storage.from('post-images').upload(fileName, _imageFile!);
                          imageUrl = _supabase.storage.from('post-images').getPublicUrl(fileName);
                        }

                        await _supabase.from('posts').insert({
                          'user_id': userId,
                          'content': _contentController.text,
                          'image_url': imageUrl,
                        });

                        Navigator.pop(context);
                        _loadPosts();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم النشر بنجاح')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('خطأ في النشر: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isDarkMode ? Colors.red[900] : Colors.red[600],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: Text(
                      'نشر',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
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
    return Theme(
      data: _isDarkMode
          ? ThemeData.dark().copyWith(
              primaryColor: Colors.red[900],
              scaffoldBackgroundColor: const Color(0xFF212121),
              cardColor: const Color(0xFF424242),
              textTheme: const TextTheme(
                bodyMedium: TextStyle(color: Colors.white),
              ),
              iconTheme: IconThemeData(color: Colors.red[700]),
            )
          : ThemeData.light().copyWith(
              primaryColor: Colors.red[600],
              scaffoldBackgroundColor: Colors.white,
              cardColor: Colors.grey[100],
              textTheme: const TextTheme(
                bodyMedium: TextStyle(color: Colors.black87),
              ),
              iconTheme: IconThemeData(color: Colors.red[600]),
            ),
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120.0,
              floating: true,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isDarkMode
                          ? [const Color(0xFFD32F2F), const Color(0xFFB71C1C)]
                          : [const Color(0xFFFFCDD2), const Color(0xFFF44336)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/LogoAlahly.png',
                          height: 40,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'قهوة الأهلوية',
                          style: GoogleFonts.cairo(
                            color: _isDarkMode ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ) ??
                              TextStyle(
                                color: _isDarkMode ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                color: _isDarkMode ? const Color(0xFF424242) : Colors.grey[100],
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    PopupMenuButton<String>(
                      icon: Icon(Icons.menu, color: _isDarkMode ? Colors.white : Colors.grey, size: 36),
                      onSelected: (value) {
                        if (value == 'dark_mode') {
                          setState(() {
                            _isDarkMode = !_isDarkMode;
                          });
                        } else if (value == 'logout') {
                          _supabase.auth.signOut();
                          Navigator.pushReplacementNamed(context, '/login');
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'dark_mode',
                          child: Text(_isDarkMode ? 'الوضع الفاتح' : 'الوضع الداكن'),
                        ),
                        const PopupMenuItem(
                          value: 'logout',
                          child: Text('تسجيل الخروج'),
                        ),
                      ],
                    ),
                    Icon(Icons.message, color: _isDarkMode ? Colors.white : Colors.grey, size: 36),
                    Icon(Icons.sports_soccer, color: _isDarkMode ? Colors.white : Colors.grey, size: 36),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.mic, color: _isDarkMode ? Colors.white : Colors.grey, size: 36),
                        Positioned(
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            color: Colors.black54,
                            child: const Text('قريبًا', style: TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                        ),
                      ],
                    ),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.video_library, color: _isDarkMode ? Colors.white : Colors.grey, size: 36),
                        Positioned(
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            color: Colors.black54,
                            child: const Text('قريبًا', style: TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Icon(Icons.home,
                            color: _isDarkMode ? Colors.red[700] : Colors.red[600], size: 36),
                        Container(
                          height: 2,
                          width: 24,
                          color: _isDarkMode ? Colors.red[700] : Colors.red[600],
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/profile'),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundImage: _userAvatarUrl != null ? NetworkImage(_userAvatarUrl!) : null,
                        backgroundColor: _isDarkMode ? Colors.grey[700] : Colors.grey[300],
                        child: _userAvatarUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _posts.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      children: _posts.map((post) => _buildPostCard(post)).toList(),
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: _isDarkMode ? Colors.red[900] : Colors.red[600],
          elevation: 6,
          onPressed: _showPostDialog,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('منشور جديد', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildPostCard(_Post post) {
    final index = _posts.indexOf(post);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Card(
        elevation: 1,
        color: _isDarkMode ? const Color(0xFF424242) : Colors.grey[100],
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
                    icon: Icon(Icons.more_horiz, color: _isDarkMode ? Colors.white : Colors.grey),
                    onSelected: (value) {
                      if (value == 'edit') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تعديل المنشور قيد التطوير')),
                        );
                      } else if (value == 'delete') {
                        _deletePost(post.id, index);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('تعديل المنشور'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('حذف المنشور'),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            post.username,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            _timeAgo(post.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: _isDarkMode ? Colors.grey[400] : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: post.avatarUrl != null ? NetworkImage(post.avatarUrl!) : null,
                        backgroundColor: _isDarkMode ? Colors.grey[700] : Colors.grey[300],
                        child: post.avatarUrl == null
                            ? Text(post.username[0], style: const TextStyle(color: Colors.white, fontSize: 16))
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                post.content,
                style: TextStyle(fontSize: 15, color: _isDarkMode ? Colors.white : Colors.black87),
              ),
              if (post.imageUrl != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    post.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Divider(color: _isDarkMode ? Colors.grey[600] : Colors.grey),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('المشاركة قيد التطوير')),
                      );
                    },
                    icon: Icon(Icons.share, color: _isDarkMode ? Colors.white : Colors.grey),
                    label: Text(
                      'مشاركة',
                      style: TextStyle(color: _isDarkMode ? Colors.white : Colors.grey),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/comments', arguments: {'postId': post.id});
                    },
                    icon: Icon(Icons.comment, color: _isDarkMode ? Colors.white : Colors.grey),
                    label: Text(
                      'تعليق',
                      style: TextStyle(color: _isDarkMode ? Colors.white : Colors.grey),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _toggleLike(post.id, post.isLiked, index),
                    icon: Icon(
                      post.isLiked ? Icons.favorite : Icons.favorite_border,
                      color: post.isLiked
                          ? Colors.red
                          : (_isDarkMode ? Colors.white : Colors.grey),
                    ),
                    label: Text(
                      '${post.likesCount} إعجاب',
                      style: TextStyle(color: _isDarkMode ? Colors.white : Colors.grey),
                    ),
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