import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/like_model.dart';

class LikeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> toggleLike(String userId, String videoId) async {
    final likeRef = _firestore
        .collection('likes')
        .where('uid', isEqualTo: userId)
        .where('video_id', isEqualTo: videoId)
        .limit(1);

    final querySnapshot = await likeRef.get();

    if (querySnapshot.docs.isEmpty) {
      // Like doesn't exist, create it
      await _firestore.collection('likes').add({
        'uid': userId,
        'video_id': videoId,
        'created_at': DateTime.now(),
      });
    } else {
      // Like exists, remove it
      await querySnapshot.docs.first.reference.delete();
    }
  }

  Stream<int> getLikeCount(String videoId) {
    return _firestore
        .collection('likes')
        .where('video_id', isEqualTo: videoId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<bool> hasUserLiked(String userId, String videoId) {
    return _firestore
        .collection('likes')
        .where('uid', isEqualTo: userId)
        .where('video_id', isEqualTo: videoId)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }
} 