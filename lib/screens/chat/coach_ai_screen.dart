import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/chat_provider.dart';

class CoachAIScreen extends StatefulWidget {
  const CoachAIScreen({super.key});

  @override
  State<CoachAIScreen> createState() => _CoachAIScreenState();
}

class _CoachAIScreenState extends State<CoachAIScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final chatProvider = context.read<ChatProvider>();
    _messageController.clear();

    try {
      await chatProvider.sendMessage(message);
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }

    // Scroll to bottom after sending message
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessage(Message message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: CircleAvatar(
                backgroundColor: Colors.grey[800],
                child: const Icon(Icons.auto_awesome, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.person, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach AI Chat'),
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) => Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: chatProvider.messages.length,
                itemBuilder: (context, index) => 
                    _buildMessage(chatProvider.messages[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 24.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: !chatProvider.isLoading,
                      decoration: InputDecoration(
                        hintText: 'Ask Coach AI...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
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
                      icon: chatProvider.isLoading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).brightness == Brightness.light
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.send,
                              color: Theme.of(context).brightness == Brightness.light
                                  ? Colors.white
                                  : Colors.black,
                            ),
                      onPressed: chatProvider.isLoading ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
