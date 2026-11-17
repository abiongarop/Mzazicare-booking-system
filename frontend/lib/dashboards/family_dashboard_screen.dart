import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../onboarding/family_profile_screen.dart';
import '../booking/care_schedule_screen.dart';
import '../messaging/messages_screen.dart';
import '../care_updates/care_updates_screen.dart';
import '../auth/auth_screen.dart';
import '../widgets/shap_explanation_chart.dart';

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
    // Notification state
  int _unreadMessageCount = 0;


  Timer? _notificationTimer;

  bool _notificationInitialized = false;
  bool _notificationCheckInProgress = false;

  final Set<int> _seenNotificationIds = {};

  ThemeData get _theme => Theme.of(context);
  ColorScheme get _colors => _theme.colorScheme;
  bool get _isDark => _theme.brightness == Brightness.dark;

    @override
  void initState() {
    super.initState();

    _loadDashboard();

    // Check notifications immediately after entering the dashboard.
    _refreshNotifications(showInitialPopup: true);

    // Continue checking for new messages while the dashboard is open.
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshNotifications(),
    );
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------
  // FAMILY DASHBOARD TOP BAR
  // ------------------------------------------------------------

    Widget _familyTopBarIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    int badgeCount = 0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor:
              _colors.primaryContainer.withValues(alpha: 0.55),
          foregroundColor: _colors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          fixedSize: const Size(43, 43),
        ),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: 21),
            if (badgeCount > 0)
              Positioned(
                right: -9,
                top: -8,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _colors.error,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _colors.surface,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }


  Widget _familyMenuItem(
    IconData icon,
    String label, {
    Color? color,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: color ?? _colors.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: color ?? _colors.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildFamilyAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: _colors.surface,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            height: 43,
            width: 43,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFC8758D),
                  Color(0xFFA95570),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MzaziCare',
                  style: _theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: _colors.onSurface,
                  ),
                ),
                Text(
                  'Family care centre',
                  style: _theme.textTheme.bodySmall?.copyWith(
                    color: _colors.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        _familyTopBarIcon(
          icon: Icons.calendar_month_outlined,
          tooltip: 'Care schedule',
          onPressed: () => _openPage(
            const CareScheduleScreen(),
          ),
        ),
                _familyTopBarIcon(
          icon: Icons.chat_bubble_outline_rounded,
          tooltip: 'Messages',
          badgeCount: _unreadMessageCount,
          onPressed: () => _openPage(
            const MessagesScreen(),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Refresh dashboard',
          onPressed: _loading ? null : _loadDashboard,
          icon: _loading
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.refresh_rounded),
        ),
        PopupMenuButton<String>(
          tooltip: 'More options',
          icon: CircleAvatar(
            radius: 17,
            backgroundColor: _colors.primaryContainer,
            child: Icon(
              Icons.person_rounded,
              color: _colors.primary,
              size: 20,
            ),
          ),
          onSelected: (value) {
            switch (value) {
              case 'profile':
                _openPage(const FamilyProfileScreen());
                break;
              case 'schedule':
                _openPage(const CareScheduleScreen());
                break;
              case 'messages':
                _openPage(const MessagesScreen());
                break;
              case 'updates':
                _openPage(const CareUpdatesScreen());
                break;
              case 'recommendations':
                _loadDashboard();
                break;
              case 'logout':
                _logout();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'profile',
              child: _familyMenuItem(
                Icons.person_outline_rounded,
                'Family care profile',
              ),
            ),
            PopupMenuItem(
              value: 'schedule',
              child: _familyMenuItem(
                Icons.calendar_month_outlined,
                'Care schedule',
              ),
            ),
            PopupMenuItem(
              value: 'messages',
              child: _familyMenuItem(
                Icons.chat_outlined,
                'Messages',
              ),
            ),
            PopupMenuItem(
              value: 'updates',
              child: _familyMenuItem(
                Icons.notifications_active_outlined,
                'Care updates',
              ),
            ),
            PopupMenuItem(
              value: 'recommendations',
              child: _familyMenuItem(
                Icons.volunteer_activism_outlined,
                'Refresh recommendations',
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: _familyMenuItem(
                Icons.logout_rounded,
                'Log out',
                color: _colors.error,
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
      ],
    );
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
          value['data'] ??
          value['features'] ??
          value['factors'] ??
          value['contributions'] ??
          value['shap_values'] ??
          value['explanation'];

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
          .map((item) {
            if (item is Map) {
              return (item['name'] ?? '').toString();
            }
            return item.toString();
          })
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
  // NOTIFICATIONS
  // ------------------------------------------------------------

  Future<void> _refreshNotifications({
    bool showInitialPopup = false,
  }) async {
    if (_notificationCheckInProgress) return;

    _notificationCheckInProgress = true;

    try {
      final results = await Future.wait([
        ApiService.getNotificationSummary(),
        ApiService.getNotifications(unreadOnly: true),
      ]);

      if (!mounted) return;

      final summary = _toMap(results[0]);
      final notificationsResponse = _toMap(results[1]);

      final notifications = _toList(
        notificationsResponse['notifications'],
      );

      final unreadCount =
          int.tryParse('${summary['unread_message_count']}') ?? 0;



      final unreadMessageNotifications = notifications
          .map(_toMap)
          .where(
            (notification) =>
                notification['notification_type'] == 'new_message',
          )
          .toList();

      final currentIds = unreadMessageNotifications
          .map((notification) => int.tryParse(
                '${notification['id']}',
              ))
          .whereType<int>()
          .toSet();

      final isFirstCheck = !_notificationInitialized;

      final newNotifications = isFirstCheck
          ? <Map<String, dynamic>>[]
          : unreadMessageNotifications.where((notification) {
              final id = int.tryParse('${notification['id']}');
              return id != null && !_seenNotificationIds.contains(id);
            }).toList();

      setState(() {
        _unreadMessageCount = unreadCount;
      });

      _seenNotificationIds.addAll(currentIds);
      _notificationInitialized = true;

      if (isFirstCheck && showInitialPopup && unreadCount > 0) {
        _showMessageNotification(
          unreadCount,
          initial: true,
        );
      } else if (newNotifications.isNotEmpty) {
        _showMessageNotification(
          newNotifications.length,
          initial: false,
        );
      }
    } catch (e) {
      debugPrint('Notification refresh failed: $e');
    } finally {
      _notificationCheckInProgress = false;
    }
  }

  void _showMessageNotification(
    int count, {
    required bool initial,
  }) {
    if (!mounted || count <= 0) return;

    // Play a short system alert for newly received messages.
    if (!initial) {
      SystemSound.play(SystemSoundType.alert);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            Icons.mark_chat_unread_rounded,
            color: _colors.primary,
            size: 34,
          ),
          title: const Text('New messages'),
          content: Text(
            count == 1
                ? 'You have 1 unread message from your care connection.'
                : 'You have $count unread messages from your care connections.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _openPage(const MessagesScreen());
              },
              child: const Text('View messages'),
            ),
          ],
        ),
      );
    });
  }
  // ------------------------------------------------------------
  // LOAD DASHBOARD
  // ------------------------------------------------------------

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        ApiService.getMyProfile(),
        ApiService.getFamilyCareProfile(),
        ApiService.getFamilyRecommendations(),
      ]);

      debugPrint('RECOMMENDATION RESPONSE: ${results[2]}');

      if (!mounted) return;

      setState(() {
        _profile = _toMap(results[0]);
        _careProfile = _toMap(results[1]);
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
      _refreshNotifications();
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'Are you sure you want to log out of MzaziCare?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

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

  Map<String, double> _extractShapValues(dynamic explanation) {
    dynamic rawFactors = explanation;

    if (rawFactors is Map) {
      rawFactors = rawFactors['features'] ??
          rawFactors['factors'] ??
          rawFactors['contributions'] ??
          rawFactors['shap_values'] ??
          rawFactors['explanation'];
    }

    final factors = _toList(rawFactors)
        .map(_toMap)
        .where((factor) => factor.isNotEmpty)
        .toList();

    final values = <String, double>{};

    const labels = {
      'skill_match': 'Skills',
      'service_match': 'Services',
      'availability_match': 'Availability',
      'location_match': 'Location',
      'distance_km': 'Distance',
      'rating': 'Rating',
      'experience_years': 'Experience',
      'care_level_match': 'Care level',
      'gender_match': 'Gender',
    };

    for (final factor in factors) {
      final feature = factor['feature']?.toString() ?? '';

      final rawContribution = factor['contribution'] ??
          factor['shap_value'] ??
          factor['value'];

      final contribution = double.tryParse('$rawContribution');

      if (feature.isEmpty ||
          contribution == null ||
          !contribution.isFinite) {
        continue;
      }

      final impact =
          factor['impact']?.toString().toLowerCase() ?? '';

      double signedValue = contribution;

      if (impact == 'increased') {
        signedValue = contribution.abs();
      } else if (impact == 'decreased') {
        signedValue = -contribution.abs();
      }

      values[labels[feature] ?? feature] = signedValue;
    }

    debugPrint('EXTRACTED SHAP VALUES: $values');

    return values;
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
                ? MzaziCareColors.success
                : _colors.onSurfaceVariant,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              explanation,
              style: _theme.textTheme.bodySmall?.copyWith(
                color: _colors.onSurfaceVariant,
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
      return Text(
        'Detailed recommendation explanations are not available.',
        style: _theme.textTheme.bodySmall?.copyWith(
          color: _colors.onSurfaceVariant,
          height: 1.4,
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
        Divider(
          height: 25,
          color: _colors.outlineVariant,
        ),
        Text(
          'Why this caregiver was recommended',
          style: _theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: _colors.onSurface,
          ),
        ),
        const SizedBox(height: 13),
        if (supportingFactors.isNotEmpty) ...[
          Text(
            'Factors supporting the recommendation',
            style: _theme.textTheme.bodySmall?.copyWith(
              color: _colors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 9),
          ...supportingFactors.map(
            (factor) => _explanationItem(
              explanation: _humanReadableFactor(factor),
              positive: true,
            ),
          ),
        ] else
          Text(
            'No factors positively influenced this recommendation.',
            style: _theme.textTheme.bodySmall?.copyWith(
              color: _colors.onSurfaceVariant,
            ),
          ),
        if (factorsToReview.isNotEmpty) ...[
          const SizedBox(height: 9),
          Text(
            'Areas to review',
            style: _theme.textTheme.bodySmall?.copyWith(
              color: _colors.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 9),
          ...factorsToReview.map(
            (factor) => _explanationItem(
              explanation: _humanReadableFactor(factor),
              positive: false,
            ),
          ),
        ],
      ],
    );
  }

  // ------------------------------------------------------------
  // DASHBOARD HEADER
  // ------------------------------------------------------------

  Widget _dashboardHeader(String name) {
    final gradientColors = _isDark
        ? const [
            Color(0xFF493541),
            Color(0xFF30232D),
            Color(0xFF251D27),
          ]
        : const [
            Color(0xFFC8758D),
            Color(0xFFA95570),
            Color(0xFF593847),
          ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA95570).withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              right: -55,
              top: -65,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              right: 65,
              bottom: -100,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.055),
                ),
              ),
            ),
            Positioned(
              right: 24,
              top: 115,
              child: Icon(
                Icons.favorite_rounded,
                size: 95,
                color: Colors.white.withValues(alpha: 0.055),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.17),
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Colors.white,
                          size: 29,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MZAZICARE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 2,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Family care dashboard',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shield_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Care & trust',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'YOUR FAMILY CARE JOURNEY',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.76),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Hello, $name!',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Because your loved one deserves the best care. '
                    'Find trusted caregivers, coordinate visits and '
                    'stay connected every step of the way.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      height: 1.65,
                    ),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 51,
                    child: FilledButton.icon(
                      onPressed: () => _openPage(
                        const FamilyProfileScreen(),
                      ),
                      icon: const Icon(
                        Icons.edit_note_rounded,
                        size: 21,
                      ),
                      label: const Text(
                        'Manage care profile',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFA95570),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.favorite_border_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                        SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            'Care that connects families and caregivers.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white70,
                          size: 19,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
                  color: _colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: _colors.primary,
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
                      style: _theme.textTheme.titleMedium?.copyWith(
                        color: _colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: _theme.textTheme.bodySmall?.copyWith(
                        color: _colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _colors.primary,
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
                Icon(
                  Icons.elderly_rounded,
                  color: _colors.primary,
                  size: 25,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Care details',
                    style: _theme.textTheme.titleMedium,
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
            Divider(color: _colors.outlineVariant, height: 24),
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
            color: _colors.primary,
          ),
          const SizedBox(width: 11),
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: _theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: _colors.onSurface,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: _theme.textTheme.bodyMedium?.copyWith(
                color: _colors.onSurfaceVariant,
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
        color: _colors.secondaryContainer,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: _colors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: _theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: _colors.onSecondaryContainer,
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

    final name = _value(
      caregiver['full_name'] ??
          caregiver['name'] ??
          caregiver['caregiver_name'],
      fallback: 'Caregiver $caregiverId',
    );

    final experience = caregiver['experience_years'];
    final rating = caregiver['rating'];
    final availability = caregiver['availability'];

    final location = _formatLocation(caregiver['location']);

    final isVerified = caregiver['is_verified'] == true;
    final rank = caregiver['recommendation_rank'];
    final score = caregiver['suitability_score'];

    final services = _stringList(caregiver['matching_services']);
    final skills = _stringList(caregiver['matching_skills']);

    final explanation = caregiver['explanation'];
    final shapValues = _extractShapValues(explanation);

    final whyRecommended =
        caregiver['why_recommended']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor: _colors.secondaryContainer,
                  child: Icon(
                    Icons.person_rounded,
                    color: _colors.primary,
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
                        style: _theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Caregiver ID: $caregiverId',
                        style: _theme.textTheme.bodySmall?.copyWith(
                          color: _colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      if (databaseId != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Database ID: $databaseId',
                          style: _theme.textTheme.bodySmall?.copyWith(
                            color: _colors.onSurfaceVariant,
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
                      color: _colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 15,
                          color: _colors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: _theme.textTheme.labelSmall?.copyWith(
                            color: _colors.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
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
            _recommendationDetail(
              Icons.location_on_outlined,
              'Location',
              location,
            ),
            const SizedBox(height: 11),
            _recommendationDetail(
              Icons.medical_services_outlined,
              'Matching services',
              services.isEmpty
                  ? 'No matching services were returned by the recommendation API.'
                  : services.join(', '),
            ),
            const SizedBox(height: 11),
            _recommendationDetail(
              Icons.psychology_outlined,
              'Matching skills',
              skills.isEmpty
                  ? 'No matching skills were returned by the recommendation API.'
                  : skills.join(', '),
            ),
            _explanationSection(explanation),
            if (shapValues.isNotEmpty) ...[
              const SizedBox(height: 12),
              ShapExplanationChart(
                shapValues: shapValues,
              ),
            ],
            if (whyRecommended != null &&
                whyRecommended.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: _colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  whyRecommended,
                  style: _theme.textTheme.bodySmall?.copyWith(
                    color: _colors.onSecondaryContainer,
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
          color: _colors.primary,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: _theme.textTheme.bodySmall?.copyWith(
                  color: _colors.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: _theme.textTheme.bodySmall?.copyWith(
                  color: _colors.onSurfaceVariant,
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
                  Icon(
                    Icons.volunteer_activism_outlined,
                    size: 38,
                    color: _colors.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No recommendations available yet',
                    style: _theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Complete your care profile so MzaziCare can identify caregivers whose services and skills match your needs.',
                    textAlign: TextAlign.center,
                    style: _theme.textTheme.bodyMedium?.copyWith(
                      color: _colors.onSurfaceVariant,
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
          subtitle: 'Manage your loved one’s care requirements.',
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
        Text(
          'MzaziCare • Caring connects us.',
          textAlign: TextAlign.center,
          style: _theme.textTheme.bodySmall?.copyWith(
            color: _colors.onSurfaceVariant,
            fontSize: 12,
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
      backgroundColor: _theme.scaffoldBackgroundColor,
      appBar: _buildFamilyAppBar(),
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
                        Icon(
                          Icons.cloud_off_outlined,
                          size: 42,
                          color: _colors.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Unable to load your dashboard.',
                          style: _theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: _theme.textTheme.bodyMedium?.copyWith(
                            color: _colors.onSurfaceVariant,
                          ),
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
