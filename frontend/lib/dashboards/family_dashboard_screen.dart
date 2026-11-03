import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../onboarding/family_profile_screen.dart';

import '../booking/care_schedule_screen.dart';

import '../messaging/messages_screen.dart';
import '../care_updates/care_updates_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../auth/auth_screen.dart';


const _green = Color(0xFF176B57);
const _darkGreen = Color(0xFF174A3D);
const _page = Color(0xFFF5F8F6);

class FamilyDashboardScreen extends StatefulWidget {
  const FamilyDashboardScreen({super.key});

  @override
  State<FamilyDashboardScreen> createState() => _FamilyDashboardScreenState();
}

class _FamilyDashboardScreenState extends State<FamilyDashboardScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _care = {};
  List<dynamic> _recommendations = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
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
  

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getMyProfile(),
        ApiService.getFamilyCareProfile(),
      ]);

      Map<String, dynamic> recommendationData = {};

      // Recommendations may not be available until the family
      // profile and matching backend are fully configured.
      try {
        recommendationData = await ApiService.getFamilyRecommendations();
      } catch (e) {
        debugPrint('Recommendations not available yet: $e');
      }

      final raw =
          recommendationData['recommendations'] ??
          recommendationData['caregivers'] ??
          recommendationData['results'] ??
          [];

      if (!mounted) return;

      setState(() {
        _profile = results[0];
        _care = results[1];
        _recommendations = raw is List ? raw : <dynamic>[];
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

  Future<void> _openFamilyProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const FamilyProfileScreen()),
    );

    if (mounted) _loadDashboard();
  }
  

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _darkGreen,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF728078), fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: const BorderSide(color: Color(0xFFE3EBE6)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F2EC),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: _green, size: 25),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF758179),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _green),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendations() {
    if (_recommendations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3EBE6)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.people_alt_outlined, color: _green, size: 30),
            SizedBox(height: 10),
            Text(
              'Your caregiver matches will appear here',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            SizedBox(height: 6),
            Text(
              'Complete your family care profile so MzaziCare '
              'can use your care requirements to find suitable caregivers.',
              style: TextStyle(
                color: Color(0xFF758179),
                height: 1.5,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _recommendations.take(5).map((item) {
        if (item is! Map) return const SizedBox.shrink();

        final caregiverId =
    item['caregiver_id']?.toString() ??
    item['id']?.toString() ??
    'ID unavailable';

        final rating = item['rating'];
        final explanation =
            item['explanation'] ?? item['reason'] ?? item['matching_services'];

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          color: Colors.white,
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE6F2EC),
              child: Icon(Icons.person_outline, color: _green),
            ),
            title: Text(
              caregiverId,
              style: const TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 18,
    color: _darkGreen,
  ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rating != null) Text('Rating: $rating'),
                if (explanation != null)
                  Text(
                    explanation is List
                        ? explanation.join(', ')
                        : explanation.toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (_profile['full_name'] ?? _profile['name'] ?? 'there')
        .toString();

    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
  title: const Text('Family Dashboard'),
  actions: [
    IconButton(
      tooltip: 'Log out',
      icon: const Icon(Icons.logout),
      onPressed: _logout,
    ),
  ],
),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 42),
                    const SizedBox(height: 12),
                    const Text(
                      'Unable to load your dashboard.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(_error!, textAlign: TextAlign.center),
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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 850),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(23),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_darkGreen, _green],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(23),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.favorite_rounded,
                              color: Color(0xFFC8E7D4),
                              size: 30,
                            ),
                            const SizedBox(height: 17),
                            Text(
                              'Hello, $name',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Care that feels closer. '
                              'Support that gives your family peace of mind.',
                              style: TextStyle(
                                color: Color(0xFFE0F0E7),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _openFamilyProfile,
                                icon: const Icon(Icons.search),
                                label: const Text('Find my care matches'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFE5F2E9),
                                  foregroundColor: _darkGreen,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _sectionTitle(
                        'Your care space',
                        subtitle: 'Everything you need to coordinate care.',
                      ),
                      _actionCard(
                        icon: Icons.assignment_ind_outlined,
                        title: 'Family care profile',
                        description:
                            'Manage care needs, location and preferences.',
                        onTap: _openFamilyProfile,
                      ),
                      
_actionCard(
  icon: Icons.calendar_month_outlined,
  title: 'Care schedule',
  description: 'View your bookings and arrange care visits.',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CareScheduleScreen(),
      ),
    );
  },
),

                      _actionCard(
  icon: Icons.chat_bubble_outline,
  title: 'Messages',
  description: 'Communicate directly with your caregiver.',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MessagesScreen(),
      ),
    );
  },
),

_actionCard(
  icon: Icons.health_and_safety_outlined,
  title: 'Visit updates',
  description: 'Read care summaries, activities and follow-up notes.',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CareUpdatesScreen(),
      ),
    );
  },
),
                      const SizedBox(height: 22),
                      _sectionTitle(
                        'Recommended caregivers',
                        subtitle: 'Suggestions based on your saved care requirements.',
                      ),
                      _buildRecommendations(),
                      const SizedBox(height: 20),
                      _sectionTitle('Your saved care details'),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(color: const Color(0xFFE3EBE6)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _detail(
                              'Location',
                              _care['location']?.toString() ?? '',
                            ),
                            _detail(
                              'Care level',
                              _care['care_level']?.toString() ?? '',
                            ),
                            _detail(
                              'Care arrangement',
                              _care['care_arrangement']?.toString() ?? '',
                            ),
                            _detail(
                              'Required services',
                              (_care['required_services'] as List?)?.join(
                                    ', ',
                                  ) ??
                                  '',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Center(
                        child: Text(
                          'MzaziCare • Compassionate care, connected.',
                          style: TextStyle(
                            color: Color(0xFF7A8780),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF758179)),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not provided yet' : value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
