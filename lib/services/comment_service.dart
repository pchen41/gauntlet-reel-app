import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/comment_model.dart';

class CommentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addComment(String userId, String videoId, String text) async {
    await _firestore.collection('comments').add({
      'uid': userId,
      'video_id': videoId,
      'text': text,
      'created_at': DateTime.now(),
    });
  }

  Stream<List<CommentModel>> getComments(String videoId) {
    return _firestore
        .collection('comments')
        .where('video_id', isEqualTo: videoId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommentModel.fromMap(doc.data()))
            .toList());
  }

  Stream<int> getCommentCount(String videoId) {
    return _firestore
        .collection('comments')
        .where('video_id', isEqualTo: videoId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
} 