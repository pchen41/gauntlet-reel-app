import 'package:cloud_firestore/cloud_firestore.dart';

class VideoModel {
  final String uid;
  final String id;  // This is the document ID
  final String title;
  final String description;
  final String url;
  final String thumbnailUrl;
  final Timestamp createdAt;

  VideoModel({
    required this.uid,
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    required this.thumbnailUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'title': title,
      'description': description,
      'url': url,
      'thumbnail_url': thumbnailUrl,
      'created_at': createdAt,
    };
  }

  factory VideoModel.fromMap(Map<String, dynamic> map, String documentId) {
    return VideoModel(
      uid: map['uid'] ?? '',
      id: documentId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      url: map['url'] ?? '',
      thumbnailUrl: map['thumbnail_url'] ?? '',
      createdAt: map['created_at'] as Timestamp,
    );
  }
}