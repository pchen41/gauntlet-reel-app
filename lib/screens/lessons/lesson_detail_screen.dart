import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../services/lesson_service.dart';
import '../../widgets/video_player_widget.dart';
import '../../models/video_model.dart';
import '../video/video_feed_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LessonDetailScreen extends StatefulWidget {
  final String lessonId;

  const LessonDetailScreen({
    Key? key,
    required this.lessonId,
  }) : super(key: key);

  @override
  _LessonDetailScreenState createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  final LessonService _lessonService = LessonService();
  Map<String, dynamic>? _lessonData;
  Map<String, bool> _videoLikeStatuses = {};
  bool _isLoading = true;
  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();
    _loadLessonData();
  }

  Future<void> _loadLessonData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final lessonData = await _lessonService.getLessonDetails(widget.lessonId);
        if (lessonData != null) {
          final videoIds = (lessonData['videos'] as List)
              .map((video) => video['id'] as String)
              .toList();
          
          final likeStatuses = await _lessonService.getVideoLikeStatuses(
            user.uid,
            videoIds,
          );

          final isBookmarked = await _lessonService.getLessonBookmarkStatuses(
            user.uid,
            [widget.lessonId],
          );

          if (mounted) {
            setState(() {
              _lessonData = lessonData;
              _videoLikeStatuses = likeStatuses;
              _isBookmarked = isBookmarked[widget.lessonId] ?? false;
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading lesson: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleBookmark() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final isBookmarked = await _lessonService.toggleLessonBookmark(
          user.uid,
          widget.lessonId,
        );
        setState(() {
          _isBookmarked = isBookmarked;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating bookmark: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleLike(String videoId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final isLiked = await _lessonService.toggleVideoLike(user.uid, videoId);
        setState(() {
          _videoLikeStatuses[videoId] = isLiked;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating like: $e')),
          );
        }
      }
    }
  }

  Future<void> _showAISummary() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to use this feature')),
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('summarizeLesson').call({
        'lessonId': widget.lessonId,
      });

      if (!mounted) return;
      Navigator.of(context).pop(); // Dismiss loading dialog

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('AI Lesson Summary'),
          content: SingleChildScrollView(
            child: Text(result.data['response']['content'][0]['text'] ?? 'No summary available'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Dismiss loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting AI summary: $e')),
      );
    }
  }

  Widget _buildVideoList() {
    final videos = (_lessonData?['videos'] as List<dynamic>?) ?? [];
    if (videos.isEmpty) {
      return const Center(
        child: Text('No videos available'),
      );
    }

    return Container(
      color: Theme.of(context).brightness == Brightness.dark
          ? null
          : Colors.white,
      child: ListView.builder(
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final video = videos[index];
          final isLiked = _videoLikeStatuses[video['id']] ?? false;
          final thumbnailUrl = video['thumbnail_url'];
          final double thumbnailWidth = 78.0;
          
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16.0),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[700]!
                    : Colors.grey[400]!,
                width: 1,
              ),
            ),
            child: InkWell(
              onTap: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await _lessonService.updateLessonView(
                    user.uid,
                    widget.lessonId,
                    index,
                  );
                }

                // Convert lesson videos to VideoModel list
                final lessonVideos = (_lessonData!['videos'] as List)
                    .map((video) => VideoModel(
                          id: video['id'],
                          uid: video['uid'] ?? '',
                          title: video['title'] ?? '',
                          description: video['description'] ?? '',
                          url: video['url'] ?? '',
                          thumbnailUrl: video['thumbnail_url'],
                          createdAt: video['created_at'] as Timestamp? ?? 
                              Timestamp.fromDate(DateTime.now()),
                        ))
                    .toList();

                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoFeedScreen(
                        videos: lessonVideos,
                        initialIndex: index,
                      ),
                    ),
                  );
                }
              },
              child: SizedBox(
                height: 75,
                child: Row(
                  children: [
                    if (thumbnailUrl != null)
                      SizedBox(
                        width: thumbnailWidth,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                          child: CachedNetworkImage(
                            height: double.infinity,
                            imageUrl: thumbnailUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[300],                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.error),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 56.0, 12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  video['title'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.0,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Expanded(
                                  child: Text(
                                    video['description'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 0,
                            bottom: 0,
                            right: 8,
                            child: Center(
                              child: GestureDetector(
                                onTap: () => _toggleLike(video['id']),
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Icon(
                                    isLiked ? Icons.favorite : Icons.favorite_border,
                                    color: isLiked 
                                        ? Colors.red
                                        : Theme.of(context).brightness == Brightness.dark
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson Details'),
        elevation: 0,
        actions: [
          GestureDetector(
            onTap: _toggleBookmark,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Icon(
                _isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                color: _isBookmarked 
                    ? Theme.of(context).colorScheme.secondary
                    : Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                size: 24,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lessonData == null
              ? const Center(child: Text('Lesson not found'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _lessonData!['title'],
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _lessonData!['description'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[700],
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.play_circle_outline,
                                            size: 18,
                                            color: Theme.of(context).colorScheme.secondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${(_lessonData!['videos'] as List).length} ${(_lessonData!['videos'] as List).length == 1 ? 'video' : 'videos'}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Theme.of(context).colorScheme.secondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: _showAISummary,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary,
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.auto_awesome,
                                              size: 18,
                                              color: Theme.of(context).colorScheme.onPrimary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'AI Summary',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Theme.of(context).colorScheme.onPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _buildVideoList(),
                    ),
                  ],
                ),
    );
  }
}
