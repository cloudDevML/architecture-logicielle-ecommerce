import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/services/auth_service.dart';
import 'local_cache_service.dart';

class StudentAnalytics {
  final double overallAverage;
  final double highestScore;
  final double lowestScore;
  final int totalModules;
  final List<ModuleScore> progression;

  StudentAnalytics({
    required this.overallAverage,
    required this.highestScore,
    required this.lowestScore,
    required this.totalModules,
    required this.progression,
  });

  factory StudentAnalytics.fromJson(Map<String, dynamic> json) {
    return StudentAnalytics(
      overallAverage: (json['overallAverage'] as num).toDouble(),
      highestScore: (json['highestScore'] as num).toDouble(),
      lowestScore: (json['lowestScore'] as num).toDouble(),
      totalModules: json['totalModules'] as int,
      progression: (json['progression'] as List)
          .map((item) => ModuleScore.fromJson(item))
          .toList(),
    );
  }
}

class ModuleScore {
  final String moduleCode;
  final double score;
  final double classAverage;

  ModuleScore({
    required this.moduleCode, 
    required this.score,
    required this.classAverage,
  });

  factory ModuleScore.fromJson(Map<String, dynamic> json) {
    return ModuleScore(
      moduleCode: json['moduleCode'],
      score: (json['score'] as num).toDouble(),
      classAverage: (json['classAverage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Lacune {
  final int id;
  final String competence;
  final int moduleId;
  final String? moduleName;
  final int studentId;
  final DateTime createdAt;

  Lacune({
    required this.id,
    required this.competence,
    required this.moduleId,
    this.moduleName,
    required this.studentId,
    required this.createdAt,
  });

  factory Lacune.fromJson(Map<String, dynamic> json) {
    return Lacune(
      id: json['id'] ?? 0,
      competence: json['competence'] ?? '',
      moduleId: json['moduleId'] ?? 0,
      moduleName: json['moduleName'],
      studentId: json['studentId'] ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class ProfilAdaptatif {
  final String? niveauGlobal;
  final double? classeMoyenne;
  final Map<String, String>? competences;
  final DateTime? dernierMisAJour;

  ProfilAdaptatif({
    this.niveauGlobal,
    this.classeMoyenne,
    this.competences,
    this.dernierMisAJour,
  });

  factory ProfilAdaptatif.fromJson(Map<String, dynamic> json) {
    return ProfilAdaptatif(
      niveauGlobal: json['niveauGlobal'],
      classeMoyenne: (json['classeMoyenne'] as num?)?.toDouble(),
      competences: json['competences'] != null
          ? Map<String, String>.from(json['competences'])
          : null,
      dernierMisAJour: json['dernierMisAJour'] != null
          ? DateTime.tryParse(json['dernierMisAJour'])
          : null,
    );
  }
}

class Recommandation {
  final int id;
  final String typeReco;
  final String cibleId;
  final String? raison;
  final bool vue;
  final DateTime createdAt;

  Recommandation({
    required this.id,
    required this.typeReco,
    required this.cibleId,
    this.raison,
    required this.vue,
    required this.createdAt,
  });

  factory Recommandation.fromJson(Map<String, dynamic> json) {
    return Recommandation(
      id: json['id'] ?? 0,
      typeReco: json['typeReco'] ?? '',
      cibleId: json['cibleId']?.toString() ?? '',
      raison: json['raison'],
      vue: json['vue'] ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class AnalyticsService {
  final AuthService _authService = AuthService();

  Future<StudentAnalytics?> getStudentAnalytics(int studentId) async {
    try {
      final token = await _authService.getToken();
      final response = await http.get(
        Uri.parse('${ApiConstants.studentAnalytics}/$studentId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        LocalCacheService().saveCache('analytics_student_grades_$studentId', decoded);
        return StudentAnalytics.fromJson(decoded);
      }
      debugPrint('[AnalyticsService] getStudentAnalytics failed status=${response.statusCode}');
      return null;
    } catch (e, st) {
      debugPrint('[AnalyticsService] Error fetching student analytics: $e\n$st');
      return null;
    }
  }

  Future<StudentAnalytics?> getCachedStudentAnalytics(int studentId) async {
    try {
      final cached = await LocalCacheService().getCache('analytics_student_grades_$studentId');
      if (cached != null) {
        return StudentAnalytics.fromJson(Map<String, dynamic>.from(cached as Map));
      }
    } catch (e) {
      debugPrint('Error getting cached student analytics: $e');
    }
    return null;
  }

  Future<List<Lacune>> getLacunes(String username) async {
    try {
      final dio = await _authService.getAuthenticatedDio();
      final response = await dio.get('${ApiConstants.baseUrl}/api/course/lacune/student/$username');
      
      if (response.data is List) {
        LocalCacheService().saveCache('analytics_lacunes_$username', response.data);
        return (response.data as List)
            .map((e) => Lacune.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching lacunes: $e');
      return [];
    }
  }

  Future<List<Lacune>> getCachedLacunes(String username) async {
    try {
      final cached = await LocalCacheService().getCache('analytics_lacunes_$username');
      if (cached is List) {
        return cached.map((e) => Lacune.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
    } catch (e) {
      debugPrint('Error getting cached lacunes: $e');
    }
    return [];
  }

  Future<ProfilAdaptatif?> getProfilAdaptatif(String username) async {
    try {
      final dio = await _authService.getAuthenticatedDio();
      final response = await dio.get('${ApiConstants.profilAdaptatif}/$username/profil-adaptatif');
      if (response.data != null) {
        LocalCacheService().saveCache('analytics_profil_adaptatif_$username', response.data);
        return ProfilAdaptatif.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching profil adaptatif: $e');
      return null;
    }
  }

  Future<ProfilAdaptatif?> getCachedProfilAdaptatif(String username) async {
    try {
      final cached = await LocalCacheService().getCache('analytics_profil_adaptatif_$username');
      if (cached != null) {
        return ProfilAdaptatif.fromJson(Map<String, dynamic>.from(cached as Map));
      }
    } catch (e) {
      debugPrint('Error getting cached profil adaptatif: $e');
    }
    return null;
  }

  Future<List<Recommandation>> getRecommandations(String username) async {
    try {
      final dio = await _authService.getAuthenticatedDio();
      final response = await dio.get('${ApiConstants.recommandations}/$username/recommandations');
      if (response.data is List) {
        LocalCacheService().saveCache('analytics_recommandations_$username', response.data);
        return (response.data as List)
            .map((e) => Recommandation.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching recommandations: $e');
      return [];
    }
  }

  Future<List<Recommandation>> getCachedRecommandations(String username) async {
    try {
      final cached = await LocalCacheService().getCache('analytics_recommandations_$username');
      if (cached is List) {
        return cached.map((e) => Recommandation.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
    } catch (e) {
      debugPrint('Error getting cached recommandations: $e');
    }
    return [];
  }

  Future<bool> markRecommandationAsVue(int id) async {
    try {
      final dio = await _authService.getAuthenticatedDio();
      await dio.put('${ApiConstants.markRecoAsVue}/$id/view');
      return true;
    } catch (e) {
      debugPrint('Error marking recommandation as vue: $e');
      return false;
    }
  }

  Future<List<dynamic>> getRecommendedModules(String studentId) async {
    try {
      final dio = await _authService.getAuthenticatedDio();
      final response = await dio.get('${ApiConstants.recommendedModules}/$studentId');
      if (response.data is List) {
        LocalCacheService().saveCache('analytics_recommended_modules_$studentId', response.data);
        return response.data as List;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching recommended modules: $e');
      return [];
    }
  }

  Future<List<dynamic>> getCachedRecommendedModules(String studentId) async {
    try {
      final cached = await LocalCacheService().getCache('analytics_recommended_modules_$studentId');
      if (cached is List) {
        return cached;
      }
    } catch (e) {
      debugPrint('Error getting cached recommended modules: $e');
    }
    return [];
  }
}
