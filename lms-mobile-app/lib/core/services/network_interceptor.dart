import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../main.dart';
import '../providers/auth_provider.dart';
import '../constants/api_constants.dart';

class NetworkInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    String message = '';
    bool isConnectionError = false;
    bool isAuthError = false;

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = "Le serveur met trop de temps à répondre. Vérifiez votre connexion.";
        isConnectionError = true;
        break;
      case DioExceptionType.connectionError:
        message = "Impossible de se connecter au serveur. Vérifiez votre accès internet.";
        isConnectionError = true;
        break;
      case DioExceptionType.badResponse:
        if (err.response?.statusCode == 401) {
          // 1. Tenter un rafraîchissement silencieux
          const storage = FlutterSecureStorage();
          final refreshToken = await storage.read(key: 'refresh_token');
          if (refreshToken != null && refreshToken.isNotEmpty) {
            try {
              debugPrint('[NetworkInterceptor] Access token expiré. Tentative de rafraîchissement silencieux...');
              final refreshDio = Dio();
              final refreshResponse = await refreshDio.post(
                ApiConstants.keycloakToken,
                data: {
                  'client_id': 'lms-web',
                  'grant_type': 'refresh_token',
                  'refresh_token': refreshToken,
                },
                options: Options(
                  contentType: 'application/x-www-form-urlencoded',
                ),
              );

              if (refreshResponse.statusCode == 200) {
                final data = refreshResponse.data;
                final newAccess = data['access_token'] as String? ?? '';
                final newRefresh = data['refresh_token'] as String? ?? '';

                if (newAccess.isNotEmpty) {
                  await storage.write(key: 'jwt_token', value: newAccess);
                  if (newRefresh.isNotEmpty) {
                    await storage.write(key: 'refresh_token', value: newRefresh);
                  }
                  debugPrint('[NetworkInterceptor] Refresh token réussi ! Rejeu de la requête...');

                  // Rejouer la requête d'origine avec le nouveau token
                  final options = err.requestOptions;
                  options.headers['Authorization'] = 'Bearer $newAccess';

                  final retryDio = Dio();
                  try {
                    final response = await retryDio.request(
                      options.path,
                      data: options.data,
                      queryParameters: options.queryParameters,
                      options: Options(
                        method: options.method,
                        headers: options.headers,
                        contentType: options.contentType,
                      ),
                    );
                    return handler.resolve(response);
                  } catch (retryErr) {
                    // Si le rejeu échoue avec une autre erreur, on propage cette erreur
                    if (retryErr is DioException) {
                      return handler.next(retryErr);
                    }
                    return handler.next(err);
                  }
                }
              }
            } catch (e) {
              if (e is DioException) {
                debugPrint('[NetworkInterceptor] Échec du rafraîchissement silencieux: Status=${e.response?.statusCode}, Body=${e.response?.data}');
              } else {
                debugPrint('[NetworkInterceptor] Échec du rafraîchissement silencieux : $e');
              }
            }
          }

          // Si le refresh a échoué ou s'il n'y avait pas de refresh_token, on procède à la déconnexion
          message = "Votre session a expiré. Veuillez vous reconnecter.";
          isAuthError = true;
          
          final context = globalNavigatorKey.currentContext;
          if (context != null && context.mounted) {
            Future.microtask(() {
              try {
                Provider.of<AuthProvider>(context, listen: false).logout();
              } catch (e) {
                debugPrint('Erreur lors du logout automatique (session expirée): $e');
              }
            });
          }
        }
        break;
      default:
        break;
    }

    if ((isConnectionError || isAuthError) && message.isNotEmpty) {
      _showGlobalError(message, isAuthError: isAuthError);
    }

    return handler.next(err);
  }

  void _showGlobalError(String message, {bool isAuthError = false}) {
    globalMessengerKey.currentState?.clearSnackBars();
    globalMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isAuthError ? Icons.lock_outline_rounded : Icons.wifi_off_rounded, 
              color: Colors.white
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isAuthError ? Colors.red.shade900 : Colors.orange.shade900,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
