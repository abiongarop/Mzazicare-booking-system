
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../booking/booking_screen.dart';
import '../theme/app_theme.dart';

class RecommendationsScreen extends StatefulWidget {
  final bool refreshOnOpen;

  const RecommendationsScreen({
    super.key,
    this.refreshOnOpen = false,
  });

  @override
  State<RecommendationsScreen> createState() =>
      _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _caregivers = [];

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

  Future<void> _loadRecommendations() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ApiService.getFamilyRecommendations();

      final dynamic raw = response['recommendations'] ??
          response['results'] ??
          response['caregivers'] ??
          response['data'] ??
          [];

      final List<dynamic> items = raw is List ? raw : <dynamic>[];

      final updated = items
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where(_isVerified)
          .toList();

      if (!mounted) return;

      setState(() {
        _caregivers = updated;
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
    return caregiver['is_verified'] == true ||
        caregiver['verified'] == true;
  }

  String _value(
    dynamic value, {
    String fallback = 'Not provided',
  }) {
    if (value == null) return fallback;

    if (value is Map || value is List) {
      return fallback;
    }

    final text = value.toString().trim();

    return text.isEmpty ? fallback : text;
  }

  List<String> _names(dynamic value) {
    if (value is! List) return [];

    return value.map((item) {
      if (item is Map) {
        return (item['name'] ??
                item['service_name'] ??
                item['skill_name'] ??
                item['id'] ??
                '')
            .toString();
      }

      return item.toString();
    }).where((name) => name.trim().isNotEmpty).toList();
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
    final feature = _value(
      item['feature'],
      fallback: '',
    ).toLowerCase();

    final label = _value(
      item['label'],
      fallback: '',
    );

    if (label.isNotEmpty) return label;

    switch (feature) {
      case 'skill_match':
        return 'Required skills';
      case 'service_match':
        return 'Required care services';
      case 'availability_match':
        return 'Availability';
      case 'location_match':
      case 'distance_km':
        return 'Location suitability';
      case 'rating':
        return 'Caregiver rating';
      case 'experience_years':
        return 'Caregiving experience';
      default:
        return feature.isEmpty
            ? 'Recommendation factor'
            : feature.replaceAll('_', ' ');
    }
  }

  bool _isPositive(Map<String, dynamic> item) {
    final impact = _value(
      item['impact'],
      fallback: '',
    ).toLowerCase();

    if (impact == 'increased' || impact == 'positive') {
      return true;
    }

    if (impact == 'decreased' || impact == 'negative') {
      return false;
    }

    return (_number(item['contribution']) ?? 0) >= 0;
  }

  String _featureDescription(
    Map<String, dynamic> item,
    Map<String, dynamic> caregiver,
  ) {
    final feature = _value(
      item['feature'],
      fallback: '',
    ).toLowerCase();

    final positive = _isPositive(item);

    switch (feature) {
      case 'skill_match':
        final skills = _names(
          caregiver['matching_skills'] ?? caregiver['skills'],
        );

        if (skills.isEmpty) {
          return 'No required skills are currently recorded as matched. '
              'Please confirm the caregiver’s qualifications and skills '
              'before booking.';
        }

        return 'Recorded matching skills: ${skills.join(', ')}. '
            'This factor ${positive ? 'strengthened' : 'reduced'} '
            'the recommendation.';

      case 'service_match':
        final services = _names(
          caregiver['matching_services'] ?? caregiver['services'],
        );

        if (services.isEmpty) {
          return 'No requested care services are currently recorded '
              'as matched. Please confirm that the caregiver offers '
              'the services your family needs before booking.';
        }

        return 'Recorded matching services: ${services.join(', ')}. '
            'This factor ${positive ? 'strengthened' : 'reduced'} '
            'the recommendation.';

      case 'availability_match':
        return positive
            ? 'The caregiver’s recorded availability contributed '
                'positively to the recommendation.'
            : 'The caregiver’s recorded availability reduced '
                'the recommendation score. Confirm the preferred '
                'schedule before booking.';

      case 'rating':
        final rating = _value(
          caregiver['rating'],
          fallback: 'Not recorded',
        );

        return 'The caregiver has a recorded rating of $rating. '
            'This factor ${positive ? 'increased' : 'reduced'} '
            'the recommendation score.';

      case 'experience_years':
        final experience = _value(
          caregiver['experience_years'],
          fallback: 'Not recorded',
        );

        return 'The caregiver has $experience years of recorded '
            'experience. This factor '
            '${positive ? 'increased' : 'reduced'} the recommendation score.';

      case 'location_match':
      case 'distance_km':
        final distance = caregiver['distance_km'];

        if (distance != null) {
          return 'The recorded distance is $distance km. '
              'Location suitability ${positive ? 'supported' : 'reduced'} '
              'this recommendation.';
        }

        return 'The caregiver’s recorded location contributed '
            '${positive ? 'positively' : 'negatively'} to the location fit.';

      default:
        final explanation = item['explanation'];

        if (explanation is String && explanation.trim().isNotEmpty) {
          return explanation.trim();
        }

        return 'This factor ${positive ? 'increased' : 'decreased'} '
            'the caregiver’s recommendation score.';
    }
  }

  List<Map<String, dynamic>> _shapFactors(
    Map<String, dynamic> caregiver,
  ) {
    final raw = caregiver['explanation'] ??
        caregiver['shap_explanation'];

    if (raw is! List) return [];

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _recommendationSummary(
    Map<String, dynamic> caregiver,
  ) {
    final summary = caregiver['why_recommended'];

    if (summary is String && summary.trim().isNotEmpty) {
      return summary.trim();
    }

    final factors = _shapFactors(caregiver);

    if (factors.isEmpty) {
      final reason = caregiver['reason'];

      if (reason is String && reason.trim().isNotEmpty) {
        return reason.trim();
      }

      return 'This caregiver was selected by the recommendation system. '
          'Review the profile details and confirm suitability before booking.';
    }

    final positive = factors
        .where(_isPositive)
        .map(_featureLabel)
        .toList();

    final negative = factors
        .where((item) => !_isPositive(item))
        .map(_featureLabel)
        .toList();

    final parts = <String>[];

    if (positive.isNotEmpty) {
      parts.add('Factors supporting this recommendation include '
          '${positive.join(', ')}.');
    }

    if (negative.isNotEmpty) {
      parts.add('Factors that reduced the match include '
          '${negative.join(', ')}.');
    }

    return parts.join(' ');
  }

  Future<void> _openBooking(
    Map<String, dynamic> caregiver,
  ) async {
    final rawId = caregiver['caregiver_database_id'] ??
        caregiver['id'] ??
        caregiver['caregiver_pk'];

    final caregiverDatabaseId = int.tryParse(rawId.toString());

    if (caregiverDatabaseId == null) {
      _showMessage(
        'This caregiver has no valid booking database ID.',
      );
      return;
    }

    if (!_isVerified(caregiver)) {
      _showMessage('Only verified caregivers can be booked.');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _shapSection(
    Map<String, dynamic> caregiver, {
    required bool positive,
  }) {
    final factors = _shapFactors(caregiver)
        .where((item) => _isPositive(item) == positive)
        .toList();

    if (factors.isEmpty) return const SizedBox.shrink();

    final color = positive
        ? Colors.green.shade700
        : Colors.deepOrange.shade700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              positive
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              color: color,
              size: 19,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                positive
                    ? 'Factors supporting the match'
                    : 'Factors reducing the match',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ...factors.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: MzaziCareColors.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _featureDescription(item, caregiver),
                        style: const TextStyle(
                          color: MzaziCareColors.textMuted,
                          height: 1.4,
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
    Map<String, dynamic> caregiver,
  ) {
    final factors = _shapFactors(caregiver);
    final summary = _recommendationSummary(caregiver);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: MzaziCareColors.surfaceSoft,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: MzaziCareColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: MzaziCareColors.primaryDark,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Why this caregiver was recommended',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: MzaziCareColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            summary,
            style: const TextStyle(
              color: MzaziCareColors.text,
              height: 1.5,
              fontSize: 13,
            ),
          ),
          if (factors.isNotEmpty) ...[
            const SizedBox(height: 17),
            const Divider(),
            const SizedBox(height: 10),
            _shapSection(caregiver, positive: true),
            _shapSection(caregiver, positive: false),
            const SizedBox(height: 5),
            const Text(
              'These explanations are generated from the features '
              'used by the recommendation model. Please review the '
              'caregiver’s profile and confirm details before booking.',
              style: TextStyle(
                fontSize: 11,
                color: MzaziCareColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _caregiverCard(
    Map<String, dynamic> caregiver,
    int index,
  ) {
    final name = _value(
      caregiver['full_name'] ??
          caregiver['name'] ??
          caregiver['caregiver_id'],
      fallback: 'Caregiver',
    );

    final services = _names(
      caregiver['matching_services'] ?? caregiver['services'],
    );

    final skills = _names(
      caregiver['matching_skills'] ?? caregiver['skills'],
    );

    final score = caregiver['suitability_score'] ??
        caregiver['score'] ??
        caregiver['recommendation_score'] ??
        caregiver['probability'];

    final rating = _value(
      caregiver['rating'],
      fallback: 'Not rated',
    );

    final experience = _value(
      caregiver['experience_years'],
      fallback: '0',
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: MzaziCareColors.surface,
      elevation: 1,
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
              children: [
                CircleAvatar(
                  backgroundColor: MzaziCareColors.accent,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: MzaziCareColors.primaryDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: MzaziCareColors.text,
                    ),
                  ),
                ),
                const Icon(
                  Icons.verified,
                  color: MzaziCareColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 15),
            _detail(
              Icons.location_on_outlined,
              'Location',
              _location(caregiver),
            ),
            _detail(
              Icons.work_outline,
              'Experience',
              '$experience years',
            ),
            _detail(
              Icons.star_outline,
              'Rating',
              rating,
            ),
            _detail(
              Icons.schedule,
              'Availability',
              _value(caregiver['availability']),
            ),
            if (score != null)
              _detail(
                Icons.auto_awesome,
                'Suitability score',
                score.toString(),
              ),
            if (services.isNotEmpty)
              _detail(
                Icons.medical_services_outlined,
                'Matching services',
                services.join(', '),
              )
            else
              _detail(
                Icons.medical_services_outlined,
                'Matching services',
                'No matches currently recorded',
              ),
            if (skills.isNotEmpty)
              _detail(
                Icons.psychology_outlined,
                'Matching skills',
                skills.join(', '),
              )
            else
              _detail(
                Icons.psychology_outlined,
                'Matching skills',
                'No matches currently recorded',
              ),
            const SizedBox(height: 12),
            _explanationCard(caregiver),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openBooking(caregiver),
                icon: const Icon(Icons.calendar_month),
                label: const Text('Book this caregiver'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MzaziCareColors.primary,
                  foregroundColor: Colors.white,
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
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: MzaziCareColors.primary,
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 112,
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

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: const [
        SizedBox(height: 80),
        Icon(
          Icons.search_off,
          size: 55,
          color: MzaziCareColors.primary,
        ),
        SizedBox(height: 14),
        Text(
          'No verified caregiver recommendations found.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: MzaziCareColors.text,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Update your care requirements or try refreshing.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MzaziCareColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _errorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 70),
        const Icon(
          Icons.error_outline,
          size: 48,
          color: MzaziCareColors.primaryDark,
        ),
        const SizedBox(height: 12),
        const Text(
          'Could not load recommendations.',
          textAlign: TextAlign.center,
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
      backgroundColor: MzaziCareColors.background,
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
                  Center(
                    child: CircularProgressIndicator(),
                  ),
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
                          return _caregiverCard(
                            _caregivers[index],
                            index,
                          );
                        },
                      ),
      ),
    );
  }
}
