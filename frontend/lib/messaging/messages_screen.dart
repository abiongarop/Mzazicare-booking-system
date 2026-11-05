
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
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
  List<dynamic> _conversations = [];

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

      final data = response['conversations'] ??
          response['results'] ??
          response['data'] ??
          [];

      if (!mounted) return;

      setState(() {
        _conversations = data is List ? data : [];
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

  // Caregivers can select a family from one of their bookings.
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
              final bookingStatus =
                  schedule['status']?.toString().toLowerCase();

              return bookingStatus != 'cancelled' &&
                  bookingStatus != 'declined';
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
        backgroundColor: MzaziCareColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(22),
          ),
        ),
        builder: (sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Message a family',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: MzaziCareColors.text,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Choose a family from one of your bookings.',
                    style: TextStyle(
                      color: MzaziCareColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: schedules.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final schedule = schedules[index];

                        final scheduleId = int.tryParse(
                          schedule['id']?.toString() ?? '',
                        );

                        final familyName =
                            schedule['family_name']?.toString() ??
                                'Family';

                        final bookingStatus =
                            schedule['status']?.toString() ??
                                'Booking';

                        final location =
                            schedule['family_location']?.toString() ??
                                '';

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: MzaziCareColors.accent,
                            child: Icon(
                              Icons.person_outline,
                              color: MzaziCareColors.primaryDark,
                            ),
                          ),
                          title: Text(
                            familyName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            location.isNotEmpty
                                ? '$bookingStatus • $location'
                                : bookingStatus,
                          ),
                          trailing: const Icon(
                            Icons.chat_bubble_outline,
                            color: MzaziCareColors.primaryDark,
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

      final conversationId = int.tryParse(
        conversation['id']?.toString() ?? '',
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
          conversation['family_profile_id']?.toString() ??
          'Family';
    }

    return conversation['caregiver_name']?.toString() ??
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

  Widget _conversationCard(
    Map<String, dynamic> conversation,
  ) {
    final participant = _participantName(conversation);
    final messageCount = conversation['messages_count'] ?? 0;

    final lastMessage =
        conversation['last_message']?.toString() ??
            'Open conversation to view messages';

    final unread = conversation['unread_count'];

    return Card(
      margin: const EdgeInsets.only(bottom: 11),
      child: InkWell(
        onTap: () => _openConversation(conversation),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: MzaziCareColors.accent,
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: MzaziCareColors.primaryDark,
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: MzaziCareColors.text,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: MzaziCareColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$messageCount messages',
                      style: const TextStyle(
                        fontSize: 11,
                        color: MzaziCareColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread != null && unread.toString() != '0')
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(
                    color: MzaziCareColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unread.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: MzaziCareColors.primaryDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
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
                color: MzaziCareColors.accent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 37,
                color: MzaziCareColors.primaryDark,
              ),
            ),
            const SizedBox(height: 17),
            Text(
              'No conversations yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Conversations linked to your care bookings will appear here. You can also start a conversation from a booking.',
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

  Widget _errorState() {
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
              'Unable to load conversations.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: MzaziCareColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MzaziCareColors.textMuted,
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
    return Scaffold(
      backgroundColor: MzaziCareColors.background,
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          if (_role == 'caregiver')
            IconButton(
              tooltip: 'Start a conversation with a family',
              onPressed:
                  _loading ? null : _startConversationWithFamily,
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
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          20,
                          18,
                          20,
                          30,
                        ),
                        children: [
                          MzaziSectionHeader(
                            title: 'Your conversations',
                            subtitle: _role == 'caregiver'
                                ? 'Stay connected with the families you care for.'
                                : 'Stay connected with your caregivers.',
                          ),
                          const SizedBox(height: 16),
                          ..._conversations.map((item) {
                            if (item is! Map) {
                              return const SizedBox.shrink();
                            }

                            return _conversationCard(_toMap(item));
                          }),
                        ],
                      ),
                    ),
    );
  }
}
