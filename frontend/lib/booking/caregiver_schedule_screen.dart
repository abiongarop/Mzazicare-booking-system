
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../messaging/chat_screen.dart';

class CaregiverScheduleScreen extends StatefulWidget {
  final bool showAssignments;

  const CaregiverScheduleScreen({
    super.key,
    this.showAssignments = false,
  });

  @override
  State<CaregiverScheduleScreen> createState() =>
      _CaregiverScheduleScreenState();
}

class _CaregiverScheduleScreenState
    extends State<CaregiverScheduleScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _schedules = [];

  final Set<int> _processingIds = {};

  ColorScheme get _colors => Theme.of(context).colorScheme;
  TextTheme get _text => Theme.of(context).textTheme;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  Future<void> _loadSchedules() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ApiService.getCareSchedules();
      final responseMap = _toMap(response);

      final data = responseMap['results'] ??
          responseMap['schedules'] ??
          responseMap['care_schedules'] ??
          responseMap['data'];

      final schedules = data is List
          ? data
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;

      setState(() {
        _schedules = schedules;
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

  String _firstValue(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = 'Not provided',
  }) {
    for (final key in keys) {
      final value = data[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return fallback;
  }

  String _personName(
    dynamic value, {
    String fallback = 'Not provided',
  }) {
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }

    if (value is Map) {
      final map = _toMap(value);

      for (final key in [
        'full_name',
        'name',
        'display_name',
      ]) {
        final name = map[key];

        if (name != null && name.toString().trim().isNotEmpty) {
          return name.toString();
        }
      }
    }

    return fallback;
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return 'Date not available';
    }

    final parsed = DateTime.tryParse(value.toString());

    if (parsed == null) return value.toString();

    final local = parsed.toLocal();

    final date =
        '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';

    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$date at $hour:$minute $period';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase().replaceAll(' ', '_')) {
      case 'confirmed':
      case 'accepted':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
      case 'declined':
      case 'rejected':
        return _colors.error;
      case 'in_progress':
        return _colors.tertiary;
      default:
        return Colors.orange;
    }
  }

  String _servicesText(dynamic services) {
    if (services is! List) {
      return services?.toString() ?? '';
    }

    return services.map((item) {
      if (item is Map) {
        return (item['name'] ??
                item['service_name'] ??
                item['title'] ??
                item['id'] ??
                'Service')
            .toString();
      }

      return item.toString();
    }).join(', ');
  }

  Future<void> _decideBooking(
    Map<String, dynamic> schedule,
    String decision,
  ) async {
    final scheduleId = int.tryParse(
      schedule['id']?.toString() ?? '',
    );

    if (scheduleId == null) {
      _showMessage('Invalid booking ID.');
      return;
    }

    if (_processingIds.contains(scheduleId)) return;

    setState(() {
      _processingIds.add(scheduleId);
    });

    try {
      await ApiService.decideCareSchedule(
        scheduleId,
        decision: decision,
      );

      if (!mounted) return;

      _showMessage(
        decision == 'accept'
            ? 'Booking accepted successfully.'
            : 'Booking declined.',
      );

      await _loadSchedules();
    } catch (e) {
      if (!mounted) return;
      _showMessage('Could not update booking: $e');
    } finally {
      if (mounted) {
        setState(() {
          _processingIds.remove(scheduleId);
        });
      }
    }
  }

  Future<void> _messageFamily(
    Map<String, dynamic> schedule,
  ) async {
    final scheduleId = int.tryParse(
      schedule['id']?.toString() ?? '',
    );

    if (scheduleId == null) {
      _showMessage('Invalid booking ID.');
      return;
    }

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

      final familyName = _personName(
        schedule['family_name'] ?? schedule['family'],
        fallback: 'Family',
      );

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
        await _loadSchedules();
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Could not open family conversation: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value,
  ) {
    if (value.trim().isEmpty || value == 'Not provided') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 17,
            color: _colors.primary,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 105,
            child: Text(
              '$label:',
              style: _text.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: _colors.onSurface,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: _text.bodySmall?.copyWith(
                color: _colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingActions(
    Map<String, dynamic> schedule,
    String status,
  ) {
    final scheduleId = int.tryParse(
      schedule['id']?.toString() ?? '',
    );

    final processing = scheduleId != null &&
        _processingIds.contains(scheduleId);

    final normalizedStatus =
        status.toLowerCase().replaceAll(' ', '_');

    if (normalizedStatus == 'pending') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 25),
          Text(
            'Booking decision',
            style: _text.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: _colors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: processing
                      ? null
                      : () => _decideBooking(schedule, 'decline'),
                  icon: const Icon(Icons.close),
                  label: const Text('Decline'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _colors.error,
                    side: BorderSide(
                      color: _colors.error.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: processing
                      ? null
                      : () => _decideBooking(schedule, 'accept'),
                  icon: processing
                      ? const SizedBox(
                          height: 17,
                          width: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Accept'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: processing
                ? null
                : () => _messageFamily(schedule),
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Message Family'),
          ),
        ],
      );
    }

    if ([
      'confirmed',
      'accepted',
      'in_progress',
    ].contains(normalizedStatus)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 25),
          OutlinedButton.icon(
            onPressed: () => _messageFamily(schedule),
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Message Family'),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _scheduleCard(Map<String, dynamic> schedule) {
    final status = _firstValue(
      schedule,
      ['status'],
      fallback: 'pending',
    );

    final start = _firstValue(
      schedule,
      [
        'scheduled_start',
        'scheduledStart',
        'start_time',
        'start',
      ],
      fallback: '',
    );

    final end = _firstValue(
      schedule,
      [
        'scheduled_end',
        'scheduledEnd',
        'end_time',
        'end',
      ],
      fallback: '',
    );

    final family = _personName(
      schedule['family'] ??
          schedule['family_profile'] ??
          schedule['family_name'],
      fallback: _firstValue(
        schedule,
        ['family_name', 'client_name'],
        fallback: 'Family details unavailable',
      ),
    );

    final familyPhone = _firstValue(
      schedule,
      ['family_phone', 'contact_phone'],
      fallback: '',
    );

    final familyEmail = _firstValue(
      schedule,
      ['family_email'],
      fallback: '',
    );

    final familyLocation = _firstValue(
      schedule,
      ['family_location'],
      fallback: '',
    );

    final client = _personName(
      schedule['elderly_person'] ??
          schedule['care_recipient'],
      fallback: _firstValue(
        schedule,
        [
          'care_recipient_name',
          'client_name',
          'elderly_name',
        ],
        fallback: '',
      ),
    );

    final recipientAge = _firstValue(
      schedule,
      ['care_recipient_age'],
      fallback: '',
    );

    final recipientGender = _firstValue(
      schedule,
      ['care_recipient_gender'],
      fallback: '',
    );

    final careLevel = _firstValue(
      schedule,
      ['care_level'],
      fallback: '',
    );

    final services = _servicesText(
      schedule['services'] ?? schedule['required_services'],
    );

    final arrangement = _firstValue(
      schedule,
      ['arrangement', 'care_arrangement'],
      fallback: 'One time',
    );

    final notes = _firstValue(
      schedule,
      ['family_notes', 'notes', 'description'],
      fallback: '',
    );

    final statusColor = _statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 45,
                  width: 45,
                  decoration: BoxDecoration(
                    color: _colors.primaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    widget.showAssignments
                        ? Icons.assignment_ind_outlined
                        : Icons.calendar_month_outlined,
                    color: _colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        family,
                        style: _text.titleSmall?.copyWith(
                          color: _colors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _formatDate(start),
                        style: _text.bodySmall?.copyWith(
                          color: _colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.replaceAll('_', ' ').toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 25),
            _detailRow(Icons.person_outline, 'Family', family),
            _detailRow(Icons.phone_outlined, 'Phone', familyPhone),
            _detailRow(Icons.email_outlined, 'Email', familyEmail),
            _detailRow(Icons.location_on_outlined, 'Location', familyLocation),
            if (client.isNotEmpty)
              _detailRow(Icons.elderly_outlined, 'Care recipient', client),
            if (recipientAge.isNotEmpty)
              _detailRow(Icons.cake_outlined, 'Age', recipientAge),
            if (recipientGender.isNotEmpty)
              _detailRow(Icons.person_outline, 'Gender', recipientGender),
            if (careLevel.isNotEmpty)
              _detailRow(
                Icons.health_and_safety_outlined,
                'Care level',
                careLevel,
              ),
            if (end.isNotEmpty)
              _detailRow(
                Icons.schedule_outlined,
                'End time',
                _formatDate(end),
              ),
            _detailRow(
              Icons.repeat_rounded,
              'Arrangement',
              arrangement.replaceAll('_', ' '),
            ),
            _detailRow(
              Icons.medical_services_outlined,
              'Services',
              services,
            ),
            _detailRow(Icons.notes_outlined, 'Notes', notes),
            _bookingActions(schedule, status),
          ],
        ),
      ),
    );
  }

  Widget _emptyView() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: [
            Icon(
              widget.showAssignments
                  ? Icons.assignment_outlined
                  : Icons.event_available_outlined,
              size: 45,
              color: _colors.primary,
            ),
            const SizedBox(height: 13),
            Text(
              widget.showAssignments
                  ? 'No care assignments yet'
                  : 'No scheduled visits yet',
              style: _text.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: _colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.showAssignments
                  ? 'When a family booking is assigned to you, it will appear here.'
                  : 'Your upcoming care visits will appear here.',
              textAlign: TextAlign.center,
              style: _text.bodyMedium?.copyWith(
                color: _colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: _colors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Unable to load your care records.',
              style: _text.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: _colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An unexpected error occurred.',
              textAlign: TextAlign.center,
              style: _text.bodySmall?.copyWith(
                color: _colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadSchedules,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.showAssignments
        ? 'Care Assignments'
        : 'My Schedule';

    return Scaffold(
      backgroundColor: _colors.surface,
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadSchedules,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSchedules,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _colors.primary,
                    _colors.primaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    widget.showAssignments
                        ? Icons.assignment_ind_outlined
                        : Icons.calendar_month_outlined,
                    color: _colors.onPrimary,
                    size: 30,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: TextStyle(
                      color: _colors.onPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    widget.showAssignments
                        ? 'Review the care requests and clients assigned to you.'
                        : 'Keep track of your upcoming and previous care visits.',
                    style: TextStyle(
                      color: _colors.onPrimary.withValues(alpha: 0.9),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 23),
            Text(
              widget.showAssignments
                  ? 'Assigned care requests'
                  : 'Your care visits',
              style: _text.titleMedium?.copyWith(
                color: _colors.onSurface,
              ),
            ),
            const SizedBox(height: 13),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(35),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _errorView()
            else if (_schedules.isEmpty)
              _emptyView()
            else ...[
              Text(
                '${_schedules.length} record${_schedules.length == 1 ? '' : 's'}',
                style: _text.bodySmall?.copyWith(
                  color: _colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              ..._schedules.map(_scheduleCard),
            ],
          ],
        ),
      ),
    );
  }
}
