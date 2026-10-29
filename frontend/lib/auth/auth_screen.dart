
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/api_service.dart';
import '../onboarding/role_selection_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLoading = false;

  Future<void> signInWithGoogle() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Step 1: Sign in with Google through Firebase.
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithPopup(
        GoogleAuthProvider(),
      );

      final User? user = userCredential.user;

      if (user == null) {
        throw Exception('Google sign-in did not return a user.');
      }

      debugPrint('Firebase sign-in successful: ${user.email}');

      // Step 2: Verify the Firebase ID token with Django.
      final authResult = await ApiService.checkAuthentication();
      debugPrint('Django authentication successful: $authResult');

      // Step 3: Retrieve or create the user's MzaziCare profile.
      final profile = await ApiService.getMyProfile();
      debugPrint('MzaziCare profile: $profile');

      if (!mounted) return;

      // Step 4: Navigate to onboarding.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (context) => const RoleSelectionScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'Firebase authentication error: ${e.code} - ${e.message}',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Google sign-in failed. Please try again.',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Sign-in or backend error: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to complete sign-in: $e'),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF16877A);
    const darkColor = Color(0xFF174A45);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 3,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // MzaziCare logo.
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5F4F0),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.health_and_safety_rounded,
                          size: 58,
                          color: primaryColor,
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        'MzaziCare',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: darkColor,
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        'Trusted care for your loved ones.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'Find suitable elderly home caregivers or '
                        'create a professional caregiver profile.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton(
                          onPressed:
                              isLoading ? null : signInWithGoogle,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: darkColor,
                            side: const BorderSide(
                              color: Color(0xFFD5DEDB),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: primaryColor,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.g_mobiledata_rounded,
                                      size: 34,
                                      color: primaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Continue with Google',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'By continuing, you agree to use MzaziCare '
                        'responsibly and protect the privacy of care '
                        'recipients.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Colors.black54,
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (isLoading)
                        const Text(
                          'Signing you in securely...',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
