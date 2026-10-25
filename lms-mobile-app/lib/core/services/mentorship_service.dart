import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import 'auth_service.dart';

class MentorshipRequest {
  final int id;
  final String mentorUsername;
  final String menteeUsername;
  final String? mentorName;
  final String? menteeName;
  final int moduleId;
  final String? moduleName;
  final String mentorRole; // LECTURER or STUDENT
  final String status; // PENDING, ACCEPTED, COMPLETED, REJECTED, CANCELLED
  final DateTime createdAt;

  MentorshipRequest({
    required this.id,
    required this.mentorUsername,
    required this.menteeUsername,
    this.mentorName,
    this.menteeName,
    required this.moduleId,
    this.moduleName,
    required this.mentorRole,
    required this.status,
    required this.createdAt,
  });

  factory MentorshipRequest.fromJson(Map<String, dynamic> json) {
    return MentorshipRequest(
      id: json['id'] ?? 0,
      mentorUsername: json['mentorUsername'] ?? '',
      menteeUsername: json['menteeUsername'] ?? '',
      mentorName: json['mentorName'],
      menteeName: json['menteeName'],
      moduleId: json['moduleId'] ?? 0,
      moduleName: json['moduleName'] ?? json['moduleTitle'],
      mentorRole: json['mentorRole'] ?? 'LECTURER',
      status: json['status'] ?? 'PENDING',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class MentorshipService {
  final AuthService _authService = AuthService();

  // Get requests where I'm the mentee (sent requests)
  Future<List<MentorshipRequest>> getMenteeRequests(String username) async {
    try {
      final dio = await _authService.getAuthenticatedDio();
      final response = await dio.get('${ApiConstants.mentorship}/mentee/$username');
      
      if (response.data is List) {
        return (response.data as List)
            .map((e) => MentorshipRequest.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching mentee requests: $e');
      return [];
    }
  }

  // Get requests where I'm the mentor (received requests)
  Future<List<MentorshipRequest>> getMentorRequests(String username) async {
    try {
      final dio = await _authService.getAuthenticatedDio();
      final response = await dio.get('${ApiConstants.mentorship}/mentor/$username');
      
      if (response.data is List) {
        return (response.data as List)
            .map((e) => MentorshipRequest.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching mentor requests: $e');
      return [];
    }
  }

  // Create a new mentorship request
  Future<bool> requestMentorship({
    required String mentorUsername,
    required String menteeUsername,
    required int moduleId,
    String mentorRole = 'LECTURER',
  }) async {
    try {
      final dio = await _authService.getAuthenticatedDio();
      await dio.post(
        '${ApiConstants.mentorship}/request',
        data: {
          'mentorUsername': mentorUsername,
          'menteeUsername': menteeUsername,
          'moduleId': moduleId,
          'mentorRole': mentorRole,
        },
      );
      return true;
    } catch (e) {
      debugPrint('Error requesting mentorship: $e');
      return false;
    }
  }

  // Update mentorship status (ACCEPTED, REJECTED, COMPLETED, CANCELLED)
  Future<bool> updateStatus(int id, String status) async {
    try {
      final dio = await _authService.getAuthenticatedDio();
      await dio.put('${ApiConstants.mentorship}/$id/status?status=$status');
      return true;
    } catch (e) {
      debugPrint('Error updating mentorship status: $e');
      return false;
    }
  }
}
