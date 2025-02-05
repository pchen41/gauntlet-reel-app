import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;
import '../models/video_model.dart';
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';

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
    //final String thumbnailFileName = 'thumbnails/$userId/$videoId.jpg';

    try {
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

      // For now, we'll use a placeholder thumbnail URL
      // TODO: Generate actual thumbnail from video
      const thumbnailUrl = 'https://placeholder.com/thumbnail.jpg';

      // Create video document in Firestore
      final videoModel = VideoModel(
        uid: videoId,
        title: title,
        description: description,
        url: videoUrl,
        thumbnailUrl: thumbnailUrl,
        userId: userId,
      );

      await _firestore
          .collection('videos')
          .doc(videoId)
          .set(videoModel.toMap());

      return videoModel;
    } catch (e) {
      throw 'Failed to upload video: $e';
    }
  }

  Future<List<VideoModel>> getVideos() async {
    try {
      final querySnapshot = await _firestore
          .collection('videos')
          .orderBy('uid', descending: true)  // Latest first
          .get();

      return querySnapshot.docs.map((doc) => VideoModel.fromMap(doc.data())).toList();
    } catch (e) {
      throw 'Failed to fetch videos: $e';
    }
  }
} 