import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import 'auth_service.dart';

class Certificate {
  final int id;
  final int studentId;
  final int? courseId;
  final String? courseName;
  final String? courseCode;
  final int? moduleId;
  final String? urlPdf;
  final String codeVerification;
  final DateTime dateEmission;

  Certificate({
    required this.id,
    required this.studentId,
    this.courseId,
    this.courseName,
    this.courseCode,
    this.moduleId,
    this.urlPdf,
    required this.codeVerification,
    required this.dateEmission,
  });

  factory Certificate.fromJson(Map<String, dynamic> json) {
    final course = json['course'] as Map<String, dynamic>?;
    
    return Certificate(
      id: json['id'] ?? 0,
      studentId: json['studentId'] ?? 0,
      courseId: course?['id'],
      courseName: course?['name'],
      courseCode: course?['code'],
      moduleId: json['moduleId'],
      urlPdf: json['urlPdf'],
      codeVerification: json['codeVerification'] ?? '',
      dateEmission: DateTime.tryParse(json['dateEmission'] ?? '') ?? DateTime.now(),
    );
  }
}

class CertificateService {
  final AuthService _authService = AuthService();

  Future<List<Certificate>> getStudentCertificates(String studentId) async {
    try {
      final dio = await _authService.getAuthenticatedDio();
      final response = await dio.get('${ApiConstants.baseUrl}/api/course/certificat/student/$studentId');
      
      if (response.data is List) {
        return (response.data as List)
            .map((e) => Certificate.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching certificates: $e');
      return [];
    }
  }

  Future<Certificate?> verifyCertificate(String code) async {
    try {
      final dio = await _authService.getAuthenticatedDio();
      final response = await dio.get('${ApiConstants.baseUrl}/api/course/certificat/verify/$code');
      
      if (response.data != null) {
        return Certificate.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Error verifying certificate: $e');
      return null;
    }
  }
}
