import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import 'auth_service.dart';
import 'message_service.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  StompClient? _client;
  final _messageStreamController = StreamController<MessageModel>.broadcast();
  Stream<MessageModel> get messageStream => _messageStreamController.stream;

  final _authService = AuthService();
  bool _connected = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;

  // Module meeting topic subscriptions (int keyed)
  final Map<int, void Function(Map<String, dynamic>)> _pendingModuleCallbacks = {};
  final Map<int, void Function()> _moduleUnsubFns = {};

  // Generic named topic subscriptions (string keyed)
  final Map<String, String> _pendingTopicDestinations = {};
  final Map<String, void Function(Map<String, dynamic>)> _pendingTopicCallbacks = {};
  final Map<String, void Function()> _namedTopicUnsubFns = {};

  // Registry persists across reconnects so topics are re-subscribed automatically
  final Map<String, ({String destination, void Function(Map<String, dynamic>) callback})> _topicRegistry = {};
  final Map<int, void Function(Map<String, dynamic>)> _moduleRegistry = {};

  bool get isConnected => _connected;

  void connect() async {
    if (_connected) {
      debugPrint('WS: Already connected, skipping');
      return;
    }
    if (_isConnecting) {
      debugPrint('WS: Connection already in progress, skipping');
      return;
    }
    _isConnecting = true;
    _reconnectTimer?.cancel();

    final username = await _authService.getUsername();
    
    // Proactively refresh the token before establishing WebSocket to avoid 401 errors
    String? token;
    try {
      final refreshToken = await _authService.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        debugPrint('WS: Proactively refreshing token before WS connection...');
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ));
        final response = await dio.post(
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
        if (response.statusCode == 200 && response.data != null) {
          final newAccess = response.data['access_token'] as String? ?? '';
          final newRefresh = response.data['refresh_token'] as String? ?? '';
          if (newAccess.isNotEmpty) {
            await _authService.saveTokens(newAccess, newRefresh);
            token = newAccess;
            debugPrint('WS: Token successfully refreshed proactively!');
          }
        }
      }
    } catch (e) {
      debugPrint('WS: Proactive token refresh failed: $e');
    }

    // Fallback to stored token if proactive refresh failed
    token ??= await _authService.getToken();

    if (username == null || token == null) {
      debugPrint('WS: Missing username or token, aborting');
      _isConnecting = false;
      return;
    }

    debugPrint('WS: Connecting for user=$username, token=${token.substring(0, 10)}...');

    // stomp_dart_client uses native STOMP-over-WebSocket (no SockJS framing).
    // Backend exposes a dedicated /ws-stomp endpoint (no .withSockJS()) for native clients.
    // /ws-announcement is reserved for the web SockJS client.
    String wsUrl = '${ApiConstants.baseUrl.replaceFirst('http', 'ws')}/ws-stomp';
    // Proactively append port to avoid stomp_dart_client :0 port fallback bug
    if (!wsUrl.substring(wsUrl.indexOf('://') + 3).contains(':')) {
      final uri = Uri.parse(wsUrl);
      final port = uri.scheme == 'wss' ? 443 : 80;
      wsUrl = '${uri.scheme}://${uri.host}:$port${uri.path}';
    }
    debugPrint('WS: Connecting to $wsUrl');

    // Deactivate existing client to avoid leaks
    try {
      _client?.deactivate();
    } catch (_) {}
    _client = null;

    _client = StompClient(
      config: StompConfig(
        url: wsUrl,
        onConnect: (frame) => _onConnect(frame, username),
        onWebSocketError: (dynamic error) {
          debugPrint('WS WebSocketError: $error');
          _handleDisconnect();
        },
        onDisconnect: (_) {
          debugPrint('WS Disconnected');
          _handleDisconnect();
        },
        onStompError: (frame) {
          debugPrint('WS STOMP Error: ${frame.body}');
          _handleDisconnect();
        },
        // We use our custom manual reconnect with refreshed token instead of stomp internal reconnect
        reconnectDelay: Duration.zero,
        stompConnectHeaders: {
          'username': username,
          'Authorization': 'Bearer $token',
        },
        webSocketConnectHeaders: {
          // Send only lightweight HTTP headers during the initial WebSocket upgrade.
          // The massive JWT token is sent inside the STOMP protocol (stompConnectHeaders) 
          // to prevent reverse proxies (Nginx/Gateway) from throwing 400 Bad Request.
          'username': username,
        },
      ),
    );

    try {
      _client?.activate();
    } catch (e) {
      debugPrint('WS: Activation error: $e');
      _handleDisconnect();
    }
    _isConnecting = false;
  }

  void _onConnect(StompFrame frame, String username) {
    _connected = true;
    _reconnectTimer?.cancel();
    debugPrint('WS: STOMP Connected successfully for $username');

    _client?.subscribe(
      destination: '/user/$username/queue/messages',
      callback: (frame) {
        debugPrint('WS: Message received on queue');
        if (frame.body != null) {
          final data = jsonDecode(frame.body!);
          final message = MessageModel.fromJson(data);
          debugPrint('WS: Parsed message: ${message.senderUsername} -> ${message.receiverUsername}');
          _messageStreamController.add(message);
        }
      },
    );

    // Re-subscribe ALL registered topics (handles reconnect correctly)
    _topicRegistry.forEach((topicId, entry) {
      _subscribeNamedTopic(topicId, entry.destination, entry.callback);
    });
    _moduleRegistry.forEach((moduleId, callback) {
      _subscribeModuleTopic(moduleId, callback);
    });

    // Drain pending (first connect only — registry handles reconnects)
    _pendingModuleCallbacks.forEach((moduleId, callback) {
      _subscribeModuleTopic(moduleId, callback);
    });
    _pendingModuleCallbacks.clear();

    _pendingTopicCallbacks.forEach((topicId, callback) {
      final destination = _pendingTopicDestinations[topicId];
      if (destination != null) _subscribeNamedTopic(topicId, destination, callback);
    });
    _pendingTopicCallbacks.clear();
    _pendingTopicDestinations.clear();
  }

  void _subscribeNamedTopic(String topicId, String destination, void Function(Map<String, dynamic>) callback) {
    final sub = _client?.subscribe(
      destination: destination,
      callback: (frame) {
        if (frame.body != null) {
          try {
            final data = jsonDecode(frame.body!) as Map<String, dynamic>;
            callback(data);
          } catch (e) {
            debugPrint('WS: Error parsing topic event [$topicId]: $e');
          }
        }
      },
    );
    if (sub != null) {
      _namedTopicUnsubFns[topicId] = sub;
    }
  }

  void subscribeTopic(String topicId, String destination, void Function(Map<String, dynamic>) callback) {
    // Always register so reconnect can re-subscribe
    _topicRegistry[topicId] = (destination: destination, callback: callback);
    if (_connected) {
      _subscribeNamedTopic(topicId, destination, callback);
    } else {
      _pendingTopicDestinations[topicId] = destination;
      _pendingTopicCallbacks[topicId] = callback;
    }
  }

  void unsubscribeTopic(String topicId) {
    _topicRegistry.remove(topicId);
    _pendingTopicCallbacks.remove(topicId);
    _pendingTopicDestinations.remove(topicId);
    final unsub = _namedTopicUnsubFns.remove(topicId);
    unsub?.call();
  }

  void _subscribeModuleTopic(int moduleId, void Function(Map<String, dynamic>) callback) {
    final sub = _client?.subscribe(
      destination: '/topic/module/$moduleId/meeting-started',
      callback: (frame) {
        if (frame.body != null) {
          try {
            final data = jsonDecode(frame.body!) as Map<String, dynamic>;
            callback(data);
          } catch (e) {
            debugPrint('WS: Error parsing meeting event: $e');
          }
        }
      },
    );
    if (sub != null) {
      _moduleUnsubFns[moduleId] = sub;
    }
  }

  void subscribeToModuleMeetings(int moduleId, void Function(Map<String, dynamic>) callback) {
    _moduleRegistry[moduleId] = callback;
    if (_connected) {
      _subscribeModuleTopic(moduleId, callback);
    } else {
      _pendingModuleCallbacks[moduleId] = callback;
    }
  }

  void unsubscribeFromModuleMeetings(int moduleId) {
    _moduleRegistry.remove(moduleId);
    _pendingModuleCallbacks.remove(moduleId);
    final unsub = _moduleUnsubFns.remove(moduleId);
    unsub?.call();
  }

  void _handleDisconnect() {
    _connected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      debugPrint('WS: Attempting manual reconnect with fresh token...');
      connect();
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _client?.deactivate();
    _client = null;
    _connected = false;
  }

  /// Force une reconnexion propre, même si l'état interne pense être encore
  /// connecté. Utile au retour au premier plan (didChangeAppLifecycleState) :
  /// l'OS (surtout iOS) peut couper la socket pendant que l'app est en
  /// arrière-plan sans jamais déclencher onWebSocketError/onDisconnect — le
  /// service reste alors persuadé d'être connecté ("zombie"), et connect()
  /// tout seul ne ferait rien à cause du early-return `if (_connected) return`.
  void reconnect() {
    debugPrint('WS: Forcing reconnect (app resumed)');
    disconnect();
    connect();
  }
}
