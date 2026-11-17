
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CareJournalScreen extends StatefulWidget {
  const CareJournalScreen({super.key});

  @override
  State<CareJournalScreen> createState() => _CareJournalScreenState();
}

class _CareJournalScreenState extends State<CareJournalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _activitiesController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _followUpRequired = false;

  String _updateType = 'visit_summary';
  String? _error;

  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _updates = [];
  int? _selectedScheduleId;

  final Map<String, String> _updateTypes = {
    'visit_summary': 'Visit summary',
    'daily_observation': 'Daily observation',
    'health_observation': 'Health observation',
    'incident': 'Incident report',
    'follow_up': 'Follow-up',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _activitiesController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  List<Map<String, dynamic>> _extractList(
    Map<String, dynamic> response,
    List<String> keys,
  ) {
    dynamic data;

    for (final key in keys) {
      if (response[key] is List) {
        data = response[key];
        break;
      }
    }

    if (data is! List) return [];

    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getCareSchedules(),
        ApiService.getCareUpdates(),
      ]);

      final scheduleResponse = _toMap(results[0]);
      final updateResponse = _toMap(results[1]);

      final schedules = _extractList(
        scheduleResponse,
        ['results', 'schedules', 'care_schedules', 'data'],
      );

      final updates = _extractList(
        updateResponse,
        ['updates', 'results', 'data'],
      );

      if (!mounted) return;

      setState(() {
        _schedules = schedules;
        _updates = updates;
        _loading = false;

        if (_selectedScheduleId == null && schedules.isNotEmpty) {
          _selectedScheduleId = _scheduleId(schedules.first);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int? _scheduleId(Map<String, dynamic> schedule) {
    final raw = schedule['id'] ??
        schedule['schedule_id'] ??
        schedule['care_schedule_id'];

    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  String _scheduleLabel(Map<String, dynamic> schedule) {
    final id = _scheduleId(schedule);
    final start = schedule['scheduled_start'] ??
        schedule['start_time'] ??
        schedule['scheduledStart'];

    final client = schedule['client_name'] ??
        schedule['elderly_name'] ??
        schedule['care_recipient_name'];

    final family = schedule['family_name'] ??
        schedule['family'] ??
        schedule['client'];

    String familyName = 'Family';

    if (family is Map) {
      familyName = (family['full_name'] ??
              family['name'] ??
              family['display_name'] ??
              'Family')
          .toString();
    } else if (family is String && family.trim().isNotEmpty) {
      familyName = family;
    }

    final person = client?.toString().trim();
    final date = start == null ? 'Date unavailable' : _formatDate(start);

    return 'Booking #${id ?? '—'} • '
        '${person?.isNotEmpty == true ? person : familyName} • $date';
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Date unavailable';

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

    return '$date, $hour:$minute $period';
  }

  List<String> _activities() {
    return _activitiesController.text
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> _saveJournalEntry() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedScheduleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a care booking first.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await ApiService.createCareUpdate(
        scheduleId: _selectedScheduleId!,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        updateType: _updateType,
        activities: _activities(),
        followUpRequired: _followUpRequired,
      );

      if (!mounted) return;

      _titleController.clear();
      _bodyController.clear();
      _activitiesController.clear();

      setState(() {
        _followUpRequired = false;
        _updateType = 'visit_summary';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Care journal entry saved successfully.'),
        ),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save journal entry: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _journalForm() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final validSchedules = _schedules
        .where((schedule) => _scheduleId(schedule) != null)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New journal entry',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Record what happened during a care visit. These notes help families stay informed.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<int>(
                initialValue: validSchedules.any(
                  (item) => _scheduleId(item) == _selectedScheduleId,
                )
                    ? _selectedScheduleId
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Select care booking',
                  prefixIcon: Icon(Icons.calendar_month_outlined),
                  border: OutlineInputBorder(),
                ),
                items: validSchedules.map((schedule) {
                  final id = _scheduleId(schedule)!;
                  return DropdownMenuItem<int>(
                    value: id,
                    child: Text(
                      _scheduleLabel(schedule),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedScheduleId = value);
                },
                validator: (value) =>
                    value == null ? 'Select a care booking' : null,
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                initialValue: _updateType,
                decoration: const InputDecoration(
                  labelText: 'Entry type',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                items: _updateTypes.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _updateType = value);
                  }
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _titleController,
                maxLength: 150,
                decoration: const InputDecoration(
                  labelText: 'Journal title',
                  hintText: 'e.g. Afternoon care visit',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bodyController,
                minLines: 4,
                maxLines: 7,
                maxLength: 5000,
                decoration: const InputDecoration(
                  labelText: 'Visit summary / observations',
                  hintText:
                      'Describe the care provided and any important observations...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a visit summary';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _activitiesController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Activities completed',
                  hintText:
                      'Enter one activity per line, e.g.\nAssisted with mobility\nPrepared lunch\nProvided companionship',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Follow-up required',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Flag this entry if the family or care team needs to take further action.',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
                activeThumbColor: colors.primary,
                value: _followUpRequired,
                onChanged: (value) {
                  setState(() => _followUpRequired = value);
                },
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveJournalEntry,
                  icon: _saving
                      ? const SizedBox(
                          height: 17,
                          width: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _saving ? 'Saving...' : 'Save journal entry',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _entryCard(Map<String, dynamic> entry) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final title = (entry['title'] ?? 'Care update').toString();
    final body = (entry['body'] ?? '').toString();
    final created = entry['created_at'];
    final type = (entry['update_type'] ?? 'visit_summary')
        .toString()
        .replaceAll('_', ' ');
    final followUp = entry['follow_up_required'] == true;
    final activities = entry['activities'];

    return Card(
      margin: const EdgeInsets.only(bottom: 11),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (followUp)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.tertiaryContainer,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      'FOLLOW-UP',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onTertiaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '$type • ${_formatDate(created)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            Divider(height: 20, color: colors.outlineVariant),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            if (activities is List && activities.isNotEmpty) ...[
              const SizedBox(height: 13),
              Text(
                'Activities completed',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              ...activities.map((activity) {
                final text = activity is Map
                    ? (activity['name'] ?? activity['title'] ?? activity)
                        .toString()
                    : activity.toString();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 15,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          text,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyEntries() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 42,
            color: colors.primary,
          ),
          const SizedBox(height: 10),
          Text(
            'No journal entries yet',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your saved care visit notes will appear here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
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
              size: 40,
              color: colors.primary,
            ),
            const SizedBox(height: 10),
            Text(
              'Could not load your journal data.',
              style: theme.textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An unexpected error occurred.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _loadData,
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

    final hasBookableSchedules = _schedules.any(
      (item) => _scheduleId(item) != null,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Care Journal'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.brightness == Brightness.dark
                                  ? colors.primaryContainer
                                  : const Color(0xFF593847),
                              theme.brightness == Brightness.dark
                                  ? colors.secondaryContainer
                                  : const Color(0xFFA95570),
                          ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.menu_book_outlined,
                              color: theme.brightness == Brightness.dark
                                  ? colors.onPrimaryContainer
                                  : Colors.white,
                              size: 30,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Document every visit',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: theme.brightness == Brightness.dark
                                    ? colors.onPrimaryContainer
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              'Keep families informed by recording care activities, observations and follow-up needs.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.brightness == Brightness.dark
                                    ? colors.onPrimaryContainer
                                    : Colors.white,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (hasBookableSchedules)
                        _journalForm()
                      else
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(
                              'You need an assigned care booking before you can create a journal entry.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 25),
                      const MzaziSectionHeader(
                        title: 'Previous entries',
                        subtitle: 'Review the care updates you have recorded.',
                      ),
                      const SizedBox(height: 12),
                      if (_updates.isEmpty)
                        _emptyEntries()
                      else
                        ..._updates.map(_entryCard),
                    ],
                  ),
                ),
    );
  }
}
