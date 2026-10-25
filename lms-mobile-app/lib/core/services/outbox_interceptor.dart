import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../main.dart';
import 'local_cache_service.dart';

class OutboxInterceptor extends Interceptor {
  final LocalCacheService _cacheService = LocalCacheService();

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final method = err.requestOptions.method.toUpperCase();
    final isWriteRequest = method == 'POST' || method == 'PUT' || method == 'DELETE';

    bool isConnectionError = false;
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        isConnectionError = true;
        break;
      default:
        // Si le message d'erreur contient des indices de panne réseau (SocketException, etc.)
        final errMsg = err.message?.toLowerCase() ?? '';
        if (errMsg.contains('socketexception') || errMsg.contains('network') || errMsg.contains('failed to connect')) {
          isConnectionError = true;
        }
        break;
    }

    if (isWriteRequest && isConnectionError) {
      final uuid = DateTime.now().microsecondsSinceEpoch.toString();
      final url = err.requestOptions.path;
      
      String description = "Action enregistrée";
      if (url.contains('/api/message') || url.contains('/send')) {
        description = "Envoi de votre message";
      } else if (url.contains('/forum') || url.contains('/posts') || url.contains('/threads')) {
        description = "Publication sur le forum";
      } else if (url.contains('/quizzes/submit') || url.contains('/submission')) {
        description = "Validation de votre évaluation";
      } else if (url.contains('/attendance') || url.contains('/scan')) {
        description = "Enregistrement de votre présence";
      }

      // Convert body to a clean format
      dynamic payload = err.requestOptions.data;
      String? serializedPayload;
      if (payload != null) {
        try {
          if (payload is Map || payload is List) {
            serializedPayload = jsonEncode(payload);
          } else {
            serializedPayload = payload.toString();
          }
        } catch (_) {
          serializedPayload = payload.toString();
        }
      }

      // Headers (sans Authorization car le token peut expirer d'ici la resync, on réinjectera le token frais à la volée !)
      final headers = Map<String, dynamic>.from(err.requestOptions.headers);
      headers.remove('Authorization');

      final requestData = {
        'id': uuid,
        'url': url,
        'method': method,
        'payload': serializedPayload,
        'headers': headers,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'description': description,
      };

      // Sauvegarde locale dans l'outbox
      await _cacheService.addToOutbox(requestData);
      debugPrint('[OutboxInterceptor] Requête hors-ligne enregistrée dans la file d\'attente ($description)');

      // Notification visuelle de secours
      _showOfflineActionSnackbar(description);

      // Résolution fictive (202 Accepted) pour éviter le crash de l'UI
      final mockResponse = Response(
        requestOptions: err.requestOptions,
        statusCode: 202,
        data: {
          'status': 'ACCEPTED_OFFLINE',
          'id': uuid,
          'message': 'Requête sauvegardée hors-ligne.',
          'offline': true,
        },
      );
      
      return handler.resolve(mockResponse);
    }

    return handler.next(err);
  }

  void _showOfflineActionSnackbar(String description) {
    globalMessengerKey.currentState?.clearSnackBars();
    globalMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.amber, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$description (Hors-ligne)',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Enregistré en local. Synchronisation automatique au retour du réseau.',
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blueGrey.shade900,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
