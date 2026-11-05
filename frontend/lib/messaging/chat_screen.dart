
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

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

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  List<dynamic> _extractMessages(dynamic response) {
    if (response is List) return response;

    if (response is Map) {
      final data = response['messages'] ??
          response['results'] ??
          response['data'] ??
          [];

      if (data is List) return data;
    }

    return [];
  }

  Future<void> _loadMessages() async {
    try {
      final results = await Future.wait([
        ApiService.getMessages(widget.conversationId),
        ApiService.getMyProfile(),
      ]);

      final rawMessages = _extractMessages(results[0]);
      final profileResponse = _toMap(results[1]);

      if (!mounted) return;

      setState(() {
        _messages = rawMessages;
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
        SnackBar(
          content: Text('Could not send message: $e'),
        ),
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

    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  Widget _messageBubble(Map<String, dynamic> message) {
    final mine = _isMyMessage(message);

    final senderName =
        message['sender_name']?.toString().trim();

    return Align(
      alignment: mine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: mine
              ? MzaziCareColors.primary
              : MzaziCareColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(17),
            topRight: const Radius.circular(17),
            bottomLeft: Radius.circular(mine ? 17 : 4),
            bottomRight: Radius.circular(mine ? 4 : 17),
          ),
          border: mine
              ? null
              : Border.all(color: MzaziCareColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  senderName != null && senderName.isNotEmpty
                      ? senderName
                      : 'Other participant',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: MzaziCareColors.primaryDark,
                  ),
                ),
              ),
            Text(
              message['body']?.toString() ?? '',
              style: TextStyle(
                color: mine ? Colors.white : MzaziCareColors.text,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                _formatTime(message['created_at']),
                style: TextStyle(
                  fontSize: 10,
                  color: mine
                      ? Colors.white70
                      : MzaziCareColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyMessages() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: MzaziCareColors.primaryDark,
            ),
            SizedBox(height: 14),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: MzaziCareColors.text,
              ),
            ),
            SizedBox(height: 7),
            Text(
              'Send a message to start the conversation.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: MzaziCareColors.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: MzaziCareColors.primaryDark,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load messages.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: MzaziCareColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An unexpected error occurred.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MzaziCareColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadMessages,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageInput() {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: MzaziCareColors.surface,
          border: Border(
            top: BorderSide(color: MzaziCareColors.border),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                maxLength: 5000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Write a message...',
                  counterText: '',
                  filled: true,
                  fillColor: MzaziCareColors.surfaceSoft,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 17,
                    vertical: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: MzaziCareColors.primary,
                    ),
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 9),
            SizedBox(
              height: 48,
              width: 48,
              child: FilledButton(
                onPressed: _sending ? null : _sendMessage,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                  backgroundColor: MzaziCareColors.primary,
                ),
                child: _sending
                    ? const SizedBox(
                        height: 19,
                        width: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MzaziCareColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Conversation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.caregiverId.isNotEmpty
                  ? widget.caregiverId
                  : 'MzaziCare messages',
              style: const TextStyle(
                fontSize: 12,
                color: MzaziCareColors.textMuted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh messages',
            onPressed: _loading ? null : _loadMessages,
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
                    ? _errorView()
                    : _messages.isEmpty
                        ? _emptyMessages()
                        : RefreshIndicator(
                            onRefresh: _loadMessages,
                            child: ListView.builder(
                              controller: _scrollController,
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final item = _messages[index];

                                if (item is! Map) {
                                  return const SizedBox.shrink();
                                }

                                return _messageBubble(
                                  Map<String, dynamic>.from(item),
                                );
                              },
                            ),
                          ),
          ),
          _messageInput(),
        ],
      ),
    );
  }
}
