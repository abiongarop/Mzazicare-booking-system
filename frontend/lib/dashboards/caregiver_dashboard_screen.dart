
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../onboarding/caregiver_profile_screen.dart';
import '../auth/auth_screen.dart';
import '../booking/caregiver_schedule_screen.dart';
import '../care_updates/care_journal_screen.dart';
import '../messaging/messages_screen.dart';
import '../messaging/chat_screen.dart';

class CaregiverDashboardScreen extends StatefulWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  State<CaregiverDashboardScreen> createState() =>
      _CaregiverDashboardScreenState();
}

class _CaregiverDashboardScreenState
    extends State<CaregiverDashboardScreen> {
  bool _loading = true;
  bool _loadingBookings = false;
  String? _error;

  Map<String, dynamic> _profile = {};
  List<Map<String, dynamic>> _bookings = [];
  final Set<int> _processingBookings = {};

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  List<Map<String, dynamic>> _extractList(dynamic response) {
    if (response is List) {
      return response.map(_toMap).toList();
    }

    if (response is Map) {
      final data = response['results'] ??
          response['bookings'] ??
          response['care_schedules'] ??
          response['data'];

      if (data is List) {
        return data.map(_toMap).toList();
      }
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

  String _profileValue(
    List<String> keys, {
    String fallback = 'Not provided',
  }) {
    for (final key in keys) {
      final value = _profile[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getMyProfile(),
        ApiService.getCareSchedules(),
      ]);

      if (!mounted) return;

      setState(() {
        _profile = _toMap(results[0]);
        _bookings = _extractList(results[1]);
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

  Future<void> _refreshBookings() async {
    if (_loadingBookings) return;

    setState(() => _loadingBookings = true);

    try {
      final response = await ApiService.getCareSchedules();

      if (!mounted) return;

      setState(() {
        _bookings = _extractList(response);
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not refresh bookings: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingBookings = false);
      }
    }
  }

  bool get _isVerified {
    final value = _profile['is_verified'] ??
        _profile['verified'] ??
        _profile['verification_status'];

    if (value is bool) return value;

    return value?.toString().toLowerCase() == 'verified' ||
        value?.toString().toLowerCase() == 'true';
  }

  List<Map<String, dynamic>> get _pendingBookings {
    return _bookings.where((booking) {
      return booking['status']?.toString().toLowerCase() == 'pending';
    }).toList();
  }

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CaregiverProfileScreen(),
      ),
    );

    if (mounted) _loadDashboard();
  }

  Future<void> _openSchedule({
    required bool assignments,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CaregiverScheduleScreen(
          showAssignments: assignments,
        ),
      ),
    );

    if (mounted) _refreshBookings();
  }

  Future<void> _openJournal() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CareJournalScreen(),
      ),
    );
  }

  Future<void> _openMessages() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MessagesScreen(),
      ),
    );

    if (mounted) _refreshBookings();
  }

  Future<void> _openBookingChat(
    Map<String, dynamic> booking,
  ) async {
    final rawId = booking['conversation_id'];

    final conversationId = int.tryParse(
      rawId?.toString() ?? '',
    );

    if (conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No conversation is linked to this booking yet. '
            'Refresh the booking or open Messages.',
          ),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversationId,
          caregiverId: 'Family',
        ),
      ),
    );

    if (mounted) _refreshBookings();
  }

  Future<void> _makeBookingDecision(
    Map<String, dynamic> booking,
    String decision,
  ) async {
    final scheduleId = int.tryParse(
      booking['id']?.toString() ?? '',
    );

    if (scheduleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid booking ID.'),
        ),
      );
      return;
    }

    if (_processingBookings.contains(scheduleId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          decision == 'accept'
              ? 'Accept booking?'
              : 'Decline booking?',
        ),
        content: Text(
          decision == 'accept'
              ? 'Do you want to accept this care booking? '
                  'The family will be notified.'
              : 'Are you sure you want to decline this booking? '
                  'The family will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: Text(
              decision == 'accept' ? 'Accept' : 'Decline',
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _processingBookings.add(scheduleId);
    });

    try {
      await ApiService.decideCareSchedule(
        scheduleId,
        decision: decision,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'accept'
                ? 'Booking accepted successfully.'
                : 'Booking declined successfully.',
          ),
        ),
      );

      await _refreshBookings();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking decision failed: $e'),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingBookings.remove(scheduleId);
        });
      }
    }
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');

    if (date == null) return 'Not provided';

    final local = date.toLocal();

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '${local.day} ${months[local.month - 1]} '
        '${local.year}, $hour:$minute $period';
  }

  String _formatServices(dynamic value) {
    if (value is List) {
      if (value.isEmpty) return 'No services specified';

      return value.map((item) {
        if (item is Map) {
          return item['name']?.toString() ??
              item['id']?.toString() ??
              item.toString();
        }
        return item.toString();
      }).join(', ');
    }

    return _value(value, fallback: 'No services specified');
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending response';
      case 'confirmed':
        return 'Accepted';
      case 'declined':
        return 'Declined';
      case 'in_progress':
        return 'In progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
      case 'completed':
        return Colors.green;
      case 'declined':
      case 'cancelled':
        return Colors.red;
      case 'in_progress':
        return MzaziCareColors.primaryDark;
      default:
        return MzaziCareColors.textMuted;
    }
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  void _showBookingDetails(Map<String, dynamic> booking) {
    final status = booking['status']?.toString() ?? 'pending';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MzaziCareColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: MzaziCareColors.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Booking details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: MzaziCareColors.text,
                          ),
                        ),
                      ),
                      _statusChip(status),
                    ],
                  ),
                  const SizedBox(height: 17),
                  _detail(
                    'Booking reference',
                    '#${booking['id'] ?? 'Unavailable'}',
                  ),
                  _detail(
                    'Family profile',
                    _value(
                      booking['family_name'] ??
                          booking['family_profile_id'],
                    ),
                  ),
                  _detail(
                    'Start',
                    _formatDate(booking['scheduled_start']),
                  ),
                  _detail(
                    'End',
                    _formatDate(booking['scheduled_end']),
                  ),
                  _detail(
                    'Arrangement',
                    _value(booking['arrangement']),
                  ),
                  _detail(
                    'Services',
                    _formatServices(booking['services']),
                  ),
                  _detail(
                    'Family notes',
                    _value(
                      booking['family_notes'],
                      fallback: 'No additional notes.',
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _openBookingChat(booking);
                      },
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('Message the family'),
                    ),
                  ),
                  if (status == 'pending') ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _processingBookings.contains(
                              int.tryParse(
                                booking['id']?.toString() ?? '',
                              ),
                            )
                                ? null
                                : () {
                                    Navigator.pop(sheetContext);
                                    _makeBookingDecision(
                                      booking,
                                      'decline',
                                    );
                                  },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                            child: const Text('Decline'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _makeBookingDecision(
                                booking,
                                'accept',
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  MzaziCareColors.primary,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                            child: const Text('Accept booking'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: MzaziCareColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: MzaziCareColors.text,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingCard(Map<String, dynamic> booking) {
    final status = booking['status']?.toString() ?? 'pending';
    final id = int.tryParse(booking['id']?.toString() ?? '');
    final processing =
        id != null && _processingBookings.contains(id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: () => _showBookingDetails(booking),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    color: MzaziCareColors.primaryDark,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Booking #${booking['id'] ?? ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: MzaziCareColors.text,
                      ),
                    ),
                  ),
                  _statusChip(status),
                ],
              ),
              const SizedBox(height: 12),
              _compactDetail(
                Icons.access_time,
                _formatDate(booking['scheduled_start']),
              ),
              _compactDetail(
                Icons.medical_services_outlined,
                _formatServices(booking['services']),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'View booking details',
                    style: TextStyle(
                      color: MzaziCareColors.primaryDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(width: 5),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: MzaziCareColors.primaryDark,
                  ),
                ],
              ),
              if (status == 'pending') ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: processing
                            ? null
                            : () => _makeBookingDecision(
                                  booking,
                                  'decline',
                                ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: processing
                            ? null
                            : () => _makeBookingDecision(
                                  booking,
                                  'accept',
                                ),
                        style: FilledButton.styleFrom(
                          backgroundColor: MzaziCareColors.primary,
                        ),
                        child: processing
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _compactDetail(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 17,
            color: MzaziCareColors.primaryDark,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: MzaziCareColors.textMuted,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: MzaziSectionHeader(
                title: 'Booking requests',
                subtitle:
                    'Review requests from families and respond to them.',
              ),
            ),
            IconButton(
              onPressed: _loadingBookings ? null : _refreshBookings,
              icon: _loadingBookings
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_pendingBookings.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  const Icon(
                    Icons.event_available_outlined,
                    size: 40,
                    color: MzaziCareColors.primaryDark,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No pending booking requests',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: MzaziCareColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'New booking requests from families will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: MzaziCareColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._pendingBookings.map(_bookingCard),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _openSchedule(assignments: true),
          icon: const Icon(Icons.calendar_month_outlined),
          label: const Text('View all bookings and assignments'),
        ),
      ],
    );
  }

  Widget _header() {
    final name = _profileValue(
      ['full_name', 'name', 'display_name'],
      fallback: 'Caregiver',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            MzaziCareColors.primaryDark,
            MzaziCareColors.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 27,
                backgroundColor: Colors.white24,
                child: Icon(
                  Icons.volunteer_activism_outlined,
                  color: Colors.white,
                  size: 29,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isVerified
                          ? Icons.verified
                          : Icons.pending_outlined,
                      size: 15,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isVerified ? 'Verified' : 'Verification pending',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Welcome back,',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'Manage your care visits, assignments and communication with families.',
            style: TextStyle(
              color: Colors.white,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspaceCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 13),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(
                height: 49,
                width: 49,
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: MzaziCareColors.text,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        color: MzaziCareColors.textMuted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: MzaziCareColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  color: MzaziCareColors.primaryDark,
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Professional profile',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: MzaziCareColors.text,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _openProfile,
                  child: const Text('Edit'),
                ),
              ],
            ),
            const Divider(),
            _profileRow('Location', _profileValue(['location'])),
            _profileRow(
              'Experience',
              '${_profileValue(['experience_years'], fallback: '0')} years',
            ),
            _profileRow(
              'Availability',
              _profileValue(['availability']),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                color: MzaziCareColors.textMuted,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: MzaziCareColors.text,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 38,
              color: MzaziCareColors.primaryDark,
            ),
            const SizedBox(height: 10),
            const Text('Could not load your dashboard.'),
            const SizedBox(height: 12),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadDashboard,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
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
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MzaziCareColors.background,
      appBar: AppBar(
        title: const Text('Caregiver Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadDashboard,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ListView(
                  padding: const EdgeInsets.all(20),
                  children: [_errorView()],
                )
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 15, 20, 35),
                    children: [
                      _header(),
                      const SizedBox(height: 24),

                      _bookingRequestsSection(),

                      const SizedBox(height: 24),
                      const MzaziSectionHeader(
                        title: 'Your workspace',
                        subtitle:
                            'Manage your daily caregiving activities.',
                      ),
                      const SizedBox(height: 13),

                      _workspaceCard(
                        icon: Icons.calendar_month_outlined,
                        title: 'My Schedule',
                        description:
                            'View your upcoming and completed care visits.',
                        onTap: () => _openSchedule(assignments: false),
                      ),
                      _workspaceCard(
                        icon: Icons.assignment_ind_outlined,
                        title: 'Care Assignments',
                        description:
                            'Review families and clients assigned to you.',
                        onTap: () => _openSchedule(assignments: true),
                      ),
                      _workspaceCard(
                        icon: Icons.menu_book_outlined,
                        title: 'Care Journal',
                        description:
                            'Record visit summaries, activities and follow-ups.',
                        onTap: _openJournal,
                      ),
                      _workspaceCard(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'Messages',
                        description:
                            'Communicate with families about care arrangements.',
                        onTap: _openMessages,
                      ),

                      const SizedBox(height: 15),
                      const MzaziSectionHeader(
                        title: 'Your professional details',
                        subtitle:
                            'Keep your profile and qualifications up to date.',
                      ),
                      const SizedBox(height: 12),
                      _profileSummary(),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _openProfile,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Manage professional profile'),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Earnings and payment tracking will be available here once payment records are connected.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: MzaziCareColors.textMuted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
