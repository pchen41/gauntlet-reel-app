import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String uid;
  final String videoId;
  final String text;
  final DateTime createdAt;

  CommentModel({
    required this.uid,
    required this.videoId,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'video_id': videoId,
      'text': text,
      'created_at': createdAt,
    };
  }

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    return CommentModel(
      uid: map['uid'] ?? '',
      videoId: map['video_id'] ?? '',
      text: map['text'] ?? '',
      createdAt: (map['created_at'] as Timestamp).toDate(),
    );
  }
} 