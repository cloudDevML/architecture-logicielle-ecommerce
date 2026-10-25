import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../constants/api_constants.dart';
import 'auth_service.dart';
import 'local_cache_service.dart';

class OutboxService {
  static final LocalCacheService _cacheService = LocalCacheService();
  static final AuthService _authService = AuthService();
  static bool _isSyncing = false;
  static Timer? _syncTimer;

  /// Lance le démon de synchronisation périodique (toutes les 30 secondes)
  static void startOutboxSyncTimer() {
    if (_syncTimer != null) return;
    
    debugPrint('[OutboxService] Démarre le démon de synchronisation hors-ligne...');
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await syncOutbox();
    });

    // Déclencher une première tentative immédiate au lancement
    Future.delayed(const Duration(seconds: 5), () => syncOutbox());
  }

  /// Arrête le démon
  static void stopOutboxSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Procède à la vérification et au dépilage de la queue Outbox
  static Future<void> syncOutbox() async {
    if (_isSyncing) return;

    final queue = await _cacheService.getOutbox();
    if (queue.isEmpty) return;

    _isSyncing = true;
    debugPrint('[OutboxService] Détecté ${queue.length} requêtes en attente. Vérification réseau...');

    try {
      // 1. Prober de connectivité active (HEAD ultra-léger sur les contacts avec timeout de 3s)
      final probeDio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
      ));
      
      final token = await _authService.getToken();
      final probeUrl = '${ApiConstants.baseUrl}/api/user/contacts';
      
      await probeDio.get(
        probeUrl,
        options: Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      
      debugPrint('[OutboxService] Connexion au serveur validée avec succès ! Début du dépilage...');

      int successfulSyncs = 0;

      // 2. Dépilage chronologique
      for (final req in queue) {
        final reqId = req['id'] as String;
        final url = req['url'] as String;
        final method = req['method'] as String;
        final payload = req['payload'] as String?;
        final description = req['description'] as String;

        // S'assurer que les URLs relatives possèdent le bon hôte
        String finalUrl = url;
        if (!finalUrl.startsWith('http')) {
          finalUrl = '${ApiConstants.baseUrl}$finalUrl';
        }

        debugPrint('[OutboxService] Synchronisation : $description ($method $finalUrl)...');

        final reqDio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ));

        // Récupérer un token frais
        final freshToken = await _authService.getToken();
        final headers = Map<String, dynamic>.from(req['headers'] ?? {});
        if (freshToken != null) {
          headers['Authorization'] = 'Bearer $freshToken';
        }

        try {
          final response = await reqDio.request(
            finalUrl,
            data: payload != null ? jsonDecode(payload) : null,
            options: Options(
              method: method,
              headers: headers,
            ),
          );

          if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
            await _cacheService.removeFromOutbox(reqId);
            successfulSyncs++;
            debugPrint('[OutboxService] Synchronisation réussie pour $reqId');
          }
        } catch (e) {
          if (e is DioException) {
            // Si c'est à nouveau un problème de connexion, on arrête le traitement pour cette fois
            if (e.type == DioExceptionType.connectionTimeout || 
                e.type == DioExceptionType.connectionError ||
                e.type == DioExceptionType.sendTimeout ||
                e.type == DioExceptionType.receiveTimeout) {
              debugPrint('[OutboxService] Perte de connexion réseau pendant la resync. Arrêt de la file.');
              break;
            }
            
            // Si c'est une erreur sémantique (400, 500, etc.), on supprime pour ne pas bloquer indéfiniment la queue
            debugPrint('[OutboxService] Erreur serveur ($e) pour $reqId. Requête écartée de la queue pour éviter les blocages.');
            await _cacheService.removeFromOutbox(reqId);
          } else {
            debugPrint('[OutboxService] Erreur inattendue ($e). Requête écartée.');
            await _cacheService.removeFromOutbox(reqId);
          }
        }
      }

      // 3. Notification finale en cas de réussite
      if (successfulSyncs > 0) {
        _showSyncSuccessSnackbar(successfulSyncs);
      }
    } catch (e) {
      debugPrint('[OutboxService] Serveur ou réseau indisponible lors du probe : $e');
    } finally {
      _isSyncing = false;
    }
  }

  static void _showSyncSuccessSnackbar(int count) {
    globalMessengerKey.currentState?.clearSnackBars();
    globalMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cloud_done_rounded, color: Colors.green, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Synchronisation terminée ! 🎉',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count action${count > 1 ? "s" : ""} hors-ligne enregistrée${count > 1 ? "s" : ""} a${count > 1 ? "ont" : ""} été transmise${count > 1 ? "s" : ""} au serveur.',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.teal.shade900,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
