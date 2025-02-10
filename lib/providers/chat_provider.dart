import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;

class Lesson {
  final String title;
  final String description;
  final String id;

  Lesson({
    required this.title,
    required this.description,
    required this.id,
  });

  factory Lesson.fromJson(Map<Object?, Object?> json) {
    return Lesson(
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
    );
  }
}

class Goal {
  final String id;
  final String name;

  Goal({
    required this.id,
    required this.name,
  });

  factory Goal.fromJson(Map<Object?, Object?> json) {
    return Goal(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  // Convert to GoalModel type
  Goal toGoalModel() {
    return Goal(
      id: id,
      name: name,
    );
  }
}

class Task {
  final String name;
  final bool completed;
  final String comments;
  final String type;
  final String value;

  Task({
    required this.name,
    required this.completed,
    required this.comments,
    required this.type,
    required this.value,
  });

  factory Task.fromJson(Map<Object?, Object?> json) {
    return Task(
      name: json['name']?.toString() ?? '',
      completed: json['completed'] == true,
      comments: json['comments']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
    );
  }
}

class ProposedGoal {
  final String name;
  final List<Task> tasks;

  ProposedGoal({
    required this.name,
    required this.tasks,
  });

  factory ProposedGoal.fromJson(Map<Object?, Object?> json) {
    final tasksList = json['tasks'];
    return ProposedGoal(
      name: json['name']?.toString() ?? '',
      tasks: (tasksList is List)
          ? tasksList
              .map((task) => Task.fromJson(task as Map<Object?, Object?>))
              .toList()
          : [],
    );
  }
}

class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<Lesson>? lessons;
  final List<Goal>? goals;
  final List<ProposedGoal>? proposedGoals;
  final String? imageUrl;

  Message({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.lessons,
    this.goals,
    this.proposedGoals,
    this.imageUrl,
  });
}

class ChatProvider extends ChangeNotifier {
  final List<Message> _messages = [
    Message(
      text: "Hello! I'm your ClimbCoach AI assistant. How can I help you today?",
      isUser: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
  ];

  List<Message> get messages => List.unmodifiable(_messages);
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<String?> _uploadImage(String filePath) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final file = File(filePath);
      final fileName = path.basename(filePath);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('images')
          .child(user.uid)
          .child(fileName);

      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask;
      
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> sendMessage(String message, {String? imagePath}) async {
    if (message.isEmpty && imagePath == null) return;

    _isLoading = true;
    notifyListeners();

    String? imageUrl;
    
    try {
      final functions = FirebaseFunctions.instance;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      if (imagePath != null) {
        imageUrl = await _uploadImage(imagePath);
        if (imageUrl == null) {
          throw Exception('Failed to upload image');
        }
      }

      _messages.add(Message(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
        imageUrl: imageUrl,
      ));

      
      /*if (imagePath != null) {
        // set message to include base64 image
        final bytes = await File(imagePath).readAsBytes();
        final base64Image = base64Encode(bytes);
        message = 'This is a base64 image:\n"$base64Image"\n\n$message';
      }*/

      final result = await functions.httpsCallable('coachAiGenkitStructured').call({
        'message': message,
        'uid': user.uid,
        if (imageUrl != null) 'image': imageUrl,
      });

      final data = result.data as Map<Object?, Object?>;
      final lessonsList = data['lessons'];
      final goalsList = data['goals'];
      final proposedGoalsList = data['proposedGoals'];
      
      _messages.add(Message(
        text: data['response']?.toString() ?? 'No response received',
        isUser: false,
        timestamp: DateTime.now(),
        lessons: (lessonsList is List)
            ? lessonsList
                .map((lesson) => Lesson.fromJson(lesson as Map<Object?, Object?>))
                .toList()
            : null,
        goals: (goalsList is List)
            ? goalsList
                .map((goal) => Goal.fromJson(goal as Map<Object?, Object?>))
                .toList()
            : null,
        proposedGoals: (proposedGoalsList is List)
            ? proposedGoalsList
                .map((goal) => ProposedGoal.fromJson(goal as Map<Object?, Object?>))
                .toList()
            : null,
      ));
    } catch (e) {
      _messages.add(Message(
        text: "I apologize, but I encountered an error. Please try again.",
        isUser: false,
        timestamp: DateTime.now(),
      ));
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearChat() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Reference to the main document and its messages subcollection
      final mainDocRef = FirebaseFirestore.instance
          .collection('genkit_chats')
          .doc(user.uid);
          
      final messagesCollectionRef = mainDocRef.collection('messages');
      
      // Get all documents in the messages subcollection
      final messagesSnapshot = await messagesCollectionRef.get();
      
      // Delete all documents in the messages subcollection
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Clear local messages except the initial greeting
      _messages.clear();
      _messages.add(Message(
        text: "Hello! I'm your ClimbCoach AI assistant. How can I help you today?",
        isUser: false,
        timestamp: DateTime.now(),
      ));
      
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
}
