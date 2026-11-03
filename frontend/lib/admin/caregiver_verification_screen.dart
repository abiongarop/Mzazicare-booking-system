

import 'package:flutter/material.dart';

import '../services/api_service.dart';

class CaregiverVerificationScreen extends StatefulWidget {
  const CaregiverVerificationScreen({super.key});

  @override
  State<CaregiverVerificationScreen> createState() =>
      _CaregiverVerificationScreenState();
}

class _CaregiverVerificationScreenState
    extends State<CaregiverVerificationScreen> {
  List<Map<String, dynamic>> caregivers = [];
  bool isLoading = true;
  bool isUpdating = false;
  String filter = 'pending';
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadCaregivers();
  }

  Future<void> loadCaregivers() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await ApiService.getAdminCaregivers(
        verified: filter == 'all'
            ? null
            : filter == 'verified',
      );

      final results = response['caregivers'] as List? ?? [];

      if (!mounted) return;

      setState(() {
        caregivers = results
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

  Future<void> updateVerification(
    int caregiverId,
    bool verified,
  ) async {
    setState(() => isUpdating = true);

    try {
      await ApiService.verifyCaregiver(
        caregiverId,
        verified: verified,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            verified
                ? 'Caregiver verified successfully.'
                : 'Caregiver verification revoked.',
          ),
        ),
      );

      await loadCaregivers();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update caregiver: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isUpdating = false);
      }
    }
  }

  Widget buildCaregiverCard(Map<String, dynamic> caregiver) {
    final int id = caregiver['id'] as int;
    final bool verified = caregiver['is_verified'] == true;

    final name = caregiver['account_name']?.toString().trim();
    final email = caregiver['account_email']?.toString() ?? '';
    final publicId = caregiver['caregiver_id']?.toString() ?? 'N/A';
    final experience =
        caregiver['experience_years']?.toString() ?? '0';
    final location =
        caregiver['location_name']?.toString() ?? '';

    final skills = (caregiver['skills'] as List? ?? [])
        .map((item) => item.toString())
        .join(', ');

    final services = (caregiver['services'] as List? ?? [])
        .map((item) => item.toString())
        .join(', ');

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name == null || name.isEmpty
                            ? 'Caregiver $publicId'
                            : name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        publicId,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  avatar: Icon(
                    verified ? Icons.verified : Icons.pending,
                    size: 16,
                    color: verified ? Colors.green : Colors.orange,
                  ),
                  label: Text(
                    verified ? 'Verified' : 'Pending',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (email.isNotEmpty) Text('Email: $email'),
            if (location.isNotEmpty) Text('Location: $location'),
            Text('Experience: $experience years'),
            if (skills.isNotEmpty) Text('Skills: $skills'),
            if (services.isNotEmpty) Text('Services: $services'),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isUpdating
                    ? null
                    : () => updateVerification(id, !verified),
                icon: Icon(
                  verified ? Icons.cancel_outlined : Icons.verified,
                ),
                label: Text(
                  verified
                      ? 'Revoke verification'
                      : 'Approve caregiver',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      verified ? Colors.red.shade700 : Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
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
        title: const Text('Caregiver Verification'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: isLoading ? null : loadCaregivers,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'pending',
                  label: Text('Pending'),
                  icon: Icon(Icons.pending_actions),
                ),
                ButtonSegment(
                  value: 'verified',
                  label: Text('Verified'),
                  icon: Icon(Icons.verified),
                ),
                ButtonSegment(
                  value: 'all',
                  label: Text('All'),
                  icon: Icon(Icons.people),
                ),
              ],
              selected: {filter},
              onSelectionChanged: (selection) {
                setState(() => filter = selection.first);
                loadCaregivers();
              },
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 42,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                errorMessage!,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: loadCaregivers,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : caregivers.isEmpty
                        ? const Center(
                            child: Text(
                              'No caregivers found in this category.',
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: loadCaregivers,
                            child: ListView.builder(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              itemCount: caregivers.length,
                              itemBuilder: (context, index) {
                                return buildCaregiverCard(
                                  caregivers[index],
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
