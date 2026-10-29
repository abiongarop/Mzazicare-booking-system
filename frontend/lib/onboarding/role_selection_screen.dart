
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'family_profile_screen.dart';
import 'caregiver_profile_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? selectedRole;
  bool isLoading = false;

  Future<void> continueToProfile() async {
    if (selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select how you want to use MzaziCare.'),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await ApiService.updateMyProfile(role: selectedRole!);

      if (!mounted) return;

      if (selectedRole == 'client') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const FamilyProfileScreen(),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CaregiverProfileScreen(),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save your role: $e'),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Choose Your Role'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF174A45),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.health_and_safety,
                  size: 64,
                  color: Color(0xFF16877A),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Welcome to MzaziCare',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF174A45),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'How would you like to use our elderly home-care platform?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 28),

                _buildRoleCard(
                  role: 'client',
                  title: 'Family / Client',
                  description:
                      'Find suitable caregivers for an elderly family member.',
                  icon: Icons.family_restroom,
                ),

                const SizedBox(height: 16),

                _buildRoleCard(
                  role: 'caregiver',
                  title: 'Caregiver',
                  description:
                      'Create a professional profile and offer home-care services.',
                  icon: Icons.volunteer_activism,
                ),

                const SizedBox(height: 28),

                ElevatedButton(
                  onPressed: isLoading ? null : continueToProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16877A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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

  Widget _buildRoleCard({
    required String role,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = selectedRole == role;

    return Card(
      elevation: isSelected ? 3 : 1,
      color: isSelected
          ? const Color(0xFFE5F4F0)
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected
              ? const Color(0xFF16877A)
              : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => selectedRole = role),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                icon,
                size: 38,
                color: const Color(0xFF16877A),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(description),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF16877A),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
