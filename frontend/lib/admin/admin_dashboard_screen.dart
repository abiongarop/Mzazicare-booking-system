import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_screen.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'caregiver_verification_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic> statistics = {};
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await ApiService.getAdminDashboard();

      if (!mounted) return;

      setState(() {
        statistics = result;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
  final shouldLogout = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Log out'),
      content: const Text(
        'Are you sure you want to log out of the admin dashboard?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Log out'),
        ),
      ],
    ),
  );

  if (shouldLogout != true || !mounted) return;

  try {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const AuthScreen(),
      ),
      (route) => false,
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not log out: $e'),
      ),
    );
  }
}

  int number(String key) {
    final value = statistics[key];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void openScreen(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Widget buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade700,
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

  Widget buildManagementTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget buildDashboardContent() {
    return RefreshIndicator(
      onRefresh: loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.75,
            children: [
              buildStatCard(
                title: 'Total caregivers',
                value: '${number('total_caregivers')}',
                icon: Icons.people,
                color: Colors.blue,
              ),
              buildStatCard(
                title: 'Verified caregivers',
                value: '${number('verified_caregivers')}',
                icon: Icons.verified,
                color: Colors.green,
              ),
              buildStatCard(
                title: 'Pending verification',
                value: '${number('pending_caregivers')}',
                icon: Icons.pending_actions,
                color: Colors.orange,
              ),
              buildStatCard(
                title: 'Registered families',
                value: '${number('total_families')}',
                icon: Icons.family_restroom,
                color: Colors.purple,
              ),
              buildStatCard(
                title: 'Total bookings',
                value: '${number('total_bookings')}',
                icon: Icons.calendar_month,
                color: Colors.teal,
              ),
              buildStatCard(
                title: 'Pending bookings',
                value: '${number('pending_bookings')}',
                icon: Icons.hourglass_top,
                color: Colors.deepOrange,
              ),
              buildStatCard(
                title: 'Active bookings',
                value: '${number('active_bookings')}',
                icon: Icons.event_available,
                color: Colors.indigo,
              ),
              buildStatCard(
                title: 'Completed bookings',
                value: '${number('completed_bookings')}',
                icon: Icons.task_alt,
                color: Colors.green,
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Text(
            'Management',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          buildManagementTile(
            title: 'Caregiver management',
            subtitle: 'Review profiles and verify caregivers',
            icon: Icons.medical_services,
            onTap: () => openScreen(
              const CaregiverVerificationScreen(),
            ),
          ),

          buildManagementTile(
            title: 'Family and client management',
            subtitle: 'View registered families and care requirements',
            icon: Icons.family_restroom,
            onTap: () => openScreen(
              const AdminFamiliesScreen(),
            ),
          ),

          buildManagementTile(
            title: 'Booking and schedule management',
            subtitle: 'View bookings and manage their statuses',
            icon: Icons.calendar_month,
            onTap: () => openScreen(
              const AdminBookingsScreen(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: const Text('MzaziCare Admin'),
  actions: [
    IconButton(
      tooltip: 'Refresh dashboard',
      onPressed: isLoading ? null : loadDashboard,
      icon: const Icon(Icons.refresh),
    ),
    TextButton.icon(
      onPressed: _logout,
      icon: const Icon(
        Icons.logout,
        color: Colors.red,
      ),
      label: const Text(
        'Log out',
        style: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    const SizedBox(width: 8),
  ],
),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 45,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: loadDashboard,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : buildDashboardContent(),
    );
  }
}


// ---------------------------------------------------------
// FAMILY MANAGEMENT SCREEN
// ---------------------------------------------------------

class AdminFamiliesScreen extends StatefulWidget {
  const AdminFamiliesScreen({super.key});

  @override
  State<AdminFamiliesScreen> createState() =>
      _AdminFamiliesScreenState();
}

class _AdminFamiliesScreenState extends State<AdminFamiliesScreen> {
  List<Map<String, dynamic>> families = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadFamilies();
  }

  Future<void> loadFamilies() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await ApiService.getAdminFamilies();
      final results = response['families'] as List? ?? [];

      if (!mounted) return;

      setState(() {
        families = results
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Widget familyCard(Map<String, dynamic> family) {
    final name = family['account_name']?.toString() ?? 'Family member';
    final email = family['account_email']?.toString() ?? '';
    final phone = family['contact_phone']?.toString() ??
        family['account_phone']?.toString() ?? '';
    final location = family['location']?.toString() ?? '';
    final age = family['care_recipient_age']?.toString() ?? '';
    final gender = family['care_recipient_gender']?.toString() ?? '';
    final level = family['care_level']?.toString() ?? '';
    final arrangement =
        family['care_arrangement']?.toString() ?? '';

    final services = (family['required_services'] as List? ?? [])
        .map((item) => item.toString())
        .join(', ');

    final skills = (family['required_skills'] as List? ?? [])
        .map((item) => item.toString())
        .join(', ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 7),
      child: ExpansionTile(
        leading: const CircleAvatar(
          child: Icon(Icons.family_restroom),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(email),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (phone.isNotEmpty) _detail('Contact', phone),
          if (location.isNotEmpty) _detail('Location', location),
          if (age.isNotEmpty) _detail('Care recipient age', age),
          if (gender.isNotEmpty) _detail('Gender', gender),
          if (level.isNotEmpty) _detail('Care level', level),
          if (arrangement.isNotEmpty) 
            _detail('Arrangement', arrangement),
          if (services.isNotEmpty) _detail('Required services', services),
          if (skills.isNotEmpty) _detail('Required skills', skills),
          if ((family['notes'] ?? '').toString().isNotEmpty)
            _detail('Notes', family['notes'].toString()),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text('$label: $value'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Management'),
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadFamilies,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : families.isEmpty
                  ? const Center(child: Text('No family profiles found.'))
                  : RefreshIndicator(
                      onRefresh: loadFamilies,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: families.length,
                        itemBuilder: (context, index) =>
                            familyCard(families[index]),
                      ),
                    ),
    );
  }
}


// ---------------------------------------------------------
// BOOKING MANAGEMENT SCREEN
// ---------------------------------------------------------

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() =>
      _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  List<Map<String, dynamic>> schedules = [];
  bool isLoading = true;
  String? errorMessage;
  String selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    loadSchedules();
  }

  Future<void> loadSchedules() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await ApiService.getAdminCareSchedules(
        status: selectedFilter == 'all' ? null : selectedFilter,
      );

      final results = response['schedules'] as List? ?? [];

      if (!mounted) return;

      setState(() {
        schedules = results
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  String displayDate(dynamic value) {
    if (value == null) return 'Not specified';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> changeStatus(
    int scheduleId,
    String newStatus,
  ) async {
    try {
      await ApiService.updateAdminCareScheduleStatus(
        scheduleId,
        status: newStatus,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking status updated.')),
      );

      await loadSchedules();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update booking: $e')),
      );
    }
  }

  Widget bookingCard(Map<String, dynamic> schedule) {
    final id = schedule['id'] as int;
    final status = schedule['status']?.toString() ?? 'pending';
    final family = schedule['family_name']?.toString() ?? 'Family';
    final email = schedule['family_email']?.toString() ?? '';
    final caregiverId =
        schedule['caregiver_id']?.toString() ?? 'Not assigned';

    final start = displayDate(schedule['scheduled_start']);
    final end = displayDate(schedule['scheduled_end']);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 7),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Booking #$id',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            Text('Family: $family'),
            if (email.isNotEmpty) Text('Family email: $email'),
            Text('Caregiver: $caregiverId'),
            Text('Start: $start'),
            Text('End: $end'),
            Text('Status: ${status.replaceAll('_', ' ')}'),
            const SizedBox(height: 12),
            if (status != 'completed' && status != 'cancelled')
              DropdownButtonFormField<String>(
                key: ValueKey('booking-$id-$status'),
                initialValue: status,
                decoration: const InputDecoration(
                  labelText: 'Update booking status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'pending',
                    child: Text('Pending'),
                  ),
                  DropdownMenuItem(
                    value: 'confirmed',
                    child: Text('Confirmed'),
                  ),
                  DropdownMenuItem(
                    value: 'in_progress',
                    child: Text('In progress'),
                  ),
                  DropdownMenuItem(
                    value: 'completed',
                    child: Text('Completed'),
                  ),
                  DropdownMenuItem(
                    value: 'cancelled',
                    child: Text('Cancelled'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null && value != status) {
                    changeStatus(id, value);
                  }
                },
              )
            else
              Text(
                'This booking is $status.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Management'),
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadSchedules,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              initialValue: selectedFilter,
              decoration: const InputDecoration(
                labelText: 'Filter bookings',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All bookings')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
                DropdownMenuItem(value: 'in_progress', child: Text('In progress')),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => selectedFilter = value);
                loadSchedules();
              },
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                    ? Center(child: Text(errorMessage!))
                    : schedules.isEmpty
                        ? const Center(
                            child: Text('No bookings found.'),
                          )
                        : RefreshIndicator(
                            onRefresh: loadSchedules,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: schedules.length,
                              itemBuilder: (context, index) =>
                                  bookingCard(schedules[index]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
