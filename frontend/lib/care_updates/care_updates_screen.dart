import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CareUpdatesScreen extends StatefulWidget {
  const CareUpdatesScreen({super.key});

  @override
  State<CareUpdatesScreen> createState() => _CareUpdatesScreenState();
}

class _CareUpdatesScreenState extends State<CareUpdatesScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _updates = [];

  @override
  void initState() {
    super.initState();
    _loadUpdates();
  }

  Future<void> _loadUpdates() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ApiService.getCareUpdates();
      final raw = response['updates'] ?? response['results'] ?? [];

      if (!mounted) return;

      setState(() {
        _updates = raw is List ? raw : [];
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

  String _dateLabel(dynamic value) {
    if (value == null) return 'Date unavailable';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} at '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _typeLabel(dynamic value) {
    const labels = {
      'visit_summary': 'Visit summary',
      'activity': 'Activity completed',
      'observation': 'Observation',
      'medication': 'Medication note',
      'follow_up': 'Follow-up required',
      'incident': 'Incident',
    };

    return labels[value?.toString()] ?? 'Care update';
  }

  IconData _typeIcon(dynamic value) {
    switch (value?.toString()) {
      case 'visit_summary':
        return Icons.summarize_outlined;
      case 'activity':
        return Icons.task_alt;
      case 'observation':
        return Icons.visibility_outlined;
      case 'medication':
        return Icons.medication_outlined;
      case 'follow_up':
        return Icons.event_note;
      case 'incident':
        return Icons.warning_amber_rounded;
      default:
        return Icons.health_and_safety_outlined;
    }
  }

  Widget _updateCard(Map<String, dynamic> update) {
    final activities = update['activities'];
    final followUp = update['follow_up_required'] == true;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 14),
      color: MzaziCareColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(
          color: MzaziCareColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: MzaziCareColors.accent,
                  child: Icon(
                    _typeIcon(update['update_type']),
                    color: MzaziCareColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        update['title']?.toString() ?? 'Care update',
                        style: const TextStyle(
                          color: MzaziCareColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _typeLabel(update['update_type']),
                        style: const TextStyle(
                          color: MzaziCareColors.primaryDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 13),

            Text(
              update['body']?.toString() ?? '',
              style: const TextStyle(
                color: MzaziCareColors.text,
                height: 1.5,
              ),
            ),

            if (activities is List && activities.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Activities recorded',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: MzaziCareColors.text,
                ),
              ),
              const SizedBox(height: 8),
              ...activities.map(
                (activity) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 17,
                        color: MzaziCareColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          activity.toString(),
                          style: const TextStyle(
                            color: MzaziCareColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (followUp) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4DF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFF946200),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The caregiver has indicated that follow-up is required.',
                        style: TextStyle(
                          color: Color(0xFF765000),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Divider(
              height: 26,
              color: MzaziCareColors.border,
            ),

            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: MzaziCareColors.textMuted,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _dateLabel(update['created_at']),
                    style: const TextStyle(
                      color: MzaziCareColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  'Visit #${update['schedule_id'] ?? '—'}',
                  style: const TextStyle(
                    color: MzaziCareColors.primaryDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
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
              Icons.cloud_off,
              size: 45,
              color: MzaziCareColors.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load visit updates.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: MzaziCareColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MzaziCareColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUpdates,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.health_and_safety_outlined,
              size: 54,
              color: MzaziCareColors.primary,
            ),
            SizedBox(height: 14),
            Text(
              'No visit updates yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: MzaziCareColors.text,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Updates recorded by your caregiver after a visit '
              'will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: MzaziCareColors.textMuted,
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
        title: const Text('Visit Updates'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadUpdates,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh visit updates',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorState()
              : _updates.isEmpty
                  ? _emptyState()
                  : RefreshIndicator(
                      onRefresh: _loadUpdates,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Text(
                              'Updates about completed care activities, '
                              'observations and follow-up needs.',
                              style: TextStyle(
                                color: MzaziCareColors.textMuted,
                                height: 1.4,
                              ),
                            ),
                          ),
                          ..._updates.map((item) {
                            if (item is! Map) {
                              return const SizedBox.shrink();
                            }

                            return _updateCard(
                              Map<String, dynamic>.from(item),
                            );
                          }),
                        ],
                      ),
                    ),
    );
  }
}