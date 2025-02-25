import 'package:flutter/material.dart';
import '../../services/goal_service.dart';
import '../../services/lesson_service.dart';
import '../../services/user_service.dart';
import '../../models/goal_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../lessons/lesson_detail_screen.dart';
import '../goals/goal_detail_screen.dart';
import '../chat/coach_ai_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final LessonService _lessonService = LessonService();
  final GoalService _goalService = GoalService();
  final UserService _userService = UserService();
  bool _isLoading = true;
  String _userName = '';
  int _viewedLessons = 0;
  int _completedObjectives = 0;
  int _completedGoals = 0;
  List<Map<String, dynamic>> _recentLessons = [];
  List<Map<String, dynamic>> _goals = [];
  List<Map<String, dynamic>> _allGoals = [];

  @override
  void initState() {
    super.initState();
    _loadUserProgress();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  String _pluralize(int count, String singular, String plural) {
    return '$count ${count == 1 ? singular : plural}';
  }

  List<TextSpan> _buildProgressSpans(BuildContext context) {
    if (_completedObjectives == 0 && _completedGoals == 0 && _viewedLessons == 0) {
      return [
        TextSpan(text: '${_getGreeting()}, $_userName. '),
        TextSpan(text: 'Welcome to ClimbCoach.'),
      ];
    }

    final parts = <String>[];
    
    if (_completedObjectives > 0) {
      parts.add(_pluralize(_completedObjectives, 'objective', 'objectives'));
    }
    
    if (_completedGoals > 0) {
      parts.add(_pluralize(_completedGoals, 'goal', 'goals'));
    }
    
    if (_viewedLessons > 0) {
      parts.add(_pluralize(_viewedLessons, 'lesson', 'lessons'));
    }

    if (parts.isEmpty) return [];

    final spans = <TextSpan>[
      TextSpan(text: '${_getGreeting()}, $_userName. '),
    ];

    if (parts.length == 1) {
      spans.add(TextSpan(text: "You've completed ${parts[0]}."));
    } else {
      final lastPart = parts.removeLast();
      spans.add(TextSpan(text: "You've completed ${parts.join(', ')} and $lastPart."));
    }

    return spans;
  }

  Future<void> _loadUserProgress() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Fetch user data from Firestore
      final userData = await _userService.getUser(user.uid);
      final name = userData?['name'] ?? 'Climber';
      final goals = await _goalService.getGoals();
      
      int objectives = 0;
      int completedGoals = 0;

      // Filter out completed goals and count objectives
      final activeGoals = goals.where((goal) {
        final tasks = (goal['tasks'] as List<dynamic>?) ?? [];
        final isCompleted = tasks.isNotEmpty && tasks.every((task) => task['completed'] == true);
        
        // Count objectives and completed goals for the progress message
        objectives += tasks.where((task) => task['completed'] == true).length;
        if (isCompleted) completedGoals++;
        
        // Only keep incomplete goals
        return !isCompleted;
      }).toList();

      // Get all user's lessons
      final viewedLessons = await _lessonService.getRecentlyViewedLessons(user.uid);

      if (mounted) {
        setState(() {
          _completedObjectives = objectives;
          _completedGoals = completedGoals;
          _viewedLessons = viewedLessons.length;
          _userName = name;
          _recentLessons = viewedLessons;
          _goals = activeGoals.take(3).toList();
          _allGoals = goals; // Store all goals, including completed ones
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user progress: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildLessonCard(Map<String, dynamic> lesson) {
    final thumbnailUrl = lesson['thumbnail_url'];
    final double thumbnailWidth = 78.0;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
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
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LessonDetailScreen(lessonId: lesson['id']),
            ),
          );
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
                        color: Colors.grey[300],
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.error),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    thumbnailUrl != null ? 12.0 : 16.0,
                    10.0,
                    16.0,
                    10.0
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        lesson['title'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lesson['description'] ?? '',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                          fontSize: 14.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalCard(Map<String, dynamic> goalMap) {
    final goal = Goal.fromMap(goalMap);
    final completedTasks = goal.tasks.where((task) => task.completed).length;
    final totalTasks = goal.tasks.length;
    final allTasksCompleted = completedTasks == totalTasks && totalTasks > 0;
    final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
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
        onTap: () => _navigateToGoal(goalMap['id']),
        child: ListTile(
          contentPadding: EdgeInsets.fromLTRB(16, completedTasks > 0 ? 4 : 0, 16, completedTasks > 0 ? 8 : 4),
          title: Text(
            goal.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              Text(
                '$completedTasks of $totalTasks tasks completed',
                style: TextStyle(
                  fontSize: 13.0,
                  color: allTasksCompleted
                      ? Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF81C784) // Lighter green for dark mode
                          : const Color(0xFF2E7D32) // Darker green for light mode
                      : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              if (completedTasks > 0) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      allTasksCompleted
                          ? Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF81C784) // Lighter green for dark mode
                              : const Color(0xFF2E7D32) // Darker green for light mode
                          : Theme.of(context).colorScheme.primary,
                    ),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 1.5), // Added additional padding after progress bar
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToGoal(String goalId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GoalDetailScreen(
          goalId: goalId,
          onTasksModified: _loadUserProgress,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CoachAIScreen(
                existingGoals: _allGoals,
                onGoalsModified: _loadUserProgress,
              ),
            ),
          );
        },
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Coach AI'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0),
              child: Row(
                children: [
                  const Icon(
                    Icons.sports_gymnastics,
                    size: 32,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'ClimbCoach',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24.0, 4.0, 24.0, 80.0), // Added bottom padding for FAB
                  children: [
                    RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                        children: _buildProgressSpans(context),
                      ),
                    ),
                    if (_recentLessons.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Text(
                        'Recent Lessons',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ...(_recentLessons.take(3).map(_buildLessonCard).toList()),
                    ],
                    if (_goals.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Text(
                        'Top Goals',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ...(_goals.take(3).map((g) => _buildGoalCard(g)).toList()),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
