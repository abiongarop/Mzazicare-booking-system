
import 'package:flutter/material.dart';

import '../recommendations/recommendations_screen.dart';
import '../services/api_service.dart';

class CareScheduleScreen extends StatefulWidget {
  const CareScheduleScreen({super.key});

  @override
  State<CareScheduleScreen> createState() => _CareScheduleScreenState();
}

class _CareScheduleScreenState extends State<CareScheduleScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _schedules = [];

  static const Color _darkGreen = Color(0xFF174D38);
  static const Color _lightGreen = Color(0xFFE5F2E9);

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  
Future<void> _loadSchedules() async {
  if (mounted) {
    setState(() {
      _isLoading = true;
      _error = null;
    });
  }

  try {
    final response = await ApiService.getCareSchedules();

    // The API service returns a JSON map.
    final dynamic data =
        response['results'] ??
        response['schedules'] ??
        response['care_schedules'] ??
        response['data'];

    List<Map<String, dynamic>> schedules = [];

    if (data is List) {
      schedules = data
          .whereType<Map<String, dynamic>>()
          .toList();
    }

    if (!mounted) return;

    setState(() {
      _schedules = schedules;
      _isLoading = false;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _error = e.toString();
      _isLoading = false;
    });
  }
}


  Future<void> _findCaregiver() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RecommendationsScreen(),
      ),
    );

    // Refresh after the user returns from recommendations/booking.
    if (mounted) {
      await _loadSchedules();
    }
  }

  String _firstValue(
    Map<String, dynamic> schedule,
    List<String> keys, {
    String fallback = 'Not provided',
  }) {
    for (final key in keys) {
      final value = schedule[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  String _formatDateTime(dynamic value) {
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
    final time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';

    return '$date at $time';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green.shade700;
      case 'completed':
        return Colors.blue.shade700;
      case 'cancelled':
        return Colors.red.shade700;
      case 'in_progress':
      case 'in progress':
        return Colors.orange.shade800;
      case 'pending':
      default:
        return Colors.orange.shade800;
    }
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    final status = _firstValue(
      schedule,
      ['status'],
      fallback: 'pending',
    );

    final start = _firstValue(
      schedule,
      ['scheduled_start', 'scheduledStart', 'start_time', 'start'],
      fallback: '',
    );

    final end = _firstValue(
      schedule,
      ['scheduled_end', 'scheduledEnd', 'end_time', 'end'],
      fallback: '',
    );

    final caregiver = schedule['caregiver'];
    String caregiverName = 'Caregiver not assigned';

    if (caregiver is Map) {
      caregiverName = [
        caregiver['full_name'],
        caregiver['name'],
        caregiver['display_name'],
      ].where((value) => value != null && value.toString().isNotEmpty)
          .join(' ');

      if (caregiverName.trim().isEmpty) {
        caregiverName = 'Caregiver not assigned';
      }
    } else if (caregiver is String && caregiver.isNotEmpty) {
      caregiverName = caregiver;
    } else if (schedule['caregiver_name'] != null) {
      caregiverName = schedule['caregiver_name'].toString();
    }

    final arrangement = _firstValue(
      schedule,
      ['arrangement', 'care_arrangement'],
      fallback: 'one_time',
    );

    final services = schedule['services'];
    final serviceText = services is List
        ? services.map((item) {
            if (item is Map) {
              return (item['name'] ?? item['service_name'] ?? item['id'])
                  .toString();
            }
            return item.toString();
          }).join(', ')
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE3EBE6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: _lightGreen,
                  child: Icon(
                    Icons.calendar_month_outlined,
                    color: _darkGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caregiverName,
                        style: const TextStyle(
                          color: _darkGreen,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _formatDateTime(start),
                        style: const TextStyle(
                          color: Colors.black87,
                        ),
                      ),
                      if (end.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Ends: ${_formatDateTime(end)}',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Arrangement: ${arrangement.replaceAll('_', ' ')}',
              style: const TextStyle(color: Colors.black87),
            ),
            if (serviceText.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                'Services: $serviceText',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
            if (schedule['family_notes'] != null &&
                schedule['family_notes'].toString().trim().isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                'Notes: ${schedule['family_notes']}',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        title: const Text('Your care schedule'),
        backgroundColor: _darkGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh schedules',
            onPressed: _loadSchedules,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSchedules,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _darkGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.health_and_safety_outlined,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Coordinate care with confidence',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Review your scheduled visits or find a caregiver '
                    'who matches your family’s needs.',
                    style: TextStyle(
                      color: Color(0xFFE0F0E7),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _findCaregiver,
                      icon: const Icon(Icons.search),
                      label: const Text('Find a caregiver'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _lightGreen,
                        foregroundColor: _darkGreen,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your bookings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _darkGreen,
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE3EBE6)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 38,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'We could not load your bookings.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _error!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
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
              )
            else if (_schedules.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE3EBE6)),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      size: 42,
                      color: _darkGreen,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No bookings yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Find a caregiver to arrange your first care visit.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Text(
                '${_schedules.length} booking${_schedules.length == 1 ? '' : 's'}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 10),
              ..._schedules.map(_buildScheduleCard),
            ],
          ],
        ),
      ),
    );
  }
}
