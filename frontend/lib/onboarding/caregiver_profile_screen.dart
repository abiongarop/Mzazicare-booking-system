
import 'package:flutter/material.dart';

class CaregiverProfileScreen extends StatelessWidget {
  const CaregiverProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caregiver Profile'),
        backgroundColor: const Color(0xFF16877A),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Caregiver Profile\n\n'
            'This form will collect your qualifications, '
            'experience, skills, services, service area '
            'and availability.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, height: 1.6),
          ),
        ),
      ),
    );
  }
}
