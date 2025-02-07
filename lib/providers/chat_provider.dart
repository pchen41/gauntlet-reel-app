import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  Message({
    required this.text,
    required this.isUser,
    required this.timestamp,
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

  Future<void> sendMessage(String message) async {
    if (message.isEmpty) return;

    _isLoading = true;
    _messages.add(Message(
      text: message,
      isUser: true,
      timestamp: DateTime.now(),
    ));
    notifyListeners();

    try {
      final functions = FirebaseFunctions.instance;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final result = await functions.httpsCallable('coachAIChatGenkit').call({
        'message': message,
        'uid': user.uid,
      });

      _messages.add(Message(
        text: result.data['response'].toString(),
        isUser: false,
        timestamp: DateTime.now(),
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
}
