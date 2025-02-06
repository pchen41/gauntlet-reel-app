import 'package:cloud_firestore/cloud_firestore.dart';

class LessonService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> getAllLessons() async {
    final QuerySnapshot snapshot = await _firestore.collection('lessons')
        .orderBy('created_at', descending: true)
        .get();
    return snapshot.docs.map((doc) => {
      'id': doc.id,
      ...doc.data() as Map<String, dynamic>
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getRecentlyViewedLessons(String uid) async {
    final QuerySnapshot snapshot = await _firestore.collection('lesson_views')
        .where('uid', isEqualTo: uid)
        .orderBy('updated_at', descending: true)
        .limit(5)
        .get();
    
    List<String> lessonIds = snapshot.docs.map((doc) => 
      (doc.data() as Map<String, dynamic>)['lesson_id'] as String
    ).toList();

    if (lessonIds.isEmpty) return [];

    final QuerySnapshot lessonsSnapshot = await _firestore.collection('lessons')
        .where(FieldPath.documentId, whereIn: lessonIds)
        .get();

    return lessonsSnapshot.docs.map((doc) => {
      'id': doc.id,
      ...doc.data() as Map<String, dynamic>
    }).toList();
  }

  Future<List<Map<String, dynamic>>> searchLessons(String query) async {
    query = query.toLowerCase();
    final QuerySnapshot snapshot = await _firestore.collection('lessons')
        .orderBy('title')
        .get();
    
    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .where((lesson) => 
          lesson['title'].toString().toLowerCase().contains(query) ||
          lesson['description'].toString().toLowerCase().contains(query)
        )
        .toList();
  }

  Future<Map<String, dynamic>?> getLessonDetails(String lessonId) async {
    final DocumentSnapshot doc = await _firestore.collection('lessons').doc(lessonId).get();
    if (!doc.exists) return null;
    
    final data = doc.data() as Map<String, dynamic>;
    final List<String> videoIds = List<String>.from(data['videos'] ?? []);
    
    if (videoIds.isEmpty) {
      return {
        'id': doc.id,
        ...data,
        'videos': [],
      };
    }

    final QuerySnapshot videosSnapshot = await _firestore.collection('videos')
        .where(FieldPath.documentId, whereIn: videoIds)
        .get();

    final videos = videosSnapshot.docs.map((videoDoc) => {
      'id': videoDoc.id,
      'uid': videoDoc.get('uid'),
      'url': videoDoc.get('url'),
      'thumbnail_url': videoDoc.get('thumbnail_url'),
      'title': videoDoc.get('title'),
      'description': videoDoc.get('description'),
      'created_at': videoDoc.get('created_at'),
    }).toList();

    // Sort videos to match the order in the lesson's videos array
    videos.sort((a, b) => videoIds.indexOf(a['id']).compareTo(videoIds.indexOf(b['id'])));

    return {
      'id': doc.id,
      ...data,
      'videos': videos,
    };
  }

  Future<void> updateLessonView(String uid, String lessonId, int lastViewedIndex) async {
    final docRef = _firestore.collection('lesson_views')
        .doc('${uid}_${lessonId}');

    await docRef.set({
      'uid': uid,
      'lesson_id': lessonId,
      'last_viewed_index': lastViewedIndex,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, bool>> getVideoLikeStatuses(String uid, List<String> videoIds) async {
    final QuerySnapshot likesSnapshot = await _firestore.collection('likes')
        .where('uid', isEqualTo: uid)
        .where('video_id', whereIn: videoIds)
        .get();

    Map<String, bool> likeStatuses = {};
    for (String videoId in videoIds) {
      likeStatuses[videoId] = false;
    }

    for (var doc in likesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      likeStatuses[data['video_id']] = true;
    }

    return likeStatuses;
  }

  Future<bool> toggleVideoLike(String uid, String videoId) async {
    final likeRef = _firestore.collection('likes')
        .doc('${uid}_${videoId}');
    
    final likeDoc = await likeRef.get();
    
    if (likeDoc.exists) {
      await likeRef.delete();
      return false;
    } else {
      await likeRef.set({
        'uid': uid,
        'video_id': videoId,
        'created_at': FieldValue.serverTimestamp(),
      });
      return true;
    }
  }

  Future<Map<String, bool>> getLessonBookmarkStatuses(String uid, List<String> lessonIds) async {
    final QuerySnapshot bookmarksSnapshot = await _firestore.collection('bookmarks')
        .where('uid', isEqualTo: uid)
        .where('lesson_id', whereIn: lessonIds)
        .get();

    Map<String, bool> bookmarkStatuses = {};
    for (String lessonId in lessonIds) {
      bookmarkStatuses[lessonId] = false;
    }

    for (var doc in bookmarksSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      bookmarkStatuses[data['lesson_id']] = true;
    }

    return bookmarkStatuses;
  }

  Future<bool> toggleLessonBookmark(String uid, String lessonId) async {
    final bookmarkRef = _firestore.collection('bookmarks')
        .doc('${uid}_${lessonId}');
    
    final bookmarkDoc = await bookmarkRef.get();
    
    if (bookmarkDoc.exists) {
      await bookmarkRef.delete();
      return false;
    } else {
      await bookmarkRef.set({
        'uid': uid,
        'lesson_id': lessonId,
        'created_at': FieldValue.serverTimestamp(),
      });
      return true;
    }
  }
}
