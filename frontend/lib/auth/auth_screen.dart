import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../onboarding/role_selection_screen.dart';
import '../onboarding/family_profile_screen.dart';
import '../onboarding/caregiver_profile_screen.dart';

enum AuthMode { signIn, register }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  AuthMode _mode = AuthMode.signIn;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  static const Color _primary = Color(0xFF176B57);
  static const Color _primaryDark = Color(0xFF104C40);
  static const Color _background = Color(0xFFF5F8F6);

  bool get _isRegistering => _mode == AuthMode.register;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _setMode(AuthMode mode) {
    if (_isLoading) return;

    setState(() {
      _mode = mode;
      _errorMessage = null;
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  Future<void> _authenticate(
    UserCredential credential, {
    required bool isNewUser,
  }) async {
    final user = credential.user;

    if (user == null) {
      throw Exception('Firebase did not return a signed-in user.');
    }

    debugPrint('Firebase sign-in successful: ${user.email}');

    // Verify that Django accepts the Firebase ID token.
    final authResult = await ApiService.checkAuthentication();
    debugPrint('Django authentication successful: $authResult');

    // Retrieve the authenticated user's MzaziCare profile.
    final profile = await ApiService.getMyProfile();
    debugPrint('MzaziCare profile retrieved successfully.');

    if (!mounted) return;

    final role = profile['role']?.toString().toLowerCase();

    Widget destination;

    if (isNewUser || (role != 'client' && role != 'caregiver')) {
      destination = const RoleSelectionScreen();
    } else if (role == 'client') {
      // Existing family member: continue to family onboarding/profile.
      destination = const FamilyProfileScreen();
    } else {
      // Existing caregiver: continue to caregiver onboarding/profile.
      destination = const CaregiverProfileScreen();
    }

    Navigator.of(context)
        .pushReplacement(MaterialPageRoute<void>(builder: (_) => destination));
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithPopup(
        GoogleAuthProvider(),
      );

      final isNewUser = credential.additionalUserInfo?.isNewUser ?? false;

      await _authenticate(credential, isNewUser: isNewUser);
    } on FirebaseAuthException catch (e) {
      _showError(_firebaseError(e));
    } catch (e, stackTrace) {
      debugPrint('Google authentication error: $e');
      debugPrintStack(stackTrace: stackTrace);
      _showError(_readableError(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitEmailForm() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      late final UserCredential credential;
      bool isNewUser = false;

      if (_isRegistering) {
        credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        isNewUser = true;

        // Set a display name only if one is already available.
        // Users can update their full name in their profile later.
      } else {
        credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      await _authenticate(credential, isNewUser: isNewUser);
    } on FirebaseAuthException catch (e) {
      _showError(_firebaseError(e));
    } catch (e, stackTrace) {
      debugPrint('Email authentication error: $e');
      debugPrintStack(stackTrace: stackTrace);
      _showError(_readableError(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showError('Enter your email address first to reset your password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseAuthException catch (e) {
      _showError(_firebaseError(e));
    } catch (e) {
      _showError(_readableError(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
  }

  String _readableError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');

    if (message.contains('SocketException') ||
        message.contains('Failed host lookup')) {
      return 'Unable to connect. Check your internet connection and try again.';
    }

    return message;
  }

  String _firebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email. Sign in instead.';
      case 'weak-password':
        return 'Choose a stronger password with at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a while and try again.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'popup-closed-by-user':
        return 'The Google sign-in window was closed before completion.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with another sign-in method.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase Authentication.';
      default:
        debugPrint('Firebase error code: ${e.code}');
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBrandHeader(),
                  const SizedBox(height: 30),
                  _buildAuthCard(),
                  const SizedBox(height: 22),
                  const Text(
                    'Your loved ones deserve compassionate care.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF66736D), fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: _primary,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.20),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: const Icon(
            Icons.volunteer_activism_rounded,
            color: Colors.white,
            size: 39,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'MzaziCare',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: _primaryDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isRegistering
              ? 'Create your account and get started.'
              : 'Trusted care. Peace of mind. Closer connections.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF66736D),
            height: 1.5,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6ECE8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF183C2F).withValues(alpha: 0.06),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isRegistering ? 'Create an account' : 'Welcome back',
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: Color(0xFF20352C),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isRegistering
                ? 'Join the MzaziCare community.'
                : 'Sign in to continue to your account.',
            style: const TextStyle(color: Color(0xFF75817B), fontSize: 13),
          ),
          const SizedBox(height: 22),
          _buildGoogleButton(),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(child: Divider(color: Color(0xFFE1E8E3))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR CONTINUE WITH EMAIL',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: Color(0xFFE1E8E3))),
            ],
          ),
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildEmailField(),
                const SizedBox(height: 15),
                _buildPasswordField(),
                if (_isRegistering) ...[
                  const SizedBox(height: 15),
                  _buildConfirmPasswordField(),
                ],
                if (!_isRegistering)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _resetPassword,
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  _buildErrorBanner(_errorMessage!),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _submitEmailForm,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      disabledBackgroundColor: _primary.withValues(alpha: 0.55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.3,
                            ),
                          )
                        : Text(
                            _isRegistering ? 'Create account' : 'Sign in',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  _isRegistering
                      ? 'Already have an account?'
                      : "Don't have an account?",
                  style: const TextStyle(
                    color: Color(0xFF69766F),
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => _setMode(
                        _isRegistering ? AuthMode.signIn : AuthMode.register,
                      ),
                child: Text(
                  _isRegistering ? 'Sign in' : 'Register',
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _signInWithGoogle,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF26352D),
          side: const BorderSide(color: Color(0xFFDCE5DF)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 25,
              height: 25,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'G',
                style: TextStyle(
                  color: Color(0xFF4285F4),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 11),
            const Text(
              'Continue with Google',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      enabled: !_isLoading,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      decoration: _inputDecoration(
        label: 'Email address',
        hint: 'you@example.com',
        icon: Icons.email_outlined,
      ),
      validator: (value) {
        final email = value?.trim() ?? '';
        if (email.isEmpty) return 'Email address is required.';
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
          return 'Enter a valid email address.';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      enabled: !_isLoading,
      obscureText: _obscurePassword,
      textInputAction: _isRegistering
          ? TextInputAction.next
          : TextInputAction.done,
      autofillHints: _isRegistering
          ? const [AutofillHints.newPassword]
          : const [AutofillHints.password],
      onFieldSubmitted: (_) {
        if (!_isRegistering && !_isLoading) _submitEmailForm();
      },
      decoration: _inputDecoration(
        label: 'Password',
        hint: 'Enter your password',
        icon: Icons.lock_outline_rounded,
        suffix: IconButton(
          tooltip: _obscurePassword ? 'Show password' : 'Hide password',
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: Colors.grey.shade600,
          ),
        ),
      ),
      validator: (value) {
        final password = value ?? '';
        if (password.isEmpty) return 'Password is required.';
        if (_isRegistering && password.length < 6) {
          return 'Use at least 6 characters.';
        }
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      enabled: !_isLoading,
      obscureText: _obscureConfirmPassword,
      textInputAction: TextInputAction.done,
      decoration: _inputDecoration(
        label: 'Confirm password',
        hint: 'Re-enter your password',
        icon: Icons.lock_reset_rounded,
        suffix: IconButton(
          tooltip: _obscureConfirmPassword ? 'Show password' : 'Hide password',
          onPressed: () {
            setState(() {
              _obscureConfirmPassword = !_obscureConfirmPassword;
            });
          },
          icon: Icon(
            _obscureConfirmPassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: Colors.grey.shade600,
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please confirm your password.';
        }
        if (value != _passwordController.text) {
          return 'Passwords do not match.';
        }
        return null;
      },
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _primary),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFFAFCFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFDCE5DF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFDCE5DF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0EF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD5D1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFB42318),
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF912018),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
