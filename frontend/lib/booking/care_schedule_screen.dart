import 'package:flutter/material.dart';

import '../recommendations/recommendations_screen.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CareScheduleScreen extends StatefulWidget {
  const CareScheduleScreen({super.key});

  @override
  State<CareScheduleScreen> createState() => _CareScheduleScreenState();
}

class _CareScheduleScreenState extends State<CareScheduleScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _schedules = [];

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

      final dynamic data = response['results'] ??
          response['schedules'] ??
          response['care_schedules'] ??
          response['data'];

      List<Map<String, dynamic>> schedules = [];

      if (data is List) {
        schedules = data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
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
        builder: (_) => const RecommendationsScreen(
  refreshOnOpen: true,
),
      ),
    );

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
      ]
          .where((value) =>
              value != null && value.toString().trim().isNotEmpty)
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
              return (item['name'] ??
                      item['service_name'] ??
                      item['id'])
                  .toString();
            }

            return item.toString();
          }).join(', ')
        : '';

    final notes = schedule['family_notes'];

    return Card(
      margin: const EdgeInsets.only(bottom: 13),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: MzaziCareColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.calendar_month_outlined,
                    color: MzaziCareColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caregiverName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatDateTime(start),
                        style: const TextStyle(
                          color: MzaziCareColors.text,
                        ),
                      ),
                      if (end.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Ends: ${_formatDateTime(end)}',
                          style: const TextStyle(
                            color: MzaziCareColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(status)
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.replaceAll('_', ' ').toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _statusColor(status),
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 26),
            _detailRow(
              Icons.repeat_rounded,
              'Arrangement',
              arrangement.replaceAll('_', ' '),
            ),
            if (serviceText.isNotEmpty)
              _detailRow(
                Icons.medical_services_outlined,
                'Services',
                serviceText,
              ),
            if (notes != null && notes.toString().trim().isNotEmpty)
              _detailRow(
                Icons.notes_rounded,
                'Notes',
                notes.toString(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: MzaziCareColors.primaryDark,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 105,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: MzaziCareColors.text,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: MzaziCareColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(23),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            MzaziCareColors.primaryDark,
            MzaziCareColors.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.health_and_safety_outlined,
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(height: 13),
          const Text(
            'Coordinate care with confidence',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Review your scheduled visits or find a caregiver who matches your family’s needs.',
            style: TextStyle(
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _findCaregiver,
              icon: const Icon(Icons.search),
              label: const Text('Find a caregiver'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: MzaziCareColors.primaryDark,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBookings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const Icon(
              Icons.event_available_outlined,
              size: 44,
              color: MzaziCareColors.primaryDark,
            ),
            const SizedBox(height: 13),
            Text(
              'No bookings yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 7),
            const Text(
              'Find a caregiver to arrange your first care visit.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: MzaziCareColors.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: _findCaregiver,
              child: const Text('Find a caregiver'),
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
            const Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: MzaziCareColors.primaryDark,
            ),
            const SizedBox(height: 12),
            const Text(
              'We could not load your bookings.',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: MzaziCareColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MzaziCareColors.textMuted,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MzaziCareColors.background,
      appBar: AppBar(
        title: const Text('Your care schedule'),
        actions: [
          IconButton(
            tooltip: 'Refresh schedules',
            onPressed: _isLoading ? null : _loadSchedules,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSchedules,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _headerCard(),
            const SizedBox(height: 26),
            const MzaziSectionHeader(
              title: 'Your bookings',
              subtitle: 'View the status and details of your care visits.',
            ),
            const SizedBox(height: 14),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              _errorView()
            else if (_schedules.isEmpty)
              _emptyBookings()
            else ...[
              Text(
                '${_schedules.length} booking${_schedules.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: MzaziCareColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              ..._schedules.map(_buildScheduleCard),
            ],
          ],
        ),
      ),
    );
  }
}