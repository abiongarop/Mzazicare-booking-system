import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

class BookingScreen extends StatefulWidget {
  final Map<String, dynamic> caregiver;
  final int caregiverDatabaseId;

  const BookingScreen({
    super.key,
    required this.caregiver,
    required this.caregiverDatabaseId,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  String _arrangement = 'one_time';

  bool _submitting = false;
  bool _loadingServices = true;

  List<Map<String, dynamic>> _availableServices = [];
  final Set<int> _selectedServiceIds = {};

  String get _caregiverName {
    final account = widget.caregiver['account'];

    return (widget.caregiver['full_name'] ??
            widget.caregiver['caregiver_name'] ??
            widget.caregiver['name'] ??
            (account is Map ? account['full_name'] : null) ??
            'Selected caregiver')
        .toString();
  }

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    try {
      final services = await ApiService.getServicesForCaregiver(
        widget.caregiverDatabaseId,
      );

      if (!mounted) return;

      setState(() {
        _availableServices = services;
        _loadingServices = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loadingServices = false);
      _showMessage('Could not load caregiver services: $e');
    }
  }

  Future<void> _chooseServices() async {
    if (_loadingServices || _submitting) return;

    if (_availableServices.isEmpty) {
      _showMessage(
        'This caregiver has no available services listed.',
      );
      return;
    }

    final temporarySelection = Set<int>.from(
      _selectedServiceIds,
    );

    final selected = await showDialog<Set<int>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Choose care services'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: _availableServices.map((service) {
                    final id = int.tryParse(
                      service['id'].toString(),
                    );

                    if (id == null) {
                      return const SizedBox.shrink();
                    }

                    final name = service['name']?.toString() ??
                        'Care service';

                    return CheckboxListTile(
                      value: temporarySelection.contains(id),
                      title: Text(name),
                      controlAffinity:
                          ListTileControlAffinity.leading,
                      activeColor: MzaziCareColors.primary,
                      onChanged: (checked) {
                        setDialogState(() {
                          if (checked == true) {
                            temporarySelection.add(id);
                          } else {
                            temporarySelection.remove(id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      temporarySelection,
                    );
                  },
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedServiceIds
          ..clear()
          ..addAll(selected);
      });
    }
  }

  List<String> get _selectedServiceNames {
    return _availableServices
        .where((service) {
          final id = int.tryParse(service['id'].toString());
          return id != null && _selectedServiceIds.contains(id);
        })
        .map((service) => service['name'].toString())
        .toList();
  }

  Future<void> _chooseDate() async {
    final today = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 2, 12, 31),
    );

    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _chooseStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );

    if (picked != null && mounted) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _chooseEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ??
          const TimeOfDay(hour: 17, minute: 0),
    );

