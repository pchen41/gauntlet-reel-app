import 'package:flutter/material.dart';
import '../services/comment_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../models/comment_model.dart';

class CommentSheet extends StatefulWidget {
  final String videoId;

  const CommentSheet({
    super.key,
    required this.videoId,
  });

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final _commentController = TextEditingController();
  final _commentService = CommentService();
  final _authService = AuthService();
  final _userService = UserService();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Comments',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<CommentModel>>(
              stream: _commentService.getComments(widget.videoId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final comments = snapshot.data!;
                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return FutureBuilder<Map<String, dynamic>?>(
                      future: _userService.getUser(comment.uid),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) {
                          return const ListTile(
                            title: Text(''),
                          );
                        }
                        final userName = userSnapshot.data?['name'] ?? 'Unknown';
                        return ListTile(
                          title: Text(userName),
                          subtitle: Text(comment.text),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 24.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) async {
                      if (_commentController.text.isNotEmpty) {
                        await _commentService.addComment(
                          _authService.currentUser!.uid,
                          widget.videoId,
                          _commentController.text,
                        );
                        _commentController.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.send,
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.white
                          : Colors.black,
                    ),
                    onPressed: () async {
                      if (_commentController.text.isNotEmpty) {
                        await _commentService.addComment(
                          _authService.currentUser!.uid,
                          widget.videoId,
                          _commentController.text,
                        );
                        _commentController.clear();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
} 