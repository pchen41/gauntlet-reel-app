import 'package:flutter/material.dart';
import '../../models/video_model.dart';
import '../../services/video_service.dart';
import '../profile/profile_screen.dart';
import '../lessons/lessons_screen.dart';
import '../../widgets/video_player_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const FeedScreen(),
    const LessonsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '',
          ),
        ],
      ),
    );
  }
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final VideoService _videoService = VideoService();
  final PageController _pageController = PageController();
  List<VideoModel> _videos = [];
  bool _isLoading = true;
  int _currentVideoIndex = 0;
  final Map<String, GlobalKey<VideoPlayerWidgetState>> _videoKeys = {};

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
        for (int i = 0; i < _videos.length; i++) {
          if ((i - index).abs() > 1) {
            _videoKeys['${_videos[i].uid}_$i']?.currentState?.pauseAndReleaseVideo();
          }
        }
        setState(() => _currentVideoIndex = index);
      },
      itemBuilder: (context, index) {
        final video = _videos[index];
        final keyString = '${video.uid}_$index';
        _videoKeys[keyString] ??= GlobalKey<VideoPlayerWidgetState>();
        
        if ((index - _currentVideoIndex).abs() > 1) {
          return Container(color: Colors.black);
        }
        return VideoPlayerWidget(
          key: _videoKeys[keyString],
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