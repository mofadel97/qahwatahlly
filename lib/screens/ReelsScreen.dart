import 'package:flutter/material.dart';
import 'package:qahwatahlly/models/reel.dart';
import 'package:qahwatahlly/services/reel_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  _ReelsScreenState createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final ReelService _reelService = ReelService();
  List<Reel> _reels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReels();
  }

  Future<void> _loadReels() async {
    try {
      final reels = await _reelService.loadReels();
      setState(() {
        _reels = reels;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل الريلز: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الريلز'),
        backgroundColor: Colors.red[600],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reels.isEmpty
              ? const Center(child: Text('لا توجد ريلز بعد'))
              : PageView.builder(
                  scrollDirection: Axis.vertical,
                  itemCount: _reels.length,
                  itemBuilder: (context, index) {
                    return ReelWidget(reel: _reels[index]);
                  },
                ),
    );
  }
}

class ReelWidget extends StatefulWidget {
  final Reel reel;

  const ReelWidget({required this.reel});

  @override
  _ReelWidgetState createState() => _ReelWidgetState();
}

class _ReelWidgetState extends State<ReelWidget> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.reel.videoUrl != null) {
      _controller = VideoPlayerController.network(widget.reel.videoUrl!)
        ..initialize().then((_) {
          setState(() {});
          _controller!.play();
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (widget.reel.videoUrl != null && _controller != null && _controller!.value.isInitialized)
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          )
        else if (widget.reel.imageUrl != null)
          CachedNetworkImage(
            imageUrl: widget.reel.imageUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          )
        else
          const Center(child: Text('لا يوجد محتوى')),
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.reel.username != null)
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: widget.reel.avatarUrl != null
                          ? CachedNetworkImageProvider(widget.reel.avatarUrl!)
                          : null,
                      backgroundColor: Colors.grey[300],
                      child: widget.reel.avatarUrl == null ? const Icon(Icons.person) : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.reel.username!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              if (widget.reel.caption != null)
                Text(
                  widget.reel.caption!,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              const SizedBox(height: 8),
              Text(
                'الإعجابات: ${widget.reel.likesCount}',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}