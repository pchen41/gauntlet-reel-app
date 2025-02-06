import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../models/user_model.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../services/video_service.dart';
import '../../widgets/video_player_screen.dart';
import '../../models/video_model.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/lesson_service.dart';
import '../lessons/lesson_detail_screen.dart';
import 'package:flutter/services.dart';

class ProfileScreen extends StatefulWidget {
  ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final VideoService _videoService = VideoService();
  final LessonService _lessonService = LessonService();
  late TabController _tabController;
  UserModel? _user;
  bool _isLoading = true;
  List<Map<String, dynamic>> _bookmarkedLessons = [];
  List<Map<String, dynamic>> _likedVideos = [];
  Map<String, Map<String, dynamic>> _videoLessons = {};  // Map of video ID to lesson data

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      if (_user == null) {
        final userData = await _userService.getUser(_authService.currentUser!.uid);
        if (!mounted) return;
        if (userData != null) {
          _user = UserModel.fromMap(userData);
        }
      }

      await _loadUserContent();
    } catch (e) {
      print('Error loading profile data: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e')),
      );
    }
  }

  Future<void> _loadUserContent() async {
    try {
      // Get all lessons first
      final allLessons = await _lessonService.getAllLessons();
      
      // Get bookmark statuses for all lessons
      final bookmarkStatuses = await _lessonService.getLessonBookmarkStatuses(
        _authService.currentUser!.uid,
        allLessons.map((lesson) => lesson['id'] as String).toList(),
      );
      
      // Filter to only bookmarked lessons
      final bookmarkedLessons = allLessons.where(
        (lesson) => bookmarkStatuses[lesson['id']] == true
      ).toList();

      // Get liked videos
      final likedVideos = await _videoService.getLikedVideos(_authService.currentUser!.uid);
      
      // Create a map of video IDs to find which lesson each video belongs to
      Map<String, Map<String, dynamic>> videoLessons = {};
      
      // For each lesson, check if it contains any of our liked videos
      for (var lesson in allLessons) {
        final List<dynamic> lessonVideos = lesson['videos'] ?? [];
        for (var video in likedVideos) {
          if (lessonVideos.contains(video['id'])) {
            videoLessons[video['id']] = lesson;
          }
        }
      }
      
      if (!mounted) return;
      setState(() {
        _bookmarkedLessons = bookmarkedLessons;
        _likedVideos = likedVideos;
        _videoLessons = videoLessons;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading content: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRefresh() async {
    await _loadUserContent();
  }

  Widget _buildLessonList(List<Map<String, dynamic>> lessons) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= lessons.length) return null;
          final lesson = lessons[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[700]!
                    : Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16.0),
              title: Text(
                lesson['title'] ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.0,
                ),
              ),
              subtitle: Text(
                lesson['description'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LessonDetailScreen(
                      lessonId: lesson['id'],
                    ),
                  ),
                );
                // Refresh data when returning from lesson detail
                if (mounted) {
                  _loadUserContent();
                }
              },
            ),
          );
        },
        childCount: lessons.length,
      ),
    );
  }

  Widget _buildVideoGrid(List<Map<String, dynamic>> videos) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= videos.length) return null;
          final video = videos[index];
          final lesson = _videoLessons[video['id']];
          
          return GestureDetector(
            onTap: () async {
              // If we found the lesson this video belongs to, get all its videos
              if (lesson != null) {
                final lessonDetails = await _lessonService.getLessonDetails(lesson['id']);
                if (lessonDetails != null && mounted) {
                  final lessonVideos = (lessonDetails['videos'] as List<dynamic>)
                    .map((v) => VideoModel.fromMap(v as Map<String, dynamic>, v['id'] as String))
                    .toList();
                  
                  // Find the index of our current video in the lesson's videos
                  final currentVideoIndex = lessonVideos
                    .indexWhere((v) => v.id == video['id']);
                  
                  if (currentVideoIndex != -1) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoPlayerScreen(
                          videos: lessonVideos,
                          initialIndex: currentVideoIndex,
                          lessonTitle: lesson['title'],
                        ),
                      ),
                    );
                    if (mounted) {
                      _loadUserContent();
                    }
                  }
                }
              }
            },
            onLongPress: lesson != null ? () async {
              HapticFeedback.lightImpact();
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LessonDetailScreen(
                    lessonId: lesson['id'],
                  ),
                ),
              );
              if (mounted) {
                _loadUserContent();
              }
            } : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: Colors.grey[300],
                  child: video['thumbnail_url'] != null
                      ? Image.network(
                          video['thumbnail_url'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print('Error loading thumbnail: $error');
                            return const Center(
                              child: Icon(
                                Icons.error_outline,
                                size: 30,
                                color: Colors.grey,
                              ),
                            );
                          },
                        )
                      : const Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            size: 30,
                            color: Colors.grey,
                          ),
                        ),
                ),
              ],
            ),
          );
        },
        childCount: videos.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return Icon(
                  themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                );
              },
            ),
            onPressed: () {
              final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
              themeProvider.toggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // User Info Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  _user?.name ?? 'Loading...',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _user?.email ?? 'Loading...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.only(bottom: 4),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Bookmarked'),
                Tab(text: 'Liked'),
              ],
              dividerColor: Theme.of(context).dividerColor.withOpacity(0.1),
            ),
          ),
          // Scrollable content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.only(top: 2),
                      sliver: _buildLessonList(_bookmarkedLessons),
                    ),
                  ],
                ),
                CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                      sliver: _buildVideoGrid(_likedVideos),
                    ),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(6, 2, 0, 0),
                        child: Text(
                          'Long press a thumbnail to view the lesson',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
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
    );
  }
}

class _VideoDetailsDialog extends StatefulWidget {
  @override
  _VideoDetailsDialogState createState() => _VideoDetailsDialogState();
}

class _VideoDetailsDialogState extends State<_VideoDetailsDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Video Details'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'Enter video title',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Enter video description',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.isEmpty) {
              return;
            }
            Navigator.pop(context, {
              'title': _titleController.text,
              'description': _descriptionController.text,
            });
          },
          child: const Text('Upload'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}