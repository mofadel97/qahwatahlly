import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Comment {
  final String id;
  final String content;
  final String username;
  final String? avatarUrl;

  _Comment({required this.id, required this.content, required this.username, this.avatarUrl});
}

class CommentsScreen extends StatefulWidget {
  final String postId;

  const CommentsScreen({super.key, required this.postId});

  @override
  _CommentsScreenState createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _supabase = Supabase.instance.client;
  final _commentController = TextEditingController();
  List<_Comment> _comments = [];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final response = await _supabase
          .from('comments')
          .select('id, content, user_id')
          .eq('post_id', int.parse(widget.postId))
          .order('created_at', ascending: true);

      final commentsWithUsers = await Future.wait(response.map((comment) async {
        final profile = await _supabase
            .from('profiles')
            .select('username, avatar_url')
            .eq('id', comment['user_id'])
            .single();
        return _Comment(
          id: comment['id'].toString(),
          content: comment['content'],
          username: profile['username'] ?? 'مجهول',
          avatarUrl: profile['avatar_url'],
        );
      }).toList());

      setState(() {
        _comments = commentsWithUsers;
      });
    } catch (e) {
      print('Error loading comments: $e');
    }
  }

  Future<void> _addComment() async {
    final user = _supabase.auth.currentUser;
    if (user == null || _commentController.text.isEmpty) return;

    try {
      await _supabase.from('comments').insert({
        'post_id': int.parse(widget.postId),
        'user_id': user.id,
        'content': _commentController.text,
      });
      _commentController.clear();
      _loadComments();
    } catch (e) {
      print('Error adding comment: $e');
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
      ),
      body: Column(
        children: [
          Expanded(
            child: _comments.isEmpty
                ? const Center(child: Text('لا توجد تعليقات بعد', style: TextStyle(fontSize: 18, color: Colors.grey)))
                : ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: _comments.length,
              itemBuilder: (context, index) {
                final comment = _comments[index];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundImage: comment.avatarUrl != null
                        ? NetworkImage(comment.avatarUrl!)
                        : null,
                    backgroundColor: comment.avatarUrl == null
                        ? Colors.brown[200]
                        : null,
                    child: comment.avatarUrl == null
                        ? Text(comment.username[0], style: const TextStyle(color: Colors.white))
                        : null,
                  ),
                  title: Text(comment.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(comment.content),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      labelText: 'أضف تعليقًا',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.comment, color: Colors.brown),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.brown),
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}