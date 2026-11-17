
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../dashboards/caregiver_dashboard_screen.dart';

class CaregiverProfileScreen extends StatefulWidget {
  final bool isOnboarding;

  const CaregiverProfileScreen({
    super.key,
    this.isOnboarding = false,
  });

  @override
  State<CaregiverProfileScreen> createState() =>
      _CaregiverProfileScreenState();
}

class _CaregiverProfileScreenState
    extends State<CaregiverProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _locationController = TextEditingController();
  final _qualificationsController = TextEditingController();
  final _experienceController = TextEditingController();
  final _bioController = TextEditingController();

  static const List<String> _services = [
    'Companionship',
    'Personal care',
    'Health monitoring',
    'Housekeeping',
    'Meal preparation',
    'Mobility assistance',
  ];

  static const List<String> _skills = [
    'Elderly care',
    'First aid',
    'Dementia care',
    'Mobility assistance',
    'Medication assistance',
    'Personal hygiene',
  ];

  static const Map<String, String> _availabilityOptions = {
    'Full-time': 'Full-time',
    'Part-time': 'Part-time',
    'Occasional': 'Occasional',
    'Live-in': 'Live-in',
  };

  static const Map<String, String> _workingTimeOptions = {
    'morning': 'Morning',
    'afternoon': 'Afternoon',
    'evening': 'Evening',
    'flexible': 'Flexible',
  };

  final Set<String> _selectedServices = {};
  final Set<String> _selectedSkills = {};

  String? _availability;
  String? _preferredWorkingTime;

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
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _locationController.dispose();
    _qualificationsController.dispose();
    _experienceController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  String _normalise(String value) {
    return value.trim().toLowerCase();
  }

  bool _sameChoice(String first, String second) {
    return _normalise(first) == _normalise(second);
  }

  bool _isSelected(Set<String> selected, String option) {
    return selected.any(
      (item) => _sameChoice(item, option),
    );
  }

  List<String> _choiceOptions(
    List<String> predefined,
    Set<String> selected,
  ) {
    final options = [...predefined];

    for (final saved in selected) {
      if (!options.any(
        (option) => _sameChoice(option, saved),
      )) {
        options.add(saved);
      }
    }

    return options;
  }

  String? _normaliseAvailability(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return null;
    }

    final savedValue = value.toString().trim();

    for (final option in _availabilityOptions.keys) {
      if (_sameChoice(option, savedValue) ||
          _sameChoice(
            option.replaceAll('-', '_'),
            savedValue,
          )) {
        return option;
      }
    }

    return savedValue;
  }

  String? _normaliseWorkingTime(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return null;
    }

    final savedValue = value.toString().trim().toLowerCase();

    return _workingTimeOptions.containsKey(savedValue)
        ? savedValue
        : null;
  }

  Future<void> _loadProfile() async {
    try {
      final results = await Future.wait([
        ApiService.getMyProfile(),
        ApiService.getCaregiverProfile(),
      ]);

      if (!mounted) return;

      final account = results[0];
      final data = results[1];

      _nameController.text =
          (account['full_name'] ?? '').toString();

      _phoneController.text =
          (account['phone'] ?? '').toString();

      _ageController.text =
          (data['age'] ?? '').toString();

      _locationController.text =
          _readLocation(data['location']) ??
          (account['location'] ?? '').toString();

      _qualificationsController.text =
          (data['qualifications'] ?? '').toString();

      _experienceController.text =
          (data['experience_years'] ?? '').toString();

      _bioController.text =
          (data['bio'] ?? '').toString();

      _availability =
          _normaliseAvailability(data['availability']);

      _preferredWorkingTime =
          _normaliseWorkingTime(
        data['preferred_working_time'],
      );

      _selectedServices
        ..clear()
        ..addAll(_readNames(data['services']));

      _selectedSkills
        ..clear()
        ..addAll(_readNames(data['skills']));

      setState(() {});
    } catch (e, stackTrace) {
      debugPrint('Caregiver profile loading error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        _showMessage(
          'Could not load caregiver profile. Please try again. $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String? _nullableString(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return null;
    }

    return value.toString().trim();
  }

  String? _readLocation(dynamic value) {
    if (value == null) return null;

    if (value is Map) {
      return _nullableString(value['name']);
    }

    return _nullableString(value);
  }

  List<String> _readNames(dynamic value) {
    if (value is! List) return [];

    return value
        .map((item) {
          if (item is Map) {
            return (item['name'] ?? '').toString().trim();
          }

          return item.toString().trim();
        })
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _saveProfile() async {
    if (_saving || _loading) return;

    if (!_formKey.currentState!.validate()) return;

    if (_selectedServices.isEmpty) {
      _showMessage('Select at least one service you provide.');
      return;
    }

    if (_selectedSkills.isEmpty) {
      _showMessage('Select at least one professional skill.');
      return;
    }

    if (_availability == null) {
      _showMessage('Select your work arrangement.');
      return;
    }

    setState(() => _saving = true);

    try {
      await ApiService.updateMyProfile(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        location: _locationController.text.trim(),
      );

      final savedProfile =
          await ApiService.saveCaregiverProfile({
        'age': int.parse(_ageController.text.trim()),
        'location': _locationController.text.trim(),
        'qualifications':
            _qualificationsController.text.trim(),
        'experience_years':
            int.parse(_experienceController.text.trim()),
        'bio': _bioController.text.trim(),
        'services': _selectedServices.toList(),
        'skills': _selectedSkills.toList(),
        'availability': _availability,
        'preferred_working_time':
            _preferredWorkingTime ?? '',
      });

      debugPrint('Saved caregiver profile: $savedProfile');

      if (!mounted) return;

      if (savedProfile.isEmpty) {
        throw Exception(
          'The server did not return the saved caregiver profile.',
        );
      }

      if (widget.isOnboarding) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => const CaregiverDashboardScreen(),
          ),
          (route) => false,
        );
      } else {
        await _loadProfile();

        if (!mounted) return;

        _showMessage(
          'Caregiver profile updated successfully.',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Caregiver profile saving error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        _showMessage('Could not save caregiver profile: $e');
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
          color: _colors.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        keyboardType: keyboardType,
        maxLines: maxLines,
        minLines: maxLines > 1 ? 3 : 1,
        textAlignVertical: TextAlignVertical.top,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: maxLines > 1,
        ),
        validator: validator ??
            (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter $label.';
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
            value: _isSelected(selected, option),
            activeColor: _colors.primary,
            checkColor: _colors.onPrimary,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: _saving
                ? null
                : (checked) {
                    setState(() {
                      selected.removeWhere(
                        (item) => _sameChoice(item, option),
                      );

                      if (checked == true) {
                        selected.add(option);
                      }
                    });
                  },
          ),
        ),
      ],
    );
  }

  Widget _availabilityDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _availability,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Preferred work arrangement',
      ),
      dropdownColor: _colors.surface,
      style: _theme.textTheme.bodyLarge?.copyWith(
        color: _colors.onSurface,
      ),
      items: _availabilityOptions.entries.map((entry) {
        return DropdownMenuItem<String>(
          value: entry.key,
          child: Text(entry.value),
        );
      }).toList(),
      onChanged: _saving
          ? null
          : (value) {
              setState(() => _availability = value);
            },
      validator: (value) {
        if (value == null) {
          return 'Select your work arrangement.';
        }

        return null;
      },
    );
  }

  Widget _preferredWorkingTimeDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _preferredWorkingTime,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Preferred working time',
        helperText: 'Choose when you prefer to work.',
      ),
      dropdownColor: _colors.surface,
      style: _theme.textTheme.bodyLarge?.copyWith(
        color: _colors.onSurface,
      ),
      items: _workingTimeOptions.entries.map((entry) {
        return DropdownMenuItem<String>(
          value: entry.key,
          child: Text(entry.value),
        );
      }).toList(),
      onChanged: _saving
          ? null
          : (value) {
              setState(() {
                _preferredWorkingTime = value;
              });
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isOnboarding,
      child: Scaffold(
        backgroundColor: _theme.scaffoldBackgroundColor,
        appBar: AppBar(
          automaticallyImplyLeading: !widget.isOnboarding,
          title: Text(
            widget.isOnboarding
                ? 'Complete Your Caregiver Profile'
                : 'Caregiver Profile',
          ),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  children: [
                    Text(
                      widget.isOnboarding
                          ? 'Welcome to MzaziCare! Complete your profile '
                              'to help families learn about your experience '
                              'and the care services you provide.'
                          : 'Tell families about yourself, your experience, '
                              'and the care you provide.',
                      style: _theme.textTheme.bodyLarge?.copyWith(
                        color: _colors.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),

                    _sectionTitle('Personal details'),

                    _textField(
                      _nameController,
                      'Full name',
                    ),

                    _textField(
                      _phoneController,
                      'Contact phone',
                      hint: 'e.g. 0712345678',
                      keyboardType: TextInputType.phone,
                    ),

                    _textField(
                      _ageController,
                      'Age',
                      hint: 'Enter your age',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final age =
                            int.tryParse(value?.trim() ?? '');

                        if (age == null || age < 18 || age > 100) {
                          return 'Enter a valid age between 18 and 100.';
                        }

                        return null;
                      },
                    ),

                    _textField(
                      _locationController,
                      'Location',
                      hint: 'e.g. Westlands, Nairobi',
                    ),

                    _sectionTitle('Professional background'),

                    _textField(
                      _qualificationsController,
                      'Qualifications and certifications',
                      hint: 'Describe your education and caregiving '
                          'training or certifications.',
                      maxLines: 4,
                    ),

                    _textField(
                      _experienceController,
                      'Years of experience',
                      hint: 'e.g. 6',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final years =
                            int.tryParse(value?.trim() ?? '');

                        if (years == null ||
                            years < 0 ||
                            years > 80) {
                          return 'Enter a number from 0 to 80.';
                        }

                        return null;
                      },
                    ),

                    _textField(
                      _bioController,
                      'Professional biography',
                      hint: 'Introduce yourself and describe your '
                          'caregiving experience and approach to elderly care.',
                      maxLines: 5,
                    ),

                    _choiceGroup(
                      'Services you provide',
                      _choiceOptions(
                        _services,
                        _selectedServices,
                      ),
                      _selectedServices,
                    ),

                    _choiceGroup(
                      'Professional skills',
                      _choiceOptions(
                        _skills,
                        _selectedSkills,
                      ),
                      _selectedSkills,
                    ),

                    _sectionTitle('Availability'),

                    _availabilityDropdown(),

                    const SizedBox(height: 16),

                    _preferredWorkingTimeDropdown(),

                    _sectionTitle('Verification'),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              color: _colors.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'After saving your profile, an administrator '
                                'will review your qualifications and '
                                'verification documents. Saving this form '
                                'does not mean you are verified.',
                                style: _theme.textTheme.bodyMedium?.copyWith(
                                  color: _colors.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

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
                            : Text(
                                widget.isOnboarding
                                    ? 'Complete Profile'
                                    : 'Save Caregiver Profile',
                                style: const TextStyle(fontSize: 16),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }
}
