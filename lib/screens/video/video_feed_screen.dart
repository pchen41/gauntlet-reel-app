import 'package:flutter/material.dart';
import '../../models/video_model.dart';
import '../../services/video_service.dart';
import '../../widgets/video_player_widget.dart';

class VideoFeedScreen extends StatefulWidget {
  final List<VideoModel> videos;
  final int initialIndex;

  const VideoFeedScreen({
    super.key,
    required this.videos,
    required this.initialIndex,
  });

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  final PageController _pageController = PageController();
  int _currentVideoIndex = 0;
  final Map<String, GlobalKey<VideoPlayerWidgetState>> _videoKeys = {};

  @override
  void initState() {
    super.initState();
    _currentVideoIndex = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageController.jumpToPage(widget.initialIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _pageController,
        itemCount: widget.videos.length,
        onPageChanged: (index) {
          for (int i = 0; i < widget.videos.length; i++) {
            if ((i - index).abs() > 1) {
              _videoKeys['${widget.videos[i].uid}_$i']?.currentState?.pauseAndReleaseVideo();
            }
          }
          setState(() => _currentVideoIndex = index);
        },
        itemBuilder: (context, index) {
          final video = widget.videos[index];
          final keyString = '${video.uid}_$index';
          _videoKeys[keyString] ??= GlobalKey<VideoPlayerWidgetState>();
          
          if ((index - _currentVideoIndex).abs() > 1) {
            return Container(color: Colors.black);
          }
          return VideoPlayerWidget(
            key: _videoKeys[keyString],
            video: video,
            isVisible: index == _currentVideoIndex,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
