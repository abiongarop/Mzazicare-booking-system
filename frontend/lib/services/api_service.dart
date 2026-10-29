
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Django REST API base URL.
  // Android Emulator: use http://10.0.2.2:8000/api
  // Flutter Web/Windows on the same PC: use 127.0.0.1.
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  static const Duration _timeout = Duration(seconds: 30);

  // ---------------------------------------------------------
  // 1. Get a fresh Firebase ID token.
  // ---------------------------------------------------------
  static Future<String> _getFirebaseIdToken() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception(
        'No Firebase user is signed in. Please sign in again.',
      );
    }

    try {
      final String? token = await user.getIdToken(true);

      if (token == null || token.isEmpty) {
        throw Exception('Firebase returned an empty ID token.');
      }

      // Safe diagnostics: never print the full token.
      debugPrint('Firebase UID: ${user.uid}');
      debugPrint('Firebase email: ${user.email}');
      debugPrint('Firebase ID token available: true');
      debugPrint('Firebase ID token segments: ${token.split('.').length}');

      if (token.split('.').length != 3) {
        throw Exception(
          'The returned token is not in the expected JWT format.',
        );
      }

      return token;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase token refresh failed: ${e.code}');

      throw Exception(
        'Could not refresh your Firebase session. '
        'Please sign in again. (${e.code})',
      );
    }
  }

  // ---------------------------------------------------------
  // 2. Token diagnostic.
  // Run this after signing in to verify token format.
  // Does not print the token itself.
  // ---------------------------------------------------------
  static Future<void> debugFirebaseToken() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint('No Firebase user is currently signed in.');
      return;
    }

    try {
      final token = await user.getIdToken(true);

      debugPrint('Firebase UID: ${user.uid}');
      debugPrint('Firebase ID token available: '
          '${token != null && token.isNotEmpty}');
      debugPrint('Firebase ID token segments: '
          '${token?.split('.').length}');
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase token diagnostic failed: ${e.code}');
    }
  }

  // ---------------------------------------------------------
  // 3. Headers for authenticated Django requests.
  // ---------------------------------------------------------
  static Future<Map<String, String>> _authHeaders({
    bool jsonContent = false,
  }) async {
    final token = await _getFirebaseIdToken();

    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      if (jsonContent) 'Content-Type': 'application/json',
    };
  }

  // ---------------------------------------------------------
  // 4. Decode JSON response.
  // ---------------------------------------------------------
  static Map<String, dynamic> _decodeResponse(
    http.Response response,
  ) {
    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(response.body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const FormatException(
      'The server returned an unexpected JSON response.',
    );
  }

  // ---------------------------------------------------------
  // 5. Check authentication.
  // GET /api/auth/check/
  // ---------------------------------------------------------
  static Future<Map<String, dynamic>> checkAuthentication() async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/auth/check/'),
          headers: await _authHeaders(),
        )
        .timeout(_timeout);

    debugPrint('Authentication HTTP status: ${response.statusCode}');

    if (response.statusCode == 200) {
      return _decodeResponse(response);
    }

    throw Exception(
      'Authentication check failed: '
      'HTTP ${response.statusCode}: ${response.body}',
    );
  }

  // ---------------------------------------------------------
  // 6. Get current account profile.
  // GET /api/profile/me/
  // ---------------------------------------------------------
  static Future<Map<String, dynamic>> getMyProfile() async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/profile/me/'),
          headers: await _authHeaders(),
        )
        .timeout(_timeout);

    debugPrint('Profile HTTP status: ${response.statusCode}');

    if (response.statusCode == 200) {
      return _decodeResponse(response);
    }

    throw Exception(
      'Profile request failed: '
      'HTTP ${response.statusCode}: ${response.body}',
    );
  }

  // ---------------------------------------------------------
  // 7. Update current account profile.
  // PATCH /api/profile/me/
  // ---------------------------------------------------------
  static Future<Map<String, dynamic>> updateMyProfile({
    required String role,
    String phone = '',
    String location = '',
  }) async {
    if (role != 'client' && role != 'caregiver') {
      throw ArgumentError(
        'Role must be either client or caregiver.',
      );
    }

    final response = await http
        .patch(
          Uri.parse('$baseUrl/profile/me/'),
          headers: await _authHeaders(jsonContent: true),
          body: jsonEncode({
            'role': role,
            'phone': phone,
            'location': location,
          }),
        )
        .timeout(_timeout);

    debugPrint('Profile update HTTP status: ${response.statusCode}');

    if (response.statusCode == 200) {
      return _decodeResponse(response);
    }

    throw Exception(
      'Profile update failed: '
      'HTTP ${response.statusCode}: ${response.body}',
    );
  }

  // ---------------------------------------------------------
  // 8. Get family care profile.
  // GET /api/family-profile/
  // ---------------------------------------------------------
  static Future<Map<String, dynamic>> getFamilyCareProfile() async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/family-profile/'),
          headers: await _authHeaders(),
        )
        .timeout(_timeout);

    debugPrint('Family profile HTTP status: ${response.statusCode}');

    if (response.statusCode == 200) {
      return _decodeResponse(response);
    }

    throw Exception(
      'Could not load family profile: '
      'HTTP ${response.statusCode}: ${response.body}',
    );
  }

  // ---------------------------------------------------------
  // 9. Save family care profile.
  // PATCH /api/family-profile/
  // ---------------------------------------------------------
  static Future<Map<String, dynamic>> saveFamilyCareProfile(
    Map<String, dynamic> data,
  ) async {
    final response = await http
        .patch(
          Uri.parse('$baseUrl/family-profile/'),
          headers: await _authHeaders(jsonContent: true),
          body: jsonEncode(data),
        )
        .timeout(_timeout);

    debugPrint('Family profile save HTTP status: ${response.statusCode}');

    if (response.statusCode == 200) {
      return _decodeResponse(response);
    }

    throw Exception(
      'Could not save family profile: '
      'HTTP ${response.statusCode}: ${response.body}',
    );
  }

  // ---------------------------------------------------------
  // 10. Get family recommendations.
  // GET /api/recommendations/family/
  // ---------------------------------------------------------
  static Future<Map<String, dynamic>> getFamilyRecommendations() async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/recommendations/family/'),
          headers: await _authHeaders(),
        )
        .timeout(_timeout);

    debugPrint(
      'Family recommendations HTTP status: ${response.statusCode}',
    );

    if (response.statusCode == 200) {
      return _decodeResponse(response);
    }

    throw Exception(
      'Could not load family recommendations: '
      'HTTP ${response.statusCode}: ${response.body}',
    );
  }
}
