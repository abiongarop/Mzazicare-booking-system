import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Map<String, dynamic> _caregiverProfile = {};
  List<Map<String, dynamic>> _bookings = [];

  final Set<int> _processingBookings = {};

  // ------------------------------------------------------------
  // NOTIFICATION STATE
  // ------------------------------------------------------------

  int _unreadMessageCount = 0;

  Timer? _notificationTimer;

  bool _notificationInitialized = false;
  bool _notificationCheckInProgress = false;

  final Set<int> _seenNotificationIds = {};

  ColorScheme get _colors => Theme.of(context).colorScheme;
  TextTheme get _textTheme => Theme.of(context).textTheme;

  @override
  void initState() {
    super.initState();

    _loadDashboard();
    _refreshNotifications(showInitialPopup: true);

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
  // DATA CONVERSION HELPERS
  // ------------------------------------------------------------

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

  List<Map<String, dynamic>> _extractNotifications(dynamic response) {
    if (response is List) {
      return response.map(_toMap).toList();
    }

    if (response is Map) {
      final data = response['notifications'] ??
          response['results'] ??
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
        ApiService.getCareSchedules(),
      ]);

      if (!mounted) return;

      final summary = _toMap(results[0]);
      final notifications = _extractNotifications(results[1]);
      final latestBookings = _extractList(results[2]);

      final unreadCount =
          int.tryParse('${summary['unread_message_count']}') ?? 0;

      final pendingBookingCount = latestBookings.where((booking) {
        return booking['status']?.toString().toLowerCase() == 'pending';
      }).length;

      final relevantNotifications = notifications.where((notification) {
        final type = notification['notification_type']?.toString();

        return type == 'new_booking' || type == 'new_message';
      }).toList();

      final currentIds = relevantNotifications
          .map((notification) {
            return int.tryParse('${notification['id']}');
          })
          .whereType<int>()
          .toSet();

      final isFirstCheck = !_notificationInitialized;

      final newNotifications = isFirstCheck
          ? <Map<String, dynamic>>[]
          : relevantNotifications.where((notification) {
              final id = int.tryParse('${notification['id']}');

              return id != null && !_seenNotificationIds.contains(id);
            }).toList();

      final newBookingCount = newNotifications.where((notification) {
        return notification['notification_type'] == 'new_booking';
      }).length;

      final newMessageCount = newNotifications.where((notification) {
        return notification['notification_type'] == 'new_message';
      }).length;

      setState(() {
        _bookings = latestBookings;
        _unreadMessageCount = unreadCount;
      });

      _seenNotificationIds.addAll(currentIds);
      _notificationInitialized = true;

      if (isFirstCheck && showInitialPopup) {
        if (pendingBookingCount > 0 || unreadCount > 0) {
          _showNotificationDialog(
            bookingCount: pendingBookingCount,
            messageCount: unreadCount,
            initial: true,
          );
        }
      } else if (newBookingCount > 0 || newMessageCount > 0) {
        _showNotificationDialog(
          bookingCount: newBookingCount,
          messageCount: newMessageCount,
          initial: false,
        );
      }
    } catch (e) {
      debugPrint('Notification refresh failed: $e');
    } finally {
      _notificationCheckInProgress = false;
    }
  }

  void _showNotificationDialog({
    required int bookingCount,
    required int messageCount,
    required bool initial,
  }) {
    if (!mounted || (bookingCount <= 0 && messageCount <= 0)) {
      return;
    }

    if (!initial) {
      SystemSound.play(SystemSoundType.alert);
    }

    final hasBookings = bookingCount > 0;
    final hasMessages = messageCount > 0;

    String content;

    if (hasBookings && hasMessages) {
      content =
          'You have $bookingCount new or pending booking request(s) '
          'and $messageCount unread message(s).';
    } else if (hasBookings) {
      content = bookingCount == 1
          ? 'You have 1 pending booking request from a family.'
          : 'You have $bookingCount pending booking requests from families.';
    } else {
      content = messageCount == 1
          ? 'You have 1 unread message from a family.'
          : 'You have $messageCount unread messages from families.';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            hasBookings
                ? Icons.notifications_active_rounded
                : Icons.mark_chat_unread_rounded,
            color: _colors.primary,
            size: 36,
          ),
          title: Text(
            hasBookings && hasMessages
                ? 'New activity'
                : hasBookings
                    ? 'Booking request'
                    : 'New messages',
          ),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Later'),
            ),
            if (hasMessages)
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _openMessages();
                },
                child: const Text('View messages'),
              ),
            if (hasBookings)
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _openSchedule(assignments: true);
                },
                child: const Text('View bookings'),
              ),
          ],
        ),
      );
    });
  }

  // ------------------------------------------------------------
  // CAREGIVER DASHBOARD TOP BAR
  // ------------------------------------------------------------

  Widget _topBarIcon({
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
          backgroundColor: _colors.primaryContainer.withValues(alpha: 0.55),
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

  PreferredSizeWidget _buildDashboardAppBar() {
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
              Icons.volunteer_activism_rounded,
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
                  style: _textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: _colors.onSurface,
                  ),
                ),
                Text(
                  'Caregiver workspace',
                  style: _textTheme.bodySmall?.copyWith(
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
        _topBarIcon(
          icon: Icons.calendar_month_outlined,
          tooltip: 'My schedule',
          onPressed: () => _openSchedule(assignments: false),
        ),
        _topBarIcon(
          icon: Icons.chat_bubble_outline_rounded,
          tooltip: 'Messages',
          badgeCount: _unreadMessageCount,
          onPressed: _openMessages,
        ),
        _topBarIcon(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Pending booking requests',
          badgeCount: _pendingBookings.length,
          onPressed: () => _openSchedule(assignments: true),
        ),
        const SizedBox(width: 5),
        IconButton(
          tooltip: 'Refresh dashboard',
          onPressed: _loading ? null : _loadDashboard,
          icon: _loading
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(strokeWidth: 2),
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
                _openProfile();
                break;
              case 'assignments':
                _openSchedule(assignments: true);
                break;
              case 'journal':
                _openJournal();
                break;
              case 'messages':
                _openMessages();
                break;
              case 'logout':
                _logout();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'profile',
              child: _menuItem(
                Icons.person_outline,
                'Professional profile',
              ),
            ),
            PopupMenuItem(
              value: 'assignments',
              child: _menuItem(
                Icons.assignment_outlined,
                'Care assignments',
              ),
            ),
            PopupMenuItem(
              value: 'journal',
              child: _menuItem(
                Icons.menu_book_outlined,
                'Care journal',
              ),
            ),
            PopupMenuItem(
              value: 'messages',
              child: _menuItem(
                Icons.chat_outlined,
                'Messages',
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: _menuItem(
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

  Widget _menuItem(
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

  // ------------------------------------------------------------
  // LOAD DASHBOARD
  // ------------------------------------------------------------

  Future<void> _loadDashboard() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getMyProfile(),
        ApiService.getCaregiverProfile(),
        ApiService.getCareSchedules(),
      ]);

      if (!mounted) return;

      setState(() {
        _profile = _toMap(results[0]);
        _caregiverProfile = _toMap(results[1]);
        _bookings = _extractList(results[2]);
        _loading = false;
      });

      debugPrint(
        'Caregiver experience from API: '
        '${_caregiverProfile['experience_years']}',
      );
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

  // ------------------------------------------------------------
  // NAVIGATION
  // ------------------------------------------------------------

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CaregiverProfileScreen(),
      ),
    );

    if (mounted) {
      await _loadDashboard();
      _refreshNotifications();
    }
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

    if (mounted) {
      await _refreshBookings();
      _refreshNotifications();
    }
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

    if (mounted) {
      _refreshNotifications();
    }
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

    if (mounted) {
      _refreshNotifications();
    }
  }

  // ------------------------------------------------------------
  // BOOKING DECISIONS
  // ------------------------------------------------------------

  Future<void> _makeBookingDecision(
    Map<String, dynamic> booking,
    String decision,
  ) async {
    final scheduleId = int.tryParse(
      booking['id']?.toString() ?? '',
    );

    if (scheduleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid booking ID.')),
      );
      return;
    }

    if (_processingBookings.contains(scheduleId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          decision == 'accept' ? 'Accept booking?' : 'Decline booking?',
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
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(decision == 'accept' ? 'Accept' : 'Decline'),
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
      _refreshNotifications();
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

  // ------------------------------------------------------------
  // BOOKING DISPLAY HELPERS
  // ------------------------------------------------------------

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
        return _colors.error;
      case 'in_progress':
        return _colors.primary;
      default:
        return _colors.onSurfaceVariant;
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
        color: color.withValues(alpha: 0.12),
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

  // ------------------------------------------------------------
  // BOOKING DETAILS
  // ------------------------------------------------------------

  void _showBookingDetails(Map<String, dynamic> booking) {
    final status = booking['status']?.toString() ?? 'pending';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _colors.surface,
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
                        color: _colors.outlineVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Booking details',
                          style: _textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _colors.onSurface,
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
                              foregroundColor: _colors.error,
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
                              backgroundColor: _colors.primary,
                              foregroundColor: _colors.onPrimary,
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
            style: _textTheme.bodySmall?.copyWith(
              color: _colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: _textTheme.bodyMedium?.copyWith(
              color: _colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // BOOKING CARDS
  // ------------------------------------------------------------

  Widget _bookingCard(Map<String, dynamic> booking) {
    final status = booking['status']?.toString() ?? 'pending';
    final id = int.tryParse(booking['id']?.toString() ?? '');
    final processing = id != null && _processingBookings.contains(id);

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
                  Icon(
                    Icons.calendar_month_outlined,
                    color: _colors.primary,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Booking #${booking['id'] ?? ''}',
                      style: _textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _colors.onSurface,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'View booking details',
                    style: TextStyle(
                      color: _colors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: _colors.primary,
                  ),
                ],
              ),
              if (status == 'pending') ...[
                Divider(
                  height: 24,
                  color: _colors.outlineVariant,
                ),
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
                          foregroundColor: _colors.error,
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
                          backgroundColor: _colors.primary,
                          foregroundColor: _colors.onPrimary,
                        ),
                        child: processing
                            ? SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _colors.onPrimary,
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
            color: _colors.primary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: _textTheme.bodySmall?.copyWith(
                color: _colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // BOOKING REQUESTS SECTION
  // ------------------------------------------------------------

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
                  Icon(
                    Icons.event_available_outlined,
                    size: 40,
                    color: _colors.primary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No pending booking requests',
                    style: _textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'New booking requests from families will appear here.',
                    textAlign: TextAlign.center,
                    style: _textTheme.bodySmall?.copyWith(
                      color: _colors.onSurfaceVariant,
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

  // ------------------------------------------------------------
  // CAREGIVER HEADER
  // ------------------------------------------------------------

  Widget _header() {
    final name = _profileValue(
      ['full_name', 'name', 'display_name'],
      fallback: 'Caregiver',
    );

    final location = _value(
      _caregiverProfile['location'],
      fallback: 'Location not added',
    );

    final experience =
        _caregiverProfile['experience_years']?.toString() ?? '0';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFC8758D),
            Color(0xFFA95570),
            Color(0xFF593847),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA95570).withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              right: -45,
              top: -55,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              right: 45,
              bottom: -85,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
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
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.17),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: const Icon(
                          Icons.volunteer_activism_rounded,
                          color: Colors.white,
                          size: 29,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isVerified
                                  ? Icons.verified_rounded
                                  : Icons.pending_outlined,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isVerified
                                  ? 'Verified caregiver'
                                  : 'Verification pending',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 27),
                  Text(
                    'WELCOME BACK',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 29,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'Your compassion makes a difference. '
                    'Manage your care visits and stay connected '
                    'with the families you support.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _headerInfo(
                            Icons.location_on_outlined,
                            'LOCATION',
                            location,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 38,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _headerInfo(
                            Icons.workspace_premium_outlined,
                            'EXPERIENCE',
                            '$experience years',
                          ),
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

  Widget _headerInfo(
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.9),
          size: 21,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // WORKSPACE CARDS
  // ------------------------------------------------------------

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
                  color: _colors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: _colors.onPrimaryContainer,
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
                      style: _textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: _textTheme.bodySmall?.copyWith(
                        color: _colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: _colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // PROFESSIONAL PROFILE
  // ------------------------------------------------------------


String _profileListValue(dynamic value) {
  if (value is List && value.isNotEmpty) {
    return value
        .map((item) => item is Map ? item['name'] : item)
        .where((item) => item != null && item.toString().trim().isNotEmpty)
        .join(', ');
  }

  return 'Not provided';
}

Widget _profileSummary() {
  final rating = _caregiverProfile['rating'];
  final isVerified = _caregiverProfile['is_verified'] == true;

  return Card(
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: _colors.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Professional profile',
                  style: _textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _colors.onSurface,
                  ),
                ),
              ),
              TextButton(
                onPressed: _openProfile,
                child: const Text('Edit'),
              ),
            ],
          ),
          Divider(color: _colors.outlineVariant),

          _profileRow(
            'Gender',
            _value(_caregiverProfile['gender']),
          ),
          _profileRow(
            'Location',
            _value(_caregiverProfile['location']),
          ),
          _profileRow(
            'Age',
            '${_caregiverProfile['age'] ?? 'Not provided'} years',
          ),
          _profileRow(
            'Experience',
            '${_caregiverProfile['experience_years'] ?? 'Not provided'} years',
          ),
          _profileRow(
            'Qualifications',
            _value(_caregiverProfile['qualifications']),
          ),
          _profileRow(
            'Availability',
            _value(_caregiverProfile['availability']),
          ),
          _profileRow(
            'Services',
            _profileListValue(_caregiverProfile['services']),
          ),
          _profileRow(
            'Skills',
            _profileListValue(_caregiverProfile['skills']),
          ),
          _profileRow(
            'Rating',
            rating == null ? 'Not rated yet' : '$rating / 5',
          ),
          _profileRow(
            'Verification',
            isVerified ? 'Verified' : 'Pending verification',
          ),

          const SizedBox(height: 12),
          Text(
            'About me',
            style: _textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: _colors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _value(_caregiverProfile['bio']),
            style: _textTheme.bodySmall?.copyWith(
              color: _colors.onSurfaceVariant,
              height: 1.5,
            ),
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
              style: _textTheme.bodySmall?.copyWith(
                color: _colors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: _textTheme.bodySmall?.copyWith(
                color: _colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // ERROR VIEW
  // ------------------------------------------------------------

  Widget _errorView() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 38,
              color: _colors.primary,
            ),
            const SizedBox(height: 10),
            Text(
              'Could not load your dashboard.',
              style: _textTheme.titleSmall?.copyWith(
                color: _colors.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: _textTheme.bodySmall?.copyWith(
                color: _colors.onSurfaceVariant,
              ),
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

  // ------------------------------------------------------------
  // LOGOUT
  // ------------------------------------------------------------

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

    _notificationTimer?.cancel();

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
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildDashboardAppBar(),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _errorView(),
                  ],
                )
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      15,
                      20,
                      35,
                    ),
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
                        onTap: () => _openSchedule(
                          assignments: false,
                        ),
                      ),
                      _workspaceCard(
                        icon: Icons.assignment_ind_outlined,
                        title: 'Care Assignments',
                        description:
                            'Review families and clients assigned to you.',
                        onTap: () => _openSchedule(
                          assignments: true,
                        ),
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
                        label: const Text(
                          'Manage professional profile',
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Earnings and payment tracking will be available here once payment records are connected.',
                        textAlign: TextAlign.center,
                        style: _textTheme.bodySmall?.copyWith(
                          color: _colors.onSurfaceVariant,
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
