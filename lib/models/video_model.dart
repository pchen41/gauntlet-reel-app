class VideoModel {
  final String uid;
  final String title;
  final String description;
  final String url;
  final String thumbnailUrl;
  final String userId;

  VideoModel({
    required this.uid,
    required this.title,
    required this.description,
    required this.url,
    required this.thumbnailUrl,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'title': title,
      'description': description,
      'url': url,
      'thumbnail_url': thumbnailUrl,
      'user_id': userId,
    };
  }

  factory VideoModel.fromMap(Map<String, dynamic> map) {
    return VideoModel(
      uid: map['uid'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      url: map['url'] ?? '',
      thumbnailUrl: map['thumbnail_url'] ?? '',
      userId: map['user_id'] ?? '',
    );
  }
} 