import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../dashboards/family_dashboard_screen.dart';

class FamilyProfileScreen extends StatefulWidget {
  const FamilyProfileScreen({super.key});

  @override
  State<FamilyProfileScreen> createState() => _FamilyProfileScreenState();
}

class _FamilyProfileScreenState extends State<FamilyProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _ageController = TextEditingController();
  final _notesController = TextEditingController();

  static const _services = [
    'Companionship',
    'Personal care',
    'Health monitoring',
    'Housekeeping',
    'Meal preparation',
    'Mobility assistance',
  ];

  static const _skills = [
    'Elderly care',
    'First aid',
    'Dementia care',
    'Mobility assistance',
    'Medication assistance',
    'Personal hygiene',
  ];

  final Set<String> _selectedServices = {};
  final Set<String> _selectedSkills = {};

  String? _gender;
  String? _careLevel;
  String? _arrangement;

  bool _loading = true;
  bool _saving = false;

  ThemeData get _theme => Theme.of(context);
  ColorScheme get _colors => _theme.colorScheme;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _locationController.dispose();
    _ageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _nullableString(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return null;
    }
    return value.toString();
  }

  List<String> _readNames(dynamic value) {
    if (value is! List) return [];

    return value
        .map((item) {
          if (item is Map) {
            return (item['name'] ?? '').toString();
          }
          return item.toString();
        })
        .where((name) => name.trim().isNotEmpty)
        .toList();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ApiService.getFamilyCareProfile();

      if (!mounted) return;

      _phoneController.text = (data['contact_phone'] ?? '').toString();
      _locationController.text = (data['location'] ?? '').toString();
      _ageController.text =
          data['care_recipient_age']?.toString() ?? '';
      _notesController.text = (data['notes'] ?? '').toString();

      _gender = _nullableString(data['care_recipient_gender']);
      _careLevel = _nullableString(data['care_level']);
      _arrangement = _nullableString(data['care_arrangement']);

      _selectedServices
        ..clear()
        ..addAll(_readNames(data['required_services']));

      _selectedSkills
        ..clear()
        ..addAll(_readNames(data['required_skills']));

      setState(() {});
    } catch (e) {
      if (mounted) {
        _showMessage('Could not load profile: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
  if (_saving || !_formKey.currentState!.validate()) return;

  if (_selectedServices.isEmpty) {
    _showMessage('Select at least one care service.');
    return;
  }

  setState(() => _saving = true);

  try {
    final payload = {
      'contact_phone': _phoneController.text.trim(),
      'location': _locationController.text.trim(),
      'care_recipient_age': int.parse(_ageController.text.trim()),
      'care_recipient_gender': _gender ?? '',
      'required_services': _selectedServices.toList(),
      'required_skills': _selectedSkills.toList(),
      'care_level': _careLevel ?? '',
      'care_arrangement': _arrangement ?? '',
      'notes': _notesController.text.trim(),
    };

    // Save the family care profile.
    await ApiService.saveFamilyCareProfile(payload);

    if (!mounted) return;

    _showMessage('Your family care profile has been saved successfully.');

    // Navigate to the Family Dashboard.
    // The dashboard will load the recommendations.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const FamilyDashboardScreen(),
      ),
      (route) => false,
    );
  } catch (e) {
    if (mounted) {
      _showMessage('Could not save your family profile: $e');
    }
  } finally {
    if (mounted) {
      setState(() => _saving = false);
    }
  }
}

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(
        title,
        style: _theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: _colors.onSurface,
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        keyboardType: keyboardType,
        maxLines: maxLines,
        minLines: maxLines > 1 ? 3 : 1,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: maxLines > 1,
        ),
        validator: (value) {
          final text = value?.trim() ?? '';

          if (label == 'Care recipient age') {
            final age = int.tryParse(text);
            if (age == null || age < 1 || age > 120) {
              return 'Enter an age between 1 and 120.';
            }
          }

          if (label == 'Location' && text.isEmpty) {
            return 'Enter the care location.';
          }

          if (label == 'Contact phone' && text.isEmpty) {
            return 'Enter a contact phone number.';
          }

          return null;
        },
      ),
    );
  }

  Widget _choiceGroup(
    String title,
    List<String> options,
    Set<String> selected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
        ...options.map(
          (option) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              option,
              style: _theme.textTheme.bodyLarge?.copyWith(
                color: _colors.onSurface,
              ),
            ),
            value: selected.contains(option),
            activeColor: _colors.primary,
            checkColor: _colors.onPrimary,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: _saving
                ? null
                : (checked) {
                    setState(() {
                      if (checked == true) {
                        selected.add(option);
                      } else {
                        selected.remove(option);
                      }
                    });
                  },
          ),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final validValue = items.any((item) => item.value == value)
        ? value
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        initialValue: validValue,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        dropdownColor: _colors.surface,
        style: _theme.textTheme.bodyLarge?.copyWith(
          color: _colors.onSurface,
        ),
        items: items,
        onChanged: _saving ? null : onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Family Care Profile'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                children: [
                  Text(
                    'Tell us about the care your loved one needs.',
                    style: _theme.textTheme.bodyLarge?.copyWith(
                      height: 1.5,
                      color: _colors.onSurfaceVariant,
                    ),
                  ),

                  _sectionTitle('Contact and location'),

                  _textField(
                    _phoneController,
                    'Contact phone',
                    keyboardType: TextInputType.phone,
                  ),

                  _textField(
                    _locationController,
                    'Location',
                    hint: 'e.g. Westlands, Nairobi',
                  ),

                  _sectionTitle('Care recipient'),

                  _textField(
                    _ageController,
                    'Care recipient age',
                    keyboardType: TextInputType.number,
                  ),

                  _dropdown(
                    label: 'Gender',
                    value: _gender,
                    items: const [
                      DropdownMenuItem(
                        value: 'female',
                        child: Text('Female'),
                      ),
                      DropdownMenuItem(
                        value: 'male',
                        child: Text('Male'),
                      ),
                      DropdownMenuItem(
                        value: 'other',
                        child: Text('Other / Prefer not to say'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _gender = value);
                    },
                  ),

                  _choiceGroup(
                    'Required care services',
                    _services,
                    _selectedServices,
                  ),

                  _choiceGroup(
                    'Required caregiver skills',
                    _skills,
                    _selectedSkills,
                  ),

                  _sectionTitle('Care arrangements'),

                  _dropdown(
                    label: 'Level of care',
                    value: _careLevel,
                    items: const [
                      DropdownMenuItem(
                        value: 'basic',
                        child: Text('Basic assistance'),
                      ),
                      DropdownMenuItem(
                        value: 'moderate',
                        child: Text('Moderate assistance'),
                      ),
                      DropdownMenuItem(
                        value: 'intensive',
                        child: Text('Intensive assistance'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _careLevel = value);
                    },
                  ),

                  _dropdown(
                    label: 'Preferred arrangement',
                    value: _arrangement,
                    items: const [
                      DropdownMenuItem(
                        value: 'full_time',
                        child: Text('Full-time'),
                      ),
                      DropdownMenuItem(
                        value: 'part_time',
                        child: Text('Part-time'),
                      ),
                      DropdownMenuItem(
                        value: 'occasional',
                        child: Text('Occasional'),
                      ),
                      DropdownMenuItem(
                        value: 'live_in',
                        child: Text('Live-in'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _arrangement = value);
                    },
                  ),

                  _sectionTitle('Additional information'),

                  _textField(
                    _notesController,
                    'Additional notes',
                    maxLines: 4,
                    hint: 'Describe any other care needs...',
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveProfile,
                      child: _saving
                          ? SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: _colors.onPrimary,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save and Update Recommendations',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
