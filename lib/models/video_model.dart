class VideoModel {
  final String uid;
  final String id;
  final String title;
  final String description;
  final String url;
  final String thumbnailUrl;
  final int createdAt;

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
      'id': id,
      'title': title,
      'description': description,
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      'createdAt': createdAt,
    };
  }

  factory VideoModel.fromMap(Map<String, dynamic> map) {
    return VideoModel(
      uid: map['uid'],
      id: map['id'],
      title: map['title'],
      description: map['description'],
      url: map['url'],
      thumbnailUrl: map['thumbnailUrl'],
      createdAt: map['createdAt'],
    );
  }
} 