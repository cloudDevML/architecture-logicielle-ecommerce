import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import 'auth_service.dart';
import 'local_cache_service.dart';

class TimetableEntry {
  final int? id;
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final String courseName;
  final String? teacherName;
  final String type;
  final bool online;

  TimetableEntry({
    this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.courseName,
    this.teacherName,
    required this.type,
    required this.online,
  });

  factory TimetableEntry.fromJson(Map<String, dynamic> json) {
    return TimetableEntry(
      id: json['id'],
      dayOfWeek: json['dayOfWeek'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      courseName: json['courseName'] ?? '',
      teacherName: json['teacherName'],
      type: json['type'] ?? '',
      online: json['online'] == true,
    );
  }
}

class Timetable {
  final int id;
  final String classId;
  final DateTime startDate;
  final DateTime endDate;
  final List<TimetableEntry> entries;
  final bool published;

  Timetable({
    required this.id,
    required this.classId,
    required this.startDate,
    required this.endDate,
    required this.entries,
    required this.published,
  });

  factory Timetable.fromJson(Map<String, dynamic> json) {
    return Timetable(
      id: json['id'] ?? 0,
      classId: json['classId'] ?? '',
      startDate: DateTime.tryParse(json['startDate'] ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['endDate'] ?? '') ?? DateTime.now(),
      entries: (json['entries'] as List?)
              ?.map((e) => TimetableEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      published: json['published'] == true,
    );
  }
}

class TimetableService {
  final AuthService _authService = AuthService();

  Future<Timetable?> getLatestTimetable(String classId) async {
    try {
      final dio = await _authService.getAuthenticatedDio();
      final response = await dio.get('${ApiConstants.timetableLatest}/$classId/latest');
      
      if (response.data != null) {
        // Enregistrer le JSON brut dans le cache pour le hors-ligne
        LocalCacheService().saveCache('timetable_$classId', response.data);
        return Timetable.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching timetable: $e');
      return null;
    }
  }

  /// Récupère l'emploi du temps stocké localement
  Future<Timetable?> getCachedTimetable(String classId) async {
    try {
      final data = await LocalCacheService().getCache('timetable_$classId');
      if (data != null) {
        return Timetable.fromJson(data as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Error loading cached timetable: $e');
    }
    return null;
  }
}
