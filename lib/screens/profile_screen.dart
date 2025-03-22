import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qahwatahlly/models/post.dart';
import 'package:qahwatahlly/services/post_service.dart';
import 'package:qahwatahlly/screens/components/avatar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _postService = PostService();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _bioController = TextEditingController();
  String? _email;
  String? _avatarUrl;
  String? _coverUrl;
  File? _selectedAvatar;
  File? _selectedCover;
  List<Post> _userPosts = [];
  List<Post> _reels = [];
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _followersCount = 0;
  int _followingCount = 0;
  int _postsCount = 0;
  TabController? _tabController;
  final ScrollController _scrollController = ScrollController();
  int _currentOffset = 0;
  final int _limit = 10;
  bool _hasMorePosts = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDataWithDelay();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    _bioController.dispose();
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
        _loadProfile(),
        _loadInitialPosts(),
        _loadFollowStats(),
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

  Future<void> _loadProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final response = await _supabase
            .from('profiles')
            .select('email, username, full_name, bio, avatar_url, cover_url')
            .eq('id', user.id)
            .maybeSingle();
        if (response != null) {
          setState(() {
            _email = response['email'] ?? user.email;
            _usernameController.text = response['username'] ?? '';
            _fullNameController.text = response['full_name'] ?? '';
            _bioController.text = response['bio'] ?? '';
            _avatarUrl = response['avatar_url'];
            _coverUrl = response['cover_url'];
          });
          print('Profile loaded: avatar_url = $_avatarUrl, cover_url = $_coverUrl');
        } else {
          await _supabase.from('profiles').insert({
            'id': user.id,
            'email': user.email,
          });
          setState(() {
            _email = user.email;
          });
        }
      }
    } catch (e) {
      print('Error loading profile: $e');
      throw 'خطأ في تحميل الملف الشخصي: $e';
    }
  }

  Future<void> _loadInitialPosts() async {
    try {
      final posts = await _postService.loadUserPosts(limit: _limit, offset: 0);
      setState(() {
        _userPosts = posts;
        _postsCount = posts.length;
        _currentOffset = posts.length;
        _hasMorePosts = posts.length == _limit;
        _reels = [];
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
      final morePosts = await _postService.loadUserPosts(limit: _limit, offset: _currentOffset);
      setState(() {
        _userPosts.addAll(morePosts);
        _postsCount = _userPosts.length;
        _currentOffset = _userPosts.length;
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

  Future<void> _loadFollowStats() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final followers = await _supabase
          .from('follows')
          .select('follower_id')
          .eq('following_id', user.id)
          .count();
      final following = await _supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', user.id)
          .count();

      setState(() {
        _followersCount = followers.count;
        _followingCount = following.count;
      });
    } catch (e) {
      print('Error loading follow stats: $e');
    }
  }

  Future<String?> _uploadAvatar() async {
    if (_selectedAvatar == null) return _avatarUrl;

    final user = _supabase.auth.currentUser;
    if (user == null) throw 'يرجى تسجيل الدخول';

    try {
      final fileName = '${user.id}_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      print('Uploading avatar to: avatar-url/$fileName');
      await _supabase.storage.from('avatar-url').upload(
            fileName,
            _selectedAvatar!,
            fileOptions: const FileOptions(upsert: true),
          );
      final newAvatarUrl = _supabase.storage.from('avatar-url').getPublicUrl(fileName);
      print('Avatar uploaded successfully: $newAvatarUrl');
      return newAvatarUrl;
    } catch (e) {
      print('Error uploading avatar: $e');
      throw 'فشل في رفع الصورة الشخصية: $e';
    }
  }

  Future<String?> _uploadCover() async {
    if (_selectedCover == null) return _coverUrl;

    final user = _supabase.auth.currentUser;
    if (user == null) throw 'يرجى تسجيل الدخول';

    try {
      final fileName = '${user.id}_cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
      print('Uploading cover to: cover-url/$fileName');
      await _supabase.storage.from('cover-url').upload(
            fileName,
            _selectedCover!,
            fileOptions: const FileOptions(upsert: true),
          );
      final newCoverUrl = _supabase.storage.from('cover-url').getPublicUrl(fileName);
      print('Cover uploaded successfully: $newCoverUrl');
      return newCoverUrl;
    } catch (e) {
      print('Error uploading cover: $e');
      throw 'فشل في رفع صورة الغلاف: $e';
    }
  }

  Future<void> _updateProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تسجيل الدخول')));
      return;
    }

    try {
      print('Starting avatar upload...');
      final newAvatarUrl = await _uploadAvatar();
      print('Starting cover upload...');
      final newCoverUrl = await _uploadCover();
      print('New avatar URL: $newAvatarUrl, New cover URL: $newCoverUrl');

      final updateData = {
        'id': user.id,
        'username': _usernameController.text,
        'full_name': _fullNameController.text,
        'bio': _bioController.text,
        'avatar_url': newAvatarUrl,
        'cover_url': newCoverUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };
      print('Updating profile with data: $updateData');
      await _supabase.from('profiles').upsert(updateData);
      print('Profile updated successfully');

      await _loadProfile();

      setState(() {
        _selectedAvatar = null;
        _selectedCover = null;
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الملف الشخصي بنجاح!')));
    } catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في التحديث: $e')));
    }
  }

  Future<void> _deleteAvatar() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('profiles').update({'avatar_url': null}).eq('id', user.id);
      await _loadProfile();
      setState(() {
        _selectedAvatar = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الصورة الشخصية بنجاح!')));
    } catch (e) {
      print('Error deleting avatar: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في حذف الصورة الشخصية: $e')));
    }
  }

  Future<void> _deleteCover() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('profiles').update({'cover_url': null}).eq('id', user.id);
      await _loadProfile();
      setState(() {
        _selectedCover = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف صورة الغلاف بنجاح!')));
    } catch (e) {
      print('Error deleting cover: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في حذف صورة الغلاف: $e')));
    }
  }

  void _showImageOptions(BuildContext context, bool isAvatar) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload, color: Colors.white),
              title: Text('تحميل الصورة', style: GoogleFonts.cairo(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final imageFile = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Avatar(
                      imageUrl: isAvatar ? _avatarUrl : _coverUrl,
                      onImageSelected: (file) => Navigator.pop(context, file),
                    ),
                  ),
                );
                if (imageFile != null) {
                  setState(() {
                    if (isAvatar) {
                      _selectedAvatar = imageFile;
                    } else {
                      _selectedCover = imageFile;
                    }
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: Text('تغيير الصورة', style: GoogleFonts.cairo(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final imageFile = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Avatar(
                      imageUrl: isAvatar ? _avatarUrl : _coverUrl,
                      onImageSelected: (file) => Navigator.pop(context, file),
                    ),
                  ),
                );
                if (imageFile != null) {
                  setState(() {
                    if (isAvatar) {
                      _selectedAvatar = imageFile;
                    } else {
                      _selectedCover = imageFile;
                    }
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.white),
              title: Text('حذف الصورة', style: GoogleFonts.cairo(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                if (isAvatar) {
                  _deleteAvatar();
                } else {
                  _deleteCover();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'الملف الشخصي',
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.brown[600],
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.brown))
          : SingleChildScrollView(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _isEditing ? () => _showImageOptions(context, false) : null,
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      color: Colors.grey[800],
                      child: _coverUrl != null
                          ? CachedNetworkImage(
                              imageUrl: _coverUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                              errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
                            )
                          : const Center(child: Icon(Icons.add_a_photo, color: Colors.white, size: 50)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -50),
                        child: GestureDetector(
                          onTap: _isEditing ? () => _showImageOptions(context, true) : null,
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.black,
                            child: CircleAvatar(
                              radius: 56,
                              backgroundImage: _avatarUrl != null ? CachedNetworkImageProvider(_avatarUrl!) : null,
                              child: _avatarUrl == null ? const Icon(Icons.person, size: 56, color: Colors.white) : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // استبدلنا SizedBox(height: -40) بمسافة إيجابية صغيرة
                  const SizedBox(height: 8),
                  Text(
                    _fullNameController.text.isNotEmpty ? _fullNameController.text : 'لا يوجد اسم',
                    style: GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  Text(
                    '@${_usernameController.text}',
                    style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _bioController.text.isNotEmpty ? _bioController.text : 'لا توجد نبذة',
                    style: GoogleFonts.cairo(fontSize: 14, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text('$_postsCount', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                          Text('منشورات', style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey[600])),
                        ],
                      ),
                      Column(
                        children: [
                          Text('$_followersCount', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                          Text('متابعين', style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey[600])),
                        ],
                      ),
                      Column(
                        children: [
                          Text('$_followingCount', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                          Text('متابعات', style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isEditing ? _updateProfile : () => setState(() => _isEditing = true),
                            child: Text(
                              _isEditing ? 'حفظ' : 'تعديل الملف الشخصي',
                              style: GoogleFonts.cairo(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TabBar(
                    controller: _tabController,
                    labelStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold),
                    unselectedLabelStyle: GoogleFonts.cairo(fontSize: 16),
                    indicatorColor: Colors.brown[600],
                    labelColor: Colors.brown[600],
                    unselectedLabelColor: Colors.grey[600],
                    tabs: const [
                      Tab(icon: Icon(Icons.grid_on), text: 'منشورات'),
                      Tab(icon: Icon(Icons.video_library), text: 'ريلز'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 400,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _userPosts.isEmpty
                            ? const Center(child: Text('لا توجد منشورات بعد', style: TextStyle(color: Colors.black54)))
                            : GridView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(8.0),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 4,
                                  crossAxisSpacing: 4,
                                  childAspectRatio: 1,
                                ),
                                itemCount: _userPosts.length + (_hasMorePosts ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == _userPosts.length && _hasMorePosts) {
                                    return const Center(child: CircularProgressIndicator());
                                  }
                                  final post = _userPosts[index];
                                  return Container(
                                    color: Colors.grey[800],
                                    child: post.imageUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: post.imageUrl!,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                                            errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
                                          )
                                        : const Icon(Icons.image, color: Colors.white),
                                  );
                                },
                              ),
                        _reels.isEmpty
                            ? const Center(child: Text('لا توجد ريلز بعد', style: TextStyle(color: Colors.black54)))
                            : GridView.builder(
                                padding: const EdgeInsets.all(8.0),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 4,
                                  crossAxisSpacing: 4,
                                  childAspectRatio: 1,
                                ),
                                itemCount: _reels.length,
                                itemBuilder: (context, index) {
                                  final reel = _reels[index];
                                  return Container(
                                    color: Colors.grey[800],
                                    child: reel.imageUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: reel.imageUrl!,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                                            errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
                                          )
                                        : const Icon(Icons.video_library, color: Colors.white),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}