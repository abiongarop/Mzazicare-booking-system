
import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // ---------------------------------------------------------
  // BASE CONFIGURATION
  // ---------------------------------------------------------

  // Chrome / Windows development.
  // Android emulator: http://10.0.2.2:8000/api
  // Physical phone: replace with your computer's LAN IP.
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  static const Duration _timeout = Duration(seconds: 30);

  // ---------------------------------------------------------
  // FIREBASE AUTHENTICATION
  // ---------------------------------------------------------

  static Future<String> _getFirebaseIdToken({
    bool forceRefresh = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('You must sign in before accessing the API.');
    }

    final token = await user.getIdToken(forceRefresh);

    if (token == null || token.isEmpty) {
      throw Exception('Unable to obtain a Firebase ID token.');
    }

    return token;
  }

  static Future<void> debugFirebaseToken() async {
    final token = await _getFirebaseIdToken();
    debugPrint('Firebase token obtained: ${token.isNotEmpty}');
  }

  static Future<Map<String, String>> _authHeaders({
    bool jsonContent = false,
    bool forceRefresh = false,
  }) async {
    final token = await _getFirebaseIdToken(
      forceRefresh: forceRefresh,
    );

    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      if (jsonContent) 'Content-Type': 'application/json',
    };
  }

  static Future<http.Response> _authenticatedRequest({
    required Future<http.Response> Function(
      Map<String, String> headers,
    ) request,
    bool jsonContent = false,
  }) async {
    try {
      var headers = await _authHeaders(
        jsonContent: jsonContent,
      );

      var response = await request(headers).timeout(_timeout);

      // Refresh Firebase token once after an authentication failure.
      if (response.statusCode == 401 &&
          FirebaseAuth.instance.currentUser != null) {
        debugPrint('API returned 401. Refreshing Firebase token.');

        headers = await _authHeaders(
          jsonContent: jsonContent,
          forceRefresh: true,
        );

        response = await request(headers).timeout(_timeout);
      }

      return response;
    } on TimeoutException {
      throw Exception(
        'The server took too long to respond. Please try again.',
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(
        'Firebase authentication error: ${e.message}',
      );
    }
  }

  // ---------------------------------------------------------
  // RESPONSE HANDLING
  // ---------------------------------------------------------

  static Map<String, dynamic> _decodeResponse(
    http.Response response,
  ) {
    final body = response.body;
    dynamic decoded;

    if (body.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(body);
      } on FormatException {
        decoded = null;
      }
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      String message =
          'Request failed (${response.statusCode}).';

      if (decoded is Map) {
        final detail =
            decoded['detail'] ??
            decoded['message'] ??
            decoded['error'];

        if (detail != null) {
          message = detail.toString();
        } else {
          message = decoded.entries
              .map((entry) => '${entry.key}: ${entry.value}')
              .join('\n');
        }
      } else if (body.trim().isNotEmpty && decoded == null) {
        message =
            'The server returned a non-JSON error '
            '(${response.statusCode}). Check the Django terminal.';
      }

      throw Exception(message);
    }

    if (decoded == null) {
      return <String, dynamic>{};
    }

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    if (decoded is List) {
      return <String, dynamic>{'results': decoded};
    }

    return <String, dynamic>{'data': decoded};
  }

  // ---------------------------------------------------------
  // SHARED HTTP HELPERS
  // ---------------------------------------------------------

  static Future<Map<String, dynamic>> _get(
    String path,
  ) async {
    final response = await _authenticatedRequest(
      request: (headers) => http.get(
        Uri.parse('$baseUrl$path'),
        headers: headers,
      ),
    );

    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> data,
  ) async {
    final response = await _authenticatedRequest(
      jsonContent: true,
      request: (headers) => http.post(
        Uri.parse('$baseUrl$path'),
        headers: headers,
        body: jsonEncode(data),
      ),
    );

    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> _patch(
    String path,
    Map<String, dynamic> data,
  ) async {
    final response = await _authenticatedRequest(
      jsonContent: true,
      request: (headers) => http.patch(
        Uri.parse('$baseUrl$path'),
        headers: headers,
        body: jsonEncode(data),
      ),
    );

    return _decodeResponse(response);
  }

  // ---------------------------------------------------------
  // AUTHENTICATION AND PROFILE APIs
  // ---------------------------------------------------------

  static Future<Map<String, dynamic>> checkAuthentication() {
    return _get('/auth/check/');
  }

  static Future<Map<String, dynamic>> getMyProfile() {
    return _get('/profile/me/');
  }

  static Future<Map<String, dynamic>> updateMyProfile({
    required String fullName,
    required String phone,
    required String location,
  }) {
    return _patch('/profile/me/', {
      'full_name': fullName,
      'phone': phone,
      'location': location,
    });
  }

  // Save the role selected on the landing page.
  //
  // Allowed roles:
  // - client
  // - caregiver
  //
  // Django endpoint:
  // POST /api/profile/select-role/
  static Future<Map<String, dynamic>> selectRole({
    required String role,
  }) async {
    final normalizedRole = role.trim().toLowerCase();

    if (normalizedRole != 'client' &&
        normalizedRole != 'caregiver') {
      throw ArgumentError(
        'Invalid role. Select either client or caregiver.',
      );
    }

    final response = await _post(
      '/profile/select-role/',
      {'role': normalizedRole},
    );

    debugPrint('Role selection response: $response');

    // Check the role returned by Django when available.
    final returnedProfile = response['profile'];

    if (returnedProfile is Map) {
      final savedRole =
          returnedProfile['role']?.toString().toLowerCase();

      if (savedRole != null && savedRole != normalizedRole) {
        throw Exception(
          'Django returned an unexpected role: $savedRole',
        );
      }
    }

    return response;
  }

  // ---------------------------------------------------------
  // FAMILY PROFILE APIs
  // ---------------------------------------------------------

  static Future<Map<String, dynamic>> getFamilyCareProfile() {
    return _get('/family-profile/');
  }

  static Future<Map<String, dynamic>> updateFamilyCareProfile(
    Map<String, dynamic> data,
  ) {
    return _patch('/family-profile/', data);
  }

  static Future<Map<String, dynamic>> saveFamilyCareProfile(
    Map<String, dynamic> data,
  ) {
    return updateFamilyCareProfile(data);
  }

  // ---------------------------------------------------------
  // CAREGIVER PROFILE APIs
  // ---------------------------------------------------------

  static Future<Map<String, dynamic>> getCaregiverProfile() {
    return _get('/caregiver-profile/');
  }

  static Future<Map<String, dynamic>> saveCaregiverProfile(
    Map<String, dynamic> data,
  ) {
    return _patch('/caregiver-profile/', data);
  }

  // ---------------------------------------------------------
  // SERVICES
  // ---------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getServicesForCaregiver(
    int caregiverDatabaseId,
  ) async {
    final response = await _get(
      '/services/?caregiver=$caregiverDatabaseId',
    );

    final results = response['results'];

    if (results is! List) {
      return [];
    }

    return results
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  // ---------------------------------------------------------
  // CAREGIVER RECOMMENDATIONS
  // ---------------------------------------------------------

  static Future<Map<String, dynamic>> getFamilyRecommendations() {
    return _get('/recommendations/family/');
  }

  // ---------------------------------------------------------
  // CARE SCHEDULES / BOOKINGS
  // ---------------------------------------------------------

  static Future<Map<String, dynamic>> getCareSchedules() {
    return _get('/care-schedules/');
  }

  static Future<Map<String, dynamic>> createCareSchedule({
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
    int? caregiverDatabaseId,
    String arrangement = 'one_time',
    List<String> services = const [],
    String familyNotes = '',
  }) async {
    if (!scheduledEnd.isAfter(scheduledStart)) {
      throw ArgumentError(
        'The booking end time must be after its start time.',
      );
    }

    if (scheduledStart.isBefore(DateTime.now())) {
      throw ArgumentError(
        'The booking start time must be in the future.',
      );
    }

    if (arrangement != 'one_time' &&
        arrangement != 'recurring') {
      throw ArgumentError(
        'Arrangement must be one_time or recurring.',
      );
    }

    final data = <String, dynamic>{
      'scheduled_start':
          scheduledStart.toUtc().toIso8601String(),
      'scheduled_end':
          scheduledEnd.toUtc().toIso8601String(),
      'arrangement': arrangement,
      'services': services,
      'family_notes': familyNotes.trim(),
    };

    if (caregiverDatabaseId != null) {
      data['caregiver'] = caregiverDatabaseId;
    }

    return _post('/care-schedules/', data);
  }

  static Future<Map<String, dynamic>> getCareSchedule(
    int scheduleId,
  ) {
    return _get('/care-schedules/$scheduleId/');
  }

  static Future<Map<String, dynamic>> updateCareSchedule(
    int scheduleId,
    Map<String, dynamic> data,
  ) {
    return _patch('/care-schedules/$scheduleId/', data);
  }
    // ---------------------------------------------------------
  // CAREGIVER BOOKING DECISIONS
  // ---------------------------------------------------------

  static Future<Map<String, dynamic>> decideCareSchedule(
    int scheduleId, {
    required String decision,
  }) async {
    final normalizedDecision = decision.trim().toLowerCase();

    if (normalizedDecision != 'accept' &&
        normalizedDecision != 'decline') {
      throw ArgumentError(
        'Decision must be accept or decline.',
      );
    }

    return _post(
      '/care-schedules/$scheduleId/decision/$normalizedDecision/',
      {},
    );
  }

  static Future<Map<String, dynamic>> cancelCareSchedule(
    int scheduleId, {
    String reason = '',
  }) {
    return _post(
      '/care-schedules/$scheduleId/cancel/',
      {'reason': reason},
    );
  }

  // ---------------------------------------------------------
  // CONVERSATIONS
  // ---------------------------------------------------------

  static Future<Map<String, dynamic>> getConversations() {
    return _get('/conversations/');
  }

  static Future<Map<String, dynamic>> startConversation(
    String caregiverId,
  ) {
    return _post('/conversations/', {
      'caregiver_id': caregiverId,
    });
  }

static Future<Map<String, dynamic>> startConversationForBooking(
  int scheduleId,
) {
  return _post('/conversations/', {
    'schedule_id': scheduleId,
  });
}
  // ---------------------------------------------------------
  // MESSAGES
  // ---------------------------------------------------------

  static Future<Map<String, dynamic>> getMessages(
    int conversationId,
  ) {
    return _get('/conversations/$conversationId/messages/');
  }

  static Future<Map<String, dynamic>> sendMessage(
    int conversationId,
    String body,
  ) {
    final message = body.trim();

    if (message.isEmpty) {
      throw ArgumentError('A message cannot be empty.');
    }

    return _post(
      '/conversations/$conversationId/messages/',
      {'body': message},
    );
  }

  // ---------------------------------------------------------
  // CARE UPDATES
  // ---------------------------------------------------------

  static Future<Map<String, dynamic>> getCareUpdates() {
    return _get('/care-updates/');
  }

  static Future<Map<String, dynamic>> getCareUpdate(
    int updateId,
  ) {
    return _get('/care-updates/$updateId/');
  }

  static Future<Map<String, dynamic>> createCareUpdate({
    required int scheduleId,
    required String title,
    required String body,
    String updateType = 'visit_summary',
    List<String> activities = const [],
    bool followUpRequired = false,
  }) {
    return _post('/care-updates/', {
      'schedule_id': scheduleId,
      'title': title.trim(),
      'body': body.trim(),
      'update_type': updateType,
      'activities': activities,
      'follow_up_required': followUpRequired,
    });
  }

  // ---------------------------------------------------------
  // ADMIN PORTAL APIs
  // ---------------------------------------------------------

  static Future<Map<String, dynamic>> getAdminDashboard() {
    return _get('/admin/dashboard/');
  }

  static Future<Map<String, dynamic>> getAdminCaregivers({
    bool? verified,
  }) {
    final query = verified == null
        ? ''
        : '?verified=${verified ? 'true' : 'false'}';

    return _get('/admin/caregivers/$query');
  }

  static Future<Map<String, dynamic>> verifyCaregiver(
    int caregiverDatabaseId, {
    required bool verified,
  }) {
    return _patch(
      '/admin/caregivers/$caregiverDatabaseId/verification/',
      {'is_verified': verified},
    );
  }

  static Future<Map<String, dynamic>> getAdminFamilies() {
    return _get('/admin/families/');
  }

  static Future<Map<String, dynamic>> getAdminCareSchedules({
    String? status,
  }) {
    final query = status == null || status.isEmpty
        ? ''
        : '?status=${Uri.encodeQueryComponent(status)}';

    return _get('/admin/care-schedules/$query');
  }

  static Future<Map<String, dynamic>> createAdminCareSchedule({
    required int familyProfileId,
    required int caregiverDatabaseId,
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
    required List<String> services,
    String arrangement = 'one_time',
    String familyNotes = '',
  }) {
    if (!scheduledEnd.isAfter(scheduledStart)) {
      throw ArgumentError(
        'The booking end time must be after its start time.',
      );
    }

    if (scheduledStart.isBefore(DateTime.now())) {
      throw ArgumentError(
        'The booking start time must be in the future.',
      );
    }

    return _post('/admin/care-schedules/', {
      'family_profile': familyProfileId,
      'caregiver': caregiverDatabaseId,
      'scheduled_start':
          scheduledStart.toUtc().toIso8601String(),
      'scheduled_end':
          scheduledEnd.toUtc().toIso8601String(),
      'arrangement': arrangement,
      'services': services,
      'family_notes': familyNotes.trim(),
    });
  }

  static Future<Map<String, dynamic>> updateAdminCareScheduleStatus(
    int scheduleId, {
    required String status,
  }) {
    return _patch(
      '/admin/care-schedules/$scheduleId/status/',
      {'status': status},
    );
  }
}
