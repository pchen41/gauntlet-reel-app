import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createUser({
    required String uid,
    required String name,
    required String email,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'email': email,
      });
    } catch (e) {
      throw 'Failed to create user profile: $e';
    }
  }

  Future<Map<String, dynamic>?> getUser(String uid) async {
    try {
      print('Fetching user data for uid: $uid');
      final querySnapshot = await _firestore
          .collection('users')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('No user found with uid: $uid');
        return null;
      }

      final userData = querySnapshot.docs.first.data();
      print('Got user data: $userData');
      return userData;
    } catch (e) {
      print('Error in getUser: $e');
      throw 'Failed to get user profile: $e';
    }
  }
} 