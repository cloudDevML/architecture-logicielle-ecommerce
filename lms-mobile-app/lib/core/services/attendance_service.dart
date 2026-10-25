import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_service.dart';

// ── Modèle d'Émargement ──────────────────────────────────────────────────────
class AttendanceModel {
  final String moduleName;
  final String? sessionTitle;
  final DateTime date;
  final String? startTime;
  final String? endTime;
  final String? scanTime;
  final String status;
  final String lecturerName;

  AttendanceModel({
    required this.moduleName,
    this.sessionTitle,
    required this.date,
    this.startTime,
    this.endTime,
    this.scanTime,
    required this.status,
    required this.lecturerName,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      moduleName: json['moduleName'] as String? ?? '',
      sessionTitle: json['sessionTitle'] as String?,
      date: json['date'] != null 
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
      scanTime: json['scanTime'] as String?,
      status: json['status'] as String? ?? 'ABSENT',
      lecturerName: json['lecturerName'] as String? ?? '',
    );
  }
}

// ── Service d'Émargement ─────────────────────────────────────────────────────
class AttendanceService {
  final AuthService _authService = AuthService();

  /// Récupère l'historique d'émargement d'un étudiant
  Future<List<AttendanceModel>> getHistory() async {
    final dio = await _authService.getAuthenticatedDio();
    final username = await _authService.getUsername();
    if (username == null) return [];

    try {
      final response = await dio.get('${ApiConstants.attendanceHistory}/$username');
      final List data = response.data is List ? response.data : [];
      return data.map((e) => AttendanceModel.fromJson(e)).toList()
        ..sort((a, b) {
          final dateCmp = b.date.compareTo(a.date);
          if (dateCmp != 0) return dateCmp;
          final aTime = a.scanTime ?? '00:00';
          final bTime = b.scanTime ?? '00:00';
          return bTime.compareTo(aTime);
        });
    } catch (e) {
      throw Exception('Erreur lors de la récupération de l\'historique: $e');
    }
  }

  /// Valide un émargement via scan QR Code
  Future<String> scanQr(String token, {double? latitude, double? longitude}) async {
    final dio = await _authService.getAuthenticatedDio();
    final username = await _authService.getUsername();
    if (username == null) throw Exception('Utilisateur non connecté');

    try {
      final response = await dio.post(
        ApiConstants.attendanceScan,
        data: {
          'token': token,
          'studentId': username,
          'latitude': latitude,
          'longitude': longitude,
        },
      );
      return response.data.toString();
    } catch (e) {
      if (e is DioException && e.response != null) {
        throw e.response?.data.toString() ?? 'Erreur inconnue';
      }
      throw Exception('Erreur lors du scan: $e');
    }
  }

  /// Génère un token (Pour les professeurs)
  Future<String> generateToken(String moduleId) async {
    final dio = await _authService.getAuthenticatedDio();
    try {
      final response = await dio.post(
        ApiConstants.attendanceToken,
        data: {'moduleId': moduleId},
      );
      return response.data['token'] as String;
    } catch (e) {
      throw Exception('Erreur lors de la génération du token: $e');
    }
  }
}
