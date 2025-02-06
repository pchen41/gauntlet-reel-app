import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/goal_model.dart';

class GoalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<Map<String, dynamic>>> getGoals() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    final snapshot = await _firestore
        .collection('goals')
        .where('uid', isEqualTo: uid)
        .orderBy('updated_at', descending: true)
        .get();

    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  Future<void> addGoal(String name) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    await _firestore.collection('goals').add({
      'uid': uid,
      'name': name,
      'updated_at': FieldValue.serverTimestamp(),
      'tasks': [],
    });
  }

  Future<void> addTask(String goalId, GoalTask task) async {
    final goal = await _firestore.collection('goals').doc(goalId).get();
    final tasks = List<Map<String, dynamic>>.from(goal.data()?['tasks'] ?? []);
    tasks.add(task.toMap());
    
    await _firestore.collection('goals').doc(goalId).update({
      'tasks': tasks,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTaskStatus(String goalId, int taskIndex, bool completed) async {
    final goal = await _firestore.collection('goals').doc(goalId).get();
    if (!goal.exists) throw Exception('Goal not found');

    List<dynamic> tasks = List.from(goal.data()?['tasks'] ?? []);
    if (taskIndex >= tasks.length) throw Exception('Task index out of bounds');

    tasks[taskIndex] = {
      ...tasks[taskIndex],
      'completed': completed,
    };

    await _firestore.collection('goals').doc(goalId).update({
      'tasks': tasks,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteGoal(String goalId) async {
    await _firestore.collection('goals').doc(goalId).delete();
  }

  Future<void> updateTasks(String goalId, List<dynamic> tasks) async {
    await _firestore.collection('goals').doc(goalId).update({
      'tasks': tasks,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}
