import '../onboarding/family_profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../dashboards/family_dashboard_screen.dart';
import '../dashboards/caregiver_dashboard_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../onboarding/caregiver_profile_screen.dart';

enum AuthMode { signIn, register }

class AuthScreen extends StatefulWidget {
  final String? initialRole;

  const AuthScreen({
    super.key,
    this.initialRole,
  });

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

  static const Color _primary = Color(0xFFC8758D);
  static const Color _primaryDark = Color(0xFFA95570);


  bool get _isRegistering => _mode == AuthMode.register;

  String? get _selectedRole {
    final value = widget.initialRole?.trim().toLowerCase();

    if (value == 'client' || value == 'caregiver') {
      return value;
    }

    return null;
  }

  String get _roleLabel {
    return _selectedRole == 'caregiver' ? 'Caregiver' : 'Family Member';
  }

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

  bool _isFamilyProfileComplete(Map<String, dynamic> profile) {
  if (profile.isEmpty) return false;

  final phone = profile['contact_phone']?.toString().trim() ?? '';
  final location = profile['location']?.toString().trim() ?? '';

  final age = int.tryParse(
    profile['care_recipient_age']?.toString() ?? '',
  );

  final services = profile['required_services'];

  final hasRequiredServices =
      services is List && services.isNotEmpty;

  return phone.isNotEmpty &&
      location.isNotEmpty &&
      age != null &&
      age >= 1 &&
      age <= 120 &&
      hasRequiredServices;
}

  Future<void> _authenticate(
    UserCredential credential, {
    required bool isNewUser,
  }) async {
    final user = credential.user;

    if (user == null) {
      throw Exception('Firebase did not return a signed-in user.');
    }

    debugPrint('Firebase authentication successful: ${user.email}');

    // 1. Verify Firebase authentication with Django.
    await ApiService.checkAuthentication();

    // 2. Retrieve the MzaziCare account.
    var profile = await ApiService.getMyProfile();

    debugPrint('Retrieved MzaziCare profile: $profile');

    String? role = profile['role']?.toString().trim().toLowerCase();

    // 3. Assign a role to newly registered users.
    if (isNewUser) {
      final selectedRole = _selectedRole;

      if (selectedRole == null) {
        throw Exception(
          'No account type was selected. Please return to the '
          'landing page and choose an account type.',
        );
      }

      debugPrint('Assigning account role: $selectedRole');

      await ApiService.selectRole(role: selectedRole);

      // Confirm that Django saved the role.
      profile = await ApiService.getMyProfile();
      role = profile['role']?.toString().trim().toLowerCase();

      if (role != selectedRole) {
        throw Exception(
          'Role assignment could not be confirmed. '
          'Expected $selectedRole but received $role.',
        );
      }
    }

    // 4. Validate the account role.
    if (role == null || role.isEmpty) {
      throw Exception(
        'Your account role could not be determined. '
        'Please contact support.',
      );
    }

    debugPrint('Final MzaziCare role: $role');

    // 5. Determine the correct destination.
    // 5. Determine the correct destination.
late final Widget destination;

switch (role) {
  case 'admin':
    destination = const AdminDashboardScreen();
    break;

  case 'client':
    final familyProfile = await ApiService.getFamilyCareProfile();

    debugPrint('Family profile response: $familyProfile');

    final familyProfileComplete =
        _isFamilyProfileComplete(familyProfile);

    // New family registrations must complete onboarding first.
    // Returning users with incomplete profiles must also complete it.
    if (isNewUser || !familyProfileComplete) {
      destination = const FamilyProfileScreen();
    } else {
      destination = const FamilyDashboardScreen();
    }
    break;

  case 'caregiver':
    final caregiverProfile = await ApiService.getCaregiverProfile();

    debugPrint('Caregiver profile response: $caregiverProfile');

    if (caregiverProfile.isEmpty) {
      destination = const CaregiverProfileScreen(
        isOnboarding: true,
      );
    } else {
      destination = const CaregiverDashboardScreen();
    }
    break;

  default:
    throw Exception('Unrecognised account role: $role.');
}

    // 6. Navigate only if this screen is still active.
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => destination,
      ),
      (route) => false,
    );
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

      final isNewUser =
          credential.additionalUserInfo?.isNewUser ?? false;

      await _authenticate(
        credential,
        isNewUser: isNewUser,
      );
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
        if (_selectedRole == null) {
          throw Exception(
            'Please return to the landing page and select '
            'your account type before registering.',
          );
        }

        credential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        isNewUser = true;
      } else {
        credential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        //temp debugging
        await ApiService.debugMyProfile();
      }

      await _authenticate(
        credential,
        isNewUser: isNewUser,
      );
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 28,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBrandHeader(),
                  const SizedBox(height: 30),
                  _buildAuthCard(),
                  const SizedBox(height: 22),
                  Text(
                    'Your loved ones deserve compassionate care.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
        Text(
          'MzaziCare',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: theme.brightness == Brightness.dark
                ? colors.primary
                : _primaryDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isRegistering
              ? 'Create your $_roleLabel account.'
              : 'Trusted care. Peace of mind. Closer connections.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthCard() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isRegistering ? 'Create an account' : 'Welcome back',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 23,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isRegistering
                  ? 'Join the MzaziCare community as a $_roleLabel.'
                  : 'Sign in to continue to your account.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            _buildGoogleButton(),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Divider(color: colors.outlineVariant),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR CONTINUE WITH EMAIL',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(color: colors.outlineVariant),
                ),
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
                        backgroundColor: colors.primary,
                        disabledBackgroundColor:
                            colors.primary.withValues(alpha: 0.55),
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
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => _setMode(
                            _isRegistering
                                ? AuthMode.signIn
                                : AuthMode.register,
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
      ),
    );
  }

  Widget _buildGoogleButton() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _signInWithGoogle,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.onSurface,
          side: BorderSide(color: colors.outlineVariant),
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
            Text(
              'Continue with Google',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
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
    final colors = Theme.of(context).colorScheme;

    return TextFormField(
      controller: _passwordController,
      enabled: !_isLoading,
      obscureText: _obscurePassword,
      textInputAction:
          _isRegistering ? TextInputAction.next : TextInputAction.done,
      autofillHints: _isRegistering
          ? const [AutofillHints.newPassword]
          : const [AutofillHints.password],
      onFieldSubmitted: (_) {
        if (!_isRegistering && !_isLoading) {
          _submitEmailForm();
        }
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
            color: colors.onSurfaceVariant,
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
    final colors = Theme.of(context).colorScheme;

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
          tooltip: _obscureConfirmPassword
              ? 'Show password'
              : 'Hide password',
          onPressed: () {
            setState(() {
              _obscureConfirmPassword = !_obscureConfirmPassword;
            });
          },
          icon: Icon(
            _obscureConfirmPassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: colors.onSurfaceVariant,
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
    final colors = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: colors.primary),
      suffixIcon: suffix,
      filled: true,
      fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.55),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: colors.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: colors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: colors.error, width: 1.6),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.error.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: colors.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onErrorContainer,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
