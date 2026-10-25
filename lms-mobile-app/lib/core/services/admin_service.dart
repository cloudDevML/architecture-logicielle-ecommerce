
import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/auth_service.dart';

class AdminService {
  final AuthService _authService = AuthService();

  Future<List<dynamic>> getAllLogs() async {
    final dio = await _authService.getAuthenticatedDio();
    
    // Récupérer les logs des deux services en parallèle
    final results = await Future.wait([
      dio.get('${ApiConstants.baseUrl}/api/user/logs').catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: [])),
      dio.get('${ApiConstants.baseUrl}/api/course/logs').catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: [])),
    ]);

    final List<dynamic> userLogs = results[0].data is List ? results[0].data : [];
    final List<dynamic> courseLogs = results[1].data is List ? results[1].data : [];

    // Fusionner et trier par date décroissante
    final allLogs = [...userLogs, ...courseLogs];
    allLogs.sort((a, b) {
      final dateA = DateTime.parse(a['timestamp'] ?? DateTime.now().toIso8601String());
      final dateB = DateTime.parse(b['timestamp'] ?? DateTime.now().toIso8601String());
      return dateB.compareTo(dateA);
    });

    return allLogs;
  }

  Future<List<dynamic>> getLogsByUsername(String username) async {
    final dio = await _authService.getAuthenticatedDio();
    
    final results = await Future.wait([
      dio.get('${ApiConstants.baseUrl}/api/user/logs/user/$username').catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: [])),
      dio.get('${ApiConstants.baseUrl}/api/course/logs/user/$username').catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: [])),
    ]);

    final List<dynamic> userLogs = results[0].data is List ? results[0].data : [];
    final List<dynamic> courseLogs = results[1].data is List ? results[1].data : [];

    final allLogs = [...userLogs, ...courseLogs];
    allLogs.sort((a, b) {
      final dateA = DateTime.parse(a['timestamp'] ?? DateTime.now().toIso8601String());
      final dateB = DateTime.parse(b['timestamp'] ?? DateTime.now().toIso8601String());
      return dateB.compareTo(dateA);
    });

    return allLogs;
  }
}
