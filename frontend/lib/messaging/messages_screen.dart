
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _loading = true;
  String? _error;

  String _role = '';
  List<Map<String, dynamic>> _conversations = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  List<Map<String, dynamic>> _extractList(dynamic response) {
    dynamic data = response;

    if (response is Map) {
      data = response['conversations'] ??
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

  Future<void> _loadConversations() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getConversations(),
        ApiService.getMyProfile(),
      ]);

      final response = _toMap(results[0]);
      final profile = _toMap(results[1]);

      if (!mounted) return;

      setState(() {
        _conversations = _extractList(response);
        _role = profile['role']?.toString().toLowerCase() ?? '';
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

  Future<void> _startConversationWithFamily() async {
    try {
      final response = await ApiService.getCareSchedules();

      final data = response['schedules'] ??
          response['results'] ??
          response['care_schedules'] ??
          response['data'] ??
          [];

      if (!mounted) return;

      final schedules = data is List
          ? data.where((item) {
              if (item is! Map) return false;

              final schedule = _toMap(item);
              final status =
                  schedule['status']?.toString().toLowerCase();

              return status != 'cancelled' &&
                  status != 'declined';
            }).map((item) => _toMap(item)).toList()
          : <Map<String, dynamic>>[];

      if (schedules.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You do not have any eligible family bookings yet.',
            ),
          ),
        );
        return;
      }

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(22),
          ),
        ),
        builder: (sheetContext) {
          final theme = Theme.of(sheetContext);
          final colors = theme.colorScheme;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Message a family',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Choose a family from one of your bookings.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: schedules.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: colors.outlineVariant,
                      ),
                      itemBuilder: (context, index) {
                        final schedule = schedules[index];

                        final scheduleId = int.tryParse(
                          schedule['id']?.toString() ?? '',
                        );

                        final familyName =
                            schedule['family_name']?.toString() ??
                                'Family';

                        final status =
                            schedule['status']?.toString() ?? 'Booking';

                        final location =
                            schedule['family_location']?.toString() ?? '';

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: colors.primaryContainer,
                            child: Icon(
                              Icons.person_outline,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                          title: Text(
                            familyName,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            location.isNotEmpty
                                ? '$status • $location'
                                : status,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chat_bubble_outline,
                            color: colors.primary,
                          ),
                          onTap: scheduleId == null
                              ? null
                              : () async {
                                  Navigator.pop(sheetContext);

                                  await _createBookingConversation(
                                    scheduleId,
                                    familyName,
                                  );
                                },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load your bookings: $e'),
        ),
      );
    }
  }

  Future<void> _createBookingConversation(
    int scheduleId,
    String familyName,
  ) async {
    try {
      final response =
          await ApiService.startConversationForBooking(scheduleId);

      final conversation = _toMap(response);

      // Some APIs wrap the created conversation in a data object.
      final conversationData =
          _toMap(conversation['conversation']).isNotEmpty
              ? _toMap(conversation['conversation'])
              : conversation;

      final conversationId = int.tryParse(
        conversationData['id']?.toString() ?? '',
      );

      if (conversationId == null) {
        throw Exception(
          'The server did not return a conversation ID.',
        );
      }

      await _loadConversations();

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            caregiverId: familyName,
          ),
        ),
      );

      if (mounted) {
        await _loadConversations();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start conversation: $e'),
        ),
      );
    }
  }

  String _participantName(Map<String, dynamic> conversation) {
    if (_role == 'caregiver') {
      return conversation['family_name']?.toString() ??
          conversation['family_profile_name']?.toString() ??
          conversation['family_profile_id']?.toString() ??
          'Family';
    }

    return conversation['caregiver_name']?.toString() ??
        conversation['caregiver_full_name']?.toString() ??
        conversation['caregiver_id']?.toString() ??
        'Caregiver';
  }

  Future<void> _openConversation(
    Map<String, dynamic> conversation,
  ) async {
    final id = int.tryParse(
      conversation['id']?.toString() ?? '',
    );

    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid conversation ID.'),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: id,
          caregiverId: _participantName(conversation),
        ),
      ),
    );

    if (mounted) {
      await _loadConversations();
    }
  }

  int _unreadCount(Map<String, dynamic> conversation) {
    return int.tryParse(
          conversation['unread_count']?.toString() ?? '0',
        ) ??
        0;
  }

  Widget _conversationCard(
    BuildContext context,
    Map<String, dynamic> conversation,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final participant = _participantName(conversation);
    final messageCount = conversation['messages_count'] ?? 0;

    final lastMessage =
        conversation['last_message']?.toString() ??
            'Open conversation to view messages';

    final unread = _unreadCount(conversation);

    return Card(
      margin: const EdgeInsets.only(bottom: 11),
      color: colors.surface,
      child: InkWell(
        onTap: () => _openConversation(conversation),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: colors.primaryContainer,
                child: Icon(
                  Icons.person_outline_rounded,
                  color: colors.onPrimaryContainer,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      participant,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$messageCount messages',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unread.toString(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 76,
              width: 76,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 37,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 17),
            Text(
              'No conversations yet',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Conversations linked to your care bookings will appear here. '
              'You can also start a conversation from a booking.',
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

  Widget _errorState() {
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
              color: colors.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Unable to load conversations.',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadConversations,
              child: const Text('Try again'),
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
        title: const Text('Messages'),
        actions: [
          if (_role == 'caregiver')
            IconButton(
              tooltip: 'Start a conversation with a family',
              onPressed: _loading ? null : _startConversationWithFamily,
              icon: const Icon(Icons.add_comment_outlined),
            ),
          IconButton(
            tooltip: 'Refresh messages',
            onPressed: _loading ? null : _loadConversations,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorState()
              : _conversations.isEmpty
                  ? _emptyState()
                  : RefreshIndicator(
                      onRefresh: _loadConversations,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          20,
                          18,
                          20,
                          30,
                        ),
                        children: [
                          Text(
                            'Your conversations',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _role == 'caregiver'
                                ? 'Stay connected with the families you care for.'
                                : 'Stay connected with your caregivers.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._conversations.map(
                            (conversation) => _conversationCard(
                              context,
                              conversation,
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
