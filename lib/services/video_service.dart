import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore, FieldValue, FieldPath, Timestamp;
import 'package:path/path.dart' as path;
import '../models/video_model.dart';
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

class VideoService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final int _maxSizeBytes = 25 * 1024 * 1024; // 25MB in bytes

  Future<VideoModel> uploadVideo({
    required File videoFile,
    required String userId,
    required String title,
    required String description,
  }) async {
    // Check file size
    final fileSize = await videoFile.length();
    if (fileSize > _maxSizeBytes) {
      throw 'Video size must be less than 25MB';
    }

    final String videoId = const Uuid().v4();
    final String videoExtension = path.extension(videoFile.path);
    final String videoFileName = 'videos/$userId/$videoId$videoExtension';
    final String thumbnailFileName = 'thumbnails/$userId/$videoId.jpg';

    try {
      // Generate thumbnail
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        thumbnailPath: '${tempDir.path}/thumbnail.jpg',
        imageFormat: ImageFormat.JPEG,
        maxHeight: 600,
        quality: 85,
      );

      if (thumbnailPath == null) {
        throw 'Failed to generate thumbnail';
      }

      // Upload thumbnail
      final thumbnailRef = _storage.ref().child(thumbnailFileName);
      await thumbnailRef.putFile(File(thumbnailPath));
      final thumbnailUrl = await thumbnailRef.getDownloadURL();

      // Compress video before upload (you'll need video_compress package)
      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
      );

      if (mediaInfo?.file == null) {
        throw 'Failed to compress video';
      }

      final compressedFile = mediaInfo!.file!;
      
      // Upload compressed video
      final videoRef = _storage.ref().child(videoFileName);
      final uploadTask = videoRef.putFile(
        compressedFile,
        SettableMetadata(
          contentType: 'video/mp4',
          customMetadata: {
            'width': '${mediaInfo.width}',
            'height': '${mediaInfo.height}',
          },
        ),
      );

      final videoSnapshot = await uploadTask;
      final videoUrl = await videoSnapshot.ref.getDownloadURL();

      // Create video document in Firestore
      final docRef = await _firestore.collection('videos').add({
        'uid': userId,
        'title': title,
        'description': description,
        'url': videoUrl,
        'thumbnail_url': thumbnailUrl,
        'created_at': Timestamp.now(),
      });

      final videoModel = VideoModel(
        uid: userId,
        id: docRef.id,
        title: title,
        description: description,
        url: videoUrl,
        thumbnailUrl: thumbnailUrl,
        createdAt: Timestamp.now(),
      );

      return videoModel;
    } catch (e) {
      throw 'Failed to upload video: $e';
    }
  }

  Future<List<VideoModel>> getVideos() async {
    try {
      final querySnapshot = await _firestore
          .collection('videos')
          .orderBy('created_at', descending: true)  // Changed from 'uid' to 'created_at'
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return VideoModel.fromMap(data, doc.id);
      }).toList();
    } catch (e) {
      throw 'Failed to fetch videos: $e';
    }
  }

  Future<List<Map<String, dynamic>>> getUserVideos(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('videos')
          .where('uid', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          'id': doc.id,
        };
      }).toList();
    } catch (e) {
      print('Error getting user videos: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getLikedVideos(String userId) async {
    try {
      // First get all likes by the user
      final likesSnapshot = await _firestore
          .collection('likes')
          .where('uid', isEqualTo: userId)
          .get();

      if (likesSnapshot.docs.isEmpty) {
        return [];
      }

      // Get all video IDs that the user has liked
      final videoIds = likesSnapshot.docs.map((doc) => doc.data()['video_id'] as String).toList();

      // Fetch all liked videos
      final videosSnapshot = await _firestore
          .collection('videos')
          .where(FieldPath.documentId, whereIn: videoIds)
          .get();

      return videosSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          'id': doc.id,
        };
      }).toList();
    } catch (e) {
      print('Error getting liked videos: $e');
      rethrow;
    }
  }
} 