import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../models/user_model.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../services/video_service.dart';
import '../../widgets/video_player_screen.dart';
import '../../models/video_model.dart';

class ProfileScreen extends StatefulWidget {
  ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final VideoService _videoService = VideoService();
  late TabController _tabController;
  UserModel? _user;
  bool _isLoading = true;
  List<Map<String, dynamic>> _userVideos = [];
  List<Map<String, dynamic>> _likedVideos = [];

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
      // Only load user data if not already loaded
      if (_user == null) {
        final userData = await _userService.getUser(_authService.currentUser!.uid);
        if (!mounted) return;
        if (userData != null) {
          _user = UserModel.fromMap(userData);
        }
      }

      await _loadUserVideos();
    } catch (e) {
      print('Error loading profile data: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e')),
      );
    }
  }

  Future<void> _loadUserVideos() async {
    try {
      final userVideos = await _videoService.getUserVideos(_authService.currentUser!.uid);
      final likedVideos = await _videoService.getLikedVideos(_authService.currentUser!.uid);
      
      for (var video in userVideos) {
        print('Video thumbnail URL: ${video['thumbnail_url']}');
      }
      
      if (!mounted) return;
      setState(() {
        _userVideos = userVideos;
        _likedVideos = likedVideos;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading videos: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRefresh() async {
    await _loadUserVideos();
  }

  Future<void> _handleUpload() async {
    try {
      // Pick video file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.first.path!);
      
      if (!mounted) return;
      // Show dialog for video details
      final videoDetails = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => _VideoDetailsDialog(),
      );

      if (videoDetails == null) return;

      // Show loading indicator
      setState(() => _isLoading = true);

      // Upload video
      await _videoService.uploadVideo(
        videoFile: file,
        userId: _authService.currentUser!.uid,
        title: videoDetails['title']!,
        description: videoDetails['description']!,
      );

      // Reload user data to show new video
      await _loadUserVideos();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video uploaded successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildVideoGrid(List<Map<String, dynamic>> videos) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= videos.length) return null;
          final video = videos[index];
          return GestureDetector(
            onTap: () {
              final videoModels = videos.map((data) => VideoModel(
                id: data['id'] ?? '',
                uid: data['uid'] ?? '',
                title: data['title'] ?? '',
                description: data['description'] ?? '',
                url: data['url'] ?? '',
                thumbnailUrl: data['thumbnail_url'] ?? '',
                createdAt: data['created_at']?.millisecondsSinceEpoch ?? 0,
              )).toList();

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoPlayerScreen(
                    videos: videoModels,
                    initialIndex: index,
                  ),
                ),
              );
            },
            child: Container(
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
        title: const Text('ReelAI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _user?.name ?? 'Unknown User',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _user?.email ?? '',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _handleUpload,
                    icon: const Icon(Icons.upload),
                    label: const Text('Upload Video'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Uploaded'),
                      Tab(text: 'Liked'),
                    ],
                  ),
                ],
              ),
            ),
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  CustomScrollView(
                    slivers: [_buildVideoGrid(_userVideos)],
                  ),
                  CustomScrollView(
                    slivers: [_buildVideoGrid(_likedVideos)],
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