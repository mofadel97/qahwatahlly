import 'package:flutter/material.dart';
import 'package:qahwatahlly/models/post.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/post_card.dart';
import '../widgets/new_post_dialog.dart';
import '../services/post_service.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentOffset = 0;
  final int _limit = 10;
  bool _hasMorePosts = true;
  RealtimeChannel? _postsChannel;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadDataWithDelay();
    _setupRealtime();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _postsChannel?.unsubscribe();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoadingMore && _hasMorePosts) {
      _loadMorePosts();
    }
  }

  Future<void> _loadDataWithDelay() async {
    setState(() {
      _isLoading = true;
    });

    while (!isSupabaseInitialized) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    try {
      await Future.wait([
        _loadUserProfile(),
        _loadInitialPosts(),
      ]);
    } catch (e) {
      print('Error loading data: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في تحميل البيانات: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final avatarUrl = await _postService.loadUserProfile();
      setState(() {
        _userAvatarUrl = avatarUrl;
      });
    } catch (e) {
      print('Error loading user profile: $e');
      throw 'خطأ في تحميل الملف الشخصي: $e';
    }
  }

  Future<void> _loadInitialPosts() async {
    try {
      final posts = await _postService.loadPosts(limit: _limit, offset: 0);
      setState(() {
        _posts = posts;
        _currentOffset = posts.length;
        _hasMorePosts = posts.length == _limit;
      });
    } catch (e) {
      print('Error loading initial posts: $e');
      throw 'خطأ في تحميل المنشورات: $e';
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMorePosts) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final morePosts = await _postService.loadPosts(limit: _limit, offset: _currentOffset);
      setState(() {
        _posts.addAll(morePosts);
        _currentOffset = _posts.length;
        _hasMorePosts = morePosts.length == _limit;
      });
    } catch (e) {
      print('Error loading more posts: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في تحميل المزيد من المنشورات: $e')));
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _setupRealtime() {
    _postsChannel = _postService.setupRealtime(() async {
      await _loadInitialPosts();
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
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _posts.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Center(child: Text('لا توجد منشورات بعد')),
                        )
                      : SizedBox(
                          height: MediaQuery.of(context).size.height - 200,
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: _posts.length + (_hasMorePosts ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _posts.length && _hasMorePosts) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              return PostCard(
                                post: _posts[index],
                                onToggleLike: (postId, isLiked, _) => _toggleLike(postId, isLiked, index),
                                onDelete: (postId, _) => _deletePost(postId, index),
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
          onPressed: () => NewPostDialog.show(context, onPostSubmitted: _loadInitialPosts),
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
            GestureDetector(
              onTap: () {
                if (context.mounted) {
                  Navigator.pushNamed(context, '/reels');
                }
              },
              child: Icon(Icons.video_library, color: _isDarkMode ? Colors.white : Colors.grey, size: 36),
            ),
            Column(
              children: [
                Icon(Icons.home, color: _isDarkMode ? Colors.red[700] : Colors.red[600], size: 36),
                Container(height: 2, width: 24, color: _isDarkMode ? Colors.red[700] : Colors.red[600]),
              ],
            ),
            GestureDetector(
              onTap: () {
                if (context.mounted) {
                  Navigator.pushNamed(context, '/profile');
                }
              },
              child: CircleAvatar(
                radius: 18,
                backgroundImage: _userAvatarUrl != null ? CachedNetworkImageProvider(_userAvatarUrl!) : null,
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