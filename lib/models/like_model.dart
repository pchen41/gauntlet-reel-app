import 'package:cloud_firestore/cloud_firestore.dart';

class LikeModel {
  final String uid;
  final String videoId;
  final DateTime createdAt;

  LikeModel({
    required this.uid,
    required this.videoId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'video_id': videoId,
      'created_at': createdAt,
    };
  }

  factory LikeModel.fromMap(Map<String, dynamic> map) {
    return LikeModel(
      uid: map['uid'] ?? '',
      videoId: map['video_id'] ?? '',
      createdAt: (map['created_at'] as Timestamp).toDate(),
    );
  }
} 