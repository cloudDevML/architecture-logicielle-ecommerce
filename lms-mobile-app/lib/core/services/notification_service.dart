import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import '../constants/api_constants.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? _fcm;
  final AuthService _authService = AuthService();

  Future<void> initialize() async {
    // Désactivé temporairement pour iOS Free Account (Signature error)
    debugPrint('NotificationService: Firebase temporairement désactivé');
    return;

    try {
      _fcm = FirebaseMessaging.instance;
      
      // 1. Demander les permissions (iOS/Android 13+)
      NotificationSettings settings = await _fcm!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted notification permission');
        
        // 2. Récupérer le Token
        String? token = await _fcm!.getToken();
        if (token != null) {
          debugPrint('FCM Token: $token');
          await _saveTokenToBackend(token);
        }

        // 3. Écouter les messages au premier plan
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Got a message whilst in the foreground!');
          if (message.notification != null) {
            _showInAppNotification(message);
          }
        });

        // 4. Gérer le clic sur la notification
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint('Notification clicked!');
          // Naviguer vers l'écran approprié si besoin
        });
      }
    } catch (e) {
      debugPrint('NotificationService error: $e');
    }
  }

  Future<void> _saveTokenToBackend(String token) async {
    final username = await _authService.getUsername();
    if (username == null) return;

    try {
      final dio = await _authService.getAuthenticatedDio();
      await dio.post(
        '${ApiConstants.baseUrl}/api/user/notifications/token',
        data: {
          'username': username,
          'token': token,
          'deviceType': 'MOBILE',
        },
      );
    } catch (e) {
      debugPrint('Error saving FCM token to backend: $e');
    }
  }

  void _showInAppNotification(RemoteMessage message) {
    // On pourrait utiliser un package comme flutter_local_notifications ou overlay_support
    // Pour l'instant, on affiche un simple log ou on laisse le système gérer
  }
}
