import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import '../../../providers/chat_provider.dart';
import '../lessons/lesson_detail_screen.dart';
import '../../widgets/image_viewer_dialog.dart';
import '../goals/goal_detail_screen.dart';
import '../../services/goal_service.dart';

class CoachAIScreen extends StatefulWidget {
  final List<Map<String, dynamic>> existingGoals;
  final VoidCallback onGoalsModified;
  
  const CoachAIScreen({
    super.key,
    required this.existingGoals,
    required this.onGoalsModified,
  });

  @override
  State<CoachAIScreen> createState() => _CoachAIScreenState();
}

class _CoachAIScreenState extends State<CoachAIScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GoalService _goalService = GoalService();
  XFile? _selectedImage;
  XFile? _selectedVideo;
  bool _isComposing = false;
  final Map<String, String> _acceptedGoals = {}; // Maps goal name to created Goal ID
  final Map<String, CachedVideoPlayerPlusController> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    // Initialize accepted goals from existing goals
    for (final goal in widget.existingGoals) {
      _acceptedGoals[goal['name']] = goal['id'];
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animate: false);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    if (_scrollController.hasClients) {
      if (animate) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty && _selectedImage == null && _selectedVideo == null) return;

    final chatProvider = context.read<ChatProvider>();
    final imagePath = _selectedImage?.path;
    final videoPath = _selectedVideo?.path;
    _messageController.clear();
    setState(() {
      _selectedImage = null;
      _selectedVideo = null;
      _isComposing = false;
    });

    try {
      await chatProvider.sendMessage(message, imagePath: imagePath, videoPath: videoPath);
      _scrollToBottom(animate: true);
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = image;
          _selectedVideo = null; // Clear video selection when image is picked
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30), // Limit video duration to 30 seconds
      );

      if (video != null) {
        setState(() {
          _selectedVideo = video;
          _selectedImage = null; // Clear image selection when video is picked
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting video: $e')),
      );
    }
  }

  void _cancelMediaSelection() {
    setState(() {
      _selectedImage = null;
      _selectedVideo = null;
    });
  }

  Widget _buildMessage(Message message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!message.isUser) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.grey[800],
                    child: const Icon(Icons.auto_awesome, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: message.isUser
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.imageUrl != null) ...[
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => ImageViewerDialog(
                                imageUrl: message.imageUrl!,
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              message.imageUrl!,
                              fit: BoxFit.cover,
                              width: 300,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return SizedBox(
                                  width: 300,
                                  height: 150,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 300,
                                  height: 150,
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: Icon(Icons.error_outline),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        if (message.text.isNotEmpty) const SizedBox(height: 8),
                      ],
                      if (message.videoUrl != null) ...[
                        FutureBuilder(
                          future: _initializeVideoController(message.videoUrl!),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.done) {
                              final controller = _videoControllers[message.videoUrl!]!;
                              return GestureDetector(
                                onTap: () => _showFullScreenVideo(controller),
                                child: SizedBox(
                                  height: 200,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        AspectRatio(
                                          aspectRatio: controller.value.aspectRatio,
                                          child: CachedVideoPlayerPlus(controller),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.black45,
                                            borderRadius: BorderRadius.circular(24),
                                          ),
                                          child: const Icon(
                                            Icons.play_arrow,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              return const SizedBox(
                                width: 300,
                                height: 200,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                          },
                        ),
                        if (message.text.isNotEmpty) const SizedBox(height: 8),
                      ],
                      if (message.text.isNotEmpty)
                        Text(
                          message.text,
                          style: TextStyle(
                            color: message.isUser ? Colors.white : Colors.black87,
                          ),
                        ),
                      if (!message.isUser && message.lessons != null && message.lessons!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: -8,
                          children: message.lessons!.map((lesson) => OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LessonDetailScreen(lessonId: lesson.id),
                                ),
                              );
                            },
                            icon: const Icon(Icons.play_lesson, size: 18),
                            label: Text(
                              lesson.title,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(0, 32),
                              foregroundColor: Theme.of(context).colorScheme.primary,
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          )).toList(),
                        ),
                      ],
                      if (!message.isUser && 
                          (message.goals != null && message.goals!.isNotEmpty) || 
                          (message.proposedGoals != null && message.proposedGoals!.isNotEmpty)) ...[
                        SizedBox(height: (message.lessons != null && message.lessons!.isNotEmpty) ? 2 : 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: -8,
                          children: [
                            ...?message.goals?.map((goal) => OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => GoalDetailScreen(goalId: goal.id),
                                  ),
                                );                              },
                              icon: const Icon(Icons.flag, size: 18, color: Colors.green),
                              label: Text(
                                goal.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: const Size(0, 32),
                                foregroundColor: Colors.green,
                                side: BorderSide(
                                  color: Colors.green,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            )),
                            ...?message.proposedGoals?.map((goal) => OutlinedButton.icon(
                              onPressed: () {
                                if (_acceptedGoals.containsKey(goal.name)) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => GoalDetailScreen(
                                        goalId: _acceptedGoals[goal.name]!,
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      backgroundColor: Theme.of(context).brightness == Brightness.dark
                                          ? const Color(0xFF2C2C2C)
                                          : null,
                                      title: Text('Proposed Goal'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Goal: ${goal.name}'),
                                          if (goal.tasks.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Tasks:'),
                                                  ...goal.tasks.map((task) => Padding(
                                                    padding: const EdgeInsets.only(left: 16.0, top: 4.0),
                                                    child: Text('• ${task.name}'),
                                                  )),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            try {
                                              final goalId = await _goalService.addGoalFromProposal(goal);
                                              setState(() {
                                                _acceptedGoals[goal.name] = goalId;
                                              });
                                              if (!mounted) return;
                                              Navigator.pop(context);
                                              widget.onGoalsModified(); // Refresh welcome screen
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Goal created successfully!'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            } catch (e) {
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error creating goal: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          },
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.green,
                                          ),
                                          child: const Text('Accept Goal'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: const Size(0, 32),
                                foregroundColor: _acceptedGoals.containsKey(goal.name) 
                                    ? Colors.green 
                                    : Colors.orange,
                                side: BorderSide(
                                  color: _acceptedGoals.containsKey(goal.name) 
                                      ? Colors.green 
                                      : Colors.orange,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              icon: Icon(
                                _acceptedGoals.containsKey(goal.name) 
                                    ? Icons.check_circle 
                                    : Icons.add_task,
                                size: 18,
                                color: _acceptedGoals.containsKey(goal.name) 
                                    ? Colors.green 
                                    : Colors.orange,
                              ),
                              label: Text(
                                goal.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _acceptedGoals.containsKey(goal.name) 
                                      ? Colors.green 
                                      : Colors.orange,
                                ),
                              ),
                            )),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (message.isUser) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _initializeVideoController(String videoUrl) async {
    if (!_videoControllers.containsKey(videoUrl)) {
      final controller = CachedVideoPlayerPlusController.network(
        videoUrl,
        videoPlayerOptions: VideoPlayerOptions(
          allowBackgroundPlayback: false,
        ),
      );
      await controller.initialize();
      _videoControllers[videoUrl] = controller;
    }
  }

  void _showFullScreenVideo(CachedVideoPlayerPlusController controller) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    if (controller.value.isPlaying) {
                      controller.pause();
                    } else {
                      controller.play();
                    }
                  },
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: CachedVideoPlayerPlus(controller),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black54, Colors.transparent],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 28),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach AI Chat'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'clear_chat') {
                try {
                  final chatProvider = context.read<ChatProvider>();
                  await chatProvider.clearChat();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chat history cleared'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error clearing chat: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'clear_chat',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline),
                    SizedBox(width: 8),
                    Text('Clear Chat'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          if (chatProvider.messages.isEmpty) {
            return const Center(
              child: Text('No messages yet'),
            );
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom(animate: true);
          });

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: chatProvider.messages.length,
                  itemBuilder: (context, index) => _buildMessage(chatProvider.messages[index]),
                ),
              ),
              if (_selectedImage != null || _selectedVideo != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(_selectedImage != null ? Icons.image : Icons.video_library, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedImage?.name ?? _selectedVideo?.name ?? '',
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _cancelMediaSelection,
                        tooltip: 'Cancel media selection',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 24.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        enabled: !chatProvider.isLoading,
                        decoration: InputDecoration(
                          hintText: 'Ask Coach AI...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add_photo_alternate),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                builder: (BuildContext context) {
                                  return SafeArea(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          leading: const Icon(Icons.photo),
                                          title: const Text('Upload Photo'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _pickImage();
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.videocam),
                                          title: const Text('Upload Video'),
                                          subtitle: const Text('Max 8 MB'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _pickVideo();
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                            tooltip: 'Upload Media',
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: IconButton(
                        icon: chatProvider.isLoading
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).brightness == Brightness.light
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.send,
                                color: Theme.of(context).brightness == Brightness.light
                                    ? Colors.white
                                    : Colors.black,
                              ),
                        onPressed: chatProvider.isLoading ? null : _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
