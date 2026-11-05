
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CaregiverProfileScreen extends StatefulWidget {
  const CaregiverProfileScreen({super.key});

  @override
  State<CaregiverProfileScreen> createState() =>
      _CaregiverProfileScreenState();
}

class _CaregiverProfileScreenState extends State<CaregiverProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _locationController = TextEditingController();
  final _qualificationsController = TextEditingController();
  final _experienceController = TextEditingController();
  final _bioController = TextEditingController();

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

  String? _availability;
  bool _loading = true;
  bool _saving = false;

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
          (data['contact_phone'] ?? account['phone'] ?? '').toString();

      _ageController.text =
          (data['age'] ?? account['age'] ?? '').toString();

      _locationController.text =
          (data['location'] ?? account['location'] ?? '').toString();

      _qualificationsController.text =
          (data['qualifications'] ?? '').toString();

      _experienceController.text =
          (data['experience_years'] ?? '').toString();

      _bioController.text =
          (data['bio'] ?? '').toString();

      _availability = _nullableString(data['availability']);

      _selectedServices
        ..clear()
        ..addAll(_readNames(data['services']));

      _selectedSkills
        ..clear()
        ..addAll(_readNames(data['skills']));

      setState(() {});
    } catch (e) {
      if (mounted) {
        _showMessage('Could not load caregiver profile: $e');
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
    return value.toString();
  }

  List<String> _readNames(dynamic value) {
    if (value is! List) return [];

    return value.map((item) {
      if (item is Map) {
        return (item['name'] ?? '').toString();
      }
      return item.toString();
    }).where((name) => name.trim().isNotEmpty).toList();
  }

  Future<void> _saveProfile() async {
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
      _showMessage('Select your availability.');
      return;
    }

    setState(() => _saving = true);

    try {
      // Update the general user account details.
      await ApiService.updateMyProfile(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        location: _locationController.text.trim(),
      );

      // Update the caregiver-specific profile.
      await ApiService.saveCaregiverProfile({
        'contact_phone': _phoneController.text.trim(),
        'age': int.parse(_ageController.text.trim()),
        'location': _locationController.text.trim(),
        'qualifications': _qualificationsController.text.trim(),
        'experience_years':
            int.parse(_experienceController.text.trim()),
        'bio': _bioController.text.trim(),
        'services': _selectedServices.toList(),
        'skills': _selectedSkills.toList(),
        'availability': _availability,
      });

      if (mounted) {
        _showMessage(
          'Caregiver profile saved. An administrator will review '
          'your verification status.',
        );
      }
    } catch (e) {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: MzaziCareColors.text,
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
            (value) => value == null || value.trim().isEmpty
                ? 'Please enter $label.'
                : null,
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
            title: Text(option),
            value: selected.contains(option),
            activeColor: MzaziCareColors.primary,
            checkColor: Colors.white,
            onChanged: (checked) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MzaziCareColors.background,
      appBar: AppBar(
        title: const Text('Caregiver Profile'),
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
                  const Text(
                    'Tell families about yourself, your experience, '
                    'and the care you provide. Your profile helps families '
                    'understand your professional background and suitability.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),

                  // PERSONAL DETAILS
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
                      final age = int.tryParse(value?.trim() ?? '');

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

                  // PROFESSIONAL BACKGROUND
                  _sectionTitle('Professional background'),

                  _textField(
                    _qualificationsController,
                    'Qualifications and certifications',
                    hint:
                        'Describe your educational background, '
                        'caregiving training, certificates and relevant '
                        'professional qualifications...',
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

                      if (years == null || years < 0 || years > 80) {
                        return 'Enter a number from 0 to 80.';
                      }

                      return null;
                    },
                  ),

                  _textField(
                    _bioController,
                    'Professional biography',
                    hint:
                        'Write a short introduction about yourself. '
                        'Describe your caregiving experience, your '
                        'approach to elderly care, and what families '
                        'can expect when working with you.',
                    maxLines: 5,
                  ),

                  // SERVICES AND SKILLS
                  _choiceGroup(
                    'Services you provide',
                    _services,
                    _selectedServices,
                  ),

                  _choiceGroup(
                    'Professional skills',
                    _skills,
                    _selectedSkills,
                  ),

                  // AVAILABILITY
                  _sectionTitle('Availability'),

                  DropdownButtonFormField<String>(
                    initialValue: _availability,
                    decoration: const InputDecoration(
                      labelText: 'Preferred work arrangement',
                    ),
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
                      setState(() => _availability = value);
                    },
                    validator: (value) => value == null
                        ? 'Select your availability.'
                        : null,
                  ),

                  // VERIFICATION
                  _sectionTitle('Verification'),

                  Card(
                    color: MzaziCareColors.surface,
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: MzaziCareColors.primary,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'After saving your profile, an administrator '
                              'will review your qualifications and verification '
                              'documents. Saving this form does not mean '
                              'you are verified.',
                              style: TextStyle(height: 1.4),
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
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save Caregiver Profile',
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
