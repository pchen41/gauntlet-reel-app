import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/goal_model.dart';
import '../providers/chat_provider.dart';

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

  Future<String> addGoalFromProposal(ProposedGoal proposedGoal) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    final docRef = await _firestore.collection('goals').add({
      'uid': uid,
      'name': proposedGoal.name,
      'updated_at': FieldValue.serverTimestamp(),
      'tasks': proposedGoal.tasks.map((task) => {
        'name': task.name,
        'completed': false, // Start as incomplete
        'comments': task.comments,
        'type': task.type,
        'value': task.value,
      }).toList(),
    });

    return docRef.id;
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

  Future<Map<String, dynamic>> getGoal(String goalId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    final doc = await _firestore.collection('goals').doc(goalId).get();
    if (!doc.exists) throw Exception('Goal not found');

    final data = doc.data();
    if (data == null) throw Exception('Goal data is null');

    return {...data, 'id': doc.id};
  }
}
