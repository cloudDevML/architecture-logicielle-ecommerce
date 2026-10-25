import '../../core/constants/api_constants.dart';
import '../../core/services/auth_service.dart';
import 'local_cache_service.dart';

// ── Modèle d'Annonce (Global & Riche) ───────────────────────────────────
class AnnouncementModel {
  final int id;
  final String title;
  final String content;
  final String authorName;
  final DateTime createdAt;
  final String? type; // assignment, exam, event, maintenance
  final String? targetAudience;
  final String? targetId;
  final DateTime? dueDate;
  final String? location;
  final String? instructor;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.content,
    required this.authorName,
    required this.createdAt,
    this.type,
    this.targetAudience,
    this.targetId,
    this.dueDate,
    this.location,
    this.instructor,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      content: json['description'] as String? ?? json['content'] as String? ?? '',
      authorName: json['assignmentInstructor'] as String? ?? json['authorName'] as String? ?? 'Admin',
      createdAt: json['createdDate'] != null
          ? DateTime.tryParse(json['createdDate'].toString()) ?? DateTime.now()
          : (json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now() : DateTime.now()),
      type: json['type'] as String?,
      targetAudience: json['targetAudience'] as String?,
      targetId: json['targetId']?.toString(),
      dueDate: json['assignmentDueDate'] != null || json['examDate'] != null || json['eventDate'] != null
          ? DateTime.tryParse((json['assignmentDueDate'] ?? json['examDate'] ?? json['eventDate']).toString())
          : null,
      location: (json['examLocation'] ?? json['eventLocation']) as String?,
      instructor: (json['assignmentInstructor'] ?? json['examInstructor'] ?? json['authorName']) as String?,
    );
  }
}

// ── Modèle de Notification (Personnel) ──────────────────────────────────
class NotificationModel {
  final int id;
  final String userId;
  final String title;
  final String content;
  final bool read;
  final String? type; // QUIZ, GRADE, COURSE, etc.
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.read,
    this.type,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id:        json['id'] as int? ?? 0,
      userId:    json['userId'] as String? ?? '',
      title:     json['title'] as String? ?? '',
      content:   json['content'] as String? ?? '',
      read:      json['read'] as bool? ?? false,
      type:      json['type'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class AnnouncementService {
  final AuthService _authService = AuthService();

  // ── Annonces Globales & Contextuelles ──
  Future<List<AnnouncementModel>> getAnnouncements() async {
    final dio = await _authService.getAuthenticatedDio();
    final username = await _authService.getUsername();
    if (username == null) return [];

    try {
      // 1. Get student details to get their classId
      final studentRes = await dio.get('${ApiConstants.studentDetails}/$username/username');
      final String? classId = studentRes.data['classId']?.toString();

      // 2. Get student modules for UE codes
      final modulesRes = await dio.get('${ApiConstants.studentModules}/$username/modules');
      final List modules = modulesRes.data is List ? modulesRes.data : [];
      final Set<String> ueCodes = modules
          .map((m) => m['teachingUnit']?['code']?.toString())
          .where((c) => c != null)
          .cast<String>()
          .toSet();

      // 3. Fetch all in parallel (Class, UEs, Global)
      final List<Future<dynamic>> futures = [];
      
      // Global
      futures.add(dio.get(ApiConstants.announcements, queryParameters: {'targetAudience': '', 'targetId': ''}));
      
      // By Class
      if (classId != null) {
        futures.add(dio.get(ApiConstants.announcements, queryParameters: {'targetAudience': '', 'targetId': classId}));
      }
      
      // By UE
      for (var code in ueCodes) {
        futures.add(dio.get(ApiConstants.announcements, queryParameters: {'targetAudience': code, 'targetId': ''}));
      }

      final results = await Future.wait(futures);
      final Map<int, AnnouncementModel> merged = {};

      for (var res in results) {
        if (res.data is List) {
          for (var item in res.data) {
            final ann = AnnouncementModel.fromJson(item);
            merged[ann.id] = ann;
          }
        }
      }

      final list = merged.values.toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Sauvegarder dans le cache local
      final cachedData = list.map((ann) => {
        'id': ann.id,
        'title': ann.title,
        'description': ann.content,
        'authorName': ann.authorName,
        'createdDate': ann.createdAt.toIso8601String(),
        'type': ann.type,
        'targetAudience': ann.targetAudience,
        'targetId': ann.targetId,
        'assignmentDueDate': ann.dueDate?.toIso8601String(),
        'examLocation': ann.location,
        'examInstructor': ann.instructor,
      }).toList();
      LocalCacheService().saveCache('announcements_$username', cachedData);

      return list;
    } catch (e) {
      // Fallback: simple fetch if something fails
      final response = await dio.get('${ApiConstants.baseUrl}/api/announcement/all');
      final List data = response.data is List ? response.data : [];
      final list = data.map((e) => AnnouncementModel.fromJson(e)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Sauvegarder le fallback
      final cachedData = list.map((ann) => {
        'id': ann.id,
        'title': ann.title,
        'description': ann.content,
        'authorName': ann.authorName,
        'createdDate': ann.createdAt.toIso8601String(),
        'type': ann.type,
        'targetAudience': ann.targetAudience,
        'targetId': ann.targetId,
        'assignmentDueDate': ann.dueDate?.toIso8601String(),
        'examLocation': ann.location,
        'examInstructor': ann.instructor,
      }).toList();
      LocalCacheService().saveCache('announcements_$username', cachedData);

      return list;
    }
  }

  /// Récupère les annonces en cache
  Future<List<AnnouncementModel>> getCachedAnnouncements() async {
    final username = await _authService.getUsername();
    if (username == null) return [];
    try {
      final data = await LocalCacheService().getCache('announcements_$username');
      if (data is List) {
        return data.map((e) => AnnouncementModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  // ── Notifications Personnelles ──
  Future<List<NotificationModel>> getNotifications() async {
    final dio = await _authService.getAuthenticatedDio();
    final username = await _authService.getUsername();
    if (username == null) return [];
    
    final response = await dio.get('${ApiConstants.baseUrl}/api/announcement/notifications/user/$username');
    final List data = response.data is List ? response.data : [];
    return data.map((e) => NotificationModel.fromJson(e)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> markAsRead(int id) async {
    final dio = await _authService.getAuthenticatedDio();
    await dio.put('${ApiConstants.baseUrl}/api/announcement/notifications/$id/read');
  }

  Future<void> markAllAsRead() async {
    final dio = await _authService.getAuthenticatedDio();
    final username = await _authService.getUsername();
    if (username == null) return;
    await dio.put('${ApiConstants.baseUrl}/api/announcement/notifications/user/$username/read-all');
  }

  Future<void> deleteNotification(int id) async {
    final dio = await _authService.getAuthenticatedDio();
    await dio.delete('${ApiConstants.baseUrl}/api/announcement/notifications/$id');
  }
}
