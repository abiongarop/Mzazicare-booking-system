
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../onboarding/family_profile_screen.dart';
import '../booking/care_schedule_screen.dart';
import '../messaging/messages_screen.dart';
import '../care_updates/care_updates_screen.dart';
import '../auth/auth_screen.dart';

class FamilyDashboardScreen extends StatefulWidget {
  const FamilyDashboardScreen({super.key});

  @override
  State<FamilyDashboardScreen> createState() =>
      _FamilyDashboardScreenState();
}

class _FamilyDashboardScreenState extends State<FamilyDashboardScreen> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _careProfile = {};
  List<dynamic> _recommendations = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  // ------------------------------------------------------------
  // DATA CONVERSION HELPERS
  // ------------------------------------------------------------

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  List<dynamic> _toList(dynamic value) {
    if (value is List) return value;

    if (value is Map) {
      final results = value['results'] ??
          value['recommendations'] ??
          value['data'];

      if (results is List) return results;
    }

    return [];
  }

  String _value(
    dynamic value, {
    String fallback = 'Not provided',
  }) {
    if (value == null || value.toString().trim().isEmpty) {
      return fallback;
    }

    return value.toString();
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList();
    }

    if (value == null || value.toString().trim().isEmpty) {
      return [];
    }

    return [value.toString()];
  }

  String _formatLocation(dynamic value) {
    final locations = _stringList(value);

    if (locations.isEmpty) return 'Not provided';

    return locations.join(', ');
  }

  // ------------------------------------------------------------
  // LOAD DASHBOARD
  // ------------------------------------------------------------

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getMyProfile(),
        ApiService.getFamilyCareProfile(),
        ApiService.getFamilyRecommendations(),
      ]);

      debugPrint(
        'RECOMMENDATION RESPONSE: ${results[2]}',
      );

      if (!mounted) return;

      setState(() {
        _profile = _toMap(results[0]);
        _careProfile = _toMap(results[1]);

        // The recommendation endpoint returns a map
        // containing a "recommendations" list.
        _recommendations = _toList(results[2]);

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

  Future<void> _openPage(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );

    if (mounted) {
      _loadDashboard();
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const AuthScreen(),
      ),
      (route) => false,
    );
  }

  // ------------------------------------------------------------
  // SHAP EXPLANATIONS
  // ------------------------------------------------------------

  String _humanReadableFactor(
    Map<String, dynamic> factor,
  ) {
    final feature = factor['feature']?.toString() ?? '';
    final impact =
        factor['impact']?.toString().toLowerCase() ?? '';

    final contribution =
        double.tryParse('${factor['contribution']}') ?? 0;

    final increased = impact == 'increased' ||
        (impact.isEmpty && contribution > 0);

    switch (feature) {
      case 'skill_match':
        return increased
            ? 'The caregiver has recorded skills that support your care requirements.'
            : 'The caregiver’s recorded skills did not sufficiently match the skills required in your care profile.';

      case 'service_match':
        return increased
            ? 'The caregiver’s recorded services support the services requested in your care profile.'
            : 'The caregiver’s recorded services did not sufficiently match the services requested in your care profile.';

      case 'availability_match':
        return increased
            ? 'The caregiver’s availability positively influenced the recommendation.'
            : 'The caregiver’s availability did not align well with your preferred care arrangement.';

      case 'location_match':
        return increased
            ? 'The caregiver’s location was favourable for your care location.'
            : 'The caregiver’s location was less suitable for your care location.';

      case 'distance_km':
        return increased
            ? 'The caregiver’s distance from your home supported the recommendation.'
            : 'The distance between the caregiver and your home reduced the recommendation score.';

      case 'rating':
        return increased
            ? 'The caregiver’s rating positively influenced the recommendation.'
            : 'The caregiver’s rating reduced the recommendation score.';

      case 'experience_years':
        return increased
            ? 'The caregiver’s years of experience positively influenced the recommendation.'
            : 'The caregiver’s years of experience reduced the recommendation score.';

      default:
        final label = _value(
          factor['label'],
          fallback: 'Additional matching factor',
        );

        return increased
            ? '$label positively influenced the recommendation.'
            : '$label reduced the recommendation score.';
    }
  }

  Widget _explanationItem({
    required String explanation,
    required bool positive,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            positive
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded,
            color: positive
                ? MzaziCareColors.primaryDark
                : MzaziCareColors.textMuted,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              explanation,
              style: const TextStyle(
                color: MzaziCareColors.textMuted,
                height: 1.45,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _explanationSection(dynamic explanation) {
    final factors = _toList(explanation)
        .map(_toMap)
        .where((factor) => factor.isNotEmpty)
        .toList();

    if (factors.isEmpty) {
      return const Text(
        'Detailed recommendation explanations are not available.',
        style: TextStyle(
          color: MzaziCareColors.textMuted,
          height: 1.4,
          fontSize: 13,
        ),
      );
    }

    final supportingFactors = <Map<String, dynamic>>[];
    final factorsToReview = <Map<String, dynamic>>[];

    for (final factor in factors) {
      final impact =
          factor['impact']?.toString().toLowerCase() ?? '';

      final contribution =
          double.tryParse('${factor['contribution']}') ?? 0;

      final positive = impact == 'increased' ||
          (impact.isEmpty && contribution > 0);

      if (positive) {
        supportingFactors.add(factor);
      } else {
        factorsToReview.add(factor);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 25),

        const Text(
          'Why this caregiver was recommended',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: MzaziCareColors.text,
          ),
        ),

        const SizedBox(height: 13),

        if (supportingFactors.isNotEmpty) ...[
          const Text(
            'Factors supporting the recommendation',
            style: TextStyle(
              color: MzaziCareColors.primaryDark,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 9),

          ...supportingFactors.map((factor) {
            return _explanationItem(
              explanation: _humanReadableFactor(factor),
              positive: true,
            );
          }),
        ] else
          const Text(
            'No factors positively influenced this recommendation.',
            style: TextStyle(
              color: MzaziCareColors.textMuted,
              fontSize: 13,
            ),
          ),

        if (factorsToReview.isNotEmpty) ...[
          const SizedBox(height: 9),
          const Text(
            'Areas to review',
            style: TextStyle(
              color: MzaziCareColors.text,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 9),

          ...factorsToReview.map((factor) {
            return _explanationItem(
              explanation: _humanReadableFactor(factor),
              positive: false,
            );
          }),
        ],
      ],
    );
  }

  // ------------------------------------------------------------
  // DASHBOARD HEADER
  // ------------------------------------------------------------

  Widget _dashboardHeader(String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
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
            Icons.favorite_rounded,
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(height: 18),
          Text(
            'Welcome, $name',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'Find trusted care and stay connected to your loved one.',
            style: TextStyle(
              color: Colors.white,
              height: 1.5,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openPage(
                const FamilyProfileScreen(),
              ),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Manage care profile'),
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

  // ------------------------------------------------------------
  // QUICK ACTIONS
  // ------------------------------------------------------------

  Widget _quickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: MzaziCareColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: MzaziCareColors.primaryDark,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: MzaziCareColors.primaryDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // FAMILY CARE PROFILE
  // ------------------------------------------------------------

  Widget _careProfileCard() {
    final location = _value(_careProfile['location']);
    final careLevel = _value(_careProfile['care_level']);
    final arrangement =
        _value(_careProfile['care_arrangement']);

    final services =
        _stringList(_careProfile['required_services']);

    final serviceText = services.isEmpty
        ? 'Not provided'
        : services.join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.elderly_rounded,
                  color: MzaziCareColors.primaryDark,
                  size: 25,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Care details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => _openPage(
                    const FamilyProfileScreen(),
                  ),
                  child: const Text('Edit'),
                ),
              ],
            ),
            const Divider(height: 24),
            _detailRow(
              Icons.location_on_outlined,
              'Location',
              location,
            ),
            _detailRow(
              Icons.health_and_safety_outlined,
              'Care level',
              careLevel,
            ),
            _detailRow(
              Icons.home_outlined,
              'Care arrangement',
              arrangement,
            ),
            _detailRow(
              Icons.medical_services_outlined,
              'Required services',
              serviceText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: MzaziCareColors.primaryDark,
          ),
          const SizedBox(width: 11),
          SizedBox(
            width: 125,
            child: Text(
              label,
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

  // ------------------------------------------------------------
  // RECOMMENDATION INFORMATION CHIPS
  // ------------------------------------------------------------

  Widget _infoChip(
    IconData icon,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: MzaziCareColors.surfaceSoft,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: MzaziCareColors.primaryDark,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: MzaziCareColors.text,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // RECOMMENDED CAREGIVER CARD
  // ------------------------------------------------------------

  Widget _recommendationCard(dynamic item) {
    final caregiver = _toMap(item);

    final caregiverId = _value(
      caregiver['caregiver_id'],
      fallback: 'ID unavailable',
    );

    final databaseId = caregiver['caregiver_database_id'];

    // Your current response does not contain full_name.
    // Display the actual caregiver ID instead of a false name.
    final name = _value(
      caregiver['full_name'] ??
          caregiver['name'] ??
          caregiver['caregiver_name'],
      fallback: 'Caregiver $caregiverId',
    );

    final experience = caregiver['experience_years'];
    final rating = caregiver['rating'];
    final availability = caregiver['availability'];

    final location = _formatLocation(
      caregiver['location'],
    );

    final isVerified = caregiver['is_verified'] == true;

    final rank = caregiver['recommendation_rank'];
    final score = caregiver['suitability_score'];

    final services = _stringList(
      caregiver['matching_services'],
    );

    final skills = _stringList(
      caregiver['matching_skills'],
    );

    final explanation = caregiver['explanation'];

    final whyRecommended =
        caregiver['why_recommended']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Caregiver identity and verification
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor: MzaziCareColors.accent,
                  child: const Icon(
                    Icons.person_rounded,
                    color: MzaziCareColors.primaryDark,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Caregiver ID: $caregiverId',
                        style: const TextStyle(
                          color: MzaziCareColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      if (databaseId != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Database ID: $databaseId',
                          style: const TextStyle(
                            color: MzaziCareColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: MzaziCareColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 15,
                          color: MzaziCareColors.primaryDark,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: TextStyle(
                            fontSize: 11,
                            color: MzaziCareColors.primaryDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Recommendation rank and score
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (rank != null)
                  _infoChip(
                    Icons.emoji_events_outlined,
                    'Rank #$rank',
                  ),
                if (score != null)
                  _infoChip(
                    Icons.analytics_outlined,
                    'Suitability score: $score',
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Experience, rating and availability
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (experience != null)
                  _infoChip(
                    Icons.work_outline,
                    '$experience years experience',
                  ),
                if (rating != null)
                  _infoChip(
                    Icons.star_outline_rounded,
                    'Rating: $rating / 5',
                  ),
                if (availability != null)
                  _infoChip(
                    Icons.schedule_outlined,
                    availability.toString(),
                  ),
              ],
            ),

            const SizedBox(height: 15),

            // Location
            _recommendationDetail(
              Icons.location_on_outlined,
              'Location',
              location,
            ),

            const SizedBox(height: 11),

            // Matching services
            _recommendationDetail(
              Icons.medical_services_outlined,
              'Matching services',
              services.isEmpty
                  ? 'No matching services were returned by the recommendation API.'
                  : services.join(', '),
            ),

            const SizedBox(height: 11),

            // Matching skills
            _recommendationDetail(
              Icons.psychology_outlined,
              'Matching skills',
              skills.isEmpty
                  ? 'No matching skills were returned by the recommendation API.'
                  : skills.join(', '),
            ),

            // Human-readable SHAP explanation
            _explanationSection(explanation),

            // General recommendation summary
            if (whyRecommended != null &&
                whyRecommended.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: MzaziCareColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  whyRecommended,
                  style: const TextStyle(
                    color: MzaziCareColors.text,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _recommendationDetail(
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: MzaziCareColors.primaryDark,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: MzaziCareColors.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: MzaziCareColors.textMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // RECOMMENDATIONS SECTION
  // ------------------------------------------------------------

  Widget _recommendationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MzaziSectionHeader(
          title: 'Recommended caregivers',
          subtitle:
              'Caregiver suggestions based on your care requirements.',
        ),

        const SizedBox(height: 14),

        if (_recommendations.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  const Icon(
                    Icons.volunteer_activism_outlined,
                    size: 38,
                    color: MzaziCareColors.primaryDark,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No recommendations available yet',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Complete your care profile so MzaziCare can identify caregivers whose services and skills match your needs.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: MzaziCareColors.textMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: () => _openPage(
                      const FamilyProfileScreen(),
                    ),
                    child: const Text('Complete care profile'),
                  ),
                ],
              ),
            ),
          )
        else
          ..._recommendations.map(_recommendationCard),
      ],
    );
  }

  // ------------------------------------------------------------
  // DASHBOARD CONTENT
  // ------------------------------------------------------------

  Widget _dashboardContent(String name) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      children: [
        _dashboardHeader(name),

        const SizedBox(height: 27),

        const MzaziSectionHeader(
          title: 'Your care management',
          subtitle:
              'Everything you need to coordinate care in one place.',
        ),

        const SizedBox(height: 14),

        _quickAction(
          icon: Icons.person_outline,
          title: 'Family care profile',
          subtitle:
              'Manage your loved one’s care requirements.',
          onTap: () => _openPage(
            const FamilyProfileScreen(),
          ),
        ),

        const SizedBox(height: 11),

        _quickAction(
          icon: Icons.calendar_month_outlined,
          title: 'Care schedule',
          subtitle: 'View and manage care bookings.',
          onTap: () => _openPage(
            const CareScheduleScreen(),
          ),
        ),

        const SizedBox(height: 11),

        _quickAction(
          icon: Icons.chat_bubble_outline,
          title: 'Messages',
          subtitle: 'Communicate with your caregiver.',
          onTap: () => _openPage(
            const MessagesScreen(),
          ),
        ),

        const SizedBox(height: 11),

        _quickAction(
          icon: Icons.notifications_active_outlined,
          title: 'Care updates',
          subtitle: 'Follow visit updates and care activities.',
          onTap: () => _openPage(
            const CareUpdatesScreen(),
          ),
        ),

        const SizedBox(height: 27),

        const MzaziSectionHeader(
          title: 'Your loved one’s care information',
          subtitle:
              'A summary of the details in your care profile.',
        ),

        const SizedBox(height: 14),

        _careProfileCard(),

        const SizedBox(height: 27),

        _recommendationsSection(),

        const SizedBox(height: 25),

        const Center(
          child: Text(
            'MzaziCare • Caring connects us.',
            style: TextStyle(
              color: MzaziCareColors.textMuted,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final name = _value(
      _profile['full_name'] ?? _profile['name'],
      fallback: 'there',
    );

    return Scaffold(
      backgroundColor: MzaziCareColors.background,

      appBar: AppBar(
        title: const Text('MzaziCare'),
        actions: [
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: _loading ? null : _loadDashboard,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          size: 42,
                          color: MzaziCareColors.primaryDark,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Unable to load your dashboard.',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadDashboard,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  child: SizedBox(
                    width: double.infinity,
                    child: _dashboardContent(name),
                  ),
                ),
    );
  }
}
