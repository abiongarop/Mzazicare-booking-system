import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'chat_screen.dart';

const _green = Color(0xFF176B57);
const _darkGreen = Color(0xFF174A3D);

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _conversations = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ApiService.getConversations();
      final data = response['conversations'] ?? response['results'] ?? [];

      if (!mounted) return;

      setState(() {
        _conversations = data is List ? data : [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openConversation(Map<String, dynamic> conversation) async {
    final id = int.tryParse(conversation['id'].toString());

    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid conversation ID.')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: id,
          caregiverId: conversation['caregiver_id']?.toString() ?? '',
        ),
      ),
    );

    if (mounted) _loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F6),
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.white,
        foregroundColor: _darkGreen,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadConversations,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh messages',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(
                  message: _error!,
                  onRetry: _loadConversations,
                )
              : _conversations.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 54,
                              color: _green,
                            ),
                            SizedBox(height: 14),
                            Text(
                              'No conversations yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _darkGreen,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'When you start a conversation with a caregiver, '
                              'it will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadConversations,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _conversations.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 9),
                        itemBuilder: (context, index) {
                          final item = _conversations[index];

                          if (item is! Map) {
                            return const SizedBox.shrink();
                          }

                          final conversation =
                              Map<String, dynamic>.from(item);
                          final caregiverId =
                              conversation['caregiver_id']?.toString() ??
                                  'Caregiver';

                          return Card(
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                              side: const BorderSide(
                                color: Color(0xFFE3EBE6),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE6F2EC),
                                child: Icon(
                                  Icons.person_outline,
                                  color: _green,
                                ),
                              ),
                              title: Text(
                                caregiverId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _darkGreen,
                                ),
                              ),
                              subtitle: Text(
                                '${conversation['messages_count'] ?? 0} messages',
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: _green,
                              ),
                              onTap: () => _openConversation(conversation),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 42),
            const SizedBox(height: 12),
            const Text(
              'Unable to load conversations.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}