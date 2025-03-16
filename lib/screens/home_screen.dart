import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'comments_screen.dart';

class _Post {
  final String id;
  final String content;
  final String? imageUrl;
  final String username;
  int likesCount;
  bool isLiked;
  final String? avatarUrl;

  _Post({
    required this.id,
    required this.content,
    this.imageUrl,
    required this.username,
    this.likesCount = 0,
    this.isLiked = false,
    this.avatarUrl,
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

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final response = await _supabase
          .from('posts')
          .select('id, content, image_url, user_id')
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
      print('Error toggling like: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // title: Container(
        //   padding: const EdgeInsets.symmetric(vertical: 8.0),
        //   child: Image.asset('assets/images/Logo.png', height: 40),
        // ),
        centerTitle: true,
        backgroundColor: Colors.brown[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await _supabase.auth.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        child: _posts.isEmpty
            ? const Center(child: Text('لا توجد منشورات بعد', style: TextStyle(fontSize: 18, color: Colors.grey)))
            : ListView.builder(
          padding: const EdgeInsets.all(12.0),
          itemCount: _posts.length,
          itemBuilder: (context, index) {
            final post = _posts[index];
            return Card(
              elevation: 5,
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: post.avatarUrl != null
                              ? NetworkImage(post.avatarUrl!)
                              : null,
                          backgroundColor: post.avatarUrl == null
                              ? Colors.brown[200]
                              : null,
                          child: post.avatarUrl == null
                              ? Text(post.username[0], style: const TextStyle(color: Colors.white))
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            post.username,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      post.content,
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    if (post.imageUrl != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(post.imageUrl!, height: 200, width: double.infinity, fit: BoxFit.cover),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                post.isLiked ? Icons.favorite : Icons.favorite_border,
                                color: post.isLiked ? Colors.red : Colors.grey,
                              ),
                              onPressed: () => _toggleLike(post.id, post.isLiked, index),
                            ),
                            Text('${post.likesCount} إعجاب'),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CommentsScreen(postId: post.id),
                              ),
                            );
                          },
                          child: const Text('التعليقات', style: TextStyle(color: Colors.brown)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.brown[600],
        onPressed: () {
          Navigator.pushNamed(context, '/post').then((_) => _loadPosts());
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}