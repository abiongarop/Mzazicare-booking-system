
import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';

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

  Timer? _refreshTimer;

  bool _loading = true;
  bool _sending = false;
  bool _refreshing = false;

  String? _error;

  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic> _profile = {};

  @override
  void initState() {
    super.initState();

    _loadMessages();

    // Refresh messages and read receipts while the conversation is open.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshMessagesSilently(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  List<Map<String, dynamic>> _extractMessages(dynamic response) {
    dynamic data = response;

    if (response is Map) {
      data = response['messages'] ??
          response['results'] ??
          response['data'] ??
          [];
    }

    if (data is! List) return [];

    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _loadMessages() async {
    if (!mounted || _refreshing) return;

    _refreshing = true;

    if (_messages.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        ApiService.getMessages(widget.conversationId),
        ApiService.getMyProfile(),
      ]);

      final messages = _extractMessages(results[0]);
      final profile = _toMap(results[1]);

      if (!mounted) return;

      setState(() {
        _messages = messages;
        _profile = profile;
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
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _refreshMessagesSilently() async {
    if (!mounted || _refreshing || _loading) return;

    _refreshing = true;

    try {
      final response =
          await ApiService.getMessages(widget.conversationId);

      final messages = _extractMessages(response);

      if (!mounted) return;

      final oldLastId = _messages.isNotEmpty
          ? _messages.last['id']?.toString()
          : null;

      final newLastId = messages.isNotEmpty
          ? messages.last['id']?.toString()
          : null;

      final hasNewMessage =
          oldLastId != newLastId || messages.length != _messages.length;

      setState(() {
        _messages = messages;
      });

      if (hasNewMessage) {
        _scrollToBottom();
      }
    } catch (e) {
      // Silent refresh: keep the existing conversation visible.
      debugPrint('Message refresh failed: $e');
    } finally {
      _refreshing = false;
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
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String? _senderId(Map<String, dynamic> message) {
    final sender = message['sender_profile'] ??
        message['sender'];

    if (sender is Map) {
      return sender['id']?.toString() ??
          sender['profile_id']?.toString();
    }

    return sender?.toString();
  }

  bool _isMyMessage(Map<String, dynamic> message) {
    final senderId = _senderId(message);

    final myId = _profile['id']?.toString();

    if (senderId != null && myId != null) {
      return senderId == myId;
    }

    // Optional fallback if the API supplies the sender Firebase UID.
    final senderUid = message['sender_uid']?.toString();
    final myUid = _profile['firebase_uid']?.toString();

    return senderUid != null &&
        myUid != null &&
        senderUid == myUid;
  }

  String _senderName(
    Map<String, dynamic> message,
    bool mine,
  ) {
    if (mine) {
      return 'You';
    }

    final senderName = message['sender_name']?.toString().trim();

    if (senderName != null && senderName.isNotEmpty) {
      return senderName;
    }

    final sender = message['sender_profile'] ??
        message['sender'];

    if (sender is Map) {
      final name = sender['full_name']?.toString().trim();

      if (name != null && name.isNotEmpty) {
        return name;
      }
    }

    return 'Other participant';
  }

  bool _isRead(Map<String, dynamic> message) {
    final readAt = message['read_at'];

    return readAt != null && readAt.toString().isNotEmpty;
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

  Widget _readReceipt(
    Map<String, dynamic> message,
    bool mine,
  ) {
    if (!mine) {
      return const SizedBox.shrink();
    }

    final read = _isRead(message);

    return Padding(
      padding: const EdgeInsets.only(left: 5),
      child: Icon(
        read ? Icons.done_all_rounded : Icons.done_rounded,
        size: 16,
        color: read
            ? Colors.lightBlueAccent
            : Colors.white70,
      ),
    );
  }

  Widget _messageBubble(Map<String, dynamic> message) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final mine = _isMyMessage(message);
    final senderName = _senderName(message, mine);

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
              ? colors.primary
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(17),
            topRight: const Radius.circular(17),
            bottomLeft: Radius.circular(mine ? 17 : 4),
            bottomRight: Radius.circular(mine ? 4 : 17),
          ),
          border: mine
              ? null
              : Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              senderName,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: mine
                    ? colors.onPrimary.withValues(alpha: 0.9)
                    : colors.primary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              message['body']?.toString() ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: mine
                    ? colors.onPrimary
                    : colors.onSurface,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _formatTime(message['created_at']),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: mine
                        ? colors.onPrimary.withValues(alpha: 0.75)
                        : colors.onSurfaceVariant,
                  ),
                ),
                _readReceipt(message, mine),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyMessages() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: colors.primary,
            ),
            const SizedBox(height: 14),
            Text(
              'No messages yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Send a message to start the conversation.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: colors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Unable to load messages.',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An unexpected error occurred.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(color: colors.outlineVariant),
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
                  fillColor: colors.surfaceContainerHighest,
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
                    borderSide: BorderSide(
                      color: colors.primary,
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
                ),
                child: _sending
                    ? SizedBox(
                        height: 19,
                        width: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onPrimary,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conversation',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.caregiverId.isNotEmpty
                  ? widget.caregiverId
                  : 'MzaziCare messages',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
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
                                return _messageBubble(
                                  _messages[index],
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
