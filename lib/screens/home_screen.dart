import 'package:flutter/material.dart';
import 'package:qahwatahlly/models/post.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/post_card.dart';
import '../widgets/new_post_dialog.dart';
import '../services/post_service.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _postService = PostService();
  List<Post> _posts = [];
  String? _userAvatarUrl;
  bool _isDarkMode = false;
  RealtimeChannel? _postsChannel;
  RealtimeChannel? _commentsChannel;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadPosts();
    _setupRealtime();
  }

  @override
  void dispose() {
    _postsChannel?.unsubscribe();
    _commentsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    _userAvatarUrl = await _postService.loadUserProfile();
    setState(() {});
  }

  Future<void> _loadPosts() async {
    _posts = await _postService.loadPosts();
    setState(() {});
  }

  void _setupRealtime() {
    _postsChannel = _postService.setupRealtime(_loadPosts);
    _commentsChannel = Supabase.instance.client
        .channel('public:comments')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'comments',
          callback: (payload) {
            final postId = payload.newRecord['post_id'].toString();
            final index = _posts.indexWhere((post) => post.id == postId);
            if (index != -1) {
              setState(() {
                _posts[index].commentsCount += 1;
              });
            }
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            print('Subscribed to comments channel in HomeScreen');
          } else if (error != null) {
            print('Error subscribing to comments: $error');
          }
        });
  }

  void _toggleLike(String postId, bool isLiked, int index) async {
    try {
      await _postService.toggleLike(postId, isLiked);
      setState(() {
        _posts[index].isLiked = !isLiked;
        _posts[index].likesCount += isLiked ? -1 : 1;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الإعجاب: $e')));
    }
  }

  void _deletePost(String postId, int index) async {
    try {
      await _postService.deletePost(postId);
      setState(() {
        _posts.removeAt(index);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الحذف: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _isDarkMode ? darkTheme : lightTheme,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            _buildAppBar(),
            _buildNavBar(),
            SliverToBoxAdapter(
              child: _posts.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : SizedBox(
                      height: MediaQuery.of(context).size.height - 200,
                      child: ListView.builder(
                        itemCount: _posts.length,
                        itemBuilder: (context, index) {
                          return PostCard(
                            post: _posts[index],
                            onToggleLike: _toggleLike,
                            onDelete: _deletePost,
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: _isDarkMode ? Colors.red[900] : Colors.red[600],
          elevation: 6,
          onPressed: () => NewPostDialog.show(context, onPostSubmitted: _loadPosts),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('منشور جديد', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: true,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isDarkMode ? [const Color(0xFFD32F2F), const Color(0xFFB71C1C)] : [const Color(0xFFFFCDD2), const Color(0xFFF44336)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/LogoAlahly.png', height: 40, errorBuilder: (_, __, ___) => const Icon(Icons.error, color: Colors.white)),
                const SizedBox(width: 8),
                Text('قهوة الأهلوية', style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildNavBar() {
    return SliverToBoxAdapter(
      child: Container(
        color: _isDarkMode ? const Color(0xFF424242) : Colors.grey[100],
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            PopupMenuButton<String>(
              icon: Icon(Icons.menu, color: _isDarkMode ? Colors.white : Colors.grey, size: 36),
              onSelected: (value) {
                if (value == 'dark_mode') setState(() => _isDarkMode = !_isDarkMode);
                if (value == 'logout') {
                  Supabase.instance.client.auth.signOut();
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'dark_mode', child: Text(_isDarkMode ? 'الوضع الفاتح' : 'الوضع الداكن')),
                const PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج')),
              ],
            ),
            Icon(Icons.message, color: _isDarkMode ? Colors.white : Colors.grey, size: 36),
            Icon(Icons.sports_soccer, color: _isDarkMode ? Colors.white : Colors.grey, size: 36),
            _buildIconWithLabel(Icons.mic, 'قريبًا'),
            _buildIconWithLabel(Icons.video_library, 'قريبًا'),
            Column(
              children: [
                Icon(Icons.home, color: _isDarkMode ? Colors.red[700] : Colors.red[600], size: 36),
                Container(height: 2, width: 24, color: _isDarkMode ? Colors.red[700] : Colors.red[600]),
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
    );
  }

  Widget _buildIconWithLabel(IconData icon, String label) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(icon, color: _isDarkMode ? Colors.white : Colors.grey, size: 36),
        Positioned(
          top: 0,
          child: Container(
            padding: const EdgeInsets.all(2),
            color: Colors.black54,
            child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
          ),
        ),
      ],
    );
  }
}