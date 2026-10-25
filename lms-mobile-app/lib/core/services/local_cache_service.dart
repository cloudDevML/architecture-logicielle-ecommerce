import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCacheService {
  static final LocalCacheService _instance = LocalCacheService._internal();
  factory LocalCacheService() => _instance;
  LocalCacheService._internal();

  /// Sauvegarde des données JSON localement sous une clé spécifique
  Future<void> saveCache(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(data);
      await prefs.setString('lms_cache_$key', jsonString);
    } catch (_) {
      // Mode silencieux pour ne pas perturber l'expérience utilisateur
    }
  }

  /// Récupère les données JSON stockées localement
  Future<dynamic> getCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('lms_cache_$key');
      if (jsonString != null && jsonString.isNotEmpty) {
        return jsonDecode(jsonString);
      }
    } catch (_) {
      // Mode silencieux
    }
    return null;
  }

  /// Supprime un cache spécifique
  Future<void> clearCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('lms_cache_$key');
    } catch (_) {}
  }

  static const String _outboxKey = 'lms_outbox_queue';

  /// Ajoute une requête dans la file d'attente hors-ligne (Outbox)
  Future<void> addToOutbox(Map<String, dynamic> request) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final outboxString = prefs.getString(_outboxKey);
      List<dynamic> queue = [];
      if (outboxString != null && outboxString.isNotEmpty) {
        queue = jsonDecode(outboxString) as List<dynamic>;
      }
      queue.add(request);
      await prefs.setString(_outboxKey, jsonEncode(queue));
    } catch (_) {}
  }

  /// Récupère la liste ordonnée des requêtes hors-ligne (Outbox)
  Future<List<Map<String, dynamic>>> getOutbox() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final outboxString = prefs.getString(_outboxKey);
      if (outboxString != null && outboxString.isNotEmpty) {
        final list = jsonDecode(outboxString) as List<dynamic>;
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Supprime une requête spécifique de la file d'attente hors-ligne (Outbox)
  Future<void> removeFromOutbox(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final outboxString = prefs.getString(_outboxKey);
      if (outboxString != null && outboxString.isNotEmpty) {
        final list = jsonDecode(outboxString) as List<dynamic>;
        final filtered = list.where((e) => e['id'] != id).toList();
        await prefs.setString(_outboxKey, jsonEncode(filtered));
      }
    } catch (_) {}
  }
}

