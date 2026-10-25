import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import 'auth_service.dart';
import 'local_cache_service.dart';

class GamificationProfile {
  final String username;
  final int level;
  final int xpPoints;
  final int currentStreak;
  final List<String> badges;
  final Map<String, int> skillScores;

  GamificationProfile({
    required this.username,
    required this.level,
    required this.xpPoints,
    required this.currentStreak,
    required this.badges,
    required this.skillScores,
  });

  factory GamificationProfile.fromJson(Map<String, dynamic> json) {
    return GamificationProfile(
      username: json['username'] ?? '',
      level: json['level'] ?? 1,
      xpPoints: json['xpPoints'] ?? 0,
      currentStreak: json['currentStreak'] ?? 0,
      badges: (json['badges'] as List?)?.map((e) => e.toString()).toList() ?? [],
      skillScores: json['skillScores'] != null
          ? Map<String, int>.from(json['skillScores'])
          : {},
    );
  }

  String get levelName {
    const levelNames = {
      1: 'Novice',
      2: 'Apprenti',
      3: 'Étudiant',
      4: 'Avancé',
      5: 'Expert',
      6: 'Maître',
      7: 'Élite',
      8: 'Légende',
    };
    return levelNames[level] ?? 'Niveau $level';
  }
}

class LeaderboardEntry {
  final String username;
  final int level;
  final int xpPoints;
  final int currentStreak;
  final int rank;

  LeaderboardEntry({
    required this.username,
    required this.level,
    required this.xpPoints,
    required this.currentStreak,
    required this.rank,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json, int rank) {
    return LeaderboardEntry(
      username: json['username'] ?? '',
      level: json['level'] ?? 1,
      xpPoints: json['xpPoints'] ?? 0,
      currentStreak: json['currentStreak'] ?? 0,
      rank: rank,
    );
  }

  String get levelName {
    const levelNames = {
      1: 'Novice',
      2: 'Apprenti',
      3: 'Étudiant',
      4: 'Avancé',
      5: 'Expert',
      6: 'Maître',
      7: 'Élite',
      8: 'Légende',
    };
    return levelNames[level] ?? 'Niveau $level';
  }
}

class GamificationService {
  final AuthService _authService = AuthService();

  Future<GamificationProfile?> getProfile(String username) async {
    try {
      final dio = await _authService.getAuthenticatedDio();
      final response = await dio.get('${ApiConstants.baseUrl}/api/user/gamification/$username');
      
      if (response.data != null) {
        LocalCacheService().saveCache('gamification_profile_$username', response.data);
        return GamificationProfile.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching gamification profile: $e');
      return null;
    }
  }

  Future<GamificationProfile?> getCachedProfile(String username) async {
    try {
      final cached = await LocalCacheService().getCache('gamification_profile_$username');
      if (cached != null) {
        return GamificationProfile.fromJson(Map<String, dynamic>.from(cached as Map));
      }
    } catch (e) {
      debugPrint('Error getting cached gamification profile: $e');
    }
    return null;
  }

  Future<List<LeaderboardEntry>> getLeaderboard() async {
    try {
      final dio = await _authService.getAuthenticatedDio();
      final response = await dio.get('${ApiConstants.baseUrl}/api/user/gamification/leaderboard');
      
      if (response.data is List) {
        LocalCacheService().saveCache('gamification_leaderboard', response.data);
        return (response.data as List)
            .asMap()
            .entries
            .map((entry) => LeaderboardEntry.fromJson(
                  entry.value as Map<String, dynamic>,
                  entry.key + 1,
                ))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
      return [];
    }
  }

  Future<List<LeaderboardEntry>> getCachedLeaderboard() async {
    try {
      final cached = await LocalCacheService().getCache('gamification_leaderboard');
      if (cached is List) {
        return cached
            .asMap()
            .entries
            .map((entry) => LeaderboardEntry.fromJson(
                  Map<String, dynamic>.from(entry.value as Map),
                  entry.key + 1,
                ))
            .toList();
      }
    } catch (e) {
      debugPrint('Error getting cached leaderboard: $e');
    }
    return [];
  }

  Future<bool> recordLoginStreak(String username) async {
    try {
      final dio = await _authService.getAuthenticatedDio();
      await dio.post('${ApiConstants.baseUrl}/api/user/gamification/$username/login');
      return true;
    } catch (e) {
      debugPrint('Error recording login streak: $e');
      return false;
    }
  }
}
