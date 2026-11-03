
import 'package:flutter/material.dart';

import '../services/api_service.dart';

const _green = Color(0xFF176B57);
const _darkGreen = Color(0xFF174A3D);

class ChatScreen extends StatefulWidget {
  final int conversationId;
  final String caregiverId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.caregiverId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController =
      TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<dynamic> _messages = [];
  Map<String, dynamic> _profile = {};

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final results = await Future.wait([
        ApiService.getMessages(widget.conversationId),
        ApiService.getMyProfile(),
      ]);

      final messageResponse =
          results[0] as Map<String, dynamic>;
      final profileResponse =
          results[1] as Map<String, dynamic>;

      final rawMessages = messageResponse['messages'] ??
          messageResponse['results'] ??
          [];

      if (!mounted) return;

      setState(() {
        _messages = rawMessages is List ? rawMessages : [];
        _profile = profileResponse;
        _loading = false;
        _error = null;
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final body = _messageController.text.trim();

    if (body.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      await ApiService.sendMessage(
        widget.conversationId,
        body,
      );

      _messageController.clear();
      await _loadMessages();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send message: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _isMyMessage(Map<String, dynamic> message) {
    final sender = message['sender_profile'];
    final senderId = sender is Map
        ? sender['id']?.toString()
        : sender?.toString();

    final myId = _profile['id']?.toString();

    return senderId != null &&
        myId != null &&
        senderId == myId;
  }

  String _formatTime(dynamic value) {
    if (value == null) return '';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return '';

    final local = date.toLocal();
    final hour =
        local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute =
        local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _darkGreen,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Caregiver conversation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.caregiverId,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadMessages,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _loadMessages,
                                child: const Text('Try again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _messages.isEmpty
                        ? const Center(
                            child: Text(
                              'No messages yet. Send a message to start the conversation.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black54,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final item = _messages[index];

                              if (item is! Map) {
                                return const SizedBox.shrink();
                              }

                              final message =
                                  Map<String, dynamic>.from(item);
                              final mine = _isMyMessage(message);

                              return Align(
                                alignment: mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context)
                                                .size
                                                .width *
                                            0.78,
                                  ),
                                  margin: const EdgeInsets.only(
                                    bottom: 12,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: mine
                                        ? _green
                                        : Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(16),
                                    border: mine
                                        ? null
                                        : Border.all(
                                            color: const Color(
                                              0xFFE3EBE6,
                                            ),
                                          ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (!mine)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(
                                            bottom: 4,
                                          ),
                                          child: Text(
                                            message['sender_name']
                                                    ?.toString() ??
                                                'Caregiver',
                                            style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.bold,
                                              fontSize: 11,
                                              color: _green,
                                            ),
                                          ),
                                        ),
                                      Text(
                                        message['body']?.toString() ??
                                            '',
                                        style: TextStyle(
                                          color: mine
                                              ? Colors.white
                                              : Colors.black87,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Align(
                                        alignment:
                                            Alignment.bottomRight,
                                        child: Text(
                                          _formatTime(
                                            message['created_at'],
                                          ),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: mine
                                                ? Colors.white70
                                                : Colors.black45,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 5000,
                      decoration: InputDecoration(
                        hintText: 'Write a message...',
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFFF5F8F6),
                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: _green,
                    child: IconButton(
                      onPressed:
                          _sending ? null : _sendMessage,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 19,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
