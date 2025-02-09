import 'package:flutter/material.dart';
import '../../services/goal_service.dart';
import '../../models/goal_model.dart';
import 'goal_detail_screen.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({Key? key}) : super(key: key);

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final GoalService _goalService = GoalService();
  List<Goal> _goals = [];
  bool _isLoading = true;
  bool _showCompletedGoals = true;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    try {
      final goalsData = await _goalService.getGoals();
      if (!mounted) return;
      setState(() {
        _goals = goalsData.map((g) => Goal.fromMap(g)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading goals: $e')),
      );
    }
  }

  Future<void> _addGoal() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const AddGoalDialog(),
    );

    if (name != null && name.isNotEmpty) {
      try {
        await _goalService.addGoal(name);
        await _loadGoals();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding goal: $e')),
        );
      }
    }
  }

  Widget _buildGoalList() {
    final filteredGoals = _showCompletedGoals
        ? _goals
        : _goals.where((goal) => goal.tasks.any((task) => !task.completed) || goal.tasks.isEmpty).toList();

    if (filteredGoals.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 100),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'No goals yet',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Add goals to track your progress',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= filteredGoals.length) return null;
          final goal = filteredGoals[index];
          final completedTasks = goal.tasks.where((task) => task.completed).length;
          final allTasksCompleted = completedTasks == goal.tasks.length && goal.tasks.isNotEmpty;
          final progress = goal.tasks.isNotEmpty ? completedTasks / goal.tasks.length : 0.0;
          
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
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
                    '$completedTasks of ${goal.tasks.length} tasks completed',
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
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GoalDetailScreen(goalId: goal.id),
                  ),
                );
                _loadGoals(); // Refresh goals after returning from detail screen
              },
            ),
          );
        },
        childCount: filteredGoals.length,
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
        title: const Text('Goals'),
        actions: [
          PopupMenuButton<bool>(
            icon: const Icon(Icons.filter_list),
            offset: const Offset(0, 40),
            initialValue: _showCompletedGoals,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2C2C2C)
                : null,
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false, // Disable click-to-close behavior
                padding: EdgeInsets.zero,
                height: 40,
                child: Container(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2C2C2C)
                      : null,
                  child: StatefulBuilder(
                    builder: (context, setState) => CheckboxListTile(
                      title: Text(
                        'Completed goals',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                      value: _showCompletedGoals,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (bool? value) {
                        this.setState(() => _showCompletedGoals = value ?? true);
                        setState(() {});
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadGoals,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.only(top: 2),
              sliver: _buildGoalList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addGoal,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddGoalDialog extends StatefulWidget {
  const AddGoalDialog({super.key});

  @override
  State<AddGoalDialog> createState() => _AddGoalDialogState();
}

class _AddGoalDialogState extends State<AddGoalDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDarkMode ? const Color(0xFF2C2C2C) : null,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Goal',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Enter goal name',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onFieldSubmitted: (value) => Navigator.pop(context, value),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context, _controller.text),
                  child: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
