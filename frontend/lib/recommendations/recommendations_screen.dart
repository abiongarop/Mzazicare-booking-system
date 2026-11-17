import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../booking/booking_screen.dart';
import '../widgets/shap_explanation_chart.dart';

class RecommendationsScreen extends StatefulWidget {
  final bool refreshOnOpen;

  const RecommendationsScreen({super.key, this.refreshOnOpen = false});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _caregivers = [];

  final Set<int> _bookedCaregiverIds = {};
  final Set<int> _pendingCaregiverIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRecommendations();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.refreshOnOpen) {
      _loadRecommendations();
    }
  }

  List<dynamic> _extractItems(
    Map<String, dynamic> response,
    List<String> possibleKeys,
  ) {
    for (final key in possibleKeys) {
      final value = response[key];

      if (value is List) {
        return value;
      }

      if (value is Map) {
        for (final nestedKey in ['results', 'data', 'items']) {
          final nested = value[nestedKey];
          if (nested is List) return nested;
        }
      }
    }

    return [];
  }

  Future<void> _loadRecommendations() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final responses = await Future.wait([
        ApiService.getFamilyRecommendations(),
        ApiService.getCareSchedules(),
      ]);

      final recommendationResponse = responses[0];
      final scheduleResponse = responses[1];

      final rawRecommendations = _extractItems(recommendationResponse, [
        'recommendations',
        'results',
        'caregivers',
        'data',
      ]);

      final updatedCaregivers = rawRecommendations
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where(_isVerified)
          .toList();

      final rawSchedules = _extractItems(scheduleResponse, [
        'results',
        'schedules',
        'care_schedules',
        'data',
      ]);

      final bookedIds = <int>{};
      final pendingIds = <int>{};

      for (final item in rawSchedules) {
        if (item is! Map) continue;

        final schedule = Map<String, dynamic>.from(item);

        final caregiverId = int.tryParse(
          (schedule['caregiver'] ?? '').toString(),
        );

        if (caregiverId == null) continue;

        final status = (schedule['status'] ?? '').toString().toLowerCase();

        if (status == 'confirmed' || status == 'in_progress') {
          bookedIds.add(caregiverId);
        } else if (status == 'pending') {
          pendingIds.add(caregiverId);
        }
      }

      if (!mounted) return;

      setState(() {
        _caregivers = updatedCaregivers;

        _bookedCaregiverIds
          ..clear()
          ..addAll(bookedIds);

        _pendingCaregiverIds
          ..clear()
          ..addAll(pendingIds);

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

  bool _isVerified(Map<String, dynamic> caregiver) {
    return caregiver['is_verified'] == true || caregiver['verified'] == true;
  }

  String _value(dynamic value, {String fallback = 'Not provided'}) {
    if (value == null || value is Map || value is List) {
      return fallback;
    }

    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  List<String> _names(dynamic value) {
    if (value is! List) return [];

    return value
        .map((item) {
          if (item is Map) {
            return (item['name'] ??
                    item['service_name'] ??
                    item['skill_name'] ??
                    item['id'] ??
                    '')
                .toString();
          }

          return item.toString();
        })
        .where((name) => name.trim().isNotEmpty)
        .toList();
  }

  String _location(Map<String, dynamic> caregiver) {
    final location = caregiver['location'];

    if (location is Map) {
      return _value(location['name']);
    }

    if (location is List) {
      final values = location
          .map((item) {
            if (item is Map) {
              return item['name']?.toString() ?? '';
            }
            return item.toString();
          })
          .where((item) => item.trim().isNotEmpty)
          .toList();

      return values.isEmpty ? 'Not provided' : values.join(', ');
    }

    return _value(location);
  }

  double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _featureLabel(Map<String, dynamic> item) {
    final feature = _value(item['feature'], fallback: '').toLowerCase().trim();

    switch (feature) {
      case 'skill_match':
      case 'matching_skills':
        return 'Required skills';

      case 'service_match':
      case 'matching_services':
        return 'Requested care services';

      case 'availability_match':
        return 'Availability';

      case 'location_match':
        return 'Location match';

      case 'distance_km':
        return 'Distance from your family';

      case 'rating':
        return 'Previous caregiver ratings';

      case 'experience_years':
      case 'experience_match':
        return 'Caregiving experience';

      default:
        final label = _value(item['label'], fallback: '');
        if (label.isNotEmpty) return label;

        return feature.isEmpty
            ? 'Care suitability'
            : feature
                  .replaceAll('_', ' ')
                  .split(' ')
                  .map(
                    (word) => word.isEmpty
                        ? word
                        : '${word[0].toUpperCase()}${word.substring(1)}',
                  )
                  .join(' ');
    }
  }

  bool _isPositive(Map<String, dynamic> item) {
    final impact = _value(item['impact'], fallback: '').toLowerCase();

    if (impact == 'increased' || impact == 'positive') {
      return true;
    }

    if (impact == 'decreased' || impact == 'negative') {
      return false;
    }

    return (_number(item['contribution']) ?? 0) >= 0;
  }

  List<Map<String, dynamic>> _shapFactors(Map<String, dynamic> caregiver) {
    final raw = caregiver['explanation'] ?? caregiver['shap_explanation'];

    if (raw is! List) return [];

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Map<String, double> _shapChartValues(Map<String, dynamic> caregiver) {
    final factors = _shapFactors(caregiver);
    final values = <String, double>{};

    for (final item in factors) {
      final contribution = _number(item['contribution']);
      if (contribution == null) continue;

      var label = _featureLabel(item);

      // Keep labels unique if the backend returns repeated factors.
      var suffix = 2;
      while (values.containsKey(label)) {
        label = '${_featureLabel(item)} ($suffix)';
        suffix++;
      }

      values[label] = contribution;
    }

    return values;
  }

  String _featureDescription(
    Map<String, dynamic> item,
    Map<String, dynamic> caregiver,
  ) {
    final feature = _value(item['feature'], fallback: '').toLowerCase().trim();

    final positive = _isPositive(item);

    switch (feature) {
      case 'skill_match':
      case 'matching_skills':
        final skills = _names(
          caregiver['matching_skills'] ?? caregiver['skills'],
        );

        if (skills.isEmpty) {
          return positive
              ? 'The caregiver’s recorded skills helped support this match.'
              : 'The available skills did not fully match the care recipient’s needs.';
        }

        return positive
            ? 'The caregiver has relevant skills for the care needed, including ${skills.join(', ')}.'
            : 'Some recorded skills may not fully meet the care recipient’s needs. The listed skills include ${skills.join(', ')}.';

      case 'service_match':
      case 'matching_services':
        final services = _names(
          caregiver['matching_services'] ?? caregiver['services'],
        );

        if (services.isEmpty) {
          return positive
              ? 'The caregiver’s service information supported this recommendation.'
              : 'The requested care services may not all be covered. Confirm the services offered before booking.';
        }

        return positive
            ? 'The caregiver offers services relevant to your request, including ${services.join(', ')}.'
            : 'The services currently recorded do not fully match your request. The listed services include ${services.join(', ')}.';

      case 'availability_match':
        return positive
            ? 'The caregiver’s recorded availability fits the requested care schedule.'
            : 'The caregiver’s availability may not fully fit the requested schedule. Please confirm the timing before booking.';

      case 'rating':
        final rating = _number(
          caregiver['rating'] ?? caregiver['caregiver_rating'],
        );

        if (rating == null || rating <= 0) {
          return 'There are not enough previous ratings recorded to assess this factor.';
        }

        return positive
            ? 'The caregiver’s previous rating of ${rating.toStringAsFixed(1)} out of 5 supported this recommendation.'
            : 'The caregiver’s previous rating of ${rating.toStringAsFixed(1)} out of 5 reduced this match.';

      case 'experience_years':
      case 'experience_match':
        final experience = _number(caregiver['experience_years']);

        if (experience == null) {
          return 'The caregiver’s experience details are not currently available.';
        }

        final years = experience == experience.roundToDouble()
            ? experience.toInt().toString()
            : experience.toStringAsFixed(1);

        return positive
            ? 'The caregiver has $years years of experience, which supports the care required.'
            : 'The caregiver’s recorded experience may be below what is preferred for these care needs.';

      case 'location_match':
        final location = _location(caregiver);

        return positive
            ? 'The caregiver’s location ($location) is a good match for the family’s location.'
            : 'The caregiver’s location may be less convenient for the family.';

      case 'distance_km':
        final distance = _number(caregiver['distance_km']);

        if (distance == null) {
          return positive
              ? 'The caregiver’s distance supported the recommendation.'
              : 'The caregiver’s distance reduced the suitability of this match.';
        }

        return positive
            ? 'The caregiver is approximately ${distance.toStringAsFixed(1)} km away, which supports this match.'
            : 'The caregiver is approximately ${distance.toStringAsFixed(1)} km away, which may make visits less convenient.';

      default:
        final explanation = item['explanation'];

        if (explanation is String && explanation.trim().isNotEmpty) {
          return explanation.trim();
        }

        return positive
            ? 'This factor helped make the caregiver a suitable match.'
            : 'This factor made the caregiver a less suitable match.';
    }
  }


String _recommendationSummary(
  Map<String, dynamic> caregiver,
) {
  final factors = _shapFactors(caregiver);

  if (factors.isEmpty) {
    final reason = caregiver['why_recommended'] ??
        caregiver['reason'];

    if (reason is String && reason.trim().isNotEmpty) {
      return reason.trim();
    }

    return 'This caregiver was identified as a possible match based '
        'on your family’s care requirements. Review their profile, '
        'experience and available services before making a booking.';
  }

  final positive = factors.where(_isPositive).toList();
  final negative = factors.where((item) => !_isPositive(item)).toList();

  final strengths = <String>[];
  final considerations = <String>[];

  for (final item in positive) {
    final feature = (item['feature'] ?? '').toString().toLowerCase();

    switch (feature) {
      case 'skill_match':
        strengths.add(
          'their skills are relevant to the care recipient’s needs',
        );
        break;

      case 'service_match':
        strengths.add(
          'the services they provide match the care your family requested',
        );
        break;

      case 'availability_match':
        strengths.add(
          'their recorded availability supports your preferred care schedule',
        );
        break;

      case 'experience_years':
      case 'experience_match':
        strengths.add(
          'their caregiving experience supports the level of care required',
        );
        break;

      case 'rating':
        strengths.add(
          'their previous caregiver ratings support their suitability',
        );
        break;

      case 'location_match':
        strengths.add(
          'their location is suitable for your family',
        );
        break;

      case 'distance_km':
        strengths.add(
          'their distance from your family makes care visits more convenient',
        );
        break;
    }
  }

  for (final item in negative) {
    final feature = (item['feature'] ?? '').toString().toLowerCase();

    switch (feature) {
      case 'skill_match':
        considerations.add(
          'some of the skills required may not be fully covered',
        );
        break;

      case 'service_match':
        considerations.add(
          'some requested care services may not be available',
        );
        break;

      case 'availability_match':
        considerations.add(
          'their availability may not fully match your preferred schedule',
        );
        break;

      case 'experience_years':
      case 'experience_match':
        considerations.add(
          'their recorded experience may not fully match the level of care needed',
        );
        break;

      case 'rating':
        considerations.add(
          'their previous ratings may need further consideration',
        );
        break;

      case 'location_match':
      case 'distance_km':
        considerations.add(
          'their location or distance may make visits less convenient',
        );
        break;
    }
  }

  final buffer = StringBuffer();

  if (strengths.isNotEmpty) {
    buffer.write(
      'This caregiver is recommended because ${strengths.join(', ')}.',
    );
  } else {
    buffer.write(
      'This caregiver was identified as a possible match based on '
      'your family’s care requirements.',
    );
  }

  if (considerations.isNotEmpty) {
    buffer.write(
      ' However, ${considerations.join(', ')}. '
      'We recommend discussing these details with the caregiver '
      'before confirming your booking.',
    );
  } else {
    buffer.write(
      ' These factors make the caregiver a promising option '
      'for your family. You can review their profile and confirm '
      'the details before booking.',
    );
  }

  return buffer.toString();
}


  Future<void> _openBooking(Map<String, dynamic> caregiver) async {
    final rawId =
        caregiver['caregiver_database_id'] ??
        caregiver['id'] ??
        caregiver['caregiver_pk'];

    final caregiverDatabaseId = int.tryParse(rawId.toString());

    if (caregiverDatabaseId == null) {
      _showMessage('This caregiver has no valid booking database ID.');
      return;
    }

    if (!_isVerified(caregiver)) {
      _showMessage('Only verified caregivers can be booked.');
      return;
    }

    if (_bookedCaregiverIds.contains(caregiverDatabaseId)) {
      _showMessage('You already have an active booking with this caregiver.');
      return;
    }

    if (_pendingCaregiverIds.contains(caregiverDatabaseId)) {
      _showMessage('Your booking request is still awaiting a decision.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingScreen(
          caregiver: Map<String, dynamic>.from(caregiver),
          caregiverDatabaseId: caregiverDatabaseId,
        ),
      ),
    );

    if (mounted) {
      await _loadRecommendations();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Color _positiveColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.green.shade300
        : Colors.green.shade800;
  }

  Color _negativeColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.red.shade300
        : Colors.red.shade800;
  }

  Widget _factorSection(
    BuildContext context,
    Map<String, dynamic> caregiver, {
    required bool positive,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final factors = _shapFactors(caregiver)
        .where((item) => _isPositive(item) == positive)
        .toList();

    if (factors.isEmpty) return const SizedBox.shrink();

    final color = positive ? _positiveColor(context) : _negativeColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              positive ? Icons.check_circle_outline : Icons.info_outline,
              color: color,
              size: 19,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                positive
                    ? 'What makes this caregiver a good match'
                    : 'What to consider before booking',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...factors.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _featureLabel(item),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _featureDescription(item, caregiver),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.45,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _explanationCard(
    BuildContext context,
    Map<String, dynamic> caregiver,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final factors = _shapFactors(caregiver);
    final chartValues = _shapChartValues(caregiver);
    final summary = _recommendationSummary(caregiver);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: colors.primary,
                size: 21,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Why this caregiver was recommended',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            summary,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface,
              height: 1.55,
              fontSize: 13,
            ),
          ),

          if (chartValues.isNotEmpty) ...[
            const SizedBox(height: 16),
            ShapExplanationChart(shapValues: chartValues),
          ],

          if (factors.isNotEmpty) ...[
            const SizedBox(height: 15),
            Divider(color: colors.outlineVariant),
            const SizedBox(height: 12),
            _factorSection(context, caregiver, positive: true),
            _factorSection(context, caregiver, positive: false),
            const SizedBox(height: 5),
            Text(
              'This explanation is based on the information available '
              'in the caregiver profile and your care requirements. '
              'Please review the profile and confirm important details '
              'before booking.',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _caregiverCard(
    BuildContext context,
    Map<String, dynamic> caregiver,
    int index,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final rawDatabaseId =
        caregiver['caregiver_database_id'] ??
        caregiver['id'] ??
        caregiver['caregiver_pk'];

    final databaseId = int.tryParse(rawDatabaseId.toString());

    final isBooked =
        databaseId != null && _bookedCaregiverIds.contains(databaseId);

    final isPending =
        databaseId != null && _pendingCaregiverIds.contains(databaseId);

    final name = _value(
      caregiver['full_name'] ?? caregiver['name'] ?? caregiver['caregiver_id'],
      fallback: 'Caregiver',
    );

    final services = _names(
      caregiver['matching_services'] ?? caregiver['services'],
    );

    final skills = _names(caregiver['matching_skills'] ?? caregiver['skills']);

    final score =
        caregiver['suitability_score'] ??
        caregiver['score'] ??
        caregiver['recommendation_score'] ??
        caregiver['probability'];

    final rating = _value(
      caregiver['rating'] ?? caregiver['caregiver_rating'],
      fallback: 'Not rated',
    );

    final experience = _value(caregiver['experience_years'], fallback: '0');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                Icon(Icons.verified, color: colors.primary),
              ],
            ),
            const SizedBox(height: 15),
            _detail(
              context,
              Icons.location_on_outlined,
              'Location',
              _location(caregiver),
            ),
            _detail(
              context,
              Icons.work_outline,
              'Experience',
              '$experience years',
            ),
            _detail(context, Icons.star_outline, 'Rating', rating),
            _detail(
              context,
              Icons.schedule,
              'Availability',
              _value(caregiver['availability']),
            ),
            if (score != null)
              _detail(
                context,
                Icons.auto_awesome,
                'Suitability score',
                score.toString(),
              ),
            _detail(
              context,
              Icons.medical_services_outlined,
              'Matching services',
              services.isEmpty
                  ? 'No matches currently recorded'
                  : services.join(', '),
            ),
            _detail(
              context,
              Icons.psychology_outlined,
              'Matching skills',
              skills.isEmpty
                  ? 'No matches currently recorded'
                  : skills.join(', '),
            ),
            const SizedBox(height: 12),
            _explanationCard(context, caregiver),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: isBooked
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Already booked'),
                    )
                  : isPending
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.hourglass_top),
                      label: const Text('Request pending'),
                    )
                  : ElevatedButton.icon(
                      onPressed: () => _openBooking(caregiver),
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('Book this caregiver'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(width: 9),
          SizedBox(
            width: 112,
            child: Text(
              '$label:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.search_off, size: 55, color: colors.primary),
        const SizedBox(height: 14),
        Text(
          'No verified caregiver recommendations found.',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Update your care requirements or try refreshing.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _errorState() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 70),
        Icon(Icons.error_outline, size: 48, color: colors.error),
        const SizedBox(height: 12),
        Text(
          'Could not load recommendations.',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _error ?? '',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            onPressed: _loadRecommendations,
            child: const Text('Try again'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Recommended Caregivers'),
        actions: [
          IconButton(
            tooltip: 'Refresh recommendations',
            onPressed: _loading ? null : _loadRecommendations,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRecommendations,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 250),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null
            ? _errorState()
            : _caregivers.isEmpty
            ? _emptyState()
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                itemCount: _caregivers.length,
                itemBuilder: (context, index) {
                  return _caregiverCard(context, _caregivers[index], index);
                },
              ),
      ),
    );
  }
}
