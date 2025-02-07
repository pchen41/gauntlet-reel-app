import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/goal_model.dart';
import '../../services/goal_service.dart';
import '../lessons/lesson_detail_screen.dart';

class GoalDetailScreen extends StatefulWidget {
  final Goal goal;

  const GoalDetailScreen({
    super.key,
    required this.goal,
  });

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  final GoalService _goalService = GoalService();
  final Map<String, Map<String, dynamic>> _lessonCache = {};
  bool _isLoading = false;
  List<GoalTask> _tasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final goals = await _goalService.getGoals();
    final goal = goals.firstWhere((g) => g['id'] == widget.goal.id);
    setState(() {
      _tasks = (goal['tasks'] as List<dynamic>?)
          ?.map((task) => GoalTask.fromMap(Map<String, dynamic>.from(task)))
          .toList() ?? [];
    });
  }

  Future<void> _addTask() async {
    final task = await showDialog<GoalTask>(
      context: context,
      builder: (context) => const AddTaskDialog(),
    );

    if (task != null) {
      setState(() => _isLoading = true);
      try {
        await _goalService.addTask(widget.goal.id, task);
        await _refreshGoal();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding task: $e')),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleTask(int index, bool? value) async {
    if (value == null) return;

    setState(() => _isLoading = true);
    try {
      List<GoalTask> updatedTasks = List.from(_tasks);
      updatedTasks[index] = updatedTasks[index].copyWith(completed: value);
      
      await _goalService.updateTasks(
        widget.goal.id,
        updatedTasks.map((task) => task.toMap()).toList(),
      );
      await _refreshGoal();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating task: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTask(int index) async {
    final deletedTask = _tasks.removeAt(index);
    setState(() {});

    try {
      await _goalService.updateTasks(
        widget.goal.id,
        _tasks.map((task) => task.toMap()).toList(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tasks.insert(index, deletedTask);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting task: $e')),
      );
    }
  }

  Future<void> _editTaskComments(int index) async {
    final task = _tasks[index];
    final comments = await showDialog<String>(
      context: context,
      builder: (context) => TaskCommentsDialog(initialComments: task.comments),
    );

    if (comments != null) {
      setState(() => _isLoading = true);
      try {
        List<GoalTask> updatedTasks = List.from(_tasks);
        updatedTasks[index] = updatedTasks[index].copyWith(comments: comments);
        
        await _goalService.updateTasks(
          widget.goal.id,
          updatedTasks.map((t) => t.toMap()).toList(),
        );
        await _refreshGoal();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating task comments: $e')),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteGoal() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2C2C2C)
            : null,
        title: const Text('Delete Goal'),
        content: const Text('Are you sure you want to delete this goal and all its tasks?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      setState(() => _isLoading = true);
      try {
        await _goalService.deleteGoal(widget.goal.id);
        if (!mounted) return;
        Navigator.pop(context); // Return to goals screen
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting goal: $e')),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshGoal() async {
    final goals = await _goalService.getGoals();
    final updatedGoal = goals.firstWhere((g) => g['id'] == widget.goal.id);
    setState(() {
      _tasks = (updatedGoal['tasks'] as List<dynamic>?)
          ?.map((task) => GoalTask.fromMap(Map<String, dynamic>.from(task)))
          .toList() ?? [];
    });
  }

  Future<void> _loadLessonDetails(String lessonId) async {
    if (_lessonCache.containsKey(lessonId)) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('lessons')
          .doc(lessonId)
          .get();
      
      if (doc.exists) {
        _lessonCache[lessonId] = doc.data()!;
      }
    } catch (e) {
      debugPrint('Error loading lesson details: $e');
    }
  }

  Future<void> _openLesson(String lessonId) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LessonDetailScreen(lessonId: lessonId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.goal.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteGoal,
            tooltip: 'Delete Goal',
          ),
        ],
      ),
      body: Stack(
        children: [
          ReorderableListView.builder(
            itemCount: _tasks.length,
            onReorder: (oldIndex, newIndex) async {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              setState(() {
                final task = _tasks.removeAt(oldIndex);
                _tasks.insert(newIndex, task);
              });
              try {
                await _goalService.updateTasks(
                  widget.goal.id,
                  _tasks.map((task) => task.toMap()).toList(),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error reordering tasks: $e')),
                );
                await _refreshGoal(); // Revert to server state on error
              }
            },
            itemBuilder: (context, index) {
              final task = _tasks[index];
              return Dismissible(
                key: ValueKey('dismissible_${index}_${task.name}'),
                background: Container(
                  color: Theme.of(context).colorScheme.error,
                  alignment: Alignment.centerLeft,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(Icons.delete, color: Colors.white),
                  ),
                ),
                secondaryBackground: Container(
                  color: Theme.of(context).colorScheme.error,
                  alignment: Alignment.centerRight,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(Icons.delete, color: Colors.white),
                  ),
                ),
                onDismissed: (direction) {
                  _deleteTask(index);
                },
                child: Card(
                  key: ValueKey('card_${index}_${task.name}'),
                  elevation: 0,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle),
                    ),
                    contentPadding: task.type == 'lesson'
                        ? const EdgeInsets.fromLTRB(16, 4, 12, 0)
                        : const EdgeInsets.fromLTRB(16, 0, 12, 0),
                    title: Text(task.name),
                    subtitle: (task.comments.isNotEmpty || task.type == 'lesson')
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (task.comments.isNotEmpty)
                                Text(
                                  task.comments,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                  ),
                                ),
                              if (task.type == 'lesson')
                                FutureBuilder(
                                  future: _loadLessonDetails(task.value),
                                  builder: (context, snapshot) {
                                    final lesson = _lessonCache[task.value];
                                    return OutlinedButton.icon(
                                      onPressed: () => _openLesson(task.value),
                                      icon: const Icon(Icons.play_lesson, size: 18),
                                      label: Text(
                                        lesson?['title'] ?? 'Loading lesson...',
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
                                    );
                                  },
                                ),
                            ],
                          )
                        : null,
                    trailing: Checkbox(
                      value: task.completed,
                      onChanged: (value) => _toggleTask(index, value),
                    ),
                    onTap: () => _editTaskComments(index),
                  ),
                ),
              );
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddTaskDialog extends StatefulWidget {
  const AddTaskDialog({super.key});

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _taskController = TextEditingController();
  String? _selectedLessonId;
  List<Map<String, dynamic>> _lessons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _loadLessons() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('lessons')
          .get();

      setState(() {
        _lessons = snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  'title': (doc.data() as Map<String, dynamic>)['title'] ?? '',
                })
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading lessons: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final task = GoalTask(
        name: _taskController.text.trim(),
        completed: false,
        type: _selectedLessonId != null ? 'lesson' : 'text',
        value: _selectedLessonId ?? _taskController.text.trim(),
      );
      Navigator.of(context).pop(task);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDarkMode ? const Color(0xFF2C2C2C) : null,
      title: const Text('Add Task'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _taskController,
                decoration: const InputDecoration(
                  labelText: 'Task Name',
                  hintText: 'Enter task name',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a task name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_lessons.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedLessonId,
                  dropdownColor: isDarkMode ? const Color(0xFF2C2C2C) : null,
                  decoration: const InputDecoration(
                    labelText: 'Lesson (Optional)',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('No lesson'),
                    ),
                    ..._lessons.map((lesson) => DropdownMenuItem<String>(
                          value: lesson['id'],
                          child: Text(lesson['title']),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedLessonId = value;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class TaskCommentsDialog extends StatefulWidget {
  final String initialComments;

  const TaskCommentsDialog({
    super.key,
    required this.initialComments,
  });

  @override
  State<TaskCommentsDialog> createState() => _TaskCommentsDialogState();
}

class _TaskCommentsDialogState extends State<TaskCommentsDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialComments);
  }

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
              'Comments',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Enter a comment for this task',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
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
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