    if (picked != null && mounted) {
      setState(() => _endTime = picked);
    }
  }

  DateTime? _combineDateAndTime(
    DateTime? date,
    TimeOfDay? time,
  ) {
    if (date == null || time == null) return null;

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  String get _formattedDate {
    if (_selectedDate == null) return 'Choose care date';

    final date = _selectedDate!;

    return 'Date: '
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedServiceIds.isEmpty) {
      _showMessage('Please select at least one care service.');
      return;
    }

    if (_selectedDate == null ||
        _startTime == null ||
        _endTime == null) {
      _showMessage(
        'Please select a date, start time and end time.',
      );
      return;
    }

    final start = _combineDateAndTime(
      _selectedDate,
      _startTime,
    )!;

    final end = _combineDateAndTime(
      _selectedDate,
      _endTime,
    )!;

    if (!start.isAfter(DateTime.now())) {
      _showMessage('Choose a future booking start time.');
      return;
    }

    if (!end.isAfter(start)) {
      _showMessage(
        'The end time must be later than the start time.',
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final serviceIds = _selectedServiceIds
          .map((id) => id.toString())
          .toList();

      await ApiService.createCareSchedule(
        scheduledStart: start,
        scheduledEnd: end,
        caregiverDatabaseId: widget.caregiverDatabaseId,
        arrangement: _arrangement,
        services: serviceIds,
        familyNotes: _notesController.text.trim(),
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Booking submitted'),
          content: Text(
            'Your booking request for $_caregiverName '
            'was submitted successfully.\n\n'
            'Selected services: '
            '${_selectedServiceNames.join(', ')}\n\n'
            'The caregiver may still need to confirm the request.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Booking failed: $e');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: MzaziCareColors.text,
        ),
      ),
    );
  }

  Widget _timeButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  Widget _selectedServicesBox() {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Care services',
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loadingServices)
            const LinearProgressIndicator()
          else if (_selectedServiceNames.isEmpty)
            const Text(
              'No services selected',
              style: TextStyle(
                color: MzaziCareColors.textMuted,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedServiceNames.map((name) {
                return Chip(
                  label: Text(name),
                  backgroundColor: MzaziCareColors.surfaceSoft,
                  deleteIconColor: MzaziCareColors.primaryDark,
                  onDeleted: _submitting
                      ? null
                      : () {
                          final service =
                              _availableServices.firstWhere(
                            (item) =>
                                item['name'].toString() == name,
                          );

                          final id = int.tryParse(
                            service['id'].toString(),
                          );

                          if (id != null) {
                            setState(() {
                              _selectedServiceIds.remove(id);
                            });
                          }
                        },
                );
              }).toList(),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loadingServices || _submitting
                ? null
                : _chooseServices,
            icon: const Icon(Icons.add),
            label: Text(
              _loadingServices
                  ? 'Loading services...'
                  : 'Select care services',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MzaziCareColors.background,
      appBar: AppBar(
        title: const Text('Book caregiver'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      MzaziCareColors.primaryDark,
                      MzaziCareColors.primary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.volunteer_activism_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _caregiverName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Selected caregiver',
                      style: TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              const MzaziSectionHeader(
                title: 'Booking details',
                subtitle:
                    'Choose the care services and schedule that suit your family.',
              ),
              const SizedBox(height: 17),
              DropdownButtonFormField<String>(
                initialValue: _arrangement,
                decoration: const InputDecoration(
                  labelText: 'Care arrangement',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'one_time',
                    child: Text('One-time booking'),
                  ),
                  DropdownMenuItem(
                    value: 'recurring',
                    child: Text('Recurring booking'),
                  ),
                ],
                onChanged: _submitting
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _arrangement = value);
                        }
                      },
              ),
              const SizedBox(height: 20),
              _selectedServicesBox(),
              const SizedBox(height: 22),
              _sectionLabel('Care date'),
              _timeButton(
                icon: Icons.calendar_today_outlined,
                label: _formattedDate,
                onPressed: _submitting ? null : _chooseDate,
              ),
              const SizedBox(height: 17),
              _sectionLabel('Start time'),
              _timeButton(
                icon: Icons.access_time_outlined,
                label: _startTime == null
                    ? 'Choose start time'
                    : 'Start: ${_startTime!.format(context)}',
                onPressed: _submitting ? null : _chooseStartTime,
              ),
              const SizedBox(height: 17),
              _sectionLabel('End time'),
              _timeButton(
                icon: Icons.schedule_outlined,
                label: _endTime == null
                    ? 'Choose end time'
                    : 'End: ${_endTime!.format(context)}',
                onPressed: _submitting ? null : _chooseEndTime,
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _notesController,
                enabled: !_submitting,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Additional care notes (optional)',
                  hintText:
                      'Describe care needs or special instructions.',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _submitting || _loadingServices
                      ? null
                      : _submitBooking,
                  icon: _submitting
                      ? const SizedBox(
                          height: 19,
                          width: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _submitting
                        ? 'Submitting booking...'
                        : 'Confirm booking',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}