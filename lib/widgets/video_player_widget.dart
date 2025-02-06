import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/video_model.dart';
import '../services/like_service.dart';
import '../services/auth_service.dart';
import '../services/comment_service.dart';
import './comment_sheet.dart';

class VideoPlayerWidget extends StatefulWidget {
  final VideoModel video;
  final bool isVisible;

  const VideoPlayerWidget({
    super.key,
    required this.video,
    this.isVisible = true,
  });

  @override
  State<VideoPlayerWidget> createState() => VideoPlayerWidgetState();
}

class VideoPlayerWidgetState extends State<VideoPlayerWidget> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  final LikeService _likeService = LikeService();
  final AuthService _authService = AuthService();
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _showPlayPauseIcon = false;
  IconData _currentIcon = Icons.pause;
  double _iconOpacity = 0.0;

  void _showPlayPauseAnimation(bool isPlaying) {
    setState(() {
      _showPlayPauseIcon = true;
      _iconOpacity = 1.0;
      _currentIcon = isPlaying ? Icons.play_arrow : Icons.pause;
    });
    
    // Start fading out immediately
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() {
          _iconOpacity = 0.0;
        });
      }
    });
    
    // Hide the icon container after animation completes
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          _showPlayPauseIcon = false;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeVideo();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller?.pause();
    }
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isVisible && _controller?.value.isPlaying == true) {
      _controller?.pause();
    } else if (widget.isVisible && _controller?.value.isPlaying == false) {
      _controller?.play();
    }
  }

  Future<void> _initializeVideo() async {
    if (_isDisposed) return;
    print('Loading video: ${widget.video.url}');
    
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.video.url),
      videoPlayerOptions: VideoPlayerOptions(
        allowBackgroundPlayback: false,
      ),
    );

    try {
      await _controller?.setLooping(true);
      await _controller?.initialize();
      if (mounted && !_isDisposed) {
        setState(() => _isInitialized = true);
        _controller?.play();
      }
    } catch (e) {
      print('Error initializing video: $e');
    }
  }

  Future<void> pauseAndReleaseVideo() async {
    await _controller?.pause();
    await _controller?.dispose();
    _controller = null;
    if (mounted) {
      setState(() => _isInitialized = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTap: () {
        if (_controller?.value.isPlaying == true) {
          _controller?.pause();
          _showPlayPauseAnimation(false);
        } else {
          _controller?.play();
          _showPlayPauseAnimation(true);
        }
      },
      child: Stack(
        children: [
          Container(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),
          if (_showPlayPauseIcon)
            AnimatedOpacity(
              opacity: _iconOpacity,
              duration: const Duration(milliseconds: 300),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _currentIcon,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 16,
            bottom: 36,
            right: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.video.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        blurRadius: 8,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.video.description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    shadows: [
                      Shadow(
                        blurRadius: 8,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 36,
            child: Column(
              children: [
                StreamBuilder<bool>(
                  stream: _likeService.hasUserLiked(
                    _authService.currentUser!.uid,
                    widget.video.id,
                  ),
                  builder: (context, hasLikedSnapshot) {
                    return StreamBuilder<int>(
                      stream: _likeService.getLikeCount(widget.video.id),
                      builder: (context, likesSnapshot) {
                        return _ActionButton(
                          icon: hasLikedSnapshot.data == true
                              ? Icons.favorite
                              : Icons.favorite_border,
                          label: '${likesSnapshot.data ?? 0}',
                          onTap: () => _likeService.toggleLike(
                            _authService.currentUser!.uid,
                            widget.video.id,
                          ),
                          color: hasLikedSnapshot.data == true
                              ? Colors.red
                              : Colors.white,
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),
                StreamBuilder<int>(
                  stream: CommentService().getCommentCount(widget.video.id),
                  builder: (context, snapshot) {
                    return _ActionButton(
                      icon: Icons.comment,
                      label: '${snapshot.data ?? 0}',
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => SizedBox(
                            height: MediaQuery.of(context).size.height * 0.75,
                            child: CommentSheet(videoId: widget.video.id),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 32,
            shadows: const [Shadow(blurRadius: 8, color: Colors.black)],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              shadows: const [Shadow(blurRadius: 8, color: Colors.black)],
            ),
          ),
        ],
      ),
    );
  }
}