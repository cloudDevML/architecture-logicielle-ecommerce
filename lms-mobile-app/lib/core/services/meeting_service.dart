import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import '../constants/api_constants.dart';

class MeetingModel {
  final int id;
  final int moduleId;
  final String roomName;
  final String createdBy;
  final String createdAt;
  final String status;
  final String title;
  final String description;

  MeetingModel({
    required this.id,
    required this.moduleId,
    required this.roomName,
    required this.createdBy,
    required this.createdAt,
    required this.status,
    required this.title,
    required this.description,
  });

  factory MeetingModel.fromJson(Map<String, dynamic> json) {
    return MeetingModel(
      id: json['id'] as int? ?? 0,
      moduleId: json['moduleId'] as int? ?? 0,
      roomName: json['roomName'] as String? ?? '',
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      status: json['status'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
}

class JoinMeetingResponseModel {
  final String token;
  final String livekitUrl;

  JoinMeetingResponseModel({
    required this.token,
    required this.livekitUrl,
  });

  factory JoinMeetingResponseModel.fromJson(Map<String, dynamic> json) {
    return JoinMeetingResponseModel(
      token: json['token'] as String? ?? '',
      livekitUrl: json['livekitUrl'] as String? ?? '',
    );
  }
}

class MeetingService {
  final AuthService _authService = AuthService();

  /// Récupérer les réunions actives pour un module
  Future<List<MeetingModel>> getActiveMeetings(int moduleId) async {
    try {
      final dio = await _authService.getAuthenticatedDio();
      final response = await dio.get(ApiConstants.activeMeetings(moduleId));
      
      if (response.statusCode == 200 && response.data is List) {
        final list = response.data as List;
        return list.map((item) => MeetingModel.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('MEETING_SERVICE: getActiveMeetings error: $e');
      return [];
    }
  }

  /// Récupérer toutes les réunions actives pour une liste de modules (Appel groupé)
  Future<List<MeetingModel>> getActiveMeetingsForModules(List<int> moduleIds) async {
    if (moduleIds.isEmpty) return [];
    try {
      final dio = await _authService.getAuthenticatedDio();
      final idsParam = moduleIds.join(',');
      final response = await dio.get('${ApiConstants.meetingBase}/active?moduleIds=$idsParam');
      
      if (response.statusCode == 200 && response.data is List) {
        final list = response.data as List;
        return list.map((item) => MeetingModel.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('MEETING_SERVICE: getActiveMeetingsForModules error: $e');
      return [];
    }
  }

  /// Rejoindre un salon de visioconférence et obtenir le token JWT LiveKit
  Future<JoinMeetingResponseModel?> joinMeeting(int meetingId, String roomName, String role) async {
    try {
      final dio = await _authService.getAuthenticatedDio();
      final response = await dio.post(
        ApiConstants.joinMeeting(meetingId),
        data: {
          'roomName': roomName,
          'role': role,
        },
      );
      
      if (response.statusCode == 200 && response.data != null) {
        return JoinMeetingResponseModel.fromJson(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('MEETING_SERVICE: joinMeeting error: $e');
      return null;
    }
  }

  /// Terminer une réunion (hôte uniquement)
  Future<void> endMeeting(int meetingId) async {
    try {
      final dio = await _authService.getAuthenticatedDio();
      await dio.post('${ApiConstants.baseUrl}/api/meeting/meetings/$meetingId/end');
    } catch (e) {
      debugPrint('MEETING_SERVICE: endMeeting error: $e');
    }
  }
}
