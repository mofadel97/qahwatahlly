import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final response = await _supabase
          .from('profiles')
          .select('avatar_url')
          .eq('id', user.id)
          .single();
      setState(() {
        _userAvatarUrl = response['avatar_url'];
      });
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
            .single();

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
          imageUrl: post['image_url'],
          username: profile['username'] ?? 'مجهول',
          likesCount: likesCount.count,
          isLiked: userLike != null,
          avatarUrl: profile['avatar_url'],
          createdAt: DateTime.parse(post['created_at']),
        );
      }).toList());

      setState(() {
        _posts = postsWithProfiles;
      });
    } catch (e) {
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

  String _timeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) return 'منذ ${difference.inDays} يوم';
    if (difference.inHours > 0) return 'منذ ${difference.inHours} ساعة';
    if (difference.inMinutes > 0) return 'منذ ${difference.inMinutes} دقيقة';
    return 'الآن';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(bottom: 16.0),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/Logo.png',
                    height: 20,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'قهوة الاهلوية',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.brown[800]!, Colors.brown[400]!],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: CircleAvatar(
                  radius: 16,
                  backgroundImage: _userAvatarUrl != null ? NetworkImage(_userAvatarUrl!) : null,
                  backgroundColor: Colors.brown[200],
                  child: _userAvatarUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
                ),
                onSelected: (value) {
                  if (value == 'profile') {
                    Navigator.pushNamed(context, '/profile');
                  } else if (value == 'logout') {
                    _supabase.auth.signOut();
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: Text('الملف الشخصي'),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Text('تسجيل الخروج'),
                  ),
                ],
              ),
              const SizedBox(width: 10),
            ],
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
        backgroundColor: Colors.brown[600],
        elevation: 6,
        onPressed: () {
          Navigator.pushNamed(context, '/post').then((_) => _loadPosts());
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('منشور جديد', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildPostCard(_Post post) {
    final index = _posts.indexOf(post);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundImage: post.avatarUrl != null ? NetworkImage(post.avatarUrl!) : null,
                    backgroundColor: post.avatarUrl == null ? Colors.brown[200] : null,
                    child: post.avatarUrl == null
                        ? Text(post.username[0], style: const TextStyle(color: Colors.white, fontSize: 20))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.username,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          _timeAgo(post.createdAt),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                post.content,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
              if (post.imageUrl != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    post.imageUrl!,
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(color: Colors.grey),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          post.isLiked ? Icons.favorite : Icons.favorite_border,
                          color: post.isLiked ? Colors.red : Colors.grey,
                          size: 28,
                        ),
                        onPressed: () => _toggleLike(post.id, post.isLiked, index),
                      ),
                      Text(
                        '${post.likesCount}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.comment, color: Colors.brown),
                    label: const Text('التعليقات', style: TextStyle(color: Colors.brown)),
                    onPressed: () {
                      Navigator.pushNamed(context, '/comments', arguments: {'postId': post.id});
                    },
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