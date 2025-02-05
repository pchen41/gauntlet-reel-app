import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../models/video_model.dart';
import '../../services/video_service.dart';
import '../../services/auth_service.dart';
import '../profile/profile_screen.dart';
import '../../services/like_service.dart';
import '../../services/comment_service.dart';
import '../../widgets/comment_sheet.dart';

class HomeScreen extends StatefulWidget {
  HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const FeedScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final VideoService _videoService = VideoService();
  final PageController _pageController = PageController();
  List<VideoModel> _videos = [];
  bool _isLoading = true;
  int _currentVideoIndex = 0;
  final Map<String, GlobalKey<_VideoPlayerWidgetState>> _videoKeys = {};

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    try {
      final videos = await _videoService.getVideos();
      setState(() {
        _videos = videos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_videos.isEmpty) {
      return const Center(
        child: Text('No videos available'),
      );
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      controller: _pageController,
      itemCount: _videos.length,
      onPageChanged: (index) {
        setState(() => _currentVideoIndex = index);
        // Handle video cleanup
        for (int i = 0; i < _videos.length; i++) {
          if ((i - index).abs() > 1) {
            _videoKeys[_videos[i].uid]?.currentState?.pauseAndReleaseVideo();
          }
        }
        // Loop back to first video
        if (index == _videos.length - 1) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _pageController.jumpToPage(0);
          });
        }
      },
      itemBuilder: (context, index) {
        final video = _videos[index];
        _videoKeys[video.uid] ??= GlobalKey<_VideoPlayerWidgetState>();
        if ((index - _currentVideoIndex).abs() > 1) {
          return Container(color: Colors.black);
        }
        return VideoPlayerWidget(
          key: _videoKeys[video.uid],
          video: video,
        );
      },
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final VideoModel video;
  final bool isVisible;

  const VideoPlayerWidget({
    Key? key,
    required this.video,
    this.isVisible = true,
  }) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  final LikeService _likeService = LikeService();
  final AuthService _authService = AuthService();
  bool _isInitialized = false;
  bool _isDisposed = false;

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
    
    _controller = VideoPlayerController.network(
      widget.video.url,
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
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
        } else {
          _controller?.play();
        }
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller?.value.size.width,
                  height: _controller?.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 16,
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
              bottom: 16,
              child: Column(
                children: [
                  StreamBuilder<bool>(
                    stream: _likeService.hasUserLiked(
                      _authService.currentUser!.uid,
                      widget.video.uid,
                    ),
                    builder: (context, hasLikedSnapshot) {
                      return StreamBuilder<int>(
                        stream: _likeService.getLikeCount(widget.video.uid),
                        builder: (context, likesSnapshot) {
                          return _ActionButton(
                            icon: hasLikedSnapshot.data == true
                                ? Icons.favorite
                                : Icons.favorite_border,
                            label: '${likesSnapshot.data ?? 0}',
                            onTap: () => _likeService.toggleLike(
                              _authService.currentUser!.uid,
                              widget.video.uid,
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
                    stream: CommentService().getCommentCount(widget.video.uid),
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
                              child: CommentSheet(videoId: widget.video.uid),
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