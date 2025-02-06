import 'package:cloud_firestore/cloud_firestore.dart';

class GoalTask {
  final String name;
  final bool completed;
  final String comments;
  final String type;
  final String value;

  const GoalTask({
    required this.name,
    required this.completed,
    this.comments = '',
    required this.type,
    required this.value,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'completed': completed,
      'comments': comments,
      'type': type,
      'value': value,
    };
  }

  factory GoalTask.fromMap(Map<String, dynamic> map) {
    return GoalTask(
      name: map['name'] ?? '',
      completed: map['completed'] ?? false,
      comments: map['comments'] ?? '',
      type: map['type'] ?? 'text',
      value: map['value'] ?? '',
    );
  }

  GoalTask copyWith({
    String? name,
    bool? completed,
    String? comments,
    String? type,
    String? value,
  }) {
    return GoalTask(
      name: name ?? this.name,
      completed: completed ?? this.completed,
      comments: comments ?? this.comments,
      type: type ?? this.type,
      value: value ?? this.value,
    );
  }
}

class Goal {
  final String id;
  final String name;
  final List<GoalTask> tasks;
  final DateTime updatedAt;

  const Goal({
    required this.id,
    required this.name,
    required this.tasks,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'tasks': tasks.map((task) => task.toMap()).toList(),
      'updated_at': updatedAt,
    };
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      tasks: (map['tasks'] as List<dynamic>?)
          ?.map((task) => GoalTask.fromMap(Map<String, dynamic>.from(task)))
          .toList() ?? [],
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
