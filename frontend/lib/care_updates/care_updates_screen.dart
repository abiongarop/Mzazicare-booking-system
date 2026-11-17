
import 'package:flutter/material.dart';

import '../services/api_service.dart';

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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final activities = update['activities'];
    final followUp = update['follow_up_required'] == true;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  child: Icon(
                    _typeIcon(update['update_type']),
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        update['title']?.toString() ?? 'Care update',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _typeLabel(update['update_type']),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.primary,
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
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            if (activities is List && activities.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Activities recorded',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...activities.map(
                (activity) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 17,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          activity.toString(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
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
                  color: colors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: colors.onTertiaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The caregiver has indicated that follow-up is required.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onTertiaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Divider(
              height: 26,
              color: colors.outlineVariant,
            ),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _dateLabel(update['created_at']),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  'Visit #${update['schedule_id'] ?? '—'}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 45, color: colors.primary),
            const SizedBox(height: 12),
            Text(
              'Unable to load visit updates.',
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.health_and_safety_outlined,
              size: 54,
              color: colors.primary,
            ),
            const SizedBox(height: 14),
            Text(
              'No visit updates yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Updates recorded by your caregiver after a visit will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
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
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              'Updates about completed care activities, observations and follow-up needs.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
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
